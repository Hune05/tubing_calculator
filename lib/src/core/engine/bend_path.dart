/// 관이 공간에서 어떻게 지나가는지 계산하는 곳.
///
/// 예전에는 이 계산이 화면 세 곳(폰·태블릿 튜브, 전선관 3D)에 따로 복사돼
/// 있었고, 모서리를 각지게 이어 붙이기만 해서 실제 형상과 달랐다. 여기 한 곳에
/// 모으고 모서리는 반경만큼 둥글게 잡는다.
///
/// 방향값은 앱이 쓰던 그대로다: 0 위, 90 우, 180 아래, 270 좌, 360 앞, 450 뒤.
/// 이 값은 "꺾은 뒤 관이 향할 절대 방향"이며, 90°가 아닌 각도에서는 그 방향으로
/// 꺾는 평면만 정하고 각도만큼만 돌아간다.
library;

import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' as vm;

import 'bend_geometry.dart';

/// 한 구간(직선 + 그 끝의 벤드).
class PathSegment {
  final double length; // 교차점에서 교차점까지
  final double angle; // 0이면 꺾지 않는다
  final double rotation; // 방향값

  const PathSegment({
    required this.length,
    required this.angle,
    required this.rotation,
  });
}

/// 방향값 → 방향 벡터.
vm.Vector3 directionForRotation(double rot) {
  if (rot == 0.0) return vm.Vector3(0, 1, 0);
  if (rot == 90.0) return vm.Vector3(1, 0, 0);
  if (rot == 180.0) return vm.Vector3(0, -1, 0);
  if (rot == 270.0) return vm.Vector3(-1, 0, 0);
  if (rot == 360.0) return vm.Vector3(0, 0, 1);
  if (rot == 450.0) return vm.Vector3(0, 0, -1);
  return vm.Vector3(1, 0, 0);
}

/// 이름(UP/DOWN/…) → 방향 벡터.
vm.Vector3 directionForName(String name) {
  switch (name) {
    case 'UP':
      return vm.Vector3(0, 1, 0);
    case 'DOWN':
      return vm.Vector3(0, -1, 0);
    case 'LEFT':
      return vm.Vector3(-1, 0, 0);
    case 'FRONT':
      return vm.Vector3(0, 0, 1);
    case 'BACK':
      return vm.Vector3(0, 0, -1);
    case 'RIGHT':
    default:
      return vm.Vector3(1, 0, 0);
  }
}

/// 표에 있는 방향값인지(표에 없으면 모두 '우'로 떨어져 엉뚱한 형상이 된다).
bool isKnownRotation(double rot) =>
    rot == 0.0 ||
    rot == 90.0 ||
    rot == 180.0 ||
    rot == 270.0 ||
    rot == 360.0 ||
    rot == 450.0;

/// 지금 진행 방향에서 그 방향으로 꺾을 수 있는지.
/// 나란하거나(같은 방향) 정반대면 꺾을 평면이 정해지지 않는다.
bool canBendToward(vm.Vector3 current, vm.Vector3 target) {
  final c = current.normalized();
  final t = target.normalized();
  return c.cross(t).length > 1e-6;
}

/// 한 벤드 결과.
class PathBend {
  final int index; // 몇 번째 구간인지(0부터)
  final vm.Vector3 corner; // 교차점
  final vm.Vector3 tangentIn; // 휘기 시작하는 접점
  final vm.Vector3 tangentOut; // 휘기가 끝나는 접점
  final vm.Vector3 dirBefore;
  final vm.Vector3 dirAfter;
  final double angle;
  final double setback;
  final double straightBefore; // 앞 벤드와 이 벤드 사이 실제 곧은 길이
  final double rollDeg; // 앞 벤드 기준으로 관을 굴릴 각도(첫 벤드는 0)

  const PathBend({
    required this.index,
    required this.corner,
    required this.tangentIn,
    required this.tangentOut,
    required this.dirBefore,
    required this.dirAfter,
    required this.angle,
    required this.setback,
    required this.straightBefore,
    required this.rollDeg,
  });
}

/// 곧은 토막 하나(벤드와 벤드 사이의 실제 직선 부분).
class PathLine {
  final vm.Vector3 a;
  final vm.Vector3 b;

  const PathLine(this.a, this.b);

  double get length => (b - a).length;
}

class BendPath {
  final List<vm.Vector3> corners; // 교차점(시작점 포함하지 않음)
  final List<PathBend> bends;

  /// 곧은 토막들(접점에서 접점까지). 그림과 간섭 검사가 쓴다.
  final List<PathLine> straights;
  final vm.Vector3 endPoint;
  final vm.Vector3 endDirection;
  final double developedLength; // 실제 필요한 관 길이
  final List<String> warnings;

  const BendPath({
    required this.corners,
    required this.bends,
    this.straights = const [],
    required this.endPoint,
    required this.endDirection,
    required this.developedLength,
    required this.warnings,
  });
}

/// 두 토막 사이의 가장 가까운 거리. 둘 다 선분으로 본다.
double segmentDistance(
  vm.Vector3 p1,
  vm.Vector3 q1,
  vm.Vector3 p2,
  vm.Vector3 q2,
) {
  final d1 = q1 - p1;
  final d2 = q2 - p2;
  final r = p1 - p2;
  final a = d1.dot(d1);
  final e = d2.dot(d2);
  final f = d2.dot(r);

  double s;
  double t;
  const eps = 1e-9;
  if (a <= eps && e <= eps) return r.length;
  if (a <= eps) {
    s = 0.0;
    t = (f / e).clamp(0.0, 1.0);
  } else {
    final c = d1.dot(r);
    if (e <= eps) {
      t = 0.0;
      s = (-c / a).clamp(0.0, 1.0);
    } else {
      final b = d1.dot(d2);
      final denom = a * e - b * b;
      s = denom > eps ? ((b * f - c * e) / denom).clamp(0.0, 1.0) : 0.0;
      t = (b * s + f) / e;
      if (t < 0.0) {
        t = 0.0;
        s = (-c / a).clamp(0.0, 1.0);
      } else if (t > 1.0) {
        t = 1.0;
        s = ((b - c) / a).clamp(0.0, 1.0);
      }
    }
  }
  return ((p1 + d1 * s) - (p2 + d2 * t)).length;
}

/// 관이 저희끼리 부딪히는지 본다.
/// 바깥지름 [outerDiameter]만큼 떨어져 있어야 하고, 붙어 있는 두 토막은
/// 벤드로 이어지므로 보지 않는다.
/// 🚀 [고침] 예전에는 화면에 형상만 그려 줄 뿐, 관이 자기 자신을 뚫고
/// 지나가도 아무 말이 없었다. 만들 수 없는 형상을 현장에 가서야 알았다.
List<String> selfInterferenceWarnings(
  BendPath path, {
  required double outerDiameter,
}) {
  final out = <String>[];
  if (outerDiameter <= 0) return out;
  final lines = path.straights;
  for (var i = 0; i < lines.length; i++) {
    for (var j = i + 2; j < lines.length; j++) {
      final d = segmentDistance(lines[i].a, lines[i].b, lines[j].a, lines[j].b);
      if (d < outerDiameter) {
        out.add(
          '${i + 1}번 구간과 ${j + 1}번 구간이 '
          '${d.toStringAsFixed(0)}mm까지 붙습니다(관 굵기 '
          '${outerDiameter.toStringAsFixed(0)}mm). 이대로는 서로 닿습니다.',
        );
      }
    }
  }
  return out;
}

/// 구간 목록을 공간에서 걸어 본다.
BendPath buildBendPath(
  List<PathSegment> segments, {
  required double radius,
  vm.Vector3? startDirection,
  double tail = 0.0,
}) {
  final warnings = <String>[];
  var pos = vm.Vector3.zero();
  var dir = (startDirection ?? vm.Vector3(1, 0, 0)).normalized();

  final corners = <vm.Vector3>[];
  final bends = <PathBend>[];
  final straights = <PathLine>[];
  var straightFrom = pos.clone();
  var developed = 0.0;
  var prevSb = 0.0;
  vm.Vector3? prevBendAxis;

  for (var i = 0; i < segments.length; i++) {
    final s = segments[i];
    final corner = pos + dir * s.length;
    corners.add(corner.clone());

    if (s.angle == 0) {
      developed += s.length - prevSb;
      pos = corner;
      prevSb = 0.0;
      continue;
    }

    if (!isKnownRotation(s.rotation)) {
      warnings.add(
        '${i + 1}번 구간: 방향값 ${s.rotation.toStringAsFixed(0)}은 쓸 수 없는 값입니다.',
      );
    }

    final target = directionForRotation(s.rotation);
    final cross = dir.cross(target);
    final mySb = bendSetback(radius, s.angle);
    final straight = s.length - prevSb - mySb;
    if (straight < 0) {
      warnings.add(
        '${i + 1}번 구간: 앞뒤 벤드를 빼면 곧은 부분이 '
        '${straight.toStringAsFixed(1)}mm입니다. 이대로는 만들 수 없습니다.',
      );
    }

    final tangentIn = corner - dir * mySb;

    if (cross.length <= 1e-6) {
      warnings.add('${i + 1}번 구간: 고른 방향이 지금 진행 방향과 나란해서 꺾을 수 없습니다.');
      developed += straight;
      pos = corner;
      prevSb = mySb;
      continue;
    }

    straights.add(PathLine(straightFrom.clone(), tangentIn.clone()));

    final axis = cross.normalized();
    final rad = s.angle * math.pi / 180.0;
    final dirBefore = dir.clone();
    dir = (dir * math.cos(rad) + axis.cross(dir) * math.sin(rad)).normalized();

    // 앞 벤드 평면과 이번 평면 사이의 각도 = 현장에서 관을 굴릴 각도.
    // 🚀 [고침] 축끼리의 각도를 그대로 썼더니, 오프셋처럼 같은 평면에서
    // 반대로 꺾는 경우에 180°로 나왔다(굴릴 필요가 없는데 굴리라고 나왔다).
    // 평면과 평면 사이의 각도는 언제나 90°를 넘지 않으므로 절댓값을 쓴다.
    var roll = 0.0;
    if (prevBendAxis != null) {
      final dot = prevBendAxis.dot(axis).abs().clamp(-1.0, 1.0);
      roll = math.acos(dot) * 180.0 / math.pi;
    }

    developed += straight;
    developed += bendArcLength(radius, s.angle);

    bends.add(
      PathBend(
        index: i,
        corner: corner.clone(),
        tangentIn: tangentIn,
        tangentOut: corner + dir * mySb,
        dirBefore: dirBefore,
        dirAfter: dir.clone(),
        angle: s.angle,
        setback: mySb,
        straightBefore: straight,
        rollDeg: roll,
      ),
    );

    prevBendAxis = axis;
    pos = corner;
    prevSb = mySb;
    straightFrom = corner + dir * mySb;
  }

  if (pos != straightFrom) {
    straights.add(PathLine(straightFrom.clone(), pos.clone()));
    straightFrom = pos.clone();
  }

  if (tail > 0) {
    final tailStraight = tail - prevSb;
    if (tailStraight < 0) {
      warnings.add(
        '꼬리 구간: 마지막 벤드를 빼면 곧은 부분이 '
        '${tailStraight.toStringAsFixed(1)}mm입니다.',
      );
    }
    developed += tailStraight;
    pos = pos + dir * tail;
    corners.add(pos.clone());
    if (straights.isNotEmpty) {
      straights[straights.length - 1] = PathLine(straights.last.a, pos.clone());
    } else {
      straights.add(PathLine(straightFrom.clone(), pos.clone()));
    }
  }

  return BendPath(
    corners: corners,
    bends: bends,
    straights: straights,
    endPoint: pos,
    endDirection: dir,
    developedLength: developed,
    warnings: warnings,
  );
}

/// 지금까지 넣은 구간을 다 걷고 난 뒤의 진행 방향.
/// 다음 벤드를 어느 방향으로 꺾을 수 있는지 판단할 때 쓴다.
vm.Vector3 directionAfter(
  List<PathSegment> segments, {
  required double radius,
  vm.Vector3? startDirection,
}) {
  if (segments.isEmpty) {
    return (startDirection ?? vm.Vector3(1, 0, 0)).normalized();
  }
  return buildBendPath(
    segments,
    radius: radius,
    startDirection: startDirection,
  ).endDirection;
}
