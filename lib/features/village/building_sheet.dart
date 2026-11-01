import 'package:flutter/material.dart';

import '../../core/game/player_state.dart';
import '../../core/game/progression.dart';
import '../../core/game/village.dart';
import '../../core/widgets/sprite_anim.dart';
import '../battle/camp_view.dart';

Future<void> showCastleSheet(
  BuildContext context, {
  required PlayerState player,
  required Rank rank,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: kWoodBg,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (_) => _CastleSheet(player: player, rank: rank),
);

class _CastleSheet extends StatefulWidget {
  const _CastleSheet({required this.player, required this.rank});
  final PlayerState player;
  final Rank rank;
  @override
  State<_CastleSheet> createState() => _CastleSheetState();
}

class _CastleSheetState extends State<_CastleSheet> {
  bool _busy = false;

  Future<void> _buy(Building building) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.player.build(building, widget.rank);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa lưu được nâng cấp. Hãy thử lại.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .82,
      child: ListenableBuilder(
        listenable: widget.player,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text('NÂNG CẤP CASTLE', style: woodText(24)),
              const SizedBox(height: 8),
              Text(
                'Hạng ${widget.rank.label} · ${widget.player.coins} Coin · ${widget.player.logs} Log',
                style: woodText(14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              for (final b in const [
                Building.tower,
                Building.granary,
                Building.barracks,
              ])
                _upgrade(b),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _upgrade(Building b) {
    final level = widget.player.levelOf(b);
    final maxed = level >= b.maxLevel;
    final required = castleUpgradeRank(b);
    final locked = widget.rank.index < required.index;
    final cost = buildCost(b, level);
    final affordable =
        widget.player.coins >= cost.coins && widget.player.logs >= cost.logs;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2118),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kWoodBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(switch (b) {
                  Building.tower => 'Thời gian ân hạn',
                  Building.granary => 'Vé giữ chuỗi',
                  _ => 'Thưởng Coin',
                }, style: woodText(18)),
                Text(b.effect, style: woodText(13)),
                Text('Cấp $level/${b.maxLevel}', style: woodText(13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (!maxed) ...[
                      const PixelIcon('coin', size: 20),
                      Text(' ${cost.coins}  ', style: woodText(13)),
                      const PixelIcon('log', size: 20),
                      Text(' ${cost.logs}', style: woodText(13)),
                    ],
                    const Spacer(),
                    FilledButton(
                      key: Key('upgrade-${b.name}'),
                      onPressed: locked || maxed || !affordable || _busy
                          ? null
                          : () => _buy(b),
                      child: Text(maxed ? 'Đã tối đa' : 'Nâng cấp'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (locked)
            Positioned.fill(
              child: Container(
                key: Key('upgrade-lock-${b.name}'),
                decoration: BoxDecoration(
                  color: const Color(0xDD0B0E14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock, color: Color(0xFFFFD54F)),
                      Text('Mở ở hạng ${required.label}', style: woodText(17)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
