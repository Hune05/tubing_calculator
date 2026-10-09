// 10-09: 롤링 오프셋의 굴림 각도가 목록에 남지 않아 현장 탭·마킹지에 안 나왔다(두 벤드가 한 평면이라
// 형상 점검으로는 굴림이 안 잡힌다). 첫 줄에 rollHint로 남기고 현장 자료가 읽는다.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_result_tabs.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_field_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('튜브: 첫 줄 rollHint가 현장 자료의 굴림 각도로 나온다', () {
    SharedPreferences.setMockInitialValues({});
    MachineSpecs().resetForTest();
    MachineSpecs().update(radius: 38.1, gain90: 16.3, springback: 0, tail: 0, startFit: false, endFit: false);
    MobileBendDataManager().bendList
      ..clear()
      ..addAll([
        {'length': 300.0, 'angle': 45.0, 'rotation': 0.0, 'rollHint': 53.1},
        {'length': 250.0, 'angle': 45.0, 'rotation': 180.0},
        {'length': 300.0, 'angle': 0.0, 'rotation': 0.0},
      ]);
    final d = computeTubeFieldData();
    expect(d.bends.first.roll, closeTo(53.1, 1e-9));
  });

  test('전선관도 같다', () {
    SharedPreferences.setMockInitialValues({});
    ConduitDataManager().bendList
      ..clear()
      ..addAll([
        {'length': 400.0, 'angle': 45.0, 'rotation': 0.0, 'rollHint': 30.0},
        {'length': 250.0, 'angle': 45.0, 'rotation': 180.0},
        {'length': 300.0, 'angle': 0.0, 'rotation': 0.0},
      ]);
    final d = computeConduitFieldData();
    expect(d.bends.first.roll, closeTo(30.0, 1e-9));
  });
}
