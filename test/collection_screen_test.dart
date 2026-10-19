import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/core/game/player_state.dart';
import 'package:test_dart/core/game/progression.dart';
import 'package:test_dart/features/collection/collection_screen.dart';

void main() {
  late PlayerState player;

  Future<void> pumpCollection(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      player = PlayerState();
      await player.load();
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CollectionScreen(player: player, totalFocusSeconds: 34 * 3600)),
    ));
    await tester.pump();
  }

  testWidgets('only unlocked characters can be selected', (tester) async {
    await pumpCollection(tester);
    await tester.tap(find.byKey(const Key('char-monk')));
    await tester.pump();
    expect(player.selectedCharacter, GameCharacter.pawn);
    await tester.tap(find.byKey(const Key('char-archer')));
    await tester.pump();
    expect(player.selectedCharacter, GameCharacter.archer);
  });

  testWidgets('only unlocked badges become the avatar', (tester) async {
    await pumpCollection(tester);
    await tester.tap(find.byKey(const Key('badge-archer_diamond')));
    await tester.pump();
    expect((player.badgeCharacter, player.badgeRank), (GameCharacter.archer, Rank.diamond));
    await tester.tap(find.byKey(const Key('badge-monk_starter')));
    await tester.pump();
    expect((player.badgeCharacter, player.badgeRank), (GameCharacter.archer, Rank.diamond));
  });

  testWidgets('shows hours left to next unlock', (tester) async {
    await pumpCollection(tester);
    expect(find.text('Còn 36h để mở Monk + huy hiệu Ruby'), findsOneWidget);
  });
}
