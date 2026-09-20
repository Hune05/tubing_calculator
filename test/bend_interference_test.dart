import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/engine/bend_path.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

BendPath walk(List<List<double>> segs, {double radius = 20.0}) {
  return buildBendPath(
    [
      for (final s in segs)
        PathSegment(length: s[0], angle: s[1], rotation: s[2]),
    ],
    radius: radius,
    startDirection: vm.Vector3(1, 0, 0),
  );
}

void main() {
  group('두 토막 사이 거리', () {
    test('나란한 두 토막은 떨어진 만큼', () {
      final d = segmentDistance(
        vm.Vector3(0, 0, 0),
        vm.Vector3(100, 0, 0),
        vm.Vector3(0, 30, 0),
        vm.Vector3(100, 30, 0),
      );
      expect(d, closeTo(30, 0.001));
    });

    test('엇갈리는 두 토막은 0', () {
      final d = segmentDistance(
        vm.Vector3(-50, 0, 0),
        vm.Vector3(50, 0, 0),
        vm.Vector3(0, -50, 0),
        vm.Vector3(0, 50, 0),
      );
      expect(d, closeTo(0, 0.001));
    });

    test('토막 밖이면 끝점까지의 거리', () {
      final d = segmentDistance(
        vm.Vector3(0, 0, 0),
        vm.Vector3(10, 0, 0),
        vm.Vector3(30, 0, 0),
        vm.Vector3(40, 0, 0),
      );
      expect(d, closeTo(20, 0.001));
    });

    test('서로 꼬인(같은 평면에 없는) 두 토막', () {
      final d = segmentDistance(
        vm.Vector3(-50, 0, 0),
        vm.Vector3(50, 0, 0),
        vm.Vector3(0, -50, 25),
        vm.Vector3(0, 50, 25),
      );
      expect(d, closeTo(25, 0.001));
    });
  });

  group('곧은 토막 모으기', () {
    test('벤드가 없으면 토막 하나', () {
      final p = walk([
        [500, 0, 0],
      ]);
      expect(p.straights.length, 1);
      expect(p.straights.first.length, closeTo(500, 0.001));
    });

    test('벤드 하나면 토막 둘', () {
      final p = walk([
        [300, 90, 0],
        [300, 0, 0],
      ], radius: 50);
      expect(p.straights.length, 2);
      // 앞 토막은 셋백만큼 짧다(300 − 50).
      expect(p.straights[0].length, closeTo(250, 0.001));
      // 뒤 토막도 셋백만큼 짧다.
      expect(p.straights[1].length, closeTo(250, 0.001));
    });

    test('꼬리를 붙이면 마지막 토막이 길어진다', () {
      final base = buildBendPath(
        [const PathSegment(length: 300, angle: 90, rotation: 0)],
        radius: 50,
        startDirection: vm.Vector3(1, 0, 0),
      );
      final withTail = buildBendPath(
        [const PathSegment(length: 300, angle: 90, rotation: 0)],
        radius: 50,
        startDirection: vm.Vector3(1, 0, 0),
        tail: 200,
      );
      expect(withTail.straights.last.length, greaterThan(
        base.straights.last.length,
      ));
    });
  });

  group('관이 저희끼리 닿는지', () {
    test('곧은 관은 닿을 데가 없다', () {
      final p = walk([
        [1000, 0, 0],
      ]);
      expect(selfInterferenceWarnings(p, outerDiameter: 12.7), isEmpty);
    });

    test('보통 90° 한 번은 닿지 않는다', () {
      final p = walk([
        [400, 90, 0],
        [400, 0, 0],
      ], radius: 50);
      expect(selfInterferenceWarnings(p, outerDiameter: 12.7), isEmpty);
    });

    test('네모로 한 바퀴 돌면 처음 자리로 돌아와 닿는다', () {
      final p = walk([
        [200, 90, 0], // 우 → 위
        [200, 90, 270], // 위 → 좌
        [200, 90, 180], // 좌 → 아래
        [200, 0, 0],
      ]);
      final warns = selfInterferenceWarnings(p, outerDiameter: 12.7);
      expect(warns, isNotEmpty);
      expect(warns.first, contains('닿습니다'));
    });

    test('관이 굵을수록 더 일찍 걸린다', () {
      // 두 다리가 60mm 떨어진 ㄷ자.
      final p = walk([
        [300, 90, 0],
        [60, 90, 270],
        [300, 0, 0],
      ], radius: 10);
      expect(selfInterferenceWarnings(p, outerDiameter: 12.7), isEmpty);
      expect(selfInterferenceWarnings(p, outerDiameter: 100), isNotEmpty);
    });

    test('굵기를 모르면(0) 아무 말도 하지 않는다', () {
      final p = walk([
        [200, 90, 0],
        [200, 90, 270],
        [200, 90, 180],
        [200, 0, 0],
      ]);
      expect(selfInterferenceWarnings(p, outerDiameter: 0), isEmpty);
    });

    test('붙어 있는 두 토막은 벤드로 이어지므로 보지 않는다', () {
      // 아주 급한 U — 이웃한 토막끼리는 가깝지만 경고하지 않는다.
      final p = walk([
        [300, 90, 0],
        [300, 0, 0],
      ], radius: 10);
      expect(selfInterferenceWarnings(p, outerDiameter: 12.7), isEmpty);
    });
  });
}
