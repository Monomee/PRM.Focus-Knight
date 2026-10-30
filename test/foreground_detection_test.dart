import 'package:flutter_test/flutter_test.dart';
import 'package:test_dart/features/telemetry/screen_time_tracker.dart';
import 'package:usage_stats/usage_stats.dart';

EventUsageInfo _e(String? pkg, int ms, int type) =>
    EventUsageInfo(packageName: pkg, timeStamp: '$ms', eventType: '$type');

void main() {
  test('keeps resumed package through polls without events', () {
    final resumed = ScreenTimeTracker.reduceForegroundEvents(
      ForegroundUsageState(),
      [_e('com.google.android.youtube', 1000, 1)],
    );
    final noEvents = ScreenTimeTracker.reduceForegroundEvents(
      resumed,
      const [],
    );

    expect(noEvents.activePackage, 'com.google.android.youtube');
  });

  test('overlap deduplicates old events and accepts late events', () {
    final processed = <String>{};
    final resumed = _e('com.google.android.youtube', 1000, 1);
    final first = ScreenTimeTracker.unseenForegroundEvents([
      resumed,
    ], processed);
    final latePause = _e('com.google.android.youtube', 1500, 2);
    final overlap = ScreenTimeTracker.unseenForegroundEvents([
      resumed,
      latePause,
    ], processed);

    expect(first, [resumed]);
    expect(overlap, [latePause]);
    final state = ScreenTimeTracker.reduceForegroundEvents(
      ScreenTimeTracker.reduceForegroundEvents(ForegroundUsageState(), first),
      overlap,
    );
    expect(state.activePackage, isNull);
  });

  test('paused event clears the active package', () {
    final state = ScreenTimeTracker.reduceForegroundEvents(
      ForegroundUsageState(),
      [
        _e('com.google.android.youtube', 1000, 1),
        _e('com.google.android.youtube', 2000, 2),
      ],
    );

    expect(state.activePackage, isNull);
  });

  test('self and launcher resumed replace the previous app', () {
    final self = ScreenTimeTracker.reduceForegroundEvents(
      ForegroundUsageState(),
      [
        _e('com.google.android.youtube', 1000, 1),
        _e('com.example.test_dart', 2000, 1),
      ],
    );
    final launcher = ScreenTimeTracker.reduceForegroundEvents(self, [
      _e('com.android.launcher', 3000, 1),
    ]);

    expect(self.activePackage, 'com.example.test_dart');
    expect(launcher.activePackage, 'com.android.launcher');
  });

  test('locking after opening a blocked app clears foreground state', () {
    final state = ScreenTimeTracker.reduceForegroundEvents(
      ForegroundUsageState(),
      [
        _e('com.google.android.youtube', 1000, 1),
        _e(null, 2000, 16),
        _e(null, 2100, 17),
      ],
    );

    expect(state.isInteractive, isFalse);
    expect(state.isKeyguardShown, isTrue);
    expect(state.activePackage, isNull);
  });

  test('unlock does not restore the app without a new resume', () {
    final state = ScreenTimeTracker.reduceForegroundEvents(
      ForegroundUsageState(),
      [
        _e('com.google.android.youtube', 1000, 1),
        _e(null, 2000, 17),
        _e(null, 3000, 18),
        _e(null, 3100, 15),
      ],
    );

    expect(state.isInteractive, isTrue);
    expect(state.isKeyguardShown, isFalse);
    expect(state.activePackage, isNull);
  });
}
