import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/services/demo_data_seeder.dart';
import '../../core/widgets/flat_theme.dart';
import '../dashboard/services/analytics_calculations.dart';
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
  late final panels = _buildPanels(analytics);
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    analytics.refreshAnalytics();
    if (DemoDataSeeder.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoScroll());
    }
  }

  Future<void> _autoScroll() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted || !_scrollController.hasClients) return;
    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(seconds: 18),
      curve: Curves.linear,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      analytics.refreshAnalytics();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    analytics.dispose();
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
    appBar: AppBar(title: const Text('Phân tích'), backgroundColor: Flat.bg),
    body: RefreshIndicator(
      onRefresh: analytics.refreshAnalytics,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: panels,
      ),
    ),
  );
}
