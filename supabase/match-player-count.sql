-- Tarheel Degens: selected player count per match
alter table public.matches
  add column if not exists player_count integer not null default 2;
alter table public.matches
  drop constraint if exists matches_player_count_check;
alter table public.matches
  add constraint matches_player_count_check check (player_count between 2 and 4);
comment on column public.matches.player_count is 'Target roster size: 2, 3, or 4 players. Existing matches default to two.';
