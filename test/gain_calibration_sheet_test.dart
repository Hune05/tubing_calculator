import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_gain_calibration_sheet.dart';

void main() {
  Future<void> open(WidgetTester tester, {required void Function(double) onApply}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MobileGainCalibrationSheet(onApply: onApply),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String result(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('calib_result'))).data!;

  Future<void> fill(
    WidgetTester tester, {
    required String cut,
    required String legA,
    required String legB,
    String angle = '90',
  }) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), cut);
    await tester.enterText(fields.at(1), legA);
    await tester.enterText(fields.at(2), legB);
    await tester.enterText(fields.at(3), angle);
    await tester.pumpAndSettle();
  }

  testWidgets('값을 안 넣으면 넣으라고 한다', (tester) async {
    await open(tester, onApply: (_) {});
    expect(result(tester), '값을 넣으십시오');
  });

  testWidgets('재 본 값으로 연신율을 보여 준다', (tester) async {
    await open(tester, onApply: (_) {});
    await fill(tester, cut: '880', legA: '500', legB: '400');
    expect(result(tester), '20.0 mm');
  });

  testWidgets('45°로 재면 90° 기준으로 바꿔 준다', (tester) async {
    await open(tester, onApply: (_) {});
    // 90° 게인 40인 벤더를 45°로 꺾으면 4.0mm 줄어든다.
    await fill(tester, cut: '896.0', legA: '500', legB: '400', angle: '45');
    expect(result(tester), '39.9 mm');
  });

  testWidgets('제원에 넣기를 누르면 그 값을 돌려준다', (tester) async {
    double? got;
    await open(tester, onApply: (v) => got = v);
    await fill(tester, cut: '880', legA: '500', legB: '400');
    final btn = find.byKey(const Key('calib_apply'));
    await tester.ensureVisible(btn);
    await tester.pumpAndSettle();
    await tester.tap(btn);
    await tester.pumpAndSettle();
    expect(got, closeTo(20.0, 0.01));
  });

  testWidgets('값이 없으면 넣기를 누를 수 없다', (tester) async {
    await open(tester, onApply: (_) {});
    final btn = tester.widget<ElevatedButton>(
      find.byKey(const Key('calib_apply')),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('자른 길이가 더 길면(줄지 않았으면) 값을 안 잡는다', (tester) async {
    await open(tester, onApply: (_) {});
    await fill(tester, cut: '950', legA: '500', legB: '400');
    expect(result(tester), '값을 넣으십시오');
  });
}
