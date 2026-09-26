// 4-20mA 계산기 화면 — 환산, 교정 점검 판정, 루프 전압, 좁은 폰.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/instrument/signal_calculator_page.dart';

Future<void> pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: SignalCalculatorPage()));
  await tester.pumpAndSettle();
}

String textIn(WidgetTester tester, Key key) => tester
    .widgetList<Text>(
      find.descendant(of: find.byKey(key), matching: find.byType(Text)),
    )
    .map((t) => t.data ?? '')
    .join('\n');

Future<void> openTab(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('환산: 0~10bar에서 12mA → 5 bar, 50%, 5점 표', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byKey(const Key('sg_value')), '12');
    await tester.pump();
    final r = textIn(tester, const Key('sg_conv_result'));
    expect(r, startsWith('측정값\n5 bar'));
    expect(r, contains('측정 범위의 50%'));
    expect(r, contains('3 V (250Ω)'));
    expect(r, contains('정상 구간'));
    final t = textIn(tester, const Key('sg_table'));
    expect(t, contains('7.5 bar'));
    expect(t, contains('16'));
  });

  testWidgets('환산: 측정값 7.5 → 16mA, 3.5mA는 고장 신호 알림', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('sg_in_pv')));
    await tester.enterText(find.byKey(const Key('sg_value')), '7.5');
    await tester.pump();
    expect(textIn(tester, const Key('sg_conv_result')), contains('16 mA'));
    await tester.tap(find.byKey(const Key('sg_in_ma')));
    await tester.enterText(find.byKey(const Key('sg_value')), '3.5');
    await tester.pump();
    expect(textIn(tester, const Key('sg_conv_result')), contains('고장 신호(낮음)'));
  });

  testWidgets('교정 점검: ±0.5%, 50% 점 12.1mA → 넘음, 나머지 정상', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'sg_tab_cal');
    await tester.tap(find.byKey(const Key('sc_tol_0.5')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('sc_read_0')), '4.02');
    await tester.enterText(find.byKey(const Key('sc_read_2')), '12.1');
    await tester.enterText(find.byKey(const Key('sc_read_4')), '19.96');
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('sc_err_0'))).data,
      contains('+0.13% · +0.02 mA'),
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('sc_err_2'))).data,
      endsWith('넘음'),
    );
    final r = textIn(tester, const Key('sg_cal_result'));
    expect(r, contains('+0.63%'));
    expect(r, contains('허용 오차 넘음 — 1점이 ±0.5% 밖'));
    expect(r, contains('넘은 점: 50%'));
    // 고치고 나면 정상
    await tester.enterText(find.byKey(const Key('sc_read_2')), '12.03');
    await tester.pump();
    expect(
      textIn(tester, const Key('sg_cal_result')),
      contains('정상 — 3점 모두 ±0.5% 안'),
    );
  });

  testWidgets('교정 점검: 범위를 환산 탭에서 바꾸면 같이 바뀌고, 지시값으로도 셈', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byKey(const Key('sg_urv')), '200');
    await tester.enterText(find.byKey(const Key('sg_unit')), 'C');
    await openTab(tester, 'sg_tab_cal');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('sc_urv')))
          .controller!
          .text,
      '200',
    );
    await tester.tap(find.byKey(const Key('sc_kind_pv')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('sc_read_2')), '99.2');
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('sc_err_2'))).data,
      '오차 -0.4% · -0.064 mA · -0.8 C',
    );
  });

  testWidgets('루프 전압: 24V·250Ω·1.5sq 500m → 21mA에서 18.5V 충분', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'sg_tab_loop');
    await tester.enterText(find.byKey(const Key('sl_len')), '500');
    await tester.pump();
    final r = textIn(tester, const Key('sl_result'));
    // 1.5sq 20°C 12.1Ω/km × 1km = 12.1Ω, 합 262.1Ω → 24 − 0.021 × 262.1 = 18.4959
    expect(r, contains('18.5 V'));
    expect(r, contains('충분합니다'));
    expect(r, contains('루프 저항 합 262.1Ω'));
    await tester.enterText(find.byKey(const Key('sl_hart')), '700');
    await tester.pump();
    expect(textIn(tester, const Key('sl_result')), contains('20mA도 못 냅니다'));
  });

  testWidgets('좁은 폰(344)·큰 글씨에서 세 탭이 넘치지 않는다', (tester) async {
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
        home: const SignalCalculatorPage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sg_value')), '12');
    await tester.pump();
    expect(tester.takeException(), isNull);
    for (final t in ['sg_tab_cal', 'sg_tab_loop', 'sg_tab_conv']) {
      await tester.tap(find.byKey(Key(t)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: t);
    }
    await tester.tap(find.byKey(const Key('sg_tab_cal')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sc_read_0')), '4.02');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
