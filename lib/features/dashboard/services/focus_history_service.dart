import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight service managing user focus history, dot-grid calendar dates, and streak calculation.
/// Uses SharedPreferences with simple string list and integer keys for O(1) performance without bulky JSON.
class FocusHistoryService extends ChangeNotifier {
  static FocusHistoryService? _instance;
  static FocusHistoryService get instance => _instance ??= FocusHistoryService();

  static const String _keyCompletedDates = 'fk_completed_dates';
  static const String _keyTotalFocusSecondsAllTime = 'fk_total_focus_seconds_all_time';
  static const String _prefixFocusSecDay = 'fk_focus_sec_';

  static const String _prefixHourlyFocus = 'fk_hourly_focus_';
  static const String _prefixInterruptionDay = 'fk_interruption_day_';
  static const String _prefixSessionCountDay = 'fk_session_count_';

  List<String> _completedDates = [];
  List<String> get completedDates => List.unmodifiable(_completedDates);

  int _todayFocusSeconds = 0;
  int get todayFocusSeconds => _todayFocusSeconds;

  int _totalFocusSecondsAllTime = 0;
  int get totalFocusSecondsAllTime => _totalFocusSecondsAllTime;

  int get totalFocusHoursAllTime => _totalFocusSecondsAllTime ~/ 3600;

  FocusHistoryService() {
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
      _completedDates = prefs.getStringList(_keyCompletedDates) ?? [];
      _totalFocusSecondsAllTime = prefs.getInt(_keyTotalFocusSecondsAllTime) ?? 0;

      final todayStr = formatDate(DateTime.now());
      _todayFocusSeconds = prefs.getInt('$_prefixFocusSecDay$todayStr') ?? 0;

      notifyListeners();
    } catch (_) {}
  }

  /// Records a completed Pomodoro session (100% finished)
  Future<void> recordCompletedSession(int durationSeconds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayStr = formatDate(now);

      // Add to completed dates if not already present
      if (!_completedDates.contains(todayStr)) {
        _completedDates.add(todayStr);
        await prefs.setStringList(_keyCompletedDates, _completedDates);
      }

      // Increment today's focus seconds
      _todayFocusSeconds += durationSeconds;
      await prefs.setInt('$_prefixFocusSecDay$todayStr', _todayFocusSeconds);

      // Increment all-time focus seconds
      _totalFocusSecondsAllTime += durationSeconds;
      await prefs.setInt(_keyTotalFocusSecondsAllTime, _totalFocusSecondsAllTime);

      // Increment hourly focus for Golden Hours
      final hour = now.hour;
      final currentHourly = prefs.getInt('$_prefixHourlyFocus$hour') ?? 0;
      await prefs.setInt('$_prefixHourlyFocus$hour', currentHourly + durationSeconds);

      // Increment session count
      final sessionCount = prefs.getInt('$_prefixSessionCountDay$todayStr') ?? 0;
      await prefs.setInt('$_prefixSessionCountDay$todayStr', sessionCount + 1);

      notifyListeners();
    } catch (_) {}
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

    final completedSet = _completedDates.toSet();

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
