// 수평계·각도기 셈.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/field_tools/tilt_math.dart';

const g = 9.81;
double sinD(double d) => math.sin(d * math.pi / 180);
double cosD(double d) => math.cos(d * math.pi / 180);

void main() {
  group('축이 들린 각', () {
    test('눕혀 두면 0°', () {
      expect(axisElevation(0, 0, 0, g), closeTo(0, 1e-9));
    });

    test('오른쪽이 3° 들리면 x축 +3°', () {
      final x = g * sinD(3), z = g * cosD(3);
      expect(axisElevation(x, x, 0, z), closeTo(3, 1e-9));
    });

    test('크기가 9.81이 아니어도(흔들림) 각은 같다', () {
      final x = 2 * sinD(10), z = 2 * cosD(10);
      expect(axisElevation(x, x, 0, z), closeTo(10, 1e-9));
    });
  });

  group('놓인 모양', () {
    test('눕힘·세움·옆으로 세움', () {
      expect(poseFor(0.1, 0.2, g), TiltPose.flat);
      expect(poseFor(0.1, g, 0.3), TiltPose.upright);
      expect(poseFor(-g, 0.1, 0.3), TiltPose.sideways);
    });

    test('바뀌는 경계에서는 지금 모양을 조금 더 붙잡는다', () {
      // z가 y보다 살짝 크지만(5% 이내) 지금이 세움이면 그대로.
      expect(poseFor(0, 6.8, 7.1, current: TiltPose.upright), TiltPose.upright);
      // 확실히 크면 바꾼다.
      expect(poseFor(0, 5, 8, current: TiltPose.upright), TiltPose.flat);
    });
  });

  group('각도기', () {
    test('세로로 세우면 돌림 0°, 옆으로 세우면 ±90°', () {
      expect(screenRotation(0, g), closeTo(0, 1e-9));
      expect(screenRotation(g, 0), closeTo(90, 1e-9));
      expect(screenRotation(-g, 0), closeTo(-90, 1e-9));
    });

    test('두 다리 사이 굽힌 각 = 돌림 차이(-180~180)', () {
      final a = screenRotation(0, g); // 0°
      final b = screenRotation(g * sinD(45), g * cosD(45)); // 45°
      expect(angleDiff(b, a), closeTo(45, 1e-9));
      expect(angleDiff(170, -170), closeTo(-20, 1e-9));
      expect(angleDiff(-170, 170), closeTo(20, 1e-9));
    });

    test('눕혀 두면 화면 돌림을 믿을 수 없다', () {
      expect(tooFlatForRotation(0, 0.5, g), isTrue);
      expect(tooFlatForRotation(0, g, 0.5), isFalse);
    });
  });

  group('단위', () {
    test('45° = 100% = 1000mm/m', () {
      expect(slopeIn(45, SlopeUnit.percent), closeTo(100, 1e-9));
      expect(slopeIn(45, SlopeUnit.mmPerM), closeTo(1000, 1e-9));
      expect(slopeIn(45, SlopeUnit.degree), 45);
    });

    test('배관 구배 1% ≈ 0.57°, 10mm/m', () {
      final deg = math.atan(0.01) * 180 / math.pi;
      expect(formatSlope(deg, SlopeUnit.percent), '1.00%');
      expect(formatSlope(deg, SlopeUnit.mmPerM), '10.0mm/m');
      expect(formatSlope(deg, SlopeUnit.degree), '0.6°');
    });

    test('기울어진 쪽과 상관없이 크기만 보인다', () {
      expect(formatSlope(-2.04, SlopeUnit.degree), '2.0°');
    });
  });

  test('수평 판정과 기포 자리', () {
    expect(isLevel(0.2), isTrue);
    expect(isLevel(-0.31), isFalse);
    expect(bubbleOffset(5), closeTo(0.5, 1e-9));
    expect(bubbleOffset(-50), -1);
  });

  test('흔들림 누그러뜨리기: 처음 값은 그대로, 다음은 조금씩 따라감', () {
    final s = TiltSmoother(alpha: 0.5);
    expect(s.add(0, 0, 10).z, 10);
    expect(s.add(0, 0, 0).z, 5);
    s.reset();
    expect(s.add(1, 2, 3).y, 2);
  });

  group('화면 각도기 팔', () {
    test('오른쪽 0°, 위 90°, 왼쪽 180°', () {
      expect(armAngle(100, 100, 200, 100), closeTo(0, 1e-9));
      expect(armAngle(100, 100, 100, 0), closeTo(90, 1e-9));
      expect(armAngle(100, 100, 0, 100), closeTo(180, 1e-9));
    });

    test('가운데보다 아래를 누르면 가까운 끝으로', () {
      expect(armAngle(100, 100, 190, 120), 0);
      expect(armAngle(100, 100, 10, 120), 180);
    });

    test('두 팔 사이 각', () {
      expect(armsBetween(30, 120), 90);
      expect(armsBetween(150, 20), 130);
    });
  });
}
