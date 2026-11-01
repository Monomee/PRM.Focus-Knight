import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/core/game/player_state.dart';
import 'package:test_dart/core/game/village.dart';
import 'package:test_dart/features/dashboard/services/focus_history_service.dart';
import 'package:test_dart/features/focus_session/focus_session_controller.dart';
import 'package:test_dart/features/focus_session/settlement.dart';

class _FailingFinishPlayer extends PlayerState {
  bool fail = true;
  @override
  Future<void> finishConstruction(String id, {required bool won}) async {
    if (won && fail) throw StateError('disk full');
    await super.finishConstruction(id, won: won);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PlayerState player;
  late FocusHistoryService history;
  late FocusSessionController controller;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    player = PlayerState();
    await player.load();
    history = FocusHistoryService();
    await history.loadData();
    controller = FocusSessionController(player: player, history: history);
  });
  tearDown(() => controller.dispose());

  test(
    'one full Pomodoro chain builds one house based on focus time only',
    () async {
      await controller.startFocusSession(
        task: 'T',
        durationSeconds: 1800,
        totalSessions: 4,
        restDurationSeconds: 600,
        longBreakEvery: 2,
        longRestSeconds: 1200,
      );
      expect(player.plots, hasLength(1));
      expect(player.plots.single.building, FocusBuilding.monastery);
      expect(player.plots.single.state, PlotState.building);
      for (var i = 0; i < 4; i++) {
        controller.debugCompleteFocus();
        if (i < 3) controller.finishRestBreak();
      }
      await pumpEventQueue();
      expect(player.plots.single.state, PlotState.complete);
      expect((player.coins, player.logs), (144, 60));
    },
  );

  test('abandoning creates a permanent ruin without a second plot', () async {
    await controller.startFocusSession(task: 'T', durationSeconds: 1500);
    controller.forceAbandonSession();
    await pumpEventQueue();
    expect(player.plots.single.state, PlotState.ruined);
    expect(player.coins, 0);
    controller.forceAbandonSession();
    expect(player.plots, hasLength(1));
  });

  test('two concurrent starts reserve only one plot', () async {
    await Future.wait([
      controller.startFocusSession(task: 'First', durationSeconds: 60),
      controller.startFocusSession(task: 'Second', durationSeconds: 120),
    ]);
    expect(player.plots, hasLength(1));
    expect(controller.taskName, 'First');
  });

  test(
    'startup resumes won construction before ruining orphaned ones',
    () async {
      final won = await player.beginConstruction(task: 'Won', focusMinutes: 25);
      await player.beginConstruction(task: 'Interrupted', focusMinutes: 90);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        Settlement.key,
        jsonEncode([
          {
            'id': 'won-battle',
            'coins': 30,
            'logs': 12,
            'seconds': [1500],
            'recorded': 0,
            'deposited': false,
            'constructionId': won,
          },
        ]),
      );
      final restored = PlayerState();
      await restored.load();
      await Settlement.resume(restored, history);
      await restored.abandonUnfinishedConstructions();
      expect(restored.plots.first.state, PlotState.complete);
      expect(restored.plots.last.state, PlotState.ruined);
      expect(restored.coins, 30);
      await Settlement.resume(restored, history);
      expect(restored.coins, 30);
    },
  );

  test(
    'failed completion after payout retains journal and retry never pays twice',
    () async {
      controller.dispose();
      final failing = _FailingFinishPlayer();
      await failing.load();
      controller = FocusSessionController(player: failing, history: history);
      await controller.startFocusSession(task: 'T', durationSeconds: 1500);
      controller.debugCompleteFocus();
      await pumpEventQueue();
      expect(controller.settlementFailed, isTrue);
      expect(failing.coins, 30);
      expect(failing.plots.single.state, PlotState.building);
      expect(
        (await SharedPreferences.getInstance()).getString(Settlement.key),
        isNotNull,
      );
      failing.fail = false;
      await controller.retrySettlement();
      expect(failing.coins, 30);
      expect(failing.plots.single.state, PlotState.complete);
      expect(
        (await SharedPreferences.getInstance()).getString(Settlement.key),
        isNull,
      );
    },
  );
}
