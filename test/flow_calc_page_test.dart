// 유량 계산 화면: 유속·관 굵기(튜브·배관·내경), 압력손실(피팅 개수·높이·기체 판정),
// 차압 유량계(환산·제곱근 표·오리피스), 임시 저장, 좁은 폰(344)·큰 글씨.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/flow/flow_calc_page.dart';

const _draftKey = 'flow_calc_draft_v1';

Future<void> pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 5200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: FlowCalcPage()));
  await tester.pumpAndSettle();
}

Future<void> pumpNarrow(WidgetTester tester) async {
  tester.view.physicalSize = const Size(344, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(1.3)),
        child: child!,
      ),
      home: const FlowCalcPage(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

String textIn(WidgetTester tester, Key key) => tester
    .widgetList<Text>(
      find.descendant(of: find.byKey(key), matching: find.byType(Text)),
    )
    .map((t) => t.data ?? '')
    .join('\n');

/// 지금 보이는 탭의 목록.
Finder get listScroll => find
    .descendant(
      of: find.byType(ListView).hitTestable().first,
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> reveal(WidgetTester tester, Finder f) async {
  if (f.hitTestable().evaluate().isEmpty) {
    try {
      await tester.scrollUntilVisible(
        f,
        200,
        scrollable: listScroll,
        maxScrolls: 80,
      );
    } catch (_) {
      await tester.scrollUntilVisible(
        f,
        -200,
        scrollable: listScroll,
        maxScrolls: 80,
      );
    }
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String key, String v) async {
  await reveal(tester, find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), v);
  await tester.pump();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await reveal(tester, find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('물 20°C 50L/min, 1/2" × 0.049 튜브 → 10.18 m/s, 난류, 권장 초과', (
    tester,
  ) async {
    await pumpPage(tester);
    await type(tester, 'fv_flow', '50');
    final r = textIn(tester, const Key('fl_vel_result'));
    expect(r, contains('10.18 m/s'));
    expect(r, contains('내경 10.21mm'));
    expect(r, contains('난류'));
    expect(r, contains('초과'));
    expect(r, contains('가장 작은 튜브'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('배관: 두께를 넣어야 계산하고, 가장 작은 호칭을 찾는다', (tester) async {
    await pumpPage(tester);
    await type(tester, 'fv_flow', '100');
    await tapKey(tester, 'fv_cd_pipe');
    expect(find.byKey(const Key('fl_vel_result')), findsNothing);
    await type(tester, 'fv_wall', '3.4');
    final r = textIn(tester, const Key('fl_vel_result'));
    // 25A KS 외경 34.0 − 6.8 = 27.2mm
    expect(r, contains('내경 27.2mm'));
    expect(r, contains('가장 작은 배관'));
  });

  testWidgets('압력손실: 직관 10m 손 계산 943kPa, 엘보를 더하면 늘어난다', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'fl_tab_dp');
    await type(tester, 'dp_flow', '50');
    var r = textIn(tester, const Key('fl_dp_result'));
    expect(r, contains('943'));
    expect(r, contains('Colebrook'));
    await tapKey(tester, 'dp_fit_elbow90_plus');
    await tapKey(tester, 'dp_fit_elbow90_plus');
    expect(textIn(tester, const Key('dp_fittings')), contains('2'));
    r = textIn(tester, const Key('fl_dp_result'));
    expect(r, isNot(contains('K 합 0)')));
    await type(tester, 'dp_dz', '5');
    r = textIn(tester, const Key('fl_dp_result'));
    expect(r, contains('높이 차 5m'));
  });

  testWidgets('공기: 압력손실이 입구 절대 압력의 40%를 넘으면 경고', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'fl_tab_dp');
    await tapKey(tester, 'dp_fluid_air');
    await type(tester, 'dp_gasP', '1');
    await type(tester, 'dp_flow', '3000');
    await type(tester, 'dp_len', '100');
    final r = textIn(tester, const Key('fl_dp_result'));
    expect(r, contains('40%를 넘어'));
    final box = tester.widget<Container>(find.byKey(const Key('fl_dp_result')));
    expect(box.decoration, isNotNull);
  });

  testWidgets('차압 환산: 최대 100m³/h·25kPa, 6.25kPa → 50m³/h, 표 5줄', (
    tester,
  ) async {
    await pumpPage(tester);
    await openTab(tester, 'fl_tab_meter');
    await type(tester, 'fm_qmax', '100');
    await type(tester, 'fm_dpmax', '25');
    await type(tester, 'fm_value', '6.25');
    final r = textIn(tester, const Key('fm_range_result'));
    expect(r, contains('50 m³/h'));
    expect(r, contains('유량 50% · 차압 25%'));
    expect(r, contains('8 mA'));
    final t = textIn(tester, const Key('fm_table'));
    expect(t, contains('56.25%'));
    expect(t, contains('\n13\n')); // 56.25% 차압의 mA = 13
    await tapKey(tester, 'fm_by_dp');
    expect(textIn(tester, const Key('fm_table')), contains('70.71%'));
  });

  testWidgets('오리피스: 물 20°C D 102.26 d 51.13 플랜지 탭 25kPa → 결과와 C', (
    tester,
  ) async {
    await pumpPage(tester);
    await openTab(tester, 'fl_tab_meter');
    await tapKey(tester, 'fm_mode_orifice');
    await type(tester, 'fm_o_D', '102.26');
    await type(tester, 'fm_o_d', '51.13');
    await type(tester, 'fm_o_dp', '25');
    final r = textIn(tester, const Key('fm_orifice_result'));
    expect(r, contains('m³/h'));
    expect(r, contains('C = 0.60'));
    expect(r, contains('β = d/D = 0.5'));
    expect(r, isNot(contains('적용 범위 밖')));
  });

  testWidgets('임시 저장: 넣은 값·고른 것이 다시 열면 되살아난다', (tester) async {
    await pumpPage(tester);
    await tapKey(tester, 'fv_fluid_oil');
    await type(tester, 'fv_oilRho', '870');
    await type(tester, 'fv_oilCst', '46');
    await type(tester, 'fv_flow', '20');
    await tester.pump(const Duration(seconds: 1));
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey)!;
    final m = jsonDecode(raw) as Map;
    expect(m['fluid'], 'oil');
    expect((m['fields'] as Map)['oilCst'], '46');

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('fv_oilCst')))
          .controller!
          .text,
      '46',
    );
    expect(textIn(tester, const Key('fl_vel_result')), contains('m/s'));
  });

  testWidgets('저장 값이 깨져 있어도 기본값으로 연다', (tester) async {
    SharedPreferences.setMockInitialValues({_draftKey: '{bad json'});
    await pumpPage(tester);
    expect(find.byKey(const Key('fv_flow')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('좁은 폰(344)·글씨 1.3배: 세 탭이 넘치지 않는다', (tester) async {
    await pumpNarrow(tester);
    await type(tester, 'fv_flow', '50');
    await reveal(tester, find.byKey(const Key('fl_vel_note')));
    expect(tester.takeException(), isNull);
    await tapKey(tester, 'fv_cd_pipe');
    await type(tester, 'fv_wall', '3.4');
    await reveal(tester, find.byKey(const Key('fl_vel_note')));
    expect(tester.takeException(), isNull);

    await openTab(tester, 'fl_tab_dp');
    expect(tester.takeException(), isNull);
    await tapKey(tester, 'dp_fluid_n2');
    await tapKey(tester, 'dp_pu_kgf');
    await reveal(tester, find.byKey(const Key('dp_fittings')));
    await tapKey(tester, 'dp_fit_globe_plus');
    await reveal(tester, find.byKey(const Key('fl_dp_note')));
    expect(tester.takeException(), isNull);

    await openTab(tester, 'fl_tab_meter');
    await type(tester, 'fm_qmax', '12345.6');
    await type(tester, 'fm_dpmax', '2500');
    await type(tester, 'fm_value', '1234.5');
    await reveal(tester, find.byKey(const Key('fm_table')));
    expect(tester.takeException(), isNull);
    await tapKey(tester, 'fm_mode_orifice');
    await tapKey(tester, 'fm_o_oil');
    await type(tester, 'fm_o_rho', '870');
    await type(tester, 'fm_o_cst', '46');
    await type(tester, 'fm_o_D', '30');
    await type(tester, 'fm_o_d', '10');
    await type(tester, 'fm_o_dp', '50');
    await reveal(tester, find.byKey(const Key('fm_orifice_result')));
    expect(textIn(tester, const Key('fm_orifice_result')), contains('적용 범위 밖'));
    expect(tester.takeException(), isNull);
  });
}
