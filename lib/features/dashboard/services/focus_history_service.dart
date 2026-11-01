import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/services/persistent_preferences.dart';

typedef FocusInterval = ({DateTime start, DateTime end});

/// Lightweight service managing user focus history, dot-grid calendar dates, and streak calculation.
/// Uses a durable snapshot with legacy preference keys for compatibility.
class FocusHistoryService extends ChangeNotifier {
  static FocusHistoryService? _instance;
  static FocusHistoryService get instance =>
      _instance ??= FocusHistoryService();

  static const String _keyCompletedDates = 'fk_completed_dates';
  static const String _keyShieldedDates = 'fk_shielded_dates';
  static const String _keyTotalFocusSecondsAllTime =
      'fk_total_focus_seconds_all_time';
  static const String _prefixFocusSecDay = 'fk_focus_sec_';

  static const String _prefixHourlyFocus = 'fk_hourly_focus_';
  static const String _prefixInterruptionDay = 'fk_interruption_day_';
  static const String _prefixSessionCountDay = 'fk_session_count_';
  static const String _keySettlementState = 'fk_history_settlement_state';

  List<String> _completedDates = [];
  List<String> get completedDates => List.unmodifiable(_completedDates);

  /// Missed days covered by a streak-protection ticket (count as completed for streaks).
  List<String> _shieldedDates = [];
  List<String> get shieldedDates => List.unmodifiable(_shieldedDates);

  final DateTime Function() _clock;
  int _todayFocusSeconds = 0;
  int get todayFocusSeconds => _todayFocusSeconds;

  int _totalFocusSecondsAllTime = 0;
  int get totalFocusSecondsAllTime => _totalFocusSecondsAllTime;

  int get totalFocusHoursAllTime => _totalFocusSecondsAllTime ~/ 3600;

  FocusHistoryService({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    loadData();
  }

  static String formatDate(DateTime d) {
    final year = d.year.toString().padLeft(4, '0');
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> loadData() async {
    try {
      final prefs = await loadPersistentPreferences();
      final stateRaw = prefs.getString(_keySettlementState);
      final state = stateRaw == null
          ? null
          : jsonDecode(stateRaw) as Map<String, dynamic>;
      final days = state == null
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(state['days'] as Map);
      _completedDates = {
        ...prefs.getStringList(_keyCompletedDates) ?? const <String>[],
        ...days.keys,
      }.toList();
      _shieldedDates = prefs.getStringList(_keyShieldedDates) ?? [];
      _totalFocusSecondsAllTime =
          state?['total'] as int? ??
          prefs.getInt(_keyTotalFocusSecondsAllTime) ??
          0;

      final todayStr = formatDate(_clock());
      _todayFocusSeconds =
          days[todayStr] as int? ??
          prefs.getInt('$_prefixFocusSecDay$todayStr') ??
          0;

      notifyListeners();
    } catch (_) {}
  }

  /// Records a completed Pomodoro session (100% finished)
  Future<void> recordCompletedSession(
    int durationSeconds, {
    String? settlementId,
    List<FocusInterval>? intervals,
  }) async {
    if (durationSeconds < 0 || (intervals != null && intervals.isEmpty)) {
      throw ArgumentError('Invalid completed focus session');
    }
    if (intervals != null) {
      var micros = 0;
      DateTime? previousEnd;
      for (final interval in intervals) {
        if (interval.end.isBefore(interval.start) ||
            (previousEnd != null && interval.start.isBefore(previousEnd))) {
          throw ArgumentError('Focus intervals must be ordered and disjoint');
        }
        micros += interval.end.difference(interval.start).inMicroseconds;
        previousEnd = interval.end;
      }
      if (micros ~/ Duration.microsecondsPerSecond != durationSeconds) {
        throw ArgumentError('Focus intervals must match session duration');
      }
    }
    final prefs = await loadPersistentPreferences();
    final now = _clock();
    final todayStr = formatDate(now);
    final raw = prefs.getString(_keySettlementState);
    final state = raw == null
        ? <String, dynamic>{
            'applied': <String>[],
            'total': prefs.getInt(_keyTotalFocusSecondsAllTime) ?? 0,
            'days': <String, dynamic>{},
            'hours': <String, dynamic>{},
            'counts': <String, dynamic>{},
          }
        : jsonDecode(raw) as Map<String, dynamic>;
    final applied = (state['applied'] as List).cast<String>();
    if (settlementId != null && applied.contains(settlementId)) {
      await loadData();
      return;
    }
    final days = Map<String, dynamic>.from(state['days'] as Map);
    final hours = Map<String, dynamic>.from(state['hours'] as Map);
    final counts = Map<String, dynamic>.from(state['counts'] as Map);
    final dayAdds = <String, int>{};
    final hourAdds = <String, int>{};
    if (intervals == null) {
      // shortcut: old sessions have no timestamps; use payout time for legacy journals.
      dayAdds[todayStr] = durationSeconds;
      hourAdds['${now.hour}'] = durationSeconds;
    } else {
      var elapsedMicros = 0;
      for (final interval in intervals) {
        var cursor = interval.start.toLocal();
        final end = interval.end.toLocal();
        while (cursor.isBefore(end)) {
          // Add elapsed time so the boundary is also correct across DST changes.
          final nextHour = cursor.add(
            Duration(
              microseconds:
                  Duration.microsecondsPerHour -
                  cursor.minute * Duration.microsecondsPerMinute -
                  cursor.second * Duration.microsecondsPerSecond -
                  cursor.millisecond * Duration.microsecondsPerMillisecond -
                  cursor.microsecond,
            ),
          );
          final sliceEnd = nextHour.isBefore(end) ? nextHour : end;
          final nextMicros =
              elapsedMicros + sliceEnd.difference(cursor).inMicroseconds;
          final seconds =
              nextMicros ~/ Duration.microsecondsPerSecond -
              elapsedMicros ~/ Duration.microsecondsPerSecond;
          if (seconds > 0) {
            final day = formatDate(cursor);
            final hour = '${cursor.hour}';
            dayAdds[day] = (dayAdds[day] ?? 0) + seconds;
            hourAdds[hour] = (hourAdds[hour] ?? 0) + seconds;
          }
          elapsedMicros = nextMicros;
          cursor = sliceEnd;
        }
      }
    }
    for (final entry in dayAdds.entries) {
      days[entry.key] =
          (days[entry.key] as int? ??
              prefs.getInt('$_prefixFocusSecDay${entry.key}') ??
              0) +
          entry.value;
    }
    for (final entry in hourAdds.entries) {
      hours[entry.key] =
          (hours[entry.key] as int? ??
              prefs.getInt('$_prefixHourlyFocus${entry.key}') ??
              0) +
          entry.value;
    }
    final completedDay = intervals == null
        ? todayStr
        : formatDate(intervals.last.end.toLocal());
    final sessionCount =
        (counts[completedDay] as int? ??
            prefs.getInt('$_prefixSessionCountDay$completedDay') ??
            0) +
        1;
    final total = (state['total'] as int) + durationSeconds;
    counts[completedDay] = sessionCount;
    if (settlementId != null) applied.add(settlementId);
    try {
      if (!await prefs.setString(
        _keySettlementState,
        jsonEncode({
          'applied': applied,
          'total': total,
          'days': days,
          'hours': hours,
          'counts': counts,
        }),
      )) {
        throw StateError('Failed to save completed session');
      }
    } catch (_) {
      invalidatePreferenceCache();
      rethrow;
    }
    final completedDates = {..._completedDates, ...days.keys}.toList();
    await Future.wait([
      prefs.setStringList(_keyCompletedDates, completedDates),
      for (final day in dayAdds.keys)
        prefs.setInt('$_prefixFocusSecDay$day', days[day] as int),
      prefs.setInt(_keyTotalFocusSecondsAllTime, total),
      for (final hour in hourAdds.keys)
        prefs.setInt('$_prefixHourlyFocus$hour', hours[hour] as int),
      prefs.setInt('$_prefixSessionCountDay$completedDay', sessionCount),
    ]);
    _completedDates = completedDates;
    _todayFocusSeconds =
        days[todayStr] as int? ??
        prefs.getInt('$_prefixFocusSecDay$todayStr') ??
        0;
    _totalFocusSecondsAllTime = total;
    notifyListeners();
  }

  /// Records an interruption or app exit during active focus session
  Future<void> recordInterruption() async {
    try {
      final prefs = await loadPersistentPreferences();
      final todayStr = formatDate(DateTime.now());
      final key = '$_prefixInterruptionDay$todayStr';
      final count = prefs.getInt(key) ?? 0;
      await prefs.setInt(key, count + 1);
      notifyListeners();
    } catch (_) {}
  }

  /// Gets total interruptions for a specific calendar date
  Future<int> getInterruptionsForDate(DateTime date) async {
    try {
      final prefs = await loadPersistentPreferences();
      final dateStr = formatDate(date);
      return prefs.getInt('$_prefixInterruptionDay$dateStr') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Gets completed session count for a specific calendar date
  Future<int> getSessionCountForDate(DateTime date) async {
    try {
      final prefs = await loadPersistentPreferences();
      final raw = prefs.getString(_keySettlementState);
      final counts = raw == null
          ? null
          : (jsonDecode(raw) as Map)['counts'] as Map;
      return counts?[formatDate(date)] as int? ??
          prefs.getInt('$_prefixSessionCountDay${formatDate(date)}') ??
          0;
    } catch (_) {
      return 0;
    }
  }

  /// Retrieves focus seconds for a specific calendar date
  Future<int> getFocusSecondsForDate(DateTime date) async {
    try {
      final prefs = await loadPersistentPreferences();
      final dateStr = formatDate(date);
      final raw = prefs.getString(_keySettlementState);
      final days = raw == null ? null : (jsonDecode(raw) as Map)['days'] as Map;
      return days?[dateStr] as int? ??
          prefs.getInt('$_prefixFocusSecDay$dateStr') ??
          0;
    } catch (_) {
      return 0;
    }
  }

  /// Retrieves hourly focus distribution across 24 hours for Golden Hours analysis
  Future<Map<int, int>> getHourlyFocusStats() async {
    final result = <int, int>{};
    try {
      final prefs = await loadPersistentPreferences();
      final raw = prefs.getString(_keySettlementState);
      final hours = raw == null
          ? null
          : (jsonDecode(raw) as Map)['hours'] as Map;
      for (int h = 0; h < 24; h++) {
        result[h] =
            hours?['$h'] as int? ?? prefs.getInt('$_prefixHourlyFocus$h') ?? 0;
      }
    } catch (_) {}
    return result;
  }

  /// Calculates the current streak following Edge Case A rules:
  /// 1. T = today, T-1 = yesterday.
  /// 2. If T is in completedDates: count continuously backwards from T (T, T-1, T-2...).
  /// 3. If T is NOT in completedDates, but T-1 IS: DO NOT reset! Keep streak from T-1 backwards.
  /// 4. If neither T nor T-1 is present: streak is officially broken -> return 0.
  int calculateStreak([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = formatDate(today);
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayStr = formatDate(yesterday);

    final completedSet = {..._completedDates, ..._shieldedDates};

    if (completedSet.contains(todayStr)) {
      // Completed today: count backwards starting from today
      int streak = 0;
      DateTime cursor = today;
      while (completedSet.contains(formatDate(cursor))) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
      return streak;
    } else if (completedSet.contains(yesterdayStr)) {
      // Not completed yet today, but completed yesterday: maintain streak!
      int streak = 0;
      DateTime cursor = yesterday;
      while (completedSet.contains(formatDate(cursor))) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
      return streak;
    } else {
      // Broken streak
      return 0;
    }
  }

  /// Covers a single missed day (yesterday) with a ticket so the streak survives.
  /// Only when today and yesterday are both missing, the day before counts, and
  /// yesterday is on/after [protectFrom] (the day the granary was built).
  Future<bool> tryShieldGap({
    required DateTime now,
    required DateTime? protectFrom,
    required bool Function() consumeTicket,
  }) async {
    if (protectFrom == null) return false;
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dayBefore = today.subtract(const Duration(days: 2));
    final done = {..._completedDates, ..._shieldedDates};
    if (done.contains(formatDate(today)) ||
        done.contains(formatDate(yesterday))) {
      return false;
    }
    if (!done.contains(formatDate(dayBefore))) return false;
    if (yesterday.isBefore(
      DateTime(protectFrom.year, protectFrom.month, protectFrom.day),
    )) {
      return false;
    }
    if (!consumeTicket()) return false;

    // Assign after the await so a concurrent loadData() can't overwrite the new entry.
    final updated = [..._shieldedDates, formatDate(yesterday)];
    try {
      final prefs = await loadPersistentPreferences();
      await prefs.setStringList(_keyShieldedDates, updated);
    } catch (_) {}
    _shieldedDates = updated;
    notifyListeners();
    return true;
  }

  /// Helper to format seconds to "Xh Ym" or "Xm"
  String formatSeconds(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}
