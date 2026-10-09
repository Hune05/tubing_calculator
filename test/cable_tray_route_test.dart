import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/cable_tray_route.dart';

void main() {
  test('V컷 폭 = 2 × 측판 높이 × tan(각/2)', () {
    expect(trayNotchWidth(100, 90), closeTo(200, 1e-9));
    expect(trayNotchWidth(100, 45), closeTo(82.84, 0.01));
    expect(trayNotchWidth(100, -30), closeTo(53.59, 0.01));
  });

  test('90° 넘어가기: 손으로 계산한 마킹', () {
    final r = trayRoute(
      kind: TrayRouteKind.over,
      rise: 300,
      angle: 90,
      rail: 100,
      obstacle: 400,
      side: 50,
      toFace: 1000,
      tail: 500,
    );
    expect(r.ok, isTrue);
    expect(r.leg, closeTo(300, 1e-9));
    expect(r.footprint, closeTo(0, 1e-9));
    expect(r.lead, closeTo(950, 1e-9));
    expect(r.top, 500);
    expect(r.corners.map((c) => c.turn), [90, -90, -90, 90]);
    expect(r.corners.map((c) => c.mark.round()), [950, 1350, 2050, 2450]);
    // 바닥면 선 2550 + 아랫변 V컷 두 개 200 × 2
    expect(r.material, closeTo(2950, 1e-9));
    expect(r.points.last.$2, closeTo(0, 1e-9));
    expect(r.points.last.$1, closeTo(1950, 1e-9));
  });

  test('45° 넘어가기: 경사 길이·수평 길이', () {
    final r = trayRoute(
      kind: TrayRouteKind.over,
      rise: 300,
      angle: 45,
      rail: 100,
      obstacle: 400,
      side: 50,
      toFace: 1000,
    );
    expect(r.leg, closeTo(300 * math.sqrt2, 1e-9));
    expect(r.footprint, closeTo(300, 1e-9));
    expect(r.lead, closeTo(650, 1e-9));
    // 윗면 첫 꺾는 점은 장애물 앞면 − 여유
    expect(r.corners[1].x, closeTo(950, 1e-9));
    expect(r.corners[1].y, closeTo(300, 1e-9));
    expect(r.corners[2].x, closeTo(1450, 1e-9));
  });

  test('나눠 꺾기: 90° = 30° 3번, 마디 150', () {
    final low = trayRoute(
      kind: TrayRouteKind.up,
      rise: 300,
      angle: 90,
      rail: 100,
      toFace: 1000,
      pieces: 3,
      pitch: 150,
    );
    expect(low.ok, isFalse);
    final r = trayRoute(
      kind: TrayRouteKind.up,
      rise: 600,
      angle: 90,
      rail: 100,
      toFace: 1000,
      pieces: 3,
      pitch: 150,
    );
    expect(r.ok, isTrue);
    expect(r.corners.length, 6);
    expect(r.leg, closeTo(600 - 2 * 150 * (0.5 + math.sqrt(3) / 2), 1e-9));
    expect(r.footprint, closeTo(2 * 150 * (math.sqrt(3) / 2 + 0.5), 1e-9));
    expect(r.radius, closeTo(150 / (2 * math.tan(math.pi / 12)), 1e-9));
    expect(r.points.last.$2, closeTo(600, 1e-6));
    // 끝은 다시 수평
    expect(r.corners.fold<double>(0, (s, c) => s + c.turn), closeTo(0, 1e-9));
  });

  test('내려가기는 단 끝 + 여유에서 아래로 먼저 꺾는다', () {
    final r = trayRoute(
      kind: TrayRouteKind.down,
      rise: 200,
      angle: 45,
      rail: 75,
      side: 50,
      toFace: 800,
    );
    expect(r.lead, 850);
    expect(r.corners.first.turn, -45);
    expect(
      r.corners.first.mark,
      closeTo(850 + trayNotchWidth(75, 45) / 2, 1e-9),
    );
    expect(r.points.last.$2, closeTo(-200, 1e-9));
  });

  test('시작점이 너무 가까우면 알린다', () {
    final r = trayRoute(
      kind: TrayRouteKind.over,
      rise: 300,
      angle: 30,
      rail: 100,
      obstacle: 400,
      toFace: 200,
    );
    expect(r.ok, isFalse);
    expect(r.problems.single, contains('너무 가깝'));
  });

  test('트레이 개수', () {
    final r = trayRoute(
      kind: TrayRouteKind.over,
      rise: 300,
      angle: 90,
      rail: 100,
      obstacle: 400,
      side: 50,
      toFace: 1000,
      tail: 500,
    );
    expect(r.lengthsNeeded(3000), 1);
    expect(r.lengthsNeeded(2000), 2);
  });

  test('옆으로 비켜가기: 트레이 폭이 V컷 깊이, 계산은 넘어가기와 같다', () {
    final r = trayRoute(
      kind: TrayRouteKind.aside,
      rise: 250,
      angle: 90,
      rail: 300,
      obstacle: 400,
      side: 50,
      toFace: 1000,
      tail: 500,
    );
    expect(r.ok, isTrue);
    expect(r.corners.map((c) => c.turn), [90, -90, -90, 90]);
    expect(r.corners.first.notch, closeTo(600, 1e-9));
    // 950 / 950 + 250 + 300 / + 600 + 500 / + 600 + 250
    expect(r.corners.map((c) => c.mark.round()), [950, 1500, 2600, 3150]);
    expect(r.material, closeTo(3650, 1e-9));
    expect(trayRouteIsPlan(TrayRouteKind.aside), isTrue);
    expect(trayRouteReturns(TrayRouteKind.shift), isFalse);
  });

  test('옆으로 옮겨가기는 꺾는 곳 두 무리, 거리가 짧으면 알림', () {
    final r = trayRoute(
      kind: TrayRouteKind.shift,
      rise: 200,
      angle: 45,
      rail: 300,
      side: 50,
      toFace: 1000,
    );
    expect(r.corners.length, 2);
    expect(r.points.last.$2, closeTo(200, 1e-9));
    final short = trayRoute(
      kind: TrayRouteKind.shift,
      rise: 100,
      angle: 90,
      rail: 300,
      toFace: 1000,
      pieces: 3,
      pitch: 150,
    );
    expect(short.problems.first, contains('옮길 거리가 짧아'));
  });

  test('기성 엘보 올라가기 90°: R300·측판 100·끝 직선 100', () {
    // 기준선 반경: IN = 300 + 100, OUT = 300. 경사 직선 = 1200 − 700 − 200 = 300
    final r = trayElbowRoute(
      kind: TrayRouteKind.up,
      rise: 1200,
      angle: 90,
      rail: 100,
      radius: 300,
      tangent: 100,
      side: 50,
      toFace: 1000,
      tail: 500,
    );
    expect(r.ok, isTrue);
    expect(r.leg, closeTo(300, 1e-9));
    expect(r.footprint, closeTo(900, 1e-9));
    expect(r.lead, closeTo(50, 1e-9));
    expect(r.elbows, 2);
    expect(r.straights.map((p) => p.length.round()), [50, 300, 500]);
    expect(r.shape.points.last.$1, closeTo(950 + 500, 1e-6));
    expect(r.shape.points.last.$2, closeTo(1200, 1e-6));
    expect(r.sideA, 400);
    expect(trayElbowName(TrayRouteKind.up, true), '수직 엘보 IN');
  });

  test('기성 엘보 넘어가기 45°: 다시 바닥으로, 엘보 4개', () {
    final r = trayElbowRoute(
      kind: TrayRouteKind.over,
      rise: 350,
      angle: 45,
      rail: 100,
      radius: 300,
      tangent: 100,
      obstacle: 400,
      side: 50,
      toFace: 2000,
    );
    expect(r.ok, isTrue);
    expect(r.elbows, 4);
    expect(r.pieces.where((p) => p.elbow).map((p) => p.turn), [
      45,
      -45,
      -45,
      45,
    ]);
    expect(r.shape.points.last.$2, closeTo(0, 1e-6));
    // 윗면 직선 = 장애물 + 앞뒤 여유, 기준선 높이 350
    expect(r.top, 500);
    expect(r.pieces[4].from.$2, closeTo(350, 1e-6));
    expect(r.pieces[4].from.$1, closeTo(2000 - 50, 1e-6));
  });

  test('기성 엘보: 높이가 낮으면 알림', () {
    final r = trayElbowRoute(
      kind: TrayRouteKind.up,
      rise: 600,
      angle: 90,
      rail: 100,
      radius: 300,
      toFace: 3000,
    );
    expect(r.ok, isFalse);
    expect(r.problems.first, contains('높이가 낮아'));
    final p = trayElbowRoute(
      kind: TrayRouteKind.aside,
      rise: 100,
      angle: 90,
      rail: 300,
      radius: 300,
      toFace: 3000,
    );
    expect(p.problems.first, contains('옮길 거리가 짧아'));
    expect(trayElbowName(TrayRouteKind.aside, true), '수평 엘보');
  });

  // 대양엔지니어링 2025 카탈로그 18쪽 수평 엘보 표(R1 = 안쪽 레일, R2 = R1 + W). 엔진으로 첫 엘보를
  // 그려 끝면 치수를 재면 끝 직선 125일 때 A·B가 맞는다(그림에는 100이라 적혀 있음).
  // 표에서 뺀 줄: 90° W300(A가 R2 + 175, 다른 줄은 R2 + 125), 90° W150 R300(570, +120), W500 줄(값이 W600).
  (double, double) dyElbow(double w, double r1, double deg, double t) {
    final e = trayElbowRoute(
      kind: TrayRouteKind.aside,
      rise: 5000,
      angle: deg,
      rail: w,
      radius: r1,
      tangent: t,
      toFace: 20000,
    );
    final p = e.pieces[1];
    final a = p.to.$1 - p.from.$1;
    // B(60°): 바깥 레일 시작에서 안쪽 레일 끝면까지 높이 = 기준선 끝 높이 + W·cos(60°)
    final b = p.to.$2 - p.from.$2 + w * math.cos(deg * math.pi / 180);
    return (a, b);
  }

  test('대양 수평 엘보 90° 표 A = R2 + 125', () {
    const rows = [
      [150, 600, 875],
      [150, 900, 1175],
      [200, 300, 625],
      [200, 600, 925],
      [200, 900, 1225],
      [450, 300, 875],
      [450, 600, 1175],
      [450, 900, 1475],
      [750, 300, 1175],
      [750, 600, 1475],
      [900, 300, 1325],
      [900, 900, 1925],
      [1000, 300, 1425],
      [1000, 600, 1725],
      [1000, 900, 2025],
    ];
    for (final r in rows) {
      expect(
        dyElbow(r[0].toDouble(), r[1].toDouble(), 90, 125).$1,
        closeTo(r[2], 0.5),
        reason: 'W${r[0]} R${r[1]}',
      );
    }
    // 끝 직선 100이면 25씩 모자란다
    expect(dyElbow(200, 300, 90, 100).$1, closeTo(600, 0.5));
  });

  test('대양 수평 엘보 60° 표 A·B', () {
    const rows = [
      // W, R1, A, B
      [150, 300, 577, 408], [150, 600, 837, 558], [150, 900, 1097, 708],
      [200, 300, 620, 458], [200, 600, 880, 608], [200, 900, 1140, 758],
      [300, 300, 707, 558], [300, 600, 967, 708], [300, 900, 1227, 858],
      [450, 300, 837, 708], [450, 600, 1097, 858], [450, 900, 1357, 1008],
      [750, 300, 1097, 1008], [750, 600, 1357, 1158], [750, 900, 1617, 1308],
      [900, 300, 1227, 1158], [900, 600, 1487, 1308], [900, 900, 1747, 1458],
    ];
    for (final r in rows) {
      final (a, b) = dyElbow(r[0].toDouble(), r[1].toDouble(), 60, 125);
      expect(a, closeTo(r[2], 1), reason: 'A W${r[0]} R${r[1]}');
      expect(b, closeTo(r[3], 1), reason: 'B W${r[0]} R${r[1]}');
    }
    // W1000 줄은 A가 200씩 늘어 다른 줄(260씩)과 안 맞는다(표 오기로 봄). B만 맞춘다.
    for (final (r1, b) in const [
      (300.0, 1258.0),
      (600.0, 1408.0),
      (900.0, 1558.0),
    ]) {
      expect(dyElbow(1000, r1, 60, 125).$2, closeTo(b, 1));
    }
  });

  // 대양 카탈로그 19쪽 수직 엘보 90° IN 표: 폭 150~1000 모두 R 300/600/900 → A 425/725/1025.
  // A는 끝면에서 다른 쪽 다리의 안쪽 테두리(측판 윗변)까지라 측판 높이와 관계없다.
  // 같은 쪽 "60° OUT" 표는 번호(VE9-)·그림(90°)·값이 90° 표와 똑같아 옮겨 적은 것으로 보고 뺐다.
  test('대양 수직 엘보 90° IN 표 A = R + 125 (측판 높이와 관계없음)', () {
    for (final h in kTrayRailHeights) {
      for (final (r, a) in const [
        (300.0, 425.0),
        (600.0, 725.0),
        (900.0, 1025.0),
      ]) {
        final e = trayElbowRoute(
          kind: TrayRouteKind.up,
          rise: 5000,
          angle: 90,
          rail: h,
          radius: r,
          tangent: 125,
          toFace: 20000,
        );
        final p = e.pieces[1];
        expect(p.elbow && p.up, isTrue);
        // 바닥면 기준선은 R + 측판 높이로 돈다 → 가로 A = 끝 직선 + R + H − H
        expect(p.to.$1 - p.from.$1 - h, closeTo(a, 1e-6), reason: 'H$h R$r 가로');
        // 세로 A: 위 끝면에서 아래 다리 윗변(높이 H)까지
        expect(p.to.$2 - p.from.$2 - h, closeTo(a, 1e-6), reason: 'H$h R$r 세로');
      }
    }
    expect(
      trayElbowRoute(
        kind: TrayRouteKind.up,
        rise: 5000,
        angle: 90,
        rail: 100,
        radius: 300,
        toFace: 20000,
      ).sideA,
      425,
    );
  });

  // 대양 카탈로그 20쪽 수평 티 표(W, R, A, B). "W500" 줄은 값이 W600이라 600으로, W200 R300 B "1625"는 625로 읽었다.
  test('대양 수평 티 표 A = W + 2(R + 125), B = W + R + 125', () {
    const rows = [
      [150, 300, 1000, 575],
      [150, 600, 1600, 875],
      [150, 900, 2200, 1175],
      [200, 300, 1050, 625],
      [200, 600, 1650, 925],
      [200, 900, 2250, 1225],
      [300, 300, 1150, 725],
      [300, 600, 1750, 1025],
      [300, 900, 2350, 1325],
      [450, 300, 1300, 875],
      [450, 600, 1900, 1175],
      [450, 900, 2500, 1475],
      [600, 300, 1450, 1025],
      [600, 600, 2050, 1325],
      [600, 900, 2650, 1625],
      [750, 300, 1600, 1175],
      [750, 600, 2200, 1475],
      [750, 900, 2800, 1775],
      [900, 300, 1750, 1325],
      [900, 600, 2350, 1625],
      [900, 900, 2950, 1925],
      [1000, 300, 1850, 1425],
      [1000, 600, 2450, 1725],
      [1000, 900, 3050, 2025],
    ];
    for (final r in rows) {
      final t = trayTee(
        width: r[0].toDouble(),
        radius: r[1].toDouble(),
        tangent: 125,
        at: 9000,
        reach: 9000,
      );
      expect(t.a, closeTo(r[2], 1e-9), reason: 'A W${r[0]} R${r[1]}');
      expect(t.b, closeTo(r[3], 1e-9), reason: 'B W${r[0]} R${r[1]}');
    }
  });

  test('가지 내기: 티 앞 본선·가지 직선, 너무 가까우면 알림', () {
    final t = trayTee(
      width: 300,
      radius: 300,
      at: 1000,
      reach: 1000,
      tail: 500,
    );
    expect(t.tangent, 125);
    expect(t.before, closeTo(425, 1e-9)); // 1000 − 1150 ÷ 2
    expect(t.branch, closeTo(575, 1e-9)); // 1000 − (300 + 125)
    expect(t.straightTotal, closeTo(1500, 1e-9));
    expect(t.ok, isTrue);
    final near = trayTee(width: 300, radius: 300, at: 400, reach: 300);
    expect(near.problems.length, 2);
    expect(near.before, 0);
    expect(near.branch, 0);
  });

  test('나눠 꺾기에서 마디 간격이 V컷 폭보다 좁으면 겹친다고 알린다(8차)', () {
    // 90°를 3번(30°씩), 측판 100 → V컷 폭 2×100×tan15° = 53.6mm
    final tight = trayRoute(
      kind: TrayRouteKind.up,
      rise: 400,
      angle: 90,
      rail: 100,
      toFace: 1000,
      pieces: 3,
      pitch: 30,
    );
    expect(tight.problems.any((p) => p.contains('V컷이 서로 겹칩니다')), isTrue);
    final ok = trayRoute(
      kind: TrayRouteKind.up,
      rise: 400,
      angle: 90,
      rail: 100,
      toFace: 1000,
      pieces: 3,
      pitch: 60,
    );
    expect(ok.problems.any((p) => p.contains('V컷이 서로 겹칩니다')), isFalse);
  });
}
