import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/blacklist_constants.dart';
import '../../core/services/overlay_service.dart';
import '../focus_session/focus_session_controller.dart';
import '../game_view/combat_engine.dart';
import '../game_view/pomodoro_game_screen.dart';
import '../telemetry/screen_time_tracker.dart';
import 'services/analytics_service.dart';
import 'services/focus_history_service.dart';
import 'widgets/correlation_chart_card.dart';
import 'widgets/distraction_velocity_card.dart';
import 'widgets/golden_hours_card.dart';

/// Central Dashboard screen for FocusKnight.
/// Displays Streak counter, Monthly Dot-Grid Calendar, Today Focus Time,
/// Screen-Time Telemetry & Plain text limit, Overlay permission controls,
/// and primary entrypoint to the Pomodoro Battle session.
class FocusKnightDashboardScreen extends StatefulWidget {
  final CombatEngine combatEngine;
  final FocusSessionController sessionController;
  final ScreenTimeTracker screenTimeTracker;
  final OverlayService overlayService;

  const FocusKnightDashboardScreen({
    super.key,
    required this.combatEngine,
    required this.sessionController,
    required this.screenTimeTracker,
    required this.overlayService,
  });

  @override
  State<FocusKnightDashboardScreen> createState() => _FocusKnightDashboardScreenState();
}

class _FocusKnightDashboardScreenState extends State<FocusKnightDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _limitTextController;
  final FocusHistoryService _historyService = FocusHistoryService.instance;
  DateTime _displayedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _limitTextController = TextEditingController(
      text: '${widget.screenTimeTracker.dailyLimitMinutes}',
    );

    widget.screenTimeTracker.addListener(_onScreenTimeTrackerChanged);
    _historyService.addListener(_onHistoryChanged);

    _loadDashboardData();
  }

  void _onScreenTimeTrackerChanged() {
    final currentVal = int.tryParse(_limitTextController.text.trim());
    if (currentVal != widget.screenTimeTracker.dailyLimitMinutes) {
      _limitTextController.text = '${widget.screenTimeTracker.dailyLimitMinutes}';
    }
    if (mounted) setState(() {});
  }

  void _onHistoryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    widget.screenTimeTracker.removeListener(_onScreenTimeTrackerChanged);
    _historyService.removeListener(_onHistoryChanged);
    _limitTextController.dispose();
    super.dispose();
  }

  /// Fixes Edge Case B: Reloads fresh data immediately after returning from PomodoroGameScreen
  Future<void> _loadDashboardData() async {
    await _historyService.loadData();
    await widget.screenTimeTracker.refreshUsageStats();
    await AnalyticsService.instance.refreshAnalytics();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _navigateToGameScreen() async {
    // Edge Case B: Await navigation and reload data on pop to prevent stale state
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PomodoroGameScreen(
          combatEngine: widget.combatEngine,
          sessionController: widget.sessionController,
        ),
      ),
    );

    _loadDashboardData();
  }

  void _saveDailyLimit() {
    final minutes = int.tryParse(_limitTextController.text.trim());
    if (minutes != null && minutes > 0) {
      widget.screenTimeTracker.setDailyLimitMinutes(minutes);
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu hạn mức MXH: $minutes phút/ngày'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF1E2333),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số phút hợp lệ (> 0)'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF7F1D1D),
        ),
      );
    }
  }

  void _showSetAppLimitDialog(String pkg, String appName) {
    final currentLimit = widget.screenTimeTracker.getAppLimit(pkg);
    final textController = TextEditingController(text: '$currentLimit');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.timer_outlined, color: Color(0xFFFFB300), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Hạn mức: $appName',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập số phút cho phép sử dụng mỗi ngày (không giới hạn):',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                suffixText: 'phút/ngày',
                suffixStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFF121520),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFFB300))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () {
              final mins = int.tryParse(textController.text.trim());
              if (mins != null && mins > 0) {
                widget.screenTimeTracker.setAppLimit(pkg, mins);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã cập nhật hạn mức cho $appName: $mins phút/ngày'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: const Color(0xFF1E2333),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161A26),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.shield, color: Color(0xFFFFB300), size: 20),
            SizedBox(width: 8),
            Text(
              'FOCUSKNIGHT',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Color(0xFFF3F4F6),
              ),
            ),
          ],
        ),
        actions: [
          // Gold Counter
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFB45309).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFB300), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on, color: Color(0xFFFFD54F), size: 14),
                const SizedBox(width: 4),
                ListenableBuilder(
                  listenable: widget.combatEngine,
                  builder: (context, _) {
                    return Text(
                      '${widget.combatEngine.gold} GOLD',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFD54F),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Segmented Pill TabBar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF161A26),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF262C3D)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xFFFFB300),
                  borderRadius: BorderRadius.circular(8),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: const Color(0xFF0F111A),
                labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.3),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.3),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.shield, size: 16),
                    text: 'TẬP TRUNG',
                    iconMargin: EdgeInsets.only(bottom: 2),
                  ),
                  Tab(
                    icon: Icon(Icons.insights, size: 16),
                    text: 'QUẢN LÝ & PHÂN TÍCH',
                    iconMargin: EdgeInsets.only(bottom: 2),
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFocusAndControlTab(),
                  _buildManagementAndAnalyticsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: TẬP TRUNG & KIỂM SOÁT (Focus & Control)
  // ---------------------------------------------------------------------------
  Widget _buildFocusAndControlTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: const Color(0xFFFFB300),
      backgroundColor: const Color(0xFF1E2333),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Streak Banner
            _buildStreakBanner(),

            const SizedBox(height: 12),

            // 2. Today Focus Stats Cards
            _buildTodayStatsRow(),

            const SizedBox(height: 14),

            // 3. Primary Action Button: Enter Pomodoro Battle
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToGameScreen,
                icon: const Icon(Icons.sports_martial_arts, size: 22),
                label: const Text(
                  'VÀO CA CHIẾN ĐẤU (START POMODORO)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 4,
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 4. Monthly Dot-Grid Calendar Card
            _buildMonthlyDotGridCalendar(),

            const SizedBox(height: 14),

            // 5. Telemetry Card (Screen-Time MXH, Text Limit, Overlay)
            _buildTelemetryCard(),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: QUẢN LÝ & PHÂN TÍCH (Analytics & Insights)
  // ---------------------------------------------------------------------------
  Widget _buildManagementAndAnalyticsTab() {
    final analytics = AnalyticsService.instance;

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: const Color(0xFFFFB300),
      backgroundColor: const Color(0xFF1E2333),
      child: ListenableBuilder(
        listenable: analytics,
        builder: (context, _) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Correlation Analysis Card
                CorrelationChartCard(data: analytics.correlationDays),

                const SizedBox(height: 14),

                // 2. Distraction Velocity Card
                DistractionVelocityCard(data: analytics.distractionVelocity),

                const SizedBox(height: 14),

                // 3. Golden Hours Card
                GoldenHoursCard(data: analytics.goldenHours),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. STREAK BANNER
  // ---------------------------------------------------------------------------
  Widget _buildStreakBanner() {
    final streak = _historyService.calculateStreak();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E1A11), Color(0xFF1B1E2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD97706), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEA580C).withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF97316), width: 1.5),
            ),
            child: const Center(
              child: Text(
                '🔥',
                style: TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$streak NGÀY LIÊN TIẾP',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Color(0xFFFFB300),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  streak > 0
                      ? 'Kỷ luật rèn giũa ý chí hiệp sĩ. Hãy hoàn thành phiên hôm nay!'
                      : 'Bắt đầu phiên Pomodoro đầu tiên để thắp sáng ngọn lửa kỷ luật!',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. TODAY STATS ROW
  // ---------------------------------------------------------------------------
  Widget _buildTodayStatsRow() {
    final todayFocus = _historyService.formatSeconds(_historyService.todayFocusSeconds);
    final totalHours = _historyService.totalFocusHoursAllTime;

    return Row(
      children: [
        Expanded(
          child: _buildMetricBox(
            title: 'HÔM NAY TẬP TRUNG',
            value: todayFocus,
            subtitle: 'Thời gian đã hoàn thành',
            icon: Icons.timer,
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricBox(
            title: 'TỔNG TÍCH LŨY',
            value: '${totalHours}h',
            subtitle: 'Kỷ luật toàn thời gian',
            icon: Icons.military_tech,
            color: const Color(0xFF60A5FA),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBox({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161A26),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF262C3D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. MONTHLY DOT-GRID CALENDAR (Clean, minimal grid with emerald green dots)
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // 4. TELEMETRY CARD (Screen-Time MXH, Text Limit, Overlay)
  // ---------------------------------------------------------------------------
  Widget _buildTelemetryCard() {
    final tracker = widget.screenTimeTracker;
    final hasPerm = tracker.hasPermission;
    final totalDistraction = tracker.totalDistractionToday;
    final isExceeded = tracker.isLimitExceeded;
    final progress = tracker.limitProgress;

    final Color progressColor = isExceeded
        ? const Color(0xFFEF4444)
        : (progress >= 0.8 ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.phone_android, size: 16, color: Color(0xFF60A5FA)),
                  SizedBox(width: 6),
                  Text(
                    'SCREEN-TIME & BLOCKER OVERLAY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => tracker.refreshUsageStats(),
                child: const Icon(Icons.refresh, size: 16, color: Color(0xFF94A3B8)),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (!hasPerm) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF78350F).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD97706)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Cần cấp quyền Truy cập Sử dụng để theo dõi MXH.',
                      style: TextStyle(fontSize: 11, color: Color(0xFFFCD34D)),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => tracker.requestPermission(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Cấp quyền', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Daily Limit Section Header & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.hourglass_top, size: 14, color: Color(0xFFFFB300)),
                    SizedBox(width: 5),
                    Text(
                      'HẠN MỨC MXH TRONG NGÀY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Color(0xFFE2E8F0),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isExceeded
                        ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                        : (progress >= 0.8
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                            : const Color(0xFF10B981).withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isExceeded
                          ? const Color(0xFFEF4444)
                          : (progress >= 0.8 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                    ),
                  ),
                  child: Text(
                    isExceeded
                        ? '⚠️ ĐÃ QUÁ HẠN'
                        : 'Còn: ${tracker.formatDuration(tracker.remainingTime)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isExceeded
                          ? const Color(0xFFEF4444)
                          : (progress >= 0.8 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Plain Text Input Field for Daily Limit
            TextField(
              controller: _limitTextController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveDailyLimit(),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: 'Nhập số phút (ví dụ: 45, 60)',
                hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF121622),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                prefixIcon: const Icon(Icons.timer_outlined, size: 18, color: Color(0xFFFFB300)),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('phút', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ElevatedButton(
                        onPressed: _saveDailyLimit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Lưu', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFFFB300), width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Quick preset chips
            Row(
              children: [
                const Text('Gợi ý:', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                const SizedBox(width: 6),
                ...[15, 30, 60, 120].map((mins) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () {
                        _limitTextController.text = '$mins';
                        tracker.setDailyLimitMinutes(mins);
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: tracker.dailyLimitMinutes == mins
                              ? const Color(0xFFFFB300).withValues(alpha: 0.2)
                              : const Color(0xFF1E2333),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: tracker.dailyLimitMinutes == mins
                                ? const Color(0xFFFFB300)
                                : const Color(0xFF334155),
                          ),
                        ),
                        child: Text(
                          '${mins}m',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: tracker.dailyLimitMinutes == mins
                                ? const Color(0xFFFFB300)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),

            const SizedBox(height: 10),

            // Usage Progress Indicator
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFF0F172A),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 6,
              ),
            ),

            const SizedBox(height: 6),

            // Usage vs Limit Caption
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Đã dùng: ${tracker.formatDuration(totalDistraction)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isExceeded ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                  ),
                ),
                Text(
                  'Hạn mức: ${tracker.dailyLimitMinutes} phút',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),

            const Divider(color: Color(0xFF262C3D), height: 16),

            // Blacklisted apps breakdown with individual limits
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'ỨNG DỤNG THEO DÕI',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                ),
                Text(
                  'ĐÃ DÙNG / HẠN MỨC',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 6),

            ...BlacklistConstants.defaultBlacklist.map((pkg) {
              final appName = BlacklistConstants.appNames[pkg] ?? pkg;
              final dur = tracker.appDistractions[pkg] ?? Duration.zero;
              final limit = tracker.getAppLimit(pkg);
              final isAppExceeded = tracker.isAppLimitExceeded(pkg);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('• $appName', style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1))),
                        if (isAppExceeded) ...[
                          const SizedBox(width: 4),
                          const Text(
                            '⚠️ Quá hạn',
                            style: TextStyle(fontSize: 9, color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${tracker.formatDuration(dur)} / ${limit}m',
                          style: TextStyle(
                            fontSize: 11,
                            color: isAppExceeded
                                ? const Color(0xFFEF4444)
                                : (dur.inSeconds > 0 ? const Color(0xFFFBBF24) : const Color(0xFF94A3B8)),
                            fontWeight: dur.inSeconds > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _showSetAppLimitDialog(pkg, appName),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2333),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: const Icon(Icons.edit, size: 12, color: Color(0xFFFFB300)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),
            const Text(
              '💡 Khi dùng quá hạn mức, hệ thống sẽ gửi thông báo đẩy (popup) nhắc nhở nghỉ ngơi.',
              style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 10),

            // Overlay Permission and Setting Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => widget.overlayService.hasPermission
                        ? widget.overlayService.openSettings()
                        : widget.overlayService.requestPermission(),
                    icon: Icon(
                      widget.overlayService.hasPermission ? Icons.settings : Icons.security,
                      size: 14,
                    ),
                    label: Text(
                      widget.overlayService.hasPermission ? 'Quản lý Overlay' : 'Cấp quyền Overlay',
                      style: const TextStyle(fontSize: 11),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.overlayService.hasPermission
                          ? const Color(0xFF10B981)
                          : const Color(0xFFFFB300),
                      side: BorderSide(
                        color: widget.overlayService.hasPermission
                            ? const Color(0xFF10B981)
                            : const Color(0xFFFFB300),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => tracker.openSettings(),
                    icon: const Icon(Icons.tune, size: 14),
                    label: const Text('Cài đặt Sử dụng', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF94A3B8),
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
