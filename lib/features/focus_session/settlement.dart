import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/game/player_state.dart';
import '../dashboard/services/focus_history_service.dart';

/// Write-ahead journal for paying out a won battle. SharedPreferences has no transactions,
/// so the whole payout is written first and each step is marked done; [resume] finishes
/// a payout that was cut short (e.g. the app was killed) without applying anything twice.
class Settlement {
  static const key = 'fk_pending_settlement';

  static Future<void> commit({
    required int coins,
    required int logs,
    required List<int> sessionSeconds,
    required PlayerState player,
    required FocusHistoryService history,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode({'coins': coins, 'logs': logs, 'seconds': sessionSeconds, 'recorded': 0, 'deposited': false}),
    );
    await resume(player, history);
  }

  static Future<void> resume(PlayerState player, FocusHistoryService history) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final seconds = (j['seconds'] as List).cast<int>();

    for (var i = j['recorded'] as int; i < seconds.length; i++) {
      await history.recordCompletedSession(seconds[i]);
      j['recorded'] = i + 1;
      await prefs.setString(key, jsonEncode(j));
    }
    // ponytail: a kill between a step and its marker repeats that one step; per-key atomic
    // writes would need a real database.
    if (j['deposited'] != true) {
      await player.deposit(coins: j['coins'] as int, logs: j['logs'] as int);
      j['deposited'] = true;
      await prefs.setString(key, jsonEncode(j));
    }
    await prefs.remove(key);
  }
}
