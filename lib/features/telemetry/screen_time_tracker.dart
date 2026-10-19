import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usage_stats/usage_stats.dart';
import '../../core/constants/blacklist_constants.dart';

/// Service monitoring screen-time for blacklisted entertainment/social apps using usage_stats
class ScreenTimeTracker extends ChangeNotifier {
  bool _hasPermission = false;
  bool get hasPermission => _hasPermission;

  Duration _totalDistractionToday = Duration.zero;
  Duration get totalDistractionToday => _totalDistractionToday;

  final Map<String, Duration> _appDistractions = {};
  Map<String, Duration> get appDistractions => Map.unmodifiable(_appDistractions);

  int _dailyLimitMinutes = 60;
  int get dailyLimitMinutes => _dailyLimitMinutes;

  final Map<String, int> _appLimits = {};
  Map<String, int> get appLimits => Map.unmodifiable(_appLimits);

  /// Gets the individual daily limit in minutes for a specific package (falls back to global limit)
  int getAppLimit(String pkg) => _appLimits[pkg] ?? _dailyLimitMinutes;

  /// Whether distraction screen-time today has exceeded the daily global limit
  bool get isLimitExceeded =>
      _dailyLimitMinutes > 0 && _totalDistractionToday.inMinutes >= _dailyLimitMinutes;

  /// Whether a specific app has exceeded its individual daily limit
  bool isAppLimitExceeded(String pkg) {
    final limit = getAppLimit(pkg);
    if (limit <= 0) return false;
    final dur = _appDistractions[pkg] ?? Duration.zero;
    return dur.inMinutes >= limit;
  }

  /// Progress ratio towards individual app limit clamped between 0.0 and 1.0
  double getAppLimitProgress(String pkg) {
    final limit = getAppLimit(pkg);
    if (limit <= 0) return 0.0;
    final dur = _appDistractions[pkg] ?? Duration.zero;
    return (dur.inSeconds / (limit * 60)).clamp(0.0, 1.0);
  }

  /// Progress ratio towards the daily global limit clamped between 0.0 and 1.0
  double get limitProgress => _dailyLimitMinutes > 0
      ? (_totalDistractionToday.inSeconds / (_dailyLimitMinutes * 60)).clamp(0.0, 1.0)
      : 0.0;

  /// Remaining duration before hitting the daily limit
  Duration get remainingTime {
    if (_dailyLimitMinutes <= 0) return Duration.zero;
    final limit = Duration(minutes: _dailyLimitMinutes);
    return limit > _totalDistractionToday ? limit - _totalDistractionToday : Duration.zero;
  }

  Timer? _periodicTracker;

  ScreenTimeTracker() {
    init();
  }

  Future<void> init() async {
    await _loadPersistedLimit();
    await checkPermission();
    if (_hasPermission) {
      await refreshUsageStats();
      startPeriodicTracking();
    }
  }

  Future<void> _loadPersistedLimit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dailyLimitMinutes = prefs.getInt('fk_daily_limit_minutes') ?? 60;
      for (final pkg in BlacklistConstants.defaultBlacklist) {
        final lim = prefs.getInt('fk_app_limit_$pkg');
        if (lim != null) {
          _appLimits[pkg] = lim;
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setDailyLimitMinutes(int minutes) async {
    _dailyLimitMinutes = minutes;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('fk_daily_limit_minutes', minutes);
    } catch (_) {}
  }

  Future<void> setAppLimit(String pkg, int minutes) async {
    _appLimits[pkg] = minutes;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('fk_app_limit_$pkg', minutes);
    } catch (_) {}
  }

  Future<bool> checkPermission() async {
    try {
      final granted = await UsageStats.checkUsagePermission() ?? false;
      _hasPermission = granted;
      notifyListeners();
      return _hasPermission;
    } catch (_) {
      _hasPermission = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> requestPermission() async {
    try {
      await UsageStats.grantUsagePermission();
      // Re-check after returning from settings
      await Future.delayed(const Duration(milliseconds: 500));
      await checkPermission();
      if (_hasPermission) {
        await refreshUsageStats();
        startPeriodicTracking();
      }
    } catch (_) {}
  }

  /// Opens the system Usage Access settings screen so users can manage or revoke access
  Future<void> openSettings() async {
    try {
      await UsageStats.openUsageAccessSettings();
      await Future.delayed(const Duration(milliseconds: 500));
      await checkPermission();
      if (_hasPermission) {
        await refreshUsageStats();
        startPeriodicTracking();
      }
    } catch (_) {}
  }

  void startPeriodicTracking() {
    _periodicTracker?.cancel();
    _periodicTracker = Timer.periodic(const Duration(seconds: 3), (timer) {
      refreshUsageStats();
    });
  }

  void stopPeriodicTracking() {
    _periodicTracker?.cancel();
    _periodicTracker = null;
  }

  Future<void> refreshUsageStats() async {
    if (!_hasPermission) return;

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final stats = await UsageStats.queryAndAggregateUsageStats(startOfDay, now);

      int totalMs = 0;
      _appDistractions.clear();

      for (final pkg in BlacklistConstants.defaultBlacklist) {
        if (stats.containsKey(pkg)) {
          final ms = stats[pkg]?.totalTimeInForegroundMs ?? 0;
          if (ms > 0) {
            _appDistractions[pkg] = Duration(milliseconds: ms);
            totalMs += ms;
          }
        }
      }

      _totalDistractionToday = Duration(milliseconds: totalMs);
      notifyListeners();
    } catch (_) {}
  }

  /// Package of the most recent ACTIVITY_RESUMED event at or after [sinceMs].
  static String? latestResumedPackage(List<EventUsageInfo> events, {required int sinceMs, String? ignorePackage}) {
    String? pkg;
    var best = -1;
    for (final e in events) {
      final resumed = e.eventTypeValue == 1 || e.eventType == '1' || e.eventTypeDescription == 'ACTIVITY_RESUMED';
      final t = int.tryParse(e.timeStamp ?? '') ?? 0;
      if (resumed && t >= sinceMs && t > best && e.packageName != ignorePackage) {
        best = t;
        pkg = e.packageName;
      }
    }
    return pkg;
  }

  /// Queries recent usage events to detect if a blacklisted app is currently in the foreground
  Future<String?> getActiveBlacklistedPackage() async {
    if (!_hasPermission) return null;
    try {
      final now = DateTime.now();
      final events = await UsageStats.queryEvents(now.subtract(const Duration(seconds: 12)), now);
      final latestPackage = latestResumedPackage(events, sinceMs: 0);
      if (latestPackage != null && BlacklistConstants.defaultBlacklist.contains(latestPackage)) {
        return latestPackage;
      }
    } catch (_) {}
    return null;
  }

  // ponytail: own applicationId hardcoded; read it from the platform if the id ever changes.
  static const _selfPackage = 'com.example.test_dart';

  /// The other app's RESUMED event lands before Flutter reports `paused`, so look back a bit.
  static const _leftSlack = Duration(seconds: 5);

  DateTime? _leftAt;
  String? _foregroundSinceLeft;

  /// Call when FocusKnight goes to the background.
  void markLeftApp() {
    _leftAt = DateTime.now();
    _foregroundSinceLeft = null;
  }

  /// App the user switched to after leaving FocusKnight (null = none yet, e.g. screen locked).
  /// Remembered between polls, so staying in one app longer than the query window still counts.
  Future<String?> foregroundSinceLeft() async {
    final leftAt = _leftAt;
    if (!_hasPermission || leftAt == null) return null;
    try {
      final now = DateTime.now();
      final windowStart = now.subtract(const Duration(seconds: 15));
      final since = leftAt.subtract(_leftSlack);
      final events = await UsageStats.queryEvents(since.isAfter(windowStart) ? since : windowStart, now);
      final pkg =
          latestResumedPackage(events, sinceMs: since.millisecondsSinceEpoch, ignorePackage: _selfPackage);
      if (pkg != null) _foregroundSinceLeft = pkg;
    } catch (_) {}
    return _foregroundSinceLeft;
  }

  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  @override
  void dispose() {
    _periodicTracker?.cancel();
    super.dispose();
  }
}
