import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/core/game/player_state.dart';
import 'package:test_dart/features/dashboard/services/focus_history_service.dart';
import 'package:test_dart/features/focus_session/focus_session_controller.dart';
import 'package:test_dart/features/home/home_screen.dart';

void main() {
  late PlayerState player;
  late FocusHistoryService history;
  late FocusSessionController controller;

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'fk_total_focus_seconds_all_time': 34 * 3600,
      'fk_gold': 1240,
      'fk_logs': 86,
      'fk_badge': 'archer_diamond',
    });
    await tester.runAsync(() async {
      player = PlayerState();
      await player.load();
      history = FocusHistoryService();
      await history.loadData();
    });
    controller = FocusSessionController(player: player, history: history);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: HomeScreen(controller: controller, player: player, history: history)),
    ));
    await tester.pump();
  }

  testWidgets('header shows rank progress, wallet and avatar', (tester) async {
    await pumpHome(tester);
    expect(find.text('Diamond'), findsOneWidget);
    expect(find.text('34h / 70h → Ruby'), findsOneWidget);
    expect(find.text('1240'), findsOneWidget);
    expect(find.text('86'), findsOneWidget);
    final avatar = find.byWidgetPredicate((w) =>
        w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'ui/ranks/archer/archer_diamond.png');
    expect(avatar, findsOneWidget);
  });

  testWidgets('home has no shadows', (tester) async {
    await pumpHome(tester);
    final shadows = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) => c.decoration is BoxDecoration && (c.decoration as BoxDecoration).boxShadow != null);
    expect(shadows, isEmpty);
  });

  testWidgets('start opens the setup sheet', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('BẮT ĐẦU'));
    // Sprites loop forever, so pump fixed frames instead of pumpAndSettle.
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('XUẤT TRẬN'), findsOneWidget);
  });
}
