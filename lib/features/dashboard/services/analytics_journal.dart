import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:usage_stats/usage_stats.dart';

import '../../../core/services/persistent_preferences.dart';
import 'analytics_calculations.dart';
import '../../telemetry/screen_time_tracker.dart';

/// Independent of battle rewards. Each session is a separate durable preference.
class AnalyticsJournal extends ChangeNotifier {
  static final instance = AnalyticsJournal();
  static const prefix = 'fk_analytics_v1_session_';
  static const goalsKey = 'fk_analytics_v1_goals';
  Future<void> _pending = Future.value();
  String? error;
  final _failed =
      <String, ({Map<String, dynamic> session, bool collectUsage})>{};
  Future<void> get flushed => _pending;
  Future<void> retryFailed() async {
    for (final pending in _failed.values.toList()) {
      save(pending.session, collectUsage: pending.collectUsage);
    }
    await flushed;
  }

  void save(Map<String, dynamic> session, {bool collectUsage = false}) {
    final snapshot = jsonEncode(session);
    final id = session['id'] as String;
    _pending = _pending.then((_) async {
      try {
        final prefs = await loadPersistentPreferences();
        final record = Map<String, dynamic>.from(jsonDecode(snapshot) as Map);
        if (collectUsage && record['monitored'] == true) {
          try {
            if (await UsageStats.checkUsagePermission() != true) {
              throw StateError('Usage Access unavailable');
            }
            final sample = SessionSample.parse(snapshot);
            if (sample == null) throw StateError('Invalid session');
            final apps = ScreenTimeTracker.readTrackedApps(prefs).keys.toSet();
            final usage = await UsageStats.queryEvents(
              sample.start,
              sample.end,
            );
            usage.sort(
              (a, b) => (int.tryParse(a.timeStamp ?? '') ?? 0).compareTo(
                int.tryParse(b.timeStamp ?? '') ?? 0,
              ),
            );
            final visits = <String>[];
            var state = ForegroundUsageState();
            for (final event in usage) {
              final previous = state.activePackage;
              state = ScreenTimeTracker.reduceForegroundEvents(state, [event]);
              final stamp = int.tryParse(event.timeStamp ?? '');
              if (stamp == null ||
                  state.activePackage == previous ||
                  !apps.contains(state.activePackage)) {
                continue;
              }
              final at = DateTime.fromMillisecondsSinceEpoch(stamp);
              if (sample.intervals.any(
                (i) => !at.isBefore(i.start) && at.isBefore(i.end),
              )) {
                visits.add(at.toUtc().toIso8601String());
              }
            }
            record['interruptions'] = visits;
          } catch (_) {
            record['monitored'] = false;
          }
        }
        if (!await prefs.setString('$prefix$id', jsonEncode(record))) {
          throw StateError('Không lưu được nhật ký');
        }
        _failed.remove(id);
        error = _failed.isEmpty
            ? null
            : 'Một số phiên chưa được lưu. Hãy thử lại.';
      } catch (e) {
        invalidatePreferenceCache();
        _failed[id] = (
          session: Map<String, dynamic>.from(jsonDecode(snapshot) as Map),
          collectUsage: collectUsage,
        );
        error = 'Không lưu được dữ liệu phân tích: $e';
      }
      notifyListeners();
    });
  }

  Future<void> setGoal(int? minutes, DateTime now) async {
    if (minutes != null && (minutes < 1 || minutes > 1440)) {
      throw ArgumentError('Mục tiêu 1–1440 phút');
    }
    final prefs = await loadPersistentPreferences();
    final goals = Map<String, dynamic>.from(
      jsonDecode(prefs.getString(goalsKey) ?? '{}') as Map,
    );
    goals[dateKey(nextDay(now))] = minutes == null ? null : minutes * 60;
    try {
      if (!await prefs.setString(goalsKey, jsonEncode(goals))) {
        throw StateError('Không lưu được mục tiêu');
      }
    } catch (_) {
      invalidatePreferenceCache();
      rethrow;
    }
    notifyListeners();
  }
}

class SessionSample {
  SessionSample(this.raw);
  final Map<String, dynamic> raw;
  String get id => raw['id'] as String;
  late final start = DateTime.parse(raw['start'] as String).toLocal();
  late final end = DateTime.parse(raw['end'] as String).toLocal();
  int get target => raw['target'] as int;
  bool get completed => raw['outcome'] == 'completed';
  bool get monitored => raw['monitored'] == true;
  late final intervals = <({DateTime start, DateTime end})>[
    for (final i in raw['intervals'] as List)
      (
        start: DateTime.parse(i['start'] as String).toLocal(),
        end: DateTime.parse(i['end'] as String).toLocal(),
      ),
  ];
  late final interruptions = <DateTime>[
    for (final s in raw['interruptions'] as List)
      DateTime.parse(s as String).toLocal(),
  ];
  late final pauses = <DateTime>[
    for (final s in raw['pauses'] as List)
      DateTime.parse(s as String).toLocal(),
  ];
  late final seconds = intervals.fold<double>(
    0,
    (s, i) => s + i.end.difference(i.start).inMicroseconds / 1e6,
  );
  SurvivalObservation get observation {
    final firstEvent = interruptions.isEmpty ? null : interruptions.first;
    final pause = pauses.isEmpty ? null : pauses.first;
    final cutoff = pause != null && pause.isBefore(end) ? pause : end;
    final event = firstEvent != null && !firstEvent.isAfter(cutoff);
    return (
      minutes:
          (event ? firstEvent : cutoff).difference(start).inMicroseconds / 6e7,
      event: event,
    );
  }

  static SessionSample? parse(String raw) {
    try {
      final s = SessionSample(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      if (s.id.isEmpty) return null;
      if (s.raw['end'] == null) return null;
      if (s.target <= 0 ||
          s.end.isBefore(s.start) ||
          !{'completed', 'cancelled', 'defeated'}.contains(s.raw['outcome'])) {
        return null;
      }
      var previous = s.start;
      for (final i in s.intervals) {
        if (i.start.isBefore(previous) ||
            i.end.isBefore(i.start) ||
            i.end.isAfter(s.end)) {
          return null;
        }
        previous = i.end;
      }
      for (final times in [s.interruptions, s.pauses]) {
        previous = s.start;
        for (final t in times) {
          if (t.isBefore(previous) || t.isAfter(s.end)) return null;
          previous = t;
        }
      }
      if (s.seconds <= 0) return null;
      return s;
    } catch (_) {
      return null;
    }
  }
}
