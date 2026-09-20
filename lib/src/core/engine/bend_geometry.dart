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

/// 각도별 테이크업(전선관 수동·시카고 벤더).
///
/// 테이크업은 "꺾이는 점까지의 거리"를 "벤더 화살표를 맞출 자리"로 바꾸는 값이다.
/// 벤더 표에는 보통 90° 값 하나만 적혀 있는데, 그 값은
/// `테이크업90 = 반경 + 신발이 먹는 고정분` 이다. 각도가 달라지면 반경 쪽만
/// `반경·tan(각/2)`로 줄고 고정분은 그대로다.
///
/// 🚀 [고침] 예전에는 45°든 90°든 90° 테이크업을 그대로 빼서, 완만한 각에서
/// 첫 마킹이 크게 앞으로 밀렸다.
/// [radius]는 굽힘 중심선 반경(CLR). 모르면(0 이하) 반경 쪽만 있다고 보고
/// tan 비율로 줄인다.
double scaleTakeUp(double takeUp90, double radius, double angleDeg) {
  if (angleDeg <= 0 || takeUp90 <= 0) return 0.0;
  final t = math.tan(angleDeg * math.pi / 360.0);
  if (radius <= 0 || radius >= takeUp90) return takeUp90 * t;
  final fixed = takeUp90 - radius; // 신발이 먹는 고정분
  return radius * t + fixed;
}

/// 한 번 꺾어 재 본 값으로 실측 게인을 되짚는다.
///
/// 한 토막을 [cutLength]만큼 잘라 [angleDeg]로 한 번 꺾고, 꺾인 점(교차점)에서
/// 양쪽 끝까지를 재서 [legA]·[legB]로 넣는다.
/// 게인은 "도면 길이의 합에서 실제 자른 길이를 뺀 것"이다.
///
/// 🚀 [추가] 예전에는 게인을 표에서 베끼거나 눈대중으로 넣었다. 벤더와 관이
/// 바뀌면 값이 달라지므로, 한 번 꺾어 재 본 값으로 바로 잡을 수 있게 한다.
/// 돌려주는 값은 90° 기준으로 환산한 게인이라 그대로 제원 칸에 넣으면 된다.
double gainFromMeasured({
  required double legA,
  required double legB,
  required double cutLength,
  required double angleDeg,
}) {
  if (angleDeg <= 0 || angleDeg >= 180) return 0.0;
  final gainAtAngle = legA + legB - cutLength;
  if (gainAtAngle <= 0) return 0.0;
  if ((angleDeg - 90.0).abs() < 0.05) return gainAtAngle;

  // 각도별 게인 비율을 거꾸로 풀어 90° 값으로 되돌린다.
  final ratio = scaleMeasuredGain(1.0, angleDeg);
  if (ratio <= 1e-9) return 0.0;
  return gainAtAngle / ratio;
}

/// 한 번 꺾어 재 본 값으로 테이크업(90° 기준)을 되짚는다.
/// [markToEnd]는 벤더 화살표를 맞췄던 자리에서 관 끝까지의 길이,
/// [legOutside]는 꺾은 뒤 그 쪽 바깥면까지 잰 길이다.
double takeUpFromMeasured({
  required double legOutside,
  required double markToEnd,
  required double angleDeg,
}) {
  if (angleDeg <= 0 || angleDeg >= 180) return 0.0;
  final takeUpAtAngle = legOutside - markToEnd;
  if (takeUpAtAngle <= 0) return 0.0;
  if ((angleDeg - 90.0).abs() < 0.05) return takeUpAtAngle;
  final t = math.tan(angleDeg * math.pi / 360.0);
  if (t <= 1e-9) return 0.0;
  return takeUpAtAngle / t;
}
