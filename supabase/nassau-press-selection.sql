-- Tarheel Degens: Nassau press selection (2-player and 2v2).
begin;
create table if not exists public.match_nassau_presses (
 id uuid primary key default gen_random_uuid(),
 match_id uuid not null references public.matches(id) on delete cascade,
 parent_id uuid references public.match_nassau_presses(id) on delete cascade,
 segment text not null check (segment in ('F','B','O','9')),
 start_hole integer not null check (start_hole between 2 and 36),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 undone_at timestamptz,
 undone_by uuid references auth.users(id)
);
create index if not exists match_nassau_presses_match on public.match_nassau_presses(match_id);
alter table public.match_nassau_presses enable row level security;
drop policy if exists match_nassau_presses_read on public.match_nassau_presses;
create policy match_nassau_presses_read on public.match_nassau_presses for select to authenticated
using (public.is_match_member(match_id) or public.is_match_owner(match_id));
create or replace function public.activate_nassau_press(p_match uuid,p_segment text,p_start integer,p_parent uuid default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare m public.matches%rowtype; new_id uuid; seg_start int; seg_end int; last_scored int;
begin
 select * into m from public.matches where id=p_match for update;
 if not found or (not public.is_match_member(p_match) and not public.is_match_owner(p_match)) then raise exception 'Match access denied'; end if;
 if lower(m.status::text)='posted' then raise exception 'Posted matches cannot be pressed'; end if;
 if p_segment not in ('F','B','O','9') then raise exception 'Invalid segment'; end if;
 seg_start:=case when p_segment='B' then 10 else 1 end;
 seg_end:=case when p_segment='F' then 9 when p_segment='9' then 9 else m.hole_count end;
 if p_start<=seg_start or p_start>seg_end then raise exception 'Invalid press start hole'; end if;
 if p_parent is not null and not exists(select 1 from public.match_nassau_presses where id=p_parent and match_id=p_match and segment=p_segment and undone_at is null and start_hole<p_start) then raise exception 'Invalid parent press'; end if;
 -- Client calculates two-down eligibility; server enforces start, membership, and no duplicate.
 if exists(select 1 from public.match_nassau_presses where match_id=p_match and segment=p_segment and start_hole=p_start and parent_id is not distinct from p_parent and undone_at is null) then raise exception 'Press already exists'; end if;
 insert into public.match_nassau_presses(match_id,parent_id,segment,start_hole,created_by) values(p_match,p_parent,p_segment,p_start,auth.uid()) returning id into new_id;
 return new_id;
end $$;
create or replace function public.undo_nassau_press(p_press uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare p public.match_nassau_presses%rowtype; m public.matches%rowtype; scored int;
begin
 select * into p from public.match_nassau_presses where id=p_press for update;
 if not found then raise exception 'Press not found'; end if;
 select * into m from public.matches where id=p.match_id for update;
 if (not public.is_match_member(p.match_id) and not public.is_match_owner(p.match_id)) or lower(m.status::text)='posted' then raise exception 'Not authorized'; end if;
 if p.undone_at is not null then raise exception 'Press already undone'; end if;
 if exists(select 1 from public.match_nassau_presses where parent_id=p.id and undone_at is null) then raise exception 'Undo child presses first'; end if;
 -- Once every player's score on the press starting hole is saved, undo is locked.
 select (select count(*) from public.hole_scores where match_id=p.match_id and hole_number=p.start_hole)
      +(select count(*) from public.guest_hole_scores where match_id=p.match_id and hole_number=p.start_hole) into scored;
 if scored>=m.player_count then raise exception 'Press is locked: starting-hole scores have been saved'; end if;
 update public.match_nassau_presses set undone_at=now(),undone_by=auth.uid() where id=p.id;
end $$;
revoke all on function public.activate_nassau_press(uuid,text,integer,uuid) from public,anon;
revoke all on function public.undo_nassau_press(uuid) from public,anon;
grant execute on function public.activate_nassau_press(uuid,text,integer,uuid) to authenticated;
grant execute on function public.undo_nassau_press(uuid) to authenticated;
commit;
