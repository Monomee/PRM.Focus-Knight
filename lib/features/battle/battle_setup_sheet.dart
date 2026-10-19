import 'package:flutter/material.dart';
import '../../core/game/battle_plan.dart';
import '../../core/widgets/flat_theme.dart';

Future<BattlePlan?> showBattleSetupSheet(
  BuildContext context, {
  required BattlePlan initial,
  required int barracksLevel,
  int longRestMinutes = 15,
}) {
  return showModalBottomSheet<BattlePlan>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Flat.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _SetupSheet(initial: initial, barracksLevel: barracksLevel, longRestMinutes: longRestMinutes),
  );
}

class _SetupSheet extends StatefulWidget {
  const _SetupSheet({required this.initial, required this.barracksLevel, required this.longRestMinutes});
  final BattlePlan initial;
  final int barracksLevel;
  final int longRestMinutes;

  @override
  State<_SetupSheet> createState() => _SetupSheetState();
}

class _SetupSheetState extends State<_SetupSheet> {
  late final BattlePlan _plan = BattlePlan.fromJson(widget.initial.toJson());
  late final TextEditingController _task = TextEditingController(text: _plan.task);

  static const _focusPresets = [15, 25, 50];
  static const _restPresets = [3, 5, 10];

  @override
  void dispose() {
    _task.dispose();
    super.dispose();
  }

  Future<int?> _askMinutes(String title, int Function(String) clamp) =>
      showDialog<int>(context: context, builder: (_) => _MinutesDialog(title: title, clamp: clamp));

  Widget _chips(List<int> presets, int current, ValueChanged<int> onPick, Future<int?> Function() custom) {
    final isCustom = !presets.contains(current);
    return Row(children: [
      for (final m in presets) FlatChip(label: '${m}p', selected: current == m, onTap: () => onPick(m)),
      FlatChip(
        label: isCustom ? '${current}p' : 'Tùy…',
        selected: isCustom,
        onTap: () async {
          final v = await custom();
          if (v != null) onPick(v);
        },
      ),
    ]);
  }

  Widget _stepper(String keyPrefix, String value, VoidCallback onMinus, VoidCallback onPlus) {
    Widget btn(String k, String t, VoidCallback f) => InkWell(
          key: Key('$keyPrefix-$k'),
          onTap: f,
          child: Container(
            width: 38,
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            color: const Color(0xFF1B2130),
            child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        );
    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: Flat.border, width: 1.5), borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Row(children: [
        btn('minus', '−', onMinus),
        Expanded(
            child: Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
        btn('plus', '+', onPlus),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeline = planTimeline(_plan, longRestMinutes: widget.longRestMinutes);
    final end = planEndTime(_plan, DateTime.now(), longRestMinutes: widget.longRestMinutes);
    final focusTotal = _plan.focusMinutes * _plan.sessions;
    final restTotal = timeline.where((s) => !s.focus).fold(0, (a, s) => a + s.minutes);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: Flat.border, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 10),
            const Text('Thiết lập trận', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            TextField(
              controller: _task,
              decoration: const InputDecoration(hintText: 'Hôm nay làm gì?'),
              onChanged: (v) => _plan.task = v,
            ),
            const SizedBox(height: 14),
            const Text('TẬP TRUNG', style: Flat.label),
            const SizedBox(height: 6),
            _chips(_focusPresets, _plan.focusMinutes, (m) => setState(() => _plan.focusMinutes = m),
                () => _askMinutes('Thời gian tập trung', clampFocusMinutes)),
            const SizedBox(height: 14),
            const Text('NGHỈ NGẮN', style: Flat.label),
            const SizedBox(height: 6),
            _chips(_restPresets, _plan.restMinutes, (m) => setState(() => _plan.restMinutes = m),
                () => _askMinutes('Thời gian nghỉ', clampRestMinutes)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('SỐ PHIÊN', style: Flat.label),
                  const SizedBox(height: 6),
                  _stepper('sessions', '${_plan.sessions}',
                      () => setState(() => _plan.sessions = (_plan.sessions - 1).clamp(1, 8)),
                      () => setState(() => _plan.sessions = (_plan.sessions + 1).clamp(1, 8))),
                ]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('NGHỈ DÀI SAU', style: Flat.label),
                  const SizedBox(height: 6),
                  _stepper('long', _plan.longBreakEvery == 0 ? 'Tắt' : '${_plan.longBreakEvery} phiên',
                      () => setState(() => _plan.longBreakEvery = (_plan.longBreakEvery - 1).clamp(0, 8)),
                      () => setState(() => _plan.longBreakEvery = (_plan.longBreakEvery + 1).clamp(0, 8))),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              const Text('LỊCH TRÌNH', style: Flat.label),
              const Spacer(),
              Text('xong lúc ~${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
                  style: Flat.label),
            ]),
            const SizedBox(height: 6),
            SizedBox(
              height: 14,
              child: Row(children: [
                for (final s in timeline)
                  Expanded(
                    flex: s.minutes,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: s.focus ? Flat.accent : (s.longRest ? Flat.longRest : Flat.rest),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: Text('${focusTotal}p tập trung · ${restTotal}p nghỉ', style: Flat.label)),
              Text('~${planCoins(_plan, widget.barracksLevel)} coin',
                  style: const TextStyle(fontSize: 12, color: Flat.accent, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _plan..task = _task.text.trim()),
                style: FilledButton.styleFrom(
                  backgroundColor: Flat.accent,
                  foregroundColor: const Color(0xFF1A1200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('XUẤT TRẬN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Owns its TextEditingController so it is disposed only after the dialog's exit animation.
class _MinutesDialog extends StatefulWidget {
  const _MinutesDialog({required this.title, required this.clamp});
  final String title;
  final int Function(String) clamp;

  @override
  State<_MinutesDialog> createState() => _MinutesDialogState();
}

class _MinutesDialogState extends State<_MinutesDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: Flat.card,
        title: Text(widget.title, style: const TextStyle(fontSize: 15)),
        content: TextField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'phút'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
          TextButton(onPressed: () => Navigator.pop(context, widget.clamp(_ctrl.text)), child: const Text('OK')),
        ],
      );
}
