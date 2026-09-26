// 압력 시험 계산기 화면 — 시험 압력·절차, 단위, 압력 강하, 저장 에너지, 구멍 누설, 좁은 폰.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_test_page.dart';

Future<void> pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: PressureTestPage()));
  await tester.pumpAndSettle();
}

String textIn(WidgetTester tester, Key key) => tester
    .widgetList<Text>(
      find.descendant(of: find.byKey(key), matching: find.byType(Text)),
    )
    .map((t) => t.data ?? '')
    .join('\n');

void main() {
  testWidgets('B31.3 수압 설계 10bar → 15bar 이상, 절차·조항', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byKey(const Key('pt_design')), '10');
    await tester.pump();
    final r = textIn(tester, const Key('pt_plan_result'));
    expect(r, contains('15 bar 이상'));
    expect(r, contains('10분 이상'));
    expect(textIn(tester, const Key('pt_steps')), contains('345.2.2(a)'));
  });

  testWidgets('B31.1 공압 10bar → 12~15bar, 점검 압력 7bar(700kPa)', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('pt_b311')));
    await tester.tap(find.byKey(const Key('pt_pneu')));
    await tester.enterText(find.byKey(const Key('pt_design')), '10');
    await tester.pump();
    final r = textIn(tester, const Key('pt_plan_result'));
    expect(r, contains('12 ~ 15 bar'));
    expect(r, contains('누설 점검 압력: 7 bar'));
  });

  testWidgets('실제 시험 압력 13.3bar → 안전밸브 14.63bar, 범위 밖이면 알림', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('pt_pneu')));
    await tester.enterText(find.byKey(const Key('pt_design')), '10');
    await tester.enterText(find.byKey(const Key('pt_actual')), '13.3');
    await tester.pump();
    var r = textIn(tester, const Key('pt_plan_result'));
    expect(r, contains('범위 안입니다'));
    expect(r, contains('안전밸브 설정: 14.63 bar 이하 (시험 압력 13.3 bar 기준)'));
    await tester.enterText(find.byKey(const Key('pt_actual')), '14');
    await tester.pump();
    r = textIn(tester, const Key('pt_plan_result'));
    expect(r, contains('최대 시험 압력을 넘습니다'));
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

  testWidgets('압력 강하: 7bar 20°C → 6.73bar 10°C는 온도 때문(실제 강하 거의 0)', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('pt_tab_decay')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('pt_p1')), '7');
    await tester.enterText(find.byKey(const Key('pt_p2')), '6.7266');
    await tester.enterText(find.byKey(const Key('pt_t2')), '10');
    await tester.pump();
    final r = textIn(tester, const Key('pt_decay_result'));
    expect(r, contains('온도 때문에 바뀐 몫'));
    expect(r, startsWith('온도를 보정한 실제 압력 강하\n0 bar'));
  });

  testWidgets('저장 에너지: 21.72bar, 체적 500L → 30m, 약 1.68MJ', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('pt_tab_energy')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('pt_se_pt')), '21.72');
    await tester.enterText(find.byKey(const Key('pt_se_vol')), '500');
    await tester.pump();
    final r = textIn(tester, const Key('pt_energy_result'));
    expect(r, contains('30 m'));
    expect(r, contains('1.68 MJ'));
  });

  testWidgets('구멍 누설: 3mm 7bar 둥근 구멍 → L/min·kW·kWh', (tester) async {
    await pumpPage(tester);
    await tester.ensureVisible(find.byKey(const Key('pt_tab_leak')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pt_tab_leak')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('pt_price')), '150');
    await tester.pump();
    final r = textIn(tester, const Key('pt_leak_result'));
    // 0.154·0.97·9·8.01 = 10.77 L/s = 646 L/min
    expect(r, contains('646'));
    expect(r, contains('kWh'));
    expect(r, contains('만 원'));
  });

  testWidgets('좁은 폰(344)·큰 글씨에서 네 탭이 넘치지 않는다', (tester) async {
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
    await tester.enterText(find.byKey(const Key('pt_design')), '100');
    await tester.pump();
    expect(tester.takeException(), isNull);
    for (final t in ['pt_tab_decay', 'pt_tab_energy', 'pt_tab_leak', 'pt_tab_plan']) {
      await tester.ensureVisible(find.byKey(Key(t)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(t)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: t);
      expect(
        tester.widget<TabBar>(find.byType(TabBar)).controller!.index,
        ['pt_tab_plan', 'pt_tab_decay', 'pt_tab_energy', 'pt_tab_leak'].indexOf(t),
      );
    }
  });
}
