import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hero skin definition using procedural palette swapping
class HeroSkin {
  final String id;
  final String name;
  final String description;
  final int unlockHours;
  final Color armorLight;
  final Color armorDark;
  final Color visorColor;
  final Color swordBlade;
  final Color swordHilt;
  final Color capeColor;

  const HeroSkin({
    required this.id,
    required this.name,
    required this.description,
    required this.unlockHours,
    required this.armorLight,
    required this.armorDark,
    required this.visorColor,
    required this.swordBlade,
    required this.swordHilt,
    required this.capeColor,
  });

  bool isUnlocked(int totalFocusHours) => totalFocusHours >= unlockHours;
}

/// Camp cosmetics / companion definitions
class CampCosmetic {
  final String id;
  final String name;
  final String description;
  final int unlockHours;
  final Color primaryColor;

  const CampCosmetic({
    required this.id,
    required this.name,
    required this.description,
    required this.unlockHours,
    required this.primaryColor,
  });

  bool isUnlocked(int totalFocusHours) => totalFocusHours >= unlockHours;
}

/// Registry and persistence for cosmetic skins and camp companions
class CosmeticsManager extends ChangeNotifier {
  static const String _keyActiveSkin = 'fk_active_skin_id';
  static const String _keyActiveCamp = 'fk_active_camp_id';

  static const List<HeroSkin> allSkins = [
    HeroSkin(
      id: 'squire',
      name: 'Hiệp Sĩ Tập Sự',
      description: 'Trang phục khởi đầu của một hiệp sĩ kiên trì.',
      unlockHours: 0,
      armorLight: Color(0xFFB0BEC5), // Steel light
      armorDark: Color(0xFF546E7A),  // Steel dark
      visorColor: Color(0xFF37474F),
      swordBlade: Color(0xFFECEFF1),
      swordHilt: Color(0xFF8D6E63),
      capeColor: Color(0xFFEF5350),  // Red cape
    ),
    HeroSkin(
      id: 'paladin',
      name: 'Paladin Kim Hoàng',
      description: 'Bộ giáp vàng rực tôi luyện qua 1 giờ kỷ luật.',
      unlockHours: 1,
      armorLight: Color(0xFFFFD54F), // Gold light
      armorDark: Color(0xFFFFA000),  // Gold dark
      visorColor: Color(0xFF4E342E),
      swordBlade: Color(0xFFFFF9C4),
      swordHilt: Color(0xFFB45309),
      capeColor: Color(0xFF3B82F6),  // Royal blue cape
    ),
    HeroSkin(
      id: 'assassin',
      name: 'Shadow Assassin',
      description: 'Bộ giáp bóng đêm dành cho hiệp sĩ đạt 5 giờ tập trung sâu.',
      unlockHours: 5,
      armorLight: Color(0xFF4A5568), // Obsidian light
      armorDark: Color(0xFF1A202C),  // Obsidian dark
      visorColor: Color(0xFF7C3AED), // Purple visor glow
      swordBlade: Color(0xFFA78BFA), // Purple energy blade
      swordHilt: Color(0xFF312E81),
      capeColor: Color(0xFF6B21A8),  // Deep purple cape
    ),
  ];

  static const List<CampCosmetic> allCampItems = [
    CampCosmetic(
      id: 'none',
      name: 'Không có thú cưng',
      description: 'Tập trung đơn độc trên chiến trường.',
      unlockHours: 0,
      primaryColor: Colors.transparent,
    ),
    CampCosmetic(
      id: 'slime_pet',
      name: 'Thú Cưng Slime Xanh',
      description: 'Một chú slime xanh ngọc trung thành đồng hành nhặt vàng.',
      unlockHours: 2,
      primaryColor: Color(0xFF10B981),
    ),
  ];

  String _activeSkinId = 'squire';
  String _activeCampId = 'none';

  String get activeSkinId => _activeSkinId;
  String get activeCampId => _activeCampId;

  HeroSkin get currentSkin {
    return allSkins.firstWhere(
      (s) => s.id == _activeSkinId,
      orElse: () => allSkins.first,
    );
  }

  CampCosmetic get currentCampItem {
    return allCampItems.firstWhere(
      (c) => c.id == _activeCampId,
      orElse: () => allCampItems.first,
    );
  }

  CosmeticsManager() {
    loadPreferences();
  }

  Future<void> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _activeSkinId = prefs.getString(_keyActiveSkin) ?? 'squire';
      _activeCampId = prefs.getString(_keyActiveCamp) ?? 'none';
      notifyListeners();
    } catch (_) {}
  }

  Future<void> equipSkin(String skinId, int totalFocusHours) async {
    final skin = allSkins.firstWhere((s) => s.id == skinId, orElse: () => allSkins.first);
    if (!skin.isUnlocked(totalFocusHours)) return;

    _activeSkinId = skinId;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyActiveSkin, skinId);
    } catch (_) {}
  }

  Future<void> equipCampItem(String campId, int totalFocusHours) async {
    final camp = allCampItems.firstWhere((c) => c.id == campId, orElse: () => allCampItems.first);
    if (!camp.isUnlocked(totalFocusHours)) return;

    _activeCampId = campId;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyActiveCamp, campId);
    } catch (_) {}
  }
}
