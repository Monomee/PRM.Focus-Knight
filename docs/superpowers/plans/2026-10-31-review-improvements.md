# Review 9–13 implementation plan

**Goal:** Complete review items 9, 10, 12 and 13; leave manual Android acceptance testing (11) to the owner.

**Spec:** `PROJECT_REVIEW.md`, sections 9–13, and the owner's request to implement them in this project.

**Architecture:** Keep ChangeNotifier, Timer and SharedPreferences. Timer callbacks refresh deadlines rather than count seconds. Completed sessions carry actual focus intervals (excluding pauses) through escrow and the settlement journal. Split history at local hour/day boundaries; count each session on its completion date. Legacy journals retain their existing fallback because their timestamps are unknown. Release builds require owner-provided signing credentials outside Git; debug builds remain usable.

**Constraints:** No new dependency, no game recovery after process death, no changes to reward rules, no destructive device actions, no commit/publish. Work in the existing project as requested.

## Tasks

- [x] Reproduce delayed timer callbacks and add deadline tests for focus, rest, pauses, fractional seconds and catch-up over multiple phases.
- [x] Replace callback decrements with deadlines, refresh on foreground resume and before background distraction checks.
- [x] Add interval history tests for crossing hours/midnight, paused gaps, delayed payout, storage retry and legacy journals; preserve exactly-once rewards.
- [x] Carry immutable session intervals through controller and settlement, distribute seconds into real local dates/hours, preserve legacy preferences.
- [x] Configure release signing from ignored `android/key.properties`, provide an example and setup instructions, reject missing release credentials without falling back to debug signing.
- [x] Remove unused Cupertino dependency and placeholder test; resolve lockfile without unrelated upgrades.
- [x] Run full tests, analyzer, debug APK build and signing validation; install/launch over ADB without clearing phone data. Update the review with measured results and remaining owner checks.

## Review focus

- Delayed callbacks must advance all elapsed phases exactly once, including an automatic pause timeout.
- Pauses exclude actual time, preserve fractions and cannot extend a battle after expiration.
- Multi-hour and midnight intervals keep exact integer totals and never include paused time.
- Retry after a durable history write must not duplicate seconds or shift dates; old journals still resume.
- Missing or invalid release credentials must fail release builds, while debug builds still succeed.

## Progress

Initial inspection: clean worktree; Samsung SM-G781N connected via ADB. Flutter 3.47.5 / Dart 3.13.4. Existing timer decrements on every callback; history assigns all seconds to payout time. Existing signing uses debug credentials.

Verification: baseline 132 tests; final 146 passed (15 regression tests added, 1 placeholder removed), analyzer clean, final debug APK built and installed with data-preserving `adb install -r`. ADB launch returned Status: ok and resumed Activity; no fatal/Flutter errors in the inspected process log window. `git diff --check` passed.

Independent review: `review_improvements` found stale skip and abandon actions at elapsed deadlines. Both reproduced RED, fixed, and covered by the green full suite. A further RED→GREEN skip regression protects a later rest from a stale skip action.

Signing verification: AGP does not create validateSigningRelease when all signing fields are absent. The missing-credentials check therefore belongs on preReleaseBuild; this task was observed to fail with the intended setup message. Debug still builds without credentials. No production key was generated; actual signed release validation remains with the owner.

Remaining owner work: Android acceptance section 11, including screen-off/battery saver and first-time permission scenarios, and supplying/backing up release credentials. Existing plugin Kotlin/SDK XML build warnings remain; no dependency upgrades were requested. No commits or publication.
