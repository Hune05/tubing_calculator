/// 3D 그림이 쓸 꼭짓점 목록.
///
/// 🚀 [고침] 그림 두 벌(폰·태블릿)이 각자 공간 걷기를 들고 있었다.
/// 마킹 값과 같은 계산(`buildBendPath`)을 쓰도록 한 곳으로 모은다.
library;

import 'dart:math' as math;

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

// ── 실제 형상(직선 + 호)으로 그리기 ──

/// 곧은 토막 하나. 치수 글과 번호를 여기에 붙인다.
class PipeStraightRun {
  /// 몇 번째 배관 줄인지(꼬리는 -1).
  final int bendIndex;
  final vm.Vector3 a;
  final vm.Vector3 b;

  const PipeStraightRun({
    required this.bendIndex,
    required this.a,
    required this.b,
  });

  vm.Vector3 get mid => (a + b) * 0.5;
  double get length => (b - a).length;
}

/// 그릴 관의 중심선.
///
/// 🚀 [고침] 예전에는 모서리를 각지게 이어 붙여서, 실제로는 둥글게 휘는
/// 자리가 뾰족하게 그려졌다. 반경만큼 둥근 호로 그린다.
class PipeDrawPath {
  /// 이어 그릴 점들(직선과 호를 잘게 나눈 것).
  final List<vm.Vector3> points;

  /// [points]의 i번째와 i+1번째를 잇는 토막이 몇 번째 배관 줄인지.
  /// 벤드가 휘는 호는 -1.
  final List<int> owner;

  /// 곧은 토막들(글자를 붙일 자리).
  final List<PipeStraightRun> straightRuns;

  /// 꺾이는 점(교차점). 예전 그림이 꼭짓점으로 쓰던 자리.
  final List<vm.Vector3> corners;

  const PipeDrawPath({
    required this.points,
    required this.owner,
    required this.straightRuns,
    required this.corners,
  });
}

/// 배관 목록을 실제 형상(직선 + 반경만큼 둥근 호)으로 걸어 낸다.
///
/// [radius]가 0이면 예전처럼 모서리를 각지게 잇는다.
/// [visualLength]를 주면 길이를 줄여 그린다(실제 비율로 그릴 때는 주지 않는다).
/// [arcSteps]는 호 하나를 몇 토막으로 나눠 그릴지.
PipeDrawPath pipeDrawPath(
  List<dynamic> bendList, {
  required String startDir,
  double radius = 0.0,
  double tail = 0.0,
  double Function(double)? visualLength,
  int arcSteps = 10,
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

  final visTail = tail > 0 ? L(tail) : 0.0;
  final path = buildBendPath(
    segs,
    radius: radius,
    startDirection: directionForName(startDir),
    tail: visTail,
  );

  final points = <vm.Vector3>[vm.Vector3.zero()];
  final owner = <int>[];
  final runs = <PipeStraightRun>[];

  void lineTo(vm.Vector3 p, int who) {
    if ((p - points.last).length2 < 1e-12) return;
    points.add(p.clone());
    owner.add(who);
  }

  var cursor = vm.Vector3.zero();
  var bi = 0;
  for (var i = 0; i < segs.length; i++) {
    final isBend =
        segs[i].angle != 0 &&
        bi < path.bends.length &&
        path.bends[bi].index == i;

    if (!isBend) {
      // 꺾지 않는 줄(또는 꺾을 수 없어 그냥 지나가는 줄).
      final to = path.corners[i];
      runs.add(PipeStraightRun(bendIndex: i, a: cursor.clone(), b: to.clone()));
      lineTo(to, i);
      cursor = to.clone();
      continue;
    }

    final b = path.bends[bi];
    // 휘기 시작하는 자리까지는 곧게.
    runs.add(
      PipeStraightRun(bendIndex: i, a: cursor.clone(), b: b.tangentIn.clone()),
    );
    lineTo(b.tangentIn, i);

    // 휘는 자리는 호로.
    if (radius > 0 && b.setback > 0) {
      final axis = b.dirBefore.cross(b.dirAfter);
      if (axis.length2 > 1e-12) {
        final n = axis.normalized();
        final center = b.tangentIn + n.cross(b.dirBefore) * radius;
        final v = b.tangentIn - center;
        final total = b.angle * math.pi / 180.0;
        final steps = arcSteps < 2 ? 2 : arcSteps;
        for (var k = 1; k <= steps; k++) {
          final t = total * k / steps;
          final p = center + v * math.cos(t) + n.cross(v) * math.sin(t);
          lineTo(p, -1);
        }
      }
    }
    lineTo(b.tangentOut, -1);
    cursor = b.tangentOut.clone();
    bi++;
  }

  if (visTail > 0) {
    final end = path.endPoint;
    runs.add(PipeStraightRun(bendIndex: -1, a: cursor.clone(), b: end.clone()));
    lineTo(end, -1);
  }

  return PipeDrawPath(
    points: points,
    owner: owner,
    straightRuns: runs,
    corners: [vm.Vector3.zero(), ...path.corners],
  );
}
