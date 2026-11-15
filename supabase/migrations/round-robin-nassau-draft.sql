-- Round Robin Nassau: one shared round with three ordinary singles Nassau matches.
-- Schema-only migration. Do not deploy until shared score entry, authorization,
-- and atomic match creation are implemented and tested.
begin;
create table if not exists public.round_robin_nassau_groups (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);
create table if not exists public.round_robin_nassau_matches (
  group_id uuid not null references public.round_robin_nassau_groups(id) on delete cascade,
  match_id uuid not null references public.matches(id) on delete cascade,
  pairing_number smallint not null check (pairing_number between 1 and 3),
  primary key (group_id, match_id),
  unique (match_id),
  unique (group_id, pairing_number)
);
create index if not exists round_robin_nassau_groups_creator_idx
  on public.round_robin_nassau_groups(created_by);
alter table public.round_robin_nassau_groups enable row level security;
alter table public.round_robin_nassau_matches enable row level security;
-- Read access follows the existing match membership rules; creator may also read
-- their own groups (including admin-created matches where admin is not playing).
create policy "Round robin group creator reads group"
  on public.round_robin_nassau_groups for select to authenticated
  using (created_by = auth.uid());
create policy "Round robin creator reads linked matches"
  on public.round_robin_nassau_matches for select to authenticated
  using (exists (select 1 from public.round_robin_nassau_groups g
                where g.id = group_id and g.created_by = auth.uid()));
-- Deliberately no client INSERT/UPDATE/DELETE policies: creation must use
-- a SECURITY DEFINER RPC validating all three distinct participants,
-- exactly three match pairs, ownership, and a single transaction.
commit;
