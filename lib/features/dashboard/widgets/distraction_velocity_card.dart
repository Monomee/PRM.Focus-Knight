import 'package:flutter/material.dart';

import '../../../core/widgets/flat_theme.dart';
import '../services/analytics_service.dart';
import 'analytics_chart.dart';

class DistractionVelocityCard extends StatelessWidget {
  const DistractionVelocityCard({super.key, required this.data});
  final DistractionVelocityData data;
  @override
  Widget build(BuildContext context) {
    final change = data.changePercent;
    final changeColor = change == null
        ? Flat.muted
        : change <= 0
        ? Flat.rest
        : Flat.danger;
    final color = data.velocityPerHour == null
        ? Flat.muted
        : data.velocityPerHour! < 2
        ? Flat.rest
        : data.velocityPerHour! < 4
        ? Flat.accent
        : Flat.danger;
    return AnalyticsCard(
      title: 'Nhịp gián đoạn',
      icon: Icons.show_chart,
      color: Flat.danger,
      info: 'Lượt mở ứng dụng đã chọn / giờ tập trung thực tế trong các phiên có theo dõi. Trung bình tuần là tổng lượt chia tổng giờ, không phải trung bình các tỷ lệ ngày. Ngày không có giờ theo dõi được để trống.\n\nSo sánh với 7 ngày trước; thay đổi chưa xác định khi tuần trước thiếu dữ liệu hoặc bằng 0. Chỉ dùng sự kiện quan sát hợp lệ, không xem background đơn thuần là gián đoạn.',
      children: [
        AnalyticsKpi(
          value: data.velocityPerHour?.toStringAsFixed(1) ?? '—',
          unit: 'lần/giờ',
          label: 'Trung bình 7 ngày',
          color: color,
        ),
        Row(
          children: [
            if (change != null) ...[
              Icon(
                change <= 0 ? Icons.trending_down : Icons.trending_up,
                size: 16,
                color: changeColor,
              ),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(
                change == null
                    ? 'Chưa có so sánh tuần trước'
                    : '${change <= 0 ? 'Giảm' : 'Tăng'} ${change.abs().toStringAsFixed(0)}% so với tuần trước',
                style: TextStyle(
                  fontSize: 12,
                  color: changeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (data.weeklyTrend.any((v) => v != null))
          AnalyticsChart(
            points: [
              for (var i = 0; i < data.weeklyTrend.length; i++)
                data.weeklyTrend[i] == null
                    ? null
                    : (x: i + 1.0, y: data.weeklyTrend[i]!),
            ],
            color: color,
            minX: 1,
            maxX: 7,
            xTicks: [for (final d in data.dates) '${d.day}'],
            xLabel: data.dates.isEmpty
                ? '7 ngày'
                : '${data.dates.first.day}/${data.dates.first.month}–${data.dates.last.day}/${data.dates.last.month}',
            yLabel: 'Lần/giờ',
            details: [
              for (var i = 0; i < data.weeklyTrend.length; i++)
                '${i < data.dates.length ? '${data.dates[i].day}/${data.dates[i].month}' : 'Ngày ${i + 1}'}\n${data.weeklyTrend[i]?.toStringAsFixed(2) ?? 'Chưa có dữ liệu'} lần/giờ${i < data.dailyEvents.length ? ' · ${data.dailyEvents[i]} lượt / ${(data.dailySeconds[i] / 60).round()} phút' : ''}',
            ],
          )
        else
          const AnalyticsEmpty(),
      ],
    );
  }
}
