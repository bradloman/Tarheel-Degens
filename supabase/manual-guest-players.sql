-- Tarheel Degens: manual guest players (phase 1)
-- Run in Supabase SQL Editor. Does not modify existing player or score tables.
begin;

create table if not exists public.guest_players (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  display_name text not null check (length(btrim(display_name)) between 1 and 80),
  handicap_index numeric check (handicap_index between -10 and 54),
  course_handicap integer not null default 0,
  created_at timestamptz not null default now(),
  unique (id, match_id)
);

create table if not exists public.guest_hole_scores (
  guest_id uuid not null,
  match_id uuid not null,
  hole_number integer not null check (hole_number between 1 and 36),
  gross_strokes integer not null check (gross_strokes between 1 and 30),
  saved_by uuid not null references auth.users(id),
  saved_at timestamptz not null default now(),
  primary key (guest_id, hole_number),
  foreign key (guest_id, match_id)
    references public.guest_players(id, match_id) on delete cascade
);

alter table public.guest_players enable row level security;
alter table public.guest_hole_scores enable row level security;

drop policy if exists guest_players_owner_all on public.guest_players;
create policy guest_players_owner_all on public.guest_players
for all to authenticated
using (exists (select 1 from public.matches m where m.id = match_id and m.created_by = (select auth.uid())))
with check (exists (select 1 from public.matches m where m.id = match_id and m.created_by = (select auth.uid())));

drop policy if exists guest_scores_owner_all on public.guest_hole_scores;
create policy guest_scores_owner_all on public.guest_hole_scores
for all to authenticated
using (exists (select 1 from public.matches m where m.id = match_id and m.created_by = (select auth.uid())))
with check (saved_by = (select auth.uid()) and exists (select 1 from public.matches m where m.id = match_id and m.created_by = (select auth.uid())));

commit;
