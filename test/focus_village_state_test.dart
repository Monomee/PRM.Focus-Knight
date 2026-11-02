import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/core/game/player_state.dart';
import 'package:test_dart/core/game/progression.dart';
import 'package:test_dart/core/game/village.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('focus building thresholds include each boundary', () {
    for (final (minutes, building) in [
      (1, FocusBuilding.house1),
      (30, FocusBuilding.house1),
      (31, FocusBuilding.archery),
      (60, FocusBuilding.archery),
      (61, FocusBuilding.tower),
      (100, FocusBuilding.tower),
      (101, FocusBuilding.monastery),
      (150, FocusBuilding.monastery),
      (151, FocusBuilding.barracks),
      (1440, FocusBuilding.barracks),
    ]) {
      expect(focusBuildingForMinutes(minutes), building);
    }
    expect(() => focusBuildingForMinutes(0), throwsArgumentError);
  });

  test(
    'migration keeps effects and refunds decoration levels exactly once',
    () async {
      SharedPreferences.setMockInitialValues({
        'fk_gold': 10,
        'fk_logs': 5,
        'fk_buildings': [
          'tower:1',
          'granary:1',
          'barracks:1',
          'archery:2',
          'castle:1',
        ],
        'fk_granary_built': '2026-10-20',
        'fk_streak_tickets': 1,
      });
      final player = PlayerState();
      await player.load();
      expect((player.coins, player.logs), (785, 160));
      expect(player.levelOf(Building.tower), 1);
      expect(player.levelOf(Building.barracks), 1);
      expect(player.levelOf(Building.granary), 1);
      expect(player.levelOf(Building.castle), 0);
      expect(player.granaryBuiltAt, DateTime(2026, 10, 20));
      expect(player.streakTickets, 1);
      final restored = PlayerState();
      await restored.load();
      expect((restored.coins, restored.logs), (785, 160));
    },
  );

  test(
    'Castle gates effects by rank and rejects decorative purchases',
    () async {
      SharedPreferences.setMockInitialValues({
        'fk_gold': 9999,
        'fk_logs': 9999,
      });
      final player = PlayerState();
      await player.load();
      expect(await player.build(Building.granary, Rank.starter), isFalse);
      expect(await player.build(Building.barracks, Rank.gold), isFalse);
      expect(await player.build(Building.archery, Rank.amethyst), isFalse);
      expect(await player.build(Building.tower, Rank.starter), isTrue);
      expect(await player.build(Building.granary, Rank.gold), isTrue);
      expect(await player.build(Building.barracks, Rank.diamond), isTrue);
    },
  );

  test(
    'construction outcome is durable, idempotent and ruins cannot be repaired',
    () async {
      final player = PlayerState();
      await player.load();
      final won = await player.beginConstruction(task: 'T', focusMinutes: 120);
      final lost = await player.beginConstruction(task: 'T2', focusMinutes: 25);
      await player.finishConstruction(won, won: true);
      await player.finishConstruction(won, won: true);
      await player.finishConstruction(lost, won: false);
      await expectLater(
        player.finishConstruction(lost, won: true),
        throwsStateError,
      );
      await player.deposit(coins: 30, logs: 12, settlementId: 'reward');
      final restored = PlayerState();
      await restored.load();
      expect(restored.plots, hasLength(2));
      expect(restored.plots.first.building, FocusBuilding.monastery);
      expect(restored.plots.first.state, PlotState.complete);
      expect(restored.plots.last.state, PlotState.ruined);
      expect((restored.coins, restored.logs), (30, 12));
    },
  );

  test(
    'startup recovery ruins only unfinished plots and can run twice',
    () async {
      final player = PlayerState();
      await player.load();
      final complete = await player.beginConstruction(
        task: 'Done',
        focusMinutes: 60,
      );
      await player.finishConstruction(complete, won: true);
      await player.beginConstruction(task: 'Killed', focusMinutes: 151);
      final restored = PlayerState();
      await restored.load();
      await restored.abandonUnfinishedConstructions();
      await restored.abandonUnfinishedConstructions();
      expect(restored.plots.first.state, PlotState.complete);
      expect(restored.plots.last.state, PlotState.ruined);
    },
  );
}
