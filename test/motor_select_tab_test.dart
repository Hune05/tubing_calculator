// 전동기·발전기 계산: 전동기 공식 추가 묶음(전압·역률 구하기, 전부하 전류 표)과 전동기 선정 탭.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';
import 'formula_flat.dart';

Future<void> _open(WidgetTester tester, {int tab = 14}) async {
  tester.view.physicalSize = const Size(800, 7000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: ElectricCalculatorPage(initialTab: tab)),
  );
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
  setUpAll(expandFormulaCards);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('전압 구하기: 11 kW, 21.85 A, 효율 90, 역률 85 삼상 → 380 V', (tester) async {
    await _open(tester);
    await _tap(tester, 'mf_sec_current');
    await _tap(tester, 'mf_s_voltage');
    await _type(tester, 'mf_kw', '11');
    await _type(tester, 'mf_amps', '21.847');
    await _type(tester, 'mf_eff', '90');
    await _type(tester, 'mf_pf', '85');
    expect(_all(tester), contains('= 380.0 V'.replaceAll('.0', '')));
    expect(find.byKey(const Key('mf_v')), findsNothing, reason: '전압을 구할 때는 전압 칸이 없다');
  });

  testWidgets('역률 구하기: 전력계 입력 전력 9.5 kW, 380 V, 18 A → 0.80', (tester) async {
    await _open(tester);
    await _tap(tester, 'mf_sec_current');
    await _tap(tester, 'mf_s_pf');
    await _tap(tester, 'mf_p_in');
    await _type(tester, 'mf_kw', '9.5');
    await _type(tester, 'mf_amps', '18');
    // 9500 ÷ (√3 × 380 × 18) = 0.8019
    final t = _all(tester);
    expect(flat(t), contains(flat('= 0.802 (80.2 %)')));
    expect(find.byKey(const Key('mf_eff')), findsNothing, reason: '입력 전력 기준이면 효율이 필요 없다');
    // 서로 안 맞는 값
    await _type(tester, 'mf_kw', '20');
    expect(_all(tester), contains('역률이 1을 넘습니다'));
  });

  testWidgets('전부하 전류 표: NEC 10 HP 230 V 28 A·460 V 14 A, IE3 11 kW 380 V 22.2 A', (tester) async {
    await _open(tester);
    await _tap(tester, 'mf_sec_flc');
    var t = _all(tester);
    expect(t, contains('230 V: 28 A, 460 V: 14 A'));
    expect(t, contains('NEC 430.6(A)(1)'));
    await _tap(tester, 'mf_flc_ie3');
    t = _all(tester);
    expect(t, contains('380 V: 22.2 A, 440 V: 19.2 A'));
    expect(t, contains('명판 값을 쓰십시오'));
  });

  testWidgets('펌프 동력: 60 m³/h, 30 m, 효율 70 %, 여유 15 % → 8.06 kW → 11 kW 올림', (tester) async {
    await _open(tester, tab: 15);
    await _type(tester, 'ms_flow', '60');
    await _type(tester, 'ms_head', '30');
    await _type(tester, 'ms_eff', '70');
    await _type(tester, 'ms_margin', '15');
    final t = _all(tester);
    expect(t, contains('수동력'));
    expect(flat(t), contains(flat('= 4.9 kW')));
    expect(flat(t), contains(flat('= 7 kW')));
    expect(flat(t), contains(flat('= 8.06 kW')));
    expect(t, contains('올림: 11 kW'));
  });

  testWidgets('팬 동력: 7200 m³/h, 1200 Pa, 효율 65 %', (tester) async {
    await _open(tester, tab: 15);
    await _tap(tester, 'ms_fan');
    await _type(tester, 'ms_flow', '7200');
    await _type(tester, 'ms_head', '1200');
    await _type(tester, 'ms_eff', '65');
    final t = _all(tester);
    expect(t, contains('공기동력'));
    expect(flat(t), contains(flat('= 2.4 kW')));
    expect(flat(t), contains(flat('= 3.69 kW')));
  });

  testWidgets('상사법칙: 1800 → 1500 rpm, 동력 11 kW → 6.37 kW (57.9 %)', (tester) async {
    await _open(tester, tab: 15);
    await _tap(tester, 'ms_sec_affinity');
    await _type(tester, 'ms_n1', '1800');
    await _type(tester, 'ms_n2', '1500');
    await _type(tester, 'ms_p1', '11');
    await _type(tester, 'ms_q1', '100');
    final t = _all(tester);
    expect(flat(t), contains(flat('r = N2 ÷ N1 = 1500 ÷ 1800 = 0.833')));
    expect(flat(t), contains(flat('= 6.37 (57.9 %)')));
    expect(flat(t), contains(flat('= 83.33')));
  });

  testWidgets('가속 시간: 11 kW 1750 rpm, 전동기 150 %, 부하 50 %, J 0.2 + 부하 1.5 → 시간과 기동 불가 경고', (tester) async {
    await _open(tester, tab: 15);
    await _tap(tester, 'ms_sec_accel');
    await _type(tester, 'ms_mkw', '11');
    await _type(tester, 'ms_mrpm', '1750');
    await _type(tester, 'ms_avgm', '150');
    await _type(tester, 'ms_avgl', '50');
    await _type(tester, 'ms_jm', '0.2');
    await _type(tester, 'ms_jl', '1.5');
    // T정격 60.0 N·m, 가속 토크 60.0 N·m(= 90 − 30), J 1.7, ω 183.26 → 1.7 × 183.26 ÷ 60.02 = 5.19 s
    var t = _all(tester);
    expect(flat(t), contains(flat('가속 토크 Ta = 90')));
    expect(flat(t), contains(flat('= 5.19 초')));
    await _type(tester, 'ms_avgl', '160');
    expect(_all(tester), contains('기동(가속)하지 못합니다'));
  });
}
