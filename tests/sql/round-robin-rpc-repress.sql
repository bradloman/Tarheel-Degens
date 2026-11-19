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
INSERT INTO public.course_holes(tee_id,hole_number,stroke_index)
 SELECT '55555555-5555-4555-8555-555555555555',h,h FROM generate_series(1,18) h;
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
ROLLBACK;
