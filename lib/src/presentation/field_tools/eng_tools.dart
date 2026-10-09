// 공학용 계산기 "현장 도구"의 셈(10-09): 직각삼각형 풀이와 볼트 구멍 원(PCD) 좌표.
// 화면 없이 계산만 한다(eng_tools_page.dart가 그린다).
library;

import 'dart:math' as math;

/// 직각삼각형 풀이 결과. 높이 [rise]·밑변 [run]·빗변 [hyp](mm), 밑변과 빗변 사이 각 [angle](°).
class RightTriangle {
  final double rise, run, hyp, angle;
  const RightTriangle(this.rise, this.run, this.hyp, this.angle);

  /// 높이와 빗변 사이 각(°).
  double get otherAngle => 90 - angle;

  /// 구배(%) = 높이 ÷ 밑변 × 100.
  double get slopePercent => rise / run * 100;
}

/// 풀이가 안 될 때의 까닭.
class TriangleError implements Exception {
  final String message;
  const TriangleError(this.message);
  @override
  String toString() => message;
}

double _rad(double d) => d * math.pi / 180;
double _deg(double r) => r * 180 / math.pi;

/// 넷 중 두 값으로 나머지를 푼다. 넣지 않은 값은 null. 꼭 두 값이어야 한다.
RightTriangle solveRightTriangle({
  double? rise,
  double? run,
  double? hyp,
  double? angle,
}) {
  final given = [rise, run, hyp, angle].where((v) => v != null).length;
  if (given < 2) throw const TriangleError('두 칸을 넣으십시오.');
  if (given > 2) throw const TriangleError('두 칸만 넣으십시오. 나머지는 비워 두면 계산합니다.');
  for (final v in [rise, run, hyp]) {
    if (v != null && v <= 0) throw const TriangleError('길이는 0보다 커야 합니다.');
  }
  if (angle != null && (angle <= 0 || angle >= 90)) {
    throw const TriangleError('각도는 0°보다 크고 90°보다 작아야 합니다.');
  }
  if (rise != null && run != null) {
    return RightTriangle(rise, run, math.sqrt(rise * rise + run * run), _deg(math.atan2(rise, run)));
  }
  if (hyp != null && (rise != null || run != null)) {
    final leg = (rise ?? run)!;
    if (leg >= hyp) throw const TriangleError('빗변이 가장 길어야 합니다.');
    final other = math.sqrt(hyp * hyp - leg * leg);
    return rise != null
        ? RightTriangle(rise, other, hyp, _deg(math.asin(rise / hyp)))
        : RightTriangle(other, run!, hyp, _deg(math.acos(run / hyp)));
  }
  final t = _rad(angle!);
  if (rise != null) return RightTriangle(rise, rise / math.tan(t), rise / math.sin(t), angle);
  if (run != null) return RightTriangle(run * math.tan(t), run, run / math.cos(t), angle);
  return RightTriangle(hyp! * math.sin(t), hyp * math.cos(t), hyp, angle);
}

/// 볼트 구멍 하나: 번호(1부터), 12시에서 시계 방향 각(°), 원 중심에서 X(오른쪽 +)·Y(위 +)(mm).
class BoltHole {
  final int no;
  final double angle, x, y;
  const BoltHole(this.no, this.angle, this.x, this.y);
}

/// 볼트 구멍 원. [pcd] 지름(mm), [count] 구멍 수, [start] 1번 구멍 각(12시에서 시계 방향, °).
/// 구멍은 1번부터 시계 방향으로 고르게 놓는다.
List<BoltHole> boltCircle(double pcd, int count, {double start = 0}) {
  final r = pcd / 2;
  return [
    for (var i = 0; i < count; i++)
      () {
        final a = (start + 360 / count * i) % 360;
        final t = _rad(a);
        // 아주 작은 값(−0.0000001)이 "−0"으로 보이지 않게 0으로 맞춘다.
        double z(double v) => v.abs() < 1e-9 ? 0 : v;
        return BoltHole(i + 1, a, z(r * math.sin(t)), z(r * math.cos(t)));
      }(),
  ];
}

/// 이웃 구멍 중심 사이 거리(현 길이, mm) = PCD × sin(180° ÷ 구멍 수).
double boltPitch(double pcd, int count) => pcd * math.sin(math.pi / count);

/// 12시 양쪽에 걸치게 놓을 때의 1번 구멍 각(°) = 180 ÷ 구멍 수.
double straddleStart(int count) => 180 / count;
