import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/core/game/player_state.dart';
import 'package:test_dart/core/game/progression.dart';
import 'package:test_dart/core/game/village.dart';
import 'package:test_dart/features/village/village_screen.dart';

void main() {
  Future<PlayerState> pumpVillage(
    WidgetTester tester, {
    int coins = 0,
    Rank rank = Rank.starter,
    int plots = 0,
  }) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'fk_gold': coins, 'fk_logs': 1000});
    late PlayerState player;
    await tester.runAsync(() async {
      player = PlayerState();
      await player.load();
      for (var i = 0; i < plots; i++) {
        final id = await player.beginConstruction(
          task: 'T$i',
          focusMinutes: 25,
        );
        await player.finishConstruction(id, won: i != 0);
      }
    });
    addTearDown(player.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VillageScreen(
            player: player,
            totalFocusSeconds: rank.thresholdHours * 3600,
          ),
        ),
      ),
    );
    await tester.pump();
    return player;
  }

  testWidgets(
    'Castle is always available and upgrade rank locks prevent buying',
    (tester) async {
      await pumpVillage(tester, coins: 1000);
      expect(find.byKey(const Key('castle')), findsOneWidget);
      await tester.tap(find.byKey(const Key('castle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('upgrade-lock-granary')), findsOneWidget);
      expect(find.byKey(const Key('upgrade-lock-barracks')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('upgrade-granary')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('Castle upgrade spends once and displays the new level', (
    tester,
  ) async {
    final player = await pumpVillage(tester, coins: 1000);
    await tester.tap(find.byKey(const Key('castle')));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('upgrade-tower'));
    await tester.tap(button);
    await tester.tap(button, warnIfMissed: false);
    await tester.runAsync(() => pumpEventQueue());
    await tester.pump();
    expect(player.levelOf(Building.tower), 1);
    expect(player.coins, 800);
  });

  testWidgets('paging changes only the grid and retains permanent ruins', (
    tester,
  ) async {
    final player = await pumpVillage(tester, plots: 16);
    final castle = tester.getRect(find.byKey(const Key('castle')));
    expect(find.byKey(Key('plot-${player.plots.first.id}')), findsOneWidget);
    await tester.tap(find.byKey(const Key('map-next')));
    await tester.pump();
    expect(find.byKey(Key('plot-${player.plots.first.id}')), findsNothing);
    expect(find.byKey(Key('plot-${player.plots.last.id}')), findsOneWidget);
    expect(tester.getRect(find.byKey(const Key('castle'))), castle);
    expect(player.plots.first.state, PlotState.ruined);
    await tester.tap(find.byKey(const Key('map-prev')));
    await tester.pump();
    expect(find.byKey(Key('plot-${player.plots.first.id}')), findsOneWidget);
  });

  testWidgets(
    'land has five columns and three rows retaining the original plot positions',
    (tester) async {
      final player = await pumpVillage(tester, plots: 2);
      final occupied = tester.widget<Container>(
        find.byKey(Key('plot-${player.plots[1].id}')),
      );
      expect(occupied.decoration, isNull);
      final empty = find.byKey(const Key('empty-plot-2'));
      final decoration =
          tester.widget<Container>(empty).decoration! as BoxDecoration;
      expect(decoration.color, isNull);
      expect(decoration.border, isNotNull);
      expect(
        find.descendant(of: empty, matching: find.byIcon(Icons.add)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: empty, matching: find.byType(Text)),
        findsNothing,
      );
      final firstRow = tester.getRect(empty);
      final lastColumn = tester.getRect(find.byKey(const Key('empty-plot-4')));
      final secondRow = tester.getRect(find.byKey(const Key('empty-plot-5')));
      final lastRow = tester.getRect(find.byKey(const Key('empty-plot-14')));
      final grid = tester.getRect(find.byType(GridView));
      final originalHeight = (grid.height - 24) / 4;
      expect(firstRow.top, lastColumn.top);
      expect(secondRow.top, greaterThan(firstRow.bottom));
      expect(firstRow.top, grid.top);
      expect(firstRow.height, closeTo(originalHeight, .01));
      expect(lastRow.top, closeTo(grid.top + 2 * (originalHeight + 8), .01));
      expect(
        lastRow.bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(GridView)).bottom),
      );
      expect(find.byIcon(Icons.add), findsNWidgets(13));
      expect(find.byKey(const Key('empty-plot-15')), findsNothing);
      expect(occupied.constraints, isNull);
      final image = find.descendant(
        of: find.byKey(Key('plot-${player.plots[1].id}')),
        matching: find.byType(Image),
      );
      expect(tester.getSize(image).width, lessThanOrEqualTo(firstRow.width));
    },
  );

  testWidgets('empty village grid fits a narrow short phone', (tester) async {
    await pumpVillage(tester);
    tester.view.physicalSize = const Size(340, 640);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('castle')), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byKey(const Key('map-next'))).onPressed,
      isNull,
    );
  });
}
