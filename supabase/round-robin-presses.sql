-- Round Robin Nassau press schema, staged for review; not applied to production.
-- Requires separate approval of the round_robin game type and match creation.
create table if not exists public.match_round_robin_presses (
 id uuid primary key default gen_random_uuid(),
 match_id uuid not null references public.matches(id) on delete cascade,
 player_a uuid not null references public.players(id),
 player_b uuid not null references public.players(id),
 segment text not null check(segment in ('front','back','overall')),
 start_hole integer not null check(start_hole between 2 and 18),
 created_by uuid not null,
 created_at timestamptz not null default now(),
 undone_at timestamptz,
 undone_by uuid,
 constraint rr_distinct_players check(player_a < player_b),
 constraint rr_segment_start check(
  (segment='front' and start_hole between 2 and 9)
  or (segment='back' and start_hole between 11 and 18)
  or (segment='overall' and start_hole between 2 and 18))
);
create unique index if not exists rr_active_press_unique
 on public.match_round_robin_presses(match_id,player_a,player_b,segment,start_hole)
 where undone_at is null;
create index if not exists rr_presses_match_idx on public.match_round_robin_presses(match_id);
alter table public.match_round_robin_presses enable row level security;
revoke all on public.match_round_robin_presses from anon,authenticated;
grant select on public.match_round_robin_presses to authenticated;
drop policy if exists rr_presses_read on public.match_round_robin_presses;
create policy rr_presses_read on public.match_round_robin_presses for select to authenticated
 using(public.is_match_member(match_id) or public.is_match_owner(match_id));

-- Mutations are RPC-only. Client-side eligibility is UX, not an authorization check.
create or replace function public.activate_round_robin_press(
 p_match uuid,p_player_a uuid,p_player_b uuid,p_segment text,p_start integer)
returns uuid language plpgsql security definer set search_path='' as $$
declare m public.matches%rowtype; v_id uuid; v_a uuid; v_b uuid; v_last integer;
begin
 if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
 select * into m from public.matches where id=p_match for update;
 if not found or m.game_type<>'round_robin' or m.status<>'active' or m.player_count<>3 or m.hole_count<>18
 then raise exception 'Not an active three-player Round Robin Nassau'; end if;
 if not (public.is_match_member(p_match) or public.is_match_owner(p_match)) then raise exception 'Not authorized'; end if;
 if p_player_a is null or p_player_b is null or p_player_a=p_player_b then raise exception 'Invalid matchup'; end if;
 v_a:=least(p_player_a,p_player_b);v_b:=greatest(p_player_a,p_player_b);
 if not exists(select 1 from public.match_players where match_id=p_match and player_id=v_a)
 or not exists(select 1 from public.match_players where match_id=p_match and player_id=v_b)
 then raise exception 'Players not in this match'; end if;
 if not ((p_segment='front' and p_start between 2 and 9) or
         (p_segment='back' and p_start between 11 and 18) or
         (p_segment='overall' and p_start between 2 and 18))
 then raise exception 'Invalid press start'; end if;
 -- All three players must have scored every prior hole; next hole must be unscored.
 select coalesce(max(h),0) into v_last from generate_series(1,18) h
 where not exists (
  select 1 from generate_series(1,h) prior
  where (select count(distinct player_id) from public.hole_scores
         where match_id=p_match and hole_number=prior)<>3
 );
 if p_start<>v_last+1 then raise exception 'Press must start on next unscored hole'; end if;
 if exists(select 1 from public.hole_scores where match_id=p_match and hole_number=p_start)
 then raise exception 'Starting hole already scored'; end if;
 -- Server-side two-down and re-press eligibility must be validated before enabling RPC execution.
 raise exception 'Round Robin press activation pending server-side eligibility validation';
end $$;

create or replace function public.undo_round_robin_press(p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare p public.match_round_robin_presses%rowtype; m public.matches%rowtype;
begin
 if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
 select * into p from public.match_round_robin_presses where id=p_id for update;
 if not found or p.undone_at is not null then raise exception 'Active press not found'; end if;
 select * into m from public.matches where id=p.match_id for update;
 if m.status<>'active' or m.game_type<>'round_robin' then raise exception 'Match is not active'; end if;
 if not public.is_match_owner(p.match_id) then raise exception 'Only the match owner can undo'; end if;
 if exists(select 1 from public.hole_scores where match_id=p.match_id and hole_number>=p.start_hole)
 or exists(select 1 from public.guest_hole_scores where match_id=p.match_id and hole_number>=p.start_hole)
 then raise exception 'Press locked: scores already saved on or after its start hole'; end if;
 update public.match_round_robin_presses set undone_at=now(),undone_by=(select auth.uid()) where id=p_id;
end $$;
revoke all on function public.activate_round_robin_press(uuid,uuid,uuid,text,integer) from public,anon,authenticated;
revoke all on function public.undo_round_robin_press(uuid) from public,anon;
grant execute on function public.undo_round_robin_press(uuid) to authenticated;
