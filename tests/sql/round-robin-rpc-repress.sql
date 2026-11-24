-- Run after the basic RPC integration script in the disposable PostgreSQL fixture.
BEGIN;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
$$ SELECT 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa'::uuid $$;
CREATE OR REPLACE FUNCTION public.is_match_member(uuid) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT true $$;
CREATE OR REPLACE FUNCTION public.is_match_owner(uuid) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT true $$;
INSERT INTO public.players(id) VALUES
 ('11111111-1111-4111-8111-111111111111'),
 ('22222222-2222-4222-8222-222222222222'),
 ('33333333-3333-4333-8333-333333333333');
INSERT INTO public.matches(id,game_type,status,player_count,hole_count,tee_id)
 VALUES ('44444444-4444-4444-8444-444444444444','round_robin','active',3,18,'55555555-5555-4555-8555-555555555555');
INSERT INTO public.match_players(match_id,player_id,course_handicap)
 SELECT '44444444-4444-4444-8444-444444444444',id,0 FROM public.players;
INSERT INTO public.match_hole_strokes(match_id,hole_number,stroke_index)
 SELECT '44444444-4444-4444-8444-444444444444',h,h FROM generate_series(1,18) h;
INSERT INTO public.hole_scores(match_id,player_id,hole_number,gross_strokes)
 SELECT '44444444-4444-4444-8444-444444444444',p.id,h,
 CASE WHEN p.id='11111111-1111-4111-8111-111111111111' THEN 3 ELSE 5 END
 FROM public.players p CROSS JOIN generate_series(1,2) h;
GRANT EXECUTE ON FUNCTION public.activate_round_robin_press(uuid,uuid,uuid,text,integer,uuid) TO authenticated;
DO $$
DECLARE parent_id uuid; child_id uuid; other_id uuid;
BEGIN
 parent_id:=public.activate_round_robin_press(
 '44444444-4444-4444-8444-444444444444',
 '11111111-1111-4111-8111-111111111111',
 '22222222-2222-4222-8222-222222222222','front',3,NULL);
 -- Score holes 3-4; parent press is now down two holes and may be re-pressed.
 INSERT INTO public.hole_scores(match_id,player_id,hole_number,gross_strokes)
 SELECT '44444444-4444-4444-8444-444444444444',p.id,h,
 CASE WHEN p.id='11111111-1111-4111-8111-111111111111' THEN 3 ELSE 5 END
 FROM public.players p CROSS JOIN generate_series(3,4) h;
 child_id:=public.activate_round_robin_press(
 '44444444-4444-4444-8444-444444444444',
 '11111111-1111-4111-8111-111111111111',
 '22222222-2222-4222-8222-222222222222','front',5,parent_id);
 IF NOT EXISTS(SELECT 1 FROM public.match_round_robin_presses WHERE id=child_id AND parent_press_id=parent_id)
 THEN RAISE EXCEPTION 'Child parent link missing'; END IF;
 -- The base Nassau bet can independently be pressed again at hole 5.
 other_id:=public.activate_round_robin_press(
 '44444444-4444-4444-8444-444444444444',
 '11111111-1111-4111-8111-111111111111',
 '22222222-2222-4222-8222-222222222222','front',5,NULL);
 IF other_id=child_id THEN RAISE EXCEPTION 'Independent parent bet was merged'; END IF;
 BEGIN
  PERFORM public.undo_round_robin_press(parent_id);
  RAISE EXCEPTION 'Parent undo incorrectly allowed with active child';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Parent undo incorrectly allowed with active child' THEN RAISE; END IF;
 END;
 PERFORM public.undo_round_robin_press(child_id);
 PERFORM public.undo_round_robin_press(other_id);
 -- Parent cannot be undone: scores were saved on and after its start hole.
 BEGIN
  PERFORM public.undo_round_robin_press(parent_id);
  RAISE EXCEPTION 'Scored parent undo incorrectly allowed';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Scored parent undo incorrectly allowed' THEN RAISE; END IF;
 END;
END $$;

-- Repeat with one registered player and two directory-only participants.
DELETE FROM public.match_round_robin_presses;
INSERT INTO public.guest_players(match_id,id,course_handicap,directory_entry_id)
 SELECT match_id,player_id,course_handicap,gen_random_uuid() FROM public.match_players
 WHERE player_id<>'11111111-1111-4111-8111-111111111111';
INSERT INTO public.guest_hole_scores(match_id,guest_id,hole_number,gross_strokes)
 SELECT match_id,player_id,hole_number,CASE WHEN player_id='22222222-2222-4222-8222-222222222222' THEN 4 ELSE 6 END
 FROM public.hole_scores WHERE player_id<>'11111111-1111-4111-8111-111111111111';
DELETE FROM public.hole_scores WHERE player_id<>'11111111-1111-4111-8111-111111111111';
DELETE FROM public.match_players WHERE player_id<>'11111111-1111-4111-8111-111111111111';
DO $$
DECLARE m uuid:='44444444-4444-4444-8444-444444444444'; a uuid:='11111111-1111-4111-8111-111111111111'; b uuid:='22222222-2222-4222-8222-222222222222'; c uuid:='33333333-3333-4333-8333-333333333333'; p uuid; q uuid; child uuid;
BEGIN
 p:=public.activate_round_robin_press(m,a,b,'overall',5,NULL);
 q:=public.activate_round_robin_press(m,b,c,'overall',5,NULL);
 IF p=q OR p IS NULL OR q IS NULL THEN RAISE EXCEPTION 'Mixed pair isolation failed'; END IF;
 PERFORM public.undo_round_robin_press(q);
 INSERT INTO public.hole_scores VALUES(m,a,5,3),(m,a,6,3);
 INSERT INTO public.guest_hole_scores(match_id,guest_id,hole_number,gross_strokes) VALUES(m,b,5,4),(m,b,6,4),(m,c,5,6),(m,c,6,6);
 child:=public.activate_round_robin_press(m,a,b,'overall',7,p);
 PERFORM public.undo_round_robin_press(child);
 BEGIN
  PERFORM public.undo_round_robin_press(p);
  RAISE EXCEPTION 'Mixed scored press undo incorrectly allowed';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM NOT LIKE 'Press locked:%' THEN RAISE; END IF;
 END;
 BEGIN
  PERFORM public.activate_round_robin_press(m,b,c,'front',7,NULL);
  RAISE EXCEPTION 'Closed mixed bet incorrectly pressed';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM<>'Bet already closed' THEN RAISE; END IF;
 END;
END $;

ROLLBACK;

-- Repeat the same independent press assertions with one registered and two directory players.
-- Run after the basic RPC integration script in the disposable PostgreSQL fixture.
BEGIN;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
$$ SELECT 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa'::uuid $$;
CREATE OR REPLACE FUNCTION public.is_match_member(uuid) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT true $$;
CREATE OR REPLACE FUNCTION public.is_match_owner(uuid) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT true $$;
INSERT INTO public.players(id) VALUES
 ('11111111-1111-4111-8111-111111111111'),
 ('22222222-2222-4222-8222-222222222222'),
 ('33333333-3333-4333-8333-333333333333');
INSERT INTO public.matches(id,game_type,status,player_count,hole_count,tee_id)
 VALUES ('44444444-4444-4444-8444-444444444444','round_robin','active',3,18,'55555555-5555-4555-8555-555555555555');
INSERT INTO public.match_players(match_id,player_id,course_handicap)
 SELECT '44444444-4444-4444-8444-444444444444',id,0 FROM public.players WHERE id='11111111-1111-4111-8111-111111111111';
INSERT INTO public.guest_players(match_id,id,course_handicap) SELECT '44444444-4444-4444-8444-444444444444',id,0 FROM public.players WHERE id<>'11111111-1111-4111-8111-111111111111';
INSERT INTO public.match_hole_strokes(match_id,hole_number,stroke_index)
 SELECT '44444444-4444-4444-8444-444444444444',h,h FROM generate_series(1,18) h;
INSERT INTO public.hole_scores(match_id,player_id,hole_number,gross_strokes)
 SELECT '44444444-4444-4444-8444-444444444444',p.id,h,
 CASE WHEN p.id='11111111-1111-4111-8111-111111111111' THEN 3 ELSE 5 END
 FROM public.players p CROSS JOIN generate_series(1,2) h WHERE p.id='11111111-1111-4111-8111-111111111111';
 INSERT INTO public.guest_hole_scores(match_id,guest_id,hole_number,gross_strokes) SELECT '44444444-4444-4444-8444-444444444444',id,h,5 FROM public.guest_players CROSS JOIN generate_series(1,2) h;
GRANT EXECUTE ON FUNCTION public.activate_round_robin_press(uuid,uuid,uuid,text,integer,uuid) TO authenticated;
DO $$
DECLARE parent_id uuid; child_id uuid; other_id uuid;
BEGIN
 parent_id:=public.activate_round_robin_press(
 '44444444-4444-4444-8444-444444444444',
 '11111111-1111-4111-8111-111111111111',
 '22222222-2222-4222-8222-222222222222','front',3,NULL);
 -- Score holes 3-4; parent press is now down two holes and may be re-pressed.
 INSERT INTO public.hole_scores(match_id,player_id,hole_number,gross_strokes)
 SELECT '44444444-4444-4444-8444-444444444444',p.id,h,
 CASE WHEN p.id='11111111-1111-4111-8111-111111111111' THEN 3 ELSE 5 END
 FROM public.players p CROSS JOIN generate_series(3,4) h WHERE p.id='11111111-1111-4111-8111-111111111111';
 INSERT INTO public.guest_hole_scores(match_id,guest_id,hole_number,gross_strokes) SELECT '44444444-4444-4444-8444-444444444444',id,h,5 FROM public.guest_players CROSS JOIN generate_series(3,4) h;
 child_id:=public.activate_round_robin_press(
 '44444444-4444-4444-8444-444444444444',
 '11111111-1111-4111-8111-111111111111',
 '22222222-2222-4222-8222-222222222222','front',5,parent_id);
 IF NOT EXISTS(SELECT 1 FROM public.match_round_robin_presses WHERE id=child_id AND parent_press_id=parent_id)
 THEN RAISE EXCEPTION 'Child parent link missing'; END IF;
 -- The base Nassau bet can independently be pressed again at hole 5.
 other_id:=public.activate_round_robin_press(
 '44444444-4444-4444-8444-444444444444',
 '11111111-1111-4111-8111-111111111111',
 '22222222-2222-4222-8222-222222222222','front',5,NULL);
 IF other_id=child_id THEN RAISE EXCEPTION 'Independent parent bet was merged'; END IF;
 BEGIN
  PERFORM public.undo_round_robin_press(parent_id);
  RAISE EXCEPTION 'Parent undo incorrectly allowed with active child';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Parent undo incorrectly allowed with active child' THEN RAISE; END IF;
 END;
 PERFORM public.undo_round_robin_press(child_id);
 PERFORM public.undo_round_robin_press(other_id);
 -- Parent cannot be undone: scores were saved on and after its start hole.
 BEGIN
  PERFORM public.undo_round_robin_press(parent_id);
  RAISE EXCEPTION 'Scored parent undo incorrectly allowed';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Scored parent undo incorrectly allowed' THEN RAISE; END IF;
 END;
END $$;
ROLLBACK;
