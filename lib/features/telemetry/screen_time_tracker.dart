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

  /// Queries recent usage events to detect if a blacklisted app is currently in the foreground
  Future<String?> getActiveBlacklistedPackage() async {
    if (!_hasPermission) return null;
    try {
      final now = DateTime.now();
      final events = await UsageStats.queryEvents(
        now.subtract(const Duration(seconds: 12)),
        now,
      );
      if (events.isEmpty) return null;

      final resumedEvents = events.where((e) {
        return e.eventTypeValue == 1 ||
            e.eventType == '1' ||
            e.eventTypeDescription == 'ACTIVITY_RESUMED';
      }).toList();

      if (resumedEvents.isEmpty) return null;

      resumedEvents.sort((a, b) {
        final tA = int.tryParse(a.timeStamp ?? '0') ?? 0;
        final tB = int.tryParse(b.timeStamp ?? '0') ?? 0;
        return tB.compareTo(tA);
      });

      final latestPackage = resumedEvents.first.packageName;
      if (latestPackage != null && BlacklistConstants.defaultBlacklist.contains(latestPackage)) {
        return latestPackage;
      }
    } catch (_) {}
    return null;
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
