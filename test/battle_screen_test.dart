import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/core/game/player_state.dart';
import 'package:test_dart/core/game/sprites.dart';
import 'package:test_dart/core/widgets/sprite_anim.dart';
import 'package:test_dart/features/battle/battle_screen.dart';
import 'package:test_dart/features/dashboard/services/focus_history_service.dart';
import 'package:test_dart/features/focus_session/focus_session_controller.dart';

void main() {
  late PlayerState player;
  late FocusSessionController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    player = PlayerState();
    controller = FocusSessionController(player: player, history: FocusHistoryService());
  });

  Future<void> pumpBattle(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: BattleScreen(controller: controller, player: player)));
    await tester.pump();
  }

  Future<void> finish(WidgetTester tester) async {
    controller.cancelSession();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('focus view has no TabBar/AppBar and shows timer', (tester) async {
    controller.startFocusSession(task: 'Học', durationSeconds: 1500);
    await pumpBattle(tester);
    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('25:00'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('give up requires 2s long press', (tester) async {
    controller.startFocusSession(task: 'Học', durationSeconds: 1500);
    await pumpBattle(tester);
    final giveUp = find.byKey(const Key('give-up'));

    final g1 = await tester.startGesture(tester.getCenter(giveUp));
    await tester.pump(const Duration(milliseconds: 1000));
    await g1.up();
    await tester.pump();
    expect(controller.isFocusing, isTrue);

    final g2 = await tester.startGesture(tester.getCenter(giveUp));
    await tester.pump(const Duration(milliseconds: 600)); // long-press recognized
    await tester.pump(const Duration(milliseconds: 2100));
    await g2.up();
    await tester.pump();
    expect(controller.isSetup, isTrue);
    expect(controller.lastResult!.won, isFalse);
    await finish(tester);
  });

  testWidgets('camp shows session reward and skip button', (tester) async {
    controller.startFocusSession(task: 'Học', durationSeconds: 1500, totalSessions: 2);
    await pumpBattle(tester);
    controller.debugCompleteFocus();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('+30'), findsOneWidget);
    final skip = find.textContaining('XUNG TRẬN NGAY');
    expect(skip, findsOneWidget);
    await tester.tap(skip);
    await tester.pump();
    expect(controller.isFocusing, isTrue);
    await finish(tester);
  });

  testWidgets('defeat shows result screen', (tester) async {
    controller.startFocusSession(task: 'Học', durationSeconds: 1500);
    await pumpBattle(tester);
    for (var i = 0; i < 4; i++) {
      controller.applyBlacklistPenalty();
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Thất bại'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('HP bars are actually filled', (tester) async {
    controller.startFocusSession(task: 'Học', durationSeconds: 1500);
    await pumpBattle(tester);
    final fills = find.descendant(of: find.byType(FractionallySizedBox), matching: find.byType(ColoredBox));
    expect(fills, findsWidgets);
    for (final e in fills.evaluate()) {
      expect(tester.getSize(find.byWidget(e.widget)).height, greaterThan(0));
    }
    await finish(tester);
  });

  testWidgets('mindful dialog closes when the session leaves focus', (tester) async {
    controller.startFocusSession(task: 'Học', durationSeconds: 1500, totalSessions: 2);
    await pumpBattle(tester);
    await tester.binding.handlePopRoute(); // system back while focusing
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(Dialog), findsOneWidget);

    controller.debugCompleteFocus();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(Dialog), findsNothing);
    expect(controller.isResting, isTrue);
    await finish(tester);
  });

  testWidgets('hero stays put and only fights once the enemy arrives', (tester) async {
    controller.startFocusSession(task: 'Học', durationSeconds: 1500);
    await pumpBattle(tester);
    final heroFinder = find.byKey(const Key('hero'));
    final heroPos = tester.getTopLeft(heroFinder);
    SpriteSheet heroSheet() => tester.widget<SpriteAnim>(heroFinder).sheet;
    final hero = characterSprites[player.selectedCharacter]!;

    expect(heroSheet(), hero.idle, reason: 'enemy is still walking');
    await tester.pump(const Duration(milliseconds: 1000));
    expect(heroSheet(), hero.idle);

    await tester.pump(const Duration(milliseconds: 2000)); // enemy has arrived
    expect(heroSheet(), hero.attack);
    expect(tester.getTopLeft(heroFinder), heroPos);
    await finish(tester);
  });
}
