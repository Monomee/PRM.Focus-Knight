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
  }) {
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
      for (var i = settlement['recorded'] as int; i < seconds.length; i++) {
        await history.recordCompletedSession(
          seconds[i],
          settlementId: '$id:history:$i',
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
