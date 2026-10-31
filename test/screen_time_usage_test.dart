import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/features/telemetry/screen_time_tracker.dart';
import 'package:usage_stats/usage_stats.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('usage_stats');
  const youtube = 'com.google.android.youtube';
  late DateTime now;
  late List<Map<String, String>> events;
  bool permissionGranted = true;

  Map<String, String> event(
    int secondsAgo,
    int type, [
    String pkg = youtube,
  ]) => {
    'packageName': pkg,
    'eventType': '$type',
    'timeStamp':
        '${now.subtract(Duration(seconds: secondsAgo)).millisecondsSinceEpoch}',
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({'fk_daily_limit_minutes': 1});
    now = DateTime.now();
    events = [];
    permissionGranted = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'isUsagePermission':
              return permissionGranted;
            case 'queryAndAggregateUsageStats':
              return {
                youtube: {
                  'packageName': youtube,
                  'totalTimeInForeground': '30000',
                },
              };
            case 'queryEvents':
              return events;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<ScreenTimeTracker> load() async {
    final tracker = ScreenTimeTracker();
    addTearDown(tracker.dispose);
    await tracker.init();
    return tracker;
  }

  test(
    'ongoing foreground time crosses the limit without another resume',
    () async {
      events = [event(70, 1)];
      final tracker = await load();
      expect(tracker.isAppLimitExceeded(youtube), isTrue);
      expect(
        tracker.appDistractions[youtube]!.inSeconds,
        inInclusiveRange(70, 75),
      );
      await tracker.refreshUsageStats();
      expect(
        tracker.appDistractions[youtube]!.inSeconds,
        inInclusiveRange(70, 75),
      );
    },
  );

  test(
    'locking stops the open interval and overlap never counts it twice',
    () async {
      events = [
        event(100, 1),
        event(80, 16, 'android'),
        event(79, 17, 'android'),
      ];
      final tracker = await load();
      await tracker.refreshUsageStats();
      expect(tracker.appDistractions[youtube], const Duration(seconds: 20));
      expect(tracker.isAppLimitExceeded(youtube), isFalse);
    },
  );

  test(
    'switching packages closes the old interval and late pause is ordered',
    () async {
      events = [event(4, 1), event(2, 1, 'com.example.test_dart')];
      final tracker = await load();
      events.add(event(3, 2));
      await tracker.refreshUsageStats();
      expect(tracker.appDistractions[youtube], const Duration(seconds: 1));
    },
  );

  test('a visit spanning midnight counts only time in the requested day', () {
    final day = DateTime(2026, 10, 31);
    final usage = ScreenTimeTracker.usageDurations(
      [
        EventUsageInfo(
          packageName: youtube,
          eventType: '1',
          timeStamp:
              '${day.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch}',
        ),
      ],
      start: day,
      end: day.add(const Duration(minutes: 2)),
    );
    expect(usage[youtube], const Duration(minutes: 2));
  });

  test('duplicate resume and lock/unlock do not invent foreground time', () {
    final usage = ScreenTimeTracker.usageDurations(
      [
        for (final (seconds, type) in [
          (100, 1),
          (90, 1),
          (80, 17),
          (50, 18),
          (49, 15),
        ])
          EventUsageInfo(
            packageName: youtube,
            eventType: '$type',
            timeStamp:
                '${now.subtract(Duration(seconds: seconds)).millisecondsSinceEpoch}',
          ),
      ],
      start: now.subtract(const Duration(minutes: 2)),
      end: now,
    );
    expect(usage[youtube], const Duration(seconds: 20));
  });

  test(
    'granting permission after startup starts periodic usage tracking',
    () async {
      permissionGranted = false;
      final tracker = await load();
      events = [event(70, 1)];
      permissionGranted = true;
      await tracker.checkPermission();
      await Future<void>.delayed(const Duration(milliseconds: 3200));
      expect(tracker.isAppLimitExceeded(youtube), isTrue);
    },
  );
}
