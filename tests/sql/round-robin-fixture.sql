-- Minimal disposable PostgreSQL schema to compile the staged Round Robin press migration.
-- This is NOT a production schema or an authorization integration test.
create schema if not exists auth;
create function auth.uid() returns uuid language sql stable as $$ select null::uuid $$;
create table public.players(id uuid primary key);
create table public.matches(
 id uuid primary key,game_type text,status text,player_count integer,hole_count integer,tee_id uuid,created_by uuid,stake numeric
);
create table public.match_players(match_id uuid,player_id uuid,course_handicap integer);
create table public.hole_scores(match_id uuid,player_id uuid,hole_number integer,gross_strokes integer);
create table public.guest_hole_scores(match_id uuid,guest_id uuid,hole_number integer,gross_strokes integer);
create table public.course_holes(tee_id uuid,hole_number integer,stroke_index integer);
create function public.is_match_member(uuid) returns boolean language sql stable as $$select false$$;
create function public.is_match_owner(uuid) returns boolean language sql stable as $$select false$$;
do $$begin
 if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
end$$;

create table public.guest_players(match_id uuid,id uuid,course_handicap integer,directory_entry_id uuid);
create table public.match_hole_strokes(match_id uuid,hole_number integer,stroke_index integer);
