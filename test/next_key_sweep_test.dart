// 칸이 많은 화면마다 첫 칸에서 키보드 "다음"을 끝까지 눌러 본다(앱 전체 순서 규칙 TextFieldsOnlyTraversalPolicy).
// 확인: 보이는 글자 칸을 하나도 빠뜨리거나 두 번 가지 않고, 마지막 칸 뒤에는 키보드가 닫힌다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/common_widgets/text_fields_traversal.dart';
import 'package:tubing_calculator/src/data/record_sync.dart';
import 'package:tubing_calculator/src/presentation/alignment/alignment_page.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_bend_page.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_ground_page.dart';
import 'package:tubing_calculator/src/presentation/electrical/cable_tray_page.dart';
import 'package:tubing_calculator/src/presentation/electrical/cable_tray_route_page.dart';
import 'package:tubing_calculator/src/presentation/electrical/panel_design_page.dart';
import 'package:tubing_calculator/src/presentation/flow/flow_calc_page.dart';
import 'package:tubing_calculator/src/presentation/instrument/signal_calculator_page.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_test_page.dart';
import 'package:tubing_calculator/src/presentation/unit_converter/unit_converter_page.dart';

/// 지금 "다음"으로 갈 수 있는 글자 칸(화면에 있고, 읽기 전용이 아니고, 접힌 구역에 들지 않은 것).
List<EditableText> _fields(WidgetTester tester) => tester
    .widgetList<EditableText>(find.byType(EditableText))
    .where(
      (e) =>
          !e.readOnly &&
          e.focusNode.canRequestFocus &&
          e.focusNode.ancestors.every((a) => a.descendantsAreFocusable),
    )
    .toList();

String _name(WidgetTester tester, EditableText e) {
  final tf = find.ancestor(
    of: find.byWidget(e),
    matching: find.byType(TextField),
  );
  if (tf.evaluate().isNotEmpty) {
    final w = tester.widget<TextField>(tf.first);
    final k = w.key;
    if (k is ValueKey) return '${k.value}';
    return w.decoration?.labelText ?? w.decoration?.hintText ?? '?';
  }
  return '?';
}

/// 첫 칸에 초점을 두고 "다음"을 끝까지 누른 순서. 끝에 키보드가 닫혔으면 마지막에 '(닫힘)'.
Future<List<String>> _sweep(WidgetTester tester) async {
  final fields = _fields(tester);
  expect(fields, isNotEmpty);
  fields.first.focusNode.requestFocus();
  await tester.pump();
  final order = <String>[];
  for (var i = 0; i < 120; i++) {
    final now = _fields(tester).where((e) => e.focusNode.hasFocus).toList();
    if (now.isEmpty) {
      order.add('(닫힘)');
      break;
    }
    order.add(_name(tester, now.single));
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
  }
  return order;
}

void _check(WidgetTester tester, String where, List<String> order, int count) {
  final visited = order.where((s) => s != '(닫힘)').toList();
  // ignore: avoid_print
  print('$where (${visited.length}/$count): ${order.join(' → ')}');
  expect(order.last, '(닫힘)', reason: '$where: 마지막 칸 뒤 키보드가 닫혀야 함');
  expect(visited.length, count, reason: '$where: 빠뜨린 칸이나 두 번 간 칸');
  expect(visited.toSet().length, visited.length, reason: '$where: 같은 칸을 두 번');
}

Widget _app(Widget home) => MaterialApp(
  builder: (context, child) => FocusTraversalGroup(
    policy: TextFieldsOnlyTraversalPolicy(),
    child: child!,
  ),
  home: home,
);

Future<void> _open(WidgetTester tester, Widget page, {double w = 390}) async {
  tester.view.physicalSize = Size(w, 9000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(page));
  await tester.pumpAndSettle();
}

Future<void> _tab(WidgetTester tester, String key) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> _run(
  WidgetTester tester,
  String where, {
  bool Function(String name)? skipped,
}) async {
  final count = _fields(
    tester,
  ).where((e) => skipped == null || !skipped(_name(tester, e))).length;
  _check(tester, where, await _sweep(tester), count);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    recordRemote = () => null;
  });

  testWidgets('압력 시험', (tester) async {
    await _open(tester, const PressureTestPage());
    await _run(tester, '압력 시험');
  });

  testWidgets('축 정렬 계산', (tester) async {
    await _open(tester, AlignmentPage(share: (_) async {}), w: 700);
    await _run(tester, '축 정렬');
  });

  testWidgets('케이블 트레이 규격 선정', (tester) async {
    await _open(tester, const CableTrayPage(), w: 400);
    await _run(tester, '트레이 규격');
  });

  testWidgets('케이블 트레이 가공', (tester) async {
    await _open(tester, const CableTrayRoutePage(), w: 400);
    await _run(tester, '트레이 가공');
  });

  testWidgets('부스바 가공', (tester) async {
    await _open(tester, const BusbarBendPage(), w: 400);
    await _run(tester, '부스바');
  });

  testWidgets('접지바 가공', (tester) async {
    await _open(tester, const GroundBarPage(), w: 400);
    await _run(tester, '접지바');
  });

  testWidgets('유량 계산 탭 4개', (tester) async {
    await _open(tester, const FlowCalcPage());
    await _run(tester, '유량: 유속·관경');
    for (final t in ['fl_tab_dp', 'fl_tab_meter', 'fl_tab_check']) {
      await _tab(tester, t);
      await _run(tester, '유량: $t');
    }
  });

  testWidgets('단위 환산', (tester) async {
    await _open(tester, const UnitConverterPage());
    await _run(tester, '단위 환산');
  });

  testWidgets('계기 교정 탭 5개', (tester) async {
    await _open(tester, const SignalCalculatorPage());
    // 교정 점검은 '다음'이 지시값 칸끼리 이어지게 따로 짰다(가한 값 2번째부터는 기본값이 들어 있어 건너뜀).
    await _run(
      tester,
      '계기: 교정 점검',
      skipped: (n) => RegExp(r'^sc_applied_[1-9]').hasMatch(n),
    );
    for (final t in [
      'sg_tab_conv',
      'sg_tab_temp',
      'sg_tab_gas',
      'sg_tab_loop',
    ]) {
      await _tab(tester, t);
      await _run(tester, '계기: $t');
    }
  });

  testWidgets('분전반·조명 탭 4개', (tester) async {
    await _open(tester, const PanelDesignPage(), w: 400);
    await _run(tester, '분전반: 조명');
    for (final t in ['pd_tab_balance', 'pd_tab_feeder', 'pd_tab_branch']) {
      await _tab(tester, t);
      await _run(tester, '분전반: $t');
    }
  });
}
