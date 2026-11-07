-- UNIFIED ROUND ROBIN NASSAU CREATION — DEVELOPMENT ONLY
-- Requires round_robin_nassau_draft.sql followed by
-- round_robin_directory_roster_draft.sql. Supersedes both prior creation RPC drafts.
-- Directory entry ID is the canonical participant identity for all three pairings.
-- A claimed_by account is NOT treated as a separate player.
-- The existing guest_players table represents each directory identity on a match.
-- No execute grant until scoring and settlement resolve claimed profiles correctly.
create or replace function public.create_round_robin_nassau(
 p_directory_ids uuid[], p_course uuid, p_tee uuid,
 p_stake numeric, p_date date default current_date
) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
 v_owner uuid := auth.uid();
 v_ids uuid[];
 v_parent uuid;
 v_child uuid;
 v_i integer;
 v_j integer;
 v_pair integer := 0;
begin
 if v_owner is null then raise exception 'Sign in required'; end if;
 if p_directory_ids is null or cardinality(p_directory_ids) <> 3
   or array_position(p_directory_ids,null) is not null
   or (select count(distinct x) from unnest(p_directory_ids) x) <> 3
 then raise exception 'Exactly three different directory players required'; end if;
 if p_stake is null or p_stake <= 0 then raise exception 'Stake must be positive'; end if;
 if p_date is null then raise exception 'Match date required'; end if;
 if not exists(select 1 from public.course_tees t where t.id=p_tee and t.course_id=p_course)
 then raise exception 'Course and tee do not match'; end if;
 if (select count(*) from public.player_directory_entries d where d.id=any(p_directory_ids)) <> 3
 then raise exception 'Directory player not found'; end if;

 select array_agg(x order by x) into v_ids from unnest(p_directory_ids) x;

 insert into public.matches
  (created_by,course_id,tee_id,game_type,match_date,stake,hole_count,player_count)
 values (v_owner,p_course,p_tee,'round_robin_nassau',p_date,p_stake,18,3)
 returning id into v_parent;

 insert into public.guest_players
  (match_id,display_name,handicap_index,directory_entry_id)
 select v_parent,d.display_name,d.handicap_index,d.id
 from public.player_directory_entries d where d.id=any(v_ids);

 for v_i in 1..2 loop
  for v_j in (v_i+1)..3 loop
   v_pair := v_pair+1;
   insert into public.matches
    (created_by,course_id,tee_id,game_type,match_date,stake,hole_count,player_count)
   values(v_owner,p_course,p_tee,'nassau',p_date,p_stake,18,2)
   returning id into v_child;

   insert into public.guest_players
    (match_id,display_name,handicap_index,directory_entry_id)
   select v_child,d.display_name,d.handicap_index,d.id
   from public.player_directory_entries d
   where d.id in (v_ids[v_i],v_ids[v_j]);

   insert into public.round_robin_nassau_pairs
    (parent_match_id,child_match_id,directory_a_id,directory_b_id,pair_number)
   values(v_parent,v_child,v_ids[v_i],v_ids[v_j],v_pair);
  end loop;
 end loop;
 return v_parent;
end;
$$;
revoke all on function public.create_round_robin_nassau(uuid[],uuid,uuid,numeric,date)
 from public,anon,authenticated;

-- IMPORTANT integration checks before enabling:
-- 1. Existing Nassau logic may read match_players rather than guest_players.
-- 2. Scores must resolve parent guest IDs by directory_entry_id for child matches.
-- 3. Claimed directory entries must settle to existing player records, not new guest records.
-- 4. Confirm function owner, direct table privileges, RLS and no bypass vulnerabilities.
-- 5. Test all-unclaimed, all-claimed and mixed rosters in staging.
