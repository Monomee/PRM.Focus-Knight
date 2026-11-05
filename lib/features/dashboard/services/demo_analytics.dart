import 'dart:convert';
import 'dart:math' as math;

import 'analytics_calculations.dart';
import 'analytics_journal.dart';
import 'analytics_service.dart';
import 'focus_history_service.dart';

/// In-memory study events only; never constructs history, tracker or settlement.
class DemoAnalytics {
  DemoAnalytics._(this.analytics, this.sessions, this.appUsageIntervals);
  final AnalyticsService analytics;
  final List<SessionSample> sessions;
  final List<FocusInterval> appUsageIntervals;

  static DemoAnalytics create({DateTime? now, bool dense = false}) {
    final reference = (now ?? DateTime.now()).toLocal();
    final first = nextDay(reference, -29);
    final sessions = <SessionSample>[], usage = <FocusInterval>[];
    final usageSeconds = <String, double>{};
    for (var d = 0; d < 30; d++) {
      final date = nextDay(first, d), isToday = d == 29;
      final inactive = const {3, 11, 18, 24}.contains(d);
      final strong = d >= 25 && d < 29;
      final weak = !strong && (date.weekday >= 6 || d % 6 == 2);
      final count = inactive
          ? 0
          : isToday
          ? (reference.isAfter(DateTime(date.year, date.month, date.day, 9))
                ? dense
                      ? 2
                      : 1
                : 0)
          : strong
          ? dense
                ? 6
                : 4
          : weak
          ? dense
                ? 3
                : 2
          : d % 6 == 0
          ? dense
                ? 6
                : 5
          : dense
          ? 5
          : 4;
      var minutes = 0;
      for (var n = 0; n < count; n++) {
        final hours = [8, 14, 15, 18, 10, 20];
        final afternoon = n == 1 || n == 2;
        final hour = weak && n == 1 ? 18 : hours[n];
        var start = DateTime(
          date.year,
          date.month,
          date.day,
          hour,
          n == 2 ? 10 : 0,
        );
        if (isToday) start = DateTime(date.year, date.month, date.day, 9);
        if (d == 9 && n == count - 1) {
          start = DateTime(date.year, date.month, date.day, 23, 45);
        }
        final target =
            (dense ? [30, 45, 60, 40, 30, 50] : [25, 40, 50, 30, 25])[n] * 60;
        var complete =
            isToday ||
            strong ||
            (afternoon && !weak ? (d + n) % 8 != 0 : (d + n) % 4 == 0);
        var seconds = complete
            ? target
            : (target * (0.45 + (d % 3) * 0.12)).round();
        if (isToday) {
          seconds = math.min(seconds, reference.difference(start).inSeconds);
          complete = seconds == target;
        }
        if (seconds <= 0) continue;
        final paused = !isToday && d % 7 == 1 && n == 0;
        final pauseAt = start.add(const Duration(minutes: 7));
        final end = start.add(Duration(seconds: seconds + (paused ? 300 : 0)));
        final intervals = <FocusInterval>[
          if (paused) ...[
            (start: start, end: pauseAt),
            (start: pauseAt.add(const Duration(minutes: 5)), end: end),
          ] else
            (start: start, end: end),
        ];
        final openings = <DateTime>[];
        if (seconds > 120 && (d + n * 2) % 7 < 3) {
          final second = math.min(
            seconds - 90,
            (12 + (d * 7 + n * 5) % 26) * 60,
          );
          var at = start.add(Duration(seconds: second));
          if (paused && !at.isBefore(pauseAt)) {
            at = at.add(const Duration(minutes: 5));
          }
          openings.add(at);
          if (seconds - second > 720 && d % 4 == 0) {
            openings.add(at.add(const Duration(minutes: 10)));
          }
        }
        final raw = <String, dynamic>{
          'id': 'demo-$d-$n',
          'start': start.toUtc().toIso8601String(),
          'end': end.toUtc().toIso8601String(),
          'target': target,
          'outcome': complete ? 'completed' : 'cancelled',
          'monitored': true,
          'intervals': [
            for (final i in intervals)
              {
                'start': i.start.toUtc().toIso8601String(),
                'end': i.end.toUtc().toIso8601String(),
              },
          ],
          'interruptions': [
            for (final t in openings) t.toUtc().toIso8601String(),
          ],
          'pauses': [if (paused) pauseAt.toUtc().toIso8601String()],
        };
        final sample = SessionSample.parse(jsonEncode(raw));
        if (sample == null) throw StateError('Invalid demo session');
        sessions.add(sample);
        minutes += seconds ~/ 60;
        for (final at in openings) {
          final stop = at.add(Duration(seconds: 30 + (d % 3) * 15));
          usage.add((start: at, end: stop));
        }
      }
      // Leisure usage varies with study time, without overlapping study slots.
      final leisure = (180 - minutes + (d % 5) * 9).clamp(20, 155);
      final leisureStart = DateTime(date.year, date.month, date.day, 20);
      if (!isToday) {
        usage.add((
          start: leisureStart,
          end: leisureStart.add(Duration(minutes: leisure)),
        ));
      }
      usageSeconds[dateKey(date)] = 0;
    }
    // Today's observation stops at the demo clock, including an unfinished day.
    final boundedUsage = <FocusInterval>[
      for (final i in usage)
        if (i.start.isBefore(reference))
          (start: i.start, end: i.end.isAfter(reference) ? reference : i.end),
    ];
    for (final i in boundedUsage) {
      for (final part in splitInterval(
        i.start,
        i.end.isAfter(reference) ? reference : i.end,
      )) {
        usageSeconds.update(
          dateKey(part.date),
          (s) => s + part.seconds,
          ifAbsent: () => part.seconds,
        );
      }
    }
    final data = AnalyticsService.fromSamples(
      samples: sessions,
      dailyGoals: {dateKey(first): 7200},
      appUsageHours: {
        for (final e in usageSeconds.entries) e.key: e.value / 3600,
      },
      now: reference,
    );
    return DemoAnalytics._(
      data,
      List.unmodifiable(sessions),
      List.unmodifiable(boundedUsage),
    );
  }
}
