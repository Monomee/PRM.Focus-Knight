import 'package:flutter/foundation.dart';
import 'package:usage_stats/usage_stats.dart';

import '../../../core/constants/blacklist_constants.dart';
import 'focus_history_service.dart';

/// Data point representing a single day's correlation between social media usage and focus completion
class DayCorrelationData {
  final String dayLabel;
  final DateTime date;
  final double? socialHours;
  final double focusHours;
  final double completionRate;

  const DayCorrelationData({
    required this.dayLabel,
    required this.date,
    required this.socialHours,
    required this.focusHours,
    required this.completionRate,
  });
}

/// Data model for Distraction Velocity (Tần suất bồn chồn)
class DistractionVelocityData {
  final double? velocityPerHour;
  final int totalInterruptions;
  final double focusWorkHours;
  final String levelKey;
  final String levelLabel;
  final List<double?> weeklyTrend;

  const DistractionVelocityData({
    required this.velocityPerHour,
    required this.totalInterruptions,
    required this.focusWorkHours,
    required this.levelKey,
    required this.levelLabel,
    required this.weeklyTrend,
  });
}

/// Data model for Golden Hours (Khung giờ vàng)
class GoldenHoursData {
  final Map<String, double>
  blockProductivity; // e.g. {'05:00 - 08:00': 0.65, ...}
  final String peakTimeSlot; // e.g. '08:00 - 11:30'
  final double peakEfficiency; // e.g. 0.94 (94%)
  final String title;
  final String recommendation;

  const GoldenHoursData({
    required this.blockProductivity,
    required this.peakTimeSlot,
    required this.peakEfficiency,
    required this.title,
    required this.recommendation,
  });
}

/// Service aggregating analytics: Correlation Analysis, Distraction Velocity, and Golden Hours
class AnalyticsService extends ChangeNotifier {
  static AnalyticsService? _instance;
  static AnalyticsService get instance => _instance ??= AnalyticsService();

  final FocusHistoryService _history = FocusHistoryService.instance;

  List<DayCorrelationData> _correlationDays = [];
  List<DayCorrelationData> get correlationDays =>
      List.unmodifiable(_correlationDays);

  DistractionVelocityData _distractionVelocity = const DistractionVelocityData(
    velocityPerHour: null,
    totalInterruptions: 0,
    focusWorkHours: 0,
    levelKey: 'NO_DATA',
    levelLabel: 'CHƯA ĐỦ DỮ LIỆU',
    weeklyTrend: [],
  );
  DistractionVelocityData get distractionVelocity => _distractionVelocity;

  GoldenHoursData _goldenHours = const GoldenHoursData(
    blockProductivity: {
      '00h - 05h': 0,
      '05h - 08h': 0,
      '08h - 11h': 0,
      '11h - 14h': 0,
      '14h - 17h': 0,
      '17h - 21h': 0,
      '21h - 24h': 0,
    },
    peakTimeSlot: '',
    peakEfficiency: 0,
    title: 'Khung Giờ Vàng Của Hiệp Sĩ',
    recommendation: 'Chưa đủ dữ liệu tập trung để xác định khung giờ vàng.',
  );
  GoldenHoursData get goldenHours => _goldenHours;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  AnalyticsService() {
    refreshAnalytics();
  }

  /// Refreshes all 3 analytics modules
  Future<void> refreshAnalytics() async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        _computeCorrelationData(),
        _computeDistractionVelocity(),
        _computeGoldenHours(),
      ]);
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  /// 1. Correlation Analysis: Computes 7-day social media hours vs focus target completion rate
  Future<void> _computeCorrelationData() async {
    final now = DateTime.now();
    final List<DayCorrelationData> days = [];
    const weekdayNames = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

    // Target daily focus duration baseline: 75 minutes (1.25h)
    const targetFocusSec = 75 * 60;

    bool usagePermission = false;
    try {
      usagePermission = await UsageStats.checkUsagePermission() ?? false;
    } catch (_) {}

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayLabel = weekdayNames[date.weekday % 7];
      final isToday = i == 0;
      final actualFocusSec = await _history.getFocusSecondsForDate(date);
      final focusHours = actualFocusSec / 3600.0;
      double? socialHours;

      if (usagePermission) {
        try {
          final startOfDay = DateTime(date.year, date.month, date.day);
          final endOfDay = isToday
              ? now
              : DateTime(date.year, date.month, date.day, 23, 59, 59);
          final stats = await UsageStats.queryAndAggregateUsageStats(
            startOfDay,
            endOfDay,
          );
          int totalSocialMs = 0;
          for (final pkg in BlacklistConstants.defaultBlacklist) {
            totalSocialMs += stats[pkg]?.totalTimeInForegroundMs ?? 0;
          }
          socialHours = totalSocialMs / 3600000.0;
        } catch (_) {}
      }

      final completionRate = (focusHours / (targetFocusSec / 3600.0)).clamp(
        0.0,
        1.0,
      );

      days.add(
        DayCorrelationData(
          dayLabel: dayLabel,
          date: date,
          socialHours: socialHours == null
              ? null
              : double.parse(socialHours.toStringAsFixed(1)),
          focusHours: double.parse(focusHours.toStringAsFixed(1)),
          completionRate: double.parse(completionRate.toStringAsFixed(2)),
        ),
      );
    }

    _correlationDays = days;
  }

  /// 2. Distraction Velocity: Measures touches / exits / interruptions per focus hour
  Future<void> _computeDistractionVelocity() async {
    final now = DateTime.now();
    final todayFocusSec = await _history.getFocusSecondsForDate(now);
    final todayWorkHours = todayFocusSec / 3600.0;
    final count = await _history.getInterruptionsForDate(now);
    final velocity = todayWorkHours > 0
        ? double.parse((count / todayWorkHours).toStringAsFixed(1))
        : null;

    String levelKey = 'NO_DATA';
    String levelLabel = 'CHƯA ĐỦ DỮ LIỆU';

    if (velocity != null) {
      levelKey = 'DEEP_FLOW';
      levelLabel = 'TẬP TRUNG SÂU';
      if (velocity > 4.0) {
        levelKey = 'HIGH_RESTLESS';
        levelLabel = 'BỒN CHỒN CAO';
      } else if (velocity >= 2.0) {
        levelKey = 'MODERATE';
        levelLabel = 'BÌNH THƯỜNG';
      }
    }

    final trend = <double?>[];
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final focusSeconds = await _history.getFocusSecondsForDate(date);
      final interruptions = await _history.getInterruptionsForDate(date);
      trend.add(
        focusSeconds > 0
            ? double.parse(
                (interruptions / (focusSeconds / 3600.0)).toStringAsFixed(1),
              )
            : null,
      );
    }

    _distractionVelocity = DistractionVelocityData(
      velocityPerHour: velocity,
      totalInterruptions: count,
      focusWorkHours: double.parse(todayWorkHours.toStringAsFixed(1)),
      levelKey: levelKey,
      levelLabel: levelLabel,
      weeklyTrend: trend,
    );
  }

  /// 3. Golden Hours: Computes peak productivity blocks in the week
  Future<void> _computeGoldenHours() async {
    final hourlyStats = await _history.getHourlyFocusStats();

    // Map 24 hours into 6 distinct productivity blocks
    // Block 1: 05h - 08h
    // Block 2: 08h - 11h
    // Block 3: 11h - 14h
    // Block 4: 14h - 17h
    // Block 5: 17h - 21h
    // Block 6: 21h - 24h
    final Map<String, int> blockMinutes = {
      '00h - 05h': 0,
      '05h - 08h': 0,
      '08h - 11h': 0,
      '11h - 14h': 0,
      '14h - 17h': 0,
      '17h - 21h': 0,
      '21h - 24h': 0,
    };

    hourlyStats.forEach((hour, sec) {
      final mins = sec ~/ 60;
      if (hour < 5) {
        blockMinutes['00h - 05h'] = (blockMinutes['00h - 05h'] ?? 0) + mins;
      } else if (hour < 8) {
        blockMinutes['05h - 08h'] = (blockMinutes['05h - 08h'] ?? 0) + mins;
      } else if (hour >= 8 && hour < 11) {
        blockMinutes['08h - 11h'] = (blockMinutes['08h - 11h'] ?? 0) + mins;
      } else if (hour >= 11 && hour < 14) {
        blockMinutes['11h - 14h'] = (blockMinutes['11h - 14h'] ?? 0) + mins;
      } else if (hour >= 14 && hour < 17) {
        blockMinutes['14h - 17h'] = (blockMinutes['14h - 17h'] ?? 0) + mins;
      } else if (hour >= 17 && hour < 21) {
        blockMinutes['17h - 21h'] = (blockMinutes['17h - 21h'] ?? 0) + mins;
      } else if (hour >= 21) {
        blockMinutes['21h - 24h'] = (blockMinutes['21h - 24h'] ?? 0) + mins;
      }
    });

    final Map<String, double> normalizedBlocks = {};

    int maxMinutes = 0;
    blockMinutes.forEach((_, m) {
      if (m > maxMinutes) maxMinutes = m;
    });

    blockMinutes.forEach((key, m) {
      final ratio = maxMinutes > 0 ? m / maxMinutes : 0.0;
      normalizedBlocks[key] = double.parse(ratio.toStringAsFixed(2));
    });

    String bestBlock = '';
    double highestRate = 0.0;
    int bestMinutes = 0;
    blockMinutes.forEach((block, minutes) {
      if (minutes > bestMinutes) {
        bestMinutes = minutes;
        highestRate = normalizedBlocks[block]!;
        bestBlock = block;
      }
    });

    final peakTimeSlot = bestBlock.replaceAll('h', ':00');
    final hasData = maxMinutes > 0;

    _goldenHours = GoldenHoursData(
      blockProductivity: normalizedBlocks,
      peakTimeSlot: hasData ? peakTimeSlot : '',
      peakEfficiency: highestRate,
      title: 'Khung Giờ Vàng Của Hiệp Sĩ',
      recommendation: hasData
          ? 'Bạn tập trung nhiều nhất vào khung giờ $peakTimeSlot. Hãy cân nhắc xếp các task quan trọng vào thời gian này.'
          : 'Chưa đủ dữ liệu tập trung để xác định khung giờ vàng.',
    );
  }
}
