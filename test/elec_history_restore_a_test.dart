// "최근 계산 기록"을 눌러 그때 입력값으로 되돌리기: 접지·전동기 보호·전동기 점검·전동기 공식 탭.
// 입력 묶음(historySnapshot)을 꺼내 두고 값을 바꾼 뒤 restoreElecHistory로 되돌려
// 칸·칩·결과 글이 처음과 같은지, 모양이 틀린 값은 지금 값을 그대로 두는지 본다.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/theme/field_view.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_ground_tab.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_motor_check_tab.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_motor_formula_tab.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_motor_protect_tab.dart';

import 'formula_flat.dart';

Future<void> _pump(WidgetTester tester, Widget tab) async {
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: FieldViewTheme(child: Scaffold(body: tab)),
    ),
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

String _text(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

bool _sel(WidgetTester tester, String key) =>
    tester.widget<ChoiceChip>(find.byKey(Key(key))).selected;

/// 탭 안의 글자만(되돌리기 알림 글은 빼고) 이어 붙인 것.
String _tabFlat(WidgetTester tester, Type t) => flat(
  tester
      .widgetList<Text>(
        find.descendant(of: find.byType(t), matching: find.byType(Text)),
      )
      .map((x) => x.data ?? '')
      .join(),
);

Map<String, Object?> _snap(WidgetTester tester, Type t) =>
    ((tester.state(find.byType(t)) as dynamic).historySnapshot()
            as Map<String, Object?>?)!;

Future<void> _restore(
  WidgetTester tester,
  Type t,
  String sumKey,
  Map<String, Object?> m,
) async {
  (tester.state(find.byType(t)) as dynamic).restoreElecHistory(
    sumKey,
    jsonEncode(m),
  );
  await tester.pumpAndSettle();
}

/// 알림 시계가 남지 않게 끝까지 흘려보낸다.
Future<void> _drain(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 30));
  await tester.pumpAndSettle();
}

/// 모든 이름에 틀린 모양의 값(목록)을 넣으면 아무것도 바뀌지 않아야 한다.
Future<void> _expectTolerant(
  WidgetTester tester,
  Type t,
  String sumKey,
  Map<String, Object?> extra,
) async {
  final before = _tabFlat(tester, t);
  final snapBefore = jsonEncode(_snap(tester, t));
  final bad = {
    for (final k in _snap(tester, t).keys) k: [1],
    ...extra,
  };
  await _restore(tester, t, sumKey, bad);
  expect(tester.takeException(), isNull);
  expect(jsonEncode(_snap(tester, t)), snapBefore);
  expect(_tabFlat(tester, t), before);
}

void main() {
  setUpAll(expandFormulaCards);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('접지 탭: 항목·칩·칸을 되돌리고 "원래대로"로 다시 돌아간다', (tester) async {
    await _pump(tester, const ElecGroundTab());
    // 보호도체 칸
    await _type(tester, 'gr_phase', '95');
    await _type(tester, 'gr_fault', '20000');
    await _tap(tester, 'gr_sep_out');
    await _tap(tester, 'gr_ins_xlpe');
    // TN 자동 차단
    await _tap(tester, 'gr_mode_tn');
    await _type(tester, 'gr_u0', '230');
    await _tap(tester, 'gr_dev_b');
    await _tap(tester, 'gr_feeder');
    await _type(tester, 'gr_zs', '0.5');
    final snap = _snap(tester, ElecGroundTab);
    final shown = _tabFlat(tester, ElecGroundTab);
    final sum = tester.widget<Text>(
      find.descendant(of: find.byKey(const Key('gr_sum')), matching: find.byType(Text)).first,
    ).data;
    expect(snap['mode'], 'tn');

    // 값을 바꾼다
    await _tap(tester, 'gr_dev_d');
    await _tap(tester, 'gr_branch');
    await _type(tester, 'gr_u0', '100');
    await _tap(tester, 'gr_mode_protective');
    await _type(tester, 'gr_phase', '10');
    await _tap(tester, 'gr_sep_in');
    await _tap(tester, 'gr_mode_rod');
    expect(_tabFlat(tester, ElecGroundTab), isNot(shown));

    await _restore(tester, ElecGroundTab, 'gr_sum', snap);
    expect(_sel(tester, 'gr_mode_tn'), isTrue);
    expect(_text(tester, 'gr_u0'), '230');
    expect(_text(tester, 'gr_zs'), '0.5');
    expect(_sel(tester, 'gr_dev_b'), isTrue);
    expect(_sel(tester, 'gr_feeder'), isTrue);
    expect(_tabFlat(tester, ElecGroundTab), shown);
    expect(
      tester.widget<Text>(
        find.descendant(of: find.byKey(const Key('gr_sum')), matching: find.byType(Text)).first,
      ).data,
      sum,
    );

    // "원래대로"를 누르면 되돌리기 전(접지봉 항목)으로 간다
    await tester.tap(find.text('원래대로'));
    await tester.pumpAndSettle();
    expect(_sel(tester, 'gr_mode_rod'), isTrue);

    // 다시 되돌리고 보호도체 항목 칸도 그때 값인지 본다
    await _restore(tester, ElecGroundTab, 'gr_sum', snap);
    await _tap(tester, 'gr_mode_protective');
    expect(_text(tester, 'gr_phase'), '95');
    expect(_text(tester, 'gr_fault'), '20000');
    expect(_sel(tester, 'gr_sep_out'), isTrue);
    expect(_sel(tester, 'gr_ins_xlpe'), isTrue);
    await _drain(tester);
  });

  testWidgets('접지 탭: 모르는 값·틀린 모양은 지금 값을 둔다', (tester) async {
    await _pump(tester, const ElecGroundTab());
    await _tap(tester, 'gr_mode_insulation');
    await _expectTolerant(tester, ElecGroundTab, 'gr_sum', {
      'mode': 'zzz',
      'dev': 'zzz',
      'gMat': 'zz',
      'trip': 'zz',
      'insKind': 'zz',
      'lv': 'zz',
      'hvKind': 'zz',
      'mat': 'zz',
      'ins': 'zz',
    });
    expect(_sel(tester, 'gr_mode_insulation'), isTrue);
    await _drain(tester);
  });

  testWidgets('전동기 보호 탭: 칸·기동 방식·계전기 위치·클래스를 되돌린다', (tester) async {
    await _pump(tester, const ElecMotorProtectTab());
    await _type(tester, 'emp_fla', '55');
    await _tap(tester, 'emp_yd');
    await _tap(tester, 'emp_line');
    await _tap(tester, 'emp_sf_n');
    await _type(tester, 'emp_run', '50');
    await _tap(tester, 'emp_cls_20');
    await _type(tester, 'emp_start', '12');
    final snap = _snap(tester, ElecMotorProtectTab);
    final shown = _tabFlat(tester, ElecMotorProtectTab);

    await _type(tester, 'emp_fla', '10');
    await _tap(tester, 'emp_direct');
    await _tap(tester, 'emp_sf_y');
    await _type(tester, 'emp_run', '');
    await _tap(tester, 'emp_cls_10A');
    await _type(tester, 'emp_start', '3');
    expect(_tabFlat(tester, ElecMotorProtectTab), isNot(shown));

    await _restore(tester, ElecMotorProtectTab, 'emp_sum', snap);
    expect(_text(tester, 'emp_fla'), '55');
    expect(_text(tester, 'emp_run'), '50');
    expect(_text(tester, 'emp_start'), '12');
    expect(_sel(tester, 'emp_yd'), isTrue);
    expect(_sel(tester, 'emp_line'), isTrue);
    expect(_sel(tester, 'emp_sf_n'), isTrue);
    expect(_sel(tester, 'emp_cls_20'), isTrue);
    expect(_tabFlat(tester, ElecMotorProtectTab), shown);

    await _expectTolerant(tester, ElecMotorProtectTab, 'emp_sum', {
      'method': 'zz',
      'place': 'zz',
      'cls': '15',
    });
    expect(_sel(tester, 'emp_cls_20'), isTrue);
    await _drain(tester);
  });

  testWidgets('전동기 점검 탭: 측정값·권선 종류·보정·절연 등급을 되돌린다', (tester) async {
    await _pump(tester, const ElecMotorCheckTab());
    const vals = {
      'mc_volt': '440',
      'mc_ir1': '50',
      'mc_irtemp': '30',
      'mc_ir10': '120',
      'mc_r1': '1.00',
      'mc_r2': '1.02',
      'mc_r3': '1.01',
      'mc_rtemp': '25',
      'mc_rref': '0.98',
      'mc_rreftemp': '20',
      'mc_v1': '380',
      'mc_v2': '385',
      'mc_v3': '378',
      'mc_a1': '20',
      'mc_a2': '21',
      'mc_a3': '19',
    };
    for (final e in vals.entries) {
      await _type(tester, e.key, e.value);
    }
    await _tap(tester, 'mc_w_form');
    await _tap(tester, 'mc_corr_iec');
    await _tap(tester, 'mc_cls_a');
    final snap = _snap(tester, ElecMotorCheckTab);
    final shown = _tabFlat(tester, ElecMotorCheckTab);

    for (final k in vals.keys) {
      await _type(tester, k, '7');
    }
    await _tap(tester, 'mc_w_random');
    await _tap(tester, 'mc_corr_ieee');
    await _tap(tester, 'mc_cls_b');
    expect(_tabFlat(tester, ElecMotorCheckTab), isNot(shown));

    await _restore(tester, ElecMotorCheckTab, 'mc_sum', snap);
    for (final e in vals.entries) {
      expect(_text(tester, e.key), e.value, reason: e.key);
    }
    expect(_sel(tester, 'mc_w_form'), isTrue);
    expect(_sel(tester, 'mc_corr_iec'), isTrue);
    expect(_sel(tester, 'mc_cls_a'), isTrue);
    expect(_tabFlat(tester, ElecMotorCheckTab), shown);

    await _expectTolerant(tester, ElecMotorCheckTab, 'mc_sum', {
      'kind': 'zz',
      'corr': 'zz',
    });
    await _drain(tester);
  });

  testWidgets('전동기 공식 탭: 묶음·구할 값·상·기동 방식과 안 보이는 묶음 칸까지 되돌린다', (tester) async {
    await _pump(tester, const ElecMotorFormulaTab());
    // 기동 방식 묶음 칸
    await _tap(tester, 'mf_sec_start');
    await _tap(tester, 'mf_k_auto');
    await _type(tester, 'mf_rated', '20');
    await _type(tester, 'mf_tap', '80');
    // 전류·효율 묶음: 역률 구하기, 입력 전력, 단상
    await _tap(tester, 'mf_sec_current');
    await _tap(tester, 'mf_s_pf');
    await _tap(tester, 'mf_p_in');
    await _tap(tester, 'mf_ph1');
    await _type(tester, 'mf_kw', '7.5');
    await _type(tester, 'mf_v', '220');
    await _type(tester, 'mf_amps', '40');
    final snap = _snap(tester, ElecMotorFormulaTab);
    final shown = _tabFlat(tester, ElecMotorFormulaTab);
    expect(find.byKey(const Key('mf_sum')), findsOneWidget);

    await _type(tester, 'mf_kw', '3');
    await _tap(tester, 'mf_s_current');
    await _tap(tester, 'mf_p_out');
    await _tap(tester, 'mf_ph3');
    await _tap(tester, 'mf_sec_start');
    await _tap(tester, 'mf_k_direct');
    await _type(tester, 'mf_rated', '5');
    expect(_tabFlat(tester, ElecMotorFormulaTab), isNot(shown));

    await _restore(tester, ElecMotorFormulaTab, 'mf_sum', snap);
    expect(_sel(tester, 'mf_sec_current'), isTrue);
    expect(_sel(tester, 'mf_s_pf'), isTrue);
    expect(_sel(tester, 'mf_p_in'), isTrue);
    expect(_sel(tester, 'mf_ph1'), isTrue);
    expect(_text(tester, 'mf_kw'), '7.5');
    expect(_text(tester, 'mf_v'), '220');
    expect(_text(tester, 'mf_amps'), '40');
    expect(_tabFlat(tester, ElecMotorFormulaTab), shown);
    await _tap(tester, 'mf_sec_start');
    expect(_sel(tester, 'mf_k_auto'), isTrue);
    expect(_text(tester, 'mf_rated'), '20');
    expect(_text(tester, 'mf_tap'), '80');

    // 전부하 전류 표: 표·고른 출력도 되돌린다
    await _restore(tester, ElecMotorFormulaTab, 'mf_sum', {
      'sec': 'flc',
      'flcNec': false,
      'ie3Kw': 30,
    });
    expect(_sel(tester, 'mf_flc_ie3'), isTrue);
    expect(find.textContaining('30 kW: 380 V 59.1 A'), findsWidgets);

    // 표에 없는 출력·극수와 틀린 모양은 지금 값을 둔다
    await _expectTolerant(tester, ElecMotorFormulaTab, 'mf_sum', {
      'sec': 'zz',
      'solve': 'zz',
      'kind': 'zz',
      'ie3Kw': 31.5,
      'necHp': 7.77,
      'xPoles': 5,
    });
    expect(find.textContaining('30 kW: 380 V 59.1 A'), findsWidgets);
    await _restore(tester, ElecMotorFormulaTab, 'mf_sum', {'sec': 'maxTorque', 'xPoles': 6});
    expect(_sel(tester, 'mf_xp_6'), isTrue);
    await _drain(tester);
  });
}
