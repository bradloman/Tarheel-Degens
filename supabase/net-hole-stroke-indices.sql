-- Tarheel Degens: per-match hole stroke rankings for net scoring.
-- Run in Supabase SQL Editor. Existing scores remain unchanged.
begin;
create table if not exists public.match_hole_strokes (
  match_id uuid not null references public.matches(id) on delete cascade,
  hole_number integer not null check (hole_number between 1 and 36),
  stroke_index integer not null check (stroke_index between 1 and 18),
  primary key (match_id, hole_number)
);
alter table public.match_hole_strokes enable row level security;
drop policy if exists match_hole_strokes_read on public.match_hole_strokes;
create policy match_hole_strokes_read on public.match_hole_strokes
for select to authenticated
using (exists (select 1 from public.matches m where m.id=match_id and (m.created_by=(select auth.uid()) or public.is_match_member(m.id))));
drop policy if exists match_hole_strokes_owner_insert on public.match_hole_strokes;
create policy match_hole_strokes_owner_insert on public.match_hole_strokes
for insert to authenticated
with check (exists (select 1 from public.matches m where m.id=match_id and m.created_by=(select auth.uid())));
drop policy if exists match_hole_strokes_owner_update on public.match_hole_strokes;
create policy match_hole_strokes_owner_update on public.match_hole_strokes
for update to authenticated
using (exists (select 1 from public.matches m where m.id=match_id and m.created_by=(select auth.uid())))
with check (exists (select 1 from public.matches m where m.id=match_id and m.created_by=(select auth.uid())));
commit;