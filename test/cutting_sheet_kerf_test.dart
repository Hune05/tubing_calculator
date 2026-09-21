// 재단 계획 카드의 '잔여'는 저장·PDF와 같이 톱날 손실을 뺀 값이어야 한다.
// 6000에서 2500×2, 톱날 3 → 6000 − 5000 − 2×3 = 994 (예전 화면은 1000).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_leftovers.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/widgets/cutting_optimization_sheet.dart';

void main() {
  leftoverStore = PrefsLeftoverStore();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('잔여 994mm', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCuttingOptimizationSheet(
                context,
                pieces: const [2500, 2500, 2500, 1000],
                initialStockLength: 6000,
                kerf: 3,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('잔여 994mm'), findsOneWidget);
    expect(find.text('잔여 1000mm'), findsNothing);
  });
}
