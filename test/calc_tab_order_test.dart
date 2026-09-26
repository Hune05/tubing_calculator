// 계산기 탭 순서(2026-09-26 사용자 선택): 전기 설계 계산은 자주 쓰는 것 먼저, 계기 교정은 교정 점검 먼저,
// 계기 교정에 교정 가스(압력 시험 에어 누설을 바꿈), 유량 계산 끝에 유량계 점검.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';
import 'package:tubing_calculator/src/presentation/flow/flow_calc_page.dart';
import 'package:tubing_calculator/src/presentation/instrument/signal_calculator_page.dart';

List<String> tabLabels(WidgetTester tester) => tester
    .widgetList<Tab>(find.byType(Tab))
    .map((t) => t.text ?? '')
    .toList();

Future<void> pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(390, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('전기 설계 계산: 기초 계산부터, 역률 개선이 끝', (tester) async {
    await pump(tester, const ElectricCalculatorPage());
    expect(tabLabels(tester), [
      '기초 계산',
      '부하 전류',
      '전선 굵기',
      '전압강하',
      '전선관',
      '부스바',
      '역률 개선',
    ]);
  });

  testWidgets('계기 교정: 교정 점검부터, 환산 탭 이름은 4-20mA', (tester) async {
    await pump(tester, const SignalCalculatorPage());
    final labels = tabLabels(tester);
    expect(labels.first, '교정 점검');
    expect(labels[1], '4-20mA');
    expect(labels, isNot(contains('환산')));
    expect(labels.sublist(2), ['온도 센서', '교정 가스', '루프 전압']);
  });

  testWidgets('유량 계산: 끝 탭이 유량계 점검', (tester) async {
    await pump(tester, const FlowCalcPage());
    expect(tabLabels(tester).last, '유량계 점검');
  });
}
