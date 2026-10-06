// 범용 전기 설비 계산기에 새로 넣은 식: 역률·전압 구하기, 임피던스, 케이블 임피던스·손실·온도, 자동 차단 최대 길이,
// 다른 전압에서의 콘덴서 출력.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';
import 'formula_flat.dart';

Future<void> _open(WidgetTester tester, String tab) async {
  tester.view.physicalSize = const Size(800, 9000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: ElectricCalculatorPage()));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(Key(tab)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(tab)));
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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('역률 구하기: 9.5 kW 380 V 18 A 삼상 → 0.802, kW·kVA 80/100 → 0.8', (tester) async {
    await _open(tester, 'ec_tab_basic');
    await _tap(tester, 'ec_bs_acSolve');
    await _type(tester, 'ec_as_kw', '9.5');
    await _type(tester, 'ec_as_amps', '18');
    var t = _all(tester);
    expect(flat(t), contains(flat('= 0.802')));
    expect(t, contains('80.2 %'));
    await _type(tester, 'ec_as_kw', '20');
    expect(_all(tester), contains('역률이 1을 넘습니다'));
    await _tap(tester, 'ec_as_kva');
    await _type(tester, 'ec_as_kw', '80');
    await _type(tester, 'ec_as_kvav', '100');
    t = _all(tester);
    expect(flat(t), contains(flat('= 0.8')));
    expect(flat(t), contains(flat('무효전력 Q = √(S² − P²)')));
  });

  testWidgets('전압 구하기: 10 kW, 18.2 A, 역률 85 % 삼상 → 373.2 V, kVA·전류 방식', (tester) async {
    await _open(tester, 'ec_tab_basic');
    await _tap(tester, 'ec_bs_acSolve');
    await _tap(tester, 'ec_as_v');
    await _type(tester, 'ec_as_kw', '10');
    await _type(tester, 'ec_as_amps', '18.2');
    await _type(tester, 'ec_as_pf_in', '85');
    expect(flat(_all(tester)), contains(flat('= 373.2 V')));
    await _tap(tester, 'ec_as_kva');
    await _type(tester, 'ec_as_kvav', '100');
    await _type(tester, 'ec_as_amps', '152');
    expect(flat(_all(tester)), contains(flat('= 379.8 V')));
  });

  testWidgets('임피던스: R 30, XL 40, 220 V → 50 Ω, 역률 0.6, 4.4 A, L·C로도 구한다', (tester) async {
    await _open(tester, 'ec_tab_basic');
    await _tap(tester, 'ec_bs_impedance');
    await _type(tester, 'ec_zi_r', '30');
    await _type(tester, 'ec_zi_xl', '40');
    await _type(tester, 'ec_zi_v', '220');
    var t = _all(tester);
    expect(flat(t), contains(flat('= √(30² + 40²) = 50 Ω')));
    expect(flat(t), contains(flat('= 0.6 (60 %)')));
    expect(flat(t), contains(flat('= 4.4 A')));
    // L 100 mH → XL 37.7 Ω
    await _type(tester, 'ec_zi_xl', '');
    await _type(tester, 'ec_zi_l', '100');
    t = _all(tester);
    expect(flat(t), contains(flat('= 37.7 Ω')));
    await _type(tester, 'ec_zi_c', '50');
    expect(_all(tester), contains('용량성'));
  });

  testWidgets('전선 굵기: 풀이에 케이블 임피던스·전력 손실·도체 온도가 나온다', (tester) async {
    await _open(tester, 'ec_tab_cable');
    await _type(tester, 'ec_ib', '100');
    final t = _all(tester);
    expect(t, contains('케이블 임피던스(한 가닥 50 m)'));
    expect(flat(t), contains(flat('케이블 전력 손실 = 도체 수 × I² × R × L = 3 × 100² ')));
    expect(flat(t), contains(flat('도체 온도 ≈ Ta + (Tmax − Ta) × (I ÷ IZ)²')));
    expect(t, contains('(근사식)'));
  });

  testWidgets('접지 TN: C16 220 V, 상·PE 2.5 mm² → 자동 차단 최대 길이', (tester) async {
    await _open(tester, 'ec_tab_ground');
    await _tap(tester, 'gr_mode_tn');
    await _type(tester, 'gr_sph', '2.5');
    await _type(tester, 'gr_spe', '2.5');
    final t = _all(tester);
    expect(t, contains('자동 차단되는 최대 케이블 길이'));
    expect(flat(t), contains(flat('= 76.4 m')));
    await _type(tester, 'gr_ze', '0.4');
    expect(flat(_all(tester)), contains(flat('= 54.2 m')));
  });

  testWidgets('역률 개선: 440 V 20 kvar 콘덴서를 380 V 60 Hz에 → 14.9 kvar (74.6 %)', (tester) async {
    await _open(tester, 'ec_tab_pf');
    await _type(tester, 'ec_cv_q', '20');
    await _type(tester, 'ec_cv_vn', '440');
    await _type(tester, 'ec_cv_v', '380');
    final t = _all(tester);
    expect(flat(t), contains(flat('= 14.92 kvar')));
    expect(t, contains('74.6 %'));
    await _type(tester, 'ec_cv_v', '500');
    expect(_all(tester), contains('110 %를 넘습니다'));
  });
  testWidgets('변압기 역률 개선: 630 kVA 전부하 → 11.34 + 25.2 = 36.5 kvar, 표 L22 값도 보인다', (tester) async {
    await _open(tester, 'ec_tab_pf');
    await _type(tester, 'ec_tp_kva', '630');
    var t = _all(tester);
    expect(flat(t), contains(flat('= 11.34 kvar')));
    expect(flat(t), contains(flat('= 25.2 kvar')));
    expect(flat(t), contains(flat('합계 = 36.54 kvar')));
    expect(t, contains('무부하 11.3 kvar, 전부하 35.7 kvar'));
    await _type(tester, 'ec_tp_load', '50');
    t = _all(tester);
    expect(flat(t), contains(flat('= 6.3 kvar')));
  });

  testWidgets('미네랄 절연 케이블: 750 V 70 °C 벽 3도체 16 mm² = 86 A, 100 A → 25 mm²', (tester) async {
    await _open(tester, 'ec_tab_cable');
    await _type(tester, 'ec_mi_amps', '100');
    var t = _all(tester);
    expect(t, contains('가장 작은 단면적: 25 mm² (허용 112 A)'));
    expect(t, contains('16 mm² : 86 A'));
    await _tap(tester, 'ec_mi_t105');
    await _tap(tester, 'ec_mi_efg');
    await _tap(tester, 'ec_mi_col4');
    t = _all(tester);
    expect(t, contains('10 mm² : 120 A'));
    expect(t, contains('가장 작은 단면적: 10 mm² (허용 120 A)'));
    await _tap(tester, 'ec_mi_500');
    t = _all(tester);
    expect(t, contains('표의 가장 큰 단면적(4 mm², 64 A)으로도 모자랍니다'));
  });
  testWidgets('미네랄 절연 선택은 위쪽 부하 전류를 넣어도 풀리지 않는다', (tester) async {
    await _open(tester, 'ec_tab_cable');
    await _tap(tester, 'ec_mi_t105');
    await _tap(tester, 'ec_mi_efg');
    await _type(tester, 'ec_ib', '100');
    final t = _all(tester);
    expect(t, contains('외피 105 ℃'));
    expect(t, contains('포설 방법 E·F·G'));
  });
}
