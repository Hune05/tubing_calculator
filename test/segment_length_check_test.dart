// 튜브 입력 탭 "벤딩 및 누설 경고" 창의 셈 검사.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/calculator/segment_length_check.dart';

List<Map<String, dynamic>> bends(List<List<double>> rows) => [
  for (final r in rows) {'length': r[0], 'angle': r[1], 'rotation': r[2]},
];

SegmentLengthCheck check(
  List<Map<String, dynamic>> existing,
  double length,
  double angle, {
  double odMm = 12.7,
}) => checkSegmentLength(
  existing: existing,
  length: length,
  angle: angle,
  tubeOdMm: odMm,
  minStraight: 30,
  warnShoeInterference: true,
);

void main() {
  group('누설 기준(바깥지름 mm)', () {
    test('1/2" 튜브는 30mm (예전에는 인치 0.5를 대서 21mm였다)', () {
      expect(minFittingStraightMm(0.5 * 25.4), 30.0);
      expect(minFittingStraightMm(6.35), 21.0);
      expect(minFittingStraightMm(9.525), 24.0);
      expect(minFittingStraightMm(19.05), 32.0);
      expect(minFittingStraightMm(25.4), 38.0);
    });
  });

  test('직관 150 다음의 10mm 벤드 구간은 경고하지 않는다', () {
    final c = check(
      bends([
        [150, 0, 0],
      ]),
      10,
      90,
    );
    expect(c.run, 160);
    expect(c.merged, isTrue);
    expect(c.hasWarning, isFalse);
  });

  test('첫 구간이 짧으면 물림·누설 둘 다 잡는다', () {
    final c = check(const [], 10, 90);
    expect(c.shoeInterference, isTrue);
    expect(c.leakRisk, isTrue);
    expect(c.merged, isFalse);
  });

  test('앞 직관과 합쳐도 모자라면 잡는다', () {
    final c = check(
      bends([
        [10, 0, 0],
      ]),
      10,
      90,
    );
    expect(c.run, 20);
    expect(c.shoeInterference, isTrue);
    expect(c.leakRisk, isTrue);
  });

  test('벤드 사이 중간 구간은 누설을 따지지 않는다(피팅이 없다)', () {
    final c = check(
      bends([
        [300, 90, 0],
      ]),
      20,
      90,
    );
    expect(c.leakRisk, isFalse);
    // 벤더에 물릴 길이는 여전히 본다.
    expect(c.shoeInterference, isTrue);
  });

  test('벤드 뒤에 붙이는 짧은 직관(끝이 될 수 있다)은 누설을 본다', () {
    final c = check(
      bends([
        [300, 90, 0],
      ]),
      20,
      0,
    );
    expect(c.leakRisk, isTrue);
  });

  test('물림 경고를 꺼 두면 물림은 보지 않는다', () {
    final c = checkSegmentLength(
      existing: const [],
      length: 10,
      angle: 90,
      tubeOdMm: 12.7,
      minStraight: 30,
      warnShoeInterference: false,
    );
    expect(c.shoeInterference, isFalse);
    expect(c.leakRisk, isTrue);
  });

  group("반경을 주면 앞뒤 셋백을 빼고 본다(10-09)", () {
    SegmentLengthCheck withR(List<Map<String, dynamic>> ex, double len, double ang) =>
        checkSegmentLength(
          existing: ex,
          length: len,
          angle: ang,
          tubeOdMm: 12.7,
          minStraight: 30,
          warnShoeInterference: true,
          radius: 38.1,
        );

    test("R38.1 90° 두 번 사이 80mm: 곧은 부분 3.8mm라 물림 경고(예전에는 80 ≥ 30이라 통과)", () {
      final c = withR(bends([[300, 90, 0]]), 80, 90);
      expect(c.straight, closeTo(3.8, 0.05));
      expect(c.shoeInterference, isTrue);
      expect(c.setbackRemoved, isTrue);
      expect(c.leakRisk, isFalse); // 중간 구간은 누설을 안 본다
    });

    test("45° 두 번 사이 빗변 42.4: 곧은 부분 10.9mm라 경고", () {
      final c = withR(bends([[300, 45, 0]]), 42.4, 45);
      expect(c.straight, closeTo(10.8, 0.1));
      expect(c.shoeInterference, isTrue);
    });

    test("첫 구간 50mm 뒤 90°: 곧은 끝 11.9mm라 물림·누설 둘 다", () {
      final c = withR(const [], 50, 90);
      expect(c.straight, closeTo(11.9, 0.05));
      expect(c.shoeInterference, isTrue);
      expect(c.leakRisk, isTrue);
    });

    test("90° 뒤 꼬리 직관 60mm: 앞 셋백만 빼서 21.9mm, 누설 경고", () {
      final c = withR(bends([[300, 90, 0]]), 60, 0);
      expect(c.straight, closeTo(21.9, 0.05));
      expect(c.leakRisk, isTrue);
    });

    test("넉넉하면 경고 없음, 반경 0이면 예전과 같다", () {
      expect(withR(bends([[300, 90, 0]]), 200, 90).hasWarning, isFalse);
      final old = check(bends([[300, 90, 0]]), 80, 90);
      expect(old.straight, 80);
      expect(old.hasWarning, isFalse);
    });
  });
}

