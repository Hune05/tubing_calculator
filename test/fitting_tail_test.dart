// 끝 피팅 + 꼬리: 관 끝은 꼬리 끝이므로 피팅 깊이는 꼬리에 붙는다.
// 예전에는 마지막 구간에 붙여서 R100·500 90°·꼬리 300·깊이 20에서
// 마킹이 400이 아니라 420으로 찍혔다(절단 길이는 777.08로 같았다).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_result_tabs.dart';
import 'package:tubing_calculator/src/presentation/calculator/tube_marking_rules.dart';

void main() {
  group('규칙', () {
    final list = [
      {'length': 500.0, 'angle': 90.0, 'rotation': 0.0},
    ];
    test('꼬리가 있으면 끝 피팅은 꼬리에', () {
      final f = tubeFittedLengths(
        list,
        startFit: false,
        endFit: true,
        fittingDepth: 20,
        tail: 300,
      );
      expect(f.lengths, [500.0]);
      expect(f.tail, 320.0);
      expect(f.endFitOnTail, isTrue);
    });
    test('꼬리가 없으면 마지막 구간에', () {
      final f = tubeFittedLengths(
        list,
        startFit: false,
        endFit: true,
        fittingDepth: 20,
        tail: 0,
      );
      expect(f.lengths, [520.0]);
      expect(f.tail, 0.0);
    });
    test('구간이 하나면 시작·끝이 겹치지 않고 꼬리가 있으면 나뉜다', () {
      final f = tubeFittedLengths(
        list,
        startFit: true,
        endFit: true,
        fittingDepth: 20,
        tail: 300,
      );
      expect(f.lengths, [520.0]);
      expect(f.tail, 320.0);
    });
  });

  test('현장 자료: 마킹 400, 절단 777.08', () {
    SharedPreferences.setMockInitialValues({});
    MachineSpecs().resetForTest();
    MachineSpecs().update(
      radius: 100,
      gain90: 0,
      springback: 0,
      fittingDepth: 20,
      benderOffset: 0,
      cutMargin: 0,
      tail: 300,
      startFit: false,
      endFit: true,
    );
    MobileBendDataManager().bendList
      ..clear()
      ..add({'length': 500.0, 'angle': 90.0, 'rotation': 0.0});
    final data = computeTubeFieldData();
    expect(data.bends.single.position, closeTo(400, 0.01));
    expect(data.totalCut, closeTo(777.08, 0.01));
  });
}
