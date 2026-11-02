import 'dart:convert';
import 'dart:async';

import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/core/game/player_state.dart';
import 'package:test_dart/features/dashboard/services/analytics_calculations.dart';
import 'package:test_dart/features/dashboard/services/analytics_journal.dart';
import 'package:test_dart/features/dashboard/services/analytics_service.dart';
import 'package:test_dart/features/dashboard/services/focus_history_service.dart';
import 'package:test_dart/features/focus_session/focus_session_controller.dart';

Map<String, dynamic> sample(
  DateTime start, {
  int seconds = 1500,
  int target = 1500,
  bool completed = true,
  bool monitored = true,
  List<int> events = const [],
  List<int> pauses = const [],
}) => {
  'id': '${start.microsecondsSinceEpoch}',
  'start': start.toUtc().toIso8601String(),
  'end': start.add(Duration(seconds: seconds)).toUtc().toIso8601String(),
  'target': target,
  'outcome': completed ? 'completed' : 'cancelled',
  'monitored': monitored,
  'intervals': [
    {
      'start': start.toUtc().toIso8601String(),
      'end': start.add(Duration(seconds: seconds)).toUtc().toIso8601String(),
    },
  ],
  'interruptions': [
    for (final t in events)
      start.add(Duration(seconds: t)).toUtc().toIso8601String(),
  ],
  'pauses': [
    for (final t in pauses)
      start.add(Duration(seconds: t)).toUtc().toIso8601String(),
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 11, 3, 12);
  setUp(() async {
    await AnalyticsJournal.instance.flushed;
    SharedPreferences.setMockInitialValues({});
  });
  Future<AnalyticsService> load() async {
    final history = FocusHistoryService(clock: () => now);
    await history.loadData();
    final service = AnalyticsService(history: history, clock: () => now);
    addTearDown(service.dispose);
    addTearDown(history.dispose);
    await service.refreshAnalytics();
    return service;
  }

  test(
    'golden efficiency weights overlap and needs three distinct sessions',
    () async {
      for (var week = 0; week < 3; week++) {
        final start = DateTime(2026, 11, 2 - 7 * week, 7, 50);
        AnalyticsJournal.instance.save(
          sample(start, seconds: 1200, target: 2400, completed: false),
        );
      }
      await AnalyticsJournal.instance.flushed;
      final a = await load();
      final early = a.goldenHours.cells[7], morning = a.goldenHours.cells[14];
      expect(early.sessions.length, 3);
      expect(morning.sessions.length, 3);
      expect(early.seconds, 1800);
      expect(morning.seconds, 1800);
      expect(early.score, 0.25);
      expect(morning.score, 0.25);
      expect(a.goldenHours.cells[15].score, isNull);
    },
  );
  test('daily focus merges legacy without duplicate settled seconds; goals not retroactive', () async {
    final prefs = await SharedPreferences.getInstance();
    final recorded = sample(DateTime(2026, 11, 2, 9));
    await prefs.setString(
      'fk_history_settlement_state',
      jsonEncode({
        'days': {'2026-11-02': 1500},
        'counts': {'2026-11-02': 1},
        'analyticsIds': [recorded['id']],
      }),
    );
    await prefs.setString(
      AnalyticsJournal.goalsKey,
      jsonEncode({'2026-11-02': 1200}),
    );
    AnalyticsJournal.instance.save(recorded);
    await AnalyticsJournal.instance.flushed;
    final a = await load();
    expect(a.day(DateTime(2026, 11, 2)).seconds, 1500);
    expect(a.day(DateTime(2026, 11, 2)).completed, 1);
    expect(a.streaks.current, 1);
    expect(a.monthlyRate(DateTime(2026, 11)), 1);
    expect(a.goalFor(DateTime(2026, 11, 1)), isNull);
  });
  test('new uncredited focus is added to old settled focus', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('fk_focus_sec_2026-11-02', 3600);
    AnalyticsJournal.instance.save(
      sample(DateTime(2026, 11, 2, 10), seconds: 600, completed: false),
    );
    await AnalyticsJournal.instance.flushed;
    final a = await load();
    expect(a.day(DateTime(2026, 11, 2)).seconds, 4200);
  });
  test('velocity uses ratio of sums, excludes unmonitored legacy and keeps missing days null', () async {
    AnalyticsJournal.instance.save(
      sample(DateTime(2026, 11, 2, 9), seconds: 1800, events: [600, 1200]),
    );
    AnalyticsJournal.instance.save(
      sample(DateTime(2026, 11, 2, 10), seconds: 1800),
    );
    AnalyticsJournal.instance.save(
      sample(DateTime(2026, 11, 1, 9), monitored: false, events: [200]),
    );
    await AnalyticsJournal.instance.flushed;
    final a = await load(), v = a.distractionVelocity;
    expect(v.velocityPerHour, 2);
    expect(v.totalInterruptions, 2);
    expect(v.weeklyTrend.last, isNull);
    expect(v.weeklyTrend[5], 2);
    expect(v.weeklyTrend[4], isNull);
    expect(v.changePercent, isNull);
  });
  test('first pause censors before a later interruption; bad timestamps are rejected', () {
    final raw = sample(now, events: [600], pauses: [300]);
    final s = SessionSample.parse(jsonEncode(raw))!;
    expect(s.observation, (minutes: 5.0, event: false));
    raw['interruptions'] = ['invalid'];
    expect(SessionSample.parse(jsonEncode(raw)), isNull);
    expect(SessionSample.parse('{}'), isNull);
    expect(
      SessionSample.parse(jsonEncode(sample(now, events: [2000]))),
      isNull,
    );
  });
  test('goal changes are effective tomorrow, can be disabled without rewriting past', () async {
    await AnalyticsJournal.instance.setGoal(30, now);
    await AnalyticsJournal.instance.setGoal(null, nextDay(now));
    final a = await load();
    expect(a.goalFor(now), isNull);
    expect(a.goalFor(nextDay(now)), 1800);
    expect(a.goalFor(nextDay(now, 2)), isNull);
    await expectLater(
      AnalyticsJournal.instance.setGoal(0, now),
      throwsArgumentError,
    );
  });
  test('controller journals pause, resume, completion and early cancellation independent of payout', () async {
    var clock = DateTime(2026, 11, 2, 9);
    final player = PlayerState();
    await player.load();
    final history = FocusHistoryService(clock: () => clock);
    await history.loadData();
    final c = FocusSessionController(
      player: player,
      history: history,
      clock: () => clock,
      analyticsMonitoring: () => true,
    );
    addTearDown(c.dispose);
    addTearDown(history.dispose);
    await c.startFocusSession(
      task: 'Real',
      durationSeconds: 600,
      totalSessions: 2,
    );
    clock = clock.add(const Duration(seconds: 120));
    c.pause();
    c.recordInterruptionEvent();
    clock = clock.add(const Duration(seconds: 60));
    c.resumeFromPause();
    clock = clock.add(const Duration(seconds: 480));
    c.refreshTimer();
    expect(c.isResting, true);
    expect(history.totalFocusSecondsAllTime, 0);
    c.finishRestBreak();
    clock = clock.add(const Duration(seconds: 60));
    c.recordInterruptionEvent();
    clock = clock.add(const Duration(seconds: 60));
    c.cancelSession();
    await c.retrySettlement();
    await AnalyticsJournal.instance.flushed;
    final prefs = await SharedPreferences.getInstance();
    final rows = [
      for (final k in prefs.getKeys())
        if (k.startsWith(AnalyticsJournal.prefix))
          SessionSample.parse(prefs.getString(k)!)!,
    ];
    expect(rows.length, 2);
    final complete = rows.singleWhere((s) => s.completed);
    expect(complete.seconds, 600);
    expect(complete.observation, (minutes: 2.0, event: false));
    expect(complete.interruptions, isEmpty);
    final cancelled = rows.singleWhere((s) => !s.completed);
    expect(cancelled.observation, (minutes: 1.0, event: true));
    expect(cancelled.seconds, 120);
  });
  test('terminal usage extraction finds brief visits and excludes pauses and lifecycle changes', () async {
    final start = DateTime(2026, 11, 2, 9);
    final raw = sample(start, seconds: 1800);
    raw['intervals'] = [
      {
        'start': start.toIso8601String(),
        'end': start.add(const Duration(minutes: 5)).toIso8601String(),
      },
      {
        'start': start.add(const Duration(minutes: 10)).toIso8601String(),
        'end': start.add(const Duration(minutes: 30)).toIso8601String(),
      },
    ];
    raw['pauses'] = [start.add(const Duration(minutes: 5)).toIso8601String()];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'fk_tracked_apps',
      jsonEncode({'com.example.reader': 'Reader'}),
    );
    const channel = MethodChannel('usage_stats');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isUsagePermission') return true;
      if (call.method == 'queryEvents') {
        return [
          for (final (sec, type, pkg) in [
            (60, 1, 'com.example.reader'),
            (61, 1, 'com.example.reader'),
            (62, 2, 'com.example.reader'),
            (360, 1, 'com.example.reader'),
            (420, 2, 'com.example.reader'),
            (900, 1, 'com.example.reader'),
            (901, 2, 'com.example.reader'),
            (1000, 1, 'com.android.settings'),
          ])
            {
              'timeStamp':
                  '${start.add(Duration(seconds: sec)).millisecondsSinceEpoch}',
              'eventType': '$type',
              'packageName': pkg,
            },
        ];
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    AnalyticsJournal.instance.save(raw, collectUsage: true);
    await AnalyticsJournal.instance.flushed;
    final saved = SessionSample.parse(
      prefs.getString('${AnalyticsJournal.prefix}${raw['id']}')!,
    )!;
    expect(saved.monitored, true);
    expect(saved.interruptions.length, 2);
    expect(saved.observation, (minutes: 1.0, event: true));
    expect(saved.seconds, 1500);
  });
  test(
    'switching range while loading queries the complete new range',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        AnalyticsJournal.goalsKey,
        jsonEncode({'2020-01-01': 1800}),
      );
      const channel = MethodChannel('usage_stats');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final entered = Completer<void>(), release = Completer<void>();
      final starts = <int>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isUsagePermission') return true;
        if (call.method == 'queryEvents') {
          starts.add((call.arguments as Map)['start'] as int);
          if (starts.length == 1) {
            entered.complete();
            await release.future;
          }
          return [];
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final h = FocusHistoryService(clock: () => now);
      await h.loadData();
      final a = AnalyticsService(history: h, clock: () => now);
      addTearDown(a.dispose);
      addTearDown(h.dispose);
      final pending = a.refreshAnalytics();
      await entered.future;
      final changed = a.setCorrelationRange(30);
      release.complete();
      await pending;
      await changed;
      expect(starts.last, nextDay(now, -31).millisecondsSinceEpoch);
      expect(a.correlationDays.length, 30);
    },
  );
  test(
    'credited focus moves across local dates without leaving legacy duplicates',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final row = sample(DateTime(2026, 11, 2, 1));
      await prefs.setString(
        'fk_history_settlement_state',
        jsonEncode({
          'days': {'2026-11-01': 1500},
          'counts': {'2026-11-01': 1},
          'analyticsIds': [row['id']],
          'analyticsCredits': {
            row['id']: {
              'days': {'2026-11-01': 1500},
              'completedDay': '2026-11-01',
            },
          },
        }),
      );
      AnalyticsJournal.instance.save(row);
      await AnalyticsJournal.instance.flushed;
      final a = await load();
      expect(a.day(DateTime(2026, 11, 1)).seconds, 0);
      expect(a.day(DateTime(2026, 11, 2)).seconds, 1500);
      expect(a.day(DateTime(2026, 11, 2)).completed, 1);
    },
  );
  test('failed usage query cannot turn an unobserved session into zero distractions', () async {
    final raw = sample(now);
    const channel = MethodChannel('usage_stats');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isUsagePermission') return true;
      throw PlatformException(code: 'unavailable');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    AnalyticsJournal.instance.save(raw, collectUsage: true);
    await AnalyticsJournal.instance.flushed;
    final prefs = await SharedPreferences.getInstance();
    expect(
      SessionSample.parse(
        prefs.getString('${AnalyticsJournal.prefix}${raw['id']}')!,
      )!.monitored,
      false,
    );
  });
}
