// 부스바 절곡 계산기(10-03): 구리 부스바를 현장에서 꺾을 때 자르는 길이와 꺾는 선(마킹)을 계산한다.
// 화면 없이 계산만 한다.
//
// 모든 길이는 중립선(꺾어도 길이가 변하지 않는 선) 기준으로 센다.
//  · d = 꺾는 방향의 판 두께. 눕혀 꺾기(폭 방향 축)는 부스바 두께 t, 세워 꺾기(edgewise)는 폭 w.
//  · r = 안쪽 반경, k = 중립선 위치 계수(안쪽 면에서 k·d). 중립선 반경 ρ = r + k·d.
//  · 꺾는 각 θ(꺾은 뒤 방향이 바뀐 각): 꼭짓점 물림 s = ρ·tan(θ/2), 굽힘 호 길이 = ρ·θ(rad).
//  · 자르는 길이 = 꼭짓점 사이 직선 길이의 합 − Σ(2s − 호 길이)
// 마킹은 곧은 부스바 한쪽 끝에서 잰 거리다: 꺾기 시작선·꺾기 끝선(호 양 끝).
// 스프링백·늘어남·벤더 장비 차이는 넣지 않았다(실측으로 k를 맞춘다).
library;

import 'dart:math' as math;

/// 꺾는 방향. flat = 눕혀 꺾기(두께 방향, 폭 w 전체가 꺾임), edge = 세워 꺾기(폭 방향).
enum BusbarBendPlane { flat, edge }

String busbarBendPlaneLabel(BusbarBendPlane p) =>
    p == BusbarBendPlane.flat ? '눕혀 꺾기' : '세워 꺾기';

/// 꺾는 방향에 맞는 판 두께 d(mm). 눕혀 꺾기는 두께, 세워 꺾기는 폭.
double busbarBendDepth(double t, double w, BusbarBendPlane p) =>
    p == BusbarBendPlane.flat ? t : w;

double _rad(double deg) => deg * math.pi / 180;

/// 중립선 반경 ρ = r + k·d.
double busbarNeutralRadius(double d, double r, double k) => r + k * d;

/// 꼭짓점 물림 s(mm): 꼭짓점에서 꺾기 시작선까지 거리.
double busbarSetback(double d, double r, double k, double deg) =>
    busbarNeutralRadius(d, r, k) * math.tan(_rad(deg.abs()) / 2);

/// 굽힘 호 길이(mm, 중립선).
double busbarArc(double d, double r, double k, double deg) =>
    busbarNeutralRadius(d, r, k) * _rad(deg.abs());

/// 꺾는 곳 하나(마킹).
class BusbarBend {
  /// 꺾는 각(°). 부호는 방향(+ 한쪽, − 반대쪽).
  final double turn;

  /// 곧은 부스바 한쪽 끝에서 잰 거리(mm): 꺾기 시작선, 호 가운데, 꺾기 끝선.
  final double start, center, end;

  const BusbarBend({
    required this.turn,
    required this.start,
    required this.center,
    required this.end,
  });
}

class BusbarBendPlan {
  /// 자르는 길이(mm).
  final double cutLength;

  /// 꺾는 곳들(시작 끝에서부터 순서대로).
  final List<BusbarBend> bends;

  /// 직선 구간 길이(꺾는 곳 사이·양 끝, mm). 꺾는 곳이 n개면 n+1개.
  final List<double> straights;

  const BusbarBendPlan({
    required this.cutLength,
    required this.bends,
    required this.straights,
  });
}

/// 일반 계산. [legs] = 꼭짓점 사이 직선 길이(중립선 기준, 양 끝은 부스바 끝에서 꼭짓점까지),
/// [turns] = 꺾는 각(°). legs.length == turns.length + 1.
/// 꺾는 곳이 하나도 없으면(turns 비어 있음) 직선 길이 그대로.
BusbarBendPlan busbarBendPlan({
  required double d,
  required double r,
  required double k,
  required List<double> legs,
  required List<double> turns,
}) {
  assert(legs.length == turns.length + 1);
  final bends = <BusbarBend>[];
  final straights = <double>[];
  var pos = 0.0; // 곧은 부스바 위 현재 위치(직선 구간 시작)
  var prevS = 0.0; // 앞 꼭짓점의 물림
  for (var i = 0; i < turns.length; i++) {
    final s = busbarSetback(d, r, k, turns[i]);
    final arc = busbarArc(d, r, k, turns[i]);
    final straight = legs[i] - prevS - s;
    straights.add(straight);
    final start = pos + straight;
    pos = start + arc;
    bends.add(
      BusbarBend(
        turn: turns[i],
        start: start,
        center: start + arc / 2,
        end: pos,
      ),
    );
    prevS = s;
  }
  final lastLeg = legs.last - prevS;
  straights.add(lastLeg);
  pos += lastLeg;
  return BusbarBendPlan(cutLength: pos, bends: bends, straights: straights);
}

/// 치수를 어디서 재는지(L·U 꺾기).
enum BusbarDimRef { outside, inside }

String busbarDimRefLabel(BusbarDimRef r) =>
    r == BusbarDimRef.outside ? '바깥 치수' : '안쪽 치수';

/// 바깥(또는 안쪽) 면 꼭짓점 기준 치수 → 중립선 꼭짓점 기준 치수로 바꾸는 보정(mm).
/// 바깥 면 꼭짓점은 중립선 꼭짓점보다 (d − k·d)·tan(θ/2)만큼 다리 쪽으로 더 나가 있다(= 빼 준다).
/// 안쪽 면 꼭짓점은 k·d·tan(θ/2)만큼 덜 나가 있다(= 더해 준다).
double busbarDimAdjust(double d, double k, double deg, BusbarDimRef ref) {
  final t = math.tan(_rad(deg.abs()) / 2);
  return ref == BusbarDimRef.outside ? -(1 - k) * d * t : k * d * t;
}

/// L 꺾기: 다리 [a]·[b](끝에서 꼭짓점까지, [ref] 면 기준)와 각 [deg].
BusbarBendPlan busbarL({
  required double d,
  required double r,
  required double k,
  required double a,
  required double b,
  required double deg,
  BusbarDimRef ref = BusbarDimRef.outside,
}) {
  final adj = busbarDimAdjust(d, k, deg, ref);
  return busbarBendPlan(
    d: d,
    r: r,
    k: k,
    legs: [a + adj, b + adj],
    turns: [deg],
  );
}

/// U 꺾기(같은 방향 두 번): 다리 [a]·[c], 바닥 [web]([ref] 면 기준)과 각 [deg](보통 90°).
BusbarBendPlan busbarU({
  required double d,
  required double r,
  required double k,
  required double a,
  required double web,
  required double c,
  double deg = 90,
  BusbarDimRef ref = BusbarDimRef.outside,
}) {
  final adj = busbarDimAdjust(d, k, deg, ref);
  return busbarBendPlan(
    d: d,
    r: r,
    k: k,
    legs: [a + adj, web + 2 * adj, c + adj],
    turns: [deg, deg],
  );
}

/// Z 꺾기(옵셋, 반대 방향 두 번): 같은 쪽 면 사이 높이 [h], 각 [deg].
/// [a]·[c] = 부스바 끝에서 꺾기 시작선까지 직선 길이(시작선 기준이라 [ref] 보정이 없다).
class BusbarZ {
  final BusbarBendPlan plan;

  /// 비스듬한 구간의 직선 길이(mm). 음수면 이 높이·각도에서는 반경 때문에 못 꺾는다.
  final double slope;

  /// 꼭짓점 사이 비스듬한 길이(h ÷ sin θ).
  final double slopeVertex;

  /// 두 꼭짓점 사이 진행 거리(h ÷ tan θ).
  final double run;

  /// 이 각도·반경에서 꺾을 수 있는 가장 작은 높이(2·s·sin θ).
  final double minHeight;

  bool get feasible => slope >= -1e-9;

  const BusbarZ({
    required this.plan,
    required this.slope,
    required this.slopeVertex,
    required this.run,
    required this.minHeight,
  });
}

BusbarZ busbarZ({
  required double d,
  required double r,
  required double k,
  required double a,
  required double c,
  required double h,
  required double deg,
}) {
  final s = busbarSetback(d, r, k, deg);
  final sinT = math.sin(_rad(deg.abs()));
  final tanT = math.tan(_rad(deg.abs()));
  final slopeVertex = h / sinT;
  final plan = busbarBendPlan(
    d: d,
    r: r,
    k: k,
    legs: [a + s, slopeVertex, c + s],
    turns: [deg.abs(), -deg.abs()],
  );
  return BusbarZ(
    plan: plan,
    slope: slopeVertex - 2 * s,
    slopeVertex: slopeVertex,
    run: h / tanT,
    minHeight: 2 * s * sinT,
  );
}

/// 꺾은 부스바 중립선의 옆모습 좌표(mm, y는 위쪽이 +). 시작 끝은 (0, 0)에서 오른쪽으로 간다.
/// + 각은 위쪽(왼쪽으로 도는 방향)으로 꺾는다. 호는 5° 간격으로 나눈 꺾은선이다.
List<math.Point<double>> busbarShape(
  BusbarBendPlan plan,
  double rho, {
  double startHeadingDeg = 0,
}) {
  final pts = <math.Point<double>>[const math.Point(0, 0)];
  var x = 0.0, y = 0.0, heading = _rad(startHeadingDeg);
  void go(double len) {
    x += len * math.cos(heading);
    y += len * math.sin(heading);
    pts.add(math.Point(x, y));
  }

  for (var i = 0; i < plan.bends.length; i++) {
    go(plan.straights[i]);
    final turn = _rad(plan.bends[i].turn);
    final steps = math.max(2, (turn.abs() / _rad(5)).ceil());
    final dTurn = turn / steps;
    final chord = 2 * rho * math.sin(dTurn.abs() / 2);
    for (var s = 0; s < steps; s++) {
      heading += dTurn / 2;
      go(chord);
      heading += dTurn / 2;
    }
  }
  go(plan.straights.last);
  return pts;
}

/// 꺾은선 위에서 시작점으로부터 길이 [len]인 점.
math.Point<double> busbarPointAt(List<math.Point<double>> pts, double len) {
  var acc = 0.0;
  for (var i = 1; i < pts.length; i++) {
    final seg = pts[i].distanceTo(pts[i - 1]);
    if (acc + seg >= len || i == pts.length - 1) {
      final t = seg == 0 ? 0.0 : ((len - acc) / seg).clamp(0.0, 1.0);
      return math.Point(
        pts[i - 1].x + (pts[i].x - pts[i - 1].x) * t,
        pts[i - 1].y + (pts[i].y - pts[i - 1].y) * t,
      );
    }
    acc += seg;
  }
  return pts.last;
}
