-- Team assignments for 4-player Tarheel Degens matches
create table if not exists public.match_team_players (
  match_id uuid not null references public.matches(id) on delete cascade,
  player_id uuid references public.players(id) on delete cascade,
  guest_id uuid references public.guest_players(id) on delete cascade,
  team_number integer not null check (team_number in (1,2)),
  player_key uuid generated always as (coalesce(player_id,guest_id)) stored,
  constraint match_team_player_identity check ((player_id is null) <> (guest_id is null)),
  primary key (match_id,player_key)
);
create index if not exists match_team_players_match_idx on public.match_team_players(match_id);
alter table public.match_team_players enable row level security;
drop policy if exists "Team members can view assignments" on public.match_team_players;
create policy "Team members can view assignments" on public.match_team_players for select to authenticated
using (public.is_match_member(match_id) or public.is_match_owner(match_id));
drop policy if exists "Match owners can assign teams" on public.match_team_players;
create policy "Match owners can assign teams" on public.match_team_players for all to authenticated
using (public.is_match_owner(match_id)) with check (public.is_match_owner(match_id));
