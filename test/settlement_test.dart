import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/core/game/player_state.dart';
import 'package:test_dart/features/focus_session/settlement.dart';
import 'package:test_dart/features/dashboard/services/focus_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(PlayerState, FocusHistoryService)> load(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final player = PlayerState();
    await player.load();
    final history = FocusHistoryService();
    await history.loadData();
    return (player, history);
  }

  test('commit applies everything and clears the journal', () async {
    final (player, history) = await load({});
    await Settlement.commit(coins: 60, logs: 24, sessionSeconds: [1500, 1500], player: player, history: history);
    expect(player.coins, 60);
    expect(player.logs, 24);
    expect(history.totalFocusSecondsAllTime, 3000);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(Settlement.key), isNull);
  });

  test('resume finishes an interrupted settlement exactly once', () async {
    final journal = jsonEncode({'coins': 60, 'logs': 24, 'seconds': [1500, 1500], 'recorded': 1, 'deposited': false});
    final (player, history) = await load({Settlement.key: journal});

    await Settlement.resume(player, history);
    expect(history.totalFocusSecondsAllTime, 1500, reason: 'first session was already recorded before the kill');
    expect(player.coins, 60);

    await Settlement.resume(player, history);
    expect(history.totalFocusSecondsAllTime, 1500);
    expect(player.coins, 60);
  });

  test('resume does not deposit twice', () async {
    final journal = jsonEncode({'coins': 60, 'logs': 24, 'seconds': [1500], 'recorded': 1, 'deposited': true});
    final (player, history) = await load({Settlement.key: journal, 'fk_gold': 60, 'fk_logs': 24});
    await Settlement.resume(player, history);
    expect(player.coins, 60);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(Settlement.key), isNull);
  });

  test('resume with no journal is a no-op', () async {
    final (player, history) = await load({});
    await Settlement.resume(player, history);
    expect(player.coins, 0);
  });
}
