import 'package:flutter/material.dart';
import '../../core/game/player_state.dart';
import '../../core/game/progression.dart';
import '../../core/game/sprites.dart';
import '../../core/widgets/flat_theme.dart';
import '../../core/widgets/sprite_anim.dart';

/// Characters to take into battle and the 5×5 rank badge grid (pick one as avatar).
class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key, required this.player, required this.totalFocusSeconds});

  final PlayerState player;
  final int totalFocusSeconds;

  static const _dim = ColorFilter.matrix([
    0.1, 0.1, 0.1, 0, 0, //
    0.1, 0.1, 0.1, 0, 0,
    0.1, 0.1, 0.1, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final rank = rankForSeconds(totalFocusSeconds);
    final next = nextRank(rank);
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const Text('Bộ sưu tập', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          const Text('NHÂN VẬT · chọn để ra trận', style: Flat.label),
          const SizedBox(height: 8),
          Row(children: [for (final c in GameCharacter.values) Expanded(child: _characterTile(c, rank))]),
          const SizedBox(height: 20),
          const Text('HUY HIỆU · chọn 1 làm avatar', style: Flat.label),
          const SizedBox(height: 8),
          Row(children: [
            const SizedBox(width: 56),
            for (final r in Rank.values)
              Expanded(child: Text(r.label, textAlign: TextAlign.center, style: Flat.label, maxLines: 1)),
          ]),
          for (final c in GameCharacter.values)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                SizedBox(width: 56, child: Text(c.label, style: const TextStyle(fontSize: 12))),
                for (final r in Rank.values) Expanded(child: _badgeTile(c, r, rank)),
              ]),
            ),
          if (next != null) ...[
            const SizedBox(height: 14),
            Text(
              'Còn ${next.thresholdHours - totalFocusSeconds ~/ 3600}h để mở '
              '${GameCharacter.values[next.index].label} + huy hiệu ${next.label}',
              style: Flat.label,
            ),
          ],
        ],
      ),
    );
  }

  Widget _characterTile(GameCharacter c, Rank rank) {
    final unlocked = isCharacterUnlocked(c, rank);
    final selected = player.selectedCharacter == c;
    final sprite = SpriteAnim(sheet: characterSprites[c]!.idle, size: 56, playing: unlocked);
    return GestureDetector(
      key: Key('char-${c.name}'),
      onTap: () => player.selectCharacter(c, rank),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.only(bottom: 4),
        decoration: Flat.cardBox(borderColor: selected ? Flat.accent : null),
        child: Column(children: [
          unlocked ? sprite : ColorFiltered(colorFilter: _dim, child: sprite),
          Text(unlocked ? c.label : c.unlockRank.label,
              style: TextStyle(fontSize: 10, color: unlocked ? Flat.text : Flat.muted), maxLines: 1),
        ]),
      ),
    );
  }

  Widget _badgeTile(GameCharacter c, Rank badge, Rank rank) {
    final unlocked = isBadgeUnlocked(c, badge, rank);
    final selected = player.badgeCharacter == c && player.badgeRank == badge;
    final image = Image.asset(badgeAsset(c, badge), filterQuality: FilterQuality.none);
    return GestureDetector(
      key: Key('badge-${c.name}_${badge.name}'),
      onTap: () => player.selectBadge(c, badge, rank),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? Flat.accent : Colors.transparent, width: 2),
        ),
        child: AspectRatio(
          aspectRatio: 1,
          child: unlocked ? image : ColorFiltered(colorFilter: _dim, child: image),
        ),
      ),
    );
  }
}
