// 롤링 오프셋 그림 설명: 시트를 열면 한 번 움직이고(자동 재생), 다시 보기로
// 처음부터 다시 움직인다. 값이 바뀌어도 애니메이션은 다시 시작하지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/rolling_offset_guide.dart';

void main() {
  Widget app({double rise = 150, double roll = 200, double rollAngle = 53}) =>
      MaterialApp(
        home: Scaffold(
          body: RollingOffsetGuide(
            rise: rise,
            roll: roll,
            trueOffset: 250,
            rollAngle: rollAngle,
            bendAngle: 45,
          ),
        ),
      );

  testWidgets('열면 자동으로 움직이고, 다 끝나면 오류 없이 멈춘다', (tester) async {
    await tester.pumpWidget(app());
    expect(find.byKey(const Key('rolling_guide')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('다시 보기를 누르면 처음부터 다시 움직인다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rolling_guide_replay')));
    await tester.pump();
    // 다시 시작했으니 아직 안 끝났다(더 pump해야 settle).
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rise·Roll이 0이어도 오류 없이 그려진다', (tester) async {
    await tester.pumpWidget(app(rise: 0, roll: 0, rollAngle: 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('좁은 폭에서도 넘치지 않는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) =>
        errors.add(d.exceptionAsString().split('\n').first);
    try {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = old;
    }
    expect(errors, isEmpty);
  });

  testWidgets('강조할 값을 어느 것으로 골라도 오류 없이 그려진다', (tester) async {
    for (final f in RollingFocus.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RollingOffsetGuide(
              rise: 150,
              roll: 200,
              trueOffset: 250,
              rollAngle: 53,
              bendAngle: 45,
              focus: f,
            ),
          ),
        ),
      );
      // 애니메이션이 끝나기 전에도, 끝난 뒤에도 그려 본다.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$f');
    }
  });
}
