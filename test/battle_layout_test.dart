import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_dart/features/battle/focus_view.dart';
import 'package:test_dart/core/widgets/cover_rect.dart';

void main() {
  const phones = [Size(411, 869), Size(400, 700), Size(360, 800)];

  test('everyone stands on the grass, above the tree line', () {
    for (final box in phones) {
      final img = coverRect(box, BattleLayout.imageSize);
      final grassTop = img.top + 0.40 * img.height;
      final treeLine = img.top + 0.57 * img.height;
      final l = BattleLayout(box);
      for (final (name, feet) in [('hero', l.heroFeet), ('house', l.houseFeet), ('enemy', l.enemyFeet)]) {
        expect(feet, inInclusiveRange(grassTop, treeLine), reason: '$name feet on $box');
      }
    }
  });

  test('enemy walks from the goblin house door to the hero', () {
    for (final box in phones) {
      final l = BattleLayout(box);
      final doorX = l.house.center.dx;
      expect((l.enemyStart.center.dx - doorX).abs(), lessThan(box.width * 0.05), reason: 'starts at the door on $box');
      expect(l.enemyEnd.left, lessThan(l.enemyStart.left));
      expect(l.enemyEnd.left, greaterThan(l.hero.left), reason: 'stops in front of the hero on $box');
    }
  });
}
