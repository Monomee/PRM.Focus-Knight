import 'package:flutter/material.dart';

import '../services/analytics_service.dart';

/// Card displaying Golden Hours (Khung giờ vàng) and productivity recommendations
class GoldenHoursCard extends StatelessWidget {
  final GoldenHoursData data;

  const GoldenHoursCard({super.key, required this.data});

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
                  color: const Color(0xFFEAB308).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.wb_sunny_rounded,
                  size: 16,
                  color: Color(0xFFFACC15),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KHUNG GIỜ VÀNG (GOLDEN HOURS)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: Color(0xFFF1F5F9),
                      ),
                    ),
                    Text(
                      'Thống kê và gợi ý khoảng thời gian não bộ đạt đỉnh cao hiệu suất',
                      style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Highlight Trophy Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B2508), Color(0xFF1E2333)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFB300), width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFFB300),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Text('👑', style: TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'KHUNG GIỜ ĐỈNH CAO CỦA BẠN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: Color(0xFFFCD34D),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.peakTimeSlot.isEmpty
                            ? 'CHƯA ĐỦ DỮ LIỆU'
                            : data.peakTimeSlot,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          letterSpacing: 1.2,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: Text(
                    data.peakTimeSlot.isEmpty
                        ? 'CHƯA CÓ DỮ LIỆU'
                        : '${(data.peakEfficiency * 100).toInt()}% TƯƠNG ĐỐI',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF34D399),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 6 Time Blocks Bar Chart
          const Text(
            'PHÂN BỔ HIỆU SUẤT TRONG TUẦN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 8),

          ...data.blockProductivity.entries.map((entry) {
            final isPeak = entry.value == data.peakEfficiency;
            final percent = (entry.value * 100).toInt();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.5),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isPeak
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isPeak
                            ? const Color(0xFFFFB300)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: entry.value,
                        backgroundColor: const Color(0xFF1E2333),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isPeak
                              ? const Color(0xFFFFB300)
                              : const Color(0xFF3B82F6),
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 38,
                    child: Text(
                      '$percent%',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        fontWeight: isPeak
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isPeak
                            ? const Color(0xFFFFB300)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),

          // Recommendation Tip Box
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
                const Icon(
                  Icons.lightbulb_outline,
                  size: 16,
                  color: Color(0xFFFFB300),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.recommendation,
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
}
