import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/game/player_state.dart';
import '../dashboard/services/focus_history_service.dart';
import '../../core/services/persistent_preferences.dart';

class Settlement {
  static const key = 'fk_pending_settlement';
  static Future<void> _serial = Future.value();
  static int _sequence = 0;

  static Future<T> _locked<T>(Future<T> Function() action) {
    final result = _serial.then((_) => action());
    _serial = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  static Future<void> commit({
    required int coins,
    required int logs,
    required List<int> sessionSeconds,
    required PlayerState player,
    required FocusHistoryService history,
    String? settlementId,
    List<List<FocusInterval>>? sessionIntervals,
    String? constructionId,
  }) {
    if (sessionIntervals != null &&
        sessionIntervals.length != sessionSeconds.length) {
      throw ArgumentError('Every completed session must have focus intervals');
    }
    return _locked(() async {
      final prefs = await loadPersistentPreferences();
      final queue = _readQueue(prefs.getString(key));
      final id =
          settlementId ??
          '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
      if (!queue.any((entry) => entry['id'] == id)) {
        queue.add({
          'id': id,
          'coins': coins,
          'logs': logs,
          'seconds': sessionSeconds,
          'constructionId': ?constructionId,
          if (sessionIntervals != null)
            'intervals': [
              for (final session in sessionIntervals)
                [
                  for (final interval in session)
                    {
                      'start': interval.start.toUtc().toIso8601String(),
                      'end': interval.end.toUtc().toIso8601String(),
                    },
                ],
            ],
          'recorded': 0,
          'deposited': false,
        });
      }
      await _writeQueue(prefs, queue);
      await _resume(prefs, player, history);
    });
  }

  static Future<void> resume(PlayerState player, FocusHistoryService history) {
    return _locked(() async {
      final prefs = await loadPersistentPreferences();
      await _resume(prefs, player, history);
    });
  }

  static Future<void> _resume(
    SharedPreferences prefs,
    PlayerState player,
    FocusHistoryService history,
  ) async {
    final queue = _readQueue(prefs.getString(key));
    while (queue.isNotEmpty) {
      final settlement = queue.first;
      final id = settlement['id'] as String;
      final seconds = (settlement['seconds'] as List).cast<int>();
      final intervals = settlement['intervals'] as List?;
      if (intervals != null && intervals.length != seconds.length) {
        throw const FormatException('Incomplete settlement timestamps');
      }
      for (var i = settlement['recorded'] as int; i < seconds.length; i++) {
        await history.recordCompletedSession(
          seconds[i],
          settlementId: '$id:history:$i',
          intervals: intervals == null
              ? null
              : [
                  for (final interval in intervals[i] as List)
                    (
                      start: DateTime.parse(interval['start'] as String)
                          .toLocal(),
                      end: DateTime.parse(interval['end'] as String).toLocal(),
                    ),
                ],
        );
        settlement['recorded'] = i + 1;
        await _writeQueue(prefs, queue);
      }
      if (settlement['deposited'] != true) {
        await player.deposit(
          coins: settlement['coins'] as int,
          logs: settlement['logs'] as int,
          settlementId: '$id:deposit',
        );
        settlement['deposited'] = true;
        await _writeQueue(prefs, queue);
      }
      final constructionId = settlement['constructionId'] as String?;
      if (constructionId != null) {
        await player.finishConstruction(constructionId, won: true);
      }
      queue.removeAt(0);
      await _writeQueue(prefs, queue);
    }
  }

  static List<Map<String, dynamic>> _readQueue(String? raw) {
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }
    final legacy = Map<String, dynamic>.from(decoded as Map);
    legacy['id'] ??= 'legacy';
    return [legacy];
  }

  static Future<void> _writeQueue(
    SharedPreferences prefs,
    List<Map<String, dynamic>> queue,
  ) async {
    try {
      final saved = queue.isEmpty
          ? await prefs.remove(key)
          : await prefs.setString(key, jsonEncode(queue));
      if (!saved) throw StateError('Failed to save settlement queue');
    } catch (_) {
      invalidatePreferenceCache();
      rethrow;
    }
  }
}
