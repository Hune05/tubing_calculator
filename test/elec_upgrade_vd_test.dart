// 전기 설비 계산 2026-09-27 개선: 전압강하 탭의 기동 방식·기동 판정·전원 쪽 강하·허용전류 점검 넘기기,
// 역률·효율 100% 초과 입력 확인, 이상한 전압·상 조합 경고, 역률 개선 과보상 경고.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_calc.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';

Future<void> pumpPage(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: ElectricCalculatorPage()));
  await tester.pumpAndSettle();
}

String textIn(WidgetTester tester, Key key) => tester
    .widgetList<Text>(
      find.descendant(of: find.byKey(key), matching: find.byType(Text)),
    )
    .map((t) => t.data ?? '')
    .join('\n');

Future<void> reveal(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    final s = find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    try {
      await tester.scrollUntilVisible(f, 200, scrollable: s, maxScrolls: 40);
    } catch (_) {
      await tester.scrollUntilVisible(f, -200, scrollable: s, maxScrolls: 40);
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

Future<void> type(WidgetTester tester, String key, String text) async {
  await reveal(tester, find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> openVd(WidgetTester tester) async {
  await pumpPage(tester);
  await openTab(tester, 'ec_tab_vd');
}

void main() {
  group('최대 길이: 전원 쪽 강하만큼 줄인다', () {
    double maxLen(double reserved) => maxLengthForDrop(
      current: 200,
      size: 25,
      phase: Phase.three,
      volts: 380,
      reservedPct: reserved,
    )!;

    test('한도 5% 중 2%를 전원 쪽이 썼으면 이 회로에는 3%: 길이는 3/5', () {
      final l0 = maxLen(0);
      expect(l0, lessThan(100));
      expect(maxLen(2), closeTo(l0 * 3 / 5, 1e-9));
    });

    test('전원 쪽 강하가 한도 이상이면 길이를 낼 수 없다', () {
      expect(
        maxLengthForDrop(
          current: 20,
          size: 4,
          phase: Phase.three,
          volts: 380,
          reservedPct: 5,
        ),
        isNull,
      );
    });
  });

  testWidgets('전압강하 탭: Y-Δ는 직입의 1/3로 계산한다(20A ×6 → 2배, 14.88V 3.9%)', (
    tester,
  ) async {
    await openVd(tester);
    await type(tester, 'ec_vd_i', '20');
    await type(tester, 'ec_vd_len', '100');
    await tapKey(tester, 'ec_vd_start');
    var r = textIn(tester, const Key('ec_vd_result'));
    expect(r, contains('기동 시(정격 ×6, 역률 0.35) 44.63 V (11.7%)'));
    await tapKey(tester, 'ec_vd_sm_yd');
    r = textIn(tester, const Key('ec_vd_result'));
    expect(r, contains('기동 시(정격 ×2, 역률 0.35) 14.88 V (3.9%)'));
  });

  testWidgets('전압강하 탭: 허용 기동 전압강하를 넣으면 합격/불합격, 전원 쪽 강하는 합산', (tester) async {
    await openVd(tester);
    await type(tester, 'ec_vd_i', '20');
    await type(tester, 'ec_vd_len', '100');
    await tapKey(tester, 'ec_vd_start');
    var r = textIn(tester, const Key('ec_vd_result'));
    expect(r, isNot(contains('허용 기동 전압강하')), reason: '비우면 판정하지 않는다');
    await type(tester, 'ec_vd_startlim', '10');
    r = textIn(tester, const Key('ec_vd_result'));
    expect(r, contains('허용 기동 전압강하 10%를 초과합니다(불합격)'));
    await tapKey(tester, 'ec_vd_sm_yd');
    r = textIn(tester, const Key('ec_vd_result'));
    expect(r, contains('허용 기동 전압강하 10% 이내입니다(합격)'));
    // 전원 쪽 강하 6%를 더하면 Y-Δ도 3.9 + 6 = 9.9%이고, 7%면 10.9%로 불합격.
    await type(tester, 'ec_vd_up', '6');
    r = textIn(tester, const Key('ec_vd_result'));
    expect(r, contains('전원 쪽 포함 기동 시 합계 9.9%'));
    expect(r, contains('이내입니다(합격)'));
    await type(tester, 'ec_vd_up', '7');
    r = textIn(tester, const Key('ec_vd_result'));
    expect(r, contains('허용 기동 전압강하 10%를 초과합니다(불합격)'));
    // 평상시 합계도 한도 5%와 비교한다.
    expect(r, contains('합계'));
    expect(r, contains('한도 5% 초과'));
  });

  testWidgets('전압강하 탭: 이 굵기로 허용전류 점검 → 전선 굵기 탭 기존 회로 점검', (tester) async {
    await openVd(tester);
    await type(tester, 'ec_vd_i', '33');
    await type(tester, 'ec_vd_len', '77');
    await tapKey(tester, 'ec_vd_to_check');
    final chip = tester.widget<ChoiceChip>(
      find.byKey(const Key('ec_mode_check')),
    );
    expect(chip.selected, isTrue);
    expect(
      tester.widget<TextField>(find.byKey(const Key('ec_ib'))).controller!.text,
      '33',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('ec_length')))
          .controller!
          .text,
      '77',
    );
  });

  testWidgets('역률·효율이 100%를 넘으면 입력 확인(조용히 100%로 자르지 않는다)', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'ec_tab_load');
    await type(tester, 'ec_kw', '11');
    await type(tester, 'ec_pf', '120');
    final r = textIn(tester, const Key('ec_load_result'));
    expect(r, contains('입력 확인'));
    expect(r, contains('역률·효율은 100%를 초과할 수 없습니다'));
    await type(tester, 'ec_pf', '85');
    expect(
      textIn(tester, const Key('ec_load_result')),
      isNot(contains('입력 확인')),
    );
  });

  testWidgets('110V 삼상·480V 단상은 확인하라는 글이 뜬다', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'ec_tab_load');
    expect(find.byKey(const Key('ec_odd_system')), findsNothing);
    await tapKey(tester, 'ec_v_110');
    await tapKey(tester, 'ec_ph_3');
    expect(find.byKey(const Key('ec_odd_system')), findsOneWidget);
    await tapKey(tester, 'ec_v_480');
    await tapKey(tester, 'ec_ph_1');
    expect(find.textContaining('480V 단상은 보통 없는 조합입니다'), findsOneWidget);
    await tapKey(tester, 'ec_ph_3');
    expect(find.byKey(const Key('ec_odd_system')), findsNothing);
  });

  testWidgets('역률 개선: 목표 역률이 95%를 넘으면 과보상 경고', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'ec_tab_pf');
    await type(tester, 'ec_pc_kw', '100');
    expect(
      textIn(tester, const Key('ec_pf_result')),
      isNot(contains('95%를 초과합니다')),
    );
    await type(tester, 'ec_pc_target', '98');
    expect(
      textIn(tester, const Key('ec_pf_result')),
      contains('목표 역률이 95%를 초과합니다'),
    );
  });
}
