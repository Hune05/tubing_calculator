// 90°를 바로 이어 넣는 것처럼 앞뒤 셋백보다 짧은 구간이 있을 때,
// 3D 그림이 꼬이지 않는지 본다.
// 예전에는 휘기 시작하는 자리가 지나온 자리보다 뒤에 있어서,
// 선이 뒤로 가며 형상이 겹쳤다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/pipe_path_points.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

List<Map<String, dynamic>> bends(List<List<double>> rows) => [
  for (final r in rows) {'length': r[0], 'angle': r[1], 'rotation': r[2]},
];

/// 곧은 토막이 그 구간의 진행 방향과 반대로 가는지 본다.
/// 반대로 가면 그림이 지나온 자리로 되돌아가 형상이 겹친다.
bool goesBackwards(List<Map<String, dynamic>> list, String startDir,
    PipeDrawPath curved) {
  // 각지게 그린 꼭짓점(모든 구간이 점으로 남는다)으로 구간 방향을 잡는다.
  final sharp = pipePathPoints(list, startDir: startDir);
  for (final run in curved.straightRuns) {
    final i = run.bendIndex;
    if (i < 0 || i + 1 >= sharp.length) continue;
    final want = sharp[i + 1] - sharp[i];
    final got = run.b - run.a;
    if (want.length2 < 1e-9 || got.length2 < 1e-9) continue;
    if (want.normalized().dot(got.normalized()) < 0) return true;
  }
  return false;
}

void main() {
  const r = 38.1; // 3/8" 튜브. 90° 셋백 38.1.

  group('90°를 바로 이어 넣어도 형상이 꼬이지 않는다', () {
    for (final second in const [0.0, 10.0, 30.0, 50.0, 76.0]) {
      test('두 번째 구간 ${second.toInt()}mm', () {
        final p = pipeDrawPath(
          bends([
            [100, 90, 0],
            [second, 90, 90],
            [200, 0, 0],
          ]),
          startDir: 'RIGHT',
          radius: r,
        );
        expect(
          goesBackwards(
            bends([
              [100, 90, 0],
              [second, 90, 90],
              [200, 0, 0],
            ]),
            'RIGHT',
            p,
          ),
          isFalse,
          reason: '선이 뒤로 갔다',
        );
        for (final run in p.straightRuns) {
          expect(run.length, greaterThanOrEqualTo(0.0));
        }
      });
    }

    test('넉넉한 구간은 예전처럼 호로 그린다', () {
      final p = pipeDrawPath(
        bends([
          [300, 90, 0],
          [300, 90, 90],
          [300, 0, 0],
        ]),
        startDir: 'RIGHT',
        radius: r,
      );
      expect(
        goesBackwards(
          bends([
            [300, 90, 0],
            [300, 90, 90],
            [300, 0, 0],
          ]),
          'RIGHT',
          p,
        ),
        isFalse,
      );
      // 호 토막이 있다.
      expect(p.owner.where((o) => o < 0).length, greaterThan(10));
    });

    test('만들 수 없는 형상은 통째로 각진 모서리로 그린다', () {
      final p = pipeDrawPath(
        bends([
          [100, 90, 0],
          [10, 90, 90],
          [200, 0, 0],
        ]),
        startDir: 'RIGHT',
        radius: r,
      );
      // 호를 그리면 선이 되돌아가 형상이 꼬이므로, 아예 각지게 그린다.
      expect(p.owner.where((o) => o < 0), isEmpty);
      // 그래도 마디는 다 나온다.
      expect(p.straightRuns.length, 3);
    });

    test('끝점은 각지게 그린 것과 같다', () {
      final list = bends([
        [100, 90, 0],
        [20, 90, 90],
        [200, 0, 0],
      ]);
      final curved = pipeDrawPath(list, startDir: 'RIGHT', radius: r);
      final sharp = pipeDrawPath(list, startDir: 'RIGHT');
      expect(curved.points.last.x, closeTo(sharp.points.last.x, 0.01));
      expect(curved.points.last.y, closeTo(sharp.points.last.y, 0.01));
      expect(curved.points.last.z, closeTo(sharp.points.last.z, 0.01));
    });
  });

  group('첫 구간이 셋백보다 짧을 때', () {
    test('선이 뒤로 가지 않는다', () {
      final p = pipeDrawPath(
        bends([
          [20, 90, 0],
          [300, 0, 0],
        ]),
        startDir: 'RIGHT',
        radius: r,
      );
      expect(
        goesBackwards(
          bends([
            [20, 90, 0],
            [300, 0, 0],
          ]),
          'RIGHT',
          p,
        ),
        isFalse,
      );
      expect(p.points.first, vm.Vector3.zero());
    });
  });

  group('길이 0짜리 벤드를 여럿 이어 넣어도', () {
    test('형상이 겹치지 않는다', () {
      final p = pipeDrawPath(
        bends([
          [200, 90, 0],
          [0, 90, 90],
          [0, 90, 180],
          [200, 0, 0],
        ]),
        startDir: 'RIGHT',
        radius: r,
      );
      expect(
        goesBackwards(
          bends([
            [200, 90, 0],
            [0, 90, 90],
            [0, 90, 180],
            [200, 0, 0],
          ]),
          'RIGHT',
          p,
        ),
        isFalse,
      );
    });
  });
}
