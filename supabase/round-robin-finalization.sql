-- Staged only: dedicated atomic settlement for three independent Nassau pairings.
create table if not exists public.round_robin_bet_results(
 id uuid primary key default gen_random_uuid(),
 match_id uuid not null references public.matches(id) on delete cascade,
 player_a uuid not null references public.players(id),
 player_b uuid not null references public.players(id),
 segment text not null check(segment in ('front','back','overall')),
 press_id uuid references public.match_round_robin_presses(id),
 start_hole integer not null,
 end_hole integer not null,
 lead integer not null,
 stake_cents bigint not null,
 amount_a_cents bigint not null
);
create unique index if not exists rr_base_bet_unique on public.round_robin_bet_results(match_id,player_a,player_b,segment) where press_id is null;
create unique index if not exists rr_press_bet_unique on public.round_robin_bet_results(press_id) where press_id is not null;
create table if not exists public.round_robin_player_results(
 match_id uuid not null references public.matches(id) on delete cascade,
 player_id uuid not null references public.players(id),
 net_cents bigint not null,
 primary key(match_id,player_id)
);
alter table public.round_robin_bet_results enable row level security;
alter table public.round_robin_player_results enable row level security;
revoke all on public.round_robin_bet_results,public.round_robin_player_results from anon,authenticated;
grant select on public.round_robin_bet_results,public.round_robin_player_results to authenticated;
drop policy if exists rr_bet_results_read on public.round_robin_bet_results;
create policy rr_bet_results_read on public.round_robin_bet_results for select to authenticated using(public.is_match_member(match_id) or public.is_match_owner(match_id));
drop policy if exists rr_player_results_read on public.round_robin_player_results;
create policy rr_player_results_read on public.round_robin_player_results for select to authenticated using(public.is_match_member(match_id) or public.is_match_owner(match_id));

create or replace function public.finalize_round_robin_match(p_match uuid)
returns text language plpgsql security definer set search_path='' as $$
declare
 m public.matches%rowtype; pair record; bet record; seg text;
 first_h integer; last_h integer; start_h integer; finish_h integer;
 running_lead integer; remaining integer; stake_c bigint;
 h integer; si integer; ga integer; gb integer; ca integer; cb integer;
 low_ch integer; net_a integer; net_b integer; amount_c bigint;
begin
 if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
 select * into m from public.matches where id=p_match for update;
 if not found or m.game_type<>'round_robin' or m.player_count<>3 or m.hole_count<>18 then raise exception 'Not a Round Robin Nassau'; end if;
 if m.created_by is distinct from (select auth.uid()) then raise exception 'Only match creator can post'; end if;
 if m.status='completed' then return 'completed'; end if;
 if m.status<>'active' then raise exception 'Match not active'; end if;
 if (select count(*) from public.match_players where match_id=p_match)<>3
 or exists(select 1 from public.guest_players where match_id=p_match) then raise exception 'Requires three registered players'; end if;
 if exists(select 1 from public.match_players mp where mp.match_id=p_match and mp.course_handicap is null)
 then raise exception 'Saved course handicaps required'; end if;
 if (select count(distinct stroke_index) from public.match_hole_strokes where match_id=p_match and hole_number between 1 and 18)<>18
 then raise exception 'Valid saved stroke indexes required'; end if;
 if exists(select 1 from public.match_players mp where mp.match_id=p_match and
   (select count(distinct hs.hole_number) from public.hole_scores hs where hs.match_id=p_match and hs.player_id=mp.player_id and hs.hole_number between 1 and 18 and hs.gross_strokes between 1 and 30)<>18)
 then raise exception 'All 18 scores required for each player'; end if;
 stake_c:=round(m.stake*100)::bigint;
 if stake_c is null or stake_c<0 then raise exception 'Invalid stake'; end if;
 for pair in select p1.player_id a,p2.player_id b,p1.course_handicap ca,p2.course_handicap cb
 from public.match_players p1 join public.match_players p2 on p1.match_id=p2.match_id and p1.player_id<p2.player_id where p1.match_id=p_match loop
  ca:=pair.ca;cb:=pair.cb;low_ch:=least(ca,cb);
  for seg in select unnest(array['front','back','overall']) loop
   first_h:=case when seg='back' then 10 else 1 end;
   last_h:=case when seg='front' then 9 else 18 end;
   for bet in
    select null::uuid id,first_h start_h,0 ord
    union all
    select pr.id,pr.start_hole,1 from public.match_round_robin_presses pr
    where pr.match_id=p_match and pr.player_a=pair.a and pr.player_b=pair.b and pr.segment=seg and pr.undone_at is null
    order by ord,start_h
   loop
    start_h:=bet.start_h;running_lead:=0;finish_h:=last_h;
    for h in start_h..last_h loop
     select stroke_index into strict si from public.match_hole_strokes where match_id=p_match and hole_number=h;
     select gross_strokes into strict ga from public.hole_scores where match_id=p_match and player_id=pair.a and hole_number=h;
     select gross_strokes into strict gb from public.hole_scores where match_id=p_match and player_id=pair.b and hole_number=h;
     net_a:=ga-((ca-low_ch)/18)-case when si<=mod(ca-low_ch,18) then 1 else 0 end;
     net_b:=gb-((cb-low_ch)/18)-case when si<=mod(cb-low_ch,18) then 1 else 0 end;
     running_lead:=running_lead+case when net_a<net_b then 1 when net_b<net_a then -1 else 0 end;
     remaining:=last_h-h;
     if abs(running_lead)>remaining then finish_h:=h;exit;end if;
    end loop;
    amount_c:=sign(running_lead)*stake_c;
    insert into public.round_robin_bet_results(match_id,player_a,player_b,segment,press_id,start_hole,end_hole,lead,stake_cents,amount_a_cents)
    values(p_match,pair.a,pair.b,seg,bet.id,start_h,finish_h,running_lead,stake_c,amount_c);
    insert into public.round_robin_player_results(match_id,player_id,net_cents) values(p_match,pair.a,amount_c)
    on conflict(match_id,player_id) do update set net_cents=public.round_robin_player_results.net_cents+excluded.net_cents;
    insert into public.round_robin_player_results(match_id,player_id,net_cents) values(p_match,pair.b,-amount_c)
    on conflict(match_id,player_id) do update set net_cents=public.round_robin_player_results.net_cents+excluded.net_cents;
   end loop;
  end loop;
 end loop;
 if (select count(*) from public.round_robin_bet_results where match_id=p_match)<>9+(select count(*) from public.match_round_robin_presses where match_id=p_match and undone_at is null) then raise exception 'Bet count mismatch'; end if;
 if (select coalesce(sum(net_cents),0) from public.round_robin_player_results where match_id=p_match)<>0 then raise exception 'Settlement not zero-sum'; end if;
 update public.matches set status='completed' where id=p_match;
 return 'completed';
end $$;
revoke all on function public.finalize_round_robin_match(uuid) from public,anon,authenticated;
-- Enable authenticated EXECUTE only after deployment approval.
