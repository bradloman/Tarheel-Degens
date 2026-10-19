# High/Low match implementation specification

Status: Rules approved; not enabled in match setup until database and scoring integration are complete.

## Format
- Four players, two teams of two, net scoring using the existing course-handicap and stroke-index rules.
- Per hole, compare the lower net score from each team (Low) and the higher net score from each team (High).
- Award one point for each comparison won; tied comparisons award zero points to either team.
- Both points contribute to one combined match score. No separate High and Low wagers.
- The team ahead on points at the end of a bet wins; equal points means a push.

## Stakes
- The configured stake is per player per bet, as with team Nassau.
- A $10 winning bet pays +$10 to each winner and -$10 to each loser; total transfer $20.
- Every press is a separate bet at the same per-person stake.

## Presses
- Press eligibility starts when a team trails by at least four points in an active bet.
- The press starts on the next hole, never retroactively.
- A press can itself be re-pressed after a four-point deficit.
- Press selection is explicit, with confirmation and visibility to all match participants.
- Undo is allowed until scores for the press's starting hole have been saved, following the existing Nassau interaction.

## Integration checklist
1. Inspect and migrate Supabase game_type validation, match and press schemas, RLS and RPCs; do not reuse Nassau's two-point press threshold.
2. Add High/Low to match setup, require exactly four players and valid two-by-two team assignments.
3. Reuse net-score calculation and existing score entry and save behavior.
4. Display Low/High point results, combined score, match and press statuses.
5. Calculate independent press settlement and per-player ledger entries, including ties.
6. Extend completed match records, yearly stats, game-type stats, and player betting histories.
7. Test missing scores, tied comparisons, presses, re-presses, undo windows, and 9/18-hole matches.

Existing Nassau and Quota flows must remain unchanged.
