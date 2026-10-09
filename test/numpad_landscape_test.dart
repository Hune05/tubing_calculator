// 가로 화면(10-09): 숫자판 창이 낮은 화면에서도 넘치지 않고 모든 단추가 화면 안에 있다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad_glass.dart';

void main() {
  for (final size in const [Size(640, 340), Size(1000, 560), Size(412, 900)]) {
    for (final glass in [false, true]) {
      testWidgets('${glass ? '유리' : '기본'} 숫자판 ${size.width.toInt()}×${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final ctrl = TextEditingController(text: '0');
        final errors = <String>[];
        final old = FlutterError.onError;
        FlutterError.onError = (d) => errors.add(d.exceptionAsString().split('\n').first);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => glass
                      ? MakitaNumpadGlass.show(context, controller: ctrl, title: '길이')
                      : MakitaNumpad.show(context, controller: ctrl, title: '길이'),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        FlutterError.onError = old;
        expect(errors, isEmpty);
        for (final d in ['1', '9', '0']) {
          final r = tester.getRect(find.text(d).last);
          expect(r.bottom <= size.height && r.top >= 0, isTrue, reason: '$d 단추가 화면 밖 $r');
        }
        await tester.tap(find.text('7').last);
        await tester.pump();
      });
    }
  }
}
