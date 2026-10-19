import 'dart:math' as math;
import 'progression.dart';

const _dir = 'ui/buildings/player_building';

/// Village buildings. Only [functional] ones have gameplay effects; the rest are decoration.
enum Building {
  tower('$_dir/Tower.png', 'Tháp canh', 2, null, 200, 40, true, 'Ân hạn 10s → 12s → 15s'),
  granary('$_dir/House1.png', 'Kho lương', 1, null, 150, 30, true, '1 vé giữ chuỗi mỗi tuần'),
  barracks('$_dir/Barracks.png', 'Doanh trại', 2, null, 300, 60, true, '+10% Coin mỗi cấp'),
  archery('$_dir/Archery.png', 'Trường bắn', 3, GameCharacter.archer, 150, 30, false, 'Nhà của Archer'),
  monastery('$_dir/Monastery.png', 'Tu viện', 3, GameCharacter.monk, 250, 50, false, 'Nhà của Monk'),
  castle('$_dir/Castle.png', 'Lâu đài', 3, GameCharacter.warrior, 400, 80, false, 'Nhà của Warrior'),
  house2('$_dir/House2.png', 'Nhà dân', 3, null, 100, 20, false, 'Trang trí'),
  house3('$_dir/House3.png', 'Nhà dân lớn', 3, null, 100, 20, false, 'Trang trí');

  const Building(this.asset, this.label, this.maxLevel, this.requiredCharacter, this.baseCoins,
      this.baseLogs, this.functional, this.effect);
  final String asset;
  final String label;
  final int maxLevel;
  final GameCharacter? requiredCharacter;
  final int baseCoins;
  final int baseLogs;
  final bool functional;
  final String effect;
}

({int coins, int logs}) buildCost(Building b, int currentLevel) {
  final m = math.pow(1.5, currentLevel);
  return (coins: (b.baseCoins * m).round(), logs: (b.baseLogs * m).round());
}

int graceSecondsFor(int towerLevel) => const [10, 12, 15][towerLevel.clamp(0, 2)];
