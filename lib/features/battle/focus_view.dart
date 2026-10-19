import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/game/economy.dart';
import '../../core/game/sprites.dart';
import '../../core/widgets/cover_rect.dart';
import '../../core/widgets/ribbon.dart';
import '../../core/widgets/sprite_anim.dart';
import '../focus_session/focus_session_controller.dart';

const _goblinHouse = 'ui/buildings/enemy_building/Goblin_House.png';

/// Where the hero, the goblin house and the walking enemy stand on `battle_field.webp`.
/// Placed in image space (like the village) so feet stay on the grass, above the tree line.
class BattleLayout {
  BattleLayout(Size box) {
    final img = coverRect(box, imageSize);
    final w = box.width;
    final ground = img.top + _groundY * img.height;
    final heroSize = w * 0.5, enemySize = w * 0.42, houseW = w * 0.34, houseH = houseW * 1.5;
    hero = Rect.fromLTWH(w * 0.04, ground - _charFeet * heroSize, heroSize, heroSize);
    house = Rect.fromLTWH(w - w * 0.03 - houseW, ground - _houseFeet * houseH, houseW, houseH);
    enemyStart = Rect.fromLTWH(house.center.dx - enemySize / 2, ground - _charFeet * enemySize, enemySize, enemySize);
    enemyEnd = enemyStart.translate(hero.left + heroSize * 0.45 - enemyStart.left, 0);
  }

  static const imageSize = Size(1080, 1920);
  static const _groundY = 0.53; // grass spans ~0.38–0.57 of the image; trees start below
  static const _charFeet = 0.72; // feet line inside a Tiny Swords character frame
  static const _houseFeet = 0.95; // base line inside Goblin_House.png

  late final Rect hero, house, enemyStart, enemyEnd;

  double get heroFeet => hero.top + _charFeet * hero.height;
  double get enemyFeet => enemyStart.top + _charFeet * enemyStart.height;
  double get houseFeet => house.top + _houseFeet * house.height;
}

enum _EnemyPhase { hidden, atDoor, walking, fighting }
const _goblinHouseDestroyed = 'ui/buildings/enemy_building/Goblin_House_Destroyed.png';

/// Full-screen battle during focus: the goblin house HP is the session timer.
/// Enemies are pure decoration – nothing here produces resources.
class FocusView extends StatefulWidget {
  const FocusView({
    super.key,
    required this.controller,
    required this.hero,
    required this.onGiveUp,
    this.victoryRun = false,
  });

  final FocusSessionController controller;
  final CharacterSprites hero;
  final VoidCallback onGiveUp;

  /// Session just ended: briefly show the destroyed house (hero stays put), no enemies.
  final bool victoryRun;

  @override
  State<FocusView> createState() => _FocusViewState();
}

class _FocusViewState extends State<FocusView> with TickerProviderStateMixin {
  static const _holdToGiveUp = Duration(seconds: 2);

  final _random = math.Random();
  bool _controlsDim = false;
  Timer? _dimTimer;

  late final AnimationController _hold = AnimationController(vsync: this, duration: _holdToGiveUp)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onGiveUp();
    });

  late final AnimationController _hurt =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 210));
  late int _lastHp = widget.controller.heroHp;

  static const _walk = Duration(milliseconds: 2400);
  static const _fight = Duration(milliseconds: 1600);
  static const _gap = Duration(milliseconds: 800);

  Timer? _enemyTimer;
  int _enemyIndex = 0;
  _EnemyPhase _enemy = _EnemyPhase.hidden;

  @override
  void initState() {
    super.initState();
    _wakeControls();
    widget.controller.addListener(_onController);
    _spawnEnemy();
  }

  void _onController() {
    final hp = widget.controller.heroHp;
    if (hp < _lastHp) _hurt.forward(from: 0);
    _lastHp = hp;
  }

  /// Enemy loop: appear at the house door → walk to the hero → fight → vanish → repeat.
  void _spawnEnemy() {
    if (!mounted) return;
    if (widget.victoryRun || widget.controller.isPaused) {
      _enemyTimer = Timer(_gap, _spawnEnemy);
      return;
    }
    setState(() {
      _enemyIndex = _random.nextInt(enemySprites.length);
      _enemy = _EnemyPhase.atDoor; // placed at the door this frame...
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _enemy = _EnemyPhase.walking); // ...then walks towards the hero
      _enemyTimer = Timer(_walk, () {
        if (!mounted) return;
        setState(() => _enemy = _EnemyPhase.fighting);
        _enemyTimer = Timer(_fight, () {
          if (!mounted) return;
          setState(() => _enemy = _EnemyPhase.hidden);
          _enemyTimer = Timer(_gap, _spawnEnemy);
        });
      });
    });
  }

  void _wakeControls() {
    _dimTimer?.cancel();
    if (_controlsDim) setState(() => _controlsDim = false);
    _dimTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsDim = true);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _dimTimer?.cancel();
    _enemyTimer?.cancel();
    _hold.dispose();
    _hurt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _wakeControls(),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final l = BattleLayout(box.biggest);
        final fighting = _enemy == _EnemyPhase.fighting && !widget.victoryRun && !c.isPaused;
        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset('ui/scenes/battle_field.webp',
                  fit: BoxFit.cover, filterQuality: FilterQuality.none),
            ),
            // Goblin house = session HP
            Positioned.fromRect(
              rect: l.house,
              child: Image.asset(widget.victoryRun ? _goblinHouseDestroyed : _goblinHouse,
                  fit: BoxFit.contain, alignment: Alignment.bottomCenter, filterQuality: FilterQuality.none),
            ),
            if (!widget.victoryRun)
              Positioned(
                left: l.house.center.dx - w * 0.12,
                top: l.house.top - 10,
                child: _Bar(value: c.houseHpRatio, color: const Color(0xFFF87171), width: w * 0.24),
              ),
            // Enemy running out of the house
            if (_enemy != _EnemyPhase.hidden && !widget.victoryRun && !c.isPaused)
              AnimatedPositioned(
                duration: _walk,
                left: _enemy == _EnemyPhase.walking || fighting ? l.enemyEnd.left : l.enemyStart.left,
                top: l.enemyStart.top,
                child: SpriteAnim(
                  sheet: fighting ? enemySprites[_enemyIndex].attack : enemySprites[_enemyIndex].run,
                  size: l.enemyStart.width,
                  flipX: true,
                ),
              ),
            // Hero
            Positioned(
              left: l.hero.center.dx - l.hero.width * 0.175,
              top: l.hero.top + l.hero.height * 0.18,
              child: _Bar(value: c.heroHp / kHeroMaxHp, color: const Color(0xFF4ADE80), width: l.hero.width * 0.35),
            ),
            // Hero: never moves; idles until an enemy reaches it, then fights back.
            Positioned.fromRect(
              rect: l.hero,
              child: Column(children: [
                AnimatedBuilder(
                  animation: _hurt,
                  builder: (context, child) {
                    if (!_hurt.isAnimating) return child!;
                    final white = _hurt.value < 60 / 210;
                    return Transform.translate(
                      offset: const Offset(-4, 0),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          white ? Colors.white : const Color(0xAAEF4444),
                          white ? BlendMode.srcIn : BlendMode.srcATop,
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: SpriteAnim(
                    key: const Key('hero'),
                    sheet: fighting ? widget.hero.attack : widget.hero.idle,
                    size: l.hero.width,
                    playing: !c.isPaused,
                  ),
                ),
              ]),
            ),
            // HUD
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Ribbon(
                      color: RibbonColor.yellow,
                      child: Text(c.formattedTime, style: _pixel(30, Colors.white)),
                    ),
                    const SizedBox(height: 6),
                    _Tag('Phiên ${c.currentSession}/${c.totalSessions} · ${c.taskName}'),
                    const SizedBox(height: 10),
                    _HouseTracker(done: c.currentSession - 1, total: c.totalSessions),
                  ]),
                ),
              ),
            ),
            if (c.isPaused)
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0x99000000),
                  child: Center(child: _Tag('Tạm dừng ${c.formattedPauseTime}', fontSize: 22)),
                ),
              ),
            // Ghost controls
            if (!widget.victoryRun)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: _controlsDim ? 0.2 : 1,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Row(children: [
                        if (c.isPaused || c.canPause)
                          _GhostButton(
                            icon: c.isPaused
                                ? const PixelIcon('play', size: 44)
                                : const Icon(Icons.pause_rounded, size: 44, color: Colors.white),
                            label: c.isPaused ? 'Tiếp tục' : 'Tạm dừng',
                            onTap: () => c.isPaused ? c.resumeFromPause() : c.pause(),
                          ),
                        const Spacer(),
                        _giveUpButton(),
                      ]),
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  // The view may already be gone when the finger lifts after a successful give-up.
  void _releaseHold() {
    if (mounted) _hold.reset();
  }

  Widget _giveUpButton() {
    return Listener(
      key: const Key('give-up'),
      onPointerDown: (_) => _hold.forward(from: 0),
      onPointerUp: (_) => _releaseHold(),
      onPointerCancel: (_) => _releaseHold(),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox.square(
          dimension: 52,
          child: Stack(alignment: Alignment.center, children: [
            AnimatedBuilder(
              animation: _hold,
              builder: (context, _) => CircularProgressIndicator(
                value: _hold.value,
                strokeWidth: 3,
                color: const Color(0xFFEF4444),
                backgroundColor: Colors.transparent,
              ),
            ),
            const PixelIcon('cancel', size: 40),
          ]),
        ),
        Text('giữ 2s', style: _pixel(11, Colors.white)),
      ]),
    );
  }
}

TextStyle _pixel(double size, Color color) => TextStyle(
      fontFamily: kPixelFont,
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color,
      shadows: const [Shadow(offset: Offset(2, 2), color: Color(0xFF3B2A10))],
    );

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.fontSize = 13});
  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: const Color(0x80000000), borderRadius: BorderRadius.circular(4)),
        child: Text(text, style: _pixel(fontSize, Colors.white), overflow: TextOverflow.ellipsis),
      );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color, required this.width});
  final double value;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 8,
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(color: const Color(0xAA000000), border: Border.all(color: Colors.black)),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0), heightFactor: 1, child: ColoredBox(color: color)),
      );
}

class _HouseTracker extends StatelessWidget {
  const _HouseTracker({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total <= 1) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < total; i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Opacity(
            opacity: i <= done ? 1 : 0.4,
            child: Image.asset(i < done ? _goblinHouseDestroyed : _goblinHouse,
                width: 22, filterQuality: FilterQuality.none),
          ),
        ),
    ]);
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.icon, required this.label, required this.onTap});
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          icon,
          Text(label, style: _pixel(11, Colors.white)),
        ]),
      );
}
