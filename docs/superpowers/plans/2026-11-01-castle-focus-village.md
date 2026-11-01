# Castle and focus-built village implementation

Execute inline using superpowers:executing-plans. Spec: ../specs/2026-11-01-castle-focus-village.md.

- [x] Model/persistence: focus building thresholds, immutable plot state, rank gates, one-time legacy decoration refunds, durable begin/finish/recover operations. Add failing tests, then implement and verify.
- [x] Focus lifecycle: await durable construction at start, connect success to settlement journal, persist defeat/abandon, recover pending after victory journals; preserve retry safety and existing reward rules. Update affected callers/tests and verify.
- [x] UI: Castle upgrade sheet, fixed Castle with 3×3 paged plots, setup preview and result building. Replace obsolete fixed-village tests, verify boundary/interaction/layout cases.
- [x] Independent final review; full tests/analyze/build; update docs; install matching debug APK and smoke-test without modifying user progress for fake battles.

No commit/push requested. Preserve all earlier uncommitted tracking/settings work. Do not award artificial focus time or create test buildings on the user's phone.

Verified: 180 tests passed; flutter analyze clean; debug APK built and installed on Samsung SM-G781N. Real-device village/Castle checked, migration refunded 950 Coin/190 Log while preserving functional levels. Did not create synthetic focus battles on the phone.
