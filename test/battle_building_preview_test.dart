import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_dart/core/game/battle_plan.dart';
import 'package:test_dart/features/battle/battle_setup_sheet.dart';

void main() {
  testWidgets(
    'construction preview uses total focus time and updates with session count',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showBattleSetupSheet(
                context,
                barracksLevel: 0,
                longRestMinutes: 60,
                initial: BattlePlan(
                  task: '',
                  focusMinutes: 30,
                  restMinutes: 30,
                  sessions: 4,
                  longBreakEvery: 2,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('focus-building-preview')), findsOneWidget);
      expect(find.text('Tu viện'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('sessions-minus')));
      await tester.tap(find.byKey(const Key('sessions-minus')));
      await tester.pump();
      expect(find.text('Tháp canh'), findsOneWidget);
      await tester.tap(find.byKey(const Key('sessions-plus')));
      await tester.tap(find.byKey(const Key('sessions-plus')));
      await tester.tap(find.byKey(const Key('sessions-plus')));
      await tester.pump();
      expect(find.text('Doanh trại'), findsOneWidget);
    },
  );
}
