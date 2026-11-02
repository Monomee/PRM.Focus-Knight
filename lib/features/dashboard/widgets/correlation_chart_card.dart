import 'package:flutter/material.dart';

import '../../../core/widgets/flat_theme.dart';
import '../services/analytics_calculations.dart';
import '../services/analytics_service.dart';
import 'analytics_chart.dart';

class CorrelationChartCard extends StatelessWidget {
  const CorrelationChartCard({
    super.key,
    required this.data,
    this.range = 7,
    this.minimumPairs = 7,
    this.onRangeChanged,
  });
  final List<DayCorrelationData> data;
  final int range, minimumPairs;
  final ValueChanged<int>? onRangeChanged;
  @override
  Widget build(BuildContext context) {
    final valid = data
        .where(
          (d) =>
              d.hasGoal &&
              d.socialHours != null &&
              d.socialHours!.isFinite &&
              d.socialHours! >= 0,
        )
        .toList();
    final points = [
      for (final d in valid) (x: d.socialHours!, y: d.completionRate * 100),
    ];
    final fit = correlation(points, minimum: minimumPairs);
    return AnalyticsCard(
      title: 'Xao nhãng & mục tiêu',
      icon: Icons.scatter_plot_outlined,
      color: Flat.analyticsPurple,
      info:
          'Mỗi điểm là một ngày: giờ dùng ứng dụng đang được chọn và tỷ lệ hoàn thành mục tiêu của ngày đó. Loại hôm nay, ngày thiếu mục tiêu hoặc thiếu lịch sử sử dụng hợp lệ.\n\nPearson r và đường hồi quy chỉ hiển thị khi có ít nhất $minimumPairs cặp và cả hai biến có phương sai. ${valid.length}/${data.length} ngày hợp lệ. r mô tả liên hệ tuyến tính, không chứng minh nguyên nhân và kết quả.',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final n in [7, 30])
              ChoiceChip(
                label: Text('$n ngày', style: const TextStyle(fontSize: 12)),
                selected: range == n,
                onSelected: onRangeChanged == null
                    ? null
                    : (_) => onRangeChanged!(n),
              ),
            if (fit != null)
              Text(
                'r ${fit.r.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Flat.analyticsPurple,
                ),
              ),
          ],
        ),
        if (points.isEmpty)
          const AnalyticsEmpty(message: 'Chưa đủ dữ liệu để so sánh.')
        else
          AnalyticsChart(
            points: points,
            color: Flat.analyticsPurple,
            xLabel: 'Giờ dùng app',
            yLabel: 'Hoàn thành mục tiêu (%)',
            maxY: 100,
            scatter: true,
            trend: fit == null
                ? null
                : (slope: fit.slope, intercept: fit.intercept),
            details: [
              for (final d in valid)
                '${dateKey(d.date)}\n${d.socialHours!.toStringAsFixed(2)} giờ dùng app · ${(d.completionRate * 100).round()}% mục tiêu',
            ],
          ),
        if (fit != null)
          const Text(
            'Mối liên hệ, không phải nguyên nhân.',
            style: TextStyle(fontSize: 11, color: Flat.muted),
          ),
      ],
    );
  }
}
