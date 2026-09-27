// 공학용 계산기 안의 "간단 단위 변환" 화면: 분류 고르기·값 넣기·단위 맞바꾸기.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/field_tools/mini_unit_converter_page.dart';

String toValue(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('unit_to_value'))).data!;

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MiniUnitConverterPage()));
    await tester.pump();
  }

  testWidgets('처음에는 길이 분류(mm→cm)가 골라져 있고, 1000mm은 100cm이다', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('unit_cat_length')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('unit_from_value')), '1000');
    await tester.pump();
    expect(toValue(tester), '100');
  });

  testWidgets('맞바꾸기 단추를 누르면 보내는·바뀐 단위가 뒤집힌다', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('unit_from_value')), '100');
    await tester.pump();
    expect(toValue(tester), '10'); // 100mm → 10cm.
    await tester.tap(find.byKey(const Key('unit_swap')));
    await tester.pump();
    // 이제 cm→mm이니 같은 글자 "100"을 cm으로 읽어 1000mm이 나온다.
    expect(toValue(tester), '1000');
  });

  testWidgets('분류를 온도로 바꾸면 섭씨→화씨로 다시 골라지고 0°C=32°F', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('unit_cat_temp')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('unit_from_value')), '0');
    await tester.pump();
    expect(toValue(tester), '32');
  });

  testWidgets('숫자가 아니면 바뀐 값 자리에 줄표가 뜬다', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('unit_from_value')), '');
    await tester.pump();
    expect(toValue(tester), '—');
  });
}
