import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'combat_engine.dart';
import 'models/skin_cosmetics.dart';

/// A 100% procedural pixel art canvas for FocusKnight.
/// Renders a pixelated Knight Hero, Monster, ground line with scrolling animation,
/// health bars, screen shake on CRIT, and floating damage numbers purely through [CustomPainter].
class PixelStageCanvas extends StatefulWidget {
  final CombatEngine? engine;
  final HeroSkin? skin;
  final CampCosmetic? campCosmetic;
  final String? countdownText;
  final Color? timerColor;

  const PixelStageCanvas({
    super.key,
    this.engine,
    this.skin,
    this.campCosmetic,
    this.countdownText,
    this.timerColor,
  });

  @override
  State<PixelStageCanvas> createState() => _PixelStageCanvasState();
}

class _PixelStageCanvasState extends State<PixelStageCanvas>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listenable = widget.engine != null
        ? Listenable.merge([_animController, widget.engine!])
        : _animController;

    return AnimatedBuilder(
      animation: listenable,
      builder: (context, child) {
        return ClipRect(
          child: CustomPaint(
            size: Size.infinite,
            painter: _PixelStagePainter(
              animationValue: _animController.value,
              engine: widget.engine,
              skin: widget.skin,
              campCosmetic: widget.campCosmetic,
              countdownText: widget.countdownText,
              timerColor: widget.timerColor,
            ),
          ),
        );
      },
    );
  }
}

class _PixelStagePainter extends CustomPainter {
  final double animationValue;
  final CombatEngine? engine;
  final HeroSkin? skin;
  final CampCosmetic? campCosmetic;
  final String? countdownText;
  final Color? timerColor;

  _PixelStagePainter({
    required this.animationValue,
    this.engine,
    this.skin,
    this.campCosmetic,
    this.countdownText,
    this.timerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 0. Apply Screen Shake (Canvas Offset on Critical Hits)
    canvas.save();
    if (engine != null && engine!.isShaking) {
      canvas.translate(
        engine!.currentShakeOffset.dx,
        engine!.currentShakeOffset.dy,
      );
    }

    // 1. Background Sky & Atmosphere
    _drawBackground(canvas, size);

    // 2. Scrolling Ground & Terrain
    final groundY = size.height * 0.72;
    _drawGround(canvas, size, groundY);

    // Base pixel unit size scaled proportionally to screen height
    final pixelSize = math.max(3.0, (size.height / 100).floorToDouble());

    // 3. Hero (left-center)
    final heroX = size.width * 0.28;
    final heroWalkBob = (engine?.isDefeated == true)
        ? 0.0
        : math.sin(animationValue * 2 * math.pi) * (pixelSize * 0.8);
    final heroY = groundY - (16 * pixelSize) + heroWalkBob;

    _drawHero(
      canvas,
      heroX,
      heroY,
      pixelSize,
      animationValue,
      engine?.heroAttacking == true,
      engine?.heroHurt == true,
      engine?.isDefeated == true,
      skin,
    );

    // 3.5. Companion Pet (if equipped)
    if (campCosmetic != null && campCosmetic!.id == 'slime_pet') {
      _drawSlimeCompanion(
        canvas,
        heroX - (14 * pixelSize),
        groundY,
        pixelSize,
        animationValue,
        campCosmetic!.primaryColor,
      );
    }

    // 4. Monster (right-center)
    final monsterX = size.width * 0.72;
    final monsterIdleBob = math.cos(animationValue * 2 * math.pi) * (pixelSize * 0.5);
    final monsterY = groundY - (16 * pixelSize) + monsterIdleBob;

    _drawMonster(
      canvas,
      monsterX,
      monsterY,
      pixelSize,
      animationValue,
      engine?.monsterHurt == true,
      engine?.monsterCurrentHp ?? 1,
    );

    // 5. Combat Health Bars
    if (engine != null) {
      _drawHealthBars(canvas, size, groundY, pixelSize);
    }

    // 6. Floating Damage Texts
    if (engine != null) {
      _drawDamageTexts(canvas, size);
    }

    // 7. Stage Header Banner (HUD)
    _drawStageHeader(canvas, size);

    // 8. Defeated / Respawning Overlay
    if (engine?.isDefeated == true) {
      _drawDefeatedBanner(canvas, size);
    }

    canvas.restore();
  }

  /// Atmospheric gradient sky and procedural stars/particles
  void _drawBackground(Canvas canvas, Size size) {
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF0F111A), // Deep void night
          Color(0xFF1B1E2E), // Midnight indigo
          Color(0xFF282A3E), // Horizon mist
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // Subtle twinkling pixel stars
    final starPaint = Paint()..color = const Color(0x66FFFFFF);
    const starCoords = [
      [0.10, 0.15],
      [0.25, 0.08],
      [0.45, 0.20],
      [0.60, 0.12],
      [0.78, 0.18],
      [0.90, 0.07],
      [0.35, 0.30],
      [0.70, 0.28],
    ];

    for (var i = 0; i < starCoords.length; i++) {
      final sx = starCoords[i][0] * size.width;
      final sy = starCoords[i][1] * size.height;
      final twinkle = (math.sin((animationValue + i * 0.2) * 2 * math.pi) + 1) / 2;
      final alpha = (80 + 175 * twinkle).toInt();
      starPaint.color = Color.fromARGB(alpha, 255, 255, 255);
      canvas.drawRect(Rect.fromLTWH(sx, sy, 3, 3), starPaint);
    }
  }

  /// Scrolling ground line simulating forward movement
  void _drawGround(Canvas canvas, Size size, double groundY) {
    // Ground depth fill
    final groundFillPaint = Paint()..color = const Color(0xFF1E222D);
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, size.width, size.height - groundY),
      groundFillPaint,
    );

    // Top surface stone line
    final topBorderPaint = Paint()..color = const Color(0xFF4B5563);
    canvas.drawRect(Rect.fromLTWH(0, groundY, size.width, 4), topBorderPaint);

    // Secondary sub-surface earth line
    final subLinePaint = Paint()..color = const Color(0xFF374151);
    canvas.drawRect(Rect.fromLTWH(0, groundY + 4, size.width, 3), subLinePaint);

    // Procedural scrolling stones & grass tufts
    const blockSpacing = 40.0;
    final isWalking = engine?.isDefeated != true;
    final scrollOffset = isWalking
        ? (animationValue * blockSpacing * 2) % blockSpacing
        : 0.0;

    final stonePaint = Paint()..color = const Color(0xFF6B7280);
    final darkStonePaint = Paint()..color = const Color(0xFF2D3748);
    final grassPaint = Paint()..color = const Color(0xFF22C55E);

    for (double x = -blockSpacing; x < size.width + blockSpacing; x += blockSpacing) {
      final actualX = x - scrollOffset;

      // Surface grass tufts
      canvas.drawRect(Rect.fromLTWH(actualX + 4, groundY - 3, 3, 3), grassPaint);
      canvas.drawRect(Rect.fromLTWH(actualX + 7, groundY - 5, 3, 5), grassPaint);

      // Embedded ground cobblestones
      canvas.drawRect(Rect.fromLTWH(actualX + 12, groundY + 10, 8, 4), stonePaint);
      canvas.drawRect(Rect.fromLTWH(actualX + 26, groundY + 18, 12, 5), darkStonePaint);
      canvas.drawRect(Rect.fromLTWH(actualX + 6, groundY + 28, 14, 4), darkStonePaint);
    }
  }

  /// 100% Procedural Pixel Knight Hero (with attack thrust, hurt flash, and skin palette swap)
  void _drawHero(
    Canvas canvas,
    double originX,
    double originY,
    double p,
    double anim,
    bool isAttacking,
    bool isHurt,
    bool isDefeated, [
    HeroSkin? skin,
  ]) {
    if (isDefeated) {
      // Fallen Hero pose
      final fallenPaint = Paint()..color = const Color(0x8890A4AE);
      canvas.drawRect(
        Rect.fromLTWH(originX, originY + 12 * p, 16 * p, 4 * p),
        fallenPaint,
      );
      return;
    }

    final shadowPaint = Paint()..color = const Color(0x55000000);
    final groundY = originY + (16 * p);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(originX + 7 * p, groundY + 2),
        width: 14 * p,
        height: 4 * p,
      ),
      shadowPaint,
    );

    // Stride cycle for legs: alternating forward & back
    final legStride = math.sin(anim * 2 * math.pi) * 2;
    // Sword thrust offset during attack
    final swordLunge = isAttacking ? 3.5 * p : 0.0;

    void pixel(double col, double row, Color color, [double w = 1, double h = 1]) {
      final finalColor = isHurt ? const Color(0xFFFF5252) : color;
      final paint = Paint()..color = finalColor;
      canvas.drawRect(
        Rect.fromLTWH(originX + (col * p), originY + (row * p), w * p, h * p),
        paint,
      );
    }

    // Color Palette based on selected HeroSkin
    final steelLight = skin?.armorLight ?? const Color(0xFFCFD8DC);
    final steelMid = skin != null
        ? Color.lerp(skin.armorLight, skin.armorDark, 0.4)!
        : const Color(0xFF90A4AE);
    final steelDark = skin?.armorDark ?? const Color(0xFF455A64);
    final gold = skin?.swordHilt ?? const Color(0xFFFFC107);
    final goldBright = skin?.swordBlade ?? const Color(0xFFFFD54F);
    final capeRed = skin?.capeColor ?? const Color(0xFFDC2626);
    final capeDark = skin != null
        ? Color.lerp(skin.capeColor, Colors.black, 0.35)!
        : const Color(0xFF991B1B);
    final visorColor = skin?.visorColor ?? const Color(0xFF1E293B);

    // 1. Cape (Behind Hero)
    final capeWave = math.sin((anim * 2 * math.pi) + 1.2) * 1.5;
    pixel(2 - capeWave * 0.3, 6, capeDark, 2, 7);
    pixel(1 - capeWave * 0.6, 8, capeRed, 2, 6);
    pixel(0 - capeWave * 0.9, 10, capeRed, 2, 5);

    // 2. Legs & Iron Boots
    pixel(4 - legStride * 0.5, 12, steelDark, 2, 3);
    pixel(4 - legStride * 0.7, 15, steelMid, 3, 2);
    pixel(7 + legStride * 0.5, 12, steelDark, 2, 3);
    pixel(7 + legStride * 0.7, 15, steelMid, 3, 2);

    // 3. Torso / Breastplate & Belt
    pixel(4, 7, steelMid, 6, 4);
    pixel(5, 7, steelLight, 4, 3);
    pixel(4, 11, const Color(0xFF374151), 6, 1);
    pixel(6, 11, gold, 2, 1);

    // 4. Knight Helmet & Visor
    pixel(4, 1, steelMid, 6, 2);
    pixel(3, 2, steelMid, 8, 4);
    pixel(4, 2, steelLight, 5, 2);
    pixel(2, 0, capeRed, 3, 2);
    pixel(4, 0, capeDark, 3, 1);
    pixel(5, 4, goldBright, 5, 1);
    pixel(6, 4, visorColor, 2, 1);
    pixel(4, 5, steelDark, 6, 2);

    // 5. Shield
    pixel(2, 7, steelLight, 2, 4);
    pixel(1, 8, gold, 1, 2);

    // 6. Right Arm & Heroic Sword (lunges forward during attack)
    final swordCol = 9.0 + (swordLunge / p);
    pixel(swordCol, 8, steelLight, 2, 2);
    pixel(swordCol + 1, 6, gold, 1, 4);
    pixel(swordCol, 7, goldBright, 3, 1);
    pixel(swordCol - 1, 7, const Color(0xFF78350F), 2, 1);
    // Blade
    pixel(swordCol + 2, 7, skin?.swordBlade ?? const Color(0xFFFFFFFF), 6, 1);
    pixel(swordCol + 2, 8, steelLight, 5, 1);
  }

  /// Procedural Companion Slime Pet
  void _drawSlimeCompanion(
    Canvas canvas,
    double originX,
    double groundY,
    double p,
    double anim,
    Color slimeColor,
  ) {
    final bounce = math.sin(anim * 2 * math.pi).abs() * (2.5 * p);
    final slimeY = groundY - (7 * p) - bounce;

    // Shadow
    final shadowPaint = Paint()..color = const Color(0x44000000);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(originX + 4 * p, groundY + 1),
        width: 8 * p,
        height: 3 * p,
      ),
      shadowPaint,
    );

    void spixel(double col, double row, Color color, [double w = 1, double h = 1]) {
      final paint = Paint()..color = color;
      canvas.drawRect(
        Rect.fromLTWH(originX + (col * p), slimeY + (row * p), w * p, h * p),
        paint,
      );
    }

    // Slime body
    spixel(2, 1, slimeColor, 4, 1);
    spixel(1, 2, slimeColor, 6, 3);
    spixel(0, 3, slimeColor, 8, 3);
    spixel(1, 6, slimeColor, 6, 1);

    // Slime shine
    spixel(2, 2, Colors.white.withValues(alpha: 0.6), 2, 1);

    // Cute eyes
    spixel(2, 4, const Color(0xFF0F172A), 1, 1);
    spixel(5, 4, const Color(0xFF0F172A), 1, 1);
  }

  /// 100% Procedural Pixel Monster (with hurt recoil)
  void _drawMonster(
    Canvas canvas,
    double originX,
    double originY,
    double p,
    double anim,
    bool isHurt,
    int currentHp,
  ) {
    if (currentHp <= 0) return; // Vanish on death

    final shadowPaint = Paint()..color = const Color(0x55000000);
    final groundY = originY + (16 * p);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(originX + 7 * p, groundY + 2),
        width: 16 * p,
        height: 4 * p,
      ),
      shadowPaint,
    );

    final breathSquash = math.sin(anim * 2 * math.pi) * (p * 0.4);
    final hurtPushBack = isHurt ? (2.0 * p) : 0.0;

    void pixel(double col, double row, Color color, [double w = 1, double h = 1]) {
      final finalColor = isHurt ? const Color(0xFFFFFFFF) : color;
      final paint = Paint()..color = finalColor;
      canvas.drawRect(
        Rect.fromLTWH(
          originX + (col * p) + hurtPushBack,
          originY + (row * p) + breathSquash,
          w * p,
          h * p,
        ),
        paint,
      );
    }

    const beastDark = Color(0xFF14532D);
    const beastMid = Color(0xFF16A34A);
    const beastLight = Color(0xFF4ADE80);
    const hornColor = Color(0xFF78350F);
    const eyeRed = Color(0xFFEF4444);
    const eyeYellow = Color(0xFFFACC15);
    const fangWhite = Color(0xFFF9FAFB);

    // 1. Spiked Horns
    pixel(2, 0, hornColor, 2, 3);
    pixel(1, 0, const Color(0xFF451A03), 1, 2);
    pixel(10, 0, hornColor, 2, 3);
    pixel(12, 0, const Color(0xFF451A03), 1, 2);

    // 2. Head / Brow
    pixel(3, 2, beastDark, 8, 3);
    pixel(4, 3, beastMid, 6, 2);

    // 3. Menacing Glowing Red & Yellow Eyes
    pixel(4, 4, eyeRed, 2, 2);
    pixel(4, 4, eyeYellow, 1, 1);
    pixel(8, 4, eyeRed, 2, 2);
    pixel(9, 4, eyeYellow, 1, 1);

    // 4. Snout & Sharp Fangs
    pixel(4, 6, beastDark, 6, 3);
    pixel(5, 7, fangWhite, 1, 2);
    pixel(8, 7, fangWhite, 1, 2);

    // 5. Body & Spikes
    pixel(2, 8, beastMid, 10, 6);
    pixel(3, 9, beastLight, 8, 4);
    pixel(1, 10, beastDark, 1, 3);
    pixel(12, 10, beastDark, 1, 3);

    // 6. Monster Claws & Feet
    pixel(3, 14, beastDark, 3, 2);
    pixel(3, 16, const Color(0xFF052E16), 3, 1);
    pixel(8, 14, beastDark, 3, 2);
    pixel(8, 16, const Color(0xFF052E16), 3, 1);
  }

  /// Combat Health Bars above Hero and Monster
  void _drawHealthBars(
    Canvas canvas,
    Size size,
    double groundY,
    double pixelSize,
  ) {
    if (engine == null) return;

    // --- Hero HP Bar ---
    final heroX = size.width * 0.28;
    final heroBarY = groundY - (21 * pixelSize);
    final heroRatio = (engine!.currentHp / engine!.maxHp).clamp(0.0, 1.0);
    _drawBar(
      canvas,
      heroX - 4,
      heroBarY,
      60,
      6,
      heroRatio,
      const Color(0xFF22C55E), // Vibrant Green
      'HP ${engine!.currentHp}/${engine!.maxHp}',
    );

    // --- Monster HP Bar ---
    if (engine!.monsterCurrentHp > 0) {
      final monsterX = size.width * 0.72;
      final monsterBarY = groundY - (21 * pixelSize);
      final monsterRatio = (engine!.monsterCurrentHp / engine!.monsterMaxHp).clamp(0.0, 1.0);
      _drawBar(
        canvas,
        monsterX - 6,
        monsterBarY,
        64,
        6,
        monsterRatio,
        const Color(0xFFEF4444), // Fiery Red
        '${engine!.monsterName}: ${engine!.monsterCurrentHp}',
      );
    }
  }

  void _drawBar(
    Canvas canvas,
    double x,
    double y,
    double width,
    double height,
    double ratio,
    Color fillColor,
    String label,
  ) {
    // Outer border
    final borderPaint = Paint()..color = const Color(0xFF1E293B);
    canvas.drawRect(Rect.fromLTWH(x - 1, y - 1, width + 2, height + 2), borderPaint);

    // Background track
    final bgPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRect(Rect.fromLTWH(x, y, width, height), bgPaint);

    // Active fill
    if (ratio > 0) {
      final fillPaint = Paint()..color = fillColor;
      canvas.drawRect(Rect.fromLTWH(x, y, width * ratio, height), fillPaint);
    }

    // Small label above bar
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 8,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(x + (width - textPainter.width) / 2, y - 10));
  }

  /// Floating Combat Text (Damage numbers, CRIT, Gold)
  void _drawDamageTexts(Canvas canvas, Size size) {
    if (engine == null) return;

    final now = engine!.elapsedSeconds;
    for (final dmg in engine!.damageTexts) {
      final elapsed = now - dmg.createdAt;
      final progress = (elapsed / dmg.duration).clamp(0.0, 1.0);
      final riseOffset = progress * 32.0; // Float upward
      final alpha = ((1.0 - progress) * 255).toInt().clamp(0, 255);

      final originX = dmg.position.dx * size.width;
      final originY = (dmg.position.dy * size.height) - riseOffset;

      final textColor = dmg.color.withAlpha(alpha);

      final textPainter = TextPainter(
        text: TextSpan(
          text: dmg.text,
          style: TextStyle(
            color: textColor,
            fontSize: dmg.isCrit ? 15 : 12,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: Colors.black.withAlpha(alpha),
                offset: const Offset(1.5, 1.5),
                blurRadius: 1,
              ),
              Shadow(
                color: Colors.black.withAlpha(alpha),
                offset: const Offset(-1.5, -1.5),
                blurRadius: 1,
              ),
              if (dmg.isCrit)
                Shadow(
                  color: const Color(0xFFFFB300).withAlpha(alpha),
                  blurRadius: 8,
                ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(originX - textPainter.width / 2, originY - textPainter.height / 2),
      );
    }
  }

  /// Stage header banner
  void _drawStageHeader(Canvas canvas, Size size) {
    final stageNum = engine?.currentStage ?? 1;
    final stageName = engine?.monsterName ?? 'Goblin Forest';

    const textStyle = TextStyle(
      color: Color(0xFFFFD54F),
      fontSize: 13,
      fontWeight: FontWeight.w900,
      letterSpacing: 2.0,
      shadows: [
        Shadow(color: Colors.black, offset: Offset(1.5, 1.5), blurRadius: 0),
        Shadow(color: Colors.black, offset: Offset(-1.5, -1.5), blurRadius: 0),
      ],
    );

    final stageText = 'STAGE $stageNum • $stageName'.toUpperCase();
    final textSpan = TextSpan(text: stageText, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, 24),
        width: textPainter.width + 24,
        height: 26,
      ),
      const Radius.circular(6),
    );

    final bannerBgPaint = Paint()..color = const Color(0xCC111827);
    final bannerBorderPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(bgRect, bannerBgPaint);
    canvas.drawRRect(bgRect, bannerBorderPaint);

    textPainter.paint(
      canvas,
      Offset(size.width / 2 - textPainter.width / 2, 24 - textPainter.height / 2),
    );

    // Large Countdown Timer directly below the STAGE line - NO background container, clean large text
    if (countdownText != null && countdownText!.isNotEmpty) {
      final timeStyle = TextStyle(
        color: timerColor ?? const Color(0xFFFFB300),
        fontSize: 42,
        fontWeight: FontWeight.w900,
        fontFamily: 'monospace',
        letterSpacing: 2.5,
        shadows: const [
          Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 4),
          Shadow(color: Colors.black, offset: Offset(-2, -2), blurRadius: 4),
          Shadow(color: Color(0xAA000000), offset: Offset(0, 3), blurRadius: 6),
        ],
      );

      final timerPainter = TextPainter(
        text: TextSpan(text: countdownText, style: timeStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      timerPainter.paint(
        canvas,
        Offset(size.width / 2 - timerPainter.width / 2, 44),
      );
    }
  }

  /// Defeated state overlay: 2s timer banner
  void _drawDefeatedBanner(Canvas canvas, Size size) {
    // Red dark vignette
    final vignettePaint = Paint()..color = const Color(0x887F1D1D);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignettePaint);

    final timeRemaining = engine!.defeatTimer.clamp(0.0, 2.0).toStringAsFixed(1);
    final bannerText = 'DEFEATED • RETRYING IN ${timeRemaining}s';

    final textPainter = TextPainter(
      text: TextSpan(
        text: bannerText,
        style: const TextStyle(
          color: Color(0xFFFCA5A5),
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          shadows: [
            Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 4),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final bannerRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.40),
        width: textPainter.width + 32,
        height: 36,
      ),
      const Radius.circular(8),
    );

    final bgPaint = Paint()..color = const Color(0xEE18181B);
    final strokePaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(bannerRect, bgPaint);
    canvas.drawRRect(bannerRect, strokePaint);

    textPainter.paint(
      canvas,
      Offset(
        size.width / 2 - textPainter.width / 2,
        size.height * 0.40 - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _PixelStagePainter oldDelegate) {
    return true; // Continuously animated at 60 FPS
  }
}
