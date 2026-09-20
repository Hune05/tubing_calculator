// 3D 그림이 마킹 계산과 같은 형상을 그리는지 본다.
// 예전에는 그림이 꺾는 방향을 반대로 돌려서, "위"로 넣은 벤드가 아래로 갔다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/pipe_path_points.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

List<Map<String, dynamic>> bends(List<List<double>> rows) => [
  for (final r in rows) {'length': r[0], 'angle': r[1], 'rotation': r[2]},
];

void main() {
  group('그림 꼭짓점', () {
    test('곧은 관은 시작점과 끝점 둘', () {
      final p = pipePathPoints(
        bends([
          [500, 0, 0],
        ]),
        startDir: 'RIGHT',
      );
      expect(p.length, 2);
      expect(p.first, vm.Vector3.zero());
      expect(p.last.x, closeTo(500, 0.001));
    });

    test('우로 가다 위로 꺾으면 실제로 위로 간다', () {
      final p = pipePathPoints(
        bends([
          [500, 90, 0], // 우 → 위
          [300, 0, 0],
        ]),
        startDir: 'RIGHT',
      );
      expect(p.length, 3);
      // 첫 마디는 우로.
      expect(p[1].x, closeTo(500, 0.001));
      expect(p[1].y, closeTo(0, 0.001));
      // 두 번째 마디는 위로 — 예전에는 여기서 아래로 갔다.
      expect(p[2].x, closeTo(500, 0.001));
      expect(p[2].y, closeTo(300, 0.001));
    });

    test('아래로 꺾으면 아래로 간다', () {
      final p = pipePathPoints(
        bends([
          [500, 90, 180],
          [300, 0, 0],
        ]),
        startDir: 'RIGHT',
      );
      expect(p[2].y, closeTo(-300, 0.001));
    });

    test('앞으로 꺾으면 앞으로 간다', () {
      final p = pipePathPoints(
        bends([
          [500, 90, 360],
          [300, 0, 0],
        ]),
        startDir: 'RIGHT',
      );
      expect(p[2].z, closeTo(300, 0.001));
    });

    test('좌로 꺾으면 좌로 간다', () {
      final p = pipePathPoints(
        bends([
          [500, 90, 270],
          [300, 0, 0],
        ]),
        startDir: 'UP',
      );
      expect(p[2].x, closeTo(-300, 0.001));
      expect(p[2].y, closeTo(500, 0.001));
    });

    test('오프셋은 높이만 올라가고 방향은 그대로', () {
      final p = pipePathPoints(
        bends([
          [400, 45, 0],
          [141.42, 45, 90],
          [400, 0, 0],
        ]),
        startDir: 'RIGHT',
      );
      // 올라간 높이 = 141.42 × sin45 ≈ 100
      expect(p[2].y, closeTo(100, 0.1));
      expect(p[3].y, closeTo(100, 0.1)); // 마지막 마디는 수평
      expect(p[3].x - p[2].x, closeTo(400, 0.1));
    });

    test('길이를 줄여 그려도 형상은 같다', () {
      final full = pipePathPoints(
        bends([
          [1000, 90, 0],
          [500, 0, 0],
        ]),
        startDir: 'RIGHT',
      );
      final small = pipePathPoints(
        bends([
          [1000, 90, 0],
          [500, 0, 0],
        ]),
        startDir: 'RIGHT',
        visualLength: (v) => v / 10,
      );
      expect(small[1].x, closeTo(full[1].x / 10, 0.001));
      expect(small[2].y, closeTo(full[2].y / 10, 0.001));
    });

    test('꼬리를 붙이면 마지막 방향으로 더 간다', () {
      final p = pipePathPoints(
        bends([
          [500, 90, 0],
        ]),
        startDir: 'RIGHT',
        tail: 200,
      );
      expect(p.last.y, closeTo(200, 0.001));
    });

    test('시작 방향을 따라간다', () {
      final p = pipePathPoints(
        bends([
          [500, 0, 0],
        ]),
        startDir: 'FRONT',
      );
      expect(p.last.z, closeTo(500, 0.001));
    });

    test('배관이 없으면 시작점만', () {
      final p = pipePathPoints(const [], startDir: 'RIGHT');
      expect(p.length, 1);
    });
  });
}
