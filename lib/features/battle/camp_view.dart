import 'package:flutter/material.dart';
import '../../core/game/sprites.dart';
import '../../core/widgets/ribbon.dart';
import '../../core/widgets/sprite_anim.dart';
import '../focus_session/focus_session_controller.dart';

const kWoodBg = Color(0xFF1B1712);
const kWoodBorder = Color(0xFF6B4F2A);
const kWoodText = Color(0xFFF5E6C8);

TextStyle woodText(double size, {Color color = kWoodText}) =>
    TextStyle(fontFamily: kPixelFont, fontSize: size, color: color, fontWeight: FontWeight.w700);

/// Rest break between sessions: campfire scene + session reward + skip button.
class CampView extends StatelessWidget {
  const CampView({super.key, required this.controller, required this.hero, this.onOpenVillage});

  final FocusSessionController controller;
  final CharacterSprites hero;
  final VoidCallback? onOpenVillage;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final reward = c.lastSessionReward;
    return ColoredBox(
      color: kWoodBg,
      child: Column(children: [
        Expanded(
          flex: 5,
          child: LayoutBuilder(builder: (context, box) {
            return Stack(children: [
              Positioned.fill(
                child: Image.asset('ui/scenes/camp_fire.webp',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.06),
                    filterQuality: FilterQuality.none),
              ),
              Positioned(
                left: box.maxWidth * 0.12,
                top: box.maxHeight * 0.42,
                child: SpriteAnim(sheet: hero.idle, size: box.maxWidth * 0.3),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Ribbon(
                      color: RibbonColor.blue,
                      child: Text('${c.isLongRest ? 'Nghỉ dài' : 'Nghỉ'} ${c.formattedTime}',
                          style: woodText(24, color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ]);
          }),
        ),
        Expanded(
          flex: 5,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: kWoodBg,
              border: Border(top: BorderSide(color: kWoodBorder, width: 3)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SafeArea(
              top: false,
              child: Column(children: [
                Text('Phiên ${c.currentSession}/${c.totalSessions} hoàn thành', style: woodText(16)),
                const SizedBox(height: 12),
                if (reward != null)
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const PixelIcon('coin', size: 30),
                    Text('+${reward.coins}', style: woodText(22)),
                    const SizedBox(width: 24),
                    const PixelIcon('log', size: 30),
                    Text('+${reward.logs}', style: woodText(22)),
                  ]),
                const SizedBox(height: 8),
                Text(
                  'Quỹ trận: ${c.pendingCoins} coin · ${c.pendingLogs} log — nhận khi xong trận',
                  textAlign: TextAlign.center,
                  style: woodText(12, color: kWoodText.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 16),
                if (onOpenVillage != null)
                  OutlinedButton.icon(
                    onPressed: onOpenVillage,
                    icon: const PixelIcon('hammer', size: 22),
                    label: Text('Vào làng', style: woodText(15)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: kWoodBorder, width: 2)),
                  ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: c.finishRestBreak,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC2410C),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('⚔ XUNG TRẬN NGAY', style: woodText(17, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 14),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
