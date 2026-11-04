import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/features/dashboard/services/analytics_journal.dart';
import 'package:test_dart/features/dashboard/services/demo_analytics.dart';
import 'package:test_dart/features/dashboard/services/focus_history_service.dart';
import 'package:test_dart/features/dashboard/widgets/analytics_chart.dart';
import 'package:test_dart/features/dashboard/widgets/discipline_calendar_card.dart';
import 'package:test_dart/features/dashboard/widgets/golden_hours_card.dart';
import 'package:test_dart/features/dashboard/widgets/focus_endurance_card.dart';
import 'package:test_dart/features/dashboard/widgets/distraction_velocity_card.dart';
import 'package:test_dart/features/dashboard/widgets/correlation_chart_card.dart';
import 'package:test_dart/features/home/analytics_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 11, 30, 12);
  testWidgets(
    'demo defaults off, switches all metrics, keeps real state and never queries Android',
    (tester) async {
      late FocusHistoryService history;
      late SharedPreferences prefs;
      await tester.runAsync(() async {
        await AnalyticsJournal.instance.flushed;
        SharedPreferences.setMockInitialValues({
          'fk_focus_sec_2026-11-29': 3600,
          'fk_tracked_apps': '{}',
          'fk_wallet_state': '{"coins":234,"logs":99}',
          'fk_analytics_v1_goals': '{"2026-11-01":3600}',
        });
        prefs = await SharedPreferences.getInstance();
        history = FocusHistoryService(clock: () => now);
        await history.loadData();
      });
      final before = {for (final k in prefs.getKeys()) k: prefs.get(k)};
      var nativeCalls = 0;
      const usage = MethodChannel('usage_stats');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(usage, (call) async {
        nativeCalls++;
        return false;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(usage, null));
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: AnalyticsScreen(history: history, clock: () => now),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('analytics-demo-toggle')), findsNothing);
      expect(find.text('Xem dữ liệu mẫu'), findsNothing);
      expect(find.text('DEMO'), findsNothing);
      final real = tester
          .widget<DisciplineCalendarCard>(find.byType(DisciplineCalendarCard))
          .analytics;
      expect(real.isDemo, false);
      expect(real.day(DateTime(2026, 11, 29)).seconds, 3600);
      expect({for (final k in prefs.getKeys()) k: prefs.get(k)}, before);
      expect(nativeCalls, greaterThanOrEqualTo(0));
      await tester.pumpWidget(const SizedBox());
      history.dispose();
    },
  );

  for (final width in [320.0, 390.0]) {
    testWidgets('populated demo grids and charts fit $width at 200% text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = DemoAnalytics.create(now: now), a = fixture.analytics;
      addTearDown(a.dispose);
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
        expect(tester.takeException(), isNull, reason: '${card.runtimeType}');
        final horizontal = find.byWidgetPredicate(
          (w) =>
              w is Scrollable &&
              (w.axisDirection == AxisDirection.left ||
                  w.axisDirection == AxisDirection.right),
        );
        expect(horizontal, findsNothing);
        if (card is GoldenHoursCard) {
          final grid = find.byKey(const ValueKey('golden-grid'));
          final box = tester.getRect(grid);
          expect(box.left, greaterThanOrEqualTo(0));
          expect(box.right, lessThanOrEqualTo(width));
          expect(find.text('CN'), findsOneWidget);
          final cell = find.byWidgetPredicate(
            (w) =>
                w is Tooltip &&
                (w.message?.startsWith('T2 14:00–17:00') ?? false),
          );
          await tester.ensureVisible(cell);
          await tester.pumpAndSettle();
          await tester.tap(cell);
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsOneWidget);
          expect(
            find.textContaining(
              '${(a.goldenHours.cells[28].score! * 100).round()} điểm',
            ),
            findsWidgets,
          );
          await tester.tap(find.byTooltip('Đóng'));
          await tester.pumpAndSettle();
        }
      }
    });
  }
  testWidgets(
    'compact populated preview exports a screenshot and keeps technical notes in info sheets',
    (tester) async {
      await tester.runAsync(() async {
        final config = File('.dart_tool/package_config.json');
        final packages =
            (jsonDecode(await config.readAsString()) as Map)['packages']
                as List;
        final flutter =
            packages.singleWhere((p) => p['name'] == 'flutter') as Map;
        final fonts = Directory.fromUri(
          config.uri.resolve(flutter['rootUri'] as String),
        ).uri.resolve('../../bin/cache/artifacts/material_fonts/');
        final roboto = FontLoader('Roboto');
        for (final name in ['roboto-regular.ttf', 'roboto-bold.ttf']) {
          roboto.addFont(
            Future.value(
              ByteData.sublistView(
                await File.fromUri(fonts.resolve(name)).readAsBytes(),
              ),
            ),
          );
        }
        await roboto.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                await File.fromUri(fonts.resolve('materialicons-regular.otf'))
                    .readAsBytes(),
              ),
            ),
          );
        await icons.load();
      });
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = DemoAnalytics.create(now: now), a = fixture.analytics;
      addTearDown(a.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Roboto'),
          ),
          home: Scaffold(
            backgroundColor: const Color(0xFF0F131C),
            body: SingleChildScrollView(
              child: RepaintBoundary(
                key: boundary,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      DisciplineCalendarCard(analytics: a),
                      const SizedBox(height: 14),
                      GoldenHoursCard(data: a.goldenHours),
                      const SizedBox(height: 14),
                      FocusEnduranceCard(analytics: a),
                      const SizedBox(height: 14),
                      DistractionVelocityCard(data: a.distractionVelocity),
                      const SizedBox(height: 14),
                      CorrelationChartCard(
                        data: a.correlationDays,
                        onRangeChanged: a.setCorrelationRange,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Kaplan'), findsNothing);
      expect(find.textContaining('Pearson'), findsNothing);
      expect(find.byType(ExpansionTile), findsNothing);
      for (final element in find.byType(AnalyticsCard).evaluate()) {
        expect((element.renderObject! as RenderBox).size.height, lessThan(550));
      }
      final repaint =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final screenshot = await repaint.toImage();
        final bytes = await screenshot.toByteData(
          format: ui.ImageByteFormat.png,
        );
        screenshot.dispose();
        await Directory('build/analytics-preview').create(recursive: true);
        await File('build/analytics-preview/demo-dashboard.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      });
    },
  );
}
