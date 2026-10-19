import 'package:flutter/material.dart';
import '../../core/game/player_state.dart';
import '../../core/game/progression.dart';
import '../../core/game/village.dart';
import '../../core/widgets/sprite_anim.dart';
import '../battle/camp_view.dart';
import 'building_sheet.dart';

/// Where an image of [image] size lands inside [box] with [BoxFit.cover], centered.
Rect coverRect(Size box, Size image) {
  final scale = box.width / image.width > box.height / image.height
      ? box.width / image.width
      : box.height / image.height;
  final w = image.width * scale, h = image.height * scale;
  return Rect.fromLTWH((box.width - w) / 2, (box.height - h) / 2, w, h);
}

/// Village map: one fixed slot per building, placed in image space on `village.webp`
/// so slots stay on the grass whatever the phone's aspect ratio crops away.
class VillageScreen extends StatelessWidget {
  const VillageScreen({super.key, required this.player, required this.totalFocusSeconds});

  final PlayerState player;
  final int totalFocusSeconds;

  static const imageSize = Size(1080, 1920);

  /// Space under each sprite for the name and lock lines, and the minimum column width.
  static const labelBand = 40.0;
  static const labelWidth = 100.0;

  // (left, top, width) as fractions of the background image; grass spans ~x 0.06–0.94, y 0.22–0.80,
  // campfire at ~(0.5, 0.46). Label columns are centered at x ~0.21–0.78 so they survive the side crop
  // of tall phones.
  static const _slots = <Building, (double, double, double)>{
    Building.tower: (0.155, 0.23, 0.12),
    Building.castle: (0.35, 0.23, 0.30),
    Building.barracks: (0.69, 0.23, 0.18),
    Building.granary: (0.145, 0.43, 0.14),
    Building.archery: (0.68, 0.43, 0.18),
    Building.house2: (0.145, 0.63, 0.14),
    Building.monastery: (0.41, 0.555, 0.18),
    Building.house3: (0.69, 0.63, 0.14),
  };


  /// Sprite width / height (the Tiny Swords building sheets).
  static const _aspect = <Building, double>{
    Building.tower: 128 / 256,
    Building.castle: 320 / 256,
    Building.barracks: 192 / 256,
    Building.granary: 128 / 192,
    Building.archery: 192 / 256,
    Building.house2: 128 / 192,
    Building.monastery: 192 / 320,
    Building.house3: 128 / 192,
  };

  /// Whole footprint of a slot: the sprite plus the (possibly wider) label column under it.
  static Rect slotArea(Building b, Size box) {
    final r = slotRect(b, box);
    final width = r.width > labelWidth ? r.width : labelWidth;
    return Rect.fromLTWH(r.center.dx - width / 2, r.top, width, r.height + labelBand);
  }

  /// Sprite rect of a slot in [box] coordinates; the label band sits below it.
  static Rect slotRect(Building b, Size box) {
    final img = coverRect(box, imageSize);
    final (l, t, w) = _slots[b]!;
    final width = w * img.width;
    return Rect.fromLTWH(img.left + l * img.width, img.top + t * img.height, width, width / _aspect[b]!);
  }

  @override
  Widget build(BuildContext context) {
    final rank = rankForSeconds(totalFocusSeconds);
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) => LayoutBuilder(builder: (context, box) {
        return Stack(children: [
          Positioned.fill(
            child: Image.asset('ui/scenes/village.webp', fit: BoxFit.cover, filterQuality: FilterQuality.none),
          ),
          for (final b in _slots.keys) _positioned(context, b, rank, box.biggest),
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

  Widget _positioned(BuildContext context, Building b, Rank rank, Size box) {
    final area = slotArea(b, box);
    return Positioned(
      left: area.left,
      top: area.top,
      width: area.width,
      child: _slot(context, b, rank, slotRect(b, box).size),
    );
  }

  Widget _slot(BuildContext context, Building b, Rank rank, Size sprite) {
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
          Image.asset(b.asset,
              width: sprite.width, height: sprite.height, fit: BoxFit.contain, filterQuality: FilterQuality.none)
        else
          SizedBox.fromSize(
            size: sprite,
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
