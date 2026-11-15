-- Staged only: apply after reviewing the live schema and match authorization.
create table if not exists public.match_round_robin_presses (
 id uuid primary key default gen_random_uuid(),
 match_id uuid not null references public.matches(id) on delete cascade,
 player_a uuid not null references public.players(id),
 player_b uuid not null references public.players(id),
 segment text not null check (segment in ('front','back','overall')),
 start_hole integer not null check (start_hole between 1 and 18),
 created_by uuid not null,
 created_at timestamptz not null default now(),
 undone_at timestamptz,
 undone_by uuid,
 constraint rr_distinct_players check (player_a <> player_b)
);
create index if not exists rr_presses_match_idx on public.match_round_robin_presses(match_id);
alter table public.match_round_robin_presses enable row level security;
create policy rr_presses_read on public.match_round_robin_presses for select to authenticated using (public.is_match_member(match_id) or public.is_match_owner(match_id));
create policy rr_presses_insert on public.match_round_robin_presses for insert to authenticated with check (created_by=(select auth.uid()) and (public.is_match_member(match_id) or public.is_match_owner(match_id)) and exists (select 1 from public.matches m where m.id=match_id and m.game_type='round_robin' and m.status='active'));
create policy rr_presses_update on public.match_round_robin_presses for update to authenticated using (public.is_match_owner(match_id) and undone_at is null) with check (public.is_match_owner(match_id) and undone_by=(select auth.uid()));
grant select,insert,update on public.match_round_robin_presses to authenticated;
