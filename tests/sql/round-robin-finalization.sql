-- End-to-end disposable test: 3 pairings, 9 base bets, one independent press, zero-sum, idempotency.
BEGIN;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
$$ SELECT 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa'::uuid $$;
INSERT INTO public.players(id) VALUES
 ('11111111-1111-4111-8111-111111111111'),
 ('22222222-2222-4222-8222-222222222222'),
 ('33333333-3333-4333-8333-333333333333');
INSERT INTO public.matches(id,game_type,status,player_count,hole_count,tee_id,created_by,stake)
 VALUES ('44444444-4444-4444-8444-444444444444','round_robin','active',3,18,
 '55555555-5555-4555-8555-555555555555','aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa',5);
INSERT INTO public.match_players(match_id,player_id,course_handicap)
 VALUES
 ('44444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111',0),
 ('44444444-4444-4444-8444-444444444444','22222222-2222-4222-8222-222222222222',1),
 ('44444444-4444-4444-8444-444444444444','33333333-3333-4333-8333-333333333333',2);
INSERT INTO public.match_hole_strokes(match_id,hole_number,stroke_index)
 SELECT '44444444-4444-4444-8444-444444444444',h,h FROM generate_series(1,18) h;
INSERT INTO public.hole_scores(match_id,player_id,hole_number,gross_strokes)
 SELECT '44444444-4444-4444-8444-444444444444',p.player_id,h,
 CASE WHEN p.player_id='11111111-1111-4111-8111-111111111111' THEN 3
 WHEN p.player_id='22222222-2222-4222-8222-222222222222' THEN 4 ELSE 5 END
 FROM public.match_players p CROSS JOIN generate_series(1,18) h;
INSERT INTO public.match_round_robin_presses(match_id,player_a,player_b,segment,start_hole,created_by)
 VALUES('44444444-4444-4444-8444-444444444444',
 '11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222',
 'overall',3,'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa');
DO $
DECLARE n integer; total bigint; a bigint; b bigint; c bigint;
BEGIN
 IF public.finalize_round_robin_match('44444444-4444-4444-8444-444444444444')<>'completed' THEN RAISE EXCEPTION 'Finalization failed'; END IF;
 SELECT count(*) INTO n FROM public.round_robin_bet_results;
 IF n<>10 THEN RAISE EXCEPTION 'Expected 10 bets, got %',n; END IF;
 SELECT coalesce(sum(net_cents),0) INTO total FROM public.round_robin_player_results;
 IF total<>0 THEN RAISE EXCEPTION 'Not zero-sum'; END IF;
 SELECT net_cents INTO a FROM public.round_robin_player_results WHERE player_id='11111111-1111-4111-8111-111111111111';
 SELECT net_cents INTO b FROM public.round_robin_player_results WHERE player_id='22222222-2222-4222-8222-222222222222';
 SELECT net_cents INTO c FROM public.round_robin_player_results WHERE player_id='33333333-3333-4333-8333-333333333333';
 IF a IS DISTINCT FROM 3500 OR b IS DISTINCT FROM -500 OR c IS DISTINCT FROM -3000 THEN RAISE EXCEPTION 'Unexpected totals: %,%,%',a,b,c; END IF;
 PERFORM public.finalize_round_robin_match('44444444-4444-4444-8444-444444444444');
 SELECT count(*) INTO n FROM public.round_robin_bet_results;
 IF n<>10 THEN RAISE EXCEPTION 'Posting not idempotent'; END IF;
END $$;
ROLLBACK;

-- Mixed roster: 1 directory-only players.
-- End-to-end disposable test: 3 pairings, 9 base bets, one independent press, zero-sum, idempotency.
BEGIN;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
$$ SELECT 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa'::uuid $$;
INSERT INTO public.players(id) VALUES
 ('11111111-1111-4111-8111-111111111111'),
 ('22222222-2222-4222-8222-222222222222'),
 ('33333333-3333-4333-8333-333333333333');
INSERT INTO public.matches(id,game_type,status,player_count,hole_count,tee_id,created_by,stake)
 VALUES ('44444444-4444-4444-8444-444444444444','round_robin','active',3,18,
 '55555555-5555-4555-8555-555555555555','aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa',5);
INSERT INTO public.match_players(match_id,player_id,course_handicap)
 VALUES
 ('44444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111',0),
 ('44444444-4444-4444-8444-444444444444','22222222-2222-4222-8222-222222222222',1),
 ('44444444-4444-4444-8444-444444444444','33333333-3333-4333-8333-333333333333',2);
DELETE FROM public.match_players WHERE player_id IN ('33333333-3333-4333-8333-333333333333');
INSERT INTO public.guest_players(match_id,id,course_handicap,directory_entry_id) VALUES
 ('44444444-4444-4444-8444-444444444444','33333333-3333-4333-8333-333333333333',2,gen_random_uuid());
INSERT INTO public.guest_hole_scores(match_id,guest_id,hole_number,gross_strokes)
 SELECT '44444444-4444-4444-8444-444444444444',g.id,h,3+g.course_handicap FROM public.guest_players g CROSS JOIN generate_series(1,18) h;
INSERT INTO public.match_hole_strokes(match_id,hole_number,stroke_index)
 SELECT '44444444-4444-4444-8444-444444444444',h,h FROM generate_series(1,18) h;
INSERT INTO public.hole_scores(match_id,player_id,hole_number,gross_strokes)
 SELECT '44444444-4444-4444-8444-444444444444',p.player_id,h,
 CASE WHEN p.player_id='11111111-1111-4111-8111-111111111111' THEN 3
 WHEN p.player_id='22222222-2222-4222-8222-222222222222' THEN 4 ELSE 5 END
 FROM public.match_players p CROSS JOIN generate_series(1,18) h;
INSERT INTO public.match_round_robin_presses(match_id,player_a,player_b,segment,start_hole,created_by)
 VALUES('44444444-4444-4444-8444-444444444444',
 '11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222',
 'overall',3,'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa');
DO $
DECLARE n integer; total bigint; a bigint; b bigint; c bigint;
BEGIN
 IF public.finalize_round_robin_match('44444444-4444-4444-8444-444444444444')<>'completed' THEN RAISE EXCEPTION 'Finalization failed'; END IF;
 SELECT count(*) INTO n FROM public.round_robin_bet_results;
 IF n<>10 THEN RAISE EXCEPTION 'Expected 10 bets, got %',n; END IF;
 SELECT coalesce(sum(net_cents),0) INTO total FROM public.round_robin_player_results;
 IF total<>0 THEN RAISE EXCEPTION 'Not zero-sum'; END IF;
 SELECT net_cents INTO a FROM public.round_robin_player_results WHERE player_id='11111111-1111-4111-8111-111111111111';
 SELECT net_cents INTO b FROM public.round_robin_player_results WHERE player_id='22222222-2222-4222-8222-222222222222';
 SELECT net_cents INTO c FROM public.round_robin_player_results WHERE player_id='33333333-3333-4333-8333-333333333333';
 IF a IS DISTINCT FROM 3500 OR b IS DISTINCT FROM -500 OR c IS DISTINCT FROM -3000 THEN RAISE EXCEPTION 'Unexpected totals: %,%,%',a,b,c; END IF;
 PERFORM public.finalize_round_robin_match('44444444-4444-4444-8444-444444444444');
 SELECT count(*) INTO n FROM public.round_robin_bet_results;
 IF n<>10 THEN RAISE EXCEPTION 'Posting not idempotent'; END IF;
END $$;
ROLLBACK;


-- Mixed roster: 2 directory-only players.
-- End-to-end disposable test: 3 pairings, 9 base bets, one independent press, zero-sum, idempotency.
BEGIN;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
$$ SELECT 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa'::uuid $$;
INSERT INTO public.players(id) VALUES
 ('11111111-1111-4111-8111-111111111111'),
 ('22222222-2222-4222-8222-222222222222'),
 ('33333333-3333-4333-8333-333333333333');
INSERT INTO public.matches(id,game_type,status,player_count,hole_count,tee_id,created_by,stake)
 VALUES ('44444444-4444-4444-8444-444444444444','round_robin','active',3,18,
 '55555555-5555-4555-8555-555555555555','aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa',5);
INSERT INTO public.match_players(match_id,player_id,course_handicap)
 VALUES
 ('44444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111',0),
 ('44444444-4444-4444-8444-444444444444','22222222-2222-4222-8222-222222222222',1),
 ('44444444-4444-4444-8444-444444444444','33333333-3333-4333-8333-333333333333',2);
DELETE FROM public.match_players WHERE player_id IN ('22222222-2222-4222-8222-222222222222','33333333-3333-4333-8333-333333333333');
INSERT INTO public.guest_players(match_id,id,course_handicap,directory_entry_id) VALUES
 ('44444444-4444-4444-8444-444444444444','22222222-2222-4222-8222-222222222222',1,gen_random_uuid()),
 ('44444444-4444-4444-8444-444444444444','33333333-3333-4333-8333-333333333333',2,gen_random_uuid());
INSERT INTO public.guest_hole_scores(match_id,guest_id,hole_number,gross_strokes)
 SELECT '44444444-4444-4444-8444-444444444444',g.id,h,3+g.course_handicap FROM public.guest_players g CROSS JOIN generate_series(1,18) h;
INSERT INTO public.match_hole_strokes(match_id,hole_number,stroke_index)
 SELECT '44444444-4444-4444-8444-444444444444',h,h FROM generate_series(1,18) h;
INSERT INTO public.hole_scores(match_id,player_id,hole_number,gross_strokes)
 SELECT '44444444-4444-4444-8444-444444444444',p.player_id,h,
 CASE WHEN p.player_id='11111111-1111-4111-8111-111111111111' THEN 3
 WHEN p.player_id='22222222-2222-4222-8222-222222222222' THEN 4 ELSE 5 END
 FROM public.match_players p CROSS JOIN generate_series(1,18) h;
INSERT INTO public.match_round_robin_presses(match_id,player_a,player_b,segment,start_hole,created_by)
 VALUES('44444444-4444-4444-8444-444444444444',
 '11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222',
 'overall',3,'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa');
DO $
DECLARE n integer; total bigint; a bigint; b bigint; c bigint;
BEGIN
 IF public.finalize_round_robin_match('44444444-4444-4444-8444-444444444444')<>'completed' THEN RAISE EXCEPTION 'Finalization failed'; END IF;
 SELECT count(*) INTO n FROM public.round_robin_bet_results;
 IF n<>10 THEN RAISE EXCEPTION 'Expected 10 bets, got %',n; END IF;
 SELECT coalesce(sum(net_cents),0) INTO total FROM public.round_robin_player_results;
 IF total<>0 THEN RAISE EXCEPTION 'Not zero-sum'; END IF;
 SELECT net_cents INTO a FROM public.round_robin_player_results WHERE player_id='11111111-1111-4111-8111-111111111111';
 SELECT net_cents INTO b FROM public.round_robin_player_results WHERE player_id='22222222-2222-4222-8222-222222222222';
 SELECT net_cents INTO c FROM public.round_robin_player_results WHERE player_id='33333333-3333-4333-8333-333333333333';
 IF a IS DISTINCT FROM 3500 OR b IS DISTINCT FROM -500 OR c IS DISTINCT FROM -3000 THEN RAISE EXCEPTION 'Unexpected totals: %,%,%',a,b,c; END IF;
 PERFORM public.finalize_round_robin_match('44444444-4444-4444-8444-444444444444');
 SELECT count(*) INTO n FROM public.round_robin_bet_results;
 IF n<>10 THEN RAISE EXCEPTION 'Posting not idempotent'; END IF;
END $$;
ROLLBACK;


-- Mixed roster: 3 directory-only players.
-- End-to-end disposable test: 3 pairings, 9 base bets, one independent press, zero-sum, idempotency.
BEGIN;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
$$ SELECT 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa'::uuid $$;
INSERT INTO public.players(id) VALUES
 ('11111111-1111-4111-8111-111111111111'),
 ('22222222-2222-4222-8222-222222222222'),
 ('33333333-3333-4333-8333-333333333333');
INSERT INTO public.matches(id,game_type,status,player_count,hole_count,tee_id,created_by,stake)
 VALUES ('44444444-4444-4444-8444-444444444444','round_robin','active',3,18,
 '55555555-5555-4555-8555-555555555555','aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa',5);
INSERT INTO public.match_players(match_id,player_id,course_handicap)
 VALUES
 ('44444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111',0),
 ('44444444-4444-4444-8444-444444444444','22222222-2222-4222-8222-222222222222',1),
 ('44444444-4444-4444-8444-444444444444','33333333-3333-4333-8333-333333333333',2);
DELETE FROM public.match_players WHERE player_id IN ('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','33333333-3333-4333-8333-333333333333');
INSERT INTO public.guest_players(match_id,id,course_handicap,directory_entry_id) VALUES
 ('44444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111',0,gen_random_uuid()),
 ('44444444-4444-4444-8444-444444444444','22222222-2222-4222-8222-222222222222',1,gen_random_uuid()),
 ('44444444-4444-4444-8444-444444444444','33333333-3333-4333-8333-333333333333',2,gen_random_uuid());
INSERT INTO public.guest_hole_scores(match_id,guest_id,hole_number,gross_strokes)
 SELECT '44444444-4444-4444-8444-444444444444',g.id,h,3+g.course_handicap FROM public.guest_players g CROSS JOIN generate_series(1,18) h;
INSERT INTO public.match_hole_strokes(match_id,hole_number,stroke_index)
 SELECT '44444444-4444-4444-8444-444444444444',h,h FROM generate_series(1,18) h;
INSERT INTO public.hole_scores(match_id,player_id,hole_number,gross_strokes)
 SELECT '44444444-4444-4444-8444-444444444444',p.player_id,h,
 CASE WHEN p.player_id='11111111-1111-4111-8111-111111111111' THEN 3
 WHEN p.player_id='22222222-2222-4222-8222-222222222222' THEN 4 ELSE 5 END
 FROM public.match_players p CROSS JOIN generate_series(1,18) h;
INSERT INTO public.match_round_robin_presses(match_id,player_a,player_b,segment,start_hole,created_by)
 VALUES('44444444-4444-4444-8444-444444444444',
 '11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222',
 'overall',3,'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa');
DO $
DECLARE n integer; total bigint; a bigint; b bigint; c bigint;
BEGIN
 IF public.finalize_round_robin_match('44444444-4444-4444-8444-444444444444')<>'completed' THEN RAISE EXCEPTION 'Finalization failed'; END IF;
 SELECT count(*) INTO n FROM public.round_robin_bet_results;
 IF n<>10 THEN RAISE EXCEPTION 'Expected 10 bets, got %',n; END IF;
 SELECT coalesce(sum(net_cents),0) INTO total FROM public.round_robin_player_results;
 IF total<>0 THEN RAISE EXCEPTION 'Not zero-sum'; END IF;
 SELECT net_cents INTO a FROM public.round_robin_player_results WHERE player_id='11111111-1111-4111-8111-111111111111';
 SELECT net_cents INTO b FROM public.round_robin_player_results WHERE player_id='22222222-2222-4222-8222-222222222222';
 SELECT net_cents INTO c FROM public.round_robin_player_results WHERE player_id='33333333-3333-4333-8333-333333333333';
 IF a IS DISTINCT FROM 3500 OR b IS DISTINCT FROM -500 OR c IS DISTINCT FROM -3000 THEN RAISE EXCEPTION 'Unexpected totals: %,%,%',a,b,c; END IF;
 PERFORM public.finalize_round_robin_match('44444444-4444-4444-8444-444444444444');
 SELECT count(*) INTO n FROM public.round_robin_bet_results;
 IF n<>10 THEN RAISE EXCEPTION 'Posting not idempotent'; END IF;
END $$;
ROLLBACK;

-- Full mixed-roster lifecycle: activate a real press, then post, not a directly inserted press.
BEGIN;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa'::uuid $$;
CREATE OR REPLACE FUNCTION public.is_match_owner(uuid) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT true $$;
CREATE OR REPLACE FUNCTION public.is_match_member(uuid) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT false $$;
INSERT INTO public.players(id) VALUES ('11111111-1111-4111-8111-111111111111');
INSERT INTO public.matches(id,game_type,status,player_count,hole_count,created_by,stake) VALUES ('44444444-4444-4444-8444-444444444444','round_robin','active',3,18,'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa',5);
INSERT INTO public.match_players(match_id,player_id,course_handicap) VALUES ('44444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111',0);
INSERT INTO public.guest_players(match_id,id,course_handicap,directory_entry_id) VALUES ('44444444-4444-4444-8444-444444444444','22222222-2222-4222-8222-222222222222',1,gen_random_uuid()),('44444444-4444-4444-8444-444444444444','33333333-3333-4333-8333-333333333333',2,gen_random_uuid());
INSERT INTO public.match_hole_strokes SELECT '44444444-4444-4444-8444-444444444444',h,h FROM generate_series(1,18) h;
DO $$
DECLARE m uuid:='44444444-4444-4444-8444-444444444444'; a uuid:='11111111-1111-4111-8111-111111111111'; b uuid:='22222222-2222-4222-8222-222222222222'; c uuid:='33333333-3333-4333-8333-333333333333'; p uuid;
BEGIN
 INSERT INTO public.hole_scores SELECT m,a,h,3 FROM generate_series(1,3) h;
 INSERT INTO public.guest_hole_scores SELECT m,b,h,4 FROM generate_series(1,3) h;
 INSERT INTO public.guest_hole_scores SELECT m,c,h,5 FROM generate_series(1,3) h;
 p:=public.activate_round_robin_press(m,a,b,'overall',4,NULL);
 INSERT INTO public.hole_scores SELECT m,a,h,3 FROM generate_series(4,18) h;
 INSERT INTO public.guest_hole_scores SELECT m,b,h,4 FROM generate_series(4,18) h;
 INSERT INTO public.guest_hole_scores SELECT m,c,h,5 FROM generate_series(4,18) h;
 IF public.finalize_round_robin_match(m)<>'completed' THEN RAISE EXCEPTION 'Lifecycle posting failed'; END IF;
 IF (SELECT count(*) FROM public.round_robin_bet_results WHERE match_id=m)<>10 THEN RAISE EXCEPTION 'Lifecycle bet count'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.round_robin_bet_results WHERE match_id=m AND press_id=p AND amount_a_cents=500) THEN RAISE EXCEPTION 'Activated press not settled'; END IF;
 IF (SELECT net_cents FROM public.round_robin_player_results WHERE match_id=m AND player_id=a) IS DISTINCT FROM 3500 OR (SELECT net_cents FROM public.round_robin_player_results WHERE match_id=m AND player_id=b) IS DISTINCT FROM -500 OR (SELECT net_cents FROM public.round_robin_player_results WHERE match_id=m AND player_id=c) IS DISTINCT FROM -3000 THEN RAISE EXCEPTION 'Lifecycle payout mismatch'; END IF;
END $$;
ROLLBACK;
