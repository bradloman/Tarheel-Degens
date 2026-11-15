# Round Robin Nassau — implementation plan

Status: **scoring helpers and schema draft only** on feature/round-robin-nassau-v2. Not playable or deployed.

## Data model
Use one round-robin group with three *ordinary* singles Nassau matches. Each
pair retains independent Front, Back, Overall bets, presses, and settlement.
The group supplies the shared score-entry identity. Do not add a fourth match
or count the shared group as another match in player records.

## Match creation (next)
Create an authenticated transactional RPC that accepts exactly three unique
registered/directory player identifiers, course, tees, date, and per-bet stake.
It must validate access and roster membership, create one group and three
18-hole Nassau matches, attach the corresponding two participants to each,
and insert exactly three group-match links. Roll back the entire transaction
if any step fails. Do not rely on three independent browser inserts.

## Shared scoring
Show one score-entry grid for the three players. On save, persist each
player's gross score to both of their linked Nassau matches in a single
authorized transaction. Maintain one course handicap per player and apply
strokes off the minimum course handicap across all three, not each pair's
minimum. Recompute each pair's Nassau status and presses independently.
Keep scores editable until posted.

## Posting
Prevent posting a partial group. Finalize all three linked matches
transactionally, ensuring each pairing contributes one singles result to
each player's records and settlements, without duplicate rounds in scoring
statistics. Verify authorization and idempotency.

## Deployment gate
Run the JS scoring tests, migration in a staging Supabase project, RLS tests
for participants and non-participant admins, creation rollback tests,
score edit/press tests, and settlement reconciliation before exposing
Round Robin in the live Match Setup dropdown.
