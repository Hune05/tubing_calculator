// 10-09: 특수 벤딩·오프셋·새들 시트의 숫자판(유리)은 X·바깥 누르기로 닫아도 친 값이 남았다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad_glass.dart';

void main() {
  Future<TextEditingController> open(WidgetTester tester) async {
    final ctrl = TextEditingController(text: '100');
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => MakitaNumpadGlass.show(context, controller: ctrl, title: '높이'),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '5').first, warnIfMissed: false);
    await tester.pump();
    return ctrl;
  }

  testWidgets('X로 닫으면 열 때 값으로 돌아간다', (tester) async {
    final ctrl = await open(tester);
    expect(ctrl.text, isNot('100'));
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(ctrl.text, '100');
  });

  testWidgets('"적용"으로 닫으면 친 값이 남는다', (tester) async {
    final ctrl = await open(tester);
    final typed = ctrl.text;
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    expect(ctrl.text, typed);
    expect(ctrl.text, isNot('100'));
  });
}
