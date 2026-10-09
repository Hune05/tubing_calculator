// 10-09: 기준선 오프셋에 음수를 넣을 수 없었다(숫자판에 − 없음) → allowNegative면 "±" 단추.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad.dart';

void main() {
  Future<TextEditingController> open(WidgetTester tester, {required bool neg}) async {
    final ctrl = TextEditingController(text: '0');
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => MakitaNumpad.show(
                context,
                controller: ctrl,
                title: '기준선 오프셋',
                allowNegative: neg,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    return ctrl;
  }

  testWidgets('±로 부호를 바꾸고 적용하면 음수가 남는다', (tester) async {
    final ctrl = await open(tester, neg: true);
    expect(find.text('00'), findsNothing);
    await tester.tap(find.text('1'));
    await tester.tap(find.text('5'));
    await tester.tap(find.text('±'));
    await tester.pump();
    expect(ctrl.text, '-15');
    await tester.tap(find.text('±'));
    await tester.pump();
    expect(ctrl.text, '15');
    await tester.tap(find.text('±'));
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    expect(double.parse(ctrl.text), -15);
  });

  testWidgets('다른 칸은 예전처럼 00 단추(± 없음)', (tester) async {
    await open(tester, neg: false);
    expect(find.text('00'), findsOneWidget);
    expect(find.text('±'), findsNothing);
  });
}
