// "최근 계산 기록"을 눌러 그때 입력값으로 되돌리기(2026-10-07): 같은 탭·다른 탭·원래대로.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/electric_calculator_page.dart';

String _text(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
  // 기록은 값이 0.7초 머물러야 쌓인다.
  await tester.pump(const Duration(milliseconds: 800));
}

Future<void> _openHistory(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('calc_history_button')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> open(WidgetTester tester, int tab) async {
    tester.view.physicalSize = const Size(390, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: ElectricCalculatorPage(initialTab: tab)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('부하 전류: 지난 기록을 누르면 그때 kW로 돌아오고, 원래대로를 누르면 다시 지금 값', (tester) async {
    await open(tester, 1);
    await _type(tester, 'ec_kw', '11');
    await _type(tester, 'ec_kw', '22');
    await _openHistory(tester);
    // 맨 위가 최근(22), 그 아래가 11. 되돌릴 수 있는 기록에는 ↻ 표시가 있다.
    expect(find.byIcon(Icons.replay_rounded), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('calc_history_item_1')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'ec_kw'), '11');
    // 기록 창을 열 때 키보드를 닫아, 창을 닫은 뒤 키보드가 알림을 가리지 않는다.
    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.text('그때 입력값으로 되돌렸습니다'), findsOneWidget);
    await tester.tap(find.text('원래대로'));
    await tester.pumpAndSettle();
    expect(_text(tester, 'ec_kw'), '22');
  });

  testWidgets('다른 탭(발전기 용량) 기록을 누르면 그 탭으로 넘어가 그때 부하 줄을 넣는다', (tester) async {
    await open(tester, 9);
    await _type(tester, 'eg_row_kw_0', '100');
    await _type(tester, 'eg_row_eff_0', '85');
    await _type(tester, 'eg_row_pf_0', '80');
    await _type(tester, 'eg_g_k', '1');
    // 전동기 공식 탭으로 옮겨 놓고 발전기 값을 바꾼다.
    await _type(tester, 'eg_row_kw_0', '50');
    await tester.ensureVisible(find.text('전동기 공식').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('전동기 공식').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('eg_row_kw_0')).hitTestable(), findsNothing);
    await _openHistory(tester);
    // 전동기 공식 탭 기록이 맨 위에 쌓이므로 100 kW 때 결과(필요 147 kVA) 기록을 글로 찾아 누른다.
    await tester.tap(find.textContaining('필요 147 kVA'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('eg_row_kw_0')).hitTestable(), findsOneWidget);
    expect(_text(tester, 'eg_row_kw_0'), '100');
    expect(find.textContaining('147.1 kVA'), findsWidgets);
  });
}
