// 압력 시험 계산기 화면: 시험압력·절차·압력계·최고점 높이, 단위 환산(모든 탭), 압력강하 판정,
// 수압 물 온도, 공압 안전거리(가스·질소·가져오기), 에어 누설, 임시 저장, 좁은 폰.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_test_page.dart';

const _draftKey = 'pressure_test_draft_v1';

Future<void> pumpPage(WidgetTester tester) async {
  // 튜브 칸·튜브 결과가 더해져 시험 압력 탭이 길어졌다: 주의 사항까지 한 화면에 만들어지게 높게.
  tester.view.physicalSize = const Size(390, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: PressureTestPage()));
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

Finder get listScroll => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

String fieldText(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('B31.3 수압 설계 10bar → 15bar 이상, 절차·조항·압력계·주의 사항', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byKey(const Key('pt_design')), '10');
    await tester.pump();
    final r = textIn(tester, const Key('pt_plan_result'));
    expect(r, contains('15 bar 이상'));
    expect(r, contains('유지시간: 10분 이상'));
    expect(textIn(tester, const Key('pt_steps')), contains('345.2.2(a)'));
    final g = textIn(tester, const Key('pt_gauge'));
    expect(g, contains('눈금 범위: 약 30 bar'));
    expect(g, contains('0~25 · 0~40 · 0~60 bar'));
    expect(g, contains('2배에 가장 가까운 눈금: 0~25 bar'));
    expect(g, contains('검교정 12개월 이내'));
    final n = textIn(tester, const Key('pt_notes'));
    expect(n, startsWith('주의 사항'));
    expect(n, contains('345.2.3'));
    expect(n, contains('갇힌 물이 데워지면'));
  });

  testWidgets('B31.1 공압 10bar → 12~15bar, 누설 확인 7bar, 예비 점검 선택, 단계 압력', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('pt_b311')));
    await tester.tap(find.byKey(const Key('pt_pneu')));
    await tester.enterText(find.byKey(const Key('pt_design')), '10');
    await tester.pump();
    final r = textIn(tester, const Key('pt_plan_result'));
    expect(r, contains('12 ~ 15 bar'));
    expect(r, contains('누설 확인 압력: 7 bar'));
    expect(r, contains('예비 점검(선택): 1.75 bar 이하'));
    expect(
      r,
      contains('단계 압력(½PT 뒤 PT/10씩): 6 → 7.2 → 8.4 → 9.6 → 10.8 → 12 bar'),
    );
    // 공압은 최고점 높이 칸이 없다
    expect(find.byKey(const Key('pt_head')), findsNothing);
  });

  testWidgets('실제 시험압력 13.3bar → 안전밸브 14.63bar, 범위 이내/초과/미만', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('pt_pneu')));
    await tester.enterText(find.byKey(const Key('pt_design')), '10');
    await tester.enterText(find.byKey(const Key('pt_actual')), '13.3');
    await tester.pump();
    var r = textIn(tester, const Key('pt_plan_result'));
    expect(r, contains('실제 시험압력 13.3 bar: 범위 이내'));
    expect(r, contains('안전밸브 설정압력: 14.63 bar 이하 (시험압력 13.3 bar 기준)'));
    await tester.enterText(find.byKey(const Key('pt_actual')), '14');
    await tester.pump();
    r = textIn(tester, const Key('pt_plan_result'));
    expect(r, contains('최대 시험압력 초과'));
    await tester.enterText(find.byKey(const Key('pt_actual')), '10.5');
    await tester.pump();
    r = textIn(tester, const Key('pt_plan_result'));
    expect(r, contains('최소 시험압력 미만'));
  });

  testWidgets('최고점 높이 20m: 최고점 압력과 압력계에서 올려야 할 압력', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byKey(const Key('pt_design')), '10');
    await tester.enterText(find.byKey(const Key('pt_head')), '20');
    await tester.pump();
    var r = textIn(tester, const Key('pt_plan_result'));
    // 20m × 9.81kPa = 196.2kPa = 1.96bar
    expect(r, contains('최고점 압력: 13.04 bar (물 높이 20m = 1.96 bar)'));
    expect(r, contains('압력계에서 16.96 bar 이상이어야 합니다'));
    await tester.enterText(find.byKey(const Key('pt_actual')), '16');
    await tester.pump();
    r = textIn(tester, const Key('pt_plan_result'));
    expect(r, contains('최고점 압력이 최소 시험압력 미만입니다. 압력계에서 16.96 bar 이상으로 올리십시오.'));
    await tester.enterText(find.byKey(const Key('pt_actual')), '17');
    await tester.pump();
    r = textIn(tester, const Key('pt_plan_result'));
    expect(r, contains('최고점 압력이 최소 시험압력 이상입니다.'));
  });

  testWidgets('단위를 psi로 바꾸면 psi로 넣고 보인다: 150psi B31.3 공압 → 165~199.5psi', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('pt_pneu')));
    await tester.tap(find.byKey(const Key('pt_u_psi')));
    await tester.enterText(find.byKey(const Key('pt_design')), '150');
    await tester.pump();
    expect(
      textIn(tester, const Key('pt_plan_result')),
      contains('165 ~ 199.5 psi'),
    );
  });

  testWidgets('단위를 바꾸면 모든 탭의 압력 값을 환산한다: 10bar → 145.04psi → 다시 10bar', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.enterText(find.byKey(const Key('pt_design')), '10');
    await tester.enterText(find.byKey(const Key('pt_actual')), '16');
    await tester.enterText(find.byKey(const Key('pt_ratio')), '1.2');
    await tester.pump();
    // 다른 탭(압력 강하 시작 압력 7bar)
    await openTab(tester, 'pt_tab_decay');
    await tester.enterText(find.byKey(const Key('pt_p1')), '7');
    await tester.pump();
    await openTab(tester, 'pt_tab_plan');
    await tester.tap(find.byKey(const Key('pt_u_psi')));
    await tester.pump();
    expect(fieldText(tester, 'pt_design'), '145.04');
    expect(fieldText(tester, 'pt_actual'), '232.06');
    expect(fieldText(tester, 'pt_ratio'), '1.2'); // 압력이 아닌 칸은 그대로
    // 결과는 뜻이 그대로: 1.5 × 1.2 × 10bar = 18bar = 261.07psi
    expect(
      textIn(tester, const Key('pt_plan_result')),
      contains('261.07 psi 이상'),
    );
    // 다른 탭(압력 강하 시작 압력 7bar)도 환산
    await openTab(tester, 'pt_tab_decay');
    expect(fieldText(tester, 'pt_p1'), '101.53');
    // 다시 bar로: 반올림이 쌓이지 않는다
    await tester.tap(find.byKey(const Key('pt_u_bar')));
    await tester.pump();
    expect(fieldText(tester, 'pt_p1'), '7');
    await openTab(tester, 'pt_tab_plan');
    expect(fieldText(tester, 'pt_design'), '10');
    expect(fieldText(tester, 'pt_actual'), '16');
    // kPa → MPa처럼 작은 값도 자릿수를 잃지 않는다
    await tester.tap(find.byKey(const Key('pt_u_mpa')));
    await tester.pump();
    expect(fieldText(tester, 'pt_design'), '1');
  });

  testWidgets('압력강하: 7bar 20°C → 6.73bar 10°C는 온도 때문(실제 강하 거의 0)', (
    tester,
  ) async {
    await pumpPage(tester);
    await openTab(tester, 'pt_tab_decay');
    await tester.enterText(find.byKey(const Key('pt_p1')), '7');
    await tester.enterText(find.byKey(const Key('pt_p2')), '6.7266');
    await tester.enterText(find.byKey(const Key('pt_t2')), '10');
    await tester.pump();
    final r = textIn(tester, const Key('pt_decay_result'));
    expect(r, contains('온도 영향 0.27 bar'));
    expect(r, startsWith('온도를 보정한 실제 압력강하\n0 bar'));
    expect(r, isNot(contains('합격')));
  });

  testWidgets('허용 압력강하를 넣으면 합격/불합격, 압력이 오르면 "상승"', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'pt_tab_decay');
    await tester.enterText(find.byKey(const Key('pt_p1')), '7');
    await tester.enterText(find.byKey(const Key('pt_p2')), '6.9');
    await tester.pump();
    var r = textIn(tester, const Key('pt_decay_result'));
    expect(r, isNot(contains('합격')));
    await tester.enterText(find.byKey(const Key('pt_allow')), '0.05');
    await tester.pump();
    r = textIn(tester, const Key('pt_decay_result'));
    expect(r, contains('허용 압력강하 0.05 bar 초과: 불합격'));
    await tester.enterText(find.byKey(const Key('pt_allow')), '0.2');
    await tester.pump();
    r = textIn(tester, const Key('pt_decay_result'));
    expect(r, contains('허용 압력강하 0.2 bar 이내: 합격'));
    await tester.enterText(find.byKey(const Key('pt_p2')), '7.1');
    await tester.pump();
    r = textIn(tester, const Key('pt_decay_result'));
    expect(r, startsWith('온도를 보정한 실제 압력강하\n0.1 bar 상승'));
    expect(r, contains('합격'));
    expect(r, isNot(contains('-')));
  });

  testWidgets('온도 칸은 음수를 넣을 수 있다(영하 시험)', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'pt_tab_decay');
    const signed = TextInputType.numberWithOptions(decimal: true, signed: true);
    for (final k in ['pt_t1', 'pt_t2']) {
      expect(
        tester.widget<TextField>(find.byKey(Key(k))).keyboardType,
        signed,
        reason: k,
      );
    }
    await tester.enterText(find.byKey(const Key('pt_p1')), '7');
    await tester.enterText(find.byKey(const Key('pt_p2')), '7');
    await tester.enterText(find.byKey(const Key('pt_t1')), '-5');
    await tester.enterText(find.byKey(const Key('pt_t2')), '-10');
    await tester.pump();
    expect(find.byKey(const Key('pt_decay_result')), findsOneWidget);
    await tester.tap(find.byKey(const Key('pt_d_hydro')));
    await tester.pumpAndSettle();
    for (final k in ['pt_wt', 'pt_dt']) {
      expect(
        tester.widget<TextField>(find.byKey(Key(k))).keyboardType,
        signed,
        reason: k,
      );
    }
  });

  testWidgets('수압 물 온도: 결과를 고른 단위로, 0~100°C 밖이면 알림', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'pt_tab_decay');
    await tester.tap(find.byKey(const Key('pt_d_hydro')));
    await tester.pumpAndSettle();
    var r = textIn(tester, const Key('pt_hydro_result'));
    expect(r, contains(' bar'));
    expect(r, isNot(contains('미만이라')));
    await tester.tap(find.byKey(const Key('pt_u_kpa')));
    await tester.pump();
    r = textIn(tester, const Key('pt_hydro_result'));
    expect(r, contains(' kPa'));
    expect(r, isNot(contains(' bar')));
    expect(r, contains('온도가 올라도 압력이 오르지 않거나 내려갑니다'));
    await tester.enterText(find.byKey(const Key('pt_wt')), '-2');
    await tester.pump();
    r = textIn(tester, const Key('pt_hydro_result'));
    expect(r, contains('물 온도 -2°C: 0°C 미만이라 0°C 값으로 계산했습니다.'));
    await tester.enterText(find.byKey(const Key('pt_wt')), '60');
    await tester.pump();
    r = textIn(tester, const Key('pt_hydro_result'));
    expect(r, isNot(contains('초과라')));
    await tester.enterText(find.byKey(const Key('pt_wt')), '105');
    await tester.pump();
    r = textIn(tester, const Key('pt_hydro_result'));
    expect(r, contains('100°C 초과라 100°C 값으로 계산했습니다.'));
  });

  testWidgets('공압 안전거리: 21.72bar, 500L → 30m, 1.68MJ, 2·TNT, 파편 안내, 질소·물', (
    tester,
  ) async {
    await pumpPage(tester);
    await openTab(tester, 'pt_tab_energy');
    await tester.enterText(find.byKey(const Key('pt_se_pt')), '21.72');
    await tester.enterText(find.byKey(const Key('pt_se_vol')), '500');
    await tester.pump();
    final r = textIn(tester, const Key('pt_energy_result'));
    expect(r, startsWith('출입 통제 거리\n30 m'));
    expect(r, contains('1.68 MJ'));
    expect(r, contains('R = 20·(2·TNT)^(1/3) = 18.5m'));
    expect(r, contains('PCC-2-2022'));
    expect(r, contains('질소로 채우면 약 11.2 Nm³'));
    expect(r, contains('47L·150bar 용기 약 2병'));
    expect(
      textIn(tester, const Key('pt_energy_fragment')),
      '파편 거리는 계산하지 않았습니다. 실제 출입 통제 거리는 더 길 수 있습니다.',
    );
    expect(
      textIn(tester, const Key('pt_se_volume')),
      contains('물 약 500 L(약 500 kg)'),
    );
    // 헬륨·아르곤: k = 1.67, 질소 줄 없음
    await tester.tap(find.byKey(const Key('pt_gas_mono')));
    await tester.pump();
    final he = textIn(tester, const Key('pt_energy_result'));
    expect(he, contains('1.21 MJ'));
    expect(he, contains('k = 1.67'));
    expect(he, isNot(contains('질소')));
  });

  testWidgets('공압 안전거리: "시험 압력" 탭 값 가져오기', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'pt_tab_energy');
    expect(find.byKey(const Key('pt_se_import')), findsNothing); // 가져올 값 없음
    await openTab(tester, 'pt_tab_plan');
    await tester.tap(find.byKey(const Key('pt_pneu')));
    await tester.enterText(find.byKey(const Key('pt_design')), '10');
    await tester.pump();
    await openTab(tester, 'pt_tab_energy');
    // 실제 시험압력이 없으면 공압 최대 시험압력(1.33 × 10bar)
    expect(textIn(tester, const Key('pt_se_import')), contains('13.3 bar'));
    await tester.tap(find.byKey(const Key('pt_se_import')));
    await tester.pump();
    expect(fieldText(tester, 'pt_se_pt'), '13.3');
    // 실제 시험압력을 넣으면 그 값
    await openTab(tester, 'pt_tab_plan');
    await tester.enterText(find.byKey(const Key('pt_actual')), '12');
    await tester.pump();
    await openTab(tester, 'pt_tab_energy');
    await tester.tap(find.byKey(const Key('pt_se_import')));
    await tester.pump();
    expect(fieldText(tester, 'pt_se_pt'), '12');
  });

  testWidgets('탭: 시험 압력 · 시험 기록 · 압력 강하 · 공압 안전거리(에어 누설은 뺌)', (tester) async {
    await pumpPage(tester);
    expect(
      tester.widgetList<Tab>(find.byType(Tab)).map((t) => t.text).toList(),
      ['시험 압력', '시험 기록', '압력 강하', '공압 안전거리'],
    );
    expect(find.text('에어 누설'), findsNothing);
    expect(find.text('저장 에너지'), findsNothing);
    expect(find.text('구멍 누설'), findsNothing);
  });

  group('임시 저장', () {
    testWidgets('입력하면 잠시 뒤 저장하고, 화면을 닫을 때도 저장한다', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.byKey(const Key('pt_pneu')));
      await tester.enterText(find.byKey(const Key('pt_design')), '12');
      await tester.pump(const Duration(seconds: 1));
      final prefs = await SharedPreferences.getInstance();
      var m = jsonDecode(prefs.getString(_draftKey)!) as Map;
      expect(m['fields']['design'], '12');
      expect(m['medium'], 'pneumatic');
      // 바로 닫아도(타이머 전) 저장
      await tester.enterText(find.byKey(const Key('pt_design')), '13');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      m = jsonDecode(prefs.getString(_draftKey)!) as Map;
      expect(m['fields']['design'], '13');
    });

    testWidgets('다시 열면 넣어 둔 값을 되살린다', (tester) async {
      SharedPreferences.setMockInitialValues({
        _draftKey: jsonEncode({
          'unit': 'psi',
          'medium': 'pneumatic',
          'gas': 'monatomic',
          'fields': {'design': '150', 'sePt': '300'},
        }),
      });
      await pumpPage(tester);
      expect(fieldText(tester, 'pt_design'), '150');
      expect(
        textIn(tester, const Key('pt_plan_result')),
        contains('165 ~ 199.5 psi'),
      );
      await openTab(tester, 'pt_tab_energy');
      expect(fieldText(tester, 'pt_se_pt'), '300');
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('pt_gas_mono')))
            .selected,
        isTrue,
      );
    });

    testWidgets('저장된 글이 깨져 있어도 기본값으로 연다', (tester) async {
      SharedPreferences.setMockInitialValues({_draftKey: '{깨짐'});
      await pumpPage(tester);
      expect(fieldText(tester, 'pt_design'), '');
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('좁은 폰(344)·큰 글씨에서 네 탭과 새 칸·결과가 넘치지 않는다', (tester) async {
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
        home: const PressureTestPage(),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> type(String key, String v) async {
      await tester.scrollUntilVisible(
        find.byKey(Key(key)),
        200,
        scrollable: listScroll,
      );
      await tester.enterText(find.byKey(Key(key)), v);
      await tester.pump();
    }

    await type('pt_design', '100');
    await type('pt_actual', '150');
    await type('pt_head', '35');
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const Key('pt_notes')),
      300,
      scrollable: listScroll,
    );
    expect(tester.takeException(), isNull);
    for (final t in ['pt_tab_decay', 'pt_tab_energy', 'pt_tab_plan']) {
      await openTab(tester, t);
      expect(tester.takeException(), isNull, reason: t);
      expect(
        tester.widget<TabBar>(find.byType(TabBar)).controller!.index,
        [
          'pt_tab_plan',
          'pt_tab_record',
          'pt_tab_decay',
          'pt_tab_energy',
        ].indexOf(t),
      );
      if (t == 'pt_tab_decay') {
        await type('pt_p1', '7');
        await type('pt_p2', '7.1');
        await type('pt_allow', '0.05');
        await type('pt_t1', '-5');
        await tester.scrollUntilVisible(
          find.byKey(const Key('pt_decay_result')),
          300,
          scrollable: listScroll,
        );
        expect(tester.takeException(), isNull);
      }
      if (t == 'pt_tab_energy') {
        await tester.scrollUntilVisible(
          find.byKey(const Key('pt_se_import')),
          200,
          scrollable: listScroll,
        );
        await tester.tap(find.byKey(const Key('pt_se_import')));
        await tester.pump();
        await type('pt_se_vol', '120000');
        await tester.scrollUntilVisible(
          find.byKey(const Key('pt_energy_fragment')),
          300,
          scrollable: listScroll,
        );
        expect(tester.takeException(), isNull);
      }
    }
    // B31.1 공압 단계 압력 줄도 좁은 폰에서
    await tester.scrollUntilVisible(
      find.byKey(const Key('pt_b311')),
      -300,
      scrollable: listScroll,
    );
    await tester.tap(find.byKey(const Key('pt_b311')));
    await tester.tap(find.byKey(const Key('pt_pneu')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('pt_gauge')),
      300,
      scrollable: listScroll,
    );
    expect(tester.takeException(), isNull);
  });
}
