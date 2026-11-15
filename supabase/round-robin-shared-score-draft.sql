-- Shared Round Robin score entry, draft for review before deployment.
-- A single call writes one player's gross score to both linked Nassau matches.
-- The transaction rolls back if either write fails.
create or replace function public.save_round_robin_nassau_score(
  p_group uuid, p_player_key text, p_hole integer, p_gross integer
) returns integer
language plpgsql security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_owner uuid;
  v_match uuid;
  v_count integer := 0;
  v_registered uuid;
  v_directory uuid;
  v_guest uuid;
begin
  if v_actor is null then raise exception 'Sign in required'; end if;
  select created_by into v_owner
    from public.round_robin_nassau_groups where id=p_group for update;
  if not found then raise exception 'Round Robin round not found'; end if;
  if v_owner <> v_actor then raise exception 'Only the round creator can edit shared scores'; end if;
  if p_hole not between 1 and 18 or p_gross not between 1 and 30 then
    raise exception 'Invalid hole or gross score';
  end if;
  if p_player_key ~ '^registered:[0-9a-fA-F-]{36}$' then
    v_registered := substring(p_player_key from 12)::uuid;
  elsif p_player_key ~ '^directory:[0-9a-fA-F-]{36}$' then
    v_directory := substring(p_player_key from 11)::uuid;
  else
    raise exception 'Invalid player key';
  end if;

  for v_match in
    select l.match_id from public.round_robin_nassau_matches l
    join public.matches m on m.id=l.match_id
    where l.group_id=p_group and m.status='active'
    order by l.pairing_number
  loop
    if v_registered is not null and exists(
      select 1 from public.match_players
      where match_id=v_match and player_id=v_registered
    ) then
      insert into public.hole_scores(match_id,player_id,hole_number,gross_strokes)
      values(v_match,v_registered,p_hole,p_gross)
      on conflict (match_id,player_id,hole_number)
      do update set gross_strokes=excluded.gross_strokes;
      v_count := v_count+1;
    elsif v_directory is not null then
      select id into v_guest from public.guest_players
        where match_id=v_match and directory_entry_id=v_directory;
      if found then
        insert into public.guest_hole_scores(match_id,guest_id,hole_number,gross_strokes)
        values(v_match,v_guest,p_hole,p_gross)
        on conflict (match_id,guest_id,hole_number)
        do update set gross_strokes=excluded.gross_strokes;
        v_count := v_count+1;
      end if;
    end if;
  end loop;
  if v_count <> 2 then raise exception 'Shared score must update exactly two matches; found %',v_count; end if;
  return v_count;
end;
$$;
revoke all on function public.save_round_robin_nassau_score(uuid,text,integer,integer) from public,anon;
grant execute on function public.save_round_robin_nassau_score(uuid,text,integer,integer) to authenticated;
