// 리모컨(폰 → 태블릿·PC 계산기) 한 건을 계산기 한 줄(길이·각도)로 바꾸는 셈.
//
// 예전엔 폰 미리보기와 태블릿이 셈을 따로 했다. 새들 3점은 폰이 "각도의 절반"으로
// 이동 길이를 보여 주고 태블릿은 각도 그대로 셈해서, 폰에 보인 값과 다른 길이가
// 들어갔다(높이 100·45°: 폰 261.3, 태블릿 141.4). 또 오프셋에서 이동이 높이보다
// 짧으면 태블릿이 조용히 90°로 만들었다. 두 쪽이 이 파일 하나를 같이 쓴다.
import 'dart:math' as math;

/// 계산기에 넣을 한 줄.
class RemoteLine {
  final double length;
  final double angle;
  const RemoteLine(this.length, this.angle);
}

double _sinDeg(double deg) => math.sin(deg * math.pi / 180);

/// 새들에서 이동 길이를 셀 때 쓰는 각도. 3점(원형)은 사이드 꺾임이 가운데의 절반이라
/// 각도/2, 4점은 각도 그대로(계산기 새들 시트와 같은 공식).
double saddleEffectiveAngle(double angle, int points) =>
    points == 3 ? angle / 2 : angle;

/// 보낼 수 없는 값이면 까닭(한국어), 괜찮으면 null.
///
/// [mode]: STRAIGHT·BEND_90·OFFSET·SADDLE·ROLLING.
/// 오프셋은 [angle]이 있으면 각도로, 없으면 [val2](이동 길이)로 센다.
String? remoteInputProblem({
  required String mode,
  double val1 = 0,
  double val2 = 0,
  double angle = 0,
  int saddlePoints = 3,
}) {
  if (val1 <= 0) return "길이(높이)를 0보다 크게 넣으십시오.";
  switch (mode) {
    case 'STRAIGHT':
    case 'BEND_90':
      return null;
    case 'OFFSET':
      if (angle > 0) {
        return angle < 90 ? null : "오프셋 각도는 0°보다 크고 90°보다 작아야 합니다.";
      }
      if (val2 <= 0) return "각도나 이동 길이를 넣으십시오.";
      if (val2 < val1) return "이동 길이가 높이보다 짧습니다. 다시 확인하십시오.";
      return null;
    case 'SADDLE':
      final max = saddlePoints == 3 ? 180.0 : 90.0;
      if (angle <= 0 || angle >= max) {
        return saddlePoints == 3
            ? "3점 새들 각도는 0°보다 크고 180°보다 작아야 합니다."
            : "4점 새들 각도는 0°보다 크고 90°보다 작아야 합니다.";
      }
      return null;
    case 'ROLLING':
      if (val2 <= 0) return "롤(옆으로 간 거리)을 넣으십시오.";
      if (angle <= 0 || angle >= 90) {
        return "롤링 오프셋 각도는 0°보다 크고 90°보다 작아야 합니다.";
      }
      return null;
  }
  return "모르는 리모컨 모드입니다.";
}

/// 계산기에 넣을 한 줄. 보낼 수 없는 값이면 null.
RemoteLine? remoteLineFor({
  required String mode,
  double val1 = 0,
  double val2 = 0,
  double angle = 0,
  int saddlePoints = 3,
}) {
  if (remoteInputProblem(
        mode: mode,
        val1: val1,
        val2: val2,
        angle: angle,
        saddlePoints: saddlePoints,
      ) !=
      null) {
    return null;
  }
  switch (mode) {
    case 'STRAIGHT':
      return RemoteLine(val1, 0);
    case 'BEND_90':
      return RemoteLine(val1, 90);
    case 'OFFSET':
      if (angle > 0) return RemoteLine(val1 / _sinDeg(angle), angle);
      return RemoteLine(val2, math.asin(val1 / val2) * 180 / math.pi);
    case 'SADDLE':
      final eff = saddleEffectiveAngle(angle, saddlePoints);
      return RemoteLine(val1 / _sinDeg(eff), angle);
    case 'ROLLING':
      final trueH = math.sqrt(val1 * val1 + val2 * val2);
      return RemoteLine(trueH / _sinDeg(angle), angle);
  }
  return null;
}

/// 옛 이름(한국어 모드 이름)도 받는다(예전 폰이 보낸 명령).
String normalizeRemoteMode(String mode) => switch (mode) {
  '직관 (Straight)' => 'STRAIGHT',
  '90° 벤딩' => 'BEND_90',
  '오프셋' => 'OFFSET',
  '새들' => 'SADDLE',
  '롤링 오프셋' => 'ROLLING',
  _ => mode,
};
