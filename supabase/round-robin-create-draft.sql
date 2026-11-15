-- DRAFT: run only after round-robin-nassau-draft.sql has been reviewed/applied.
-- One transaction creates a linked group and three singles Nassau matches.
-- Each participant key is "registered:<uuid>" or "directory:<uuid>".
create or replace function public.create_round_robin_nassau(
  p_players text[], p_date date, p_stake numeric,
  p_course uuid default null, p_tee uuid default null
) returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  v_creator uuid := (select auth.uid());
  v_group uuid;
  v_match uuid;
  v_key text;
  v_player uuid;
  v_entry uuid;
  v_i int;
  v_pair_no int := 0;
  v_match_ids uuid[] := array[]::uuid[];
  v_entry_name text;
  v_entry_index numeric;
begin
  if v_creator is null then raise exception 'Sign in required'; end if;
  if not exists(select 1 from public.players where id=v_creator) then
    raise exception 'Save your profile before creating a match';
  end if;
  if p_players is null or cardinality(p_players) <> 3 or array_position(p_players,null) is not null
     or (select count(distinct k) from unnest(p_players) k) <> 3 then
    raise exception 'Select exactly three distinct players';
  end if;
  if p_date is null or p_stake is null or p_stake <= 0 then
    raise exception 'A date and positive per-bet stake are required';
  end if;
  if p_tee is not null and (p_course is null or not exists (
    select 1 from public.course_tees where id=p_tee and course_id=p_course
  )) then raise exception 'Tees must belong to the selected course'; end if;
  if p_course is not null and not exists(select 1 from public.courses where id=p_course) then
    raise exception 'Course not found';
  end if;

  -- Validate the entire roster before creating anything.
  foreach v_key in array p_players loop
    if v_key ~ '^registered:[0-9a-fA-F-]{36}$' then
      v_player := substring(v_key from 12)::uuid;
      if not exists(select 1 from public.players
                    where id=v_player and (directory_visible or id=v_creator)) then
        raise exception 'Registered player is not available';
      end if;
    elsif v_key ~ '^directory:[0-9a-fA-F-]{36}$' then
      v_entry := substring(v_key from 11)::uuid;
      if not exists(select 1 from public.player_directory_entries where id=v_entry and removed_from_directory is not true) then
        raise exception 'Directory player is not available';
      end if;
    else
      raise exception 'Invalid player selection';
    end if;
  end loop;

  -- The same claimed directory player must not appear under multiple keys.
  if exists(select 1 from public.player_directory_entries d1
            join public.player_directory_entries d2 on d1.claimed_by=d2.claimed_by
            where d1.id<>d2.id and d1.claimed_by is not null
              and ('directory:'||d1.id::text)=any(p_players)
              and ('directory:'||d2.id::text)=any(p_players)) then
    raise exception 'A claimed player was selected twice';
  end if;

  -- One selected person must not appear under two different identities.
  if exists(
    select 1 from public.player_directory_entries d
    where ('directory:' || d.id::text) = any(p_players)
      and d.claimed_by is not null
      and ('registered:' || d.claimed_by::text) = any(p_players)
  ) then raise exception 'A player was selected twice'; end if;

  insert into public.round_robin_nassau_groups(created_by)
  values(v_creator) returning id into v_group;

  for v_i in 1..3 loop
    v_pair_no := v_i;
    insert into public.matches
      (created_by,game_type,match_date,stake,player_count,hole_count,course_id,tee_id,notes)
    values
      (v_creator,'nassau',p_date,p_stake,2,18,p_course,p_tee,
       jsonb_build_object('round_robin_group',v_group,'pairing',v_pair_no)::text)
    returning id into v_match;

    foreach v_key in array array[p_players[case v_i when 1 then 1 when 2 then 1 else 2 end],p_players[case v_i when 1 then 2 when 2 then 3 else 3 end]] loop
      if left(v_key,11) = 'registered:' then
        v_player := substring(v_key from 12)::uuid;
        insert into public.match_players(match_id,player_id,course_handicap)
        values(v_match,v_player,0);
      else
        v_entry := substring(v_key from 11)::uuid;
        select display_name,handicap_index into strict v_entry_name,v_entry_index
          from public.player_directory_entries where id=v_entry;
        insert into public.guest_players
          (match_id,display_name,handicap_index,course_handicap,directory_entry_id)
        values(v_match,v_entry_name,v_entry_index,0,v_entry);
      end if;
    end loop;
    insert into public.round_robin_nassau_matches(group_id,match_id,pairing_number)
    values(v_group,v_match,v_pair_no);
    v_match_ids := array_append(v_match_ids,v_match);
  end loop;
  return jsonb_build_object('group_id',v_group,'match_ids',v_match_ids);
end;
$$;
revoke all on function public.create_round_robin_nassau(text[],date,numeric,uuid,uuid) from public,anon;
grant execute on function public.create_round_robin_nassau(text[],date,numeric,uuid,uuid) to authenticated;
