-- Draft migration: NOT applied to production.
-- Round Robin is represented by a parent match with three ordinary Nassau children.
-- Master scores are stored only against the parent match in hole_scores.
-- Existing Nassau score readers must be adapted to resolve child scores from parent.
alter table public.matches drop constraint if exists matches_game_type_check;
alter table public.matches add constraint matches_game_type_check
  check (game_type in ('nassau','mega_nassau','skins','quota','hammer','high_low','better_ball','tilt','scotch','nines','round_robin_nassau'));

alter table public.matches add constraint round_robin_nassau_player_count_check
  check (game_type <> 'round_robin_nassau' or player_count = 3);
alter table public.matches add constraint round_robin_nassau_holes_check
  check (game_type <> 'round_robin_nassau' or hole_count = 18);

create table public.round_robin_nassau_pairs (
  parent_match_id uuid not null references public.matches(id) on delete cascade,
  child_match_id uuid not null unique references public.matches(id) on delete cascade,
  player_a_id uuid not null references public.players(id),
  player_b_id uuid not null references public.players(id),
  pair_number integer not null check (pair_number between 1 and 3),
  primary key (parent_match_id,pair_number),
  constraint rr_distinct_players check (player_a_id <> player_b_id),
  constraint rr_ordered_players check (player_a_id < player_b_id),
  constraint rr_unique_pair unique (parent_match_id,player_a_id,player_b_id)
);
create index rr_pairs_child_idx on public.round_robin_nassau_pairs(child_match_id);
alter table public.round_robin_nassau_pairs enable row level security;

-- Only participants and the creator may view pairing information.
create policy "round robin pair visibility" on public.round_robin_nassau_pairs
for select to authenticated
using (
  exists (
    select 1 from public.matches m
    where m.id = parent_match_id
      and (m.created_by = (select auth.uid())
        or exists (select 1 from public.match_players mp
                   where mp.match_id = m.id and mp.player_id = (select auth.uid())))
  )
);
-- Pair inserts/deletes intentionally have no client-facing policies.
-- An authenticated, authorization-checking creation RPC will write the pairs atomically.
