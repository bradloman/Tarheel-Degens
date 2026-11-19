-- Disposable database integration checks. All changes run in a transaction and roll back.
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
DECLARE v_press uuid; v_second uuid; v_count integer;
BEGIN
 v_press:=public.activate_round_robin_press(
 '44444444-4444-4444-8444-444444444444',
 '11111111-1111-4111-8111-111111111111',
 '22222222-2222-4222-8222-222222222222','front',3,NULL);
 IF v_press IS NULL THEN RAISE EXCEPTION 'Press was not created'; END IF;
 BEGIN
  PERFORM public.activate_round_robin_press(
  '44444444-4444-4444-8444-444444444444',
  '11111111-1111-4111-8111-111111111111',
  '22222222-2222-4222-8222-222222222222','front',3,NULL);
  RAISE EXCEPTION 'Duplicate press was accepted';
 EXCEPTION WHEN unique_violation THEN NULL; END;
 BEGIN
  PERFORM public.activate_round_robin_press(
  '44444444-4444-4444-8444-444444444444',
  '11111111-1111-4111-8111-111111111111',
  '33333333-3333-4333-8333-333333333333','front',4,NULL);
  RAISE EXCEPTION 'Invalid start hole was accepted';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='Invalid start hole was accepted' THEN RAISE; END IF;
 END;
 PERFORM public.undo_round_robin_press(v_press);
 SELECT count(*) INTO v_count FROM public.match_round_robin_presses WHERE undone_at IS NULL;
 IF v_count<>0 THEN RAISE EXCEPTION 'Undo did not remove active press'; END IF;
END $$;
ROLLBACK;
