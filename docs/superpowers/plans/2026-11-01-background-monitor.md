# Background daily-limit monitor

Goal: daily notifications and Strict mode must work without reopening FocusKnight.

Root cause: the daily polling loop lives in the Activity's Dart isolate; the existing foreground task does no monitoring and only starts during battles. Device inspection confirmed no running service.

Approach: reuse flutter_foreground_task, ScreenTimeTracker and OverlayService. Move daily monitoring to its worker; keep battle penalties in the UI. Register existing native alert/close channels for the worker and prepare the cached overlay engine on process recovery. No new dependency or duplicate usage algorithm.

- [x] Reproduce with worker tests: cold recovery, preference refresh, battle heartbeat expiry all fail before implementation.
- [x] Run daily monitor in foreground worker; reload preferences across isolates and recognize already-open apps.
- [x] Start service with usage permission, retain it after battles/task removal, configure boot/update recovery. Suppress daily blocking with an expiring battle heartbeat.
- [x] Register native channels for headless engine; preserve notification and overlay behavior.
- [x] Migrate daily integration tests to worker; 162 tests pass, analyze clean, debug APK build passes. Independent review completed.
- [x] Install matching debug update without clearing data; test on connected Samsung with UI task removed.

Limits: force-stop and Android's explicit Stop action must remain respected. OEM battery restrictions and reboot recovery need honest device coverage reporting.

## Results and decisions

- Samsung SM-G781N: initial inspection showed no running foreground service. After installation, the monitoring service is foreground with silent notification ID 1000.
- Removed the active FocusKnight task (2689). The remaining historical entry 2686 has zero activities. Facebook then shows the correct daily overlay with its existing 60-minute limit; returning Home removes the overlay, and opening Facebook directly shows it again. No limits, Strict mode setting, or user data were changed for these tests.
- Screenshot: build/focusknight-background-check.png (local build artifact).
- Review found a plugin static-messenger detach bug and two heartbeat/open interleavings. State sharing now goes directly through the existing native bridge to the cached overlay engine. Both heartbeat regressions were observed failing without their fixes and passing with them.
- Ruling: extend the native bridge to share overlay state because the plugin's static messenger can be cleared when another engine detaches. This keeps the existing service/UI; replacing the overlay plugin later requires checking this bridge.
- Ruling: expire battle suppression after eight seconds without a UI heartbeat. An abandoned UI cannot indefinitely disable daily limits; under severe scheduling stalls the daily blocker can resume until the next heartbeat arrives.
- Reboot and actual process-death recovery were not verified on the phone: Samsung denies sending a kill signal from run-as to the app process. The worker's system-start path is covered by tests, and boot/update/system restart options are configured. Do not infer device recovery proof from these options.
- Existing usage_stats Kotlin Gradle Plugin warning remains; dependency migration is outside this fix.
