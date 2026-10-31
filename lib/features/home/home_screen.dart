import 'package:flutter/material.dart';
import '../../core/game/player_state.dart';
import '../../core/game/progression.dart';
import '../../core/game/sprites.dart';
import '../../core/widgets/flat_theme.dart';
import '../../core/widgets/sprite_anim.dart';
import '../battle/battle_launcher.dart';
import '../dashboard/services/focus_history_service.dart';
import '../focus_session/focus_session_controller.dart';
import 'analytics_screen.dart';

/// Flat, single-column home: rank header, start card, today stats, last 7 days.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.player,
    required this.history,
    this.onOpenVillage,
  });

  final FocusSessionController controller;
  final PlayerState player;
  final FocusHistoryService history;
  final VoidCallback? onOpenVillage;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  int _todaySessions = 0;
  int _todayInterruptions = 0;
  List<int> _weekMinutes = List.filled(7, 0);

  @override
  void initState() {
    super.initState();
    widget.history.addListener(_loadStats);
    _loadStats();
  }

  @override
  void dispose() {
    widget.history.removeListener(_loadStats);
    super.dispose();
  }

  Future<void> _loadStats() async {
    final h = widget.history;
    final today = DateTime.now();
    final sessions = await h.getSessionCountForDate(today);
    final interruptions = await h.getInterruptionsForDate(today);
    final week = [
      for (var i = 6; i >= 0; i--) (await h.getFocusSecondsForDate(today.subtract(Duration(days: i)))) ~/ 60,
    ];
    if (!mounted) return;
    setState(() {
      _todaySessions = sessions;
      _todayInterruptions = interruptions;
      _weekMinutes = week;
    });
  }

  Future<void> _start() async {
    await openBattle(context,
        controller: widget.controller, player: widget.player, onOpenVillage: widget.onOpenVillage);
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.player, widget.history, widget.controller]),
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _header(),
          const SizedBox(height: 14),
          _startCard(),
          const SizedBox(height: 10),
          _todayRow(),
          const SizedBox(height: 10),
          _weekCard(),
          const SizedBox(height: 10),
          _analyticsLink(),
        ],
      ),
    );
  }

  Widget _header() {
    final p = widget.player;
    final seconds = widget.history.totalFocusSecondsAllTime;
    final rank = rankForSeconds(seconds);
    final next = nextRank(rank);
    final hours = seconds ~/ 3600;
    final progress = next == null
        ? 1.0
        : (seconds - rank.thresholdHours * 3600) / ((next.thresholdHours - rank.thresholdHours) * 3600);

    return Row(children: [
      Container(
        width: 56,
        height: 56,
        decoration: Flat.cardBox(),
        child: Image.asset(badgeAsset(p.badgeCharacter, p.badgeRank), filterQuality: FilterQuality.none),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(rank.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              color: Flat.accent,
              backgroundColor: Flat.border,
            ),
          ),
          const SizedBox(height: 4),
          Text(next == null ? 'Hạng cao nhất' : '${hours}h / ${next.thresholdHours}h → ${next.label}',
              style: Flat.label),
        ]),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _resource('coin', p.coins),
        const SizedBox(height: 4),
        _resource('log', p.logs),
      ]),
    ]);
  }

  Widget _resource(String icon, int value) => Row(mainAxisSize: MainAxisSize.min, children: [
        PixelIcon(icon, size: 20),
        const SizedBox(width: 4),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      ]);

  Widget _startCard() {
    final inBattle = widget.controller.inBattle;
    final hero = characterSprites[widget.player.selectedCharacter]!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: Flat.cardBox(),
      child: Column(children: [
        Row(children: [
          SpriteAnim(sheet: hero.idle, size: 76),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(inBattle ? 'Đang trong trận' : 'Sẵn sàng xuất trận', style: Flat.label),
              const SizedBox(height: 4),
              Text(
                inBattle
                    ? '${widget.controller.taskName} · ${widget.controller.formattedTime}'
                    : widget.player.selectedCharacter.label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: widget.controller.isSettling ? null
                : widget.controller.hasPendingSettlement ? widget.controller.retrySettlement : _start,
            style: FilledButton.styleFrom(
              backgroundColor: Flat.accent,
              foregroundColor: const Color(0xFF1A1200),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(widget.controller.isSettling ? 'ĐANG LƯU PHẦN THƯỞNG'
                : widget.controller.hasPendingSettlement ? 'THỬ LẠI NHẬN THƯỞNG'
                : inBattle ? 'QUAY LẠI TRẬN' : 'BẮT ĐẦU',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ),
        if (widget.controller.settlementFailed)
          const Text('Chưa lưu được phần thưởng. Hãy thử lại trước khi đóng ứng dụng.',
              textAlign: TextAlign.center, style: TextStyle(color: Flat.danger)),
      ]),
    );
  }

  Widget _todayRow() {
    Widget tile(String value, String label, {Color color = Flat.text}) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: Flat.cardBox(),
            child: Column(children: [
              Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: color)),
              Text(label, style: Flat.label),
            ]),
          ),
        );
    return Row(children: [
      tile('${widget.history.todayFocusSeconds ~/ 60}', 'phút'),
      tile('$_todaySessions', 'phiên'),
      tile('$_todayInterruptions', 'xao nhãng', color: Flat.danger),
    ]);
  }

  Widget _weekCard() {
    final maxMinutes = _weekMinutes.fold(1, (a, b) => a > b ? a : b);
    final today = DateTime.now();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: Flat.cardBox(),
      child: Column(children: [
        Row(children: [
          const Text('7 ngày qua', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('🔥 ${widget.history.calculateStreak()} ngày liên tiếp', style: Flat.label),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 70,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Container(
                    width: 16,
                    height: 4 + 44 * _weekMinutes[i] / maxMinutes,
                    decoration: BoxDecoration(
                      color: _weekMinutes[i] == 0 ? Flat.border : Flat.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_weekdays[today.subtract(Duration(days: 6 - i)).weekday - 1], style: Flat.label),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _analyticsLink() => InkWell(
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => AnalyticsScreen(history: widget.history))),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: Flat.cardBox(),
          child: const Row(children: [
            Text('Phân tích chi tiết', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            SizedBox(width: 8),
            Expanded(
              child: Text('Giờ vàng · Xao nhãng · Lịch ›',
                  style: Flat.label, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      );
}
