import 'package:flutter/material.dart';

import '../../core/game/player_state.dart';
import '../../core/game/progression.dart';
import '../../core/game/village.dart';
import '../../core/widgets/sprite_anim.dart';
import '../battle/camp_view.dart';
import 'building_sheet.dart';

class VillageScreen extends StatefulWidget {
  const VillageScreen({
    super.key,
    required this.player,
    required this.totalFocusSeconds,
  });
  final PlayerState player;
  final int totalFocusSeconds;
  @override
  State<VillageScreen> createState() => _VillageScreenState();
}

class _VillageScreenState extends State<VillageScreen> {
  int _page = 0;
  static const _columns = 5;
  static const _rows = 3;
  static const _pageSize = _columns * _rows;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.player,
    builder: (context, _) {
      final plots = widget.player.plots;
      final pages = plots.length ~/ _pageSize + 1;
      final rank = rankForSeconds(widget.totalFocusSeconds);
      return Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'ui/scenes/village.webp',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.none,
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xBB0B0E14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Làng của bạn', style: woodText(18)),
                      ),
                      const PixelIcon('coin', size: 20),
                      Text(' ${widget.player.coins}  ', style: woodText(13)),
                      const PixelIcon('log', size: 20),
                      Text(' ${widget.player.logs}', style: woodText(13)),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: GestureDetector(
                  key: const Key('castle'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showCastleSheet(
                    context,
                    player: widget.player,
                    rank: rank,
                  ),
                  child: Semantics(
                    button: true,
                    label: 'Castle, mở nâng cấp nhà chính',
                    child: Column(
                      children: [
                        Expanded(
                          child: Image.asset(
                            Building.castle.asset,
                            width: 260,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                          ),
                        ),
                        Text('CASTLE · ${rank.label}', style: woodText(18)),
                        Text('Chạm để nâng cấp', style: woodText(12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: LayoutBuilder(
                    builder: (context, box) => GridView.builder(
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _columns,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        // Preserve the original four-row spacing when hiding the last row.
                        mainAxisExtent: (box.maxHeight - 8 * 3) / 4,
                      ),
                      itemCount: _pageSize,
                      itemBuilder: (context, index) {
                        final position = _page * _pageSize + index;
                        return _plot(
                          position < plots.length ? plots[position] : null,
                          position,
                        );
                      },
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    key: const Key('map-prev'),
                    tooltip: 'Mảnh đất trước',
                    onPressed: _page == 0
                        ? null
                        : () => setState(() => _page--),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Mảnh đất ${_page + 1} / $pages', style: woodText(16)),
                  IconButton(
                    key: const Key('map-next'),
                    tooltip: 'Mảnh đất tiếp theo',
                    onPressed: _page + 1 >= pages
                        ? null
                        : () => setState(() => _page++),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    },
  );

  Widget _plot(VillagePlot? plot, int position) {
    final state = plot == null
        ? 'Ô trống'
        : switch (plot.state) {
            PlotState.building => 'Đang xây',
            PlotState.complete => plot.building.label,
            PlotState.ruined => 'Đổ nát',
          };
    final tile = Container(
      key: plot == null ? Key('empty-plot-$position') : Key('plot-${plot.id}'),
      padding: const EdgeInsets.all(6),
      decoration: plot == null
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kWoodBorder),
            )
          : null,
      child: plot == null
          ? const Center(child: Icon(Icons.add, color: Color(0xFF6B4F2A)))
          : Semantics(
              label: state,
              child: Opacity(
                opacity: plot.state == PlotState.building ? .45 : 1,
                child: Image.asset(
                  plot.asset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                ),
              ),
            ),
    );
    if (plot == null) return tile;
    return Tooltip(
      message: '${plot.task} · ${plot.focusMinutes} phút\n$state',
      child: tile,
    );
  }
}
