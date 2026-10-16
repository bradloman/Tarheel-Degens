-- Tarheel Degens: only bradloman@gmail.com may delete unposted matches.
-- Run in Supabase SQL Editor after the match-teams migration.
-- Uses the signed-in auth user ID to verify email from auth.users, not a client-supplied email.
begin;

create or replace function public.can_delete_matches()
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from auth.users u
    where u.id = (select auth.uid())
      and lower(u.email) = 'bradloman@gmail.com'
  );
$$;

create or replace function public.delete_unposted_match(target_match_id uuid)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  current_status text;
begin
  if not public.can_delete_matches() then
    raise exception 'Only the designated Tarheel Degens administrator may delete matches';
  end if;

  select m.status::text into current_status
  from public.matches m
  where m.id = target_match_id
  for update;

  if not found then
    raise exception 'Match not found';
  end if;

  if lower(coalesce(current_status,'')) in ('posted','final','finalized','completed','complete') then
    raise exception 'Posted or completed matches cannot be deleted';
  end if;

  -- Remove related records first, including tables that may not cascade.
  delete from public.match_team_players where match_id = target_match_id;
  delete from public.guest_hole_scores where match_id = target_match_id;
  delete from public.guest_players where match_id = target_match_id;
  delete from public.hole_scores where match_id = target_match_id;
  delete from public.press_events where match_id = target_match_id;
  delete from public.nassau_bets where match_id = target_match_id;
  delete from public.match_hole_strokes where match_id = target_match_id;
  delete from public.match_players where match_id = target_match_id;
  delete from public.matches where id = target_match_id;
end;
$$;

revoke all on function public.can_delete_matches() from public, anon;
revoke all on function public.delete_unposted_match(uuid) from public, anon;
grant execute on function public.can_delete_matches() to authenticated;
grant execute on function public.delete_unposted_match(uuid) to authenticated;
commit;
