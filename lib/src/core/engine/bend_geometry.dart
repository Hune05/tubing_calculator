/// 벤딩 기하 계산을 한 곳에 모은 곳.
///
/// 예전에는 같은 식이 엔진·오프셋 시트·새들 시트·U벤드 시트·전선관 결과 탭에
/// 따로 적혀 있었고, 그 가운데 몇 곳은 게인을 각도에 비례로 환산해서(틀린 방식)
/// 45°에서 벤드당 16mm씩 어긋났다. 여기 있는 함수만 쓰도록 모아 둔다.
///
/// 쓰는 말
/// - 셋백(setback): 교차점에서 관이 휘기 시작하는 접점까지의 거리.
/// - 호(arc): 휘는 구간에서 관 중심선이 지나는 길이.
/// - 게인(gain): 교차점 기준 치수에서 실제 관 길이를 뺀 값. 자를 때 빼 준다.
library;

import 'dart:math' as math;

/// 셋백 = R · tan(각/2)
double bendSetback(double radius, double angleDeg) {
  if (radius <= 0 || angleDeg <= 0) return 0.0;
  return radius * math.tan(angleDeg * math.pi / 360.0);
}

/// 호 길이 = π · R · 각 / 180
double bendArcLength(double radius, double angleDeg) {
  if (radius <= 0 || angleDeg <= 0) return 0.0;
  return math.pi * radius * angleDeg / 180.0;
}

/// 반경만 알 때의 게인 = 2·셋백 − 호
double geometricGain(double radius, double angleDeg) {
  if (radius <= 0 || angleDeg <= 0) return 0.0;
  return 2 * bendSetback(radius, angleDeg) - bendArcLength(radius, angleDeg);
}

/// 90°에서 실측한 게인을 다른 각도로 환산한다.
///
/// 게인은 각도에 비례하지 않는다. 반경이 얼마든 게인의 각도별 모양은 같으므로
/// (게인 = R·(2tan(각/2) − 각rad)), 90°의 값으로 나눠 비율만 가져다 쓴다.
/// 이 식은 전선관 계산기가 쓰던 것과 같다.
double scaleMeasuredGain(double gainAt90, double angleDeg) {
  if (gainAt90 <= 0 || angleDeg <= 0) return 0.0;
  if ((angleDeg - 90.0).abs() < 0.001) return gainAt90;
  final rad = angleDeg * math.pi / 180.0;
  final numerator = 2 * math.tan(rad / 2) - rad;
  const denominator = 2 - math.pi / 2; // 90°일 때의 값 (약 0.4292)
  return gainAt90 * (numerator / denominator);
}

/// 이 벤드에서 쓸 게인. 실측값이 있으면 그것을 각도에 맞춰 환산하고,
/// 없으면 반경으로 계산한다.
double effectiveGain({
  required double radius,
  required double angleDeg,
  double measuredGain90 = 0.0,
}) {
  if (measuredGain90 > 0) return scaleMeasuredGain(measuredGain90, angleDeg);
  return geometricGain(radius, angleDeg);
}

/// 관이 실제로 휘는 데 쓰는 길이 = 2·셋백 − 게인.
/// (반경만 쓸 때는 호 길이와 같아진다.)
double realBendAllowance({
  required double radius,
  required double angleDeg,
  double measuredGain90 = 0.0,
}) {
  final sb = bendSetback(radius, angleDeg);
  final gain = effectiveGain(
    radius: radius,
    angleDeg: angleDeg,
    measuredGain90: measuredGain90,
  );
  return (2 * sb) - gain;
}
