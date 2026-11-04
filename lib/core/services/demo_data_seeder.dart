import 'dart:convert';

import '../../features/dashboard/services/analytics_calculations.dart';
import '../../features/dashboard/services/analytics_journal.dart';
import '../../features/dashboard/services/demo_analytics.dart';
import '../game/village.dart';
import 'persistent_preferences.dart';

class DemoDataSeeder {
  static const enabled = bool.fromEnvironment('DEMO_DATA');

  static Future<bool> reset({
    bool isEnabled = enabled,
    DateTime Function()? clock,
  }) async {
    if (!isEnabled) return false;
    final now = (clock ?? DateTime.now)().toLocal();
    final reference = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final fixture = DemoAnalytics.create(now: reference, dense: true);
    try {
      final prefs = await loadPersistentPreferences();
      for (final key in prefs.getKeys().where((key) => key.startsWith('fk_'))) {
        if (!await prefs.remove(key)) {
          throw StateError('Failed to clear demo preference: $key');
        }
      }
      final state = _historyState(fixture.sessions);
      final days = Map<String, dynamic>.from(state['days'] as Map);
      final hours = Map<String, dynamic>.from(state['hours'] as Map);
      final counts = Map<String, dynamic>.from(state['counts'] as Map);
      final first = nextDay(reference, -29);
      final monday = dayOf(reference)
          .subtract(Duration(days: reference.weekday - DateTime.monday));
      final writes = <Future<bool>>[
        prefs.setString(
          AnalyticsJournal.goalsKey,
          jsonEncode({dateKey(first): 7200}),
        ),
        for (final session in fixture.sessions)
          prefs.setString(
            '${AnalyticsJournal.prefix}${session.id}',
            jsonEncode(session.raw),
          ),
        prefs.setString('fk_history_settlement_state', jsonEncode(state)),
        prefs.setStringList('fk_completed_dates', days.keys.toList()..sort()),
        prefs.setStringList('fk_shielded_dates', [
          dateKey(nextDay(reference, -11)),
        ]),
        prefs.setInt('fk_total_focus_seconds_all_time', state['total'] as int),
        for (final entry in days.entries)
          prefs.setInt('fk_focus_sec_${entry.key}', entry.value as int),
        for (final entry in hours.entries)
          prefs.setInt('fk_hourly_focus_${entry.key}', entry.value as int),
        for (final entry in counts.entries)
          prefs.setInt('fk_session_count_${entry.key}', entry.value as int),
        for (final day in _interruptionCounts(fixture.sessions).entries)
          prefs.setInt('fk_interruption_day_${day.key}', day.value),
        prefs.setString(
          'fk_wallet_state',
          jsonEncode({
            'villageVersion': 2,
            'plots': _plots(),
            'coins': 1280,
            'logs': 340,
            'applied': <String>[],
            'buildings': ['tower:2', 'granary:1', 'barracks:1'],
            'granaryBuilt': dateKey(nextDay(reference, -24)),
          }),
        ),
        prefs.setInt('fk_gold', 1280),
        prefs.setInt('fk_logs', 340),
        prefs.setString('fk_character', 'archer'),
        prefs.setString('fk_badge', 'archer_diamond'),
        prefs.setStringList('fk_buildings', [
          'tower:2',
          'granary:1',
          'barracks:1',
        ]),
        prefs.setInt('fk_streak_tickets', 1),
        prefs.setString('fk_granary_built', dateKey(nextDay(reference, -24))),
        prefs.setString('fk_ticket_week', dateKey(monday)),
        prefs.setString(
          'fk_last_plan',
          jsonEncode({
            'task': 'Ôn tập chương tiếp theo',
            'focus': 40,
            'rest': 8,
            'sessions': 3,
            'longEvery': 2,
          }),
        ),
        prefs.setInt('fk_long_rest_minutes', 15),
        prefs.setBool('fk_strict_mode', true),
        prefs.setString(
          'fk_tracked_apps',
          jsonEncode({
            'com.google.android.youtube': 'YouTube',
            'com.instagram.android': 'Instagram',
            'com.zhiliaoapp.musically': 'TikTok',
          }),
        ),
        prefs.setInt('fk_app_limit_com.google.android.youtube', 35),
        prefs.setInt('fk_app_limit_com.instagram.android', 20),
        prefs.setInt('fk_app_limit_com.zhiliaoapp.musically', 15),
      ];
      if ((await Future.wait(writes)).contains(false)) {
        throw StateError('Failed to seed demo preferences');
      }
      await prefs.remove('fk_pending_settlement');
      return true;
    } finally {
      fixture.analytics.dispose();
    }
  }

  static Map<String, dynamic> _historyState(List<SessionSample> sessions) {
    final days = <String, int>{};
    final hours = <String, int>{};
    final counts = <String, int>{};
    final analyticsIds = <String>[];
    final analyticsCredits = <String, dynamic>{};
    var total = 0;
    for (final session in sessions) {
      if (session.completed != true) continue;
      final sessionDays = <String, int>{};
      var elapsedMicros = 0;
      for (final interval in session.intervals) {
        var cursor = interval.start.toLocal();
        final end = interval.end.toLocal();
        while (cursor.isBefore(end)) {
          final boundary = DateTime(
            cursor.year,
            cursor.month,
            cursor.day,
            cursor.hour + 1,
          );
          final sliceEnd = boundary.isBefore(end) ? boundary : end;
          final nextMicros =
              elapsedMicros + sliceEnd.difference(cursor).inMicroseconds;
          final seconds =
              nextMicros ~/ Duration.microsecondsPerSecond -
              elapsedMicros ~/ Duration.microsecondsPerSecond;
          final day = dateKey(cursor);
          sessionDays[day] = (sessionDays[day] ?? 0) + seconds;
          hours['${cursor.hour}'] = (hours['${cursor.hour}'] ?? 0) + seconds;
          elapsedMicros = nextMicros;
          cursor = sliceEnd;
        }
      }
      for (final entry in sessionDays.entries) {
        days[entry.key] = (days[entry.key] ?? 0) + entry.value;
      }
      final completedDay = dateKey(session.end);
      counts[completedDay] = (counts[completedDay] ?? 0) + 1;
      total += session.seconds.round();
      analyticsIds.add(session.id);
      analyticsCredits[session.id] = {
        'days': sessionDays,
        'completedDay': completedDay,
      };
    }
    return {
      'applied': <String>[],
      'analyticsIds': analyticsIds,
      'analyticsCredits': analyticsCredits,
      'total': total,
      'days': days,
      'hours': hours,
      'counts': counts,
    };
  }

  static Map<String, int> _interruptionCounts(List<SessionSample> sessions) {
    final result = <String, int>{};
    for (final session in sessions) {
      for (final interruption in session.interruptions) {
        final day = dateKey(interruption);
        result[day] = (result[day] ?? 0) + 1;
      }
    }
    return result;
  }

  static List<Map<String, Object>> _plots() {
    const buildings = [
      FocusBuilding.archery,
      FocusBuilding.tower,
      FocusBuilding.house1,
      FocusBuilding.monastery,
      FocusBuilding.barracks,
    ];
    const minutes = [50, 90, 25, 120, 180];
    const tasks = [
      'Ôn kiến trúc ứng dụng',
      'Luyện bài tập thuật toán',
      'Đọc tài liệu',
      'Thiết kế tính năng',
      'Hoàn thiện dự án',
    ];
    return List.generate(18, (index) {
      final variant = index % buildings.length;
      return VillagePlot(
        id: 'demo-plot-${index + 1}',
        building: buildings[variant],
        task: tasks[variant],
        focusMinutes: minutes[variant],
        state: index == 2 || index == 12
            ? PlotState.ruined
            : PlotState.complete,
      ).toJson();
    });
  }
}
