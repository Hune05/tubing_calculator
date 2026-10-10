// 철판 가공(10-10, 사용자: "평철판 3t, 4t 되는 걸로 원하는 모양으로 가공하는 것 … 레이저 절단만 할 것인가 레이저 가공 절곡까지").
// 레이저로 자를 철판의 전개도(외곽·구멍·장공)와, 꺾는 것이면 꺾기선·방향·각도·전개 길이를 계산한다. 화면 없이 계산만.
//  · 좌표: 전개도 왼쪽 아래가 (0, 0), x는 오른쪽(길이 방향), y는 위(폭 방향), 단위 mm. DXF도 이 좌표 그대로.
//  · 꺾음(ㄱ·ㄷ·Z·모자)은 치수가 모두 바깥 치수다. 꼭짓점 사이 중립선 길이로 바꿔(다리마다 −(1−k)·t·tan(θ/2)씩)
//    부스바 절곡 계산(busbar_bend.dart, 고치지 않음)에 넘겨 전개 길이와 꺾기 시작선·끝선을 받는다.
//  · 공제값(90°, 바깥 치수 합 − 전개 길이)을 넣으면 그 값이 나오게 k를 거꾸로 구해 쓴다(업체 값 맞추기).
//  · 구멍 자리: 평판·리브·자유는 판 위 (x, y). 꺾음은 면마다 (u, v) — u는 그 면 시작(첫 면은 끝, 다른 면은 앞 면 바깥면)에서,
//    v는 아래 가장자리에서. 전개도 x = 앞 꺾기 끝선 + u − (r + t)·tan(θ/2).
library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../electrical/busbar_bend.dart' show BusbarBendPlan, busbarBendPlan;

enum PlateShape { flat, rib, free, l, u, z, hat }

/// 꺾는 모양인지(절단 + 절곡).
bool plateShapeBends(PlateShape s) =>
    s == PlateShape.l ||
    s == PlateShape.u ||
    s == PlateShape.z ||
    s == PlateShape.hat;

enum PlateMaterial { steel, stainless, aluminum }

const Map<PlateMaterial, (String, double)> kPlateMaterials = {
  PlateMaterial.steel: ('철판', 7.85),
  PlateMaterial.stainless: ('스테인리스', 7.93),
  PlateMaterial.aluminum: ('알루미늄', 2.70),
};

/// 공제값을 모를 때 쓰는 중립선 계수(일반 판금 값, 업체 값과 다를 수 있다).
const double kPlateDefaultK = 0.33;

/// 구멍 묶음 하나: 둥근 구멍 또는 장공(긴 구멍).
class PlateHoleGroup {
  /// 꺾음에서 구멍이 있는 면(0부터). 평판·리브·자유는 0.
  final int face;
  final double dia;

  /// 장공 전체 길이(0이면 둥근 구멍), 장공 방향(true = 길이(x) 방향).
  final double slot;
  final bool slotAlongX;

  /// 네 귀: [x]·[y]를 가장자리에서 구멍 중심까지 거리로 써서 네 귀에 하나씩(평판만).
  final bool corners;

  /// 줄: 첫 구멍 (x, y), 개수, 피치, 줄 방향(true = x 방향).
  final int count;
  final double x, y, pitch;
  final bool rowAlongX;

  const PlateHoleGroup({
    this.face = 0,
    required this.dia,
    this.slot = 0,
    this.slotAlongX = true,
    this.corners = false,
    this.count = 1,
    required this.x,
    required this.y,
    this.pitch = 0,
    this.rowAlongX = true,
  });

  Map<String, Object> toJson() => {
    'f': face,
    'd': dia,
    's': slot,
    'sx': slotAlongX,
    'c': corners,
    'n': count,
    'x': x,
    'y': y,
    'p': pitch,
    'rx': rowAlongX,
  };

  static PlateHoleGroup? fromJson(Object? o) {
    if (o is! Map) return null;
    double n(String k, double def) =>
        o[k] is num ? (o[k] as num).toDouble() : def;
    final d = n('d', 0);
    if (d <= 0) return null;
    return PlateHoleGroup(
      face: o['f'] is int ? o['f'] as int : 0,
      dia: d,
      slot: n('s', 0),
      slotAlongX: o['sx'] != false,
      corners: o['c'] == true,
      count: o['n'] is int && (o['n'] as int) >= 1 ? o['n'] as int : 1,
      x: n('x', 0),
      y: n('y', 0),
      pitch: n('p', 0),
      rowAlongX: o['rx'] != false,
    );
  }
}

/// 외곽 한 토막: 직선 또는 원호(가운데·반지름·시작 각·쓸어 가는 각, °, 반시계가 +).
sealed class PlateSeg {
  const PlateSeg();
}

class PlateLine extends PlateSeg {
  final Offset a, b;
  const PlateLine(this.a, this.b);
}

class PlateArc extends PlateSeg {
  final Offset c;
  final double r, start, sweep;
  const PlateArc(this.c, this.r, this.start, this.sweep);

  Offset at(double deg) {
    final a = deg * math.pi / 180;
    return c + Offset(math.cos(a), math.sin(a)) * r;
  }
}

/// 전개도 위 구멍 하나(장공이면 [slot] > 0).
class PlateHole {
  final String label;
  final Offset c;
  final double dia, slot;
  final bool slotAlongX;
  final int face;

  /// 면 기준 자리(꺾음일 때 면 시작에서 u, 아래 가장자리에서 v).
  final double u, v;
  const PlateHole({
    required this.label,
    required this.c,
    required this.dia,
    required this.slot,
    required this.slotAlongX,
    required this.face,
    required this.u,
    required this.v,
  });

  /// 길이(x)·폭(y) 방향으로 중심에서 가장자리까지.
  double get halfX => slot > 0 && slotAlongX ? slot / 2 : dia / 2;
  double get halfY => slot > 0 && !slotAlongX ? slot / 2 : dia / 2;

  double get area => slot > 0
      ? dia * (slot - dia) + math.pi * dia * dia / 4
      : math.pi * dia * dia / 4;
}

/// 꺾기선 하나(전개도 x 위치): 가운데 선과 꺾기 시작·끝선, 각(+ 위로, − 아래로).
class PlateBendLine {
  final double center, start, end, turn;
  const PlateBendLine(this.center, this.start, this.end, this.turn);
}

class PlateInput {
  final PlateShape shape;
  final PlateMaterial material;
  final double t;

  /// 평판: 가로 [length]·세로 [width]·모서리 R [cornerR]. 꺾음: 폭 [width](꺾는 선 방향).
  final double length, width, cornerR;

  /// 꺾음: 면마다 바깥 치수(ㄱ 2개, ㄷ·Z 3개, 모자 [발, 높이, 윗면]), ㄱ자 각도.
  final List<double> legs;
  final double angle;

  /// 안쪽 반경(null이면 두께), 90° 공제값(null이면 일반 k 값).
  final double? r, bd90;

  /// 삼각 리브: 가로 변·세로 변·직각 모서리 따내기.
  final double ribA, ribB, ribC;

  /// 자유 모양 꼭짓점(차례대로).
  final List<Offset> points;

  final List<PlateHoleGroup> holes;
  final int qty;

  const PlateInput({
    required this.shape,
    this.material = PlateMaterial.steel,
    required this.t,
    this.length = 0,
    this.width = 0,
    this.cornerR = 0,
    this.legs = const [],
    this.angle = 90,
    this.r,
    this.bd90,
    this.ribA = 0,
    this.ribB = 0,
    this.ribC = 0,
    this.points = const [],
    this.holes = const [],
    this.qty = 1,
  });
}

class PlatePlan {
  final List<PlateSeg> outline;
  final List<PlateHole> holes;
  final List<PlateBendLine> bends;

  /// 외곽을 감싸는 상자(전개도).
  final double minX, minY, maxX, maxY;

  /// 꺾음의 옆모습 계산(그림용), 면 이름, 면 바깥 치수.
  final BusbarBendPlan? bendPlan;
  final List<String> faceNames;
  final List<double> faceLengths;

  /// 쓴 안쪽 반경·k·90° 공제값.
  final double rUsed, kUsed, bd90Used;
  final double areaMm2, kgEach, kgTotal;
  final List<String> notes, problems;
  bool get ok => problems.isEmpty;

  double get flatLength => maxX - minX;
  double get flatWidth => maxY - minY;

  const PlatePlan({
    required this.outline,
    required this.holes,
    required this.bends,
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
    required this.bendPlan,
    required this.faceNames,
    required this.faceLengths,
    required this.rUsed,
    required this.kUsed,
    required this.bd90Used,
    required this.areaMm2,
    required this.kgEach,
    required this.kgTotal,
    required this.notes,
    required this.problems,
  });
}

String _f(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s;
}

double _rad(double deg) => deg * math.pi / 180;

/// 바깥 꼭짓점에서 꺾기 시작선까지(바깥 물림) = (r + t)·tan(θ/2).
double plateOutsideSetback(double t, double r, double deg) =>
    (r + t) * math.tan(_rad(deg.abs()) / 2);

/// 90° 공제값(바깥 치수 두 개 합 − 전개 길이) = 2(r + t) − π/2·(r + k·t).
double plateBendDeduction90(double t, double r, double k) =>
    2 * (r + t) - math.pi / 2 * (r + k * t);

/// 90° 공제값 [bd]가 나오는 k.
double plateKFromDeduction(double t, double r, double bd) =>
    ((2 * (r + t) - bd) / (math.pi / 2) - r) / t;

/// 면 이름(그림·표).
List<String> plateFaceNames(PlateShape s) => switch (s) {
  PlateShape.l => const ['1면', '2면'],
  PlateShape.u || PlateShape.z => const ['1면', '2면', '3면'],
  PlateShape.hat => const ['왼쪽 발', '왼쪽 다리', '윗면', '오른쪽 다리', '오른쪽 발'],
  _ => const ['판'],
};

/// 꺾음 모양의 면 바깥 치수와 꺾는 각. 모자는 [발, 높이, 윗면]을 [발, 높이, 윗면, 높이, 발]로 편다.
(List<double>, List<double>) plateLegsTurns(PlateInput i) {
  final l = i.legs;
  double at(int k) => k < l.length ? l[k] : 0;
  return switch (i.shape) {
    PlateShape.l => ([at(0), at(1)], [i.angle]),
    PlateShape.u => ([at(0), at(1), at(2)], const [90.0, 90.0]),
    PlateShape.z => ([at(0), at(1), at(2)], const [90.0, -90.0]),
    PlateShape.hat => (
      [at(0), at(1), at(2), at(1), at(0)],
      const [90.0, -90.0, -90.0, 90.0],
    ),
    _ => (const <double>[], const <double>[]),
  };
}

double _distToSeg(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 == 0) return (p - a).distance;
  var t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2;
  t = t.clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

bool _inPolygon(Offset p, List<Offset> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i], b = poly[j];
    if ((a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      inside = !inside;
    }
  }
  return inside;
}

double _polyArea(List<Offset> pts) {
  var s = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final a = pts[i], b = pts[(i + 1) % pts.length];
    s += a.dx * b.dy - b.dx * a.dy;
  }
  return s.abs() / 2;
}

/// 외곽을 점들로(원호는 잘게). 그림·검사용.
List<Offset> plateOutlinePoints(
  List<PlateSeg> outline, {
  double stepDeg = 7.5,
}) {
  final out = <Offset>[];
  for (final s in outline) {
    switch (s) {
      case PlateLine(:final a):
        out.add(a);
      case PlateArc():
        final n = math.max(2, (s.sweep.abs() / stepDeg).ceil());
        for (var k = 0; k < n; k++) {
          out.add(s.at(s.start + s.sweep * k / n));
        }
    }
  }
  return out;
}

PlatePlan platePlan(PlateInput i) {
  final notes = <String>[], problems = <String>[];
  void warn(String s) {
    if (!problems.contains(s)) problems.add(s);
  }

  final t = i.t;
  if (t <= 0) warn('두께를 넣으십시오.');
  final rr = i.r ?? t;
  var k = kPlateDefaultK;
  if (i.bd90 != null && t > 0) {
    k = plateKFromDeduction(t, rr, i.bd90!);
    if (k < 0 || k > 1) {
      warn(
        '공제값 ${_f(i.bd90!)}mm는 두께 ${_f(t)}·안쪽 반경 ${_f(rr)}로는 나올 수 없는 값입니다(k ${k.toStringAsFixed(2)}). 공제값이나 반경을 확인하십시오.',
      );
      k = k.clamp(0.0, 1.0);
    }
  }
  final bd90 = plateBendDeduction90(t, rr, k);

  var outline = <PlateSeg>[];
  var poly = <Offset>[];
  final bends = <PlateBendLine>[];
  BusbarBendPlan? bp;
  var faceNames = plateFaceNames(i.shape);
  var faceLengths = <double>[];
  var faceStart = <double Function(double u)>[];
  var faceSpan = <(double, double)>[]; // 면마다 전개도 x 범위(꺾기선 사이 곧은 부분)

  List<PlateSeg> rect(double w, double h) => [
    PlateLine(const Offset(0, 0), Offset(w, 0)),
    PlateLine(Offset(w, 0), Offset(w, h)),
    PlateLine(Offset(w, h), Offset(0, h)),
    PlateLine(Offset(0, h), const Offset(0, 0)),
  ];

  switch (i.shape) {
    case PlateShape.flat:
      final w = i.length, h = i.width;
      final r = i.cornerR.clamp(0.0, math.min(w, h) / 2);
      if (w <= 0 || h <= 0) warn('가로·세로를 넣으십시오.');
      if (i.cornerR > math.min(w, h) / 2 + 1e-9) {
        notes.add('모서리 R이 판 크기의 반보다 커서 ${_f(r)}mm로 계산했습니다.');
      }
      if (r <= 0) {
        outline = rect(w, h);
      } else {
        outline = [
          PlateLine(Offset(r, 0), Offset(w - r, 0)),
          PlateArc(Offset(w - r, r), r, -90, 90),
          PlateLine(Offset(w, r), Offset(w, h - r)),
          PlateArc(Offset(w - r, h - r), r, 0, 90),
          PlateLine(Offset(w - r, h), Offset(r, h)),
          PlateArc(Offset(r, h - r), r, 90, 90),
          PlateLine(Offset(0, h - r), Offset(0, r)),
          PlateArc(Offset(r, r), r, 180, 90),
        ];
      }
      faceLengths = [w];
    case PlateShape.rib:
      final a = i.ribA, b = i.ribB, c = i.ribC;
      if (a <= 0 || b <= 0) warn('삼각 리브의 두 변을 넣으십시오.');
      if (c >= math.min(a, b)) warn('모서리 따내기가 변보다 깁니다.');
      final pts = c > 0
          ? [Offset(c, 0), Offset(a, 0), Offset(0, b), Offset(0, c)]
          : [const Offset(0, 0), Offset(a, 0), Offset(0, b)];
      outline = [
        for (var k2 = 0; k2 < pts.length; k2++)
          PlateLine(pts[k2], pts[(k2 + 1) % pts.length]),
      ];
      faceLengths = [a];
    case PlateShape.free:
      final pts = i.points;
      if (pts.length < 3) {
        warn('자유 모양은 꼭짓점이 3개 이상이어야 합니다.');
      } else {
        outline = [
          for (var k2 = 0; k2 < pts.length; k2++)
            PlateLine(pts[k2], pts[(k2 + 1) % pts.length]),
        ];
        if (_polyArea(pts) < 1) warn('자유 모양의 넓이가 없습니다. 꼭짓점을 확인하십시오.');
      }
    case PlateShape.l:
    case PlateShape.u:
    case PlateShape.z:
    case PlateShape.hat:
      final (legs, turns) = plateLegsTurns(i);
      faceLengths = legs;
      final w = i.width;
      if (w <= 0) warn('폭을 넣으십시오.');
      if (i.shape == PlateShape.l && (i.angle <= 0 || i.angle >= 180)) {
        warn('꺾는 각도는 0°와 180° 사이여야 합니다.');
      }
      double adj(double deg) => -(1 - k) * t * math.tan(_rad(deg.abs()) / 2);
      final neutral = [
        for (var n = 0; n < legs.length; n++)
          legs[n] +
              (n > 0 ? adj(turns[n - 1]) : 0) +
              (n < turns.length ? adj(turns[n]) : 0),
      ];
      final plan = busbarBendPlan(
        d: t,
        r: rr,
        k: k,
        legs: neutral,
        turns: turns,
      );
      bp = plan;
      for (var n = 0; n < plan.straights.length; n++) {
        if (plan.straights[n] <= 0) {
          warn(
            '${faceNames[n]} 바깥 치수 ${_f(legs[n])}mm가 너무 짧아 꺾을 수 없습니다(꺾기 부분보다 짧음).',
          );
        }
      }
      for (final b in plan.bends) {
        bends.add(PlateBendLine(b.center, b.start, b.end, b.turn));
      }
      outline = rect(plan.cutLength, w);
      // 면마다: 시작 위치(첫 면은 끝 0, 다른 면은 앞 꺾기 끝선 − 바깥 물림)
      for (var n = 0; n < legs.length; n++) {
        if (n == 0) {
          faceStart.add((u) => u);
        } else {
          final e = plan.bends[n - 1].end;
          final s = plateOutsideSetback(t, rr, turns[n - 1]);
          faceStart.add((u) => e + u - s);
        }
        final lo = n == 0 ? 0.0 : plan.bends[n - 1].end;
        final hi = n < plan.bends.length ? plan.bends[n].start : plan.cutLength;
        faceSpan.add((lo, hi));
      }
      // 짧은 면: 절곡기 V홈에 걸치지 못할 수 있다(보통 V홈 폭 = 두께 6~8배, 다리는 그 반 + 두께 이상).
      final minLeg = 5 * t;
      final short = [
        for (var n = 0; n < legs.length; n++)
          if (legs[n] < minLeg) faceNames[n],
      ];
      if (short.isNotEmpty && t > 0) {
        notes.add(
          '${short.join('·')} 바깥 치수가 두께의 5배(${_f(minLeg)}mm)보다 짧습니다. 절곡기 금형(V홈 폭은 보통 두께의 6~8배)에 걸치지 못할 수 있으니 업체에 확인하십시오.',
        );
      }
  }

  poly = plateOutlinePoints(outline);
  var minX = 0.0, minY = 0.0, maxX = 0.0, maxY = 0.0;
  if (poly.isNotEmpty) {
    minX = poly.map((p) => p.dx).reduce(math.min);
    maxX = poly.map((p) => p.dx).reduce(math.max);
    minY = poly.map((p) => p.dy).reduce(math.min);
    maxY = poly.map((p) => p.dy).reduce(math.max);
  }

  // 구멍
  final holes = <PlateHole>[];
  var gi = 0;
  for (final g in i.holes) {
    gi++;
    final isBent = plateShapeBends(i.shape);
    final face = isBent ? g.face.clamp(0, faceStart.length - 1) : 0;
    Offset map(double u, double v) => isBent && faceStart.isNotEmpty
        ? Offset(faceStart[face](u), v)
        : Offset(u, v);
    final list = <(double, double)>[];
    if (g.corners && !isBent) {
      list.addAll([
        (minX + g.x, minY + g.y),
        (maxX - g.x, minY + g.y),
        (maxX - g.x, maxY - g.y),
        (minX + g.x, maxY - g.y),
      ]);
    } else {
      for (var n = 0; n < math.max(1, g.count); n++) {
        list.add(
          g.rowAlongX ? (g.x + n * g.pitch, g.y) : (g.x, g.y + n * g.pitch),
        );
      }
      if (g.count > 1 &&
          g.pitch <=
              (g.rowAlongX == g.slotAlongX && g.slot > 0 ? g.slot : g.dia)) {
        warn('구멍 묶음 $gi의 피치가 구멍 크기 이하라 구멍이 서로 겹칩니다.');
      }
    }
    if (g.slot > 0 && g.slot <= g.dia) {
      notes.add('구멍 묶음 $gi의 장공 길이가 지름 이하라 둥근 구멍으로 봅니다.');
    }
    var n = 0;
    for (final (u, v) in list) {
      n++;
      holes.add(
        PlateHole(
          label: '$gi-$n',
          c: map(u, v),
          dia: g.dia,
          slot: g.slot > g.dia ? g.slot : 0,
          slotAlongX: g.slotAlongX,
          face: face,
          u: u,
          v: v,
        ),
      );
    }
  }

  // 구멍 검사: 판 밖, 가장자리, 꺾기 가까이, 서로 겹침
  final edgeRule = 2 * t + rr; // 꺾기선(시작·끝)에서 구멍 가장자리까지 일반 판금 규칙
  final outside = <String>[],
      nearEdge = <String>[],
      nearBend = <String>[],
      inBend = <String>[];
  for (final h in holes) {
    final hx = h.halfX, hy = h.halfY;
    final inside = poly.length >= 3 && _inPolygon(h.c, poly);
    var edgeD = double.infinity;
    for (var a = 0; a < poly.length; a++) {
      edgeD = math.min(
        edgeD,
        _distToSeg(h.c, poly[a], poly[(a + 1) % poly.length]),
      );
    }
    if (!inside || edgeD < math.max(hx, hy) - 1e-9) {
      outside.add(h.label);
    } else if (edgeD - math.max(hx, hy) < t - 1e-9) {
      nearEdge.add(h.label);
    }
    for (final b in bends) {
      final lo = h.c.dx - hx, hi = h.c.dx + hx;
      if (hi > b.start - 1e-9 && lo < b.end + 1e-9) {
        inBend.add(h.label);
      } else {
        final d = hi < b.start ? b.start - hi : lo - b.end;
        if (d < edgeRule - 1e-9) nearBend.add(h.label);
      }
    }
  }
  String names(List<String> l) {
    final u = l.toSet().toList();
    return u.length <= 4
        ? u.join('·')
        : '${u.take(4).join('·')} 외 ${u.length - 4}개';
  }

  // 구멍 이름이 숫자(1-2)라 조사가 어색하지 않게 "…구멍: 이름" 꼴로 쓴다.
  if (outside.isNotEmpty) {
    warn('판 밖으로 나오는 구멍: ${names(outside)}. 자리를 확인하십시오.');
  }
  if (inBend.isNotEmpty) {
    warn('꺾이는 부분에 걸리는 구멍: ${names(inBend)}. 구멍을 꺾기선에서 떼십시오.');
  }
  if (nearBend.isNotEmpty) {
    notes.add(
      '꺾기선에서 ${_f(edgeRule)}mm(2 × 두께 + 안쪽 반경)보다 가까운 구멍: ${names(nearBend)}. 꺾을 때 구멍이 늘어날 수 있습니다(일반 판금 규칙).',
    );
  }
  if (nearEdge.isNotEmpty) {
    notes.add(
      '판 끝에서 두께(${_f(t)}mm)보다 가까운 구멍: ${names(nearEdge)}. 레이저 열로 찢어지거나 휠 수 있습니다.',
    );
  }
  final clash = <String>[];
  for (var a = 0; a < holes.length; a++) {
    for (var b = a + 1; b < holes.length; b++) {
      final p = holes[a], q = holes[b];
      final gap = (p.c - q.c).distance;
      final reach = math.max(p.halfX, p.halfY) + math.max(q.halfX, q.halfY);
      // 둥근 구멍끼리는 정확히, 장공이 끼면 감싸는 상자로 본다.
      final overlap = p.slot == 0 && q.slot == 0
          ? gap < reach - 1e-9
          : (p.c.dx - q.c.dx).abs() < p.halfX + q.halfX - 1e-9 &&
                (p.c.dy - q.c.dy).abs() < p.halfY + q.halfY - 1e-9;
      if (overlap) clash.add('${p.label}·${q.label}');
    }
  }
  if (clash.isNotEmpty) warn('서로 겹치는 구멍: ${names(clash)}.');
  if (holes.any((h) => h.dia < t)) {
    notes.add('두께보다 작은 구멍은 레이저 업체에 따라 못 뚫거나 모양이 나쁠 수 있습니다.');
  }

  // 넓이·무게
  var area = 0.0;
  if (i.shape == PlateShape.flat) {
    final r = i.cornerR.clamp(0.0, math.min(i.length, i.width) / 2);
    area = i.length * i.width - (4 - math.pi) * r * r;
  } else if (poly.length >= 3) {
    area = _polyArea(poly);
  }
  final holeArea = holes.fold(0.0, (s, h) => s + h.area);
  final net = math.max(0.0, area - holeArea);
  final density = kPlateMaterials[i.material]!.$2; // g/cm³
  final kg = net * t * density * 1e-6;
  final qty = i.qty < 1 ? 1 : i.qty;

  return PlatePlan(
    outline: outline,
    holes: holes,
    bends: bends,
    minX: minX,
    minY: minY,
    maxX: maxX,
    maxY: maxY,
    bendPlan: bp,
    faceNames: faceNames,
    faceLengths: faceLengths,
    rUsed: rr,
    kUsed: k,
    bd90Used: bd90,
    areaMm2: net,
    kgEach: kg,
    kgTotal: kg * qty,
    notes: notes,
    problems: problems,
  );
}

/// "x,y" 줄들을 꼭짓점으로(쉼표·공백·/ 로 나눔). 못 읽는 줄은 뺀다.
List<Offset> parsePlatePoints(String text) {
  final out = <Offset>[];
  for (final line in text.split(RegExp(r'[\n;]'))) {
    final parts = line
        .trim()
        .split(RegExp(r'[,\s/]+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length < 2) continue;
    final x = double.tryParse(parts[0]), y = double.tryParse(parts[1]);
    if (x == null || y == null) continue;
    out.add(Offset(x, y));
  }
  return out;
}
