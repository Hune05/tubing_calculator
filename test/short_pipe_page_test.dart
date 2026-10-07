// 단관 컷팅 화면: 길이 × 개수를 넣으면 원자재 본수·자르는 눈금이 나오고, 적은 것은 기억한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/short_pipe_cutting_page.dart';

Future<void> open(WidgetTester tester, {Size size = const Size(400, 900)}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: ShortPipeCuttingPage()));
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pumpAndSettle();
}

String allText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text, skipOffstage: false))
    .map((t) => t.data ?? '')
    .join('\n');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('처음에는 안내 글만 나온다', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('sp_empty')), findsOneWidget);
    expect(find.byKey(const Key('sp_bar_0')), findsNothing);
  });

  testWidgets('250mm 24개, 톱날 0 → 원자재 1본, 자르는 눈금이 250씩 늘어난다', (tester) async {
    await open(tester);
    await enter(tester, 'sp_len_0', '250');
    await enter(tester, 'sp_qty_0', '24');
    expect(find.byKey(const Key('sp_bar_0')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('sp_mark_0_0'))).data, '250');
    expect(tester.widget<Text>(find.byKey(const Key('sp_mark_0_1'))).data, '500');
    expect(tester.widget<Text>(find.byKey(const Key('sp_mark_0_23'))).data, '6000');
    expect(allText(tester), contains('1본'));
    expect(allText(tester), contains('24개'));
  });

  testWidgets('개수를 "1,000"처럼 써도 읽는다(10-08: 그 줄이 말없이 빠졌다)', (tester) async {
    await open(tester);
    await enter(tester, 'sp_len_0', '250');
    await enter(tester, 'sp_qty_0', '1,000');
    expect(find.byKey(const Key('sp_bar_0')), findsOneWidget);
    expect(allText(tester), contains('1000개'));
  });

  testWidgets('톱날 3mm로 바꾸면 두 본이 필요하다', (tester) async {
    await open(tester);
    await enter(tester, 'sp_len_0', '250');
    await enter(tester, 'sp_qty_0', '24');
    await enter(tester, 'sp_kerf', '3');
    expect(find.byKey(const Key('sp_bar_0')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('sp_mark_0_1'))).data, '503');
    // 둘째 본은 아래에 있어서 내려야 보인다.
    await tester.scrollUntilVisible(
      find.byKey(const Key('sp_bar_1')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('sp_bar_1')), findsOneWidget);
  });

  testWidgets('중심 간 거리 입력: 부속 공제를 빼고 센다', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('sp_mode_c2c')));
    await tester.pumpAndSettle();
    await enter(tester, 'sp_ded', '12.5');
    await enter(tester, 'sp_len_0', '300');
    await enter(tester, 'sp_qty_0', '2');
    expect(tester.widget<Text>(find.byKey(const Key('sp_mark_0_0'))).data, '275');
  });

  testWidgets('공제값이 길이 이상이면 간섭이라고 알리고 막는다', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('sp_mode_c2c')));
    await tester.pumpAndSettle();
    await enter(tester, 'sp_ded', '15');
    await enter(tester, 'sp_len_0', '20');
    await enter(tester, 'sp_qty_0', '3');
    expect(find.byKey(const Key('sp_problems')), findsOneWidget);
    expect(allText(tester), contains('간섭'));
    expect(find.byKey(const Key('sp_bar_0')), findsNothing);
  });

  testWidgets('원자재보다 긴 조각은 자를 수 없다고 알린다', (tester) async {
    await open(tester);
    await enter(tester, 'sp_len_0', '7000');
    await enter(tester, 'sp_qty_0', '1');
    expect(allText(tester), contains('자를 수 없습니다'));
  });

  testWidgets('줄을 더하고 지울 수 있고, 한 줄만 남으면 지우기가 막힌다', (tester) async {
    await open(tester);
    expect(tester.widget<IconButton>(find.byKey(const Key('sp_del_0'))).onPressed, isNull);
    await tester.ensureVisible(find.byKey(const Key('sp_add')));
    await tester.tap(find.byKey(const Key('sp_add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sp_len_1')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('sp_del_1')));
    await tester.tap(find.byKey(const Key('sp_del_1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sp_len_1')), findsNothing);
  });

  testWidgets('적은 것을 기억해서 다시 열면 되살린다', (tester) async {
    await open(tester);
    await enter(tester, 'sp_len_0', '400');
    await enter(tester, 'sp_qty_0', '5');
    await tester.pumpWidget(const SizedBox());
    await open(tester);
    expect(tester.widget<TextField>(find.byKey(const Key('sp_len_0'))).controller!.text, '400');
    expect(tester.widget<TextField>(find.byKey(const Key('sp_qty_0'))).controller!.text, '5');
  });

  testWidgets('튜브 컷팅의 원자재 길이·톱날을 이어받는다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'cutting_stock_length': 3000.0,
      'cutting_blade_kerf': 2.5,
    });
    await open(tester);
    expect(tester.widget<TextField>(find.byKey(const Key('sp_stock'))).controller!.text, '3000');
    expect(tester.widget<TextField>(find.byKey(const Key('sp_kerf'))).controller!.text, '2.5');
  });

  for (final w in [320.0, 360.0]) {
    testWidgets('폭 $w에서 넘치지 않는다', (tester) async {
      await open(tester, size: Size(w, 700));
      await tester.tap(find.byKey(const Key('sp_mode_c2c')));
      await tester.pumpAndSettle();
      await enter(tester, 'sp_ded', '12');
      await enter(tester, 'sp_len_0', '1234.5');
      await enter(tester, 'sp_qty_0', '40');
      expect(tester.takeException(), isNull);
    });
  }
}
