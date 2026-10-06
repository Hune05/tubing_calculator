// 전동기·발전기 계산: 콘덴서·단상 탭과 전동기 공식 탭의 최대 토크 묶음.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';
import 'formula_flat.dart';

Future<void> _open(WidgetTester tester, int tab) async {
  tester.view.physicalSize = const Size(800, 7000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: ElectricCalculatorPage(initialTab: tab)));
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

  testWidgets('콘덴서 한도: I0 10 A, 400 V → 6.24 kvar, 추정 I0, 계전기 보정, 도표 L24', (tester) async {
    await _open(tester, 16);
    await _type(tester, 'mc_volts', '400');
    await _type(tester, 'mc_i0', '10');
    var t = _all(tester);
    expect(flat(t), contains(flat('= 6.24 kvar')));
    expect(t, contains('자기여자'));
    // 정격값으로 추정: 41 A, cosφ 85 → I0 12.3 A, 380 V → 0.9 × 12.3 × 0.38 × √3 = 7.29 kvar
    await _tap(tester, 'mc_i0_est');
    await _type(tester, 'mc_in', '41');
    await _type(tester, 'mc_inpf', '85');
    await _type(tester, 'mc_volts', '380');
    t = _all(tester);
    expect(flat(t), contains(flat('= 12.3 A')));
    expect(flat(t), contains(flat('= 7.29 kvar')));
    // 계전기 보정
    await _type(tester, 'mc_set', '40');
    await _type(tester, 'mc_pf1', '80');
    await _type(tester, 'mc_pf2', '95');
    expect(flat(_all(tester)), contains(flat('= 33.7 A로 낮춥니다')));
    // 도표 L24·L25
    await _tap(tester, 'mc_rpm_1500');
    await _type(tester, 'mc_tkw', '22');
    t = _all(tester);
    expect(t, contains('최대 8 kvar'));
    expect(t, contains('1500 rpm 0.91 → 설정 36.4 A'));
    await _type(tester, 'mc_tkw', '23');
    expect(_all(tester), contains('행이 없습니다'));
  });

  testWidgets('3상 모터 단상 운전: 1.5 kW 220 V 60 Hz → 94.9 μF, 기동 2~3배, 출력 70~80 %', (tester) async {
    await _open(tester, 16);
    await _tap(tester, 'mc2_sec_steinmetz');
    await _type(tester, 'mc_skw', '1.5');
    final t = _all(tester);
    // 1.5 × 63.28 = 94.9
    expect(flat(t), contains(flat('= 94.9 μF (63.3 μF/kW)')));
    expect(t, contains('190~285 μF'));
    expect(t, contains('1.05~1.2 kW'));
    expect(t, isNot(contains('소형 한도(2.2 kW 미만)를 넘습니다')));
    await _type(tester, 'mc_skw', '3');
    expect(_all(tester), contains('소형 한도(2.2 kW 미만)를 넘습니다'));
  });

  testWidgets('단상 모터 콘덴서: 1.1 kW → 22~55 μF, 달린 100 μF 220 V 60 Hz → 8.29 A', (tester) async {
    await _open(tester, 16);
    await _tap(tester, 'mc2_sec_single');
    await _type(tester, 'mc_pkw', '1.1');
    var t = _all(tester);
    expect(flat(t), contains(flat('= 22~55 μF')));
    expect(t, contains('명판이나 제조사가 정한 용량을 우선'));
    await _type(tester, 'mc_have', '100');
    t = _all(tester);
    expect(flat(t), contains(flat('= 8.29 A')));
    expect(flat(t), contains(flat('= 1.825 kvar')));
  });

  testWidgets('최대 토크: 11 kW 1750 rpm 배수 2.3 → 138 N·m, 90 % 전압 111.8 N·m, IEC·NEMA 최소값', (tester) async {
    await _open(tester, 14);
    await _tap(tester, 'mf_sec_maxTorque');
    await _type(tester, 'mf_xkw', '11');
    await _type(tester, 'mf_xrpm', '1750');
    await _type(tester, 'mf_xmult', '2.3');
    await _type(tester, 'mf_xvolt', '90');
    var t = _all(tester);
    expect(t, contains('= 60 N·m'.replaceAll('= 60', '= 60')) /* 정격 토크 60.0 */);
    expect(t, contains('= 138 N·m').or(contains('= 138.1 N·m')));
    expect(t, contains('81 %'));
    // IEC 설계 N: 11 kW 4극 → 2.0배
    expect(t, contains('정격 토크의 2배 이상'));
    await _tap(tester, 'mf_x_nema');
    t = _all(tester);
    // 11 kW = 14.75 hp → 10~125 hp 행 200 %
    expect(t, contains('정격 토크의 200 % 이상'));
    await _type(tester, 'mf_xkw', '3');
    expect(_all(tester), contains('확인하지 못했습니다'), reason: '4 hp는 표에서 읽은 행이 아니다');
  });
}

extension on Matcher {
  Matcher or(Matcher other) => anyOf(this, other);
}
