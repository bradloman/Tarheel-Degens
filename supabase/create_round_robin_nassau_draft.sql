-- Development draft only. Requires round_robin_nassau_draft.sql first.
-- Registered players only in this initial RPC; guest/directory support is a later extension.
create or replace function public.create_round_robin_nassau(
  p_players uuid[], p_course uuid, p_tee uuid, p_stake numeric, p_date date default current_date
) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_owner uuid := auth.uid();
  v_parent uuid;
  v_child uuid;
  v_a uuid;
  v_b uuid;
  v_pairs uuid[];
  v_i int;
  v_j int;
  v_pair_number int := 0;
begin
  if v_owner is null then raise exception 'Sign in required'; end if;
  if coalesce(array_length(p_players,1),0) <> 3 or
     (select count(distinct x) from unnest(p_players) x) <> 3 or
     array_position(p_players,null) is not null
  then raise exception 'Exactly three different players required'; end if;
  if p_stake is null or p_stake <= 0 then raise exception 'Stake must be positive'; end if;
  if p_date is null then raise exception 'Match date required'; end if;
  if not exists(select 1 from public.course_tees t
                where t.id=p_tee and t.course_id=p_course)
  then raise exception 'Course and tee do not match'; end if;
  if exists(select 1 from unnest(p_players) x
            where not exists(select 1 from public.players p
              where p.id=x and (p.directory_visible or p.id=v_owner)))
  then raise exception 'Player unavailable in directory'; end if;

  -- This narrowly scoped SECURITY DEFINER RPC verifies auth and the selected roster.
  -- All writes are one transaction; no arbitrary match IDs or child links accepted.
  insert into public.matches(created_by,course_id,tee_id,game_type,match_date,stake,hole_count,player_count)
  values(v_owner,p_course,p_tee,'round_robin_nassau',p_date,p_stake,18,3)
  returning id into v_parent;

  insert into public.match_players(match_id,player_id,course_handicap,tee_id)
  select v_parent,x,0,p_tee from unnest(p_players) x;

  v_pairs := (select array_agg(x order by x) from unnest(p_players) x);
  for v_i in 1..2 loop
    for v_j in (v_i+1)..3 loop
      v_a := v_pairs[v_i]; v_b := v_pairs[v_j];
      v_pair_number := v_pair_number+1;
      insert into public.matches(created_by,course_id,tee_id,game_type,match_date,stake,hole_count,player_count)
      values(v_owner,p_course,p_tee,'nassau',p_date,p_stake,18,2)
      returning id into v_child;
      insert into public.match_players(match_id,player_id,course_handicap,tee_id)
      values(v_child,v_a,0,p_tee),(v_child,v_b,0,p_tee);
      insert into public.nassau_bets(match_id,label,start_hole,end_hole,stake)
      values (v_child,'Front 9',1,9,p_stake),
             (v_child,'Back 9',10,18,p_stake),
             (v_child,'Overall',1,18,p_stake);
      insert into public.round_robin_nassau_pairs(parent_match_id,child_match_id,player_a_id,player_b_id,pair_number)
      values(v_parent,v_child,v_a,v_b,v_pair_number);
    end loop;
  end loop;
  return v_parent;
end;
$$;
-- Deliberately disabled until migration, shared-score readers, and integration tests pass.
revoke all on function public.create_round_robin_nassau(uuid[],uuid,uuid,numeric,date) from public,anon,authenticated;
-- After review, explicitly grant execute to authenticated only.

