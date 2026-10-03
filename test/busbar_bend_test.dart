import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_bend.dart';

void main() {
  // 두께 5, 안쪽 반경 5, k 0.33 → 중립선 반경 6.65
  const d = 5.0, r = 5.0, k = 0.33;
  const bd90 = 2 * (r + d) - (math.pi / 2) * (r + k * d); // 굽힘 공제(손 계산)

  test('L 90° 바깥 치수: 절단 길이 = a + b − 굽힘 공제', () {
    final p = busbarL(d: d, r: r, k: k, a: 100, b: 100, deg: 90);
    expect(p.cutLength, closeTo(200 - bd90, 1e-9));
    expect(p.cutLength, closeTo(190.4456, 1e-3));
    expect(p.bends.single.start, closeTo(90, 1e-9)); // 100 − (r + d)
    expect(p.bends.single.end - p.bends.single.start, closeTo(10.4456, 1e-3));
    expect(p.straights, [closeTo(90, 1e-9), closeTo(90, 1e-9)]);
  });

  test('L 안쪽 치수: 바깥 치수에서 두께 두 번 뺀 값과 같은 부스바', () {
    final out = busbarL(d: d, r: r, k: k, a: 100, b: 100, deg: 90);
    final inn = busbarL(
      d: d,
      r: r,
      k: k,
      a: 100 - d,
      b: 100 - d,
      deg: 90,
      ref: BusbarDimRef.inside,
    );
    expect(inn.cutLength, closeTo(out.cutLength, 1e-9));
  });

  test('U 90°: 길이 = a + 바닥 + c − 2 × 굽힘 공제, 마킹 순서', () {
    final p = busbarU(d: d, r: r, k: k, a: 50, web: 80, c: 60);
    expect(p.cutLength, closeTo(190 - 2 * bd90, 1e-9));
    expect(p.bends.length, 2);
    expect(p.bends[0].end, lessThan(p.bends[1].start));
    // 바닥 직선 = 바깥 80 − 2 × (r + d)
    expect(p.straights[1], closeTo(80 - 2 * (r + d), 1e-9));
  });

  test('Z 옵셋 45°: 비스듬한 길이 h ÷ sin, 진행 h ÷ tan', () {
    final z = busbarZ(d: d, r: r, k: k, a: 50, c: 50, h: 40, deg: 45);
    expect(z.slopeVertex, closeTo(40 / math.sin(math.pi / 4), 1e-9));
    expect(z.run, closeTo(40, 1e-9));
    final s = (r + k * d) * math.tan(math.pi / 8);
    expect(z.slope, closeTo(z.slopeVertex - 2 * s, 1e-9));
    expect(z.plan.bends[0].turn, 45);
    expect(z.plan.bends[1].turn, -45);
    // 절단 길이 = 직선 합 + 호 두 개
    final arc = (r + k * d) * math.pi / 4;
    expect(z.plan.cutLength, closeTo(50 + 50 + z.slope + 2 * arc, 1e-9));
    expect(z.feasible, isTrue);
  });

  test('Z 옵셋: 높이가 너무 낮으면 못 꺾는다(최소 높이 = 2·s·sin θ)', () {
    final z = busbarZ(d: d, r: r, k: k, a: 50, c: 50, h: 3, deg: 45);
    expect(z.feasible, isFalse);
    final min = busbarZ(
      d: d,
      r: r,
      k: k,
      a: 50,
      c: 50,
      h: z.minHeight,
      deg: 45,
    );
    expect(min.slope, closeTo(0, 1e-9));
  });

  test('꺾기가 없으면 직선 길이 그대로', () {
    final p = busbarBendPlan(d: d, r: r, k: k, legs: [120], turns: []);
    expect(p.cutLength, 120);
    expect(p.bends, isEmpty);
  });
}
