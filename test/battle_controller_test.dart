import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/core/game/player_state.dart';
import 'package:test_dart/features/dashboard/services/focus_history_service.dart';
import 'package:test_dart/features/focus_session/focus_session_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlayerState player;
  late FocusHistoryService history;
  late FocusSessionController c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    player = PlayerState();
    await player.load();
    history = FocusHistoryService();
    await history.loadData();
    c = FocusSessionController(player: player, history: history);
  });

  tearDown(() => c.cancelSession());

  test('real timers still run a full battle', () async {
    c.startFocusSession(task: 'T', durationSeconds: 1, totalSessions: 2, restDurationSeconds: 1);
    await Future.delayed(const Duration(milliseconds: 3500));
    expect(c.lastResult, isNotNull);
    expect(c.lastResult!.won, isTrue);
    expect(c.lastResult!.sessions, 2);
    expect(history.totalFocusSecondsAllTime, 2);
  });

  test('completed battle deposits reward once', () async {
    c.startFocusSession(task: 'T', durationSeconds: 1500);
    c.debugCompleteFocus();
    await pumpEventQueue();
    expect(player.coins, 30);
    expect(player.logs, 12);
    expect(history.totalFocusSecondsAllTime, 1500);
    expect(c.lastResult!.coins, 30);
    expect(c.isSetup, isTrue);
  });

  test('hours and coins withheld until battle ends', () async {
    c.startFocusSession(task: 'T', durationSeconds: 1500, totalSessions: 2);
    c.debugCompleteFocus();
    await pumpEventQueue();
    expect(c.pendingCoins, 30);
    expect(c.lastSessionReward, (coins: 30, logs: 12));
    expect(player.coins, 0);
    expect(history.totalFocusSecondsAllTime, 0);
    expect(c.isResting, isTrue);
  });

  test('defeat forfeits everything', () async {
    c.startFocusSession(task: 'T', durationSeconds: 1500, totalSessions: 2);
    c.debugCompleteFocus();
    for (var i = 0; i < 4; i++) {
      c.applyBlacklistPenalty();
    }
    await pumpEventQueue();
    expect(c.lastResult!.won, isFalse);
    expect(c.lastResult!.coins, 0);
    expect(player.coins, 0);
    expect(history.totalFocusSecondsAllTime, 0);
    expect(c.isSetup, isTrue);

    final result = c.lastResult;
    c.applyBlacklistPenalty();
    c.applyDistractionTax();
    expect(c.lastResult, same(result));
  });

  test('tax never below zero', () {
    c.startFocusSession(task: 'T', durationSeconds: 1500, totalSessions: 2);
    c.debugCompleteFocus();
    c.applyDistractionTax();
    expect(c.pendingCoins, 15);
    c.applyDistractionTax();
    c.applyDistractionTax();
    expect(c.pendingCoins, 0);
  });

  test('penalty ignored when not in battle', () {
    c.applyBlacklistPenalty();
    expect(c.heroHp, 100);
    expect(c.lastResult, isNull);
  });

  test('pause once per session and freezes timer', () async {
    c.startFocusSession(task: 'T', durationSeconds: 5, totalSessions: 2, restDurationSeconds: 5);
    expect(c.pause(), isTrue);
    expect(c.isPaused, isTrue);
    await Future.delayed(const Duration(milliseconds: 1200));
    expect(c.remainingSeconds, 5);
    expect(c.pauseRemainingSeconds, lessThan(300));
    c.resumeFromPause();
    expect(c.isPaused, isFalse);
    expect(c.canPause, isFalse);
    expect(c.pause(), isFalse);

    c.debugCompleteFocus();
    expect(c.isResting, isTrue);
    expect(c.pause(), isFalse);
  });

  test('long rest after N sessions', () {
    c.startFocusSession(
      task: 'T',
      durationSeconds: 1500,
      totalSessions: 3,
      restDurationSeconds: 1,
      longBreakEvery: 2,
      longRestSeconds: 7,
    );
    c.debugCompleteFocus();
    expect(c.isLongRest, isFalse);
    c.finishRestBreak();
    expect(c.canPause, isTrue);
    c.debugCompleteFocus();
    expect(c.isLongRest, isTrue);
    expect(c.remainingSeconds, 7);
  });

  test('house HP ratio follows remaining time', () {
    c.startFocusSession(task: 'T', durationSeconds: 1500);
    expect(c.houseHpRatio, 1.0);
  });
}
