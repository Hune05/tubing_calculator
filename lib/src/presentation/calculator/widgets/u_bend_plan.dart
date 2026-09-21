/// 퀵 U-Bend(180°)를 입력 목록에 넣을 때 쓰는 셈.
///
/// 계산 엔진은 180° 한 번짜리를 셈하지 못하므로(진입·진출 방향이 나란해 교차점이
/// 없다), U자를 "90° 두 번"으로 넣는다. 두 벤드 사이 교차점 거리는 2R이고
/// 곧은 부분은 0이다. 벤더로 한 번에 180°를 꺾을 때는 1번 마킹만 쓰면 된다.
library;

import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';
import 'package:tubing_calculator/src/core/engine/bend_path.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/opposite_rotation.dart';

/// 방향 이름(시작 방향 설정) → 방향값. 0 위 · 90 우 · 180 아래 · 270 좌 · 360 앞 · 450 뒤.
double rotationForName(String name) {
  switch (name) {
    case 'UP':
      return 0.0;
    case 'DOWN':
      return 180.0;
    case 'LEFT':
      return 270.0;
    case 'FRONT':
      return 360.0;
    case 'BACK':
      return 450.0;
    case 'RIGHT':
    default:
      return 90.0;
  }
}

const List<double> _axisRotations = [0.0, 90.0, 180.0, 270.0, 360.0, 450.0];

/// 지금 목록 끝에서 관이 가는 방향의 방향값. 여섯 축 중 하나와 나란할 때만
/// 돌려주고, 비스듬히 가고 있으면(예: 45° 한 번 꺾은 뒤) null.
double? travelRotation(
  List<Map<String, dynamic>> bendList, {
  required String startDir,
  required double radius,
}) {
  final path = buildBendPath(
    [
      for (final b in bendList)
        PathSegment(
          length: (b['length'] as num?)?.toDouble() ?? 0.0,
          angle: (b['angle'] as num?)?.toDouble() ?? 0.0,
          rotation: (b['rotation'] as num?)?.toDouble() ?? 0.0,
        ),
    ],
    radius: radius,
    startDirection: directionForName(startDir),
  );
  final dir = path.endDirection.normalized();
  for (final r in _axisRotations) {
    if (dir.dot(directionForRotation(r)) > 0.9999) return r;
  }
  return null;
}

/// U자 한 개가 관을 먹는 길이(90° 두 번). 실측 게인이 있으면 그것으로 셈한다
/// (마킹 탭 엔진과 같은 셈).
double uBendAllowance({required double radius, double measuredGain90 = 0.0}) =>
    2 *
    realBendAllowance(
      radius: radius,
      angleDeg: 90,
      measuredGain90: measuredGain90,
    );

/// 입력 목록에 넣을 줄들.
///
/// - [startStraight] U자 앞 곧은 길이(앞 벤드가 끝난 곳, 또는 관 끝에서부터)
/// - [returnStraight] U자 뒤 곧은 길이. 0이면 넣지 않는다.
/// - [turn] U자가 튀어나가는 방향(진행 방향과 직각이어야 한다)
/// - [travel] 지금 관이 가는 방향. 두 번째 벤드는 그 반대로 돌아온다.
/// - [prevSetback] 목록 끝이 벤드이면 그 벤드의 셋백(교차점 기준 길이로 바꾸려고).
List<Map<String, double>> uBendSegments({
  required double startStraight,
  required double returnStraight,
  required double radius,
  required double turn,
  required double travel,
  double prevSetback = 0.0,
}) {
  final double back = oppositeRotation(travel);
  return [
    {
      'length': prevSetback + startStraight + radius,
      'angle': 90,
      'rotation': turn,
    },
    {'length': 2 * radius, 'angle': 90, 'rotation': back},
    if (returnStraight > 0)
      {'length': returnStraight + radius, 'angle': 0, 'rotation': back},
  ];
}

/// 목록 끝이 벤드이면 그 셋백, 아니면 0.
double lastSetback(List<Map<String, dynamic>> bendList, double radius) {
  if (bendList.isEmpty) return 0.0;
  final double a = (bendList.last['angle'] as num?)?.toDouble() ?? 0.0;
  return a > 0 ? bendSetback(radius, a) : 0.0;
}
