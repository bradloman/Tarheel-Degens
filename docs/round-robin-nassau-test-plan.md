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
