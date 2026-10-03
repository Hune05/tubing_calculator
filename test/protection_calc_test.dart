// 감전 보호 자동 차단(TN·TT)과 절연저항·절연내력 계산. 값은 현행 KEC 원문(2026.1.5 시행) 211.2·132·133,
// 전기설비기술기준 제52조.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';
import 'package:tubing_calculator/src/presentation/electrical/protection_calc.dart';

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 9000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: ElectricCalculatorPage()));
  await tester.pumpAndSettle();
  final tab = find.byKey(const Key('ec_tab_ground'));
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pumpAndSettle();
}

void main() {
  test('표 211.2-1 최대 차단시간(32 A 이하 분기회로)', () {
    expect(maxDisconnectTime(sys: EarthSystem.tn, u0: 220), 0.4);
    expect(maxDisconnectTime(sys: EarthSystem.tt, u0: 220), 0.2);
    expect(maxDisconnectTime(sys: EarthSystem.tn, u0: 220, dc: true), 5);
    expect(maxDisconnectTime(sys: EarthSystem.tt, u0: 220, dc: true), 0.4);
    expect(maxDisconnectTime(sys: EarthSystem.tn, u0: 100), 0.8);
    expect(maxDisconnectTime(sys: EarthSystem.tn, u0: 100, dc: true), isNull);
    expect(maxDisconnectTime(sys: EarthSystem.tn, u0: 400), 0.2);
    expect(maxDisconnectTime(sys: EarthSystem.tt, u0: 400), 0.07);
    expect(maxDisconnectTime(sys: EarthSystem.tn, u0: 480), 0.1);
    expect(maxDisconnectTime(sys: EarthSystem.tt, u0: 480), 0.04);
    expect(maxDisconnectTime(sys: EarthSystem.tn, u0: 48), isNull);
    expect(distributionDisconnectTime(EarthSystem.tn), 5);
    expect(distributionDisconnectTime(EarthSystem.tt), 1);
  });

  test('Ia와 Zs 최대: C16 220 V → 1.375 Ω', () {
    expect(tripCurrentIa(ProtDevice.b, 16), 80);
    expect(tripCurrentIa(ProtDevice.c, 16), 160);
    expect(tripCurrentIa(ProtDevice.d, 16), 320);
    expect(tripCurrentIa(ProtDevice.setting, 100), closeTo(120, 1e-9));
    expect(tripCurrentIa(ProtDevice.rcd, 0.03), closeTo(0.15, 1e-9));
    expect(maxLoopImpedance(u0: 220, ia: 160), closeTo(1.375, 1e-9));
    expect(maxLoopImpedance(u0: 220, ia: 80), closeTo(2.75, 1e-9));
    // Ze 0.35 + 0.0225 × 30 × (1/2.5 + 1/2.5) = 0.89
    expect(
      estimateLoopImpedance(ze: 0.35, lengthM: 30, phaseMm2: 2.5, peMm2: 2.5),
      closeTo(0.89, 1e-9),
    );
  });

  test('저압 절연저항(제52조)', () {
    expect(lvInsulation(LvCircuit.selvPelv), (testV: 250.0, minMOhm: 0.5));
    expect(lvInsulation(LvCircuit.upTo500), (testV: 500.0, minMOhm: 1.0));
    expect(lvInsulation(LvCircuit.over500), (testV: 1000.0, minMOhm: 1.0));
  });

  test('고압·특고압 전로 절연내력(표 132-1)과 회전기(표 133-1)', () {
    expect(hvTestVoltageKv(HvCircuit.upTo7k, 6.9), closeTo(10.35, 1e-9));
    expect(hvTestVoltageKv(HvCircuit.upTo7k, 8), isNull);
    expect(hvTestVoltageKv(HvCircuit.multiGround7to25, 25.8), isNull);
    expect(hvTestVoltageKv(HvCircuit.multiGround7to25, 24), closeTo(22.08, 1e-9));
    expect(hvTestVoltageKv(HvCircuit.k7to60, 8), 10.5); // 1.25 × 8 = 10 < 10.5
    expect(hvTestVoltageKv(HvCircuit.k7to60, 24), closeTo(30, 1e-9));
    expect(hvTestVoltageKv(HvCircuit.over60Grounded, 66), 75); // 72.6 < 75
    expect(hvTestVoltageKv(HvCircuit.over60Grounded, 161), closeTo(177.1, 1e-9));
    expect(hvTestVoltageKv(HvCircuit.over60Solid, 161), closeTo(115.92, 1e-9));
    expect(hvTestVoltageKv(HvCircuit.over170PlantSolid, 170), isNull);
    expect(hvTestVoltageKv(HvCircuit.over170PlantSolid, 362), closeTo(231.68, 1e-9));
    expect(machineTestVoltageKv(0.22), 0.5); // 0.33 < 0.5
    expect(machineTestVoltageKv(0.44), closeTo(0.66, 1e-9));
    expect(machineTestVoltageKv(6.9), closeTo(10.35, 1e-9));
    expect(machineTestVoltageKv(7.5), 10.5); // 9.375 < 10.5
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('접지 탭 TN 자동 차단: C16·220 V → 1.38 Ω, 측정값 판정', (tester) async {
    await _open(tester);
    await _tap(tester, 'gr_mode_tn');
    expect(find.text('1.38 Ω 이하'), findsOneWidget);
    expect(find.textContaining('최대 차단시간: 0.4초'), findsOneWidget);
    await _type(tester, 'gr_zs', '1.6');
    expect(find.textContaining('불합격'), findsOneWidget);
    await _type(tester, 'gr_zs', '0.9');
    expect(find.textContaining(': 합격'), findsOneWidget);
    await _tap(tester, 'gr_feeder');
    expect(find.textContaining('최대 차단시간: 5초'), findsOneWidget);
    await _tap(tester, 'gr_dev_b');
    expect(find.text('2.75 Ω 이하'), findsOneWidget);
  });

  testWidgets('접지 탭 절연: 저압 1 MΩ 판정, 고압 내력, 회전기', (tester) async {
    await _open(tester);
    await _tap(tester, 'gr_mode_insulation');
    expect(find.text('1 MΩ 이상'), findsOneWidget);
    expect(find.textContaining('시험전압 DC 500 V'), findsOneWidget);
    await _type(tester, 'gr_megger', '0.4');
    expect(find.textContaining('불합격'), findsOneWidget);
    await _tap(tester, 'gr_ins_hv');
    expect(find.text('10.35 kV'), findsOneWidget); // 6.9 × 1.5
    await _tap(tester, 'gr_hv_k7to60');
    expect(find.textContaining('범위를 벗어났습니다'), findsOneWidget);
    await _type(tester, 'gr_vmax', '24');
    expect(find.text('30 kV'), findsOneWidget);
    await _tap(tester, 'gr_ins_mc');
    expect(find.text('660 V'), findsOneWidget);
  });
}
