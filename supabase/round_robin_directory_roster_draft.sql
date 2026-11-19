-- Draft: directory-compatible Round Robin roster identity.
-- Apply after the initial round_robin_nassau_draft.sql migration.
-- Replaces registered-only player_a_id/player_b_id with directory-aware identifiers.
alter table public.round_robin_nassau_pairs
  drop constraint if exists rr_distinct_players,
  drop constraint if exists rr_ordered_players,
  drop constraint if exists rr_unique_pair;
alter table public.round_robin_nassau_pairs
  drop column player_a_id,
  drop column player_b_id;
alter table public.round_robin_nassau_pairs
  add column directory_a_id uuid not null references public.player_directory_entries(id),
  add column directory_b_id uuid not null references public.player_directory_entries(id),
  add constraint rr_distinct_directory_players check (directory_a_id < directory_b_id),
  add constraint rr_unique_directory_pair unique(parent_match_id,directory_a_id,directory_b_id);

-- Directory identities are stable across match-specific guest_player IDs.
-- Every child gets its own guest_players rows, with the same directory_entry_id.
-- Shared score entry is recorded against the parent guest IDs, and child score
-- consumers must resolve those identities through directory_entry_id.
-- NOTE: registered player profiles need a directory-entry mapping before
-- this approach can be enabled for mixed registered/directory rosters.
