import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/core/game/player_state.dart';
import 'package:test_dart/core/game/progression.dart';
import 'package:test_dart/features/village/village_screen.dart';

void main() {
  late PlayerState player;

  Future<void> pumpVillage(WidgetTester tester, {required Map<String, Object> prefs, Rank rank = Rank.starter}) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(prefs);
    await tester.runAsync(() async {
      player = PlayerState();
      await player.load();
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: VillageScreen(player: player, totalFocusSeconds: rank.thresholdHours * 3600)),
    ));
    await tester.pump();
  }

  Future<void> openSlot(WidgetTester tester, String building) async {
    await tester.tap(find.byKey(Key('slot-$building')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('cannot build without funds', (tester) async {
    await pumpVillage(tester, prefs: {});
    await openSlot(tester, 'tower');
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Xây'));
    expect(button.onPressed, isNull);
  });

  testWidgets('building spends and shows level', (tester) async {
    await pumpVillage(tester, prefs: {'fk_gold': 500, 'fk_logs': 100});
    await openSlot(tester, 'tower');
    await tester.tap(find.widgetWithText(FilledButton, 'Xây'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Tháp canh Lv1'), findsOneWidget);
    expect(player.coins, 300);
  });

  testWidgets('character houses show their lock rank', (tester) async {
    await pumpVillage(tester, prefs: {}, rank: Rank.gold);
    expect(find.text('🔒 Diamond'), findsOneWidget);
  });
}
