// 직관 뒤의 짧은 구간을 "만들 수 없다"고 하지 않는지(튜브 마킹 화면 세 곳 공용).
// 예전에는 직관 150 다음에 짧은 벤드 구간이 오면 엔진과 공간 점검이 둘 다
// "곧은 부분 음수"로 잡았다. 한 줄로 이어진 관이라 실제로는 꺾을 수 있다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/engine/tube_bending_engine.dart';
import 'package:tubing_calculator/src/presentation/calculator/bend_check.dart';

List<Map<String, dynamic>> bends(List<List<double>> rows) => [
  for (final r in rows) {'length': r[0], 'angle': r[1], 'rotation': r[2]},
];

const double r = 38.1;

/// 화면이 하는 대로 엔진 경고를 받아 점검에 넘긴다.
BendCheck screenCheck(List<Map<String, dynamic>> list) {
  final result = TubeBendingEngine(radius: r, userGain90: 12).calculate([
    for (final b in list)
      BendInstruction(
        length: b['length'] as double,
        angle: b['angle'] as double,
        rotation: b['rotation'] as double,
      ),
  ], 0);
  return checkBends(
    list,
    radius: r,
    startDir: 'RIGHT',
    outerDiameter: 9.53,
    engineWarnings: List<String>.from(result['warnings'] as List),
  );
}

void main() {
  test('직관 뒤의 짧은 구간은 경고하지 않는다(엔진 경고도 걷어 낸다)', () {
    // 90°면 셋백 38.1. 10mm 구간은 따로 보면 -28.1이다.
    final list = bends([
      [150, 0, 0],
      [10, 90, 0],
      [300, 0, 0],
    ]);
    final engine = TubeBendingEngine(radius: r).calculate([
      for (final b in list)
        BendInstruction(
          length: b['length'] as double,
          angle: b['angle'] as double,
          rotation: b['rotation'] as double,
        ),
    ], 0);
    // 엔진은 여전히 따로 보고 경고한다(엔진은 그대로 둔다).
    expect(engine['warnings'] as List, isNotEmpty);
    expect(screenCheck(list).warnings, isEmpty);
  });

  test('벤드 사이에 낀 짧은 직관도 합쳐서 본다', () {
    // 90° 다음 직관 20, 다시 90°까지 100. 합치면 120 − 38.1×2 = 43.8.
    final list = bends([
      [300, 90, 0],
      [20, 0, 0],
      [100, 90, 90],
      [300, 0, 0],
    ]);
    expect(screenCheck(list).warnings, isEmpty);
  });

  test('합쳐도 모자라면 잡고, 번호는 입력 목록 번호로 적는다', () {
    // 90° 다음 직관 20, 다시 90°까지 30. 합치면 50 − 76.2 = -26.2.
    // 예전에는 -8.1(30 − 38.1)이라고 해서 모자란 양을 작게 봤다.
    final list = bends([
      [300, 90, 0],
      [20, 0, 0],
      [30, 90, 90],
      [300, 0, 0],
    ]);
    final w = screenCheck(list).warnings;
    expect(w, hasLength(1));
    expect(w.first, contains('3번 구간'));
    expect(w.first, contains('-26.2'));
  });

  test('벤드끼리 붙은 짧은 구간은 예전처럼 잡는다(한 번만)', () {
    final list = bends([
      [300, 90, 0],
      [50, 90, 90],
      [300, 0, 0],
    ]);
    final w = screenCheck(list).warnings;
    expect(w, hasLength(1));
    expect(w.first, contains('2번 구간'));
  });

  test('굴림 각도 번호도 입력 목록 번호다', () {
    // 직관을 앞에 두고 평면이 다른 벤드 둘.
    final list = bends([
      [100, 0, 0],
      [300, 90, 0],
      [300, 90, 360],
      [300, 0, 0],
    ]);
    final rolls = screenCheck(list).rollByIndex;
    expect(rolls.keys, contains(2));
    expect(rolls.keys, isNot(contains(1)));
  });
}
