import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_dart/features/settings/app_selection_screen.dart';
import 'package:test_dart/features/telemetry/screen_time_tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('focusknight/apps');
  const usage = MethodChannel('usage_stats');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  bool failLoad = false;

  setUp(() {
    failLoad = false;
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(usage, (call) async => false);
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (failLoad) throw PlatformException(code: 'unavailable');
      return {
        'com.example.reader': 'Reader',
        'com.example.long':
            'Ứng dụng có tên rất dài để kiểm tra trên màn hình nhỏ',
      };
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(usage, null);
  });

  Future<ScreenTimeTracker> open(WidgetTester tester) async {
    final tracker = ScreenTimeTracker();
    await tracker.ready;
    addTearDown(tracker.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AppSelectionScreen(tracker: tracker),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return tracker;
  }

  testWidgets(
    'search and save add a custom app, cancel keeps the saved selection',
    (tester) async {
      tester.view.physicalSize = const Size(340, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tracker = await open(tester);
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'reader');
      await tester.pump();
      expect(find.text('Reader'), findsOneWidget);
      expect(find.text('Facebook'), findsNothing);
      await tester.tap(find.text('Reader'));
      await tester.pump();
      await tester.tap(find.text('Lưu (5)'));
      await tester.pumpAndSettle();
      expect(tracker.trackedApps['com.example.reader'], 'Reader');
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'reader');
      await tester.pump();
      await tester.tap(find.text('Reader'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tracker.trackedApps['com.example.reader'], 'Reader');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'failed installed-app query shows retry instead of an empty successful list',
    (tester) async {
      failLoad = true;
      await open(tester);
      expect(find.text('Không tải được danh sách ứng dụng.'), findsOneWidget);
      failLoad = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Reader'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
