// 각도 역산(Field Matcher): 잰 높이와 Travel/Run으로 실제 각도를 거꾸로 구하는 식.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/calculator/angle_matcher.dart';

void main() {
  test('Travel로 잰 경우: 높이 100 · Travel 200 → 30° (표준 각도, Run 173.2, 줄어듦 26.8)', () {
    final m = matchAngle(rise: 100, measure: 200, basis: MatchBasis.travel)!;
    expect(m.angle, closeTo(30, 1e-9));
    expect(m.nearest.angle, 30);
    expect(m.nearest.diff, closeTo(0, 1e-9));
    expect(m.isStandard, true);
    expect(m.run, closeTo(173.205, 0.001));
    expect(m.shrink, closeTo(26.795, 0.001));
    expect(m.multiplier, closeTo(2, 1e-9));
  });

  test('Run으로 잰 경우: 높이 100 · Run 100 → 45°, Travel 141.4', () {
    final m = matchAngle(rise: 100, measure: 100, basis: MatchBasis.run)!;
    expect(m.angle, closeTo(45, 1e-9));
    expect(m.nearest.angle, 45);
    expect(m.travel, closeTo(141.421, 0.001));
    expect(m.run, 100);
  });

  test('표준이 아닌 손으로 꺾은 값: 높이 100 · Travel 190 → 약 31.8°, 가장 가까운 표준 30°, 차이 −1.8°', () {
    final m = matchAngle(rise: 100, measure: 190, basis: MatchBasis.travel)!;
    expect(m.angle, closeTo(31.76, 0.01));
    expect(m.nearest.angle, 30);
    expect(m.nearest.diff, closeTo(-1.76, 0.01));
    expect(m.isStandard, false);
    // Travel 190을 그대로 두고 30°로 꺾으면 높이는 95, 즉 5mm 낮다.
    expect(m.nearest.riseError, closeTo(-5, 1e-9));
  });

  test('표 각 줄: 같은 높이를 표준 각도로 꺾을 때의 Travel·Run', () {
    final m = matchAngle(rise: 100, measure: 200, basis: MatchBasis.travel)!;
    final r45 = m.rows.firstWhere((r) => r.angle == 45);
    expect(r45.travel, closeTo(141.421, 0.001));
    expect(r45.run, closeTo(100, 1e-9));
    expect(r45.diff, closeTo(15, 1e-9));
    final r225 = m.rows.firstWhere((r) => r.angle == 22.5);
    expect(r225.travel, closeTo(100 / math.sin(22.5 * math.pi / 180), 1e-9));
    expect(m.rows.map((r) => r.angle), kStandardAngles);
  });

  test('Run 기준 오차: 높이 100 · Run 150 → 33.7°, 표준 30°로 꺾으면 Run 150에서 높이 86.6', () {
    final m = matchAngle(rise: 100, measure: 150, basis: MatchBasis.run)!;
    expect(m.angle, closeTo(33.69, 0.01));
    expect(m.nearest.angle, 30);
    expect(m.nearest.riseError, closeTo(150 * math.tan(30 * math.pi / 180) - 100, 1e-9));
  });

  test('Travel이 높이와 같으면 90°, 높이보다 짧으면 풀 수 없다', () {
    final m = matchAngle(rise: 100, measure: 100, basis: MatchBasis.travel)!;
    expect(m.angle, closeTo(90, 1e-9));
    expect(m.run, 0);
    expect(
      matchProblem(rise: 100, measure: 99, basis: MatchBasis.travel),
      MatchProblem.travelShorter,
    );
    expect(matchAngle(rise: 100, measure: 99, basis: MatchBasis.travel), isNull);
    // Run은 높이보다 짧아도 된다(60° 넘는 가파른 꺾임).
    final steep = matchAngle(rise: 100, measure: 50, basis: MatchBasis.run)!;
    expect(steep.angle, closeTo(63.43, 0.01));
  });

  test('값이 비었거나 0 이하이면 null', () {
    for (final (h, m) in <(double?, double?)>[(null, 100), (100, null), (0, 100), (100, 0), (-1, 5)]) {
      expect(matchProblem(rise: h, measure: m, basis: MatchBasis.run), MatchProblem.missing);
      expect(matchAngle(rise: h, measure: m, basis: MatchBasis.run), isNull);
    }
  });

  test('실제 각도로 되먹임: 각도 a로 만든 Rise·Travel을 넣으면 a가 되돌아온다', () {
    for (final a in [5.0, 12.0, 22.5, 37.3, 45.0, 71.0]) {
      final r = a * math.pi / 180;
      const rise = 80.0;
      final byTravel = matchAngle(rise: rise, measure: rise / math.sin(r), basis: MatchBasis.travel)!;
      final byRun = matchAngle(rise: rise, measure: rise / math.tan(r), basis: MatchBasis.run)!;
      expect(byTravel.angle, closeTo(a, 1e-9), reason: 'travel $a');
      expect(byRun.angle, closeTo(a, 1e-9), reason: 'run $a');
    }
  });
}
