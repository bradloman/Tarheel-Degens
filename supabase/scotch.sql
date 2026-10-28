-- Scotch per-hole closest-to-pin results and match options.
-- Apply in Supabase SQL editor before enabling Scotch match creation.
create table if not exists public.match_scotch_ctp (
  match_id uuid not null references public.matches(id) on delete cascade,
  hole_number integer not null check (hole_number between 1 and 18),
  player_id uuid null references auth.users(id),
  guest_id uuid null references public.guest_players(id) on delete cascade,
  primary key (match_id, hole_number),
  constraint scotch_ctp_one_player check (num_nonnulls(player_id, guest_id) <= 1)
);
create index if not exists match_scotch_ctp_player_idx on public.match_scotch_ctp(player_id);
alter table public.match_scotch_ctp enable row level security;
-- Reuse the existing match membership/ownership helpers.
create policy "scotch_ctp_read_members" on public.match_scotch_ctp
for select to authenticated using (public.is_match_member(match_id) or public.is_match_owner(match_id));
create policy "scotch_ctp_insert_members" on public.match_scotch_ctp
for insert to authenticated with check (public.is_match_member(match_id) or public.is_match_owner(match_id));
create policy "scotch_ctp_update_members" on public.match_scotch_ctp
for update to authenticated using (public.is_match_member(match_id) or public.is_match_owner(match_id))
with check (public.is_match_member(match_id) or public.is_match_owner(match_id));
create policy "scotch_ctp_delete_members" on public.match_scotch_ctp
for delete to authenticated using (public.is_match_member(match_id) or public.is_match_owner(match_id));
-- Match options are stored in matches.notes as JSON: {"scotch":{"birdieMode":"gross","bettingMode":"fixed"}}.
-- Null player/guest signifies no qualifying ball on the green.
