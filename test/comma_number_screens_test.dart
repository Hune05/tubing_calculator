// 쉼표 소수점 자판으로 "1,5"를 넣어도 1.5로 읽는다(10-07). 예전에는 유량·압력시험·계기 교정이
// 쉼표를 지워 "1,5"를 15로 읽었고(10배), 공식 계산·단위 환산은 아예 못 읽었다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/field_tools/formula_calc_page.dart';
import 'package:tubing_calculator/src/presentation/field_tools/formula_defs.dart';
import 'package:tubing_calculator/src/presentation/field_tools/mini_unit_converter_page.dart';
import 'package:tubing_calculator/src/presentation/flow/flow_calc_page.dart';

Future<void> _open(WidgetTester t, Widget page) async {
  t.view.physicalSize = const Size(390, 3000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: page));
  await t.pumpAndSettle();
}

Future<void> _type(WidgetTester t, String key, String text) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.enterText(find.byKey(Key(key)), text);
  await t.pump();
}

String _texts(WidgetTester t, String key) => t
    .widgetList<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)))
    .map((w) => w.data ?? '')
    .join(' ');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('유량 계산: 1,5와 1.5가 같은 유속', (t) async {
    await _open(t, const FlowCalcPage());
    await _type(t, 'fv_flow', '1.5');
    final dot = _texts(t, 'fl_vel_result');
    await _type(t, 'fv_flow', '1,5');
    expect(_texts(t, 'fl_vel_result'), dot);
    await _type(t, 'fv_flow', '15');
    expect(_texts(t, 'fl_vel_result'), isNot(dot));
  });

  testWidgets('공식 계산: 전류 0,5 A × 저항 100 Ω = 50 V', (t) async {
    await _open(t, FormulaDetailPage(def: kFormulas.firstWhere((f) => f.id == 'ohm_v')));
    await _type(t, 'formula_in_i', '0,5');
    await _type(t, 'formula_in_r', '100');
    expect(_texts(t, 'formula_result'), contains('50'));
  });

  testWidgets('단위 환산: 1,5 mm는 0.15 cm', (t) async {
    await _open(t, const MiniUnitConverterPage());
    await _type(t, 'unit_from_value', '1,5');
    expect(t.widget<Text>(find.byKey(const Key('unit_to_value'))).data, '0.15');
  });

  testWidgets('공식 계산: 역률 칸에 85를 넣으면 85%(0.85)로 읽고, 150은 입력 확인', (t) async {
    await _open(t, FormulaDetailPage(def: kFormulas.firstWhere((f) => f.id == 'power_3ph')));
    await _type(t, 'formula_in_v', '380');
    await _type(t, 'formula_in_i', '10');
    await _type(t, 'formula_in_pf', '0.85');
    final ratio = _texts(t, 'formula_result');
    await _type(t, 'formula_in_pf', '85');
    final pct = _texts(t, 'formula_result');
    // 줄글(85%로 읽었다는 안내)만 더 붙고 결과 숫자는 같다(약 5,594 W).
    expect(pct, startsWith(ratio.split(' ').first));
    expect(pct, contains('85%(0.85)로 계산했습니다'));
    await _type(t, 'formula_in_pf', '150');
    expect(_texts(t, 'formula_result'), contains('0~1(또는 0~100%)로 넣으십시오'));
  });

  testWidgets('공식 계산: 넣은 값은 화면을 닫았다 열어도 남는다', (t) async {
    final def = kFormulas.firstWhere((f) => f.id == 'ohm_v');
    await _open(t, FormulaDetailPage(def: def));
    await _type(t, 'formula_in_i', '2');
    await _type(t, 'formula_in_r', '50');
    await t.pump(const Duration(milliseconds: 600));
    await t.pumpWidget(const SizedBox());
    await _open(t, FormulaDetailPage(def: def));
    expect(t.widget<TextField>(find.byKey(const Key('formula_in_i'))).controller!.text, '2');
    expect(_texts(t, 'formula_result'), contains('100'));
  });
}
