import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight service managing user focus history, dot-grid calendar dates, and streak calculation.
/// Uses SharedPreferences with simple string list and integer keys for O(1) performance without bulky JSON.
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
      final prefs = await SharedPreferences.getInstance();
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
  }) async {
    final prefs = await SharedPreferences.getInstance();
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
    final daySeconds =
        (days[todayStr] as int? ??
            prefs.getInt('$_prefixFocusSecDay$todayStr') ??
            0) +
        durationSeconds;
    final hour = now.hour.toString();
    final hourSeconds =
        (hours[hour] as int? ?? prefs.getInt('$_prefixHourlyFocus$hour') ?? 0) +
        durationSeconds;
    final sessionCount =
        (counts[todayStr] as int? ??
            prefs.getInt('$_prefixSessionCountDay$todayStr') ??
            0) +
        1;
    final total = (state['total'] as int) + durationSeconds;
    days[todayStr] = daySeconds;
    hours[hour] = hourSeconds;
    counts[todayStr] = sessionCount;
    if (settlementId != null) applied.add(settlementId);
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
    final completedDates = _completedDates.contains(todayStr)
        ? _completedDates
        : [..._completedDates, todayStr];
    await Future.wait([
      prefs.setStringList(_keyCompletedDates, completedDates),
      prefs.setInt('$_prefixFocusSecDay$todayStr', daySeconds),
      prefs.setInt(_keyTotalFocusSecondsAllTime, total),
      prefs.setInt('$_prefixHourlyFocus$hour', hourSeconds),
      prefs.setInt('$_prefixSessionCountDay$todayStr', sessionCount),
    ]);
    _completedDates = completedDates;
    _todayFocusSeconds = daySeconds;
    _totalFocusSecondsAllTime = total;
    notifyListeners();
  }

  /// Records an interruption or app exit during active focus session
  Future<void> recordInterruption() async {
    try {
      final prefs = await SharedPreferences.getInstance();
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
      final prefs = await SharedPreferences.getInstance();
      final dateStr = formatDate(date);
      return prefs.getInt('$_prefixInterruptionDay$dateStr') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Gets completed session count for a specific calendar date
  Future<int> getSessionCountForDate(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('$_prefixSessionCountDay${formatDate(date)}') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Retrieves focus seconds for a specific calendar date
  Future<int> getFocusSecondsForDate(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateStr = formatDate(date);
      return prefs.getInt('$_prefixFocusSecDay$dateStr') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Retrieves hourly focus distribution across 24 hours for Golden Hours analysis
  Future<Map<int, int>> getHourlyFocusStats() async {
    final result = <int, int>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      for (int h = 0; h < 24; h++) {
        result[h] = prefs.getInt('$_prefixHourlyFocus$h') ?? 0;
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
        done.contains(formatDate(yesterday)))
      return false;
    if (!done.contains(formatDate(dayBefore))) return false;
    if (yesterday.isBefore(
      DateTime(protectFrom.year, protectFrom.month, protectFrom.day),
    ))
      return false;
    if (!consumeTicket()) return false;

    // Assign after the await so a concurrent loadData() can't overwrite the new entry.
    final updated = [..._shieldedDates, formatDate(yesterday)];
    try {
      final prefs = await SharedPreferences.getInstance();
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
