// 전동기·발전기 계산의 "전동기 기타" 탭: 일곱 묶음 입력 → 결과·풀이.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 7000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: ElectricCalculatorPage(initialTab: 17)));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

String _all(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text, skipOffstage: false))
    .map((t) => t.data ?? '')
    .join('\n');

void main() {
  insulationUiGroup();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('권선 온도: 2.0 → 2.4 Ω, 20℃, 주위 30℃ → 상승 40.9 K, 권선 70.9 ℃', (tester) async {
    await _open(tester);
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 3);
    await _type(tester, 'mm_r1', '2.0');
    await _type(tester, 'mm_r2', '2.4');
    final t = _all(tester);
    expect(t, contains('= 70.9 ℃'));
    expect(t, contains('= 40.9 K'));
    await _tap(tester, 'mm_al');
    expect(_all(tester), contains('(225.0 + 20.0) − 225.0'.replaceAll('.0', '')));
  });

  testWidgets('효율 절감: 11 kW 부하율 75 효율 90 → 93, 6000 h, 120원, 50만 원 → 2.35년', (tester) async {
    await _open(tester);
    await _tap(tester, 'mm_sec_energy');
    await _type(tester, 'mm_ekw', '11');
    await _type(tester, 'mm_ehours', '6000');
    await _type(tester, 'mm_eold', '90');
    await _type(tester, 'mm_enew', '93');
    await _type(tester, 'mm_eprice', '120');
    await _type(tester, 'mm_eextra', '500000');
    final t = _all(tester);
    expect(t, contains('= 55000 kWh'));
    expect(t, contains('= 1774 kWh'));
    expect(t, contains('= 2.35 년'));
  });

  testWidgets('감속기: 1750 rpm 11 kW, i 10, 95 % → 175 rpm, 570.2 N·m', (tester) async {
    await _open(tester);
    await _tap(tester, 'mm_sec_gear');
    await _type(tester, 'mm_gin', '1750');
    await _type(tester, 'mm_gkw', '11');
    await _type(tester, 'mm_gratio', '10');
    await _type(tester, 'mm_geff', '95');
    var t = _all(tester);
    expect(t, contains('= 175 rpm'));
    expect(t, contains('= 570.2 N·m'));
    // 풀리 지름으로: 비 20 / 100 → i 5
    await _type(tester, 'mm_gratio', '');
    await _type(tester, 'mm_gd1', '100');
    await _type(tester, 'mm_gd2', '500');
    t = _all(tester);
    expect(t, contains('= 500 ÷ 100 = 5'));
    expect(t, contains('= 350 rpm'));
  });

  testWidgets('권상·컨베이어 동력', (tester) async {
    await _open(tester);
    await _tap(tester, 'mm_sec_load');
    await _type(tester, 'mm_lm', '1000');
    await _type(tester, 'mm_lv', '0.5');
    await _type(tester, 'mm_leff', '85');
    expect(_all(tester), contains('= 5.77 kW'));
    await _tap(tester, 'mm_conv');
    await _type(tester, 'mm_lm', '2000');
    await _type(tester, 'mm_lv', '1');
    await _type(tester, 'mm_lmu', '0.03');
    await _type(tester, 'mm_leff', '90');
    expect(_all(tester), contains('= 0.65 kW'));
    await _type(tester, 'mm_lang', '10');
    expect(_all(tester), contains('= 4.43 kW'));
  });

  testWidgets('소프트스타터: 22 A × 6배, 시작 전압 50 % → 66 A, 토크 25 %', (tester) async {
    await _open(tester);
    await _tap(tester, 'mm_sec_soft');
    await _type(tester, 'mm_sia', '22');
    await _type(tester, 'mm_sv', '50');
    final t = _all(tester);
    expect(t, contains('= 66 A'));
    expect(t, contains('0.25배'));
    await _type(tester, 'mm_sv', '150');
    expect(_all(tester), contains('0보다 크고 100 % 이하'));
  });

  testWidgets('제동 에너지: J 2, 1750 → 0 rpm, 5초, 700 V → 33584 J, 6.72 kW, 36.5 Ω', (tester) async {
    await _open(tester);
    await _tap(tester, 'mm_sec_brake');
    await _type(tester, 'mm_bj', '2');
    await _type(tester, 'mm_brpm1', '1750');
    await _type(tester, 'mm_bsec', '5');
    await _type(tester, 'mm_bvdc', '700');
    final t = _all(tester);
    expect(t, contains('= 33584 J'));
    expect(t, contains('= 6.72 kW'));
    expect(t, contains('= 36.5 Ω'));
  });

  testWidgets('직류 전동기: 220 V 20 A 0.5 Ω 1500 rpm → Ea 210 V, 4.2 kW, 26.74 N·m', (tester) async {
    await _open(tester);
    await _tap(tester, 'mm_sec_dc');
    await _type(tester, 'mm_dv', '220');
    await _type(tester, 'mm_dia', '20');
    await _type(tester, 'mm_dra', '0.5');
    await _type(tester, 'mm_drpm', '1500');
    final t = _all(tester);
    expect(t, contains('= 210 V'));
    expect(t, contains('= 4.2 kW'));
    expect(t, contains('= 26.74 N·m'));
    await _type(tester, 'mm_dra', '15');
    expect(_all(tester), contains('이상입니다'));
  });
}

void insulationUiGroup() {
  testWidgets('절연 등급: F급, 상승 90 K, 주위 40℃ → 권선 130℃, 등급 여유 25 K, 한계 여유 15 K', (tester) async {
    tester.view.physicalSize = const Size(800, 7000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: ElectricCalculatorPage(initialTab: 17)));
    await tester.pumpAndSettle();
    await _tap(tester, 'mm_sec_insul');
    var t = _all(tester);
    expect(t, contains('등급 F: 최고 연속 사용 온도 155 ℃(IEC 60085 표 1), 저항법 온도 상승 한계 105 K'));
    await _type(tester, 'mm_irise', '90');
    t = _all(tester);
    expect(t, contains('= 130 ℃'));
    expect(t, contains('= 25 K'));
    expect(t, contains('= 15 K'));
    expect(t, contains('5.66배'));
    // B급으로 바꾸면 한계 초과
    await _tap(tester, 'mm_cls_B');
    await _type(tester, 'mm_irise', '100');
    t = _all(tester);
    expect(t, contains('등급 온도를 넘었습니다'));
    expect(t, contains('한계 초과'));
    await _tap(tester, 'mm_cls_N');
    expect(_all(tester), contains('온도 상승 한계를 확인하지 못했습니다'));
  });
}
