// 전기 설계 계산 2026-09-27 후속: 부하 합산 → 단락 전류로 변압기 값 넘기기, 새 탭이 탭을 옮겨도 입력을 지니는지,
// 단락 전류 요약 줄이 선택 칸 때문에 붉어지지 않는지, 발전기 효율·역률을 % 로 받는지.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';

Future<void> pumpPage(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: ElectricCalculatorPage()));
  await tester.pumpAndSettle();
}

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

Future<void> type(WidgetTester tester, String key, String text) async {
  await reveal(tester, find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await reveal(tester, find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

String fieldText(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

String textIn(WidgetTester tester, Key key) => tester
    .widgetList<Text>(
      find.descendant(of: find.byKey(key), matching: find.byType(Text)),
    )
    .map((t) => t.data ?? '')
    .join('\n');

void main() {
  testWidgets('부하 합산 → 단락 전류: 필요 용량과 2차 전압을 넘기고 단락 전류 탭이 열린다', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'ec_tab_loadsum');
    await type(tester, 'els_kw_0', '100');
    await type(tester, 'els_pf_0', '90');
    await type(tester, 'els_df_0', '80');
    await tapKey(tester, 'els_v_440');
    // 선정 용량을 안 넣었으니 필요 용량 88.9 kVA를 넘긴다.
    await tapKey(tester, 'els_to_short');
    expect(
      tester.widget<TabBar>(find.byType(TabBar)).controller!.index,
      5,
      reason: '단락 전류 탭',
    );
    expect(fieldText(tester, 'ec_sc_kva'), '88.9');
    expect(fieldText(tester, 'ec_sc_volts'), '440');
  });

  testWidgets('선정 변압기 용량을 넣었으면 그 값을 넘긴다', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'ec_tab_loadsum');
    await type(tester, 'els_kw_0', '100');
    await type(tester, 'els_pf_0', '90');
    await type(tester, 'els_df_0', '80');
    await type(tester, 'els_selected', '150');
    await tapKey(tester, 'els_to_short');
    expect(fieldText(tester, 'ec_sc_kva'), '150');
    expect(fieldText(tester, 'ec_sc_volts'), '380');
    // 다시 넘기면(값을 고친 뒤) 새 값으로 덮는다.
    await openTab(tester, 'ec_tab_loadsum');
    await type(tester, 'els_selected', '200');
    await tapKey(tester, 'els_to_short');
    expect(fieldText(tester, 'ec_sc_kva'), '200');
  });

  testWidgets('탭을 옮겨 돌아와도 새 탭의 입력이 남아 있다', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'ec_tab_short');
    await type(tester, 'ec_sc_kva', '750');
    await openTab(tester, 'ec_tab_basic');
    await openTab(tester, 'ec_tab_gen');
    await type(tester, 'eg_load', '123');
    await openTab(tester, 'ec_tab_short');
    expect(fieldText(tester, 'ec_sc_kva'), '750');
    await openTab(tester, 'ec_tab_gen');
    expect(fieldText(tester, 'eg_load'), '123');
  });

  testWidgets('단락 전류: 선택 칸을 비웠다고 요약 줄이 붉어지지 않는다', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'ec_tab_short');
    await type(tester, 'ec_sc_kva', '1000');
    await type(tester, 'ec_sc_volts', '380');
    await type(tester, 'ec_sc_z', '5.5');
    final sum = find.byKey(const Key('ec_sc_sum'));
    expect(sum, findsOneWidget);
    expect(textIn(tester, const Key('ec_sc_sum')), contains('Ik″ 최대'));
    final box = tester.widget<Container>(sum);
    final color = (box.decoration as BoxDecoration).color;
    expect(color, isNot(Colors.red.shade50));
  });

  testWidgets('발전기: 효율·역률을 %로 넣는다(85, 80). 0.85 꼴도 그대로 받는다', (tester) async {
    await pumpPage(tester);
    await openTab(tester, 'ec_tab_gen');
    expect(fieldText(tester, 'eg_eff'), '85');
    expect(fieldText(tester, 'eg_pf'), '80');
    expect(fieldText(tester, 'eg_demand'), '100');
    await type(tester, 'eg_load', '100');
    // PG1 = 100 ÷ (0.85 × 0.8) = 147.06 kVA.
    final pct = textIn(tester, const Key('eg_result'));
    expect(pct, contains('147.1'));
    await type(tester, 'eg_eff', '0.85');
    await type(tester, 'eg_pf', '0.8');
    expect(textIn(tester, const Key('eg_result')), contains('147.1'));
  });
}
