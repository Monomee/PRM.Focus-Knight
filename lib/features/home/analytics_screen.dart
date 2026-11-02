import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/widgets/flat_theme.dart';
import '../dashboard/services/analytics_calculations.dart';
import '../dashboard/services/demo_analytics.dart';
import '../dashboard/services/analytics_journal.dart';
import '../dashboard/services/analytics_service.dart';
import '../dashboard/services/focus_history_service.dart';
import '../dashboard/widgets/correlation_chart_card.dart';
import '../dashboard/widgets/discipline_calendar_card.dart';
import '../dashboard/widgets/distraction_velocity_card.dart';
import '../dashboard/widgets/focus_endurance_card.dart';
import '../dashboard/widgets/golden_hours_card.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, required this.history, this.clock});
  final DateTime Function()? clock;
  final FocusHistoryService history;
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with WidgetsBindingObserver {
  late final analytics = AnalyticsService(
    history: widget.history,
    clock: widget.clock,
  );
  DemoAnalytics? _demo;
  bool _showDemo = false;
  List<Widget>? _demoPanels;
  late final realPanels = _buildPanels(analytics);
  AnalyticsService get current => _showDemo ? _demo!.analytics : analytics;
  void _toggleDemo(bool value) {
    if (value && _demo == null) {
      _demo = DemoAnalytics.create(now: widget.clock?.call());
      _demoPanels = _buildPanels(_demo!.analytics);
    }
    setState(() => _showDemo = value);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    analytics.refreshAnalytics();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_showDemo) {
      analytics.refreshAnalytics();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    analytics.dispose();
    _demo?.analytics.dispose();
    super.dispose();
  }

  // Keep each card's element and scroll state when only another metric changes.
  Widget _panel(
    AnalyticsService analytics,
    Object Function() select,
    Widget Function() build,
  ) {
    String? previous;
    Widget? child;
    return ListenableBuilder(
      listenable: analytics,
      builder: (context, _) {
        final fingerprint = jsonEncode(select());
        if (child == null || previous != fingerprint) {
          previous = fingerprint;
          child = build();
        }
        return child!;
      },
    );
  }

  List<Widget> _buildPanels(AnalyticsService analytics) => <Widget>[
    ListenableBuilder(
      listenable: analytics,
      builder: (context, _) => Column(
        children: [
          if (analytics.isLoading)
            const LinearProgressIndicator(semanticsLabel: 'Đang tải phân tích'),
          if (analytics.error != null) ...[
            Text(analytics.error!),
            TextButton(
              onPressed: () async {
                if (!analytics.isDemo) {
                  await AnalyticsJournal.instance.retryFailed();
                }
                await analytics.refreshAnalytics();
              },
              child: const Text('Thử lại'),
            ),
          ],
        ],
      ),
    ),
    _panel(
      analytics,
      () => [
        dateKey(analytics.referenceDate),
        analytics.goals,
        analytics.days.map(
          (k, d) => MapEntry(k, [
            d.seconds,
            d.completed,
            d.incomplete,
            d.goalSeconds,
          ]),
        ),
      ],
      () => DisciplineCalendarCard(
        key: ValueKey('calendar-${analytics.isDemo}'),
        analytics: analytics,
      ),
    ),
    const SizedBox(height: 14),
    _panel(
      analytics,
      () => [
        for (final c in analytics.goldenHours.cells)
          [c.seconds, c.weightedScore, c.sessions.length],
      ],
      () => GoldenHoursCard(data: analytics.goldenHours),
    ),
    const SizedBox(height: 14),
    _panel(
      analytics,
      () => [
        analytics.endurance.count,
        analytics.endurance.median,
        analytics.uninterruptedRate,
        analytics.invalidSessions,
        for (final p in analytics.endurance.points) [p.x, p.y],
      ],
      () => FocusEnduranceCard(analytics: analytics),
    ),
    const SizedBox(height: 14),
    _panel(
      analytics,
      () => [
        analytics.distractionVelocity.weeklyTrend,
        analytics.distractionVelocity.previousRate,
        analytics.distractionVelocity.dailySeconds,
        analytics.distractionVelocity.dailyEvents,
      ],
      () => DistractionVelocityCard(data: analytics.distractionVelocity),
    ),
    const SizedBox(height: 14),
    _panel(
      analytics,
      () => [
        analytics.correlationRange,
        for (final d in analytics.correlationDays)
          [
            dateKey(d.date),
            d.socialHours,
            d.focusHours,
            d.completionRate,
            d.hasGoal,
          ],
      ],
      () => CorrelationChartCard(
        data: analytics.correlationDays,
        range: analytics.correlationRange,
        minimumPairs: analytics.minimumCorrelationPairs,
        onRangeChanged: analytics.setCorrelationRange,
      ),
    ),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Flat.bg,
    appBar: AppBar(
      title: const Text('Phân tích'),
      backgroundColor: Flat.bg,
      actions: [
        if (_showDemo)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Flat.longRest.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  'DEMO',
                  style: TextStyle(
                    color: Flat.longRest,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: current.refreshAnalytics,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Xem dữ liệu mẫu',
                      style: TextStyle(fontSize: 14, color: Flat.text),
                    ),
                    if (_showDemo)
                      const Text(
                        'Dữ liệu mô phỏng · 30 ngày',
                        style: TextStyle(fontSize: 12, color: Flat.longRest),
                      ),
                  ],
                ),
              ),
              Switch.adaptive(
                key: const ValueKey('analytics-demo-toggle'),
                value: _showDemo,
                onChanged: _toggleDemo,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...(_showDemo ? _demoPanels! : realPanels),
        ],
      ),
    ),
  );
}
