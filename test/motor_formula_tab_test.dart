// 전기기기 계산의 "전동기 공식" 탭: 다섯 묶음 입력 → 결과·풀이.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(home: ElectricCalculatorPage(group: ElecGroup.motor)),
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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('첫 탭이 전동기 공식이고, 60 Hz 4극은 동기속도 1800 rpm', (tester) async {
    await _open(tester);
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
    expect(_all(tester), contains('동기속도 Ns = 120 × f ÷ P = 120 × 60 ÷ 4 = 1800 rpm'));
  });

  testWidgets('속도·슬립: 1750 rpm → 슬립 2.78 %, 슬립으로 회전수와 회전자 주파수', (tester) async {
    await _open(tester);
    await _type(tester, 'mf_rpm', '1750');
    expect(_all(tester), contains('= 2.78 %'));
    await _type(tester, 'mf_rpm', '');
    await _type(tester, 'mf_slip', '3');
    final t = _all(tester);
    expect(t, contains('= 1746 rpm'));
    expect(t, contains('f2 = s × f = 0.03 × 60 = 1.8 Hz'));
    // 홀수 극수는 계산하지 않는다
    await _type(tester, 'mf_poles', '3');
    expect(_all(tester), contains('극수는 2 이상 짝수'));
  });

  testWidgets('전류·효율: 11 kW 380 V 효율 90 역률 85 삼상 → 21.8 A, 입력 12.22 kW', (tester) async {
    await _open(tester);
    await _tap(tester, 'mf_sec_current');
    await _type(tester, 'mf_kw', '11');
    await _type(tester, 'mf_eff', '90');
    await _type(tester, 'mf_pf', '85');
    final t = _all(tester);
    expect(t, contains('= 21.8 A'));
    expect(t, contains('입력 전력 P1 = P ÷ η = 11 ÷ 0.9 = 12.22 kW'));
    await _tap(tester, 'mf_ph1');
    expect(_all(tester), isNot(contains('√3 × 380')));
  });

  testWidgets('토크·출력: 11 kW 1750 rpm → 60.02 N·m, 되돌리면 11 kW', (tester) async {
    await _open(tester);
    await _tap(tester, 'mf_sec_torque');
    await _type(tester, 'mf_tkw', '11');
    await _type(tester, 'mf_trpm', '1750');
    final t = _all(tester);
    expect(t, contains('= 60.02 N·m'));
    expect(t, contains('6.12 kgf·m'));
    await _tap(tester, 'mf_t_rev');
    await _type(tester, 'mf_tnm', '60.02');
    expect(_all(tester), contains('= 11 kW'));
  });

  testWidgets('기동 방식: 22 A × 6배, Y-Δ 44 A, 기동보상기 65 % 55.8 A', (tester) async {
    await _open(tester);
    await _tap(tester, 'mf_sec_start');
    await _type(tester, 'mf_rated', '22');
    expect(_all(tester), contains('= 132 A'));
    await _tap(tester, 'mf_k_yd');
    expect(_all(tester), contains('= 44 A'));
    await _tap(tester, 'mf_k_auto');
    final t = _all(tester);
    expect(t, contains('= 55.8 A'));
    expect(t, contains('0.423배'));
    await _type(tester, 'mf_tap', '100');
    expect(_all(tester), contains('100 % 미만'));
  });

  testWidgets('부하율: 18 A / 22 A → 81.8 %, 정격 초과면 붉은 안내', (tester) async {
    await _open(tester);
    await _tap(tester, 'mf_sec_load');
    await _type(tester, 'mf_meas', '18');
    await _type(tester, 'mf_lrated', '22');
    await _type(tester, 'mf_lpf', '80');
    expect(_all(tester), contains('= 81.8 %'));
    await _type(tester, 'mf_meas', '25');
    expect(_all(tester), contains('정격 초과: 과부하'));
  });
}
