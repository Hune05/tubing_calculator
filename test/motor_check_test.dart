// 전동기 점검: 절연저항(IEEE 43·IEC 60034-27-4), 권선 저항 불평형(EASA AR100), 전압 불평형(NEMA MG1).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';
import 'package:tubing_calculator/src/presentation/electrical/motor_check.dart';
import 'formula_flat.dart';

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(expandFormulaCards);
  test('시험전압(IEEE 43 표 1)', () {
    expect(megTestVoltage(380), (500.0, 500.0));
    expect(megTestVoltage(440), (500.0, 500.0));
    expect(megTestVoltage(2400), (500.0, 1000.0));
    expect(megTestVoltage(3300), (1000.0, 2500.0));
    expect(megTestVoltage(6600), (2500.0, 5000.0));
    expect(megTestVoltage(13800), isNull);
  });

  test('40 ℃ 환산: IEEE 43은 10 ℃마다 절반, IEC 합성수지는 40 ℃ 이하 그대로', () {
    expect(irAt40(measuredMOhm: 100, tempC: 20), closeTo(25, 1e-9));
    expect(irAt40(measuredMOhm: 100, tempC: 40), closeTo(100, 1e-9));
    expect(irAt40(measuredMOhm: 100, tempC: 50), closeTo(200, 1e-9));
    expect(
      irAt40(measuredMOhm: 100, tempC: 20, method: IrCorrection.iecResin),
      100,
    );
    expect(
      irAt40(measuredMOhm: 100, tempC: 57, method: IrCorrection.iecResin),
      closeTo(200, 1e-9),
    );
    expect(irAt40(measuredMOhm: 6000, tempC: 20), 6000); // 5 GΩ 초과는 보정 안 함
  });

  test('최소값·PI', () {
    expect(minIrMOhm(WindingKind.random), 5);
    expect(minIrMOhm(WindingKind.form), 100);
    expect(minIrMOhm(WindingKind.old, ratedKv: 6.6), closeTo(7.6, 1e-9));
    expect(polarizationIndex(100, 250), 2.5);
    expect(polarizationIndex(6000, 9000), isNull);
    expect(minPi(classA: true), 1.5);
    expect(minPi(classA: false), 2.0);
  });

  test('불평형·권선 저항 온도 환산·NEMA 저감', () {
    // 평균 1.0, 가장 먼 차 0.03 → 3 %
    expect(unbalancePct(1.0, 1.03, 0.97), closeTo(3, 1e-9));
    expect(unbalancePct(0, 1, 1), isNull);
    expect(windingUnbalanceLimit(WindingKind.random), 2);
    expect(windingUnbalanceLimit(WindingKind.form), 1);
    // 20 ℃ 1.000 Ω → 75 ℃: (75 + 234.5)/(20 + 234.5) = 1.2161
    expect(
      windingResistanceAt(ohms: 1, fromC: 20, toC: 75),
      closeTo(1.21611, 1e-4),
    );
    expect(nemaDerating(0.5), 1.0);
    expect(nemaDerating(2), closeTo(0.95, 1e-9));
    expect(nemaDerating(2.5), closeTo(0.915, 1e-9));
    expect(nemaDerating(6), isNull);
    expect(unbalanceHeatingPct(2), 8);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('전동기 점검 탭: 값을 넣으면 과정과 판정이 나온다', (tester) async {
    tester.view.physicalSize = const Size(800, 12000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: ElectricCalculatorPage(initialTab: 13)),
    );
    await tester.pumpAndSettle();
    expect(find.text('점검 순서'), findsOneWidget);
    expect(find.textContaining('시험전압: DC 500 V'), findsOneWidget);

    await _type(tester, 'mc_ir1', '12');
    // 20 ℃ 12 MΩ → 40 ℃ 3 MΩ < 5 MΩ: 불합격
    expect(find.text('3 MΩ (40 ℃)'), findsOneWidget);
    expect(allFlat(tester), contains(flat('12 × 0.5^((40 − 20) ÷ 10) = 3 MΩ')));
    expect(find.textContaining('불합격'), findsWidgets);
    expect(find.byKey(const Key('mc_sum')), findsOneWidget);
    expect(find.textContaining('소손·열화 의심'), findsOneWidget);

    await _type(tester, 'mc_ir1', '80');
    expect(find.text('20 MΩ (40 ℃)'), findsOneWidget);
    expect(find.textContaining('20 ≥ 5 MΩ: 합격'), findsOneWidget);

    await _type(tester, 'mc_r1', '1.00');
    await _type(tester, 'mc_r2', '1.01');
    await _type(tester, 'mc_r3', '0.99');
    expect(find.text('불평형 1 %'), findsOneWidget);
    expect(find.textContaining('허용 2 % 이내: 합격'), findsOneWidget);
    expect(find.textContaining('이상 없음'), findsOneWidget);

    await _type(tester, 'mc_v1', '380');
    await _type(tester, 'mc_v2', '390');
    await _type(tester, 'mc_v3', '370');
    expect(find.textContaining('전압 불평형 2.63 %'), findsOneWidget);
    expect(allFlat(tester), contains(flat('평균 = (380 + 390 + 370) ÷ 3 = 380 V, 차 10 ÷ 380 × 100 = 2.63 %')));
    expect(allFlat(tester), contains(flat('2 × 2.63² = 13.')));
  });
}
