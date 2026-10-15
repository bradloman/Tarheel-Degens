# Multiplayer setup — Tarheel Degens

The existing `scorecard-v2.html` remains the standalone local-only test site.

## Supabase configuration

1. Create a free project at https://supabase.com/dashboard.
2. In SQL Editor, run `supabase/schema.sql`.
3. In Project Settings → API, copy the **Project URL** and **publishable/anon key**. These are intended for browser use; **never** publish a service-role or secret key.
4. Set up Auth (email sign-in or another supported method) before enabling the shared match UI.
5. Use Realtime to subscribe to `matches` and `match_events` for a joined match.
6. Build the UI for Create Match / Join Match / match code, then wire Save Scores, multi-select Press, and Undo Press to authenticated server-side RPCs.

## Important implementation caveat

`save_match_state` is only a **foundation**. It provides membership checks and optimistic concurrency, but it does **not** yet validate golf scoring, enforce permanent press locks, or merge concurrent score edits. Do not wire production betting to this generic RPC. Replace it with narrow score-save, press-activation and press-cancellation transactions that validate locks on the server. The local scorecard must remain separate until that work is complete.

## Agreed behavior

- Any match member can score either player.
- All members see saved scores and bets in real time.
- A press can be selected from any eligible bet, including a press; activate multiple at once.
- Activation and cancellation broadcast to match members, without requiring approval.
- A press permanently locks when both gross scores on its starting hole have been saved.
- A score can be corrected until both players' following-hole scores have been saved.
- Never reopen a previously locked press after a score correction.
