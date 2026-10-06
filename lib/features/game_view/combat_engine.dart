import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Floating damage text entity rendered above combatants
class DamageText {
  final String text;
  final Offset position;
  final Color color;
  final bool isCrit;
  final double createdAt; // Ticker time in seconds
  final double duration; // Total lifetime in seconds

  DamageText({
    required this.text,
    required this.position,
    required this.color,
    this.isCrit = false,
    required this.createdAt,
    this.duration = 0.8,
  });
}

/// Core passive auto-battler engine and combat math loop.
/// Supports stat upgrades and persistence via SharedPreferences.
class CombatEngine extends ChangeNotifier {
  final math.Random _random = math.Random();

  // ---------------------------------------------------------------------------
  // HERO STATS & UPGRADES
  // ---------------------------------------------------------------------------
  int atk = 16;
  int maxHp = 120;
  int currentHp = 120;
  double critRate = 25.0; // 0% to 100%
  double critDmg = 2.0; // Multiplier (2x)
  int gold = 0;

  // Upgrade counts for progressive costs
  int atkUpgrades = 0;
  int hpUpgrades = 0;
  int critUpgrades = 0;

  // Upgrade cost formulas
  int get atkUpgradeCost => 25 + (atkUpgrades * 10);
  int get hpUpgradeCost => 20 + (hpUpgrades * 8);
  int get critUpgradeCost => 35 + (critUpgrades * 15);

  // ---------------------------------------------------------------------------
  // MONSTER STATS (Scaled by currentStage)
  // ---------------------------------------------------------------------------
  int currentStage = 1;
  String monsterName = 'Goblin Scout';
  int monsterMaxHp = 45;
  int monsterCurrentHp = 45;
  int monsterAtk = 6;

  // ---------------------------------------------------------------------------
  // COMBAT LOOP & TIMERS
  // ---------------------------------------------------------------------------
  Timer? _tickerTimer;
  double _elapsedSeconds = 0.0;
  double get elapsedSeconds => _elapsedSeconds;
  double _heroAttackCooldown = 0.0;
  double _monsterAttackCooldown = 0.5;
  final double heroAttackInterval = 1.0;
  final double monsterAttackInterval = 1.4;

  bool isPaused = true; // Idle by default until session starts!

  // ---------------------------------------------------------------------------
  // VISUAL EFFECTS & STATES
  // ---------------------------------------------------------------------------
  final List<DamageText> damageTexts = [];
  bool isDefeated = false;
  double defeatTimer = 0.0;
  bool isShaking = false;
  double shakeTimeRemaining = 0.0;
  Offset currentShakeOffset = Offset.zero;

  bool heroAttacking = false;
  double heroAttackAnim = 0.0;
  bool monsterHurt = false;
  double monsterHurtAnim = 0.0;
  bool heroHurt = false;
  double heroHurtAnim = 0.0;

  CombatEngine() {
    _initMonster();
    _loadPersistedStats();
    isPaused = true; // Idle state by default: hero does not attack until focus starts!
    startCombat();
  }

  // ---------------------------------------------------------------------------
  // PERSISTENCE (SharedPreferences)
  // ---------------------------------------------------------------------------
  Future<void> _loadPersistedStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      gold = prefs.getInt('fk_gold') ?? gold;
      atk = prefs.getInt('fk_atk') ?? atk;
      maxHp = prefs.getInt('fk_max_hp') ?? maxHp;
      currentHp = maxHp;
      critRate = prefs.getDouble('fk_crit_rate') ?? critRate;
      atkUpgrades = prefs.getInt('fk_atk_upgrades') ?? 0;
      hpUpgrades = prefs.getInt('fk_hp_upgrades') ?? 0;
      critUpgrades = prefs.getInt('fk_crit_upgrades') ?? 0;
      notifyListeners();
    } catch (_) {
      // Graceful fallback to default stats if storage unavailable
    }
  }

  Future<void> _saveStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('fk_gold', gold);
      await prefs.setInt('fk_atk', atk);
      await prefs.setInt('fk_max_hp', maxHp);
      await prefs.setDouble('fk_crit_rate', critRate);
      await prefs.setInt('fk_atk_upgrades', atkUpgrades);
      await prefs.setInt('fk_hp_upgrades', hpUpgrades);
      await prefs.setInt('fk_crit_upgrades', critUpgrades);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // REST INTERVAL UPGRADES
  // ---------------------------------------------------------------------------
  bool upgradeAtk() {
    final cost = atkUpgradeCost;
    if (gold >= cost) {
      gold -= cost;
      atk += 2;
      atkUpgrades++;
      _saveStats();
      notifyListeners();
      return true;
    }
    return false;
  }

  bool upgradeMaxHp() {
    final cost = hpUpgradeCost;
    if (gold >= cost) {
      gold -= cost;
      maxHp += 10;
      currentHp += 10; // Instantly reward health
      hpUpgrades++;
      _saveStats();
      notifyListeners();
      return true;
    }
    return false;
  }

  bool upgradeCritRate() {
    final cost = critUpgradeCost;
    if (gold >= cost && critRate < 100.0) {
      gold -= cost;
      critRate = math.min(100.0, critRate + 1.0);
      critUpgrades++;
      _saveStats();
      notifyListeners();
      return true;
    }
    return false;
  }

  void pauseCombat() {
    isPaused = true;
    notifyListeners();
  }

  void resumeCombat() {
    isPaused = false;
    notifyListeners();
  }

  void startCombat() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      _tick(0.05);
    });
  }

  void stopCombat() {
    _tickerTimer?.cancel();
    _tickerTimer = null;
  }

  void _initMonster() {
    monsterMaxHp = 40 + (currentStage * 22);
    monsterCurrentHp = monsterMaxHp;
    monsterAtk = 5 + (currentStage * 3);

    const names = [
      'Goblin Scout',
      'Forest Orc',
      'Cave Spider',
      'Shadow Wolf',
      'Crypt Skeleton',
      'Armored Troll',
      'Void Drake',
    ];
    monsterName = names[(currentStage - 1) % names.length];
  }

  void _tick(double dt) {
    _elapsedSeconds += dt;

    // 1. Screen Shake
    if (shakeTimeRemaining > 0) {
      shakeTimeRemaining -= dt;
      if (shakeTimeRemaining <= 0) {
        isShaking = false;
        currentShakeOffset = Offset.zero;
      } else {
        final dx = (_random.nextDouble() * 6) - 3;
        final dy = (_random.nextDouble() * 6) - 3;
        currentShakeOffset = Offset(dx, dy);
      }
    }

    // 2. Clean up expired floating damage texts
    damageTexts.removeWhere(
      (dmg) => (_elapsedSeconds - dmg.createdAt) >= dmg.duration,
    );

    // 3. Update Attack & Hurt animations
    if (heroAttackAnim > 0) {
      heroAttackAnim = math.max(0.0, heroAttackAnim - dt * 3.5);
      heroAttacking = heroAttackAnim > 0;
    }
    if (monsterHurtAnim > 0) {
      monsterHurtAnim = math.max(0.0, monsterHurtAnim - dt * 4.0);
      monsterHurt = monsterHurtAnim > 0;
    }
    if (heroHurtAnim > 0) {
      heroHurtAnim = math.max(0.0, heroHurtAnim - dt * 4.0);
      heroHurt = heroHurtAnim > 0;
    }

    if (isPaused) {
      notifyListeners();
      return;
    }

    // 4. Defeat & Respawn Loop
    if (isDefeated) {
      defeatTimer -= dt;
      if (defeatTimer <= 0) {
        isDefeated = false;
        currentHp = maxHp;
        _initMonster();
        _heroAttackCooldown = 0.5;
        _monsterAttackCooldown = 1.0;
      }
      notifyListeners();
      return;
    }

    // 5. Hero Auto-Attack
    _heroAttackCooldown -= dt;
    if (_heroAttackCooldown <= 0) {
      _heroAttackCooldown = heroAttackInterval;
      _executeHeroAttack();
    }

    // 6. Monster Auto-Attack
    if (monsterCurrentHp > 0) {
      _monsterAttackCooldown -= dt;
      if (_monsterAttackCooldown <= 0) {
        _monsterAttackCooldown = monsterAttackInterval;
        _executeMonsterAttack();
      }
    }

    notifyListeners();
  }

  void _executeHeroAttack() {
    heroAttacking = true;
    heroAttackAnim = 1.0;
    monsterHurt = true;
    monsterHurtAnim = 1.0;

    final roll = _random.nextDouble() * 100;
    final isCrit = roll <= critRate;
    final dmgAmount = isCrit ? (atk * critDmg).round() : atk;

    monsterCurrentHp = math.max(0, monsterCurrentHp - dmgAmount);

    if (isCrit) {
      isShaking = true;
      shakeTimeRemaining = 0.1;
      damageTexts.add(
        DamageText(
          text: 'CRIT! $dmgAmount',
          position: const Offset(0.72, 0.46),
          color: const Color(0xFFFFEB3B),
          isCrit: true,
          createdAt: _elapsedSeconds,
        ),
      );
    } else {
      damageTexts.add(
        DamageText(
          text: '$dmgAmount',
          position: const Offset(0.72, 0.48),
          color: Colors.white,
          isCrit: false,
          createdAt: _elapsedSeconds,
        ),
      );
    }

    // Check Monster Defeat
    if (monsterCurrentHp <= 0) {
      final earnedGold = (currentStage * 8) + 5;
      gold += earnedGold;
      currentStage++;
      _saveStats(); // Persist earned gold

      damageTexts.add(
        DamageText(
          text: '+$earnedGold GOLD',
          position: const Offset(0.72, 0.38),
          color: const Color(0xFFFFB300),
          isCrit: true,
          createdAt: _elapsedSeconds,
          duration: 1.2,
        ),
      );

      _heroAttackCooldown = 0.8;
      _monsterAttackCooldown = 1.4;
      _initMonster();
    }
  }

  void _executeMonsterAttack() {
    heroHurt = true;
    heroHurtAnim = 1.0;

    final dmgAmount = monsterAtk;
    currentHp = math.max(0, currentHp - dmgAmount);

    damageTexts.add(
      DamageText(
        text: '-$dmgAmount',
        position: const Offset(0.28, 0.48),
        color: const Color(0xFFEF4444),
        isCrit: false,
        createdAt: _elapsedSeconds,
      ),
    );

    if (currentHp <= 0) {
      isDefeated = true;
      defeatTimer = 2.0;
      damageTexts.add(
        DamageText(
          text: 'DEFEATED!',
          position: const Offset(0.28, 0.38),
          color: const Color(0xFFFF5252),
          isCrit: true,
          createdAt: _elapsedSeconds,
          duration: 2.0,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }
}
