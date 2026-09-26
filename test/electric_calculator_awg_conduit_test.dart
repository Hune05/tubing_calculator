// 전기 계산기 AWG·kcmil 모드(전선 굵기·전압강하 탭)와 전선관 탭 화면 시험, 저장, 좁은 폰·큰 글씨.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';

Future<void> pumpPage(
  WidgetTester tester, {
  Size size = const Size(390, 3200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: ElectricCalculatorPage()));
  await tester.pumpAndSettle();
}

/// 좁은 폰(344×760)·글씨 1.3배.
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
      home: const ElectricCalculatorPage(),
    ),
  );
  await tester.pumpAndSettle();
}

String textIn(WidgetTester tester, Key key) {
  final texts = tester.widgetList<Text>(
    find.descendant(of: find.byKey(key), matching: find.byType(Text)),
  );
  return texts.map((t) => t.data ?? '').join('\n');
}

bool chipOn(WidgetTester tester, String key) =>
    tester.widget<ChoiceChip>(find.byKey(Key(key))).selected;

Future<void> openTab(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    final s = find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    try {
      await tester.scrollUntilVisible(f, 200, scrollable: s, maxScrolls: 60);
    } catch (_) {
      await tester.scrollUntilVisible(f, -200, scrollable: s, maxScrolls: 60);
    }
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await reveal(tester, find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String key, String v) async {
  await reveal(tester, find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), v);
  await tester.pump();
}

Future<void> pickDropdown(WidgetTester tester, String key, String item) async {
  await tapKey(tester, key);
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

Future<String> resultOf(WidgetTester tester, String key) async {
  await reveal(tester, find.byKey(Key(key)));
  return textIn(tester, Key(key));
}

Future<String> basisOf(WidgetTester tester, String key) async {
  await reveal(tester, find.byKey(Key(key)));
  await tester.tap(
    find.descendant(of: find.byKey(Key(key)), matching: find.text('근거 보기')),
  );
  await tester.pumpAndSettle();
  return textIn(tester, Key(key));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AWG·kcmil', () {
    testWidgets('기본은 SQ, AWG를 누르면 전선 굵기·전압강하 탭이 같이 바뀐다', (tester) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_cable');
      expect(chipOn(tester, 'ec_cable_unit_sq'), isTrue);
      expect(find.byKey(const Key('ec_kind')), findsOneWidget);
      await tapKey(tester, 'ec_cable_unit_awg');
      expect(find.byKey(const Key('ec_kind')), findsNothing);
      expect(find.byKey(const Key('ec_awg_col_90')), findsOneWidget);
      await openTab(tester, 'ec_tab_vd');
      expect(chipOn(tester, 'ec_vd_unit_awg'), isTrue);
      expect(find.byKey(const Key('ec_vd_awg_size')), findsOneWidget);
      await tapKey(tester, 'ec_vd_unit_sq');
      expect(find.byKey(const Key('ec_vd_size')), findsOneWidget);
      await openTab(tester, 'ec_tab_cable');
      expect(chipOn(tester, 'ec_cable_unit_sq'), isTrue);
    });

    testWidgets('일반 부하 20A 단상 → 12 AWG, 240.4(D) 20A 이하, SQ 환산', (
      tester,
    ) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_cable');
      await tapKey(tester, 'ec_cable_unit_awg');
      await tapKey(tester, 'ec_v_220');
      await tapKey(tester, 'ec_cable_motor');
      await type(tester, 'ec_ib', '20');
      await type(tester, 'ec_length', '');
      await tester.pumpAndSettle();
      final r = await resultOf(tester, 'ec_cable_result');
      expect(r, contains('12 AWG'));
      expect(r, contains('20A 이하'));
      expect(r, contains('NEC 240.4(D)'));
      expect(r, contains('같거나 굵은 SQ는 4sq'));
      expect(r, contains('KEC는 mm²'));
      final b = await basisOf(tester, 'ec_cable_basis');
      expect(b, contains('단자 60°C 열 20A'));
      expect(b, contains('NEC 표 310.16'));
    });

    testWidgets('전동기 28A: ×1.25 = 35A, 단자 75°C면 10 AWG', (tester) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_cable');
      await tapKey(tester, 'ec_cable_unit_awg');
      await tapKey(tester, 'ec_v_480');
      await type(tester, 'ec_ib', '28');
      await type(tester, 'ec_length', '');
      await tester.pumpAndSettle();
      expect(await resultOf(tester, 'ec_cable_result'), contains('8 AWG'));
      await tapKey(tester, 'ec_awg_term_75');
      final r = await resultOf(tester, 'ec_cable_result');
      expect(r, contains('10 AWG'));
      expect(r, contains('설계전류 35A'));
      expect(r, isNot(contains('240.4(D)')));
    });

    testWidgets('기존 회로 점검: 14 AWG에 20A 차단기는 240.4(D) 초과', (tester) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_cable');
      await tapKey(tester, 'ec_cable_unit_awg');
      await tapKey(tester, 'ec_cable_motor');
      await tapKey(tester, 'ec_mode_check');
      await pickDropdown(tester, 'ec_awg_chk_size', '14 AWG (2.08 mm²)');
      await type(tester, 'ec_chk_breaker', '20');
      await tester.pumpAndSettle();
      final r = await resultOf(tester, 'ec_cable_result');
      expect(r, contains('14 AWG 허용전류'));
      expect(r, contains('15A를 초과합니다(NEC 240.4(D))'));
      expect(textIn(tester, const Key('ec_sum_cable')), contains('점검 필요'));
    });

    testWidgets('전압강하 AWG: 삼상 380V 20A 50m 12 AWG 역률 100', (tester) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_vd');
      await tapKey(tester, 'ec_vd_unit_awg');
      await type(tester, 'ec_vd_i', '20');
      await type(tester, 'ec_vd_len', '50');
      await type(tester, 'ec_vd_pf', '100');
      await tester.pumpAndSettle();
      // √3 × 20 × 0.05 × 6.50 = 11.26V → 2.96%
      final r = await resultOf(tester, 'ec_vd_result');
      expect(r, contains('11.26 V'));
      expect(r, contains('2.96 %'));
      expect(r, contains('6.5 Ω/km'));
    });

    testWidgets('AWG 선택·조건을 저장했다가 다시 열면 채운다', (tester) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_cable');
      await tapKey(tester, 'ec_cable_unit_awg');
      await tapKey(tester, 'ec_awg_col_75');
      await tapKey(tester, 'ec_awg_term_75');
      await type(tester, 'ec_awg_amb', '45');
      await type(tester, 'ec_awg_ccc', '6');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      final prefs = await SharedPreferences.getInstance();
      final m =
          jsonDecode(prefs.getString(ElectricCalculatorPage.draftKey)!) as Map;
      expect(m['awg'], isTrue);
      expect(m['awgCol'], 'c75');
      expect(m['awgTerm'], 'c75');
      expect(m['awgAmb'], '45');
      expect(m['awgCcc'], '6');

      await tester.pumpWidget(const SizedBox());
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_cable');
      expect(chipOn(tester, 'ec_cable_unit_awg'), isTrue);
      expect(chipOn(tester, 'ec_awg_col_75'), isTrue);
      expect(chipOn(tester, 'ec_awg_term_75'), isTrue);
    });
  });

  group('전선관', () {
    testWidgets('기본: HFIX 2.5sq 3가닥 후강 22 → 10.5%, 한도 32%, 종류별 최소 전선관', (
      tester,
    ) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_conduit');
      expect(chipOn(tester, 'ec_cd_type_thick'), isTrue);
      expect(chipOn(tester, 'ec_cd_rule_naesun'), isTrue);
      final r = await resultOf(tester, 'ec_cd_result');
      expect(r, contains('10.5 %'));
      expect(r, contains('후강 22 (내경 21.9mm)'));
      expect(r, contains('한도 32% 이내입니다.'));
      expect(r, contains('최소 후강: 16'));
      expect(r, contains('최소 박강: 19'));
      expect(r, contains('최소 2종 가요관: 15'));
      expect(textIn(tester, const Key('ec_sum_cd')), contains('후강 22 10.5%'));
      final b = await basisOf(tester, 'ec_cd_basis');
      expect(b, contains('HFIX 450/750V 2.5sq 외경 4.1mm × 3가닥'));
      expect(b, contains('2225-5'));
    });

    testWidgets('같은 굵기 절연전선 10가닥: 32% 초과면 빨간 결과, 48% 스위치로 이내', (tester) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_conduit');
      await type(tester, 'ec_cd_n_0', '10');
      await tester.pumpAndSettle();
      var r = await resultOf(tester, 'ec_cd_result');
      expect(r, contains('35 %'));
      expect(r, contains('한도 32% 초과'));
      expect(r, contains('후강 28 이상으로 선정하십시오'));
      await tapKey(tester, 'ec_cd_easy');
      r = await resultOf(tester, 'ec_cd_result');
      expect(r, contains('한도 48% 이내입니다.'));
      expect(r, contains('최소 후강: 22'));
    });

    testWidgets('전선 추가·종류 바꾸기: 굵기가 다르면 48% 스위치가 없다, 케이블 1본은 1.5배', (
      tester,
    ) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_conduit');
      await tapKey(tester, 'ec_cd_add');
      expect(find.byKey(const Key('ec_cd_kind_1')), findsOneWidget);
      await pickDropdown(tester, 'ec_cd_size_1', '4sq (외경 4.7)');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ec_cd_easy')), findsNothing);
      expect(await resultOf(tester, 'ec_cd_result'), contains('굵기가 다른 전선'));
      // 첫 줄 지우고 남은 줄을 F-CV 4심 16sq 1본으로
      await tapKey(tester, 'ec_cd_del_0');
      expect(find.byKey(const Key('ec_cd_kind_1')), findsNothing);
      await pickDropdown(tester, 'ec_cd_kind_0', 'F-CV 4심');
      await pickDropdown(tester, 'ec_cd_size_0', '16sq (외경 22)');
      final r = await resultOf(tester, 'ec_cd_result');
      expect(r, contains('1.5배'));
      expect(r, contains('최소 후강: 36'));
      await tapKey(tester, 'ec_cd_rule_nec');
      expect(await resultOf(tester, 'ec_cd_result'), contains('53%'));
    });

    testWidgets('전선관 종류를 바꾸면 굵기 목록이 바뀐다(박강 → 내경이 같거나 큰 규격)', (tester) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_conduit');
      await tapKey(tester, 'ec_cd_type_thin');
      final r = await resultOf(tester, 'ec_cd_result');
      expect(r, contains('박강 25 (내경 22.2mm)'));
      await tapKey(tester, 'ec_cd_type_pvc');
      expect(await resultOf(tester, 'ec_cd_result'), contains('경질 비닐 28'));
    });

    testWidgets('음수 가닥은 계산하지 않는다', (tester) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_conduit');
      await type(tester, 'ec_cd_n_0', '-2');
      await tester.pumpAndSettle();
      expect(await resultOf(tester, 'ec_cd_result'), contains('음수는 넣을 수 없습니다'));
    });

    testWidgets('전선관 입력을 저장했다가 다시 열면 채운다', (tester) async {
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_conduit');
      await tapKey(tester, 'ec_cd_type_flex2');
      await tapKey(tester, 'ec_cd_add');
      await pickDropdown(tester, 'ec_cd_kind_1', 'F-CVV-S 10심');
      await type(tester, 'ec_cd_n_1', '2');
      await tapKey(tester, 'ec_cd_rule_nec');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      final prefs = await SharedPreferences.getInstance();
      final m =
          jsonDecode(prefs.getString(ElectricCalculatorPage.draftKey)!) as Map;
      expect(m['cdKind'], 'flex2');
      expect(m['cdRule'], 'nec');
      final rows = m['cdRows'] as List;
      expect(rows.length, 2);
      expect(rows[1], {'k': 'cvvs10', 's': 2.5, 'n': '2'});

      await tester.pumpWidget(const SizedBox());
      await pumpPage(tester);
      await openTab(tester, 'ec_tab_conduit');
      expect(chipOn(tester, 'ec_cd_type_flex2'), isTrue);
      expect(chipOn(tester, 'ec_cd_rule_nec'), isTrue);
      expect(find.byKey(const Key('ec_cd_kind_1')), findsOneWidget);
      expect(find.text('F-CVV-S 10심'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ec_cd_n_1')))
            .controller!
            .text,
        '2',
      );
    });
  });

  group('좁은 폰(344)·큰 글씨', () {
    testWidgets('탭 7개가 모두 열리고 넘치지 않는다', (tester) async {
      await pumpNarrow(tester);
      const tabs = [
        'ec_tab_load',
        'ec_tab_cable',
        'ec_tab_vd',
        'ec_tab_conduit',
        'ec_tab_pf',
        'ec_tab_basic',
        'ec_tab_bus',
      ];
      for (final t in [...tabs.reversed, ...tabs]) {
        await openTab(tester, t);
        expect(tester.takeException(), isNull, reason: t);
        expect(
          tester.widget<TabBar>(find.byType(TabBar)).controller!.index,
          tabs.indexOf(t),
        );
      }
    });

    testWidgets('전선관 여러 줄·긴 이름·근거 보기가 넘치지 않는다', (tester) async {
      await pumpNarrow(tester);
      await openTab(tester, 'ec_tab_conduit');
      expect(tester.takeException(), isNull, reason: '기본');
      await tapKey(tester, 'ec_cd_add');
      await pickDropdown(tester, 'ec_cd_kind_1', 'F-CV 단심');
      await tapKey(tester, 'ec_cd_add');
      await pickDropdown(tester, 'ec_cd_kind_2', 'F-CV 4심');
      await type(tester, 'ec_cd_n_2', '100');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '여러 줄');
      await tapKey(tester, 'ec_cd_type_flex2');
      await tapKey(tester, 'ec_cd_rule_nec');
      expect(tester.takeException(), isNull, reason: '가요·NEC');
      await basisOf(tester, 'ec_cd_basis');
      expect(tester.takeException(), isNull, reason: '근거 보기');
      await tapKey(tester, 'ec_cd_type_pf');
      await pickDropdown(tester, 'ec_cd_size', '42 (내경 42mm)');
      expect(tester.takeException(), isNull, reason: 'PF 42');
    });

    testWidgets('AWG 선정·점검·전압강하가 넘치지 않는다', (tester) async {
      await pumpNarrow(tester);
      await openTab(tester, 'ec_tab_cable');
      await tapKey(tester, 'ec_cable_unit_awg');
      await type(tester, 'ec_ib', '150');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'AWG 선정');
      await basisOf(tester, 'ec_cable_basis');
      expect(tester.takeException(), isNull, reason: 'AWG 근거');
      await tapKey(tester, 'ec_mode_check');
      await type(tester, 'ec_chk_breaker', '200');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'AWG 점검');
      await openTab(tester, 'ec_tab_vd');
      await type(tester, 'ec_vd_i', '10');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'AWG 전압강하');
    });
  });
}
