// "최근 계산 기록"을 눌러 그때 입력값으로 되돌리기: 전동기 탭 셋(콘덴서·단상, 구동·효율, 선정)과
// 분전반·조명 탭 넷(조명, 상 평형, 간선 전압강하, 분기회로 수).
// 값을 넣고 칩을 바꾼 뒤 입력 묶음을 받아 두고, 값을 바꾼 다음 되돌려 칸·칩·결과가 그때와 같은지,
// "원래대로"를 누르면 바꾼 값으로 다시 돌아오는지 본다.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_motor_capacitor_tab.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_motor_misc_tab.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_motor_select_tab.dart';
import 'package:tubing_calculator/src/presentation/electrical/panel_design_page.dart';
import 'formula_flat.dart';

Future<void> _open(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}

Widget _tab(Widget body) => Scaffold(body: body);

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

/// 결과 카드 안의 글자 전부.
String _res(WidgetTester tester, String key) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(Text, skipOffstage: false),
        skipOffstage: false,
      ),
    )
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join('\n');

String _field(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

dynamic _state(WidgetTester tester, Finder owner) => tester.state(owner) as dynamic;

String _snapRaw(WidgetTester tester, Finder owner) =>
    jsonEncode(_state(tester, owner).historySnapshot());

Finder _private(String name) =>
    find.byWidgetPredicate((w) => w.runtimeType.toString() == name);

/// 되돌리기 → 그때 묶음·결과와 같은지 → "원래대로" → 바꾼 묶음·결과와 같은지.
Future<void> _restoreAndUndo(
  WidgetTester tester, {
  required Finder owner,
  required String resultKey,
  required String raw,
  required String result,
  required Future<void> Function() change,
  Future<void> Function()? checkRestored,
  Future<void> Function()? checkChanged,
}) async {
  await change();
  final changedRaw = _snapRaw(tester, owner);
  final changedResult = _res(tester, resultKey);
  expect(changedRaw, isNot(raw), reason: '바꾼 뒤 입력 묶음이 달라야 한다');
  expect(changedResult, isNot(result), reason: '바꾼 뒤 결과가 달라야 한다');

  _state(tester, owner).restoreElecHistory('x', raw);
  await tester.pumpAndSettle();
  expect(_snapRaw(tester, owner), raw);
  expect(_res(tester, resultKey), result);
  await checkRestored?.call();

  expect(find.text('원래대로'), findsOneWidget);
  await tester.tap(find.text('원래대로'));
  await tester.pumpAndSettle();
  expect(_snapRaw(tester, owner), changedRaw);
  expect(_res(tester, resultKey), changedResult);
  await checkChanged?.call();
}

void main() {
  setUpAll(expandFormulaCards);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('콘덴서·단상: 추정 I0·회전수 칩·칸 값이 되돌아온다', (tester) async {
    await _open(tester, _tab(const ElecMotorCapacitorTab()));
    final owner = find.byType(ElecMotorCapacitorTab);
    await _tap(tester, 'mc_i0_est');
    await _type(tester, 'mc_in', '41');
    await _type(tester, 'mc_inpf', '85');
    await _type(tester, 'mc_set', '40');
    await _type(tester, 'mc_pf1', '80');
    await _type(tester, 'mc_pf2', '95');
    await _tap(tester, 'mc_rpm_1500');
    await _type(tester, 'mc_tkw', '22');
    final result = _res(tester, 'mc2_result');
    expect(flat(result), contains(flat('= 7.29 kvar')));
    final snap = _state(tester, owner).historySnapshot() as Map<String, Object?>;
    expect(snap['estI0'], true);
    expect(snap['rpm'], 1500);
    final raw = jsonEncode(snap);

    await _restoreAndUndo(
      tester,
      owner: owner,
      resultKey: 'mc2_result',
      raw: raw,
      result: result,
      change: () async {
        await _tap(tester, 'mc_i0_direct');
        await _type(tester, 'mc_i0', '10');
        await _tap(tester, 'mc_rpm_1500'); // 회전수 고르기 풀기(null)
        await _tap(tester, 'mc2_sec_single');
        await _type(tester, 'mc_pkw', '1.1');
      },
      checkRestored: () async {
        expect(find.byKey(const Key('mc_in')), findsOneWidget, reason: '추정 칸이 다시 보여야 한다');
        expect(_field(tester, 'mc_in'), '41');
        expect(_field(tester, 'mc_tkw'), '22');
        expect(find.byKey(const Key('mc_pkw')), findsNothing);
      },
      checkChanged: () async {
        expect(find.byKey(const Key('mc_pkw')), findsOneWidget);
        expect(_field(tester, 'mc_pkw'), '1.1');
      },
    );
  });

  testWidgets('구동·효율: 묶음·컨베이어 칩·절연 등급·칸 값이 되돌아온다', (tester) async {
    await _open(tester, _tab(const ElecMotorMiscTab()));
    final owner = find.byType(ElecMotorMiscTab);
    await _tap(tester, 'mm_sec_load');
    await _tap(tester, 'mm_conv');
    await _type(tester, 'mm_lm', '1000');
    await _type(tester, 'mm_lv', '0.5');
    await _type(tester, 'mm_lmu', '0.03');
    await _type(tester, 'mm_lang', '5');
    await _type(tester, 'mm_leff', '85');
    final result = _res(tester, 'mm_result');
    expect(result, contains('kW'));
    final snap = _state(tester, owner).historySnapshot() as Map<String, Object?>;
    expect(snap['sec'], 'load');
    expect(snap['conv'], true);
    final raw = jsonEncode(snap);

    await _restoreAndUndo(
      tester,
      owner: owner,
      resultKey: 'mm_result',
      raw: raw,
      result: result,
      change: () async {
        await _tap(tester, 'mm_hoist');
        await _type(tester, 'mm_lm', '2000');
        await _tap(tester, 'mm_sec_insul');
        await _tap(tester, 'mm_cls_H');
        await _type(tester, 'mm_irise', '90');
      },
      checkRestored: () async {
        expect(find.byKey(const Key('mm_lmu')), findsOneWidget, reason: '컨베이어 칸이 다시 보여야 한다');
        expect(_field(tester, 'mm_lm'), '1000');
        expect(_field(tester, 'mm_lang'), '5');
      },
      checkChanged: () async {
        expect(find.byKey(const Key('mm_irise')), findsOneWidget);
        expect(_field(tester, 'mm_irise'), '90');
        final s = _state(tester, owner).historySnapshot() as Map<String, Object?>;
        expect(s['cls'], 'H');
        expect(s['conv'], false);
      },
    );
  });

  testWidgets('전동기 선정: 팬 칩·GD² 칩·칸 값이 되돌아온다', (tester) async {
    await _open(tester, _tab(const ElecMotorSelectTab()));
    final owner = find.byType(ElecMotorSelectTab);
    await _tap(tester, 'ms_fan');
    await _type(tester, 'ms_flow', '600');
    await _type(tester, 'ms_head', '1000');
    await _type(tester, 'ms_eff', '70');
    await _type(tester, 'ms_margin', '10');
    final result = _res(tester, 'ms_result');
    expect(result, contains('kW'));
    final raw = _snapRaw(tester, owner);
    expect(jsonDecode(raw)['fan'], true);

    await _restoreAndUndo(
      tester,
      owner: owner,
      resultKey: 'ms_result',
      raw: raw,
      result: result,
      change: () async {
        await _tap(tester, 'ms_pump');
        await _type(tester, 'ms_head', '30');
        await _tap(tester, 'ms_sec_accel');
        await _tap(tester, 'ms_gd2');
        await _type(tester, 'ms_mkw', '11');
        await _type(tester, 'ms_mrpm', '1750');
        await _type(tester, 'ms_avgm', '150');
        await _type(tester, 'ms_avgl', '50');
        await _type(tester, 'ms_jm', '0.4');
      },
      checkRestored: () async {
        expect(find.byKey(const Key('ms_density')), findsNothing, reason: '팬이면 밀도 칸이 없다');
        expect(_field(tester, 'ms_head'), '1000');
        expect(_field(tester, 'ms_flow'), '600');
      },
      checkChanged: () async {
        expect(_field(tester, 'ms_jm'), '0.4');
        expect(jsonDecode(_snapRaw(tester, owner))['gd2'], true);
      },
    );
  });

  testWidgets('조명: 칸 값이 되돌아온다', (tester) async {
    await _open(tester, const PanelDesignPage());
    final owner = _private('_LightingTab');
    await _type(tester, 'pd_lux', '500');
    await _type(tester, 'pd_x', '10');
    await _type(tester, 'pd_y', '5');
    await _type(tester, 'pd_h', '2.5');
    await _type(tester, 'pd_lm', '3000');
    await _type(tester, 'pd_u', '0.6');
    await _type(tester, 'pd_m', '80');
    final result = _res(tester, 'pd_light_result');
    expect(result, contains('18개'));
    final raw = _snapRaw(tester, owner);

    await _restoreAndUndo(
      tester,
      owner: owner,
      resultKey: 'pd_light_result',
      raw: raw,
      result: result,
      change: () async {
        await _type(tester, 'pd_lux', '300');
        await _type(tester, 'pd_w', '40');
      },
      checkRestored: () async {
        expect(_field(tester, 'pd_lux'), '500');
        expect(_field(tester, 'pd_w'), '');
      },
      checkChanged: () async {
        expect(_field(tester, 'pd_lux'), '300');
        expect(_field(tester, 'pd_w'), '40');
      },
    );
  });

  testWidgets('상 평형: 회로 줄·상 칩·삼상 칩이 되돌아온다', (tester) async {
    await _open(tester, const PanelDesignPage(initialTab: 1));
    final owner = _private('_BalanceTab');
    await _type(tester, 'pd_bal_name_0', '전등');
    await _type(tester, 'pd_bal_va_0', '3000');
    await _tap(tester, 'pd_bal_add');
    await _type(tester, 'pd_bal_va_1', '1000');
    await _tap(tester, 'pd_bal_ph_1_S');
    await _tap(tester, 'pd_bal_add');
    await _type(tester, 'pd_bal_va_2', '2000');
    await _tap(tester, 'pd_bal_3_2');
    final result = _res(tester, 'pd_bal_result');
    final raw = _snapRaw(tester, owner);
    final rows = jsonDecode(raw)['rows'] as List;
    expect(rows.length, 3);
    expect(rows[1]['ph'], 's');
    expect(rows[2]['3'], true);

    await _restoreAndUndo(
      tester,
      owner: owner,
      resultKey: 'pd_bal_result',
      raw: raw,
      result: result,
      change: () async {
        await _tap(tester, 'pd_bal_del_2');
        await _tap(tester, 'pd_bal_ph_1_T');
        await _type(tester, 'pd_bal_va_0', '500');
        await _type(tester, 'pd_bal_v', '230');
      },
      checkRestored: () async {
        expect(find.byKey(const Key('pd_bal_row_2')), findsOneWidget);
        expect(_field(tester, 'pd_bal_name_0'), '전등');
        expect(_field(tester, 'pd_bal_va_0'), '3000');
        expect(_field(tester, 'pd_bal_va_2'), '2000');
        expect(_field(tester, 'pd_bal_v'), '220');
      },
      checkChanged: () async {
        expect(find.byKey(const Key('pd_bal_row_2')), findsNothing);
        expect(_field(tester, 'pd_bal_va_0'), '500');
      },
    );
  });

  testWidgets('간선 전압강하: 회로 칩·굵기·온도·한도·구간 줄이 되돌아온다', (tester) async {
    await _open(tester, const PanelDesignPage(initialTab: 2));
    final owner = _private('_FeederTab');
    await _tap(tester, 'pd_feed_three');
    await _type(tester, 'pd_feed_v', '380');
    await _tap(tester, 'pd_feed_size');
    await tester.tap(find.text('10 mm²').last);
    await tester.pumpAndSettle();
    await _tap(tester, 'pd_feed_xlpe');
    await _tap(tester, 'pd_feed_lim_other');
    await _type(tester, 'pd_feed_len_0', '30');
    await _type(tester, 'pd_feed_amps_0', '5');
    await _type(tester, 'pd_feed_len_1', '30');
    await _type(tester, 'pd_feed_amps_1', '10');
    await _tap(tester, 'pd_feed_add');
    await _type(tester, 'pd_feed_len_2', '20');
    await _type(tester, 'pd_feed_amps_2', '4');
    final result = _res(tester, 'pd_feed_result');
    expect(result, contains('3구간'));
    final snap = jsonDecode(_snapRaw(tester, owner)) as Map<String, dynamic>;
    expect(snap['phase'], 'three');
    expect(snap['size'], 10);
    expect(snap['xlpe'], true);
    expect(snap['light'], false);
    expect((snap['rows'] as List).length, 3);
    final raw = jsonEncode(snap);

    await _restoreAndUndo(
      tester,
      owner: owner,
      resultKey: 'pd_feed_result',
      raw: raw,
      result: result,
      change: () async {
        await _tap(tester, 'pd_feed_dc');
        await _tap(tester, 'pd_feed_size');
        await tester.tap(find.text('6 mm²').last);
        await tester.pumpAndSettle();
        await _tap(tester, 'pd_feed_pvc');
        await _tap(tester, 'pd_feed_lim_light');
        await _tap(tester, 'pd_feed_del_2');
        await _type(tester, 'pd_feed_len_0', '50');
      },
      checkRestored: () async {
        expect(find.byKey(const Key('pd_feed_pf')), findsOneWidget, reason: '교류면 역률 칸이 보인다');
        expect(find.byKey(const Key('pd_feed_row_2')), findsOneWidget);
        expect(_field(tester, 'pd_feed_len_0'), '30');
        expect(_field(tester, 'pd_feed_amps_2'), '4');
        expect(tester.widget<DropdownButton<double>>(find.byKey(const Key('pd_feed_size'))).value, 10);
      },
      checkChanged: () async {
        expect(find.byKey(const Key('pd_feed_pf')), findsNothing);
        expect(find.byKey(const Key('pd_feed_row_2')), findsNothing);
        expect(_field(tester, 'pd_feed_len_0'), '50');
        expect(tester.widget<DropdownButton<double>>(find.byKey(const Key('pd_feed_size'))).value, 6);
      },
    );
  });

  testWidgets('분기회로 수: 용도 칩 값·칸 값이 되돌아온다', (tester) async {
    await _open(tester, const PanelDesignPage(initialTab: 3));
    final owner = _private('_BranchTab');
    await _tap(tester, 'pd_use_30');
    await _type(tester, 'pd_branch_area', '200');
    await _type(tester, 'pd_branch_extra', '1000');
    await _type(tester, 'pd_branch_util', '80');
    final result = _res(tester, 'pd_branch_result');
    expect(result, contains('7000 VA'));
    final raw = _snapRaw(tester, owner);

    await _restoreAndUndo(
      tester,
      owner: owner,
      resultKey: 'pd_branch_result',
      raw: raw,
      result: result,
      change: () async {
        await _tap(tester, 'pd_use_10');
        await _type(tester, 'pd_branch_amps', '15');
      },
      checkRestored: () async {
        expect(_field(tester, 'pd_branch_density'), '30');
        expect(_field(tester, 'pd_branch_amps'), '20');
        expect(_field(tester, 'pd_branch_util'), '80');
      },
      checkChanged: () async {
        expect(_field(tester, 'pd_branch_density'), '10');
        expect(_field(tester, 'pd_branch_amps'), '15');
      },
    );
  });

  testWidgets('틀린 묶음은 지금 값을 그대로 둔다', (tester) async {
    await _open(tester, const PanelDesignPage(initialTab: 2));
    final owner = _private('_FeederTab');
    await _type(tester, 'pd_feed_len_0', '30');
    final before = _snapRaw(tester, owner);
    _state(tester, owner).restoreElecHistory(
      'x',
      jsonEncode({'phase': 'nope', 'v': 5, 'size': 3.3, 'xlpe': 'y', 'rows': 'z'}),
    );
    await tester.pumpAndSettle();
    expect(_snapRaw(tester, owner), before);
  });
}
