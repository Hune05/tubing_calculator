// 10-09 사용자 결정: 튜브 기준선(장비 원점) 오프셋은 마킹 자리만 옮기고 자를 길이는 늘리지 않는다
// (예전에는 오프셋 50이면 관 한쪽 다리가 50mm 길어졌다).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_result_tabs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ({double cut, List<double> marks}) run(double offset) {
    MachineSpecs().resetForTest();
    MachineSpecs().update(
      radius: 100,
      gain90: 0,
      springback: 0,
      fittingDepth: 0,
      benderOffset: offset,
      cutMargin: 0,
      tail: 300,
      startFit: false,
      endFit: false,
    );
    MobileBendDataManager().bendList
      ..clear()
      ..add({'length': 500.0, 'angle': 90.0, 'rotation': 0.0});
    final d = computeTubeFieldData();
    return (cut: d.totalCut, marks: [for (final b in d.bends) b.position]);
  }

  test('오프셋 50: 마킹은 50 뒤로, 자를 길이는 그대로', () {
    SharedPreferences.setMockInitialValues({});
    final a = run(0);
    final b = run(50);
    expect(b.marks.single, closeTo(a.marks.single + 50, 1e-9));
    expect(b.cut, closeTo(a.cut, 1e-9));
  });
}
