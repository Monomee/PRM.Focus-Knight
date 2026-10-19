import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_dart/core/game/battle_plan.dart';
import 'package:test_dart/features/battle/battle_setup_sheet.dart';

void main() {
  testWidgets('sheet returns the chosen plan', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    BattlePlan? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showBattleSetupSheet(context, initial: BattlePlan.defaults, barracksLevel: 0);
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Học Flutter');
    await tester.tap(find.text('50p'));
    await tester.tap(find.byKey(const Key('sessions-plus')));
    await tester.pump();
    expect(find.text('~150 coin'), findsOneWidget);

    await tester.tap(find.text('XUẤT TRẬN'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect((result!.task, result!.focusMinutes, result!.sessions), ('Học Flutter', 50, 2));
  });

  testWidgets('custom minutes dialog closes cleanly and applies value', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    BattlePlan? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showBattleSetupSheet(context, initial: BattlePlan.defaults, barracksLevel: 0);
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tùy…').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '1');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('1p'), findsOneWidget);

    await tester.tap(find.text('XUẤT TRẬN'));
    await tester.pumpAndSettle();
    expect(result!.focusMinutes, 1);
  });
}
