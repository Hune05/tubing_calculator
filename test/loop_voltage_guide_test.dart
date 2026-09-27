// 4-20mA 루프 잡는 법 그림 설명: 열면 한 번 움직이고, 다시 보기로 처음부터 다시.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/instrument/loop_voltage_guide.dart';

void main() {
  Widget app({double supplyV = 24, double minV = 10.5, bool ok = true}) =>
      MaterialApp(
        home: Scaffold(
          body: LoopVoltageGuide(
            supplyV: supplyV,
            minV: minV,
            wireV: 2.1,
            hartV: 5.75,
            barrierV: 0,
            extraV: 0,
            terminalV: supplyV - 2.1 - 5.75,
            ok: ok,
          ),
        ),
      );

  testWidgets('열면 자동으로 움직이고, 다 끝나면 오류 없이 멈춘다', (tester) async {
    await tester.pumpWidget(app());
    expect(find.byKey(const Key('loop_guide')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('다시 보기를 누르면 처음부터 다시 움직인다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('loop_guide_replay')));
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('전압이 모자란(불합격) 경우도 오류 없이 그려진다', (tester) async {
    await tester.pumpWidget(app(supplyV: 12, minV: 10.5, ok: false));
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
}
