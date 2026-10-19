/// Rank tiers, earned by total focus hours of completed battles.
enum Rank {
  starter(0, 'Starter'),
  gold(10, 'Gold'),
  diamond(30, 'Diamond'),
  ruby(70, 'Ruby'),
  amethyst(150, 'Amethyst');

  const Rank(this.thresholdHours, this.label);
  final int thresholdHours;
  final String label;
}

/// Playable characters, unlocked in this order by rank.
enum GameCharacter {
  pawn('Pawn'),
  lancer('Lancer'),
  archer('Archer'),
  monk('Monk'),
  warrior('Warrior');

  const GameCharacter(this.label);
  final String label;

  Rank get unlockRank => Rank.values[index];
}

Rank rankForSeconds(int totalFocusSeconds) =>
    Rank.values.lastWhere((r) => totalFocusSeconds >= r.thresholdHours * 3600);

/// The new rank if adding [addedSeconds] to [beforeSeconds] crosses a threshold, else null.
Rank? rankUp(int beforeSeconds, int addedSeconds) {
  final after = rankForSeconds(beforeSeconds + addedSeconds);
  return after.index > rankForSeconds(beforeSeconds).index ? after : null;
}

Rank? nextRank(Rank r) => r.index + 1 < Rank.values.length ? Rank.values[r.index + 1] : null;

bool isCharacterUnlocked(GameCharacter c, Rank current) => c.index <= current.index;

bool isBadgeUnlocked(GameCharacter c, Rank badge, Rank current) =>
    isCharacterUnlocked(c, current) && badge.index <= current.index;

String badgeAsset(GameCharacter c, Rank r) => 'ui/ranks/${c.name}/${c.name}_${r.name}.png';
