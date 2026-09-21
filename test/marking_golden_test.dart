// 대표 형상 마킹 값 고정 검사.
//
// ⚠ 여기 값은 "실측"이 아니다. 2026-09-21 기준 셈이 내는 값을 굳혀 둔 것이다
// (대표 몇 개는 손셈으로 확인: 전선관 수동 90° 스텁 300 − 152.4 = 147.6,
// 절단 700 − 82.5 = 617.5 / 튜브 300 − 38.1 = 261.9).
// 코드를 고치다가 이 값이 바뀌면 검사가 깨진다. 셈을 일부러 바꾼 거라면,
// 왜 바뀌는지 적고 값을 고친다. 모르고 바뀐 거라면 버그다.
//
// 실측 모음(맨 아래 kFieldMeasured): 실제로 꺾어서 맞았던 것을 넣는다.
// 넣을 것 — 벤더·규격·제원, 입력 목록, 그때 찍은 마킹 자리, 자른 길이, 허용 오차.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/engine/tube_bending_engine.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_marking_logic.dart';

List<Map<String, dynamic>> bends(List<List<double>> rows) => [
  for (final r in rows) {'length': r[0], 'angle': r[1], 'rotation': r[2]},
];

/// 튜브: 3/8"~1/2" 수동 벤더(반경 38.1, 실측 게인 12, 스프링백 2°).
Map<String, dynamic> tubeRun(List<List<double>> rows) {
  return TubeBendingEngine(
    radius: 38.1,
    userGain90: 12.0,
    springbackDeg: 2,
  ).calculate([
    for (final r in rows)
      BendInstruction(length: r[0], angle: r[1], rotation: r[2]),
  ], 0);
}

/// 전선관: Greenlee 22mm EMT 표 값(테이크업 152.4, 게인 82.5, CLR 114.3),
/// 유압은 셋백 40, 스프링백 3°.
Map<String, dynamic> conduitSettings(String type) => {
  'benderType': type,
  'takeUp': 152.4,
  'gain': 82.5,
  'clr': 114.3,
  'setback': 40.0,
  'applySpringback': true,
  'springback': 3.0,
  'bladeKerf': 0.0,
  'couplingDepth': 20.0,
  'degPerNotch': 2.5,
  'ramTravel': 100.0,
};

const double tol = 0.01;

void main() {
  group('튜브 — 지금 셈 고정', () {
    test('90° 스텁', () {
      final r = tubeRun([
        [300, 90, 0],
        [400, 0, 0],
      ]);
      final marks = (r['steps'] as List)
          .map((s) => (s as StepResult).markingPoint)
          .toList();
      expect(marks, [
        for (final v in [261.900, 688.000]) closeTo(v, tol),
      ]);
      expect(r['totalCutLength'] as double, closeTo(688.000, tol));
      expect(r['warnings'] as List, isEmpty);
    });
    test('90° 두 번(다른 평면)', () {
      final r = tubeRun([
        [300, 90, 0],
        [400, 90, 90],
        [300, 0, 0],
      ]);
      final marks = (r['steps'] as List)
          .map((s) => (s as StepResult).markingPoint)
          .toList();
      expect(marks, [
        for (final v in [261.900, 649.900, 976.000]) closeTo(v, tol),
      ]);
      expect(r['totalCutLength'] as double, closeTo(976.000, tol));
      expect(r['warnings'] as List, isEmpty);
    });
    test('30° 오프셋', () {
      final r = tubeRun([
        [200, 30, 0],
        [200, 30, 180],
        [300, 0, 0],
      ]);
      final marks = (r['steps'] as List)
          .map((s) => (s as StepResult).markingPoint)
          .toList();
      expect(marks, [
        for (final v in [189.791, 389.447, 699.312]) closeTo(v, tol),
      ]);
      expect(r['totalCutLength'] as double, closeTo(699.312, tol));
      expect(r['warnings'] as List, isEmpty);
    });
    test('45° 오프셋', () {
      final r = tubeRun([
        [250, 45, 0],
        [141.4, 45, 180],
        [300, 0, 0],
      ]);
      final marks = (r['steps'] as List)
          .map((s) => (s as StepResult).markingPoint)
          .toList();
      expect(marks, [
        for (final v in [234.218, 374.415, 688.994]) closeTo(v, tol),
      ]);
      expect(r['totalCutLength'] as double, closeTo(688.994, tol));
      expect(r['warnings'] as List, isEmpty);
    });
    test('3포인트 새들(22.5·45·22.5)', () {
      final r = tubeRun([
        [300, 22.5, 0],
        [130.7, 45, 180],
        [130.7, 22.5, 0],
        [300, 0, 0],
      ]);
      final marks = (r['steps'] as List)
          .map((s) => (s as StepResult).markingPoint)
          .toList();
      expect(marks, [
        for (final v in [292.421, 414.775, 552.475, 859.910]) closeTo(v, tol),
      ]);
      expect(r['totalCutLength'] as double, closeTo(859.910, tol));
      expect(r['warnings'] as List, isEmpty);
    });
    test('30° 킥', () {
      final r = tubeRun([
        [400, 30, 0],
        [500, 0, 0],
      ]);
      final marks = (r['steps'] as List)
          .map((s) => (s as StepResult).markingPoint)
          .toList();
      expect(marks, [
        for (final v in [389.791, 899.656]) closeTo(v, tol),
      ]);
      expect(r['totalCutLength'] as double, closeTo(899.656, tol));
      expect(r['warnings'] as List, isEmpty);
    });
    test('90° 두 번(U자)', () {
      final r = tubeRun([
        [300, 90, 0],
        [250, 90, 90],
        [300, 0, 0],
      ]);
      final marks = (r['steps'] as List)
          .map((s) => (s as StepResult).markingPoint)
          .toList();
      expect(marks, [
        for (final v in [261.900, 499.900, 826.000]) closeTo(v, tol),
      ]);
      expect(r['totalCutLength'] as double, closeTo(826.000, tol));
      expect(r['warnings'] as List, isEmpty);
    });
    test('직관 150 뒤 21° 오프셋', () {
      final r = tubeRun([
        [150, 0, 0],
        [72.3, 21, 0],
        [195.3, 21, 180],
        [200, 0, 0],
      ]);
      final marks = (r['steps'] as List)
          .map((s) => (s as StepResult).markingPoint)
          .toList();
      expect(marks, [
        for (final v in [150.000, 215.239, 410.422, 617.367]) closeTo(v, tol),
      ]);
      expect(r['totalCutLength'] as double, closeTo(617.367, tol));
      expect(r['warnings'] as List, isEmpty);
    });
  });

  group('전선관 — 지금 셈 고정', () {
    test('hand · 90° 스텁', () {
      final list = bends([
        [300, 90, 0],
        [400, 0, 0],
      ]);
      final s = conduitSettings('hand');
      final m = calculateConduitMarkings(list, s);
      expect(m.map((x) => x['mark'] as double).toList(), [
        for (final v in [147.600, 617.500]) closeTo(v, tol),
      ]);
      expect(conduitTotalCut(list, s), closeTo(617.500, tol));
    });
    test('ram · 90° 스텁', () {
      final list = bends([
        [300, 90, 0],
        [400, 0, 0],
      ]);
      final s = conduitSettings('ram');
      final m = calculateConduitMarkings(list, s);
      expect(m.map((x) => x['mark'] as double).toList(), [
        for (final v in [260.000, 617.500]) closeTo(v, tol),
      ]);
      expect(conduitTotalCut(list, s), closeTo(617.500, tol));
    });
    test('chicago · 90° 스텁', () {
      final list = bends([
        [300, 90, 0],
        [400, 0, 0],
      ]);
      final s = conduitSettings('chicago');
      final m = calculateConduitMarkings(list, s);
      expect(m.map((x) => x['mark'] as double).toList(), [
        for (final v in [147.600, 617.500]) closeTo(v, tol),
      ]);
      expect(conduitTotalCut(list, s), closeTo(617.500, tol));
    });
    test('hand · 90° 두 번(다른 평면)', () {
      final list = bends([
        [300, 90, 0],
        [400, 90, 90],
        [300, 0, 0],
      ]);
      final s = conduitSettings('hand');
      final m = calculateConduitMarkings(list, s);
      expect(m.map((x) => x['mark'] as double).toList(), [
        for (final v in [147.600, 465.100, 835.000]) closeTo(v, tol),
      ]);
      expect(conduitTotalCut(list, s), closeTo(835.000, tol));
    });
    test('ram · 90° 두 번(다른 평면)', () {
      final list = bends([
        [300, 90, 0],
        [400, 90, 90],
        [300, 0, 0],
      ]);
      final s = conduitSettings('ram');
      final m = calculateConduitMarkings(list, s);
      expect(m.map((x) => x['mark'] as double).toList(), [
        for (final v in [260.000, 577.500, 835.000]) closeTo(v, tol),
      ]);
      expect(conduitTotalCut(list, s), closeTo(835.000, tol));
    });
    test('chicago · 90° 두 번(다른 평면)', () {
      final list = bends([
        [300, 90, 0],
        [400, 90, 90],
        [300, 0, 0],
      ]);
      final s = conduitSettings('chicago');
      final m = calculateConduitMarkings(list, s);
      expect(m.map((x) => x['mark'] as double).toList(), [
        for (final v in [147.600, 465.100, 835.000]) closeTo(v, tol),
      ]);
      expect(conduitTotalCut(list, s), closeTo(835.000, tol));
    });
    test('hand · 30° 오프셋', () {
      final list = bends([
        [200, 30, 0],
        [200, 30, 180],
        [300, 0, 0],
      ]);
      final s = conduitSettings('hand');
      final m = calculateConduitMarkings(list, s);
      expect(m.map((x) => x['mark'] as double).toList(), [
        for (final v in [131.273, 328.909, 695.272]) closeTo(v, tol),
      ]);
      expect(conduitTotalCut(list, s), closeTo(695.272, tol));
    });
    test('ram · 30° 오프셋', () {
      final list = bends([
        [200, 30, 0],
        [200, 30, 180],
        [300, 0, 0],
      ]);
      final s = conduitSettings('ram');
      final m = calculateConduitMarkings(list, s);
      expect(m.map((x) => x['mark'] as double).toList(), [
        for (final v in [189.282, 386.918, 695.272]) closeTo(v, tol),
      ]);
      expect(conduitTotalCut(list, s), closeTo(695.272, tol));
    });
    test('chicago · 30° 오프셋', () {
      final list = bends([
        [200, 30, 0],
        [200, 30, 180],
        [300, 0, 0],
      ]);
      final s = conduitSettings('chicago');
      final m = calculateConduitMarkings(list, s);
      expect(m.map((x) => x['mark'] as double).toList(), [
        for (final v in [131.273, 328.909, 695.272]) closeTo(v, tol),
      ]);
      expect(conduitTotalCut(list, s), closeTo(695.272, tol));
    });
    test('hand · 45° 오프셋', () {
      final list = bends([
        [250, 45, 0],
        [141.4, 45, 180],
        [300, 0, 0],
      ]);
      final s = conduitSettings('hand');
      final m = calculateConduitMarkings(list, s);
      expect(m.map((x) => x['mark'] as double).toList(), [
        for (final v in [164.555, 297.685, 674.858]) closeTo(v, tol),
      ]);
      expect(conduitTotalCut(list, s), closeTo(674.858, tol));
    });
    test('ram · 45° 오프셋', () {
      final list = bends([
        [250, 45, 0],
        [141.4, 45, 180],
        [300, 0, 0],
      ]);
      final s = conduitSettings('ram');
      final m = calculateConduitMarkings(list, s);
      expect(m.map((x) => x['mark'] as double).toList(), [
        for (final v in [233.431, 366.561, 674.858]) closeTo(v, tol),
      ]);
      expect(conduitTotalCut(list, s), closeTo(674.858, tol));
    });
    test('chicago · 45° 오프셋', () {
      final list = bends([
        [250, 45, 0],
        [141.4, 45, 180],
        [300, 0, 0],
      ]);
      final s = conduitSettings('chicago');
      final m = calculateConduitMarkings(list, s);
      expect(m.map((x) => x['mark'] as double).toList(), [
        for (final v in [164.555, 297.685, 674.858]) closeTo(v, tol),
      ]);
      expect(conduitTotalCut(list, s), closeTo(674.858, tol));
    });
    test('hand · 3포인트 새들(22.5·45·22.5)', () {
      final list = bends([
        [300, 22.5, 0],
        [130.7, 45, 180],
        [130.7, 22.5, 0],
        [300, 0, 0],
      ]);
      final s = conduitSettings('hand');
      final m = calculateConduitMarkings(list, s);
      expect(m.map((x) => x['mark'] as double).toList(), [
        for (final v in [239.164, 344.270, 491.308, 851.159]) closeTo(v, tol),
      ]);
      expect(conduitTotalCut(list, s), closeTo(851.159, tol));
    });
    test('ram · 3포인트 새들(22.5·45·22.5)', () {
      final list = bends([
        [300, 22.5, 0],
        [130.7, 45, 180],
        [130.7, 22.5, 0],
        [300, 0, 0],
      ]);
      final s = conduitSettings('ram');
      final m = calculateConduitMarkings(list, s);
      expect(m.map((x) => x['mark'] as double).toList(), [
        for (final v in [292.044, 413.146, 544.187, 851.159]) closeTo(v, tol),
      ]);
      expect(conduitTotalCut(list, s), closeTo(851.159, tol));
    });
    test('chicago · 3포인트 새들(22.5·45·22.5)', () {
      final list = bends([
        [300, 22.5, 0],
        [130.7, 45, 180],
        [130.7, 22.5, 0],
        [300, 0, 0],
      ]);
      final s = conduitSettings('chicago');
      final m = calculateConduitMarkings(list, s);
      expect(m.map((x) => x['mark'] as double).toList(), [
        for (final v in [239.164, 344.270, 491.308, 851.159]) closeTo(v, tol),
      ]);
      expect(conduitTotalCut(list, s), closeTo(851.159, tol));
    });
    test('hand · 30° 킥', () {
      final list = bends([
        [400, 30, 0],
        [500, 0, 0],
      ]);
      final s = conduitSettings('hand');
      final m = calculateConduitMarkings(list, s);
      expect(m.map((x) => x['mark'] as double).toList(), [
        for (final v in [331.273, 897.636]) closeTo(v, tol),
      ]);
      expect(conduitTotalCut(list, s), closeTo(897.636, tol));
    });
    test('ram · 30° 킥', () {
      final list = bends([
        [400, 30, 0],
        [500, 0, 0],
      ]);
      final s = conduitSettings('ram');
      final m = calculateConduitMarkings(list, s);
      expect(m.map((x) => x['mark'] as double).toList(), [
        for (final v in [389.282, 897.636]) closeTo(v, tol),
      ]);
      expect(conduitTotalCut(list, s), closeTo(897.636, tol));
    });
    test('chicago · 30° 킥', () {
      final list = bends([
        [400, 30, 0],
        [500, 0, 0],
      ]);
      final s = conduitSettings('chicago');
      final m = calculateConduitMarkings(list, s);
      expect(m.map((x) => x['mark'] as double).toList(), [
        for (final v in [331.273, 897.636]) closeTo(v, tol),
      ]);
      expect(conduitTotalCut(list, s), closeTo(897.636, tol));
    });
    test('hand · 90° 두 번(U자)', () {
      final list = bends([
        [300, 90, 0],
        [250, 90, 90],
        [300, 0, 0],
      ]);
      final s = conduitSettings('hand');
      final m = calculateConduitMarkings(list, s);
      expect(m.map((x) => x['mark'] as double).toList(), [
        for (final v in [147.600, 315.100, 685.000]) closeTo(v, tol),
      ]);
      expect(conduitTotalCut(list, s), closeTo(685.000, tol));
    });
    test('ram · 90° 두 번(U자)', () {
      final list = bends([
        [300, 90, 0],
        [250, 90, 90],
        [300, 0, 0],
      ]);
      final s = conduitSettings('ram');
      final m = calculateConduitMarkings(list, s);
      expect(m.map((x) => x['mark'] as double).toList(), [
        for (final v in [260.000, 427.500, 685.000]) closeTo(v, tol),
      ]);
      expect(conduitTotalCut(list, s), closeTo(685.000, tol));
    });
    test('chicago · 90° 두 번(U자)', () {
      final list = bends([
        [300, 90, 0],
        [250, 90, 90],
        [300, 0, 0],
      ]);
      final s = conduitSettings('chicago');
      final m = calculateConduitMarkings(list, s);
      expect(m.map((x) => x['mark'] as double).toList(), [
        for (final v in [147.600, 315.100, 685.000]) closeTo(v, tol),
      ]);
      expect(conduitTotalCut(list, s), closeTo(685.000, tol));
    });
    test('hand · 직관 150 뒤 21° 오프셋', () {
      final list = bends([
        [150, 0, 0],
        [72.3, 21, 0],
        [195.3, 21, 180],
        [200, 0, 0],
      ]);
      final s = conduitSettings('hand');
      final m = calculateConduitMarkings(list, s);
      expect(m.map((x) => x['mark'] as double).toList(), [
        for (final v in [150.000, 163.016, 357.516, 616.001]) closeTo(v, tol),
      ]);
      expect(conduitTotalCut(list, s), closeTo(616.001, tol));
    });
    test('ram · 직관 150 뒤 21° 오프셋', () {
      final list = bends([
        [150, 0, 0],
        [72.3, 21, 0],
        [195.3, 21, 180],
        [200, 0, 0],
      ]);
      final s = conduitSettings('ram');
      final m = calculateConduitMarkings(list, s);
      expect(m.map((x) => x['mark'] as double).toList(), [
        for (final v in [150.000, 214.886, 409.387, 616.001]) closeTo(v, tol),
      ]);
      expect(conduitTotalCut(list, s), closeTo(616.001, tol));
    });
    test('chicago · 직관 150 뒤 21° 오프셋', () {
      final list = bends([
        [150, 0, 0],
        [72.3, 21, 0],
        [195.3, 21, 180],
        [200, 0, 0],
      ]);
      final s = conduitSettings('chicago');
      final m = calculateConduitMarkings(list, s);
      expect(m.map((x) => x['mark'] as double).toList(), [
        for (final v in [150.000, 163.016, 357.516, 616.001]) closeTo(v, tol),
      ]);
      expect(conduitTotalCut(list, s), closeTo(616.001, tol));
    });
  });

  group('실측 모음', () {
    for (final c in kFieldMeasured) {
      test(c.name, () {
        final got = c.compute();
        expect(got.marks.length, c.marks.length, reason: '마킹 개수');
        for (var i = 0; i < c.marks.length; i++) {
          expect(
            got.marks[i],
            closeTo(c.marks[i], c.tolerance),
            reason: '${i + 1}번 마킹',
          );
        }
        expect(got.cut, closeTo(c.cut, c.tolerance), reason: '자른 길이');
      });
    }
  }, skip: kFieldMeasured.isEmpty ? '아직 실측값이 없습니다' : false);
}

/// 실제로 꺾어서 맞았던 것. 사용자에게 받아서 넣는다(지어내지 않는다).
class FieldMeasured {
  final String name;
  final ({List<double> marks, double cut}) Function() compute;
  final List<double> marks;
  final double cut;
  final double tolerance;
  const FieldMeasured({
    required this.name,
    required this.compute,
    required this.marks,
    required this.cut,
    this.tolerance = 1.0,
  });
}

final List<FieldMeasured> kFieldMeasured = [
  // 예)
  // FieldMeasured(
  //   name: '2026-09-22 전선관 22mm EMT 21° 오프셋(현장 ○○)',
  //   compute: () {
  //     final list = bends([[150, 0, 0], [72.3, 21, 0], [195.3, 21, 180], [200, 0, 0]]);
  //     final s = conduitSettings('hand');
  //     final m = calculateConduitMarkings(list, s);
  //     return (marks: [for (final x in m) if ((x['angle'] as double) > 0) x['mark'] as double], cut: conduitTotalCut(list, s));
  //   },
  //   marks: [163, 358],
  //   cut: 616,
  // ),
];
