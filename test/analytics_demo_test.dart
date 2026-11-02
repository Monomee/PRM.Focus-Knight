import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/features/dashboard/services/analytics_calculations.dart';
import 'package:test_dart/features/dashboard/services/demo_analytics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 11, 30, 12);
  test('demo fixtures are deterministic, coherent and never access native channels', () async {
    SharedPreferences.setMockInitialValues({
      'fk_total_focus_seconds_all_time': 1234,
      'fk_tracked_apps': '{}',
      'fk_analytics_v1_goals': '{"2026-11-01":3600}',
    });
    final prefs = await SharedPreferences.getInstance();
    final before = {for (final k in prefs.getKeys()) k: prefs.get(k)};
    var nativeCalls = 0;
    const usage = MethodChannel('usage_stats');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(usage, (call) async {
      nativeCalls++;
      throw StateError('Demo cannot use Android');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(usage, null));
    final fixture = DemoAnalytics.create(now: now),
        again = DemoAnalytics.create(now: now);
    addTearDown(fixture.analytics.dispose);
    addTearDown(again.analytics.dispose);
    expect(
      jsonEncode(fixture.sessions.map((s) => s.raw).toList()),
      jsonEncode(again.sessions.map((s) => s.raw).toList()),
    );
    final a = fixture.analytics;
    expect(a.isDemo, true);
    final daily = <String, double>{}, usageSeconds = <String, double>{};
    for (final s in fixture.sessions) {
      for (final interval in s.intervals) {
        for (final part in splitInterval(interval.start, interval.end)) {
          daily.update(
            dateKey(part.date),
            (n) => n + part.seconds,
            ifAbsent: () => part.seconds,
          );
        }
      }
    }
    for (final interval in fixture.appUsageIntervals) {
      for (final part in splitInterval(interval.start, interval.end)) {
        usageSeconds.update(
          dateKey(part.date),
          (n) => n + part.seconds,
          ifAbsent: () => part.seconds,
        );
      }
    }
    for (final e in daily.entries) {
      expect(a.days[e.key]!.seconds, e.value);
    }
    expect(a.streaks.current, 4);
    expect(a.goldenHours.best! ~/ 7, 4);
    expect(a.endurance.count, fixture.sessions.length);
    expect(a.endurance.points.first.y, 1);
    expect(a.endurance.points.last.y, lessThan(1));
    expect(a.distractionVelocity.velocityPerHour, isNotNull);
    var weeklyEvents = 0, weeklySeconds = 0.0;
    for (final s in fixture.sessions) {
      for (final t in s.interruptions) {
        if (!t.isBefore(nextDay(now, -6))) weeklyEvents++;
        expect(
          s.intervals.any((i) => !t.isBefore(i.start) && t.isBefore(i.end)),
          true,
        );
        expect(fixture.appUsageIntervals.any((i) => i.start == t), true);
      }
      for (final i in s.intervals) {
        for (final part in splitInterval(i.start, i.end)) {
          if (!part.date.isBefore(nextDay(now, -6))) {
            weeklySeconds += part.seconds;
          }
        }
      }
    }
    expect(a.distractionVelocity.totalInterruptions, weeklyEvents);
    expect(a.distractionVelocity.focusWorkHours, weeklySeconds / 3600);
    expect(
      a.distractionVelocity.velocityPerHour,
      closeTo(
        a.distractionVelocity.totalInterruptions /
            a.distractionVelocity.focusWorkHours,
        1e-9,
      ),
    );
    for (final d in a.correlationDays) {
      expect(
        d.socialHours,
        closeTo((usageSeconds[dateKey(d.date)] ?? 0) / 3600, 1e-9),
      );
      expect(d.completionRate, a.day(d.date).progress);
    }
    await a.setCorrelationRange(30);
    await a.refreshAnalytics();
    expect(a.correlationDays.length, 30);
    expect(nativeCalls, 0);
    expect({for (final k in prefs.getKeys()) k: prefs.get(k)}, before);
  });
  test('demo observation ends at its clock, including midnight and partial sessions', () {
    for (final time in [
      DateTime(2026, 11, 30, 0),
      DateTime(2026, 11, 30, 9, 5),
      DateTime(2026, 11, 30, 12),
    ]) {
      final fixture = DemoAnalytics.create(now: time);
      addTearDown(fixture.analytics.dispose);
      expect(fixture.sessions.every((s) => !s.end.isAfter(time)), true);
      expect(
        fixture.appUsageIntervals.every((i) => !i.end.isAfter(time)),
        true,
      );
      expect(
        fixture.sessions.any((s) => dateKey(s.start) != dateKey(s.end)),
        true,
      );
    }
  });
}
