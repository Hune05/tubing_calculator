/// 3D 그림이 쓸 꼭짓점 목록.
///
/// 🚀 [고침] 그림 두 벌(폰·태블릿)이 각자 공간 걷기를 들고 있었고, 꺾는
/// 방향을 반대로 돌리고 있었다(같은 축에 −각도). 그래서 "위"로 꺾으라고
/// 넣은 벤드가 그림에서는 아래로 내려갔다. 마킹 값과 같은 계산
/// (`buildBendPath`)을 쓰도록 한 곳으로 모은다.
library;

import 'package:vector_math/vector_math_64.dart' as vm;

import 'package:tubing_calculator/src/core/engine/bend_path.dart';

/// 배관 목록을 걸어 꼭짓점을 낸다(시작점 포함).
///
/// 그림은 길이를 줄여 그리므로 [visualLength]로 눈에 보일 길이를 받는다.
/// 모서리는 각지게 잇는다(반경 0) — 그림에서 마디를 세기 위해서다.
List<vm.Vector3> pipePathPoints(
  List<dynamic> bendList, {
  required String startDir,
  double Function(double)? visualLength,
  double tail = 0.0,
}) {
  double L(double v) => visualLength == null ? v : visualLength(v);

  final segs = <PathSegment>[
    for (final raw in bendList)
      if (raw is Map)
        PathSegment(
          length: L((raw['length'] as num?)?.toDouble() ?? 0.0),
          angle: (raw['angle'] as num?)?.toDouble() ?? 0.0,
          rotation: (raw['rotation'] as num?)?.toDouble() ?? 0.0,
        ),
  ];

  final path = buildBendPath(
    segs,
    radius: 0,
    startDirection: directionForName(startDir),
    tail: tail > 0 ? L(tail) : 0.0,
  );

  return [vm.Vector3.zero(), ...path.corners];
}

/// 꼭짓점 목록의 끝점.
vm.Vector3 pathEndPoint(List<vm.Vector3> pts) =>
    pts.isEmpty ? vm.Vector3.zero() : pts.last;

/// 꼭짓점 목록의 마지막 진행 방향(끝 화살표를 그릴 때 쓴다).
vm.Vector3 pathEndDirection(List<vm.Vector3> pts) {
  if (pts.length < 2) return vm.Vector3(1, 0, 0);
  final d = pts.last - pts[pts.length - 2];
  if (d.length2 < 1e-9) return vm.Vector3(1, 0, 0);
  return d.normalized();
}
