// 공식 계산 "배관"(10-09): 물 채움량·배관 무게·열팽창·구배 낙차·원통 탱크(손계산·규격표 대조).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/field_tools/formula_calc_page.dart';
import 'package:tubing_calculator/src/presentation/field_tools/formula_defs.dart';

double _v(String id, Map<String, double> vals) =>
    kFormulas.firstWhere((f) => f.id == id).compute(vals);

void main() {
  test('배관 공식이 맞게 계산된다', () {
    // 2" Sch40(60.3 × 3.91): 안지름 52.48 mm → 1 m에 2.163 L, 10 m에 21.63 L.
    expect(
      _v('pipe_water_volume', {'od': 60.3, 't': 3.91, 'l': 10}),
      closeTo(21.63, 0.01),
    );
    // 1/2" 튜브 12.7 × 1.24, 50 m: 안지름 10.22 → π/4×10.22²×50/1000 = 4.10 L.
    expect(
      _v('pipe_water_volume', {'od': 12.7, 't': 1.24, 'l': 50}),
      closeTo(4.102, 0.001),
    );
    // 두께가 지름의 반을 넘으면 계산하지 않는다.
    expect(_v('pipe_water_volume', {'od': 10, 't': 5, 'l': 1}).isNaN, isTrue);

    // 2" Sch40 탄소강 1 m: 규격표 5.44 kg/m(0.02466 × 3.91 × 56.39 = 5.437).
    expect(
      _v('pipe_weight', {'od': 60.3, 't': 3.91, 'l': 1, 'rho': 7850}),
      closeTo(5.44, 0.01),
    );
    // 6 m 한 본 = 32.6 kg
    expect(
      _v('pipe_weight', {'od': 60.3, 't': 3.91, 'l': 6, 'rho': 7850}),
      closeTo(32.62, 0.02),
    );

    // 탄소강 100 m, 100 °C 오름: 11.7e-6 × 100000 mm × 100 = 117 mm. 식으면 −.
    expect(
      _v('pipe_thermal_expansion', {'alpha': 11.7, 'l': 100, 'dt': 100}),
      closeTo(117, 1e-9),
    );
    expect(
      _v('pipe_thermal_expansion', {'alpha': 17.3, 'l': 30, 'dt': -20}),
      closeTo(-10.38, 1e-9),
    );

    // 10 m, 1% → 100 mm. 25 m, 0.5% → 125 mm.
    expect(_v('pipe_slope_drop', {'l': 10, 'slope': 1}), closeTo(100, 1e-9));
    expect(_v('pipe_slope_drop', {'l': 25, 'slope': 0.5}), closeTo(125, 1e-9));

    // 안지름 2 m, 높이 3 m: π × 3 = 9.4248 m³ = 9424.8 L.
    expect(
      _v('tank_cylinder_volume', {'d': 2, 'h': 3}),
      closeTo(9424.78, 0.01),
    );
  });

  test('배관 칸 단위: 지름·두께는 mm(m·in), 부피는 L(m³), 무게는 kg(t)', () {
    expect(formulaUnitChoices('mm').map((u) => u.label), ['mm', 'm', 'in']);
    expect(formulaUnitChoices('L').map((u) => u.label), ['L', 'm³']);
    expect(formulaUnitChoices('kg').map((u) => u.label), ['kg', 't']);
    expect(kFormulaCategoryIntro['배관'], isNotNull);
  });

  testWidgets('물 채움량: 칸에 넣으면 L로 나오고, m³로 바꿔 볼 수 있다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final def = kFormulas.firstWhere((f) => f.id == 'pipe_water_volume');
    await tester.pumpWidget(MaterialApp(home: FormulaDetailPage(def: def)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('formula_in_od')), '60.3');
    await tester.enterText(find.byKey(const Key('formula_in_t')), '3.91');
    await tester.enterText(find.byKey(const Key('formula_in_l')), '100');
    await tester.pump();
    expect(find.textContaining(RegExp(r'^216\.31\d* L$')), findsOneWidget);
    await tester.tap(find.byKey(const Key('formula_result_unit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('m³').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('0.21631'), findsOneWidget);
  });

  testWidgets('공식 목록에 "배관" 묶음이 보인다', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: FormulaCalcPage()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('formula_pipe_water_volume')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('배관 물 채움량(수압시험)'), findsOneWidget);
  });
}
