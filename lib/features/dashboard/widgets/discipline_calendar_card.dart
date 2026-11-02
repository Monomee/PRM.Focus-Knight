import 'package:flutter/material.dart';

import '../../../core/widgets/flat_theme.dart';
import '../services/analytics_calculations.dart';
import '../services/analytics_journal.dart';
import '../services/analytics_service.dart';
import 'analytics_chart.dart';

class DisciplineCalendarCard extends StatefulWidget {
  const DisciplineCalendarCard({super.key, required this.analytics});
  final AnalyticsService analytics;
  @override
  State<DisciplineCalendarCard> createState() => _DisciplineCalendarCardState();
}

class _DisciplineCalendarCardState extends State<DisciplineCalendarCard> {
  late DateTime month;
  DateTime? selected;
  @override
  void initState() {
    super.initState();
    final now = widget.analytics.referenceDate;
    final initial = widget.analytics.isDemo && now.day < 16
        ? nextDay(now, -14)
        : now;
    month = DateTime(initial.year, initial.month);
  }

  Future<void> _goal() async {
    if (widget.analytics.isDemo) return;
    final form = GlobalKey<FormState>();
    var input = '';
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mục tiêu từ ngày mai'),
        content: Form(
          key: form,
          child: TextFormField(
            onChanged: (v) => input = v,
            keyboardType: TextInputType.number,
            autofocus: true,
            validator: (v) {
              final n = int.tryParse(v ?? '');
              return n == null || n < 1 || n > 1440
                  ? 'Nhập số phút từ 1 đến 1440'
                  : null;
            },
            decoration: const InputDecoration(
              labelText: 'Phút/ngày (1–1440)',
              helperText: 'Lịch sử mục tiêu được giữ nguyên.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 0),
            child: const Text('Tắt mục tiêu'),
          ),
          TextButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, int.parse(input));
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (value == null || !mounted) return;
    try {
      await AnalyticsJournal.instance.setGoal(
        value == 0 ? null : value,
        DateTime.now(),
      );
    } catch (_) {
      if (mounted) {
        showAnalyticsDetail(context, 'Chưa lưu được', 'Hãy thử lại sau.');
      }
    }
  }

  void _info() {
    showAnalyticsDetail(
      context,
      'Lịch kỷ luật',
      'Màu xanh tăng theo thời gian tập trung: dưới 50%, 50–99% và từ 100% mục tiêu. Ngày không có mục tiêu dùng ngưỡng 30/60 phút. Chấm nhỏ là ngày đạt mục tiêu.\n\nChuỗi chỉ tính ngày đạt mục tiêu. Hôm nay chưa đạt vẫn giữ chuỗi từ hôm qua; ngày không có mục tiêu ngắt chuỗi. Tỷ lệ tháng loại ngày tương lai và hôm nay chưa đạt.\n\nChạm một ngày để xem chi tiết.',
      actions: [
        if (!widget.analytics.isDemo)
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _goal();
            },
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Đặt mục tiêu ngày'),
          ),
      ],
    );
  }

  void _select(DateTime date) {
    setState(() => selected = date);
    final d = widget.analytics.day(date);
    showAnalyticsDetail(
      context,
      dateKey(date),
      '${(d.seconds / 60).toStringAsFixed(0)} phút tập trung\n${d.completed} phiên hoàn thành\n${d.incomplete} phiên chưa hoàn thành\n${d.goalSeconds == null ? 'Chưa đặt mục tiêu' : '${(d.progress! * 100).round()}% mục tiêu · ${d.goalSeconds! ~/ 60} phút\n${d.achieved ? '✓ Đã đạt mục tiêu' : 'Chưa đạt mục tiêu'}'}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.analytics, streak = a.streaks, rate = a.monthlyRate(month);
    final count = DateTime(month.year, month.month + 1, 0).day,
        offset = month.weekday - 1;
    return AnalyticsCard(
      title: 'Lịch kỷ luật',
      icon: Icons.calendar_month_outlined,
      color: Flat.rest,
      onInfo: _info,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AnalyticsKpi(
                value: '${streak.current}',
                label: 'Chuỗi hiện tại',
                unit: 'ngày',
                color: Flat.rest,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AnalyticsKpi(
                value: '${streak.longest}',
                label: 'Chuỗi dài nhất',
                unit: 'ngày',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AnalyticsKpi(
                value: rate == null ? '—' : '${(rate * 100).round()}%',
                label: 'Hoàn thành tháng',
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                '${month.month}/${month.year}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Tháng trước',
              onPressed: () =>
                  setState(() => month = DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left, size: 20),
            ),
            IconButton(
              tooltip: 'Tháng sau',
              onPressed: () =>
                  setState(() => month = DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right, size: 20),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, box) => Column(
            children: [
              Row(
                children: [
                  for (final w in weekdays)
                    Expanded(
                      child: Text(
                        w,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, color: Flat.muted),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              GridView.builder(
                key: const ValueKey('discipline-grid'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ((offset + count) / 7).ceil() * 7,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: MediaQuery.textScalerOf(context)
                      .scale(20)
                      .clamp(38, 56),
                ),
                itemBuilder: (context, i) {
                  final n = i - offset + 1;
                  if (n < 1 || n > count) return const SizedBox.shrink();
                  final date = DateTime(month.year, month.month, n),
                      d = a.day(DateTime(month.year, month.month, n));
                  final label =
                      '${dateKey(date)}: ${(d.seconds / 60).round()} phút${d.achieved ? ', đạt mục tiêu' : ''}';
                  return Semantics(
                    label: label,
                    button: true,
                    selected: selected == date,
                    child: Tooltip(
                      message: label,
                      child: InkWell(
                        onTap: () => _select(date),
                        borderRadius: BorderRadius.circular(5),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Flat.activityHeat[d.heatLevel],
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: selected == date
                                  ? Flat.longRest
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                '$n',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: d.heatLevel == 3 ? Flat.bg : Flat.text,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (d.achieved)
                                Positioned(
                                  bottom: 3,
                                  child: Container(
                                    width: 3,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: d.heatLevel == 3
                                          ? Flat.bg
                                          : Flat.text,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('Ít', style: TextStyle(fontSize: 11, color: Flat.muted)),
            const SizedBox(width: 6),
            for (final color in Flat.activityHeat)
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            const SizedBox(width: 3),
            const Text(
              'Nhiều',
              style: TextStyle(fontSize: 11, color: Flat.muted),
            ),
          ],
        ),
      ],
    );
  }
}
