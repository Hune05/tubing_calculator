/// 전선관 특수 벤딩(킥·분할 90°·백투백 90°·스터브업)의 셈. 화면과 떼어 놓아서 검사할 수 있게 한다.
///
/// 목록에 넣는 줄은 오프셋·새들과 같은 모양이다: {length, angle, rotation}.
/// length는 앞 꺾이는 점(없으면 관 끝)에서 이 꺾이는 점(교차점)까지, rotation은 꺾은 뒤 관이 향할 절대 방향
/// (0 위 · 90 우 · 180 아래 · 270 좌 · 360 앞 · 450 뒤)이다. 마킹 자리(꺾이는 점 − 테이크업)와 게인은
/// 마킹 셈([calculateConduitMarkings])이 목록 전체에 대해 처리한다.
library;

import 'dart:math' as math;

double _rad(double deg) => deg * math.pi / 180.0;

// ───────────────────────── 킥(한 번만 꺾어 높이를 올림) ─────────────────────────

/// 킥 한 번의 기하. 높이 H를 각도 θ로 올리면 비스듬한 관 길이 = H ÷ sinθ, 그동안 앞으로 가는 거리
/// = H ÷ tanθ, 두 값의 차이가 축소값(관을 그만큼 덜 쓰게 되는 양)이다. 배수 = 1 ÷ sinθ.
class ConduitKick {
  final double travel;
  final double run;
  final double shrink;
  final double multiplier;
  const ConduitKick(this.travel, this.run, this.shrink, this.multiplier);
}

/// [angle]은 0 초과 90 미만(도). 높이나 각도가 맞지 않으면 null.
ConduitKick? conduitKick({required double height, required double angle}) {
  if (height <= 0 || angle <= 0 || angle >= 90) return null;
  final double s = math.sin(_rad(angle));
  final double t = math.tan(_rad(angle));
  final double travel = height / s;
  final double run = height / t;
  return ConduitKick(travel, run, travel - run, 1 / s);
}

// ───────────────────────── 분할 90°(작은 각을 여러 번 이어 큰 반경으로) ─────────────────────────

/// 분할 90° 한 벌. 반경 R의 원호에 바깥에서 접하는 다각형으로 90°를 [bends]번에 나눠 꺾는다.
/// 한 번 각 = 90 ÷ n, 꺾이는 점 사이 간격 = 2R·tan(각/2), 가상의 직각 모서리에서 첫 꺾이는 점까지
/// 거리(lead) = R − R·tan(각/2)(양쪽 같다).
class ConduitSegmented {
  final int bends;
  final double angle;
  final double spacing;
  final double lead;
  final double arcLength;
  const ConduitSegmented(this.bends, this.angle, this.spacing, this.lead, this.arcLength);
}

/// 나눌 횟수는 2~12, 반경은 0 초과. 안 맞으면 null.
ConduitSegmented? conduitSegmented({required double radius, required int bends}) {
  if (radius <= 0 || bends < 2 || bends > 12) return null;
  final double a = 90.0 / bends;
  final double t = math.tan(_rad(a / 2));
  return ConduitSegmented(bends, a, 2 * radius * t, radius * (1 - t), math.pi * radius / 2);
}

/// 분할 90° 목록 줄. [cornerDistance]는 관 끝(또는 앞 꺾이는 점)에서 **가상의 직각 모서리**까지 거리.
/// 첫 줄 길이 = 모서리 거리 − lead. 그 길이가 0 이하(반경이 거리에 비해 너무 큼)이면 null.
List<Map<String, dynamic>>? conduitSegmentedBends({
  required double cornerDistance,
  required double radius,
  required int bends,
  required double rotation,
}) {
  final seg = conduitSegmented(radius: radius, bends: bends);
  if (seg == null) return null;
  final double first = cornerDistance - seg.lead;
  if (first <= 0) return null;
  double r1(double v) => (v * 10).roundToDouble() / 10;
  return [
    {'length': r1(first), 'angle': seg.angle, 'rotation': rotation},
    for (var i = 1; i < bends; i++)
      {'length': r1(seg.spacing), 'angle': seg.angle, 'rotation': rotation},
  ];
}

// ───────────────────────── 백투백 90°(U자: 같은 평면에서 두 번 90°) ─────────────────────────

/// 두 다리 사이 꺾이는 점 간격. [distance]를 바깥~바깥(등과 등 사이)으로 재면 − 관 바깥지름,
/// 안쪽~안쪽으로 재면 + 관 바깥지름이다(관 한 굵기만큼 안쪽이 좁다).
double conduitBackToBackSpacing({
  required double distance,
  required double od,
  required bool outside,
}) => outside ? distance - od : distance + od;

/// 백투백 90° 목록 줄: 첫 90°는 [firstRotation] 쪽으로, 둘째 90°는 처음 진행 방향의 반대
/// ([headingRotation]의 반대)로 꺾어 U자가 된다.
List<Map<String, dynamic>>? conduitBackToBackBends({
  required double firstLength,
  required double spacing,
  required double firstRotation,
  required double secondRotation,
}) {
  if (firstLength <= 0 || spacing <= 0) return null;
  double r1(double v) => (v * 10).roundToDouble() / 10;
  return [
    {'length': r1(firstLength), 'angle': 90.0, 'rotation': firstRotation},
    {'length': r1(spacing), 'angle': 90.0, 'rotation': secondRotation},
  ];
}

// ───────────────────────── 스터브업(관 끝에서 90°) ─────────────────────────

/// 스터브업 한 줄. 길이는 관 끝에서 꺾이는 점(스터브 높이)까지다. 마킹은 길이 − 테이크업.
List<Map<String, dynamic>>? conduitStubBends({
  required double stub,
  required double rotation,
}) {
  if (stub <= 0) return null;
  return [
    {'length': (stub * 10).roundToDouble() / 10, 'angle': 90.0, 'rotation': rotation},
  ];
}
