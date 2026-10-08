// 10-09 사용자 결정: 톱날 손실(두께)은 자를 길이·자르는 자리에 더하지 않는다
// (톱날은 버리는 쪽을 먹는다. 더하면 관이 톱날 두께만큼 길어졌다).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_result_tabs.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_marking_logic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  double tubeCut(double kerf) {
    MachineSpecs().resetForTest();
    MachineSpecs().update(
      radius: 38.1,
      gain90: 16.3,
      springback: 0,
      fittingDepth: 0,
      benderOffset: 0,
      cutMargin: kerf,
      tail: 300,
      startFit: false,
      endFit: false,
    );
    MobileBendDataManager().bendList
      ..clear()
      ..add({'length': 500.0, 'angle': 90.0, 'rotation': 0.0});
    return computeTubeFieldData().totalCut;
  }

  test('튜브: 톱날 손실을 넣어도 총 절단 길이(자르는 자리)는 같다', () {
    SharedPreferences.setMockInitialValues({});
    final none = tubeCut(0);
    expect(none, greaterThan(0));
    expect(tubeCut(3), none);
  });

  test('전선관: 톱날 두께는 더하지 않고, 커플링 끝 여유는 켰을 때만 더한다', () {
    final list = [
      {'length': 400.0, 'angle': 90.0},
      {'length': 300.0, 'angle': 0.0},
    ];
    final base = {'gain': 81.2, 'bladeKerf': 0.0, 'couplingAllowance': 50.0};
    final withKerf = {...base, 'bladeKerf': 3.0};
    final cut = conduitTotalCut(list, base);
    expect(cut, closeTo(700 - 81.2, 1e-9));
    expect(conduitTotalCut(list, withKerf), cut);
    expect(conduitTotalCut(list, withKerf, useCoupling: true), closeTo(cut + 50, 1e-9));
  });
}
