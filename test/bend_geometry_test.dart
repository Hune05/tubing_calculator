// 벤딩 기하 검사. 손으로 푼 값과 맞는지 본다.
// 여기 값이 바뀌면 마킹·절단 길이가 바뀐 것이므로, 현장에서 다시 재 보기 전에는
// 고치면 안 된다.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';

void main() {
  group('셋백·호·게인 (반경 100mm)', () {
    test('90°: 셋백 100, 호 157.08, 게인 42.92', () {
      expect(bendSetback(100, 90), closeTo(100.0, 0.01));
      expect(bendArcLength(100, 90), closeTo(157.08, 0.01));
      expect(geometricGain(100, 90), closeTo(42.92, 0.01));
    });

    test('45°: 셋백 41.42, 호 78.54, 게인 4.30', () {
      expect(bendSetback(100, 45), closeTo(41.42, 0.01));
      expect(bendArcLength(100, 45), closeTo(78.54, 0.01));
      expect(geometricGain(100, 45), closeTo(4.30, 0.01));
    });

    test('30°: 게인 1.23 (각도에 비례하지 않는다)', () {
      expect(geometricGain(100, 30), closeTo(1.23, 0.01));
      // 각도 비례로 봤다면 42.92/3 = 14.3이 됐을 값이다.
      expect(geometricGain(100, 30) < 2.0, isTrue);
    });

    test('0°·음수·반경 0은 0', () {
      expect(bendSetback(100, 0), 0.0);
      expect(bendArcLength(0, 90), 0.0);
      expect(geometricGain(100, -10), 0.0);
    });
  });

  group('실측 게인 각도 환산', () {
    // 현장에서 90°로 한 번 꺾어 잰 게인이 40mm일 때.
    const measured = 40.0;

    test('90°는 잰 값 그대로', () {
      expect(scaleMeasuredGain(measured, 90), closeTo(40.0, 0.001));
    });

    test('45°는 4.01 (비례 환산이면 20이 나와 16mm 어긋났다)', () {
      expect(scaleMeasuredGain(measured, 45), closeTo(4.01, 0.01));
    });

    test('22.5°는 0.48, 60°는 10.02, 75°는 21.03', () {
      expect(scaleMeasuredGain(measured, 22.5), closeTo(0.48, 0.01));
      expect(scaleMeasuredGain(measured, 60), closeTo(10.02, 0.01));
      expect(scaleMeasuredGain(measured, 75), closeTo(21.03, 0.01));
    });

    test('반경으로 구한 게인과 같은 모양이다', () {
      // 반경 100에서 90° 게인은 42.92. 그 값을 실측이라 치고 환산하면
      // 각도별로 기하 게인과 같아야 한다.
      final g90 = geometricGain(100, 90);
      for (final double deg in [22.5, 30, 45, 60, 75, 90]) {
        expect(
          scaleMeasuredGain(g90, deg),
          closeTo(geometricGain(100, deg), 0.01),
          reason: '$deg°',
        );
      }
    });
  });

  group('쓸 게인 고르기', () {
    test('실측값이 있으면 실측을 환산해서 쓴다', () {
      final g = effectiveGain(radius: 100, angleDeg: 45, measuredGain90: 40);
      expect(g, closeTo(4.01, 0.01));
    });

    test('실측값이 없으면 반경으로 구한다', () {
      final g = effectiveGain(radius: 100, angleDeg: 45);
      expect(g, closeTo(4.30, 0.01));
    });

    test('실제 휘는 길이 = 2·셋백 − 게인, 반경만 쓰면 호와 같다', () {
      final ba = realBendAllowance(radius: 100, angleDeg: 45);
      expect(ba, closeTo(bendArcLength(100, 45), 0.001));
    });
  });

  group('오프셋·새들 삼각형', () {
    test('오프셋 45°·높이 100: 빗변 141.42, 런 100, 축소값 41.42', () {
      const h = 100.0;
      final travel = h / math.sin(45 * math.pi / 180);
      final run = h / math.tan(45 * math.pi / 180);
      expect(travel, closeTo(141.42, 0.01));
      expect(run, closeTo(100.0, 0.01));
      expect(travel - run, closeTo(41.42, 0.01));
    });

    test('3점 새들 45°·높이 100: 옆 각도 22.5°, 빗변 261.31', () {
      const h = 100.0;
      final travel = h / math.sin(22.5 * math.pi / 180);
      expect(travel, closeTo(261.31, 0.01));
    });
  });
}
