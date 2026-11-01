# Daily-limit Strict Mode Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an optional full-screen blocker when a social app reaches its daily limit.

**Architecture:** Reuse the existing tracker, preferences, overlay service and overlay isolate. Daily-limit monitoring remains outside battles; the battle guard stays unchanged.

**Tech Stack:** Flutter, SharedPreferences, usage_stats, flutter_overlay_window.

**Spec:** ../specs/2026-11-01-daily-limit-strict-mode-design.md (approved by user).

## Global Constraints

- Default off; persist selection; no added dependencies.
- Keep battle overlays, penalties, release signing and package ID unchanged.
- No device uninstall or replacement during this task.

## Review Focus

- Permission denial: retain notifications and explain missing permission.
- Pending overlay opens must not outlive a close/resume.
- Reused overlay engine must switch between limit and battle content.
- Leaving apps/locking screen/changing day must remove the daily blocker.
- Preference write failure must not claim a saved setting.

### Task 1: Persist setting and expose permission-aware switch

Files: ScreenTimeTracker, SettingsScreen, test/daily_limit_test.dart, test/settings_screen_test.dart.

- [x] Recover existing tests for default off, persisted on/off, save failure and switch/permission behavior.
- [x] Verify the recovered `strictModeEnabled`, persistence and permission-aware settings switch.
- [x] Run focused tests: green. Original red runs belonged to the interrupted session and were not repeated by deleting its implementation.

### Task 2: Daily overlay and monitoring

Files: main.dart, OverlayService, BlockerOverlayWidget, MainActivity.kt, test/blocker_overlay_test.dart, test/daily_limit_overlay_test.dart.

- [x] Recover tests for strict on/off notifications, locking, increased limits, denied permission and mode changes.
- [x] Add regressions for permission-result overwrite and native activation after a close; observe both fail before fixing.
- [x] Recover daily-limit state/UI and outside-battle monitoring with ordered operations and cancellation.
- [x] Serialize permission requests and defer permission checks while a request is pending.
- [x] Stop the existing overlay service through MainActivity, including pending starts and inactive services.
- [x] Run focused tests: green.
- [ ] Device acceptance of live overlay across midnight and OEM-specific lifecycle timing. Pure usage-duration midnight handling has existing test coverage.

### Task 3: Verification and documentation

- [x] Recover README with strict mode, permissions and process-lifetime limitation.
- [x] Format changed Dart files; `flutter test --no-pub`: all tests passed; `flutter analyze --no-pub`: no issues.
- [x] `flutter build apk --release --no-pub`: passed (55,008,558 bytes).
- [x] `apksigner verify --verbose`: verifies, v2 signature, one signer. `git diff --check`: passed.
- [x] Independent review identified the delayed-native-start race, fixed with a failing-to-passing regression. No additional important findings.

Execution: inline in the current workspace, as authorized by the user's approval. No commits or deployment requested.

## Recovery ledger — 2026-11-01

- Tasks 1–2 were mostly implemented in the interrupted session; resume preserved all existing edits and added two regression tests/fixes.
- Ruling: use a small native close channel for the same plugin service instead of waiting for activation with an arbitrary timeout. Plugin 0.5.0 acknowledges a start before activation and does not reply to inactive closes. The bridge stops both states; future plugin replacement must retain or update this channel.
- Final: fixed permission-result overwrite and overlay reappearing after resume — both regressions observed red then green; full suite green.
- Task 3: complete for automated verification and signed APK build. No APK installed or app data changed on the connected Samsung; device acceptance remains pending.
- Existing build warning: usage_stats applies Kotlin Gradle Plugin, which a future Flutter release will no longer support. Dependency migration is outside this change.
