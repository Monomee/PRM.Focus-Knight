import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/features/telemetry/screen_time_tracker.dart';
import 'package:test_dart/features/dashboard/services/analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const custom = 'com.example.reader';
  const facebook = 'com.facebook.katana';
  const channel = MethodChannel('usage_stats');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isUsagePermission') return true;
      if (call.method == 'queryAndAggregateUsageStats') {
        return {
          facebook: {
            'packageName': facebook,
            'totalTimeInForeground': '3600000',
          },
          custom: {'packageName': custom, 'totalTimeInForeground': '7200000'},
        };
      }
      if (call.method == 'queryEvents') {
        final now = DateTime.now().millisecondsSinceEpoch;
        return [
          {
            'packageName': facebook,
            'eventType': '1',
            'timeStamp': '${now - 180000}',
          },
          {
            'packageName': custom,
            'eventType': '1',
            'timeStamp': '${now - 120000}',
          },
        ];
      }
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<ScreenTimeTracker> load() async {
    final tracker = ScreenTimeTracker();
    addTearDown(tracker.dispose);
    await tracker.ready;
    return tracker;
  }

  test('old users keep defaults, explicit empty selection stays empty after reload', () async {
    final tracker = await load();
    expect(tracker.trackedApps[facebook], 'Facebook');
    await tracker.setTrackedApps({});
    final restored = await load();
    expect(restored.trackedApps, isEmpty);
    expect(restored.appDistractions, isEmpty);
    expect(await restored.getActiveBlacklistedPackage(), isNull);
  });

  test('custom selection controls usage, limit and foreground and retains app limits', () async {
    final tracker = await load();
    await tracker.setAppLimit(custom, 1);
    await tracker.setTrackedApps({custom: 'Reader'});
    expect(tracker.appNameFor(custom), 'Reader');
    expect(tracker.appDistractions.keys, [custom]);
    expect(tracker.isAppLimitExceeded(custom), isTrue);
    expect(await tracker.getActiveBlacklistedPackage(), custom);
    await tracker.setTrackedApps({});
    final empty = await load();
    await empty.setTrackedApps({custom: 'Reader'});
    expect(empty.getAppLimit(custom), 1);
    final restored = await load();
    expect(restored.getAppLimit(custom), 1);
    expect(restored.trackedApps, {custom: 'Reader'});
  });

  test(
    'worker reload replaces selection and removes deselected usage',
    () async {
      final worker = await load();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fk_tracked_apps', jsonEncode({custom: 'Reader'}));
      await worker.reloadLimits();
      await worker.refreshUsageStats();
      expect(worker.isTrackedPackage(facebook), isFalse);
      expect(worker.isTrackedPackage(custom), isTrue);
      expect(worker.appDistractions.keys, [custom]);
      expect(worker.totalDistractionToday, worker.appDistractions[custom]);
    },
  );

  test('selection rejects self-blocking and invalid package names', () async {
    final tracker = await load();
    await expectLater(
      tracker.setTrackedApps({'com.example.test_dart': 'Self'}),
      throwsArgumentError,
    );
    await expectLater(tracker.setTrackedApps({'': 'Bad'}), throwsArgumentError);
    expect(tracker.trackedApps[facebook], 'Facebook');
  });

  test('analytics totals use the selected apps', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fk_tracked_apps', jsonEncode({custom: 'Reader'}));
    final analytics = AnalyticsService();
    addTearDown(analytics.dispose);
    await analytics.refreshAnalytics();
    expect(analytics.correlationDays, hasLength(7));
    expect(
      analytics.correlationDays.map((day) => day.socialHours),
      everyElement(2),
    );
  });
}
