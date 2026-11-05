import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/features/dashboard/services/analytics_journal.dart';
import 'package:test_dart/features/dashboard/services/analytics_service.dart';
import 'package:test_dart/features/dashboard/services/focus_history_service.dart';
import 'package:test_dart/features/dashboard/widgets/analytics_chart.dart';
import 'package:test_dart/features/dashboard/widgets/correlation_chart_card.dart';
import 'package:test_dart/features/dashboard/widgets/discipline_calendar_card.dart';
import 'package:test_dart/features/dashboard/widgets/distraction_velocity_card.dart';
import 'package:test_dart/features/dashboard/widgets/focus_endurance_card.dart';
import 'package:test_dart/features/dashboard/widgets/golden_hours_card.dart';
import 'package:test_dart/features/home/analytics_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'calendar handles 28, 29, 30 and 31 day months without outside days',
    (tester) async {
      late AnalyticsService a;
      late FocusHistoryService h;
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({});
        h = FocusHistoryService();
        await h.loadData();
        a = AnalyticsService(history: h);
        await a.refreshAnalytics();
      });
      addTearDown(a.dispose);
      addTearDown(h.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: DisciplineCalendarCard(analytics: a),
            ),
          ),
        ),
      );
      final now = DateTime.now(), lengths = <int>{};
      for (var offset = 0; offset < 98 && lengths.length < 4; offset++) {
        final month = DateTime(now.year, now.month + offset),
            last = DateTime(now.year, now.month + offset + 1, 0).day;
        lengths.add(last);
        expect(find.text('${month.month}/${month.year}'), findsOneWidget);
        expect(find.text('$last'), findsOneWidget);
        expect(find.text('${last + 1}'), findsNothing);
        await tester.ensureVisible(find.byTooltip('Tháng sau'));
        await tester.tap(find.byTooltip('Tháng sau'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(lengths, {28, 29, 30, 31});
    },
  );
  testWidgets('analytics route contains exactly five dashboards in order', (
    tester,
  ) async {
    late FocusHistoryService h;
    await tester.runAsync(() async {
      await AnalyticsJournal.instance.flushed;
      SharedPreferences.setMockInitialValues({});
      h = FocusHistoryService();
      await h.loadData();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: AnalyticsScreen(history: h),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    for (final type in [
      DisciplineCalendarCard,
      GoldenHoursCard,
      FocusEnduranceCard,
      DistractionVelocityCard,
      CorrelationChartCard,
    ]) {
      for (
        var attempt = 0;
        attempt < 10 && find.byType(type).evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(find.byType(type), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    h.dispose();
  });
  for (final width in [320.0, 412.0]) {
    testWidgets(
      'five dashboards render at $width with 200% text and calendar navigation',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late AnalyticsService a;
        late FocusHistoryService h;
        await tester.runAsync(() async {
          await AnalyticsJournal.instance.flushed;
          SharedPreferences.setMockInitialValues({});
          h = FocusHistoryService();
          await h.loadData();
          a = AnalyticsService(history: h);
          await a.refreshAnalytics();
        });
        addTearDown(a.dispose);
        addTearDown(h.dispose);
        final cards = <Widget>[
          DisciplineCalendarCard(analytics: a),
          GoldenHoursCard(data: a.goldenHours),
          FocusEnduranceCard(analytics: a),
          DistractionVelocityCard(data: a.distractionVelocity),
          CorrelationChartCard(data: a.correlationDays),
        ];
        for (final card in cards) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 900),
                  textScaler: TextScaler.linear(2),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: card,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (card is DisciplineCalendarCard) {
            final now = DateTime.now();
            await tester.ensureVisible(find.byTooltip('Tháng trước'));
            await tester.tap(find.byTooltip('Tháng trước'));
            await tester.pumpAndSettle();
            final previous = DateTime(now.year, now.month - 1);
            expect(
              find.text('${previous.month}/${previous.year}'),
              findsOneWidget,
            );
            await tester.tap(find.byTooltip('Tháng sau'));
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('1').first);
            await tester.tap(find.text('1').first);
            await tester.pumpAndSettle();
            expect(
              find.textContaining('phiên chưa hoàn thành'),
              findsOneWidget,
            );
            await tester.tap(find.byTooltip('Đóng'));
            await tester.pumpAndSettle();
          }
          if (card is GoldenHoursCard) {
            expect(find.byKey(const ValueKey('golden-grid')), findsNothing);
            await tester.ensureVisible(
              find.byTooltip('Thông tin Khung giờ vàng'),
            );
            await tester.tap(find.byTooltip('Thông tin Khung giờ vàng'));
            await tester.pumpAndSettle();
            expect(find.byType(BottomSheet), findsOneWidget);
            expect(find.textContaining('ít nhất 3 phiên'), findsWidgets);
            await tester.tap(find.byTooltip('Đóng'));
            await tester.pumpAndSettle();
          }
        }
      },
    );
  }
  testWidgets(
    'real chart points expose touch detail and missing line samples remain absent',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnalyticsChart(
              points: const [(x: 1.0, y: 0.0), null, (x: 3.0, y: 2.0)],
              color: Colors.red,
              xLabel: 'Ngày',
              yLabel: 'Lần/giờ',
              details: const [
                'Không gián đoạn',
                'Không có dữ liệu',
                '2 lần/giờ',
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('2 lần/giờ'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('2 lần/giờ'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
