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

  group('자유 꺾기(여러 번)', () {
    test('꺾기 하나(90°): L과 같은 부스바 — 곧은 길이 90·90이면 191.0 안팎', () {
      final f = busbarFree(d: d, r: r, k: k, straights: [90, 90], turns: [90]);
      final l = busbarL(d: d, r: r, k: k, a: 100, b: 100, deg: 90);
      expect(f.cutLength, closeTo(l.cutLength, 1e-9));
      expect(f.bends.single.start, closeTo(90, 1e-9));
    });

    test('절단 길이 = 곧은 길이 합 + 호 길이 합, 마킹은 앞에서부터 누적', () {
      const st = [50.0, 80.0, 60.0, 40.0, 70.0];
      const tu = [90.0, -45.0, 60.0, -90.0];
      final p = busbarFree(d: d, r: r, k: k, straights: st, turns: tu);
      final rho = busbarNeutralRadius(d, r, k);
      final arcs = tu.map((t) => rho * t.abs() * math.pi / 180).reduce((a, b) => a + b);
      expect(p.cutLength, closeTo(st.reduce((a, b) => a + b) + arcs, 1e-9));
      expect(p.bends.length, 4);
      for (var i = 0; i < st.length; i++) {
        expect(p.straights[i], closeTo(st[i], 1e-9));
      }
      var pos = 0.0;
      for (var i = 0; i < tu.length; i++) {
        pos += st[i];
        expect(p.bends[i].start, closeTo(pos, 1e-9), reason: '꺾기 ${i + 1} 시작선');
        pos += rho * tu[i].abs() * math.pi / 180;
        expect(p.bends[i].end, closeTo(pos, 1e-9), reason: '꺾기 ${i + 1} 끝선');
        expect(p.bends[i].turn, tu[i]);
      }
    });

    test('Z와 같은 부스바: 시작·끝 직선과 비스듬한 직선을 그대로 넣으면 절단 길이가 같다', () {
      final z = busbarZ(d: d, r: r, k: k, a: 100, c: 100, h: 40, deg: 45);
      final f = busbarFree(
        d: d,
        r: r,
        k: k,
        straights: [100, z.slope, 100],
        turns: [45, -45],
      );
      expect(f.cutLength, closeTo(z.plan.cutLength, 1e-9));
      expect(f.bends[1].start, closeTo(z.plan.bends[1].start, 1e-9));
    });

    test('꼭짓점 사이 길이로 되짚기: 꺾는 곳 6개도 곧은 길이가 그대로 돌아온다', () {
      const st = [30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0];
      const tu = [15.0, -30.0, 45.0, -60.0, 90.0, -15.0];
      final p = busbarFree(d: 6, r: 8, k: 0.4, straights: st, turns: tu);
      for (var i = 0; i < st.length; i++) {
        expect(p.straights[i], closeTo(st[i], 1e-9));
      }
    });

    test('모양 좌표: 위·아래로 번갈아 꺾으면 끝이 처음과 같은 높이로 돌아온다(Z 두 번)', () {
      final p = busbarFree(
        d: d,
        r: r,
        k: k,
        straights: [100, 60, 100, 60, 100],
        turns: [90, -90, 90, -90],
      );
      final pts = busbarShape(p, busbarNeutralRadius(d, r, k));
      // + 90°(위) 다음 −90°(아래)로 두 번 꺾으면 두 번째 구간과 마지막 구간이 처음과 같은 방향(오른쪽)이다.
      expect(pts.last.x, greaterThan(pts.first.x + 250));
      expect(pts.last.y, closeTo(2 * (60 + 2 * busbarNeutralRadius(d, r, k)), 1.0));
    });
  });
}
