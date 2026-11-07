# 3-Man Round Robin Nassau — implementation specification

Status: design approved; implementation pending.

## Match setup
- Game type: Round Robin Nassau; exactly three distinct players.
- Select course, tees, and one per-person Nassau stake applied to each matchup.
- Admin may create a match without participating.
- On creation generate one parent round-robin event and exactly three linked 1v1 matchups: A/B, A/C, B/C.
- Creation must be atomic: no partially created event or child matches.

## Score storage
- Store one gross hole score per (event, player, hole); do not duplicate across child matchups.
- Master scorecard presents all three players with editable scores until posted, front/back nine mobile layout, autosave.
- Child matchups derive their scores from the master source and must reflect edits immediately.

## Handicap and Nassau logic
- Each head-to-head matchup allocates strokes relative to the lower of its two course handicaps, using course hole stroke indices.
- Reuse existing 1v1 Nassau rules: front nine, back nine, overall 18, independent presses, press eligibility, activation, undo, and mathematically closed bets.
- Press state belongs to each child matchup; no cross-match press effects.

## UI
- Shared master score-entry view with matchup selector for A/B, A/C, B/C.
- Each matchup view shows its own bet status, presses, and net scoring indicators.
- Combined event bet summary aggregates each player's projected/closed per-person financial result across all three matchups.

## Posting
- Finalization must be idempotent and atomic, settling each child matchup exactly once.
- Post each child matchup to both players' head-to-head records and betting history, with no duplicate master-event match record.
- Parent event remains a navigable grouping for history and active match selection.

## Acceptance checks
1. Reject fewer/more than three players or duplicate players.
2. Create exactly three pairings and nine main Nassau bets.
3. Editing one score updates both relevant matchups, never the third unrelated matchup.
4. Each pair has independent strokes and presses.
5. Repeated finalize attempts do not duplicate settlements or records.
6. Existing standard Nassau games continue to behave unchanged.

## Implementation order
1. Inspect existing match setup, database constraints/RLS, match creation and Nassau functions.
2. Add schema/migration and atomic creation flow.
3. Add setup UI and verify creation of three matchups.
4. Build shared scorecard and child views.
5. Implement combined settlement and regression tests.
