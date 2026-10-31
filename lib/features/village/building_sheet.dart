import 'package:flutter/material.dart';
import '../../core/game/player_state.dart';
import '../../core/game/progression.dart';
import '../../core/game/village.dart';
import '../../core/widgets/sprite_anim.dart';
import '../battle/camp_view.dart';

Future<void> showBuildingSheet(BuildContext context, {required PlayerState player, required Building building, required Rank rank}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: kWoodBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      side: BorderSide(color: kWoodBorder, width: 2),
    ),
    builder: (_) => _BuildingSheet(player: player, building: building, rank: rank),
  );
}

class _BuildingSheet extends StatefulWidget {
  const _BuildingSheet({required this.player, required this.building, required this.rank});
  final PlayerState player;
  final Building building;
  final Rank rank;

  @override
  State<_BuildingSheet> createState() => _BuildingSheetState();
}

class _BuildingSheetState extends State<_BuildingSheet> {
  bool _busy = false; // a second tap while saving must not spend again

  @override
  Widget build(BuildContext context) {
    final player = widget.player, rank = widget.rank;
    final b = widget.building;
    final level = player.levelOf(b);
    final maxed = level >= b.maxLevel;
    final cost = buildCost(b, level);
    final required = b.requiredCharacter;
    final locked = required != null && !isCharacterUnlocked(required, rank);
    final affordable = player.coins >= cost.coins && player.logs >= cost.logs;

    final String? reason = maxed
        ? null
        : locked
            ? 'Cần rank ${required.unlockRank.label} (mở ${required.label})'
            : affordable
                ? null
                : 'Chưa đủ tài nguyên';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset(b.asset, height: 120, filterQuality: FilterQuality.none),
          const SizedBox(height: 8),
          Text(b.label, style: woodText(22)),
          Text(b.effect, style: woodText(14, color: kWoodText.withValues(alpha: 0.75))),
          const SizedBox(height: 6),
          Text('Cấp $level/${b.maxLevel}', style: woodText(14)),
          if (!maxed) ...[
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const PixelIcon('coin', size: 24),
              Text(' ${cost.coins}', style: woodText(16)),
              const SizedBox(width: 18),
              const PixelIcon('log', size: 24),
              Text(' ${cost.logs}', style: woodText(16)),
            ]),
          ],
          if (reason != null) ...[
            const SizedBox(height: 6),
            Text(reason, style: woodText(12, color: const Color(0xFFF87171))),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: maxed || reason != null || _busy
                  ? null
                  : () async {
                      if (_busy) return; // two taps can land before the rebuild
                      setState(() => _busy = true);
                      try {
                        final ok = await player.build(b, rank);
                        if (ok && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Chưa lưu được công trình. Hãy thử lại.'),
                          ));
                        }
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC2410C),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: Text(maxed ? 'Đã tối đa' : (level == 0 ? 'Xây' : 'Nâng cấp'),
                  style: woodText(17, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }
}
