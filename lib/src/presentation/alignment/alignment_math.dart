// 축 정렬(센터링) 계산: 펌프처럼 고정하는 기계(고정 쪽)와 모터처럼 발에 심을 넣어 움직이는 기계(이동 쪽)의
// 두 축이 얼마나 어긋났는지를 다이얼 게이지 읽음값으로 구하고, 이동 쪽 앞발·뒷발에 넣고 뺄 심 두께와 좌우 이동량을 계산한다.
//
// ── 약속(화면에도 같은 글이 나온다) ──
// * 좌표: 커플링 중심을 0으로, 고정 쪽(펌프)은 음수, 이동 쪽(모터)은 양수 방향. 길이는 모두 mm.
// * 위·아래는 12시(+y)·6시(−y), 옆은 "고정 쪽에서 이동 쪽을 바라볼 때" 오른쪽이 3시(+z), 왼쪽이 9시(−z).
// * 다이얼은 12시에서 0으로 맞추고 3시→6시→9시 순서로 읽는다. 다이얼 읽음은 누르는 쪽이 +(닿는 면이 다이얼 쪽으로 다가오면 +).
// * 결과의 + 는: 심은 "넣는다"(발을 올린다), 좌우는 "+z(오른쪽)로 민다".
//
// ── 원리(작은 각도) ──
// 두 축을 같이 돌리며 읽으면, 다이얼 위치 φ에서 읽음은 (두 축 중심이 어긋난 벡터 c)와 방향 u(φ)로
// r(φ) − r(0) = c·(u(φ) − u(0)). 그래서 12시를 0으로 하면
//   r(180) = −2·c_y,  r(90) = c_z − c_y,  r(270) = −c_z − c_y
//   → c_y = −r(180)/2,  c_z = (r(90) − r(270))/2,  검산: r(90) + r(270) = r(180)
// 면(페이스) 읽음도 같은 모양이고 c 대신 (반지름 × 축 기울기)가 들어간다.
library;

import 'dart:math' as math;

/// 어느 방식으로 읽었는지.
enum AlignMethod { reverse, rimFace }

/// 한 방향(위아래 또는 옆)의 결과. 축 높이(또는 옆 위치)를 x의 직선 v(x) = v0 + slope·x 로 나타낸다(고정 쪽 축이 0).
class AxisLine {
  final double v0; // 커플링 중심(x=0)에서 이동 쪽 축의 어긋남(mm)
  final double slope; // 축 기울기(mm/mm)
  const AxisLine(this.v0, this.slope);

  double at(double x) => v0 + slope * x;
}

/// 계산 결과.
class AlignResult {
  final AxisLine vertical; // 위아래(+ = 이동 쪽 축이 위)
  final AxisLine horizontal; // 옆(+ = 이동 쪽 축이 오른쪽)

  /// 앞발(커플링 쪽)·뒷발에 넣을 심(mm). + 넣기, − 빼기. 목표 위치로 가기 위한 값.
  final double shimFront;
  final double shimRear;

  /// 앞발·뒷발을 옆으로 밀 양(mm). + 오른쪽, − 왼쪽.
  final double moveFront;
  final double moveRear;

  /// 커플링 중심에서 본 평행 어긋남(mm)과 각도 어긋남(mm/100mm). 위아래·옆을 합친 크기.
  final double offset;
  final double angle100;

  /// 검산: 옆 읽음 둘의 합과 아래 읽음의 차(mm). 클수록 읽음이 의심스럽다.
  final double closure;
  const AlignResult({
    required this.vertical,
    required this.horizontal,
    required this.shimFront,
    required this.shimRear,
    required this.moveFront,
    required this.moveRear,
    required this.offset,
    required this.angle100,
    required this.closure,
  });
}

/// 잘못된 입력(거리가 0 이하 등).
class AlignInputError implements Exception {
  final String message;
  const AlignInputError(this.message);
  @override
  String toString() => message;
}

double _hyp(double a, double b) => math.sqrt(a * a + b * b);

/// 12시 0 기준 읽음값(3시·6시·9시)과 처짐을 넣으면 어긋남 벡터의 성분을 돌려준다.
/// [sag]는 같은 다이얼 세팅을 어긋남 없는 곧은 관에 걸고 잰 6시 읽음(보통 음수). 6시에서 sag, 옆에서 sag/2 만큼 뺀다.
({double cy, double cz, double closure}) _components(
  double r90,
  double r180,
  double r270,
  double sag,
) {
  final a90 = r90 - sag / 2;
  final a180 = r180 - sag;
  final a270 = r270 - sag / 2;
  return (
    cy: -a180 / 2,
    cz: (a90 - a270) / 2,
    closure: (a90 + a270 - a180).abs(),
  );
}

/// 앞발·뒷발 값을 만든다: 직선이 목표 직선(커플링 중심에서 [target], 기울기 0)과 같아지도록.
AlignResult _finish({
  required AxisLine vert,
  required AxisLine horiz,
  required double xFront,
  required double xRear,
  required double targetY,
  required double targetZ,
  required double closure,
}) {
  return AlignResult(
    vertical: vert,
    horizontal: horiz,
    shimFront: targetY - vert.at(xFront),
    shimRear: targetY - vert.at(xRear),
    moveFront: targetZ - horiz.at(xFront),
    moveRear: targetZ - horiz.at(xRear),
    offset: _hyp(vert.v0, horiz.v0),
    angle100: _hyp(vert.slope, horiz.slope) * 100,
    closure: closure,
  );
}

/// 리버스 다이얼: 고정 쪽 축에 건 다이얼 A가 이동 쪽 림을, 이동 쪽 축에 건 다이얼 B가 고정 쪽 림을 읽는다.
///
/// [dial] 거리(mm):
/// * [betweenPlanes] 두 다이얼이 림에 닿는 면 사이 거리(B면 → A면)
/// * [couplingFromB] B면에서 커플링 중심까지 거리
/// * [frontFoot]·[rearFoot] A면에서 이동 쪽 앞발·뒷발까지 거리(뒷발이 더 멀다)
/// [targetY]·[targetZ]는 커플링 중심에서 원하는 어긋남(더운 상태의 열팽창 등을 미리 준다. 기본 0).
AlignResult solveReverse({
  required double a90,
  required double a180,
  required double a270,
  required double b90,
  required double b180,
  required double b270,
  double sagA = 0,
  double sagB = 0,
  required double betweenPlanes,
  required double couplingFromB,
  required double frontFoot,
  required double rearFoot,
  double targetY = 0,
  double targetZ = 0,
}) {
  if (betweenPlanes <= 0) throw const AlignInputError('두 다이얼 사이 거리를 0보다 크게 넣어 주십시오');
  if (frontFoot <= 0 || rearFoot <= 0) throw const AlignInputError('앞발·뒷발까지 거리를 0보다 크게 넣어 주십시오');
  if (rearFoot <= frontFoot) throw const AlignInputError('뒷발이 앞발보다 더 멀어야 합니다');

  final a = _components(a90, a180, a270, sagA);
  final b = _components(b90, b180, b270, sagB);

  // A는 고정 쪽 축에서 본 이동 쪽 림의 어긋남을 준다(그대로).
  // B는 이동 쪽 축에서 본 고정 쪽 림의 어긋남이라, 이동 쪽 기준으로는 부호가 반대다.
  final xB = -couplingFromB;
  final xA = xB + betweenPlanes;
  final cAy = a.cy, cAz = a.cz;
  final cBy = -b.cy, cBz = -b.cz;

  double slope(double cA, double cB) => (cA - cB) / betweenPlanes;
  final sy = slope(cAy, cBy), sz = slope(cAz, cBz);
  final vert = AxisLine(cBy - sy * xB, sy);
  final horiz = AxisLine(cBz - sz * xB, sz);
  return _finish(
    vert: vert,
    horiz: horiz,
    xFront: xA + frontFoot,
    xRear: xA + rearFoot,
    targetY: targetY,
    targetZ: targetZ,
    closure: math.max(a.closure, b.closure),
  );
}

/// 림·페이스: 고정 쪽 축에 건 다이얼이 이동 쪽 커플링의 바깥둘레(림)와 옆면(페이스)을 읽는다.
///
/// * [faceRadius] 페이스 다이얼이 닿는 곳의 반지름
/// * [couplingFromRim] 림 측정면에서 커플링 중심까지 거리
/// * [frontFoot]·[rearFoot] 림 측정면에서 이동 쪽 앞발·뒷발까지 거리(뒷발이 더 멀다)
AlignResult solveRimFace({
  required double r90,
  required double r180,
  required double r270,
  required double f90,
  required double f180,
  required double f270,
  double sagRim = 0,
  required double faceRadius,
  required double couplingFromRim,
  required double frontFoot,
  required double rearFoot,
  double targetY = 0,
  double targetZ = 0,
}) {
  if (faceRadius <= 0) throw const AlignInputError('페이스 다이얼이 닿는 반지름을 0보다 크게 넣어 주십시오');
  if (couplingFromRim < 0) throw const AlignInputError('림 측정면에서 커플링 중심까지 거리를 0 이상으로 넣어 주십시오');
  if (frontFoot <= 0 || rearFoot <= 0) throw const AlignInputError('앞발·뒷발까지 거리를 0보다 크게 넣어 주십시오');
  if (rearFoot <= frontFoot) throw const AlignInputError('뒷발이 앞발보다 더 멀어야 합니다');

  final rim = _components(r90, r180, r270, sagRim);
  // 페이스는 곧은 옆면이라 처짐이 읽음에 거의 없다(축 방향 읽음). 그대로 쓴다.
  final face = _components(f90, f180, f270, 0);

  // 림 측정면의 위치(커플링 중심이 0, 이동 쪽이 +).
  final xRim = couplingFromRim;
  final tiltY = face.cy / faceRadius; // 축 기울기 = (읽음 성분) / 반지름
  final tiltZ = face.cz / faceRadius;
  final vert = AxisLine(rim.cy - tiltY * xRim, tiltY);
  final horiz = AxisLine(rim.cz - tiltZ * xRim, tiltZ);
  return _finish(
    vert: vert,
    horiz: horiz,
    xFront: xRim + frontFoot,
    xRear: xRim + rearFoot,
    targetY: targetY,
    targetZ: targetZ,
    closure: math.max(rim.closure, face.closure),
  );
}

// ── 허용 오차 판정 ──

/// 회전수별 참고 허용값. 제조사·사내 기준이 우선이라 화면에서 직접 고칠 수 있다.
/// (일반 현장에서 쓰는 경험값을 단순하게 옮긴 것이며 어느 규격의 표가 아니다.)
class AlignTolerance {
  final double offset; // 평행 어긋남(mm)
  final double angle100; // 각도 어긋남(mm/100mm)
  const AlignTolerance(this.offset, this.angle100);
}

AlignTolerance defaultTolerance(int rpm) {
  if (rpm >= 3000) return const AlignTolerance(0.05, 0.05);
  if (rpm >= 1500) return const AlignTolerance(0.08, 0.08);
  if (rpm >= 1000) return const AlignTolerance(0.10, 0.10);
  return const AlignTolerance(0.15, 0.15);
}

enum AlignVerdict { ok, offsetOut, angleOut, bothOut }

AlignVerdict judge(AlignResult r, AlignTolerance t) {
  final o = r.offset > t.offset;
  final a = r.angle100 > t.angle100;
  if (o && a) return AlignVerdict.bothOut;
  if (o) return AlignVerdict.offsetOut;
  if (a) return AlignVerdict.angleOut;
  return AlignVerdict.ok;
}

/// 발 이동량 글: "넣기 0.35 mm" / "빼기 0.20 mm" / "그대로".
String shimText(double mm, {double eps = 0.005}) {
  if (mm.abs() < eps) return '그대로';
  return '${mm > 0 ? '넣기' : '빼기'} ${mm.abs().toStringAsFixed(2)} mm';
}

/// 옆으로 밀기 글: "오른쪽 0.20 mm" / "왼쪽 0.10 mm" / "그대로".
String moveText(double mm, {double eps = 0.005}) {
  if (mm.abs() < eps) return '그대로';
  return '${mm > 0 ? '오른쪽' : '왼쪽'} ${mm.abs().toStringAsFixed(2)} mm';
}
