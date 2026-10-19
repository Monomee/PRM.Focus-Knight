import 'package:flutter_test/flutter_test.dart';
import 'package:test_dart/features/telemetry/screen_time_tracker.dart';
import 'package:usage_stats/usage_stats.dart';

EventUsageInfo _e(String pkg, int ms, {String type = '1'}) =>
    EventUsageInfo(packageName: pkg, timeStamp: '$ms', eventType: type);

void main() {
  test('latest resumed package after the cut-off', () {
    final events = [
      _e('com.android.launcher', 1000),
      _e('com.google.android.youtube', 3000),
      _e('com.google.android.youtube', 3500, type: '2'), // paused, ignored
      _e('com.example.test_dart', 500),
    ];
    expect(ScreenTimeTracker.latestResumedPackage(events, sinceMs: 0), 'com.google.android.youtube');
    expect(ScreenTimeTracker.latestResumedPackage(events, sinceMs: 4000), isNull);
    expect(ScreenTimeTracker.latestResumedPackage(const [], sinceMs: 0), isNull);
  });

  test('ignores our own package', () {
    final events = [
      _e('com.google.android.youtube', 1000),
      _e('com.example.test_dart', 2000),
    ];
    expect(
      ScreenTimeTracker.latestResumedPackage(events, sinceMs: 0, ignorePackage: 'com.example.test_dart'),
      'com.google.android.youtube',
    );
  });
}
