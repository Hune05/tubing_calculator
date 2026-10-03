// 분전반·조명 설계 화면: 입력 → 결과, 상 자동 배정, 간선 구간 추가.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/panel_design_page.dart';

Future<void> _open(WidgetTester tester, {int tab = 0}) async {
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: PanelDesignPage(initialTab: tab)));
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

String _all(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text, skipOffstage: false))
    .map((t) => t.data ?? '')
    .join('\n');

void main() {
  testWidgets('조명: 500 lx 50 m² 3000 lm U 0.6 M 0.8 → 18개, 실제 518 lx', (tester) async {
    await _open(tester);
    expect(_all(tester), contains('을(를) 넣으십시오'));
    await _type(tester, 'pd_lux', '500');
    await _type(tester, 'pd_x', '10');
    await _type(tester, 'pd_y', '5');
    await _type(tester, 'pd_h', '2.5');
    await _type(tester, 'pd_lm', '3000');
    await _type(tester, 'pd_u', '0.6');
    await _type(tester, 'pd_m', '80'); // % 로 넣어도 0.8
    final t = _all(tester);
    expect(t, contains('18개'));
    expect(t, contains('= 17.36개'));
    expect(t, contains('518 lx'));
    expect(t, contains('실지수 K'));
    expect(t, contains('1.33'));
  });

  testWidgets('조명: 조명률이 범위를 벗어나면 오류 안내', (tester) async {
    await _open(tester);
    await _type(tester, 'pd_lux', '500');
    await _type(tester, 'pd_x', '10');
    await _type(tester, 'pd_y', '5');
    await _type(tester, 'pd_lm', '3000');
    await _type(tester, 'pd_u', '0');
    await _type(tester, 'pd_m', '0.8');
    expect(_all(tester), contains('조명률은 0보다 크고'));
  });

  testWidgets('상 평형: 3000·1000·2000 VA → 100 %, 자동 배정 뒤 줄어든다', (tester) async {
    await _open(tester, tab: 1);
    await _type(tester, 'pd_bal_va_0', '3000');
    await _tap(tester, 'pd_bal_add');
    await _type(tester, 'pd_bal_va_1', '1000');
    await _tap(tester, 'pd_bal_ph_1_S');
    await _tap(tester, 'pd_bal_add');
    await _type(tester, 'pd_bal_va_2', '2000');
    await _tap(tester, 'pd_bal_ph_2_T');
    expect(_all(tester), contains('100 %'));
    expect(_all(tester), contains('7.9 A'));
    // 모두 R로 몰아 놓고 자동 배정
    await _tap(tester, 'pd_bal_ph_1_R');
    await _tap(tester, 'pd_bal_ph_2_R');
    expect(_all(tester), contains('300 %'));
    await _tap(tester, 'pd_bal_auto');
    final t = _all(tester);
    expect(t, isNot(contains('300 %')));
    expect(t, contains('불평형률'));
  });

  testWidgets('간선 전압강하: 두 구간 입력 → 구간별·누적, 한도 판정', (tester) async {
    await _open(tester, tab: 2);
    await _type(tester, 'pd_feed_len_0', '30');
    await _type(tester, 'pd_feed_amps_0', '5');
    await _type(tester, 'pd_feed_len_1', '30');
    await _type(tester, 'pd_feed_amps_1', '10');
    final t = _all(tester);
    expect(t, contains('1구간: 30 m, 전류 15 A'));
    expect(t, contains('2구간: 30 m, 전류 10 A'));
    expect(t, contains('한도 3 %'));
    // 구간 추가
    await _tap(tester, 'pd_feed_add');
    expect(find.byKey(const Key('pd_feed_row_2')), findsOneWidget);
    // 길이만 넣으면 오류
    await _type(tester, 'pd_feed_len_2', '10');
    expect(_all(tester), contains('둘 다 넣으십시오'));
  });
}
