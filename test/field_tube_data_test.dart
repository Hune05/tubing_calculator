// 튜브 현장 탭 자료: 마킹 탭과 같은 엔진 값인지.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_result_tabs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MachineSpecs().resetForTest();
    MachineSpecs().update(
      radius: 38.1,
      gain90: 12.0,
      springback: 2.0,
      fittingDepth: 0.0,
      benderOffset: 0.0,
      cutMargin: 0.0,
      tail: 0.0,
      startFit: false,
      endFit: false,
    );
    MobileBendDataManager().bendList
      ..clear()
      ..addAll([
        {'length': 150.0, 'angle': 0.0, 'rotation': 0.0},
        {'length': bendSetback(38.1, 90), 'angle': 90.0, 'rotation': 0.0},
        {'length': 300.0, 'angle': 90.0, 'rotation': 90.0},
        {'length': 200.0, 'angle': 0.0, 'rotation': 0.0},
      ]);
  });

  test('벤드에만 번호, 꺾을 각도에 스프링백, 절단 길이 있음', () {
    final data = computeTubeFieldData();
    expect(data.error, isNull);
    expect(data.marks.map((m) => m.number).toList(), [0, 1, 2, 0]);
    expect(data.bends.first.targetAngle, closeTo(92.0, 1e-9));
    expect(data.bends.first.hasOverBend, isTrue);
    // 직관 150 뒤, 셋백만큼 넣은 첫 벤드는 직관 끝과 같은 자리.
    expect(data.bends.first.position, closeTo(150.0, 1e-6));
    // 두 번째 벤드 간격 = 자리 차이.
    expect(
      data.bends[1].gap,
      closeTo(data.bends[1].position - data.bends[0].position, 1e-9),
    );
    expect(data.totalCut, greaterThan(data.bends[1].position));
    expect(data.warnings, isEmpty);
  });

  test('못 셈하는 각도면 까닭을 돌려준다', () {
    MobileBendDataManager().bendList
      ..clear()
      ..add({'length': 100.0, 'angle': 180.0, 'rotation': 0.0});
    final data = computeTubeFieldData();
    expect(data.isEmpty, isTrue);
    expect(data.error, isNotNull);
  });
}
