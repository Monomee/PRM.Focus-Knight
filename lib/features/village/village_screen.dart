import 'package:flutter/material.dart';
import '../../core/game/player_state.dart';
import '../../core/game/progression.dart';
import '../../core/game/village.dart';
import '../../core/widgets/sprite_anim.dart';
import '../battle/camp_view.dart';
import 'building_sheet.dart';

/// Village map: one fixed slot per building, positioned as fractions of the map area.
class VillageScreen extends StatelessWidget {
  const VillageScreen({super.key, required this.player, required this.totalFocusSeconds});

  final PlayerState player;
  final int totalFocusSeconds;

  // (left, top, width) as fractions of the map size.
  static const _slots = <Building, (double, double, double)>{
    Building.castle: (0.30, 0.08, 0.40),
    Building.tower: (0.05, 0.12, 0.16),
    Building.barracks: (0.72, 0.10, 0.25),
    Building.granary: (0.06, 0.42, 0.20),
    Building.archery: (0.70, 0.40, 0.26),
    Building.house2: (0.06, 0.70, 0.20),
    Building.monastery: (0.38, 0.66, 0.24),
    Building.house3: (0.72, 0.70, 0.20),
  };

  @override
  Widget build(BuildContext context) {
    final rank = rankForSeconds(totalFocusSeconds);
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) => LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        return Stack(children: [
          Positioned.fill(
            child: Image.asset('ui/scenes/camp_fire.webp',
                fit: BoxFit.cover, alignment: const Alignment(0, 0.1), filterQuality: FilterQuality.none),
          ),
          for (final e in _slots.entries)
            Positioned(
              left: e.value.$1 * w,
              top: e.value.$2 * h,
              width: e.value.$3 * w,
              child: _slot(context, e.key, rank),
            ),
          Positioned(
            left: 12,
            right: 12,
            top: 10,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(
                child: _tag(Text('Làng của bạn',
                    style: woodText(16, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ),
              const SizedBox(width: 8),
              _tag(Row(mainAxisSize: MainAxisSize.min, children: [
                const PixelIcon('coin', size: 20),
                Text(' ${player.coins}  ', style: woodText(13, color: Colors.white)),
                const PixelIcon('log', size: 20),
                Text(' ${player.logs}', style: woodText(13, color: Colors.white)),
              ])),
            ]),
          ),
        ]);
      }),
    );
  }

  Widget _tag(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(6)),
        child: child,
      );

  Widget _slot(BuildContext context, Building b, Rank rank) {
    final level = player.levelOf(b);
    final required = b.requiredCharacter;
    final locked = required != null && !isCharacterUnlocked(required, rank);
    final label = TextStyle(
      fontFamily: kPixelFont,
      fontSize: 11,
      color: Colors.white,
      shadows: const [Shadow(offset: Offset(1, 1), color: Colors.black)],
    );

    return GestureDetector(
      key: Key('slot-${b.name}'),
      onTap: () => showBuildingSheet(context, player: player, building: b, rank: rank),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (level > 0)
          Image.asset(b.asset, filterQuality: FilterQuality.none)
        else
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0x33000000),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x99FFFFFF), width: 2),
              ),
              alignment: Alignment.center,
              child: Opacity(opacity: locked ? 0.4 : 0.9, child: const PixelIcon('hammer', size: 28)),
            ),
          ),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(color: const Color(0xAA000000), borderRadius: BorderRadius.circular(3)),
          child: Text(level > 0 ? '${b.label} Lv$level' : b.label,
              style: label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (locked) Text('🔒 ${required.unlockRank.label}', style: label),
      ]),
    );
  }
}
