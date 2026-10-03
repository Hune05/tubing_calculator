// 전선관 특수 벤딩(킥·분할 90°·백투백 90°·스터브업) 셈: 손으로 푼 값과 맞추고, 만든 목록을 벤딩 경로 엔진에
// 넣어 실제 모양(끝 위치·접선·평행)이 맞는지 따로 확인한다.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/engine/bend_path.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_special_calc.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

BendPath walk(List<Map<String, dynamic>> bends) => buildBendPath(
  [
    for (final b in bends)
      PathSegment(
        length: (b['length'] as num).toDouble(),
        angle: (b['angle'] as num).toDouble(),
        rotation: (b['rotation'] as num).toDouble(),
      ),
  ],
  radius: 0,
  startDirection: directionForName('RIGHT'),
);

/// 점 [p]에서 두 점 [a]·[b]를 지나는 직선까지 거리(3D).
double distToLine(vm.Vector3 p, vm.Vector3 a, vm.Vector3 b) =>
    (p - a).cross((b - a).normalized()).length;

void main() {
  group('킥', () {
    test('H 100, 30° → 비스듬한 길이 200, 앞으로 173.2, 축소값 26.8, 배수 2', () {
      final k = conduitKick(height: 100, angle: 30)!;
      expect(k.travel, closeTo(200, 1e-9));
      expect(k.run, closeTo(100 / math.tan(math.pi / 6), 1e-9));
      expect(k.run, closeTo(173.205, 0.001));
      expect(k.shrink, closeTo(26.795, 0.001));
      expect(k.multiplier, closeTo(2, 1e-9));
    });

    test('45° → 배수 1.414, 축소값 = H × (√2 − 1)', () {
      final k = conduitKick(height: 100, angle: 45)!;
      expect(k.multiplier, closeTo(math.sqrt2, 1e-9));
      expect(k.shrink, closeTo(100 * (math.sqrt2 - 1), 1e-9));
    });

    test('높이 0·각도 0·90° 이상은 null', () {
      expect(conduitKick(height: 0, angle: 30), isNull);
      expect(conduitKick(height: 100, angle: 0), isNull);
      expect(conduitKick(height: 100, angle: 90), isNull);
    });

    test('엔진으로 확인: 꺾은 뒤 비스듬한 길이만큼 가면 정확히 H만큼 올라가 있다', () {
      final k = conduitKick(height: 100, angle: 30)!;
      final p = walk([
        {'length': 500.0, 'angle': 30.0, 'rotation': 0.0},
        {'length': k.travel, 'angle': 0.0, 'rotation': 0.0},
      ]);
      final end = p.corners.last;
      expect(end.y, closeTo(100, 1e-6), reason: '위로 100');
      expect(end.x, closeTo(500 + k.run, 1e-6), reason: '앞으로 꺾은 자리 + 173.2');
    });
  });

  group('분할 90°', () {
    test('R 300, 3번: 각 30°, 간격 2R·tan15° = 160.77, 모서리~첫 점 R(1 − tan15°) = 219.62', () {
      final s = conduitSegmented(radius: 300, bends: 3)!;
      expect(s.angle, 30);
      expect(s.spacing, closeTo(2 * 300 * math.tan(math.pi / 12), 1e-9));
      expect(s.spacing, closeTo(160.77, 0.01));
      expect(s.lead, closeTo(219.62, 0.01));
      expect(s.arcLength, closeTo(471.24, 0.01));
    });

    test('횟수 1 이하·13 이상, 반경 0 이하는 null', () {
      expect(conduitSegmented(radius: 300, bends: 1), isNull);
      expect(conduitSegmented(radius: 300, bends: 13), isNull);
      expect(conduitSegmented(radius: 0, bends: 5), isNull);
    });

    test('목록: 첫 줄 = 모서리 거리 − lead, 나머지는 간격, 각도 합 90°', () {
      final b = conduitSegmentedBends(
        cornerDistance: 1000,
        radius: 300,
        bends: 3,
        rotation: 0,
      )!;
      expect(b.length, 3);
      expect(b[0]['length'], closeTo(1000 - 219.62, 0.06));
      expect(b[1]['length'], closeTo(160.8, 0.06));
      expect(b.fold<double>(0, (a, e) => a + (e['angle'] as num).toDouble()), closeTo(90, 1e-9));
    });

    test('반경이 모서리 거리에 비해 너무 크면 null', () {
      expect(
        conduitSegmentedBends(cornerDistance: 100, radius: 300, bends: 3, rotation: 0),
        isNull,
      );
    });

    for (final n in [2, 3, 4, 5, 7, 9]) {
      test('엔진으로 확인($n번): 다각형의 모든 변이 반경 R 원호에 접하고 끝 방향이 위다', () {
        const double R = 300, corner = 1000;
        final b = conduitSegmentedBends(
          cornerDistance: corner,
          radius: R,
          bends: n,
          rotation: 0,
        )!;
        // 마지막 꺾이는 점 뒤로 곧은 구간 하나를 더 붙여 끝 방향을 본다.
        final p = walk([
          ...b,
          {'length': 400.0, 'angle': 0.0, 'rotation': 0.0},
        ]);
        final pts = [vm.Vector3.zero(), ...p.corners];
        // 가상 직각 모서리 (1000, 0), 호의 중심 = 모서리 − 처음 방향·R + 나중 방향·R = (700, 300)
        final c = vm.Vector3(corner - R, R, 0);
        for (var i = 0; i + 1 < pts.length; i++) {
          if ((pts[i + 1] - pts[i]).length < 1e-6) continue;
          // 마지막 곧은 구간(끝 점 포함)은 위 방향 직선: x = 1000
          expect(
            distToLine(c, pts[i], pts[i + 1]),
            closeTo(R, 0.1 * n),
            reason: '변 $i (${pts[i]} → ${pts[i + 1]})',
          );
        }
        final dir = (pts.last - pts[pts.length - 2]).normalized();
        expect(dir.y, closeTo(1, 1e-6), reason: '끝 방향 = 위');
      });
    }
  });

  group('백투백 90°', () {
    test('바깥~바깥 300, 관 26.5 → 꺾이는 점 간격 273.5, 안쪽~안쪽 300 → 326.5', () {
      expect(conduitBackToBackSpacing(distance: 300, od: 26.5, outside: true), 273.5);
      expect(conduitBackToBackSpacing(distance: 300, od: 26.5, outside: false), 326.5);
    });

    test('엔진으로 확인: 두 다리가 평행하고 반대로 가며, 바깥~바깥 거리 = 간격 + 관 지름', () {
      const double od = 26.5;
      final spacing = conduitBackToBackSpacing(distance: 300, od: od, outside: true);
      final b = conduitBackToBackBends(
        firstLength: 400,
        spacing: spacing,
        firstRotation: 0, // 첫 90°: 위로
        secondRotation: 270, // 둘째 90°: 처음 진행(우)의 반대(좌)
      )!;
      final p = walk([
        ...b,
        {'length': 300.0, 'angle': 0.0, 'rotation': 270.0},
      ]);
      final v1 = p.corners[0], v2 = p.corners[1], end = p.corners[2];
      expect(v1.x, closeTo(400, 1e-9));
      expect(v2.y, closeTo(spacing, 1e-9));
      expect((end - v2).normalized().x, closeTo(-1, 1e-9), reason: '두 번째 다리는 왼쪽으로 돌아온다');
      // 처음 다리(y = 0 선)와 돌아오는 다리(y = 간격 선)는 평행, 바깥 거리 = 간격 + OD.
      expect(v2.y - 0 + od, closeTo(300, 1e-9));
    });

    test('길이·간격이 0 이하면 null', () {
      expect(
        conduitBackToBackBends(firstLength: 0, spacing: 100, firstRotation: 0, secondRotation: 270),
        isNull,
      );
      expect(
        conduitBackToBackBends(firstLength: 100, spacing: -1, firstRotation: 0, secondRotation: 270),
        isNull,
      );
    });
  });

  group('스터브업', () {
    test('길이 300, 위로 → 한 줄, 엔진에서 꺾이는 점이 (300, 0)이고 끝 방향이 위', () {
      final b = conduitStubBends(stub: 300, rotation: 0)!;
      expect(b.length, 1);
      final p = walk([
        ...b,
        {'length': 200.0, 'angle': 0.0, 'rotation': 0.0},
      ]);
      expect(p.corners[0].x, closeTo(300, 1e-9));
      expect(p.corners[1].y, closeTo(200, 1e-9));
    });
    test('0 이하는 null', () => expect(conduitStubBends(stub: 0, rotation: 0), isNull));
  });
}
