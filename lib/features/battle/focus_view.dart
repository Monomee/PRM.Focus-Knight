import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/game/economy.dart';
import '../../core/game/sprites.dart';
import '../../core/widgets/ribbon.dart';
import '../../core/widgets/sprite_anim.dart';
import '../focus_session/focus_session_controller.dart';

const _goblinHouse = 'ui/buildings/enemy_building/Goblin_House.png';
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

  /// Session just ended: hero runs off to the right, no enemies.
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

  Timer? _enemyTimer;
  int _enemyIndex = 0;
  bool _enemyArrived = false;
  bool _enemyVisible = false;

  @override
  void initState() {
    super.initState();
    _wakeControls();
    widget.controller.addListener(_onController);
    _spawnEnemy();
    _enemyTimer = Timer.periodic(const Duration(seconds: 4), (_) => _spawnEnemy());
  }

  void _onController() {
    final hp = widget.controller.heroHp;
    if (hp < _lastHp) _hurt.forward(from: 0);
    _lastHp = hp;
  }

  void _spawnEnemy() {
    if (!mounted || widget.victoryRun || widget.controller.isPaused) return;
    setState(() {
      _enemyIndex = _random.nextInt(enemySprites.length);
      _enemyArrived = false;
      _enemyVisible = true;
    });
    // Next frame: start running towards the hero.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _enemyArrived = true);
    });
    Future.delayed(const Duration(milliseconds: 3400), () {
      if (mounted) setState(() => _enemyVisible = false);
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
        final w = box.maxWidth, h = box.maxHeight;
        final heroSize = w * 0.5;
        final enemySize = w * 0.42;
        final groundTop = h * 0.46;
        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset('ui/scenes/battle_field.webp',
                  fit: BoxFit.cover, filterQuality: FilterQuality.none),
            ),
            // Goblin house = session HP
            if (!widget.victoryRun)
              Positioned(
                right: w * 0.03,
                top: groundTop - w * 0.14,
                child: Column(children: [
                  _Bar(value: c.houseHpRatio, color: const Color(0xFFF87171), width: w * 0.24),
                  Image.asset(_goblinHouse, width: w * 0.34, filterQuality: FilterQuality.none),
                ]),
              )
            else
              Positioned(
                right: w * 0.03,
                top: groundTop,
                child: Image.asset(_goblinHouseDestroyed, width: w * 0.28, filterQuality: FilterQuality.none),
              ),
            // Enemy running out of the house
            if (_enemyVisible && !widget.victoryRun && !c.isPaused)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 1600),
                left: _enemyArrived ? w * 0.04 + heroSize * 0.45 : w * 0.58,
                top: groundTop + heroSize * 0.08,
                child: SpriteAnim(
                  sheet: _enemyArrived ? enemySprites[_enemyIndex].attack : enemySprites[_enemyIndex].run,
                  size: enemySize,
                  flipX: true,
                ),
              ),
            // Hero
            AnimatedPositioned(
              duration: const Duration(milliseconds: 800),
              left: widget.victoryRun ? w : w * 0.04,
              top: groundTop,
              child: Column(children: [
                _Bar(value: c.heroHp / kHeroMaxHp, color: const Color(0xFF4ADE80), width: heroSize * 0.35),
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
                    sheet: widget.victoryRun ? widget.hero.run : widget.hero.attack,
                    size: heroSize,
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
