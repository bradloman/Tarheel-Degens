-- Tarheel Degens multiplayer foundation (Supabase SQL Editor)
-- Run in a NEW Supabase project. Players join with a shared match code.
create extension if not exists pgcrypto;
create table if not exists public.matches (
 id uuid primary key default gen_random_uuid(),
 join_code text not null unique default upper(substr(encode(gen_random_bytes(6),'hex'),1,8)),
 state jsonb not null default '{}'::jsonb,
 version bigint not null default 0,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.match_members (
 match_id uuid not null references public.matches(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 joined_at timestamptz not null default now(),
 primary key(match_id,user_id)
);
create table if not exists public.match_events (
 id bigint generated always as identity primary key,
 match_id uuid not null references public.matches(id) on delete cascade,
 actor_id uuid not null references auth.users(id),
 kind text not null check(kind in ('scores_saved','presses_activated','presses_canceled')),
 payload jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);
create index if not exists match_events_match_idx on public.match_events(match_id,id);
alter table public.matches enable row level security;
alter table public.match_members enable row level security;
alter table public.match_events enable row level security;
-- Membership lookup uses a SECURITY DEFINER helper to avoid recursive RLS.
create or replace function public.is_match_member(mid uuid)
returns boolean language sql security definer set search_path=public
as $$ select exists(select 1 from public.match_members where match_id=mid and user_id=auth.uid()) $$;
revoke all on function public.is_match_member(uuid) from public;
grant execute on function public.is_match_member(uuid) to authenticated;
create policy "Members read matches" on public.matches for select to authenticated using (public.is_match_member(id));
create policy "Members read roster" on public.match_members for select to authenticated using (public.is_match_member(match_id));
create policy "Members read events" on public.match_events for select to authenticated using (public.is_match_member(match_id));
-- All mutations happen in RPCs below, not through unrestricted client writes.
create or replace function public.create_match(initial_state jsonb)
returns table(match_id uuid, code text)
language plpgsql security definer set search_path=public as $$
declare mid uuid; c text;
begin
 if auth.uid() is null then raise exception 'Sign in first'; end if;
 insert into public.matches(state) values (initial_state) returning id,join_code into mid,c;
 insert into public.match_members(match_id,user_id) values(mid,auth.uid());
 return query select mid,c;
end $$;
create or replace function public.join_match(code_input text)
returns uuid language plpgsql security definer set search_path=public as $$
declare mid uuid;
begin
 if auth.uid() is null then raise exception 'Sign in first'; end if;
 select id into mid from public.matches where join_code=upper(trim(code_input));
 if mid is null then raise exception 'Invalid match code'; end if;
 insert into public.match_members(match_id,user_id) values(mid,auth.uid()) on conflict do nothing;
 return mid;
end $$;
-- Compare-and-swap prevents one phone silently overwriting the other's changes.
-- Future score/press-specific RPCs will enforce locks server-side.
create or replace function public.save_match_state(mid uuid, expected_version bigint, new_state jsonb, event_kind text, event_payload jsonb default '{}'::jsonb)
returns bigint language plpgsql security definer set search_path=public as $$
declare next_version bigint;
begin
 if not public.is_match_member(mid) then raise exception 'Not a match member'; end if;
 if event_kind not in ('scores_saved','presses_activated','presses_canceled') then raise exception 'Invalid event'; end if;
 update public.matches set state=new_state,version=version+1,updated_at=now()
 where id=mid and version=expected_version returning version into next_version;
 if next_version is null then raise exception 'Match changed; reload before saving'; end if;
 insert into public.match_events(match_id,actor_id,kind,payload)
 values(mid,auth.uid(),event_kind,event_payload);
 return next_version;
end $$;
revoke all on function public.create_match(jsonb),public.join_match(text),public.save_match_state(uuid,bigint,jsonb,text,jsonb) from public;
grant execute on function public.create_match(jsonb),public.join_match(text),public.save_match_state(uuid,bigint,jsonb,text,jsonb) to authenticated;
-- Add matches and events to the Supabase Realtime publication.
do $$ begin
 alter publication supabase_realtime add table public.matches;
exception when duplicate_object then null; end $$;
do $$ begin
 alter publication supabase_realtime add table public.match_events;
exception when duplicate_object then null; end $$;
