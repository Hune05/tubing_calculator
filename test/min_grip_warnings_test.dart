// 10-09: 튜브 마킹·현장 탭이 최소 물림을 다시 보지 않아, 3/8"에서 넣은 목록을 1/2"(반경 큼)로 바꾸면
// 곧은 부분이 최소 물림보다 짧아져도 경고가 없었다. 마킹 값은 그대로 두고 알리기만 한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/app_settings_controller.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_result_tabs.dart';
import 'package:tubing_calculator/src/presentation/calculator/segment_length_check.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final list = [
    {'length': 200.0, 'angle': 90.0, 'rotation': 0.0},
    {'length': 100.0, 'angle': 90.0, 'rotation': 90.0},
    {'length': 200.0, 'angle': 0.0, 'rotation': 0.0},
  ];

  test('R23.8(3/8")이면 경고 없고, R38.1(1/2")이면 2번 벤드 앞이 짧다', () {
    expect(minGripWarnings(list, radius: 23.8, minStraight: 30), isEmpty);
    final w = minGripWarnings(list, radius: 38.1, minStraight: 30);
    expect(w, hasLength(1));
    expect(w.single, startsWith('2번 벤드 앞 곧은 부분 23.8mm'));
    expect(minGripWarnings(list, radius: 38.1, minStraight: 0), isEmpty);
  });

  test('현장 탭 자료에도 같은 경고가 나온다(마킹 자리는 그대로)', () async {
    SharedPreferences.setMockInitialValues({});
    MachineSpecs().resetForTest();
    MachineSpecs().update(radius: 38.1, gain90: 16.3, springback: 0, tail: 0, startFit: false, endFit: false);
    final c = AppSettingsController();
    c.minStraight = 30;
    c.warnShoeInterference = true;
    MobileBendDataManager().bendList
      ..clear()
      ..addAll(list);
    final data = computeTubeFieldData();
    expect(data.warnings.any((w) => w.contains('최소 물림')), isTrue);
    c.warnShoeInterference = false;
    final off = computeTubeFieldData();
    expect(off.warnings.any((w) => w.contains('최소 물림')), isFalse);
    expect(off.bends.map((b) => b.position), data.bends.map((b) => b.position));
    c.warnShoeInterference = true;
  });
  test('퀵 U벤드 두 번째 줄(곧은 부분 0)은 최소 물림 경고를 띄우지 않는다(8차)', () {
    const r = 38.1;
    final w = minGripWarnings([
      {'length': 300.0, 'angle': 90.0, 'rotation': 0.0, 'uBend': 1.0},
      {'length': 2 * r, 'angle': 90.0, 'rotation': 0.0, 'uBend': 2.0},
      {'length': 300.0, 'angle': 0.0, 'rotation': 0.0},
    ], radius: r, minStraight: 30);
    expect(w, isEmpty);
  });
}
