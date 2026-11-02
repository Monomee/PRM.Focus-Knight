# User-selected tracked apps

User scope: one selection controls tracking, daily notifications/Strict mode and blocking in Pomodoro battles.

Design: Settings opens a searchable multi-select screen of installed launchable apps. Save the package-to-label map in one preference snapshot shared with the background worker. Missing preference preserves the existing four defaults; an explicit empty map tracks nothing. Keep per-app limits on disk when deselecting. Exclude FocusKnight, system settings/UI and Home apps from the picker so navigation and permission recovery stay available. Use the existing Android bridge and launcher visibility query; no dependency or broad package permission.

- [x] Test selection persistence, empty selection, custom-app usage/foreground, background reload and storage failure. Initial tests failed before the selection API existed; the reselect-after-restart test also reproduced loss of a saved per-app limit before fixing it.
- [x] Add shared selection to ScreenTimeTracker and update battle, worker, settings and analytics callers.
- [x] Add installed-app bridge/visibility and searchable picker with save, cancel, error/retry states; test meaningful interactions.
- [x] 172 tests pass, analyze clean, debug APK build passes. Independent review found no important issues. Install matching update on Samsung and smoke-test picker.

Scope: no independent tracking-versus-blocking lists, app categories or remote sync. Historical usage totals are recalculated for the selected apps from available UsageEvents. Old limits, battle rewards and player progress are retained.

Device check: Settings shows the new button, installed-app list loads with actual device labels, searching Chrome filters correctly, selecting/saving adds Chrome to both the persisted map and the usage/limit rows. Reopening the picker shows Chrome selected. Chrome was then deselected and saved, verifying persistence and restoring the user's original four choices. No per-app limits or player data were changed. Tests additionally cover an arbitrary Reader app in the background blocker, battle grace alerts, analytics filtering and failed-write cache recovery.

No new dependency or QUERY_ALL_PACKAGES permission. Android profile/OEM differences outside the connected Samsung were not device-tested. Existing usage_stats Kotlin Gradle Plugin build warning remains outside this feature.
