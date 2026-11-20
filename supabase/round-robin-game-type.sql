-- Staged only. Preserve existing permitted formats and add the three-player Round Robin.
-- Review live constraint before applying. Do not run against production without approval.
alter table public.matches drop constraint if exists matches_game_type_check;
alter table public.matches add constraint matches_game_type_check check(
 game_type in ('nassau','mega_nassau','skins','quota','hammer','high_low','better_ball','tilt','scotch','nines','round_robin')
);
-- Production activation requires separately reviewed GRANTs for press and finalization RPCs.
