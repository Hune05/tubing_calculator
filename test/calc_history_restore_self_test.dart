// 화면 하나짜리 계산기(공식 계산·단위 환산·유량 계산)도 최근 계산 기록을 눌러 그때 입력값으로 되돌린다(10-07).
// 앱을 다시 연 뒤(화면을 닫았다 열어도) 되돌아가는지, "원래대로"로 누르기 전 값에 돌아가는지 본다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/common_widgets/recent_calc_history.dart';
import 'package:tubing_calculator/src/presentation/field_tools/formula_calc_page.dart';
import 'package:tubing_calculator/src/presentation/field_tools/formula_defs.dart';
import 'package:tubing_calculator/src/presentation/field_tools/mini_unit_converter_page.dart';
import 'package:tubing_calculator/src/presentation/flow/flow_calc_page.dart';

String _text(WidgetTester t, String key) =>
    t.widget<TextField>(find.byKey(Key(key))).controller!.text;

Future<void> _type(WidgetTester t, String key, String text) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.enterText(find.byKey(Key(key)), text);
  await t.pump();
  await t.pump(const Duration(milliseconds: 800));
}

Future<void> _open(WidgetTester t, Widget page) async {
  t.view.physicalSize = const Size(390, 3000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: page));
  await t.pumpAndSettle();
}

Future<void> _close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

Future<void> _tapHistory(WidgetTester t, String text) async {
  await t.tap(find.byKey(const Key('calc_history_button')));
  await t.pumpAndSettle();
  await t.tap(find.textContaining(text).last);
  await t.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RecentCalcLog.now = DateTime.now;
  });

  testWidgets('공식 계산: 다시 연 뒤 기록을 누르면 그때 입력값, 원래대로를 누르면 누르기 전 값', (t) async {
    final def = kFormulas.firstWhere((f) => f.id == 'ohm_v');
    await _open(t, FormulaDetailPage(def: def));
    await _type(t, 'formula_in_i', '2');
    await _type(t, 'formula_in_r', '50');
    await _close(t);
    await _open(t, FormulaDetailPage(def: def));
    await _type(t, 'formula_in_i', '3');
    await _tapHistory(t, '→ 100');
    expect(_text(t, 'formula_in_i'), '2');
    expect(_text(t, 'formula_in_r'), '50');
    await t.tap(find.text('원래대로'));
    await t.pumpAndSettle();
    expect(_text(t, 'formula_in_i'), '3');
  });

  testWidgets('단위 환산: 다시 연 뒤 기록을 누르면 그때 값·단위로 돌아간다', (t) async {
    await _open(t, const MiniUnitConverterPage());
    await _type(t, 'unit_from_value', '1000');
    await t.ensureVisible(find.byKey(const Key('unit_swap')));
    await t.tap(find.byKey(const Key('unit_swap')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 800));
    await _close(t);
    await _open(t, const MiniUnitConverterPage());
    await _type(t, 'unit_from_value', '5');
    // 맞바꾼 뒤의 기록(1000 cm → 10000 mm)이 새로 넣은 5 아래에 있다.
    await t.tap(find.byKey(const Key('calc_history_button')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('calc_history_item_1')));
    await t.pumpAndSettle();
    expect(_text(t, 'unit_from_value'), '1000');
    expect(t.widget<Text>(find.byKey(const Key('unit_to_value'))).data, '10000');
  });

  testWidgets('유량 계산: 다시 연 뒤 기록을 누르면 그때 유량으로 돌아간다', (t) async {
    await _open(t, const FlowCalcPage());
    await _type(t, 'fv_flow', '30');
    await _close(t);
    await _open(t, const FlowCalcPage());
    await _type(t, 'fv_flow', '45');
    await t.tap(find.byKey(const Key('calc_history_button')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('calc_history_item_1')));
    await t.pumpAndSettle();
    expect(_text(t, 'fv_flow'), '30');
  });
}
