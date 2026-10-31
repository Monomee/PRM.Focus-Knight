# Review fixes implementation plan

**Goal:** Fix the failed review cases 1, 5, 7 and 8 without changing game rules or adding dependencies.

**Architecture:** Keep ChangeNotifier and SharedPreferences. Wallet writes share one serialized path; history readers use the committed snapshot with legacy fallback. Usage duration includes the current foreground interval and excludes screen-off time.

**Spec:** `docs/reviews/2026-10-31-camtu-verification.md` and the user's instruction to fix failures autonomously.

## Tasks

- [x] Reproduce the six existing failing tests; add failure/retry and usage duration tests before implementation.
- [x] Fix wallet balance persistence and concurrent spending/deposits; preserve applied settlement IDs and building progress.
- [x] Journal new payouts before processing older ones; keep retries safe on storage failures. Read history from the committed snapshot.
- [x] Diagnose continuous YouTube usage, count the open interval without double-counting aggregate updates, and test screen locking, midnight and permission changes.
- [x] Fix golden-hour selection before rounding and initialize the settings baseline before listeners.
- [x] Run all tests, static analysis and debug APK build; verify continuous usage crossing its limit on USB Android; restore test settings and update PROJECT_REVIEW.md.

## Checks

Use the existing regression tests for wallet spending, journal failures, snapshot recovery, golden-hour rounding and async settings loading. Add tests at the storage/plugin boundaries for failed writes and ongoing usage. Preserve legacy preferences, exactly-once payouts, screen-lock behavior and live draft edits. Do not change the timer or session timestamp rules (review 9 and 10).

Final verification: 132 tests passed, analyze clean, debug APK built/installed, continuous-use Android test passed. Final independent review found one important cache-recovery gap; wallet/history write-plus-read failure tests reproduced it and passed after adding the shared recovery guard. No dependency was added. Existing widget build tests now wait for successful persistence before asserting UI changes. Changes remain in the requested working branch, without commit or push.
