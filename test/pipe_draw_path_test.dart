// 3D 그림을 실제 형상(직선 + 반경만큼 둥근 호)으로 그리는 셈.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/pipe_path_points.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

List<Map<String, dynamic>> bends(List<List<double>> rows) => [
  for (final r in rows) {'length': r[0], 'angle': r[1], 'rotation': r[2]},
];

/// 이어 그린 점들의 길이를 다 더한다.
double drawnLength(PipeDrawPath p) {
  var sum = 0.0;
  for (var i = 0; i < p.points.length - 1; i++) {
    sum += (p.points[i + 1] - p.points[i]).length;
  }
  return sum;
}

void main() {
  group('반경 0이면 예전처럼 각지게', () {
    test('꺾이는 점이 그대로 꼭짓점이 된다', () {
      final p = pipeDrawPath(
        bends([
          [500, 90, 0],
          [300, 0, 0],
        ]),
        startDir: 'RIGHT',
      );
      expect(p.points.length, 3);
      expect(p.points[1].x, closeTo(500, 0.001));
      expect(p.points[2].y, closeTo(300, 0.001));
      // 호가 없으니 −1(벤드 호) 토막도 없다.
      expect(p.owner.where((o) => o < 0), isEmpty);
    });
  });

  group('반경을 주면 둥근 호로', () {
    final path = pipeDrawPath(
      bends([
        [500, 90, 0],
        [300, 0, 0],
      ]),
      startDir: 'RIGHT',
      radius: 50,
      arcSteps: 12,
    );

    test('곧은 부분은 셋백만큼 짧아진다', () {
      // 90°·R50이면 셋백 50. 첫 곧은 토막은 500 − 50 = 450.
      expect(path.straightRuns.first.length, closeTo(450, 0.01));
    });

    test('호가 실제로 그려진다', () {
      expect(path.owner.where((o) => o < 0).length, greaterThan(5));
    });

    test('호 위의 점은 모두 중심에서 반경만큼 떨어져 있다', () {
      // 90° 꺾이는 곳의 중심: (450, 50, 0).
      final center = vm.Vector3(450, 50, 0);
      var checked = 0;
      for (var i = 0; i < path.owner.length; i++) {
        if (path.owner[i] >= 0) continue;
        final p = path.points[i + 1];
        expect((p - center).length, closeTo(50, 0.01));
        checked++;
      }
      expect(checked, greaterThan(5));
    });

    test('호가 끝나는 자리가 접점과 맞는다', () {
      // 접점: (500, 50, 0).
      final end = path.points[path.points.length - 2];
      expect(end.x, closeTo(500, 0.01));
      expect(end.y, closeTo(50, 0.01));
    });

    test('그린 길이가 실제 관 길이(전개 길이)와 맞는다', () {
      // 직선 450 + 호 π·50/2 + 직선 250 = 778.54
      final expected = 450 + bendArcLength(50, 90) + (300 - 50);
      // 호를 토막으로 나눠 그리므로 아주 조금 짧다(1% 안쪽).
      expect(drawnLength(path), closeTo(expected, expected * 0.01));
    });

    test('끝점은 각지게 그린 것과 같다', () {
      final sharp = pipeDrawPath(
        bends([
          [500, 90, 0],
          [300, 0, 0],
        ]),
        startDir: 'RIGHT',
      );
      expect(path.points.last.x, closeTo(sharp.points.last.x, 0.01));
      expect(path.points.last.y, closeTo(sharp.points.last.y, 0.01));
    });
  });

  group('여러 벤드', () {
    test('오프셋도 호 두 개로 그려지고 높이가 맞는다', () {
      const h = 150.0;
      final travel = h / math.sin(45 * math.pi / 180);
      final p = pipeDrawPath(
        bends([
          [500, 45, 0],
          [travel, 45, 90],
          [500, 0, 0],
        ]),
        startDir: 'RIGHT',
        radius: 38,
      );
      // 곧은 토막 셋(각 벤드 앞 + 마지막).
      expect(p.straightRuns.length, 3);
      expect(p.points.last.y, closeTo(h, 0.01));
      expect(p.points.last.z, closeTo(0, 1e-9));
    });

    test('ㄷ자는 호 세 개', () {
      final p = pipeDrawPath(
        bends([
          [600, 90, 0],
          [400, 90, 270],
          [600, 90, 180],
          [300, 0, 0],
        ]),
        startDir: 'RIGHT',
        radius: 38,
        arcSteps: 6,
      );
      // 호 토막 = 3개 벤드 × (6 나눔) 남짓.
      expect(p.owner.where((o) => o < 0).length, greaterThanOrEqualTo(18));
      expect(p.straightRuns.length, 4);
    });

    test('곧은 토막마다 몇 번째 배관 줄인지 달고 있다', () {
      final p = pipeDrawPath(
        bends([
          [600, 90, 0],
          [400, 90, 90],
          [300, 0, 0],
        ]),
        startDir: 'RIGHT',
        radius: 38,
      );
      expect(p.straightRuns.map((r) => r.bendIndex).toList(), [0, 1, 2]);
    });
  });

  group('꼬리', () {
    test('꼬리를 붙이면 마지막 방향으로 더 간다', () {
      final p = pipeDrawPath(
        bends([
          [500, 90, 0],
        ]),
        startDir: 'RIGHT',
        radius: 38,
        tail: 200,
      );
      expect(p.points.last.y, closeTo(200, 0.01));
      expect(p.straightRuns.last.bendIndex, -1);
    });
  });

  group('길이를 줄여 그리기', () {
    test('줄여 그려도 꼭짓점 자리가 비례로 줄어든다', () {
      final full = pipeDrawPath(
        bends([
          [1000, 90, 0],
          [500, 0, 0],
        ]),
        startDir: 'RIGHT',
      );
      final small = pipeDrawPath(
        bends([
          [1000, 90, 0],
          [500, 0, 0],
        ]),
        startDir: 'RIGHT',
        visualLength: (v) => v / 10,
      );
      expect(small.points[1].x, closeTo(full.points[1].x / 10, 0.001));
      expect(small.points[2].y, closeTo(full.points[2].y / 10, 0.001));
    });
  });

  group('꺾을 수 없는 방향', () {
    test('그냥 지나가고 호를 그리지 않는다', () {
      final p = pipeDrawPath(
        bends([
          [400, 90, 0],
          [400, 90, 180],
          [400, 0, 0],
        ]),
        startDir: 'UP',
        radius: 38,
      );
      expect(p.points.last.y, closeTo(1200, 0.01));
      expect(p.owner.where((o) => o < 0), isEmpty);
    });
  });

  group('배관이 없을 때', () {
    test('점 하나만', () {
      final p = pipeDrawPath(const [], startDir: 'RIGHT', radius: 38);
      expect(p.points.length, 1);
      expect(p.owner, isEmpty);
      expect(p.straightRuns, isEmpty);
    });
  });
}
