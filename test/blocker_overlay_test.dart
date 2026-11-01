import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_dart/features/overlay/blocker_overlay_widget.dart';

void main() {
  testWidgets(
    'daily limit overlay has no battle penalties and resets on battle data',
    (tester) async {
      tester.view.physicalSize = const Size(400, 860);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final updates = StreamController<dynamic>();
      addTearDown(updates.close);
      var closed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: BlockerOverlayWidget(
            updates: updates.stream,
            onAutoClose: () async => closed++,
          ),
        ),
      );
      updates.add({
        'mode': 'dailyLimit',
        'app': 'Facebook',
        'limitMinutes': 30,
        'defeated': false,
      });
      await tester.pump();
      expect(find.text('ĐÃ HẾT THỜI GIAN SỬ DỤNG'), findsOneWidget);
      expect(find.textContaining('30 phút'), findsOneWidget);
      expect(find.text('QUAY LẠI FOCUSKNIGHT'), findsOneWidget);
      expect(find.textContaining('HP '), findsNothing);
      expect(find.textContaining('Quỹ trận'), findsNothing);
      await tester.pump(const Duration(seconds: 6));
      expect(closed, 0);
      updates.add({'app': 'YouTube', 'hp': 75, 'coins': 30, 'defeated': false});
      await tester.pump();
      await tester.pump();
      expect(find.text('QUAY LẠI TRẬN'), findsOneWidget);
      expect(find.text('HP 75/100'), findsOneWidget);
    },
  );

  testWidgets('overlay shows live HP and escrow from shared data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final updates = StreamController<dynamic>();
    addTearDown(updates.close);
    await tester.pumpWidget(
      MaterialApp(home: BlockerOverlayWidget(updates: updates.stream)),
    );

    updates.add({'app': 'YouTube', 'hp': 75, 'coins': 30, 'defeated': false});
    await tester.pump();
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('HP 75/100'), findsOneWidget);
    expect(find.text('Quỹ trận: 30 coin'), findsOneWidget);
    expect(find.text('QUAY LẠI TRẬN'), findsOneWidget);

    updates.add({'app': 'YouTube', 'hp': 0, 'coins': 0, 'defeated': true});
    await tester.pump();
    expect(find.textContaining('Thất bại'), findsOneWidget);
  });

  testWidgets('defeat screen closes itself after 5 seconds', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var closed = 0;
    final updates = StreamController<dynamic>();
    addTearDown(updates.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BlockerOverlayWidget(
          updates: updates.stream,
          onAutoClose: () async => closed++,
        ),
      ),
    );

    updates.add({'app': 'YouTube', 'hp': 75, 'coins': 0, 'defeated': false});
    await tester.pump(const Duration(seconds: 10));
    expect(closed, 0, reason: 'a live battle keeps blocking');

    updates.add({'app': 'YouTube', 'hp': 0, 'coins': 0, 'defeated': true});
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(closed, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(closed, 1);
  });
}
