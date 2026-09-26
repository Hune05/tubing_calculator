// 전기 계산기 화면 — 부하 전류 → 전선 굵기 넘기기, 결과 글, 안내 창, 좁은 폰.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';

Future<void> pumpPage(WidgetTester tester, {Size size = const Size(390, 1800)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: ElectricCalculatorPage()));
  await tester.pumpAndSettle();
}

String textIn(WidgetTester tester, Key key) {
  final texts = tester.widgetList<Text>(
    find.descendant(of: find.byKey(key), matching: find.byType(Text)),
  );
  return texts.map((t) => t.data ?? '').join('\n');
}

void main() {
  testWidgets('380V 삼상 11kW 효율 90 역률 85 → 21.8A, 1.25배 27.3A를 전선 탭으로', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.enterText(find.byKey(const Key('ec_kw')), '11');
    await tester.pump();
    final load = textIn(tester, const Key('ec_load_result'));
    expect(load, contains('21.8 A'));
    expect(load, contains('27.3 A (×1.25) 기준'));

    await tester.tap(find.byKey(const Key('ec_to_cable')));
    await tester.pumpAndSettle();
    final ib = tester.widget<TextField>(find.byKey(const Key('ec_ib')));
    expect(ib.controller!.text, '21.8');
    final r = textIn(tester, const Key('ec_cable_result'));
    // 설계 21.8×1.25 = 27.3A → 차단기 30A, F-CV 트레이(E) 3가닥 2.5sq 32A ≥ 30A.
    // 전압강하는 실제 21.8A로: 50m 2.5sq 90°C ≈ 4.0% < 5% → 2.5sq.
    expect(r, contains('설계 전류 27.3A = 부하 21.8A × 1.25'));
    expect(r, contains('차단기 30A'));
    expect(r, contains('허용전류로 보면 2.5sq'));
    expect(r, contains('보호도체(접지선) 2.5sq'));
  });

  testWidgets('HP로 바꾸면 480V 15HP → 전류 계산', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('ec_v_480')));
    await tester.tap(find.byKey(const Key('ec_hp')));
    await tester.enterText(find.byKey(const Key('ec_kw')), '15');
    await tester.pump();
    // 15HP = 11.19kW ÷ (√3·480·0.85·0.9) = 17.6A
    final t = textIn(tester, const Key('ec_load_result'));
    expect(t, contains('17.6 A'));
    expect(t, contains('NEC 430.250 표 (460V) 21 A'));
  });

  testWidgets('380V 11kW면 IE3 전동기 예 22.2A를 같이 보인다', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byKey(const Key('ec_kw')), '11');
    await tester.pump();
    expect(textIn(tester, const Key('ec_load_result')), contains('IE3 4극 60Hz 380V 전동기 예 22.2 A'));
  });

  testWidgets('? 를 누르면 무슨 값을 넣는지 안내 창이 뜬다', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byIcon(Icons.help_outline_rounded).at(1));
    await tester.pumpAndSettle();
    expect(find.textContaining('명판의 정격 출력'), findsOneWidget);
  });

  testWidgets('전압강하 탭: 4sq 20A 100m 삼상 380V → 한도 판정', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('ec_tab_vd')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ec_vd_i')), '20');
    await tester.enterText(find.byKey(const Key('ec_vd_len')), '100');
    await tester.pump();
    final r = textIn(tester, const Key('ec_vd_result'));
    expect(r, contains('%'));
    expect(r, contains('한도'));
  });

  testWidgets('역률 탭: 100kW 80→95% → 42.1 kvar', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('ec_tab_pf')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ec_pc_kw')), '100');
    await tester.pump();
    expect(textIn(tester, const Key('ec_pf_result')), contains('42.1 kvar'));
  });

  testWidgets('좁은 폰(344)·큰 글씨에서 네 탭 모두 넘치지 않는다', (tester) async {
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
    await tester.enterText(find.byKey(const Key('ec_kw')), '75');
    await tester.pump();
    expect(tester.takeException(), isNull);
    for (final t in ['ec_tab_cable', 'ec_tab_vd', 'ec_tab_pf', 'ec_tab_load']) {
      await tester.tap(find.byKey(Key(t)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: t);
    }
  });
}
