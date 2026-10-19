import 'package:flutter_test/flutter_test.dart';
import 'package:test_dart/core/game/economy.dart';
import 'package:test_dart/core/game/progression.dart';
import 'package:test_dart/core/game/village.dart';

void main() {
  group('rank', () {
    test('rankForSeconds uses 0/10/30/70/150h thresholds', () {
      const h = 3600;
      expect(rankForSeconds(0), Rank.starter);
      expect(rankForSeconds(10 * h - 1), Rank.starter);
      expect(rankForSeconds(10 * h), Rank.gold);
      expect(rankForSeconds(30 * h), Rank.diamond);
      expect(rankForSeconds(70 * h), Rank.ruby);
      expect(rankForSeconds(150 * h), Rank.amethyst);
      expect(rankForSeconds(999 * h), Rank.amethyst);
    });

    test('nextRank', () {
      expect(nextRank(Rank.amethyst), isNull);
      expect(nextRank(Rank.gold), Rank.diamond);
    });

    test('characters unlocked at diamond', () {
      expect(isCharacterUnlocked(GameCharacter.pawn, Rank.diamond), isTrue);
      expect(isCharacterUnlocked(GameCharacter.lancer, Rank.diamond), isTrue);
      expect(isCharacterUnlocked(GameCharacter.archer, Rank.diamond), isTrue);
      expect(isCharacterUnlocked(GameCharacter.monk, Rank.diamond), isFalse);
      expect(isCharacterUnlocked(GameCharacter.warrior, Rank.diamond), isFalse);
    });

    test('badges require unlocked character and reached rank', () {
      expect(isBadgeUnlocked(GameCharacter.archer, Rank.diamond, Rank.diamond), isTrue);
      expect(isBadgeUnlocked(GameCharacter.archer, Rank.ruby, Rank.diamond), isFalse);
      expect(isBadgeUnlocked(GameCharacter.monk, Rank.starter, Rank.diamond), isFalse);
      expect(isBadgeUnlocked(GameCharacter.monk, Rank.ruby, Rank.ruby), isTrue);
      expect(isBadgeUnlocked(GameCharacter.monk, Rank.starter, Rank.ruby), isTrue);
    });

    test('rankUp reports the new rank only when a threshold is crossed', () {
      const h = 3600;
      expect(rankUp(9 * h, 2 * h), Rank.gold);
      expect(rankUp(10 * h, 2 * h), isNull);
      expect(rankUp(0, 1500), isNull);
      expect(rankUp(29 * h, 200 * h), Rank.amethyst);
    });

    test('badgeAsset path', () {
      expect(badgeAsset(GameCharacter.archer, Rank.diamond), 'ui/ranks/archer/archer_diamond.png');
    });
  });

  group('economy', () {
    test('sessionReward', () {
      expect(sessionReward(focusMinutes: 15), (coins: 15, logs: 7));
      expect(sessionReward(focusMinutes: 25), (coins: 30, logs: 12));
      expect(sessionReward(focusMinutes: 50), (coins: 75, logs: 25));
      expect(sessionReward(focusMinutes: 25, barracksLevel: 2), (coins: 36, logs: 12));
    });
  });

  group('village', () {
    test('buildCost grows x1.5 per level', () {
      expect(buildCost(Building.tower, 0), (coins: 200, logs: 40));
      expect(buildCost(Building.tower, 1), (coins: 300, logs: 60));
    });

    test('graceSecondsFor tower level', () {
      expect([0, 1, 2].map(graceSecondsFor), [10, 12, 15]);
    });
  });
}
