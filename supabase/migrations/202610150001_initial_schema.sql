-- Tarheel Degens initial Supabase schema
-- Run in Supabase SQL Editor on a NEW project.
-- Authenticated users only; no anonymous match data access.
create extension if not exists pgcrypto;

create table public.players (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null check (length(trim(display_name)) between 1 and 80),
 handicap_index numeric(5,1) check (handicap_index between -10 and 54),
 created_at timestamptz not null default now()
);

create table public.courses (
 id uuid primary key default gen_random_uuid(),
 name text not null,
 city text,
 region text,
 country text not null default 'USA',
 created_by uuid references public.players(id),
 created_at timestamptz not null default now(),
 unique (name, city, region, country)
);

create table public.course_tees (
 id uuid primary key default gen_random_uuid(),
 course_id uuid not null references public.courses(id) on delete cascade,
 tee_name text not null,
 gender text not null default 'M' check (gender in ('M','F')),
 course_rating numeric(4,1) not null check (course_rating between 40 and 90),
 slope_rating integer not null check (slope_rating between 55 and 155),
 par integer not null check (par between 27 and 90),
 unique(course_id, tee_name, gender)
);

create table public.course_holes (
 tee_id uuid not null references public.course_tees(id) on delete cascade,
 hole_number integer not null check (hole_number between 1 and 18),
 par integer not null check (par between 3 and 6),
 stroke_index integer not null check (stroke_index between 1 and 18),
 primary key(tee_id, hole_number),
 unique(tee_id, stroke_index)
);

create table public.matches (
 id uuid primary key default gen_random_uuid(),
 created_by uuid not null references public.players(id),
 course_id uuid references public.courses(id),
 tee_id uuid references public.course_tees(id),
 game_type text not null check (game_type in ('nassau','mega_nassau','skins','quota','hammer')),
 match_date date not null default current_date,
 status text not null default 'active' check (status in ('active','completed','cancelled')),
 stake numeric(12,2) not null check (stake > 0),
 hole_count integer not null default 18 check (hole_count between 1 and 72),
 notes text,
 created_at timestamptz not null default now(),
 unique(id, game_type)
);

create table public.match_players (
 match_id uuid not null references public.matches(id) on delete cascade,
 player_id uuid not null references public.players(id),
 course_handicap integer not null default 0 check (course_handicap between -30 and 90),
 tee_id uuid references public.course_tees(id),
 joined_at timestamptz not null default now(),
 primary key(match_id, player_id)
);

-- A row is the saved score for one player on one hole.
create table public.hole_scores (
 match_id uuid not null,
 player_id uuid not null,
 hole_number integer not null check (hole_number between 1 and 72),
 gross_strokes integer not null check (gross_strokes between 1 and 30),
 saved_at timestamptz not null default now(),
 saved_by uuid not null references public.players(id),
 primary key(match_id, player_id, hole_number),
 foreign key(match_id, player_id) references public.match_players(match_id, player_id) on delete cascade
);

-- Nassau segments can span any holes, including overlapping mega-Nassau segments.
-- A press is a new bet with parent_bet_id and its own starting hole.
create table public.nassau_bets (
 id uuid primary key default gen_random_uuid(),
 match_id uuid not null references public.matches(id) on delete cascade,
 label text not null,
 start_hole integer not null check (start_hole between 1 and 72),
 end_hole integer not null check (end_hole between 1 and 72),
 stake numeric(12,2) not null check (stake > 0),
 parent_bet_id uuid references public.nassau_bets(id),
 activated_by uuid references public.players(id),
 created_at timestamptz not null default now(),
 check(start_hole <= end_hole),
 unique(id, match_id)
);

create table public.press_events (
 id uuid primary key default gen_random_uuid(),
 match_id uuid not null references public.matches(id) on delete cascade,
 parent_bet_id uuid not null,
 press_bet_id uuid not null unique,
 activated_by uuid not null references public.players(id),
 activated_at timestamptz not null default now(),
 undone_by uuid references public.players(id),
 undone_at timestamptz,
 foreign key(parent_bet_id, match_id) references public.nassau_bets(id, match_id),
 foreign key(press_bet_id, match_id) references public.nassau_bets(id, match_id),
 check ((undone_by is null) = (undone_at is null))
);

create index on public.match_players(player_id);
create index on public.hole_scores(match_id, hole_number);
create index on public.nassau_bets(match_id, start_hole);
create index on public.press_events(match_id, activated_at);

create or replace function public.is_match_member(p_match uuid)
returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.match_players where match_id=p_match and player_id=(select auth.uid()))
$$;

create or replace function public.is_match_owner(p_match uuid)
returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.matches where id=p_match and created_by=(select auth.uid()))
$$;

-- Automatically enroll the match creator, avoiding a membership chicken-and-egg problem.
create or replace function public.enroll_match_creator()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 insert into public.match_players(match_id, player_id) values(new.id,new.created_by);
 return new;
end $$;
create trigger enroll_match_creator after insert on public.matches
for each row execute function public.enroll_match_creator();

-- Enforce score edit cutoff in the database, not merely in the UI.
-- A hole's scores become uneditable after all participants have saved scores for the NEXT hole.
create or replace function public.validate_score_write()
returns trigger language plpgsql security definer set search_path = '' as $$
declare n integer; total integer; submitted integer; match_status text;
begin
 select hole_count,status into n,match_status from public.matches where id=new.match_id;
 if match_status <> 'active' then raise exception 'Match is not active'; end if;
 if new.hole_number > n then raise exception 'Hole exceeds match length'; end if;
 if tg_op = 'UPDATE' then
   if new.match_id <> old.match_id or new.player_id <> old.player_id or new.hole_number <> old.hole_number then
     raise exception 'Score identity cannot be changed';
   end if;
 end if;
 if new.hole_number < n then
   select count(*) into total from public.match_players where match_id=new.match_id;
   select count(*) into submitted from public.hole_scores
    where match_id=new.match_id and hole_number=new.hole_number+1;
   if total > 0 and submitted >= total then raise exception 'Score locked after next hole is saved'; end if;
 end if;
 new.saved_at := now();
 new.saved_by := auth.uid();
 return new;
end $$;
create trigger validate_score before insert or update on public.hole_scores
for each row execute function public.validate_score_write();

-- No direct editing of bets or press events: controlled by functions below.
create or replace function public.activate_press(p_parent uuid, p_label text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare b public.nassau_bets%rowtype; m public.matches%rowtype;
  player_a uuid; player_b uuid; h integer; a integer; c integer;
  diff integer := 0; next_hole integer; press_id uuid;
begin
 select * into b from public.nassau_bets where id=p_parent for update;
 if not found or not public.is_match_member(b.match_id) then raise exception 'Not authorized'; end if;
 select * into m from public.matches where id=b.match_id;
 if m.status <> 'active' or m.game_type not in ('nassau','mega_nassau') then
   raise exception 'Presses require an active Nassau match';
 end if;
 select count(*) into c from public.match_players where match_id=b.match_id;
 if c <> 2 then raise exception 'Press activation currently requires exactly two players'; end if;
 select player_id into player_a from public.match_players where match_id=b.match_id order by player_id limit 1;
 select player_id into player_b from public.match_players where match_id=b.match_id order by player_id offset 1 limit 1;
 -- Evaluate only consecutively completed holes within this bet.
 for h in b.start_hole..b.end_hole loop
   select gross_strokes into a from public.hole_scores where match_id=b.match_id and player_id=player_a and hole_number=h;
   select gross_strokes into c from public.hole_scores where match_id=b.match_id and player_id=player_b and hole_number=h;
   if a is null or c is null then exit; end if;
   -- Net strokes: distribute handicap by stroke index where course data exists.
   -- Fall back to the standard sequential stroke index when course holes are absent.
   select coalesce((select stroke_index from public.course_holes ch
      join public.matches mm on mm.tee_id=ch.tee_id
      where mm.id=b.match_id and ch.hole_number=((h-1)%18)+1), ((h-1)%18)+1)
     into next_hole;
   a := a - (select (course_handicap / 18) +
       case when mod(course_handicap,18) >= next_hole then 1
            when mod(course_handicap,18) <= -next_hole then -1 else 0 end
     from public.match_players where match_id=b.match_id and player_id=player_a);
   c := c - (select (course_handicap / 18) +
       case when mod(course_handicap,18) >= next_hole then 1
            when mod(course_handicap,18) <= -next_hole then -1 else 0 end
     from public.match_players where match_id=b.match_id and player_id=player_b);
   diff := diff + case when a<c then 1 when a>c then -1 else 0 end;
   next_hole := h+1;
 end loop;
 if next_hole is null or next_hole > b.end_hole or abs(diff) < 2 then
   raise exception 'Press not eligible: bet must be at least two down with a next hole';
 end if;
 if exists(select 1 from public.press_events pe where pe.parent_bet_id=p_parent and pe.undone_at is null and exists (select 1 from public.nassau_bets nb where nb.id=pe.press_bet_id and nb.start_hole=next_hole)) then raise exception 'Active press already exists for this bet and hole'; end if;
 if exists(select 1 from public.hole_scores where match_id=b.match_id and hole_number=next_hole) then
   raise exception 'Press must be activated before next-hole scoring begins';
 end if;
 insert into public.nassau_bets(match_id,label,start_hole,end_hole,stake,parent_bet_id,activated_by)
 values(b.match_id,coalesce(nullif(trim(p_label),''),'Press on '||b.label),next_hole,b.end_hole,b.stake,p_parent,auth.uid())
 returning id into press_id;
 insert into public.press_events(match_id,parent_bet_id,press_bet_id,activated_by)
 values(b.match_id,p_parent,press_id,auth.uid());
 return press_id;
end $$;

create or replace function public.undo_press(p_press_bet uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare e public.press_events%rowtype; n integer; total integer;
begin
 select * into e from public.press_events where press_bet_id=p_press_bet for update;
 if not found or not public.is_match_member(e.match_id) then raise exception 'Not authorized'; end if;
 if e.undone_at is not null then raise exception 'Already undone'; end if;
 if exists(select 1 from public.nassau_bets nb join public.press_events pe on pe.press_bet_id=nb.id where nb.parent_bet_id=p_press_bet and pe.undone_at is null) then
   raise exception 'Undo child presses first';
 end if;
 select start_hole into n from public.nassau_bets where id=p_press_bet;
 select count(*) into total from public.match_players where match_id=e.match_id;
 if (select count(*) from public.hole_scores where match_id=e.match_id and hole_number=n) >= total then
   raise exception 'Press locked after both next-hole scores are saved';
 end if;
 update public.press_events set undone_by=auth.uid(),undone_at=now() where id=e.id;
 -- Keep audit event; remove active bet only after removing FK by retaining it with undone marker.
end $$;

-- RLS: all client-facing tables deny access unless explicitly allowed.
alter table public.players enable row level security;
alter table public.courses enable row level security;
alter table public.course_tees enable row level security;
alter table public.course_holes enable row level security;
alter table public.matches enable row level security;
alter table public.match_players enable row level security;
alter table public.hole_scores enable row level security;
alter table public.nassau_bets enable row level security;
alter table public.press_events enable row level security;

create policy players_read on public.players for select to authenticated using
 (id=auth.uid() or exists(select 1 from public.match_players mp where mp.player_id=players.id and public.is_match_member(mp.match_id)));
create policy players_insert on public.players for insert to authenticated with check(id=auth.uid());
create policy players_update on public.players for update to authenticated using(id=auth.uid()) with check(id=auth.uid());

create policy courses_read on public.courses for select to authenticated using(true);
create policy courses_insert on public.courses for insert to authenticated with check(created_by=auth.uid());
create policy courses_update on public.courses for update to authenticated using(created_by=auth.uid()) with check(created_by=auth.uid());
create policy tees_read on public.course_tees for select to authenticated using(true);
create policy holes_read on public.course_holes for select to authenticated using(true);

create policy matches_read on public.matches for select to authenticated using(public.is_match_member(id));
create policy matches_insert on public.matches for insert to authenticated with check(created_by=auth.uid());
create policy matches_update on public.matches for update to authenticated using(public.is_match_owner(id)) with check(public.is_match_owner(id));

create policy members_read on public.match_players for select to authenticated using(public.is_match_member(match_id));
create policy members_insert on public.match_players for insert to authenticated with check(public.is_match_owner(match_id));
create policy members_update on public.match_players for update to authenticated using(public.is_match_owner(match_id)) with check(public.is_match_owner(match_id));

create policy scores_read on public.hole_scores for select to authenticated using(public.is_match_member(match_id));
create policy scores_insert on public.hole_scores for insert to authenticated with check(public.is_match_member(match_id) and saved_by=auth.uid());
create policy scores_update on public.hole_scores for update to authenticated using(public.is_match_member(match_id)) with check(public.is_match_member(match_id) and saved_by=auth.uid());

create policy bets_read on public.nassau_bets for select to authenticated using(public.is_match_member(match_id) and (parent_bet_id is null or not exists(select 1 from public.press_events pe where pe.press_bet_id=nassau_bets.id and pe.undone_at is not null)));
create policy bets_insert on public.nassau_bets for insert to authenticated with check(
 public.is_match_owner(match_id) and parent_bet_id is null and activated_by is null
);
create policy events_read on public.press_events for select to authenticated using(public.is_match_member(match_id));

revoke all on function public.is_match_member(uuid), public.is_match_owner(uuid) from public;
grant execute on function public.is_match_member(uuid), public.is_match_owner(uuid) to authenticated;
revoke all on function public.activate_press(uuid,text), public.undo_press(uuid) from public;
grant execute on function public.activate_press(uuid,text), public.undo_press(uuid) to authenticated;

-- Publish realtime updates only after RLS policies are enabled.
-- Note: a production release needs transactional press and score-save RPCs,
-- verified handicap allocation, and multi-user integration tests.
-- Realtime publications: clients still require authenticated RLS access.
do $$ begin
 alter publication supabase_realtime add table public.hole_scores;
exception when duplicate_object then null; end $$;
do $$ begin
 alter publication supabase_realtime add table public.nassau_bets;
exception when duplicate_object then null; end $$;
do $$ begin
 alter publication supabase_realtime add table public.press_events;
exception when duplicate_object then null; end $$;
