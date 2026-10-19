import 'package:flutter/material.dart';
import '../../core/widgets/flat_theme.dart';
import '../dashboard/services/analytics_service.dart';
import '../dashboard/services/focus_history_service.dart';
import '../dashboard/widgets/correlation_chart_card.dart';
import '../dashboard/widgets/distraction_velocity_card.dart';
import '../dashboard/widgets/golden_hours_card.dart';

/// Detailed analytics: discipline calendar + golden hours, distraction velocity, correlation.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, required this.history});
  final FocusHistoryService history;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late final FocusHistoryService _historyService = widget.history;
  DateTime _displayedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.refreshAnalytics();
  }

  @override
  Widget build(BuildContext context) {
    final analytics = AnalyticsService.instance;
    return Scaffold(
      backgroundColor: Flat.bg,
      appBar: AppBar(backgroundColor: Flat.bg, elevation: 0, title: const Text('Phân tích', style: TextStyle(fontSize: 16))),
      body: ListenableBuilder(
        listenable: Listenable.merge([analytics, _historyService]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildMonthlyDotGridCalendar(),
            const SizedBox(height: 14),
            GoldenHoursCard(data: analytics.goldenHours),
            const SizedBox(height: 14),
            DistractionVelocityCard(data: analytics.distractionVelocity),
            const SizedBox(height: 14),
            CorrelationChartCard(data: analytics.correlationDays),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyDotGridCalendar() {
    final year = _displayedMonth.year;
    final month = _displayedMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday; // 1 = Monday, 7 = Sunday
    final today = DateTime.now();

    final completedDates = _historyService.completedDates.toSet();

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
          // Month Header & Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, size: 16, color: Color(0xFFFFB300)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'LỊCH KỶ LUẬT (THÁNG $month / $year)',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: Color(0xFFF1F5F9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _displayedMonth = DateTime(year, month - 1, 1);
                      });
                    },
                    child: const Icon(Icons.chevron_left, size: 20, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _displayedMonth = DateTime(year, month + 1, 1);
                      });
                    },
                    child: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Weekday Labels (T2 to CN)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
                .map((w) => Text(
                      w,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                    ))
                .toList(),
          ),

          const SizedBox(height: 8),

          // Grid of Days
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42, // 6 weeks * 7 days
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - (firstWeekday - 1) + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final date = DateTime(year, month, dayNumber);
              final dateStr = FocusHistoryService.formatDate(date);
              final isCompleted = completedDates.contains(dateStr);
              final isToday = date.year == today.year && date.month == today.month && date.day == today.day;

              return InkWell(
                onTap: () async {
                  final focusSec = await _historyService.getFocusSecondsForDate(date);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isCompleted
                              ? 'Ngày $dayNumber/$month: Đã tập trung ${_historyService.formatSeconds(focusSec)} ✓'
                              : 'Ngày $dayNumber/$month: Chưa có phiên hoàn thành.',
                        ),
                        duration: const Duration(seconds: 2),
                        backgroundColor: const Color(0xFF1E2333),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF10B981).withValues(alpha: 0.2)
                        : (isToday ? const Color(0xFF3B82F6).withValues(alpha: 0.15) : const Color(0xFF1E2333)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isToday
                          ? const Color(0xFF60A5FA)
                          : (isCompleted ? const Color(0xFF10B981) : const Color(0xFF262C3D)),
                      width: isToday ? 1.5 : 1.0,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$dayNumber',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday
                              ? const Color(0xFF60A5FA)
                              : (isCompleted ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
                        ),
                      ),
                      if (isCompleted)
                        Positioned(
                          bottom: 2,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

}
