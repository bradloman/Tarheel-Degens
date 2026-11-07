# Round Robin Nassau staging test plan

Status: NOT RUN. Production database unchanged.

1. Apply draft schema and RPC to staging only.
2. Verify RLS and deny direct pairing inserts by authenticated clients.
3. Verify exactly three eligible registered players create one parent, three Nassau children and nine main bets.
4. Verify duplicate, missing, inaccessible players, invalid tee/course, and nonpositive stake fail atomically.
5. Confirm existing Nassau bet labels and press conventions match generated rows.
6. Confirm child score readers use parent hole scores without duplicate score rows.
7. Test pair-specific course handicaps, independent presses, settlement and idempotent posting.
8. Extend to directory/guest players before exposing Match Setup option.
9. Enable RPC for authenticated only after all checks pass.

## Read-only preflight results — 2026-11-06
- PASS: 44 course tees reference existing courses.
- PASS: existing Nassau bet table exists.
- EXPECTED: new pairing table and creation RPC do not exist in production; drafts have not been deployed.
- BLOCKER: only 1 registered player is available, versus 11 directory entries. Registered-only creation cannot support a typical three-person group.
- INVESTIGATE: zero main rows in legacy nassau_bets; determine the active Nassau representation before generating bet rows.
- NOT TESTED: transactional creation, RLS writes, scoring, presses, settlements.
- Decision: do not deploy or enable creation RPC yet. First redesign parent-child participant mapping for directory entries/guest players, then test on staging.
