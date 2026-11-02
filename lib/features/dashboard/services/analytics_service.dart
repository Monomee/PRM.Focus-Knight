import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:usage_stats/usage_stats.dart';

import '../../../core/services/persistent_preferences.dart';
import '../../telemetry/screen_time_tracker.dart';
import 'analytics_calculations.dart';
import 'analytics_journal.dart';
import 'focus_history_service.dart';

class DayCorrelationData {
  const DayCorrelationData({
    required this.dayLabel,
    required this.date,
    required this.socialHours,
    required this.focusHours,
    required this.completionRate,
    this.hasGoal = false,
  });
  final String dayLabel;
  final DateTime date;
  final double? socialHours;
  final double focusHours, completionRate;
  final bool hasGoal;
}

class DistractionVelocityData {
  const DistractionVelocityData({
    required this.velocityPerHour,
    required this.totalInterruptions,
    required this.focusWorkHours,
    required this.levelKey,
    required this.levelLabel,
    required this.weeklyTrend,
    this.previousRate,
    this.dates = const [],
    this.dailySeconds = const [],
    this.dailyEvents = const [],
  });
  final double? velocityPerHour, previousRate;
  final int totalInterruptions;
  final double focusWorkHours;
  final String levelKey, levelLabel;
  final List<double?> weeklyTrend;
  final List<DateTime> dates;
  final List<double> dailySeconds;
  final List<int> dailyEvents;
  double? get changePercent =>
      previousRate == null || previousRate == 0 || velocityPerHour == null
      ? null
      : (velocityPerHour! / previousRate! - 1) * 100;
}

class GoldenCell {
  final sessions = <String>{};
  double seconds = 0, weightedScore = 0;
  double? get score =>
      sessions.length < 3 || seconds <= 0 ? null : weightedScore / seconds;
}

class GoldenHoursData {
  GoldenHoursData(this.cells);
  final List<GoldenCell> cells;
  int? get best {
    int? result;
    for (var i = 0; i < cells.length; i++) {
      if (cells[i].score != null &&
          (result == null || cells[i].score! > cells[result].score!)) {
        result = i;
      }
    }
    return result;
  }

  String get peakTimeSlot =>
      best == null ? '' : '${weekdays[best! % 7]} ${slotLabels[best! ~/ 7]}';
  double get peakEfficiency => best == null ? 0 : cells[best!].score!;
  String get recommendation =>
      '${best == null ? 'Chưa đủ dữ liệu: ' : ''}Cần ít nhất 3 phiên/ô. Điểm = 50% hoàn thành + 50% thời gian thực tế/mục tiêu phiên, tính trung bình có trọng số theo số giây thuộc ô.';
  Map<String, double> get blockProductivity => {
    for (var s = 0; s < 7; s++)
      slotLabels[s]: cells
          .skip(s * 7)
          .take(7)
          .map((c) => c.score ?? 0)
          .reduce(math.max),
  };
}

class AnalyticsService extends ChangeNotifier {
  static AnalyticsService? _instance;
  static AnalyticsService get instance => _instance ??= AnalyticsService();
  AnalyticsService({
    FocusHistoryService? history,
    DateTime Function()? clock,
    this.minimumCorrelationPairs = 7,
  }) : _history = history ?? FocusHistoryService.instance,
       _clock = clock ?? DateTime.now,
       _previewUsage = null {
    _history!.addListener(_changed);
    AnalyticsJournal.instance.addListener(_changed);
  }
  AnalyticsService.fromSamples({
    required List<SessionSample> samples,
    required Map<String, int?> dailyGoals,
    required Map<String, double> appUsageHours,
    required DateTime now,
    this.minimumCorrelationPairs = 7,
  }) : _history = null,
       _clock = (() => now),
       _previewUsage = Map.unmodifiable(appUsageHours) {
    sessions = List.unmodifiable(samples);
    goals = Map.of(dailyGoals);
    _aggregateSessions(const {}, now);
    _updatePreviewCorrelation();
  }
  final FocusHistoryService? _history;
  final Map<String, double>? _previewUsage;
  bool get isDemo => _previewUsage != null;
  DateTime get referenceDate => _clock();
  final DateTime Function() _clock;
  final int minimumCorrelationPairs;
  bool isLoading = false;
  String? error;
  int correlationRange = 7;
  Map<String, DailyFocus> days = {};
  List<SessionSample> sessions = [];
  Map<String, dynamic> goals = {};
  List<DayCorrelationData> correlationDays = [];
  GoldenHoursData goldenHours = GoldenHoursData(
    List.generate(49, (_) => GoldenCell()),
  );
  DistractionVelocityData distractionVelocity = const DistractionVelocityData(
    velocityPerHour: null,
    totalInterruptions: 0,
    focusWorkHours: 0,
    levelKey: 'NO_DATA',
    levelLabel: 'Chưa đủ dữ liệu',
    weeklyTrend: [],
  );
  SurvivalEstimate endurance = SurvivalEstimate.calculate([]);
  double? uninterruptedRate;
  int invalidSessions = 0;
  final _sampleCache = <String, ({String raw, SessionSample? sample})>{};
  Future<void>? _refresh;
  bool _dirty = false, _disposed = false;
  void _changed() {
    if (_refresh != null) {
      _dirty = true;
    } else {
      refreshAnalytics();
    }
  }

  Future<void> refreshAnalytics() {
    if (isDemo) {
      _updatePreviewCorrelation();
      notifyListeners();
      return Future.value();
    }
    return _refresh ??= _load().whenComplete(() {
      _refresh = null;
      if (_dirty && !_disposed) {
        _dirty = false;
        refreshAnalytics();
      }
    });
  }

  void _updatePreviewCorrelation() {
    final today = dayOf(_clock());
    correlationDays = [
      for (var i = correlationRange; i >= 1; i--)
        _previewDay(nextDay(today, -i)),
    ];
  }

  DayCorrelationData _previewDay(DateTime date) {
    final value = day(date);
    return DayCorrelationData(
      dayLabel: weekdays[date.weekday - 1],
      date: date,
      socialHours: _previewUsage![dateKey(date)],
      focusHours: value.seconds / 3600,
      completionRate: value.progress ?? 0,
      hasGoal: value.goalSeconds != null,
    );
  }

  Future<void> setCorrelationRange(int range) async {
    if (range != 7 && range != 30) throw ArgumentError('7 hoặc 30 ngày');
    correlationRange = range;
    _changed();
    while (_refresh != null) {
      await _refresh;
    }
  }

  int? goalFor(DateTime date) {
    final keys =
        goals.keys.where((k) => k.compareTo(dateKey(date)) <= 0).toList()
          ..sort();
    final value = keys.isEmpty ? null : goals[keys.last];
    return value is int && value > 0 ? value : null;
  }

  DailyFocus day(DateTime date) =>
      days[dateKey(date)] ?? DailyFocus(goalSeconds: goalFor(date));
  ({int current, int longest}) get streaks =>
      goalStreaks({...days, dateKey(_clock()): day(_clock())}, _clock());
  double? monthlyRate(DateTime month) {
    var total = 0, achieved = 0;
    final today = dayOf(_clock());
    for (
      var d = DateTime(month.year, month.month);
      d.month == month.month;
      d = nextDay(d)
    ) {
      final value = day(d);
      if (d.isAfter(today) ||
          value.goalSeconds == null ||
          (d == today && !value.achieved)) {
        continue;
      }
      total++;
      if (value.achieved) achieved++;
    }
    return total == 0 ? null : achieved / total;
  }

  void _aggregateSessions(Map legacy, DateTime now) {
    final today = dayOf(now);
    final actual = <String, DailyFocus>{};
    final creditedIds = (legacy['analyticsIds'] as List? ?? [])
        .cast<String>()
        .toSet();
    final creditBreakdowns = legacy['analyticsCredits'] as Map? ?? {};
    final credited = <String, DailyFocus>{};
    final monitoredSeconds = <String, double>{}, events = <String, int>{};
    goldenHours = GoldenHoursData(List.generate(49, (_) => GoldenCell()));
    final observations = <SurvivalObservation>[];
    var monitored = 0, uninterrupted = 0;
    for (final s in sessions) {
      final score =
          0.5 * (s.completed ? 1 : 0) +
          0.5 * (s.seconds / s.target).clamp(0, 1);
      for (final interval in s.intervals) {
        for (final part in splitInterval(interval.start, interval.end)) {
          final key = dateKey(part.date);
          (actual[key] ??= DailyFocus(
            goalSeconds: goalFor(part.date),
          )).seconds += part.seconds;
          if (creditedIds.contains(s.id) &&
              !creditBreakdowns.containsKey(s.id)) {
            (credited[key] ??= DailyFocus()).seconds += part.seconds;
          }
          if (s.monitored) {
            monitoredSeconds[key] = (monitoredSeconds[key] ?? 0) + part.seconds;
          }
          if (!part.date.isBefore(nextDay(today, -29)) &&
              !part.date.isAfter(today)) {
            final cell =
                goldenHours.cells[part.slot * 7 + part.date.weekday - 1];
            cell.sessions.add(s.id);
            cell.seconds += part.seconds;
            cell.weightedScore += score * part.seconds;
          }
        }
      }
      final terminal = actual.putIfAbsent(
        dateKey(s.end),
        () => DailyFocus(goalSeconds: goalFor(s.end)),
      );
      if (s.completed) {
        terminal.completed++;
        if (creditedIds.contains(s.id) && !creditBreakdowns.containsKey(s.id)) {
          (credited[dateKey(s.end)] ??= DailyFocus()).completed++;
        }
      } else {
        terminal.incomplete++;
      }
      if (creditedIds.contains(s.id) && creditBreakdowns.containsKey(s.id)) {
        final credit = creditBreakdowns[s.id] as Map;
        for (final e in (credit['days'] as Map).entries) {
          (credited[e.key as String] ??= DailyFocus()).seconds +=
              (e.value as num).toDouble();
        }
        (credited[credit['completedDay'] as String] ??= DailyFocus())
            .completed++;
      }
      if (s.monitored) {
        for (final t in s.interruptions) {
          final key = dateKey(t);
          events[key] = (events[key] ?? 0) + 1;
        }
        if (!s.end.isBefore(nextDay(today, -29)) && !s.end.isAfter(now)) {
          monitored++;
          observations.add(s.observation);
          if (s.completed && s.interruptions.isEmpty && s.pauses.isEmpty) {
            uninterrupted++;
          }
        }
      }
    }
    for (final key in credited.keys) {
      actual.putIfAbsent(
        key,
        () => DailyFocus(goalSeconds: goalFor(DateTime.parse(key))),
      );
    }
    for (final e in actual.entries) {
      final old = days[e.key];
      e.value.seconds =
          (old?.seconds ?? 0) +
          e.value.seconds -
          (credited[e.key]?.seconds ?? 0);
      e.value.completed =
          (old?.completed ?? 0) +
          e.value.completed -
          (credited[e.key]?.completed ?? 0);
      days[e.key] = e.value;
    }
    endurance = SurvivalEstimate.calculate(observations);
    uninterruptedRate = monitored == 0 ? null : uninterrupted / monitored;
    double sumSeconds(int from, int to) => [
      for (var i = from; i <= to; i++)
        monitoredSeconds[dateKey(nextDay(today, i))] ?? 0,
    ].fold(0, (a, b) => a + b);
    int sumEvents(int from, int to) => [
      for (var i = from; i <= to; i++) events[dateKey(nextDay(today, i))] ?? 0,
    ].fold(0, (a, b) => a + b);
    final sec = sumSeconds(-6, 0), count = sumEvents(-6, 0);
    distractionVelocity = DistractionVelocityData(
      velocityPerHour: distractionRate(count, sec),
      totalInterruptions: count,
      focusWorkHours: sec / 3600,
      levelKey: sec > 0 ? 'OBSERVED' : 'NO_DATA',
      levelLabel: sec > 0 ? 'Lượt mở ứng dụng đã chọn' : 'Chưa đủ dữ liệu',
      weeklyTrend: [
        for (var i = -6; i <= 0; i++)
          distractionRate(
            events[dateKey(nextDay(today, i))] ?? 0,
            monitoredSeconds[dateKey(nextDay(today, i))] ?? 0,
          ),
      ],
      previousRate: distractionRate(sumEvents(-13, -7), sumSeconds(-13, -7)),
      dates: [for (var i = -6; i <= 0; i++) nextDay(today, i)],
      dailySeconds: [
        for (var i = -6; i <= 0; i++)
          monitoredSeconds[dateKey(nextDay(today, i))] ?? 0,
      ],
      dailyEvents: [
        for (var i = -6; i <= 0; i++) events[dateKey(nextDay(today, i))] ?? 0,
      ],
    );
  }

  Future<void> _load() async {
    final range = correlationRange;
    isLoading = true;
    if (!_disposed) notifyListeners();
    try {
      final prefs = await loadPersistentPreferences();
      final now = _clock(), today = dayOf(_clock());
      goals = Map<String, dynamic>.from(
        jsonDecode(prefs.getString(AnalyticsJournal.goalsKey) ?? '{}') as Map,
      );
      final legacy = jsonDecode(
        prefs.getString('fk_history_settlement_state') ?? '{}',
      ) as Map;
      final legacyDays = Map<String, dynamic>.from(
        legacy['days'] as Map? ?? {},
      );
      final legacyCounts = Map<String, dynamic>.from(
        legacy['counts'] as Map? ?? {},
      );
      days = {};
      sessions = [];
      invalidSessions = 0;
      for (final key in prefs.getKeys()) {
        if (key.startsWith('fk_focus_sec_')) {
          legacyDays.putIfAbsent(
            key.substring(13),
            () => prefs.getInt(key) ?? 0,
          );
        }
        if (key.startsWith('fk_session_count_')) {
          legacyCounts.putIfAbsent(
            key.substring(17),
            () => prefs.getInt(key) ?? 0,
          );
        }
        if (key.startsWith(AnalyticsJournal.prefix)) {
          final raw = prefs.getString(key)!;
          final cached = _sampleCache[key];
          final sample = cached?.raw == raw
              ? cached?.sample
              : SessionSample.parse(raw);
          _sampleCache[key] = (raw: raw, sample: sample);
          if (sample != null) {
            sessions.add(sample);
          } else {
            invalidSessions++;
          }
        }
      }
      for (final e in legacyDays.entries) {
        final date = DateTime.tryParse(e.key);
        if (date != null && e.value is num && (e.value as num) >= 0) {
          days[e.key] = DailyFocus(
            seconds: (e.value as num).toDouble(),
            goalSeconds: goalFor(date),
            completed: legacyCounts[e.key] as int? ?? 0,
          );
        }
      }
      _aggregateSessions(legacy, now);
      final apps = ScreenTimeTracker.readTrackedApps(prefs).keys.toSet();
      var permission = false;
      try {
        permission = await UsageStats.checkUsagePermission() ?? false;
      } catch (_) {
        /* Unsupported platform. */
      }
      List<EventUsageInfo> usage = [];
      if (permission && apps.isNotEmpty && goals.isNotEmpty) {
        try {
          usage = await UsageStats.queryEvents(
            nextDay(today, -range - 1),
            today,
          );
        } catch (_) {
          permission = false;
        }
      }
      final result = <DayCorrelationData>[];
      for (var i = range; i >= 1; i--) {
        final date = nextDay(today, -i), d = day(nextDay(today, -i));
        double? hours;
        if (permission && apps.isNotEmpty && d.goalSeconds != null) {
          try {
            // Empty OS history is unknown, not proof of zero usage.
            final seeded = usage.any(
              (e) =>
                  (int.tryParse(e.timeStamp ?? '') ??
                      date.millisecondsSinceEpoch) <
                  date.millisecondsSinceEpoch,
            );
            if (seeded &&
                usage.any((e) {
                  final t = int.tryParse(e.timeStamp ?? '');
                  return t != null &&
                      const {1, 2, 15, 16, 17, 18}.contains(
                        e.eventTypeValue ?? int.tryParse(e.eventType ?? ''),
                      ) &&
                      t >= date.millisecondsSinceEpoch &&
                      t < nextDay(date).millisecondsSinceEpoch;
                })) {
              final totals = ScreenTimeTracker.usageDurations(
                usage,
                start: date,
                end: nextDay(date),
                trackedPackages: apps,
              );
              hours =
                  totals.values.fold<double>(
                    0,
                    (a, b) => a + b.inMilliseconds,
                  ) /
                  3600000;
            }
          } catch (_) {
            /* Missing OS retention or permission. */
          }
        }
        result.add(
          DayCorrelationData(
            dayLabel: weekdays[date.weekday - 1],
            date: date,
            socialHours: hours,
            focusHours: d.seconds / 3600,
            completionRate: d.progress ?? 0,
            hasGoal: d.goalSeconds != null,
          ),
        );
      }
      correlationDays = result;
      error = AnalyticsJournal.instance.error;
    } catch (e) {
      error = 'Không tải được dữ liệu phân tích: $e';
    }
    isLoading = false;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _history?.removeListener(_changed);
    if (!isDemo) AnalyticsJournal.instance.removeListener(_changed);
    super.dispose();
  }
}
