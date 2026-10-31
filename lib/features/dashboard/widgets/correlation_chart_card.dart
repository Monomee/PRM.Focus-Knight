import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/analytics_service.dart';

/// Card displaying Correlation Analysis between Social Media hours and Focus Goal Completion Rate
class CorrelationChartCard extends StatelessWidget {
  final List<DayCorrelationData> data;

  const CorrelationChartCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161A26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262C3D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.compare_arrows,
                  size: 16,
                  color: Color(0xFFA78BFA),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MỐI TƯƠNG QUAN XAO NHÃNG',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: Color(0xFFF1F5F9),
                      ),
                    ),
                    Text(
                      'Số giờ lướt MXH so với Tỉ lệ hoàn thành mục tiêu 7 ngày qua',
                      style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Lướt MXH (Giờ)', const Color(0xFFEF4444)),
              const SizedBox(width: 16),
              _buildLegendItem(
                'Hoàn thành mục tiêu (%)',
                const Color(0xFF10B981),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Custom Dual Bar Chart
          SizedBox(
            height: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((d) => _buildDayColumn(d)).toList(),
            ),
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2333),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.insights, size: 16, color: Color(0xFFFFB300)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.any((day) => day.socialHours != null)
                        ? 'Biểu đồ sử dụng dữ liệu tập trung và thời gian dùng các ứng dụng bị chặn trong 7 ngày gần nhất.'
                        : 'Chưa có dữ liệu thời gian ứng dụng. Hãy cấp quyền truy cập dữ liệu sử dụng để xem mối tương quan.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFCBD5E1),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDayColumn(DayCorrelationData day) {
    const maxBarHeight = 100.0;
    const maxSocialHours = 4.0; // 4 hours ceiling for scaling

    // Heights
    final socialHeight = math.min(
      maxBarHeight,
      ((day.socialHours ?? 0) / maxSocialHours) * maxBarHeight,
    );
    final focusHeight = math.min(
      maxBarHeight,
      day.completionRate * maxBarHeight,
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Bars container
        SizedBox(
          height: maxBarHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Social Bar (Red)
              Tooltip(
                message: day.socialHours == null
                    ? '${day.dayLabel}: Chưa có quyền truy cập dữ liệu sử dụng'
                    : '${day.dayLabel}: Lướt MXH ${day.socialHours}h',
                child: Container(
                  width: 10,
                  height: math.max(4.0, socialHeight),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Focus Completion Bar (Green)
              Tooltip(
                message:
                    '${day.dayLabel}: Hoàn thành ${(day.completionRate * 100).toInt()}%',
                child: Container(
                  width: 10,
                  height: math.max(4.0, focusHeight),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Day Label
        Text(
          day.dayLabel,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
