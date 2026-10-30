import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/analytics_service.dart';

/// Card displaying Distraction Velocity (Tần suất bồn chồn)
class DistractionVelocityCard extends StatelessWidget {
  final DistractionVelocityData data;

  const DistractionVelocityCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    Color levelColor;
    IconData levelIcon;

    switch (data.levelKey) {
      case 'HIGH_RESTLESS':
        levelColor = const Color(0xFFEF4444);
        levelIcon = Icons.warning_amber_rounded;
        break;
      case 'MODERATE':
        levelColor = const Color(0xFFF59E0B);
        levelIcon = Icons.change_circle_outlined;
        break;
      case 'DEEP_FLOW':
        levelColor = const Color(0xFF10B981);
        levelIcon = Icons.self_improvement;
        break;
      default:
        levelColor = const Color(0xFF94A3B8);
        levelIcon = Icons.hourglass_empty;
        break;
    }

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
                  color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.speed,
                  size: 16,
                  color: Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TẦN SUẤT BỒN CHỒN (DISTRACTION VELOCITY)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: Color(0xFFF1F5F9),
                      ),
                    ),
                    Text(
                      'Số lần chạm / thoát app trung bình mỗi giờ làm việc',
                      style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Core Metric & Rating Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Huge Number
              Text(
                data.velocityPerHour?.toString() ?? '—',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: levelColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'LẦN / GIỜ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: Color(0xFFE2E8F0),
                      ),
                    ),
                    Text(
                      '${data.totalInterruptions} lần thoát / ${data.focusWorkHours}h tập trung',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Level Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: levelColor, width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(levelIcon, size: 14, color: levelColor),
                    const SizedBox(width: 4),
                    Text(
                      data.levelLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: levelColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 7-day Velocity Trend
          const Text(
            'XU HƯỚNG TẬP TRUNG (7 NGÀY GẦN NHẤT)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(data.weeklyTrend.length, (idx) {
                final value = data.weeklyTrend[idx];
                final v = value ?? 0;
                final barH = value == null
                    ? 6.0
                    : math.max(6.0, math.min(42.0, (v / 4.5) * 42.0));
                final isLast = idx == data.weeklyTrend.length - 1;
                final col = value == null
                    ? const Color(0xFF475569)
                    : v <= 2.0
                    ? const Color(0xFF10B981)
                    : (v <= 4.0
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFEF4444));

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 28,
                      height: barH,
                      decoration: BoxDecoration(
                        color: col,
                        borderRadius: BorderRadius.circular(4),
                        border: isLast
                            ? Border.all(color: Colors.white, width: 1.2)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          value?.toString() ?? '—',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),

          const SizedBox(height: 12),

          // Strategy Advice Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2333),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: Color(0xFF38BDF8)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chiến thuật: Sử dụng bộ đếm 15 giây hít thở sâu Mindful Interruption để bình tĩnh lại trước khi thoát app!',
                    style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
