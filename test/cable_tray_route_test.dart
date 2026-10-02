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
}
