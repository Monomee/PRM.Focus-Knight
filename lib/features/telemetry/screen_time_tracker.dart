import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usage_stats/usage_stats.dart';

import '../../core/constants/blacklist_constants.dart';

class ForegroundUsageState {
  ForegroundUsageState({
    this.packageName,
    this.isInteractive = true,
    this.isKeyguardShown = false,
  });

  String? packageName;
  bool isInteractive;
  bool isKeyguardShown;

  String? get activePackage =>
      isInteractive && !isKeyguardShown ? packageName : null;

  ForegroundUsageState copy() => ForegroundUsageState(
    packageName: packageName,
    isInteractive: isInteractive,
    isKeyguardShown: isKeyguardShown,
  );

  void reset() {
    packageName = null;
    isInteractive = true;
    isKeyguardShown = false;
  }
}

/// Service monitoring screen-time for blacklisted entertainment/social apps using usage_stats
class ScreenTimeTracker extends ChangeNotifier {
  bool _hasPermission = false;
  bool get hasPermission => _hasPermission;

  Duration _totalDistractionToday = Duration.zero;
  Duration get totalDistractionToday => _totalDistractionToday;

  final Map<String, Duration> _appDistractions = {};
  Map<String, Duration> get appDistractions =>
      Map.unmodifiable(_appDistractions);

  int _dailyLimitMinutes = 60;
  int get dailyLimitMinutes => _dailyLimitMinutes;

  final Map<String, int> _appLimits = {};
  Map<String, int> get appLimits => Map.unmodifiable(_appLimits);

  /// Gets the individual daily limit in minutes for a specific package (falls back to global limit)
  int getAppLimit(String pkg) => _appLimits[pkg] ?? _dailyLimitMinutes;

  /// Whether distraction screen-time today has exceeded the daily global limit
  bool get isLimitExceeded =>
      _dailyLimitMinutes > 0 &&
      _totalDistractionToday.inMinutes >= _dailyLimitMinutes;

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
      ? (_totalDistractionToday.inSeconds / (_dailyLimitMinutes * 60)).clamp(
          0.0,
          1.0,
        )
      : 0.0;

  /// Remaining duration before hitting the daily limit
  Duration get remainingTime {
    if (_dailyLimitMinutes <= 0) return Duration.zero;
    final limit = Duration(minutes: _dailyLimitMinutes);
    return limit > _totalDistractionToday
        ? limit - _totalDistractionToday
        : Duration.zero;
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
      final stats = await UsageStats.queryAndAggregateUsageStats(
        startOfDay,
        now,
      );

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

  static const _leftSlack = Duration(seconds: 5);
  static const _eventOverlap = Duration(seconds: 5);

  final ForegroundUsageState _foreground = ForegroundUsageState();
  final Map<String, int> _processedEvents = {};
  DateTime? _leftAt;
  int? _eventCursorMs;
  Future<String?>? _foregroundPoll;
  int _foregroundGeneration = 0;

  static ForegroundUsageState reduceForegroundEvents(
    ForegroundUsageState initial,
    List<EventUsageInfo> events, {
    int sinceMs = 0,
  }) {
    final state = initial.copy();
    final ordered =
        events.where((event) {
          final timestamp = int.tryParse(event.timeStamp ?? '') ?? 0;
          return timestamp >= sinceMs;
        }).toList()..sort((a, b) {
          final aTime = int.tryParse(a.timeStamp ?? '') ?? 0;
          final bTime = int.tryParse(b.timeStamp ?? '') ?? 0;
          return aTime.compareTo(bTime);
        });

    for (final event in ordered) {
      final type = event.eventTypeValue ?? int.tryParse(event.eventType ?? '');
      final package = event.packageName;
      switch (type) {
        case 1:
          state
            ..packageName = package
            ..isInteractive = true
            ..isKeyguardShown = false;
        case 2:
          if (package == null || package == state.packageName) {
            state.packageName = null;
          }
        case 15:
          state.isInteractive = true;
        case 16:
          state
            ..isInteractive = false
            ..packageName = null;
        case 17:
          state
            ..isKeyguardShown = true
            ..packageName = null;
        case 18:
          state.isKeyguardShown = false;
      }
    }
    return state;
  }

  static String eventIdentity(EventUsageInfo event) {
    final type = event.eventTypeValue ?? int.tryParse(event.eventType ?? '');
    return '${event.timeStamp}|$type|${event.packageName ?? ''}';
  }

  static List<EventUsageInfo> unseenForegroundEvents(
    List<EventUsageInfo> events,
    Set<String> processed,
  ) {
    final unseen = <EventUsageInfo>[];
    for (final event in events) {
      if (processed.add(eventIdentity(event))) unseen.add(event);
    }
    return unseen;
  }

  void markLeftApp() {
    _leftAt = DateTime.now();
    _eventCursorMs = null;
    _processedEvents.clear();
    _foreground.reset();
    _foregroundGeneration++;
    _foregroundPoll = null;
  }

  Future<String?> _pollForeground({required DateTime earliest}) {
    final active = _foregroundPoll;
    if (active != null) return active;
    final generation = _foregroundGeneration;
    final poll = _performForegroundPoll(
      earliest: earliest,
      generation: generation,
    );
    _foregroundPoll = poll;
    poll.whenComplete(() {
      if (identical(_foregroundPoll, poll)) _foregroundPoll = null;
    });
    return poll;
  }

  Future<String?> _performForegroundPoll({
    required DateTime earliest,
    required int generation,
  }) async {
    if (!_hasPermission) return null;
    try {
      final now = DateTime.now();
      final cursor = _eventCursorMs;
      final startMs = cursor == null
          ? earliest.millisecondsSinceEpoch
          : cursor - _eventOverlap.inMilliseconds;
      final events = await UsageStats.queryEvents(
        DateTime.fromMillisecondsSinceEpoch(startMs),
        now,
      );
      if (generation != _foregroundGeneration) {
        return _foreground.activePackage;
      }
      final unseen = unseenForegroundEvents(
        events,
        _processedEvents.keys.toSet(),
      );
      for (final event in unseen) {
        _processedEvents[eventIdentity(event)] =
            int.tryParse(event.timeStamp ?? '') ?? 0;
      }
      final next = reduceForegroundEvents(
        _foreground,
        unseen,
        sinceMs: startMs,
      );
      _foreground
        ..packageName = next.packageName
        ..isInteractive = next.isInteractive
        ..isKeyguardShown = next.isKeyguardShown;
      _eventCursorMs = now.millisecondsSinceEpoch;
      final retentionStart = startMs - _eventOverlap.inMilliseconds;
      _processedEvents.removeWhere(
        (_, timestamp) => timestamp < retentionStart,
      );
    } catch (_) {}
    return _foreground.activePackage;
  }

  Future<String?> getActiveBlacklistedPackage() async {
    final package = await _pollForeground(
      earliest: DateTime.now().subtract(const Duration(seconds: 15)),
    );
    return BlacklistConstants.defaultBlacklist.contains(package)
        ? package
        : null;
  }

  Future<String?> foregroundSinceLeft() async {
    final leftAt = _leftAt;
    if (leftAt == null) return null;
    return _pollForeground(earliest: leftAt.subtract(_leftSlack));
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
