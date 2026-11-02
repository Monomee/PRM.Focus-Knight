import 'package:flutter/material.dart';

import '../../../core/widgets/flat_theme.dart';
import '../services/analytics_service.dart';
import 'analytics_chart.dart';

class FocusEnduranceCard extends StatelessWidget {
  const FocusEnduranceCard({super.key, required this.analytics});
  final AnalyticsService analytics;
  @override
  Widget build(BuildContext context) {
    final estimate = analytics.endurance,
        enough = analytics.endurance.count >= 5;
    return AnalyticsCard(
      title: 'Duy trì tập trung',
      icon: Icons.timelapse,
      color: Flat.analyticsCyan,
      info:
          'Đo thời gian đến lần mở ứng dụng được chọn đầu tiên trong 30 ngày gần nhất. Cần ít nhất 5 phiên có theo dõi.\n\nĐường Kaplan–Meier xem phiên hoàn thành theo kế hoạch là right-censored; pause chủ động và kết thúc sớm cũng được kiểm duyệt tại thời điểm tương ứng nếu chưa có sự kiện. Median chỉ xác định khi tỷ lệ còn tập trung giảm đến 50%.\n\nTỷ lệ phiên trọn vẹn = phiên hoàn thành không gián đoạn/pause chia cho toàn bộ phiên kết thúc có theo dõi. ${estimate.count} phiên đủ điều kiện; ${analytics.invalidSessions} bản ghi chưa kết thúc/không hợp lệ được loại. Chỉ quan sát được gián đoạn ứng dụng, không phải mọi gián đoạn ngoài đời.',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AnalyticsKpi(
                value: enough && estimate.median != null
                    ? estimate.median!.toStringAsFixed(0)
                    : '—',
                unit: enough && estimate.median != null ? 'phút' : null,
                label: 'Liên tục · trung vị',
                color: enough && estimate.median != null
                    ? Flat.analyticsCyan
                    : Flat.muted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnalyticsKpi(
                value: enough
                    ? '${(analytics.uninterruptedRate! * 100).round()}%'
                    : '—',
                label: 'Phiên trọn vẹn',
                color: enough ? Flat.analyticsCyan : Flat.muted,
              ),
            ),
          ],
        ),
        if (enough)
          AnalyticsChart(
            points: [for (final p in estimate.points) (x: p.x, y: p.y * 100)],
            color: Flat.analyticsCyan,
            xLabel: 'Phút',
            yLabel: 'Chưa gián đoạn (%)',
            maxY: 100,
            steps: true,
            details: [
              for (final p in estimate.points)
                '${p.x.toStringAsFixed(1)} phút · ${(p.y * 100).toStringAsFixed(1)}% chưa gián đoạn',
            ],
          )
        else
          const AnalyticsEmpty(),
      ],
    );
  }
}
