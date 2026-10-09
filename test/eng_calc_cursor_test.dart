// 공학용 계산기: 식 가운데 고치기(식 글을 눌러 자리 정하기), 기록에서 식째 불러오기(10-09).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/field_tools/eng_calculator_page.dart';

Future<void> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: EngCalculatorPage()));
  await tester.pump();
  await tester.pump();
}

Future<void> _keys(WidgetTester tester, List<String> keys) async {
  for (final k in keys) {
    await tester.tap(find.byKey(Key(k)));
    await tester.pump();
  }
}

TextEditingController _ctrl(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(const Key('calc_expr'))).controller!;

String _expr(WidgetTester tester) => _ctrl(tester).text;

String _result(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('calc_display_result'))).data!;

/// 식 글을 눌러 [offset] 자리에 고칠 자리를 둔 것과 같다.
Future<void> _cursorAt(WidgetTester tester, int offset) async {
  _ctrl(tester).selection = TextSelection.collapsed(offset: offset);
  await tester.pump();
}

void main() {
  testWidgets('식 가운데를 눌러 숫자를 넣고, ⌫로 그 자리 앞 글자를 지운다', (tester) async {
    await _pump(tester);
    await _keys(tester, ['calc_1', 'calc_2', 'calc_add', 'calc_3']);
    expect(_expr(tester), '12+3');
    await _cursorAt(tester, 1); // 1|2+3
    await _keys(tester, ['calc_5']);
    expect(_expr(tester), '152+3');
    expect(_result(tester), '155');
    expect(_ctrl(tester).selection.baseOffset, 2); // 넣은 글자 뒤로 자리가 옮겨 간다
    await _keys(tester, ['calc_back']);
    expect(_expr(tester), '12+3');
    expect(_result(tester), '15');
    // 그 자리에서 연산자도 넣는다: 1×2+3
    await _keys(tester, ['calc_mul']);
    expect(_expr(tester), '1×2+3');
    expect(_result(tester), '5');
  });

  testWidgets('맨 앞에 빼기를 넣으면 음수 부호가 된다', (tester) async {
    await _pump(tester);
    await _keys(tester, ['calc_1', 'calc_2', 'calc_add', 'calc_3']);
    await _cursorAt(tester, 0);
    await _keys(tester, ['calc_sub']);
    expect(_expr(tester), '-12+3');
    expect(_result(tester), '-9');
  });

  testWidgets('맨 끝을 누르면 예전처럼 뒤에 붙는다', (tester) async {
    await _pump(tester);
    await _keys(tester, ['calc_1', 'calc_add', 'calc_2']);
    await _cursorAt(tester, 1);
    await _cursorAt(tester, 3); // 다시 맨 끝
    await _keys(tester, ['calc_4']);
    expect(_expr(tester), '1+24');
  });

  testWidgets('= 뒤 결과 글자를 눌러 고치면 새 식으로 지우지 않는다', (tester) async {
    await _pump(tester);
    await _keys(tester, ['calc_2', 'calc_add', 'calc_3', 'calc_eq']);
    expect(_expr(tester), '5');
    await _cursorAt(tester, 0);
    await _keys(tester, ['calc_1']);
    expect(_expr(tester), '15');
    expect(_result(tester), '15');
  });

  testWidgets('= 은 식 전체로 계산하고, 가운데에서 치던 분수는 그 자리에 들어간다', (tester) async {
    await _pump(tester);
    await _keys(tester, ['calc_2', 'calc_add', 'calc_3']);
    await _cursorAt(tester, 2); // 2+|3
    await _keys(tester, ['calc_frac_key', 'calc_1', 'calc_frac_den', 'calc_2']);
    await _keys(tester, ['calc_eq']);
    // 2+(1/2)×3 = 3.5
    expect(find.text('2+(1/2)×3 = 3.5'), findsOneWidget);
    expect(_result(tester), '3.5');
  });

  testWidgets('식 글을 눌러도 폰 자판이 뜨지 않는다', (tester) async {
    await _pump(tester);
    await _keys(tester, ['calc_1', 'calc_add', 'calc_2']);
    await tester.tap(find.byKey(const Key('calc_expr')));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('기록 줄을 길게 누르면 식을 불러와 고칠 수 있다', (tester) async {
    await _pump(tester);
    await _keys(tester, ['calc_1', 'calc_2', 'calc_mul', 'calc_3', 'calc_eq']);
    await _keys(tester, ['calc_ac']);
    await tester.longPress(find.byKey(const Key('calc_history_item_0')));
    await tester.pumpAndSettle();
    expect(find.text('식 불러와 고치기'), findsOneWidget);
    await tester.tap(find.byKey(const Key('calc_hist_load')));
    await tester.pumpAndSettle();
    expect(_expr(tester), '12×3');
    expect(_result(tester), '36');
    // 불러온 식의 12를 15로
    await _cursorAt(tester, 2);
    await _keys(tester, ['calc_back', 'calc_5']);
    expect(_expr(tester), '15×3');
    expect(_result(tester), '45');
  });

  testWidgets('기록 줄 길게 누름 → "결과만 넣기"는 누를 때와 같다', (tester) async {
    await _pump(tester);
    await _keys(tester, ['calc_2', 'calc_add', 'calc_3', 'calc_eq']);
    await _keys(tester, ['calc_ac', 'calc_4', 'calc_mul']);
    await tester.longPress(find.byKey(const Key('calc_history_item_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calc_hist_value')));
    await tester.pumpAndSettle();
    expect(_expr(tester), '4×5');
    expect(_result(tester), '20');
  });
  testWidgets('가운데에서 지울 때는 곱하기를 다시 붙이지 않는다', (tester) async {
    await _pump(tester);
    await _keys(tester, ['calc_lparen', 'calc_1', 'calc_rparen', 'calc_3']);
    expect(_expr(tester), '(1)×3');
    await _cursorAt(tester, 4); // (1)×|3
    await _keys(tester, ['calc_back']);
    expect(_expr(tester), '(1)3');
    // 그 자리에 다시 +를 넣으면 (1)+3
    await _keys(tester, ['calc_add']);
    expect(_expr(tester), '(1)+3');
    expect(_result(tester), '4');
  });
}
