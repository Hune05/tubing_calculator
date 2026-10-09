// 공학용 계산기 안의 "단위 환산" 화면: 분류 고르기(슬라이더)·값 넣기·단위 맞바꾸기.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/field_tools/mini_unit_converter_page.dart';
import 'package:tubing_calculator/src/presentation/unit_converter/unit_defs.dart';

String toValue(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('unit_to_value'))).data!;

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MiniUnitConverterPage()));
    await tester.pump();
  }

  /// 슬라이더를 직접 그 분류 값으로 옮긴다(드래그 좌표 계산 없이 값만 바꿔 확인).
  Future<void> pickCategory(WidgetTester tester, UnitCategory c) async {
    final idx = kMiniConvertCategories.indexOf(c).toDouble();
    final slider = tester.widget<Slider>(
      find.byKey(const Key('unit_cat_slider')),
    );
    slider.onChanged!(idx);
    await tester.pump();
  }

  testWidgets('처음에는 길이 분류(mm→cm)가 골라져 있고, 1000mm은 100cm이다', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('unit_cat_label')), findsOneWidget);
    expect(find.text('길이'), findsOneWidget);
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

  testWidgets('슬라이더로 분류를 온도로 옮기면 섭씨→화씨로 다시 골라지고 0°C=32°F', (tester) async {
    await pump(tester);
    await pickCategory(tester, kTemperature);
    expect(find.text('온도'), findsOneWidget);
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

  testWidgets('변환하면 "최근 계산 기록"에 쌓인다', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('unit_from_value')), '1000');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800)); // 디바운스 지나가기
    await tester.tap(find.byKey(const Key('calc_history_button')));
    await tester.pumpAndSettle();
    expect(find.text('최근 계산 기록'), findsOneWidget);
    expect(find.textContaining('1000 mm'), findsWidgets);
  });

  testWidgets('기록을 눌러 되돌리면 커서가 글 끝에 있다(8차)', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('unit_from_value')), '1000');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.enterText(find.byKey(const Key('unit_from_value')), '5');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.byKey(const Key('calc_history_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('1000 mm').first);
    await tester.pumpAndSettle();
    final c = tester.widget<TextField>(find.byKey(const Key('unit_from_value'))).controller!;
    expect(c.text, '1000');
    expect(c.selection.baseOffset, 4);
  });
}
