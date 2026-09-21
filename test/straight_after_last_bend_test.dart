// 마킹 탭 "마지막 벤드 뒤 곧은 길이".
// 예전 식(절단 − 마지막 마킹 − 반경)은 R100·90°·꼬리 300에서 200이어야 할
// 값을 257로, 꼬리가 없으면 0이어야 할 값을 57로 보여 줬다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/engine/tube_bending_engine.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_result_tabs.dart';
import 'package:tubing_calculator/src/presentation/calculator/tube_marking_rules.dart';

double straightFor(
  List<BendInstruction> list, {
  double tail = 0,
  double gain = 0,
  double offset = 0,
}) {
  final r = TubeBendingEngine(
    radius: 100,
    userGain90: gain,
  ).calculate(list, offset, tail: tail);
  return straightAfterLastBend(
    r['steps'] as List<StepResult>,
    r['totalCutLength'] as double,
  );
}

BendInstruction b(double l, double a) =>
    BendInstruction(length: l, angle: a, rotation: 0);

void main() {
  test('R100 90° 꼬리 300: 곧은 길이 = 300 − 100 = 200', () {
    expect(straightFor([b(500, 90)], tail: 300), closeTo(200, 0.01));
  });

  test('꼬리 없으면 0', () {
    expect(straightFor([b(500, 90)]), closeTo(0, 0.01));
  });

  test('45°에서는 반경이 아니라 셋백(41.42)을 뺀다', () {
    expect(straightFor([b(500, 45)], tail: 300), closeTo(300 - 41.42, 0.01));
  });

  test('실측 게인·벤더 원점이 있어도 같다', () {
    expect(
      straightFor([b(500, 90)], tail: 300, gain: 30, offset: 50),
      closeTo(200, 0.01),
    );
  });

  test('끝이 직관이면 그 직관에서 셋백을 뺀 길이', () {
    expect(straightFor([b(500, 90), b(400, 0)]), closeTo(300, 0.01));
  });

  test('벤드가 없으면 0', () {
    expect(straightFor([b(500, 0)]), 0);
  });

  testWidgets('마킹 탭 글', (tester) async {
    SharedPreferences.setMockInitialValues({});
    MachineSpecs().resetForTest();
    MachineSpecs().update(
      radius: 100,
      gain90: 0,
      springback: 0,
      fittingDepth: 0,
      benderOffset: 0,
      cutMargin: 5,
      tail: 300,
      startFit: false,
      endFit: false,
    );
    MobileBendDataManager().bendList
      ..clear()
      ..add({'length': 500.0, 'angle': 90.0, 'rotation': 0.0});
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MobileResultTab(startDir: 'RIGHT')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('마지막 벤드 뒤 곧은 길이 200mm'), findsOneWidget);
  });
}
