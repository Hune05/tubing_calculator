// 평행·축소 시트: 각도 범위를 벗어나면 값 대신 까닭을 보인다.
// 예전 평행 모드는 180°에서 tan(90°)로 '+816…mm'가 나왔다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_parallel_shrink_bottom_sheet.dart';

void main() {
  Future<List<String>> pump(WidgetTester tester, double width) async {
    await tester.binding.setSurfaceSize(Size(width, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString());
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MobileParallelShrinkBottomSheet(initialAngle: 45),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = old;
    }
    return errors;
  }

  TextEditingController angleCtrl(WidgetTester tester) => tester
      .widget<TextField>(
        find.byWidgetPredicate(
          (w) => w is TextField && w.controller?.text == '45',
        ),
      )
      .controller!;

  testWidgets('평행 180°: 까닭을 보인다', (tester) async {
    await pump(tester, 800);
    angleCtrl(tester).text = '180';
    await tester.pump();
    expect(find.text('각도는 90°까지 넣을 수 있습니다.'), findsOneWidget);
    expect(find.textContaining('+8'), findsNothing);
  });

  testWidgets('평행 90°, 간격 50, 1번: +50.0 mm', (tester) async {
    await pump(tester, 800);
    angleCtrl(tester).text = '90';
    await tester.pump();
    expect(find.text('+50.0 mm'), findsOneWidget);
  });

  for (final w in [320.0, 360.0]) {
    testWidgets('폭 $w에서 넘치지 않는다', (tester) async {
      expect(await pump(tester, w), isEmpty);
    });
  }
}
