import 'package:flutter/material.dart';

import '../../../core/widgets/flat_theme.dart';
import '../services/analytics_calculations.dart';
import '../services/analytics_service.dart';
import 'analytics_chart.dart';

class GoldenHoursCard extends StatelessWidget {
  const GoldenHoursCard({super.key, required this.data});
  final GoldenHoursData data;
  @override
  Widget build(BuildContext context) {
    final best = data.best;
    return AnalyticsCard(
      title: 'Khung giờ vàng',
      icon: Icons.wb_sunny_outlined,
      color: Flat.accent,
      info: '30 ngày gần nhất. Mỗi ô cần ít nhất 3 phiên để hiển thị hiệu suất. Điểm phiên = 50% hoàn thành + 50% tỷ lệ thời gian tập trung thực tế/mục tiêu phiên, tối đa 100%. Điểm ô là trung bình có trọng số theo số giây thuộc đúng khung giờ.\n\nMàu sáng hơn là hiệu suất cao hơn. Chạm ô để xem số phiên và thời gian.',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AnalyticsKpi(
                value: best == null ? '—' : slotLabels[best ~/ 7],
                label: 'Khung giờ hiệu quả nhất',
                color: best == null ? Flat.muted : Flat.accent,
              ),
            ),
            if (best != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Flat.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${(data.peakEfficiency * 100).round()}đ',
                    style: const TextStyle(
                      color: Flat.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (data.cells.any((cell) => cell.sessions.isNotEmpty))
          LayoutBuilder(
            builder: (context, box) {
              final rowHeight = MediaQuery.textScalerOf(context)
                  .scale(20)
                  .clamp(34.0, 52.0)
                  .toDouble();
              final showNumber =
                  (box.maxWidth - 46) / 7 >
                  MediaQuery.textScalerOf(context).scale(18) + 4;
              return Table(
                key: const ValueKey('golden-grid'),
                columnWidths: const {0: FixedColumnWidth(46)},
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    children: [
                      const SizedBox(height: 24),
                      for (final w in weekdays)
                        Center(
                          child: Text(
                            w,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Flat.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                  for (var slot = 0; slot < 7; slot++)
                    TableRow(
                      children: [
                        Text(
                          '${slotEdges[slot]}–${slotEdges[slot + 1]}h',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Flat.muted,
                          ),
                        ),
                        for (var weekday = 0; weekday < 7; weekday++)
                          _cell(context, slot, weekday, rowHeight, showNumber),
                      ],
                    ),
                ],
              );
            },
          ),
        if (best == null)
          const AnalyticsEmpty(
            message: 'Thêm vài phiên để tìm khung giờ tốt nhất.',
          )
        else
          Text(
            'Hiệu quả nhất: ${weekdays[best % 7]}, ${slotLabels[best ~/ 7]}.',
            style: const TextStyle(fontSize: 12, color: Flat.muted),
          ),
      ],
    );
  }

  Widget _cell(
    BuildContext context,
    int slot,
    int weekday,
    double height,
    bool showNumber,
  ) {
    final cell = data.cells[slot * 7 + weekday],
        score = data.cells[slot * 7 + weekday].score;
    final color = score == null
        ? Flat.border
        : Flat.goldenHeat[score < 0.5
              ? 0
              : score < 0.7
              ? 1
              : score < 0.85
              ? 2
              : 3];
    final label =
        '${weekdays[weekday]} ${slotLabels[slot]}\n${score == null ? 'Chưa đủ dữ liệu' : '${(score * 100).round()} điểm'} · ${cell.sessions.length} phiên\n${(cell.seconds / 60).round()} phút tập trung';
    return Semantics(
      label: label,
      button: true,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: () => showAnalyticsDetail(context, 'Khung giờ', label),
          child: Container(
            height: height,
            margin: const EdgeInsets.all(2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              score == null
                  ? '·'
                  : showNumber
                  ? '${(score * 100).round()}'
                  : '•',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: score != null && score >= 0.7 ? Flat.bg : Flat.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
