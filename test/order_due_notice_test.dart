import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/material/material_order_page.dart';

void main() {
  for (final width in [320.0, 360.0, 390.0]) {
    for (final today in [true, false]) {
      testWidgets('입고 알림 줄이 폭 $width에서 넘치지 않는다(오늘=$today)', (tester) async {
        tester.view.physicalSize = Size(width * 3, 2400);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                // 목록 여백 16과 같은 조건.
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OrderDueNotice(isToday: today),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          find.textContaining(today ? '오늘 입고 예정입니다' : '입고가 지연되고 있습니다'),
          findsOneWidget,
        );
      });
    }
  }
}
