// 공간 형상 검사. 관이 실제로 어디로 가는지, 꺾을 수 있는지 본다.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/engine/bend_path.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

const double kR = 100.0;

PathSegment seg(double len, double angle, double rot) =>
    PathSegment(length: len, angle: angle, rotation: rot);

void main() {
  group('꺾을 수 있는 방향인지', () {
    test('진행 방향과 같은 방향으로는 꺾을 수 없다', () {
      final right = directionForRotation(90); // 우
      expect(canBendToward(right, directionForRotation(90)), isFalse);
    });

    test('정반대 방향도 꺾을 수 없다(평면이 안 정해진다)', () {
      final right = directionForRotation(90);
      expect(canBendToward(right, directionForRotation(270)), isFalse);
    });

    test('직각이면 꺾을 수 있다', () {
      final right = directionForRotation(90);
      for (final rot in [0.0, 180.0, 360.0, 450.0]) {
        expect(canBendToward(right, directionForRotation(rot)), isTrue);
      }
    });

    test('표에 없는 방향값은 걸러낸다', () {
      expect(isKnownRotation(30), isFalse); // 롤링 오프셋이 만들던 값
      expect(isKnownRotation(90), isTrue);
    });
  });

  group('형상', () {
    test('90° 한 번: 위로 꺾이고 끝점이 맞는다', () {
      final p = buildBendPath([seg(500, 90, 0)], radius: kR, tail: 300);
      expect(p.endDirection.y, closeTo(1.0, 0.001));
      expect(p.endPoint.x, closeTo(500.0, 0.01));
      expect(p.endPoint.y, closeTo(300.0, 0.01));
      // 전개 길이 = (500−100) + 호157.08 + (300−100)
      expect(p.developedLength, closeTo(757.08, 0.01));
    });

    test('오프셋: 높이만큼 올라가고 방향은 그대로', () {
      const h = 100.0;
      final travel = h / math.sin(45 * math.pi / 180);
      final shrink = travel - h / math.tan(45 * math.pi / 180);
      final p = buildBendPath(
        [seg(300 + shrink, 45, 0), seg(travel, 45, 180)],
        radius: kR,
        tail: 300,
      );
      expect(p.endDirection.x, closeTo(1.0, 0.001));
      expect(p.endPoint.y, closeTo(h, 0.01));
      expect(p.warnings, isEmpty);
    });

    test('3점 새들: 높이 0으로 돌아온다', () {
      const h = 100.0;
      final t = h / math.sin(22.5 * math.pi / 180);
      final shrink = (t - h / math.tan(22.5 * math.pi / 180)) * 2;
      final p = buildBendPath(
        [seg(shrink, 22.5, 0), seg(t, 45, 180), seg(t, 22.5, 0)],
        radius: kR,
        tail: 300,
      );
      expect(p.endPoint.y, closeTo(0.0, 0.01));
      expect(p.endDirection.x, closeTo(1.0, 0.001));
    });

    test('오프셋 뒤에 같은 방향 90°를 붙이면 꺾이지 않는다고 알려 준다', () {
      const h = 100.0;
      final travel = h / math.sin(45 * math.pi / 180);
      final shrink = travel - h / math.tan(45 * math.pi / 180);
      final p = buildBendPath([
        seg(300 + shrink, 45, 0),
        seg(travel, 45, 180),
        seg(400, 90, 90), // 진행 방향이 이미 '우'
      ], radius: kR);
      expect(p.warnings.length, 1);
      expect(p.warnings.first.contains('3번 구간'), isTrue);
      expect(p.warnings.first.contains('나란해서'), isTrue);
    });
  });

  group('굴림(롤) 각도', () {
    test('같은 평면에서 이어 꺾으면 0°', () {
      final p = buildBendPath([
        seg(500, 90, 0), // 우 → 위
        seg(500, 90, 270), // 위 → 좌 (같은 x-y 평면)
      ], radius: kR);
      expect(p.bends.length, 2);
      expect(p.bends[1].rollDeg, closeTo(0.0, 0.5));
    });

    test('평면을 90° 틀면 90°로 나온다', () {
      final p = buildBendPath([
        seg(500, 90, 0), // 우 → 위 (x-y 평면)
        seg(500, 90, 360), // 위 → 앞 (y-z 평면)
      ], radius: kR);
      expect(p.bends[1].rollDeg, closeTo(90.0, 0.5));
    });

    test('첫 벤드는 굴림이 없다', () {
      final p = buildBendPath([seg(500, 90, 0)], radius: kR);
      expect(p.bends.first.rollDeg, 0.0);
    });
  });

  group('구간 길이', () {
    test('벤드 사이 실제 곧은 길이를 알려 준다', () {
      final p = buildBendPath([seg(500, 90, 0), seg(600, 90, 360)], radius: kR);
      expect(p.bends[0].straightBefore, closeTo(400.0, 0.01)); // 500−100
      expect(p.bends[1].straightBefore, closeTo(400.0, 0.01)); // 600−100−100
    });

    test('짧으면 만들 수 없다고 알려 준다', () {
      final p = buildBendPath([seg(500, 90, 0), seg(150, 90, 360)], radius: kR);
      expect(p.warnings.any((w) => w.contains('만들 수 없습니다')), isTrue);
    });
  });

  test('지금 진행 방향 구하기', () {
    final d = directionAfter([seg(500, 90, 0)], radius: kR);
    expect(d.y, closeTo(1.0, 0.001));
    expect(directionAfter(const [], radius: kR).x, closeTo(1.0, 0.001));
    expect(
      directionAfter(
        const [],
        radius: kR,
        startDirection: vm.Vector3(0, 0, 1),
      ).z,
      closeTo(1.0, 0.001),
    );
  });
}
