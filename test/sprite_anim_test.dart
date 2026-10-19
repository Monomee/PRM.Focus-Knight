import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_dart/core/game/progression.dart';
import 'package:test_dart/core/game/sprites.dart';
import 'package:test_dart/core/widgets/sprite_anim.dart';

Alignment _frameAlignment(WidgetTester tester) =>
    tester.widget<OverflowBox>(find.byType(OverflowBox)).alignment as Alignment;

void main() {
  test('characterSprites has an entry for every GameCharacter', () {
    expect(characterSprites.keys.toSet(), GameCharacter.values.toSet());
  });

  testWidgets('SpriteAnim shows frame 0 then advances', (tester) async {
    await tester.pumpWidget(const Center(
      child: SpriteAnim(
        sheet: SpriteSheet('ui/characters/player/warrior/Warrior_Idle.png', 8),
        size: 96,
      ),
    ));
    expect(_frameAlignment(tester), const Alignment(-1, 0));

    await tester.pump(const Duration(milliseconds: 100));
    expect(_frameAlignment(tester).x, closeTo(-1 + 2 / 7, 1e-9));
  });

  testWidgets('SpriteAnim non-loop calls onComplete once', (tester) async {
    var completed = 0;
    await tester.pumpWidget(Center(
      child: SpriteAnim(
        sheet: const SpriteSheet('ui/characters/Dead.png', 4),
        size: 64,
        loop: false,
        onComplete: () => completed++,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(completed, 1);
  });
}
