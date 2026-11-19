-- DEVELOPMENT DRAFT ONLY. Requires both Round Robin schema drafts.
-- Directory-only path. Mixed registered/directory rosters require a canonical
-- player identity mapping; do not enable until that is designed and tested.
create or replace function public.create_round_robin_nassau_directory(
 p_entries uuid[], p_course uuid, p_tee uuid, p_stake numeric,
 p_date date default current_date
) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
 v_owner uuid := auth.uid();
 v_ids uuid[];
 v_parent uuid;
 v_child uuid;
 v_i int;
 v_j int;
 v_pair int := 0;
begin
 if v_owner is null then raise exception 'Sign in required'; end if;
 if cardinality(p_entries) <> 3
    or (select count(distinct x) from unnest(p_entries) x) <> 3
    or array_position(p_entries,null) is not null
 then raise exception 'Exactly three distinct directory entries required'; end if;
 if p_stake is null or p_stake <= 0 then raise exception 'Positive stake required'; end if;
 if p_date is null then raise exception 'Date required'; end if;
 if not exists (select 1 from public.course_tees t
                where t.id=p_tee and t.course_id=p_course)
 then raise exception 'Invalid course and tee'; end if;
 if (select count(*) from public.player_directory_entries d
     where d.id=any(p_entries)) <> 3
 then raise exception 'Directory entry missing'; end if;
 select array_agg(x order by x) into v_ids from unnest(p_entries) x;

 insert into public.matches(created_by,course_id,tee_id,game_type,match_date,stake,hole_count,player_count)
 values(v_owner,p_course,p_tee,'round_robin_nassau',p_date,p_stake,18,3)
 returning id into v_parent;

 insert into public.guest_players(match_id,display_name,handicap_index,directory_entry_id)
 select v_parent,d.display_name,d.handicap_index,d.id
 from public.player_directory_entries d where d.id=any(v_ids);

 for v_i in 1..2 loop
  for v_j in v_i+1..3 loop
   v_pair:=v_pair+1;
   insert into public.matches(created_by,course_id,tee_id,game_type,match_date,stake,hole_count,player_count)
   values(v_owner,p_course,p_tee,'nassau',p_date,p_stake,18,2)
   returning id into v_child;

   insert into public.guest_players(match_id,display_name,handicap_index,directory_entry_id)
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
-- No client execution while draft is untested.
revoke all on function public.create_round_robin_nassau_directory(uuid[],uuid,uuid,numeric,date)
 from public,anon,authenticated;
