// 철판 가공(10-10, 사용자: "평철판 3t, 4t 되는 걸로 원하는 모양으로 가공하는 것 … 레이저 절단만 할 것인가 레이저 가공 절곡까지").
// 레이저로 자를 철판의 전개도(외곽·구멍·장공)와, 꺾는 것이면 꺾기선·방향·각도·전개 길이를 계산한다. 화면 없이 계산만.
//  · 좌표: 전개도 왼쪽 아래가 (0, 0), x는 오른쪽(길이 방향), y는 위(폭 방향), 단위 mm. DXF도 이 좌표 그대로.
//  · 꺾음(ㄱ·ㄷ·Z·모자)은 치수가 모두 바깥 치수다. 꼭짓점 사이 중립선 길이로 바꿔(다리마다 −(1−k)·t·tan(θ/2)씩)
//    부스바 절곡 계산(busbar_bend.dart, 고치지 않음)에 넘겨 전개 길이와 꺾기 시작선·끝선을 받는다.
//  · 공제값(90°, 바깥 치수 합 − 전개 길이)을 넣으면 그 값이 나오게 k를 거꾸로 구해 쓴다(업체 값 맞추기).
//  · 구멍(10-10 배치 편집): 구멍 하나마다 (면, u, v, 지름, 장공 길이, 각도). 평판·리브·자유는 판 위 (u, v) = (x, y).
//    꺾음은 면마다 — u는 그 면 시작(첫 면은 끝, 다른 면은 앞 면 바깥면)에서, v는 아래 가장자리에서.
//    전개도 x = 앞 꺾기 끝선 + u − (r + t)·tan(θ/2). 그래서 면 치수를 바꿔도 구멍은 그 면에 붙어 따라간다.
//  · 판 90° 돌리기(평판·리브·자유): 외곽·구멍을 반시계로 90°씩 돌린 뒤 왼쪽 아래가 (0, 0)이 되게 옮긴다.
//    구멍의 (u, v)는 돌리기 전 자리로 저장하고, 화면·DXF 자리는 돌린 자리다.
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

/// 구멍 하나(저장 단위): 면, 면 위 자리 (u, v), 지름, 장공 전체 길이(0이면 둥근 구멍), 장공 각도(°, 0 = 가로).
class PlateHoleSpec {
  final int face;
  final double u, v, dia, slot, angle;
  const PlateHoleSpec({
    this.face = 0,
    required this.u,
    required this.v,
    required this.dia,
    this.slot = 0,
    this.angle = 0,
  });

  bool get isSlot => slot > dia;

  PlateHoleSpec copyWith({
    int? face,
    double? u,
    double? v,
    double? dia,
    double? slot,
    double? angle,
  }) => PlateHoleSpec(
    face: face ?? this.face,
    u: u ?? this.u,
    v: v ?? this.v,
    dia: dia ?? this.dia,
    slot: slot ?? this.slot,
    angle: angle ?? this.angle,
  );

  Map<String, Object> toJson() => {
    'f': face,
    'u': u,
    'v': v,
    'd': dia,
    's': slot,
    'a': angle,
  };

  /// 저장 값 읽기. 하나짜리 구멍이 아니면 null(예전 묶음 저장은 [PlateHoleGroup.fromJson]).
  static PlateHoleSpec? fromJson(Object? o) {
    if (o is! Map || !o.containsKey('u')) return null;
    double n(String k, double def) =>
        o[k] is num ? (o[k] as num).toDouble() : def;
    final d = n('d', 0);
    if (d <= 0) return null;
    return PlateHoleSpec(
      face: o['f'] is int ? o['f'] as int : 0,
      u: n('u', 0),
      v: n('v', 0),
      dia: d,
      slot: n('s', 0),
      angle: n('a', 0),
    );
  }
}

/// 구멍 여러 개를 한 번에 넣는 틀: 줄(첫 구멍·개수·피치·방향) 또는 네 귀(평판).
/// 10-10 전에는 이것이 저장 단위였다(예전 저장 값은 [expand]로 풀어 옮긴다).
class PlateHoleGroup {
  final int face;
  final double dia;
  final double slot;
  final bool slotAlongX;
  final bool corners;
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

  /// 구멍 하나하나로. 네 귀는 판 상자(돌리기 전 자리) [minX]~[maxX], [minY]~[maxY] 안쪽으로 [x]·[y]씩.
  List<PlateHoleSpec> expand({
    double minX = 0,
    double minY = 0,
    double maxX = 0,
    double maxY = 0,
  }) {
    final s = slot > dia ? slot : 0.0;
    final a = slotAlongX ? 0.0 : 90.0;
    PlateHoleSpec at(double u, double v) =>
        PlateHoleSpec(face: face, u: u, v: v, dia: dia, slot: s, angle: a);
    if (corners) {
      return [
        at(minX + x, minY + y),
        at(maxX - x, minY + y),
        at(maxX - x, maxY - y),
        at(minX + x, maxY - y),
      ];
    }
    return [
      for (var n = 0; n < math.max(1, count); n++)
        rowAlongX ? at(x + n * pitch, y) : at(x, y + n * pitch),
    ];
  }

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

/// 원형 배치(PCD): 가운데 ([cu], [cv])에서 지름 [pcd] 원 위에 [count]개를 같은 간격으로, 첫 구멍은 [startDeg](0 = 오른쪽).
List<PlateHoleSpec> platePcd({
  int face = 0,
  required double cu,
  required double cv,
  required double pcd,
  required int count,
  double startDeg = 0,
  required double dia,
}) {
  final n = math.max(1, count);
  return [
    for (var k = 0; k < n; k++)
      () {
        final a = (startDeg + 360 * k / n) * math.pi / 180;
        return PlateHoleSpec(
          face: face,
          u: cu + pcd / 2 * math.cos(a),
          v: cv + pcd / 2 * math.sin(a),
          dia: dia,
        );
      }(),
  ];
}

/// 모서리 처리(10-10): 직각, R(둥글게), C(빗기게 모따기), 따내기(앞 변으로 가로 [a] × 다음 변으로 [b] 사각을 따냄).
enum PlateCornerKind { none, round, chamfer, notch }

class PlateCorner {
  final PlateCornerKind kind;
  final double a, b;
  const PlateCorner([this.kind = PlateCornerKind.none, this.a = 0, this.b = 0]);

  static const square = PlateCorner();

  bool get isNone => kind == PlateCornerKind.none || a <= 0;

  /// 화면 글: "직각", "R10", "C5", "따내기 20×15".
  String get label => switch (kind) {
    _ when isNone => '직각',
    PlateCornerKind.round => 'R${_f(a)}',
    PlateCornerKind.chamfer => 'C${_f(a)}',
    PlateCornerKind.notch => '따내기 ${_f(a)}×${_f(b <= 0 ? a : b)}',
    PlateCornerKind.none => '직각',
  };

  /// 꼭짓점 줄 꼬리표(자유 모양 글): "r10", "c5", "n20x15". 직각은 빈 글.
  String get token => switch (kind) {
    _ when isNone => '',
    PlateCornerKind.round => 'r${_f(a)}',
    PlateCornerKind.chamfer => 'c${_f(a)}',
    PlateCornerKind.notch => 'n${_f(a)}x${_f(b <= 0 ? a : b)}',
    PlateCornerKind.none => '',
  };

  /// 꼬리표 읽기("R10", "c5", "n20x15", "노치20x15"는 안 받음). 못 읽으면 null.
  static PlateCorner? parseToken(String s) {
    final t = s.trim().toLowerCase();
    final m = RegExp(
      r'^([rcn])\s*([0-9.]+)(?:\s*[x×*]\s*([0-9.]+))?$',
    ).firstMatch(t);
    if (m == null) return null;
    final a = double.tryParse(m.group(2)!);
    if (a == null || a <= 0) return null;
    final b = m.group(3) == null ? a : (double.tryParse(m.group(3)!) ?? a);
    return switch (m.group(1)) {
      'r' => PlateCorner(PlateCornerKind.round, a),
      'c' => PlateCorner(PlateCornerKind.chamfer, a),
      _ => PlateCorner(PlateCornerKind.notch, a, b),
    };
  }

  Map<String, Object> toJson() => {'k': kind.index, 'a': a, 'b': b};

  static PlateCorner fromJson(Object? o) {
    if (o is! Map) return square;
    final k = o['k'];
    double n(String key) => o[key] is num ? (o[key] as num).toDouble() : 0;
    if (k is! int || k < 0 || k >= PlateCornerKind.values.length) return square;
    return PlateCorner(PlateCornerKind.values[k], n('a'), n('b'));
  }
}

/// 꼭짓점 [pts](차례대로, 닫힘)와 꼭짓점마다 처리 [corners]로 외곽 토막들을 만든다.
/// 처리가 이웃 변을 넘으면 [warn]으로 알린다. [names]는 알림에 쓰는 꼭짓점 이름(없으면 번호).
List<PlateSeg> plateCornerOutline(
  List<Offset> pts,
  List<PlateCorner> corners,
  void Function(String) warn, {
  List<String>? names,
}) {
  final n = pts.length;
  if (n < 3) return const [];
  // 다각형 방향(반시계 +)
  var area2 = 0.0;
  for (var i = 0; i < n; i++) {
    final a = pts[i], b = pts[(i + 1) % n];
    area2 += a.dx * b.dy - b.dx * a.dy;
  }
  final ccw = area2 >= 0;
  final entry = List<Offset>.filled(n, Offset.zero);
  final exit = List<Offset>.filled(n, Offset.zero);
  final segs = List<List<PlateSeg>>.generate(n, (_) => []);
  String nameOf(int i) =>
      names != null && i < names.length ? names[i] : '꼭짓점 ${i + 1}';
  for (var i = 0; i < n; i++) {
    final p = pts[i], a = pts[(i - 1 + n) % n], b = pts[(i + 1) % n];
    final c = i < corners.length ? corners[i] : PlateCorner.square;
    final la = (a - p).distance, lb = (b - p).distance;
    entry[i] = p;
    exit[i] = p;
    if (c.isNone || la < 1e-9 || lb < 1e-9) continue;
    final u1 = (a - p) / la, u2 = (b - p) / lb;
    final dot = (u1.dx * u2.dx + u1.dy * u2.dy).clamp(-1.0, 1.0);
    final phi = math.acos(dot); // 두 변 사이 각
    if (phi < 1e-6 || (math.pi - phi) < 1e-6) continue; // 접히거나 곧은 꼭짓점
    final turn = (p - a).dx * (b - p).dy - (p - a).dy * (b - p).dx;
    final convex = ccw ? turn > 0 : turn < 0;
    switch (c.kind) {
      case PlateCornerKind.round:
        final tl = c.a / math.tan(phi / 2);
        final e = p + u1 * tl, x = p + u2 * tl;
        final bis = u1 + u2;
        final cen = p + bis / bis.distance * (c.a / math.sin(phi / 2));
        final a1 = math.atan2(e.dy - cen.dy, e.dx - cen.dx) * 180 / math.pi;
        final a2 = math.atan2(x.dy - cen.dy, x.dx - cen.dx) * 180 / math.pi;
        var sw = a2 - a1;
        while (sw > 180) {
          sw -= 360;
        }
        while (sw <= -180) {
          sw += 360;
        }
        entry[i] = e;
        exit[i] = x;
        segs[i].add(PlateArc(cen, c.a, a1, sw));
      case PlateCornerKind.chamfer:
        final e = p + u1 * c.a, x = p + u2 * c.a;
        entry[i] = e;
        exit[i] = x;
        segs[i].add(PlateLine(e, x));
      case PlateCornerKind.notch:
        if (!convex) {
          warn('${nameOf(i)}는 안으로 꺾인 모서리라 따낼 수 없습니다.');
          continue;
        }
        final bb = c.b <= 0 ? c.a : c.b;
        final e = p + u1 * c.a, x = p + u2 * bb;
        final inner = p + u1 * c.a + u2 * bb;
        entry[i] = e;
        exit[i] = x;
        segs[i]
          ..add(PlateLine(e, inner))
          ..add(PlateLine(inner, x));
      case PlateCornerKind.none:
        break;
    }
  }
  // 변마다 양 끝 처리가 변 길이를 넘으면 알림
  for (var i = 0; i < n; i++) {
    final j = (i + 1) % n;
    final len = (pts[j] - pts[i]).distance;
    final used = (exit[i] - pts[i]).distance + (entry[j] - pts[j]).distance;
    if (used > len + 1e-6) {
      warn(
        '${nameOf(i)}·${nameOf(j)} 사이 변(${_f(len)}mm)보다 모서리 처리가 큽니다. R·C·따내기 값을 줄이십시오.',
      );
    }
  }
  final out = <PlateSeg>[];
  for (var i = 0; i < n; i++) {
    out.addAll(segs[i]);
    final j = (i + 1) % n;
    if ((entry[j] - exit[i]).distance > 1e-9) {
      out.add(PlateLine(exit[i], entry[j]));
    }
  }
  return out;
}

/// 외곽 토막들의 넓이(원호는 정확히).
double plateOutlineArea(List<PlateSeg> outline) {
  var s = 0.0;
  for (final g in outline) {
    switch (g) {
      case PlateLine(:final a, :final b):
        s += a.dx * b.dy - b.dx * a.dy;
      case PlateArc(:final c, :final r, :final start, :final sweep):
        final p1 = g.at(start), p2 = g.at(start + sweep);
        // 원호를 따라 x dy − y dx 적분 = c×(p2 − p1) + r²·쓸어 간 각
        s +=
            c.dx * (p2.dy - p1.dy) -
            c.dy * (p2.dx - p1.dx) +
            r * r * sweep * math.pi / 180;
    }
  }
  return s.abs() / 2;
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

/// 전개도 위 구멍 하나(화면·DXF 자리). 장공은 두 반원 가운데 [p1]–[p2]를 잇는 긴 구멍.
class PlateHole {
  final String label;
  final Offset c;
  final double dia, slot, angle;
  final int face;

  /// 저장 자리(면 기준 u·v, 평판은 돌리기 전 x·y).
  final double u, v;

  /// 만들 수 없음(판 밖·꺾이는 부분·겹침), 주의(꺾기선·판 끝 가까움).
  final bool bad, caution;

  const PlateHole({
    required this.label,
    required this.c,
    required this.dia,
    required this.slot,
    required this.angle,
    required this.face,
    required this.u,
    required this.v,
    this.bad = false,
    this.caution = false,
  });

  PlateHole flagged({bool? bad, bool? caution}) => PlateHole(
    label: label,
    c: c,
    dia: dia,
    slot: slot,
    angle: angle,
    face: face,
    u: u,
    v: v,
    bad: bad ?? this.bad,
    caution: caution ?? this.caution,
  );

  double get r => dia / 2;
  double get _half => slot > dia ? (slot - dia) / 2 : 0;
  Offset get _dir {
    final a = angle * math.pi / 180;
    return Offset(math.cos(a), math.sin(a));
  }

  Offset get p1 => c - _dir * _half;
  Offset get p2 => c + _dir * _half;

  /// 길이(x)·폭(y) 방향으로 중심에서 가장자리까지.
  double get halfX => _dir.dx.abs() * _half + r;
  double get halfY => _dir.dy.abs() * _half + r;

  double get area => slot > dia
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

  /// 자유 모양 꼭짓점(차례대로)과 꼭짓점마다 모서리 처리(없으면 직각).
  final List<Offset> points;
  final List<PlateCorner> pointCorners;

  /// 평판 네 귀 처리(왼쪽 아래·오른쪽 아래·오른쪽 위·왼쪽 위 차례). 비어 있으면 [cornerR]을 네 귀에.
  /// 따내기는 a = 가로(판 가로 변 따라), b = 세로.
  final List<PlateCorner> corners;

  final List<PlateHoleSpec> holes;
  final int qty;

  /// 판을 반시계로 90° 돌린 횟수(0~3, 평판·리브·자유만).
  final int rotQ;

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
    this.pointCorners = const [],
    this.corners = const [],
    this.holes = const [],
    this.qty = 1,
    this.rotQ = 0,
  });

  PlateInput withHoles(List<PlateHoleSpec> h, {int? rotQ}) => PlateInput(
    shape: shape,
    material: material,
    t: t,
    length: length,
    width: width,
    cornerR: cornerR,
    legs: legs,
    angle: angle,
    r: r,
    bd90: bd90,
    ribA: ribA,
    ribB: ribB,
    ribC: ribC,
    points: points,
    pointCorners: pointCorners,
    corners: corners,
    holes: h,
    qty: qty,
    rotQ: rotQ ?? this.rotQ,
  );
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

  /// 꺾음: 면마다 u = 0인 전개도 x, 면의 곧은 부분(꺾기 사이) x 범위.
  final List<double> faceBase;
  final List<(double, double)> faceSpans;

  /// 판 돌린 횟수와 돌린 뒤 옮긴 거리(평판·리브·자유).
  final int rotQ;
  final Offset rotShift;

  /// 쓴 안쪽 반경·k·90° 공제값, 꺾기선에서 구멍까지 일반 규칙 거리(2t + r).
  final double rUsed, kUsed, bd90Used, bendClear;
  final double areaMm2, kgEach, kgTotal;
  final List<String> notes, problems;
  bool get ok => problems.isEmpty;

  double get flatLength => maxX - minX;
  double get flatWidth => maxY - minY;
  bool get isBent => faceBase.isNotEmpty;

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
    required this.faceBase,
    required this.faceSpans,
    required this.rotQ,
    required this.rotShift,
    required this.rUsed,
    required this.kUsed,
    required this.bd90Used,
    required this.bendClear,
    required this.areaMm2,
    required this.kgEach,
    required this.kgTotal,
    required this.notes,
    required this.problems,
  });

  /// 저장 자리(돌리기 전) → 화면·DXF 자리.
  Offset toDisplay(Offset base) => plateRotate(base, rotQ) + rotShift;

  /// 화면·DXF 자리 → 저장 자리(돌리기 전).
  Offset toBase(Offset disp) => plateRotate(disp - rotShift, (4 - rotQ) % 4);

  /// 전개도 x가 놓이는 면(꺾기 부분이면 가까운 면).
  int faceAt(double x) {
    if (faceSpans.isEmpty) return 0;
    var best = 0;
    var bestD = double.infinity;
    for (var f = 0; f < faceSpans.length; f++) {
      final (lo, hi) = faceSpans[f];
      final d = x < lo ? lo - x : (x > hi ? x - hi : 0.0);
      if (d < bestD) {
        bestD = d;
        best = f;
      }
    }
    return best;
  }

  /// 화면(전개도) 자리 → 저장 구멍 자리(면·u·v). 꺾음은 면에 붙이고, 평판은 돌리기 전 자리로.
  (int, double, double) specAt(Offset disp) {
    if (isBent) {
      final f = faceAt(disp.dx);
      return (f, disp.dx - faceBase[f], disp.dy);
    }
    final b = toBase(disp);
    return (0, b.dx, b.dy);
  }
}

String _f(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s;
}

double _rad(double deg) => deg * math.pi / 180;

/// 원점 둘레로 반시계 90°×[q].
Offset plateRotate(Offset p, int q) => switch (q % 4) {
  1 => Offset(-p.dy, p.dx),
  2 => Offset(-p.dx, -p.dy),
  3 => Offset(p.dy, -p.dx),
  _ => p,
};

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

double _cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;

/// 두 선분 사이 가장 가까운 거리(만나면 0).
double plateSegSegDist(Offset p1, Offset p2, Offset q1, Offset q2) {
  final d1 = p2 - p1, d2 = q2 - q1;
  final den = _cross(d1, d2);
  if (den.abs() > 1e-12) {
    final t = _cross(q1 - p1, d2) / den, u = _cross(q1 - p1, d1) / den;
    if (t >= 0 && t <= 1 && u >= 0 && u <= 1) return 0;
  }
  return [
    _distToSeg(p1, q1, q2),
    _distToSeg(p2, q1, q2),
    _distToSeg(q1, p1, p2),
    _distToSeg(q2, p1, p2),
  ].reduce(math.min);
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
  final isBent = plateShapeBends(i.shape);

  var outline = <PlateSeg>[];
  final bends = <PlateBendLine>[];
  BusbarBendPlan? bp;
  final faceNames = plateFaceNames(i.shape);
  var faceLengths = <double>[];
  final faceBase = <double>[];
  final faceSpans = <(double, double)>[];

  List<PlateSeg> rect(double w, double h) => [
    PlateLine(const Offset(0, 0), Offset(w, 0)),
    PlateLine(Offset(w, 0), Offset(w, h)),
    PlateLine(Offset(w, h), Offset(0, h)),
    PlateLine(Offset(0, h), const Offset(0, 0)),
  ];

  switch (i.shape) {
    case PlateShape.flat:
      final w = i.length, h = i.width;
      if (w <= 0 || h <= 0) warn('가로·세로를 넣으십시오.');
      // 네 귀 처리: 넣은 값, 없으면 예전 "모서리 R"(네 귀 같음)
      final cs = i.corners.length == 4
          ? i.corners
          : List.filled(
              4,
              i.cornerR > 0
                  ? PlateCorner(PlateCornerKind.round, i.cornerR)
                  : PlateCorner.square,
            );
      // 평판 따내기는 가로 a × 세로 b로 받는다. 외곽은 앞 변 × 다음 변이라 왼쪽 아래·오른쪽 위는 바꿔 넣는다.
      final cs2 = [
        for (var k = 0; k < 4; k++)
          k.isEven && cs[k].kind == PlateCornerKind.notch
              ? PlateCorner(
                  PlateCornerKind.notch,
                  cs[k].b <= 0 ? cs[k].a : cs[k].b,
                  cs[k].a,
                )
              : cs[k],
      ];
      outline = w > 0 && h > 0
          ? plateCornerOutline(
              [Offset.zero, Offset(w, 0), Offset(w, h), Offset(0, h)],
              cs2,
              warn,
              names: kPlateCornerNames,
            )
          : rect(w, h);
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
        outline = plateCornerOutline(pts, i.pointCorners, warn);
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
      // 면마다: u = 0인 자리(첫 면은 끝 0, 다른 면은 앞 꺾기 끝선 − 바깥 물림)와 곧은 부분
      for (var n = 0; n < legs.length; n++) {
        faceBase.add(
          n == 0
              ? 0
              : plan.bends[n - 1].end -
                    plateOutsideSetback(t, rr, turns[n - 1]),
        );
        final lo = n == 0 ? 0.0 : plan.bends[n - 1].end;
        final hi = n < plan.bends.length ? plan.bends[n].start : plan.cutLength;
        faceSpans.add((lo, hi));
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

  // 판 돌리기(평판·리브·자유): 돌린 뒤 왼쪽 아래가 (0, 0)이 되게 옮긴다.
  final rotQ = isBent ? 0 : ((i.rotQ % 4) + 4) % 4;
  var shift = Offset.zero;
  if (rotQ != 0) {
    final pts = [
      for (final p in plateOutlinePoints(outline)) plateRotate(p, rotQ),
    ];
    if (pts.isNotEmpty) {
      shift = Offset(
        -pts.map((p) => p.dx).reduce(math.min),
        -pts.map((p) => p.dy).reduce(math.min),
      );
    }
    Offset tr(Offset p) => plateRotate(p, rotQ) + shift;
    outline = [
      for (final s in outline)
        switch (s) {
          PlateLine(:final a, :final b) => PlateLine(tr(a), tr(b)),
          PlateArc(:final c, :final r, :final start, :final sweep) => PlateArc(
            tr(c),
            r,
            start + 90.0 * rotQ,
            sweep,
          ),
        },
    ];
  }

  final poly = plateOutlinePoints(outline);
  var minX = 0.0, minY = 0.0, maxX = 0.0, maxY = 0.0;
  if (poly.isNotEmpty) {
    minX = poly.map((p) => p.dx).reduce(math.min);
    maxX = poly.map((p) => p.dx).reduce(math.max);
    minY = poly.map((p) => p.dy).reduce(math.min);
    maxY = poly.map((p) => p.dy).reduce(math.max);
  }

  // 구멍: 저장 자리 → 화면·DXF 자리
  var holes = <PlateHole>[];
  for (var n = 0; n < i.holes.length; n++) {
    final s = i.holes[n];
    final int face = isBent
        ? s.face.clamp(0, math.max(0, faceBase.length - 1)).toInt()
        : 0;
    final c = isBent && faceBase.isNotEmpty
        ? Offset(faceBase[face] + s.u, s.v)
        : plateRotate(Offset(s.u, s.v), rotQ) + shift;
    holes.add(
      PlateHole(
        label: '${n + 1}',
        c: c,
        dia: s.dia,
        slot: s.isSlot ? s.slot : 0,
        angle: s.angle + (isBent ? 0 : 90.0 * rotQ),
        face: face,
        u: s.u,
        v: s.v,
      ),
    );
    if (s.slot > 0 && !s.isSlot) {
      notes.add('구멍 ${n + 1}의 장공 길이가 지름 이하라 둥근 구멍으로 봅니다.');
    }
  }

  // 구멍 검사: 판 밖, 가장자리, 꺾기 가까이, 서로 겹침
  final edgeRule = 2 * t + rr; // 꺾기선(시작·끝)에서 구멍 가장자리까지 일반 판금 규칙
  final outside = <String>[],
      nearEdge = <String>[],
      nearBend = <String>[],
      inBend = <String>[];
  final bad = <int>{}, caution = <int>{};
  for (var n = 0; n < holes.length; n++) {
    final h = holes[n];
    final inside =
        poly.length >= 3 && _inPolygon(h.p1, poly) && _inPolygon(h.p2, poly);
    var edgeD = double.infinity;
    for (var a = 0; a < poly.length; a++) {
      edgeD = math.min(
        edgeD,
        plateSegSegDist(h.p1, h.p2, poly[a], poly[(a + 1) % poly.length]),
      );
    }
    if (!inside || edgeD < h.r - 1e-9) {
      outside.add(h.label);
      bad.add(n);
    } else if (edgeD - h.r < t - 1e-9) {
      nearEdge.add(h.label);
      caution.add(n);
    }
    for (final b in bends) {
      final lo = h.c.dx - h.halfX, hi = h.c.dx + h.halfX;
      if (hi > b.start - 1e-9 && lo < b.end + 1e-9) {
        inBend.add(h.label);
        bad.add(n);
      } else {
        final d = hi < b.start ? b.start - hi : lo - b.end;
        if (d < edgeRule - 1e-9) {
          nearBend.add(h.label);
          caution.add(n);
        }
      }
    }
  }
  String names(List<String> l) {
    final u = l.toSet().toList();
    return u.length <= 6
        ? u.join('·')
        : '${u.take(6).join('·')} 외 ${u.length - 6}개';
  }

  // 구멍 이름이 숫자라 조사가 어색하지 않게 "…구멍: 이름" 꼴로 쓴다.
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
      if (plateSegSegDist(p.p1, p.p2, q.p1, q.p2) < p.r + q.r - 1e-9) {
        clash.add('${p.label}·${q.label}');
        bad.addAll([a, b]);
      }
    }
  }
  if (clash.isNotEmpty) warn('서로 겹치는 구멍: ${names(clash)}.');
  if (holes.any((h) => h.dia < t)) {
    notes.add('두께보다 작은 구멍은 레이저 업체에 따라 못 뚫거나 모양이 나쁠 수 있습니다.');
  }
  holes = [
    for (var n = 0; n < holes.length; n++)
      holes[n].flagged(bad: bad.contains(n), caution: caution.contains(n)),
  ];

  // 넓이·무게
  final area = outline.isEmpty ? 0.0 : plateOutlineArea(outline);
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
    faceBase: faceBase,
    faceSpans: faceSpans,
    rotQ: rotQ,
    rotShift: shift,
    rUsed: rr,
    kUsed: k,
    bd90Used: bd90,
    bendClear: edgeRule,
    areaMm2: net,
    kgEach: kg,
    kgTotal: kg * qty,
    notes: notes,
    problems: problems,
  );
}

/// 구멍 모양 글: "φ13.5", "장공 11×30(가로)", "장공 11×30(45°)".
String plateHoleKind(PlateHole h) {
  if (h.slot <= 0) return 'φ${_f(h.dia)}';
  final a = ((h.angle % 180) + 180) % 180;
  final dir = a.abs() < 1e-6
      ? '가로'
      : ((a - 90).abs() < 1e-6 ? '세로' : '${_f(a)}°');
  return '장공 ${_f(h.dia)}×${_f(h.slot)}($dir)';
}

/// 평판 네 귀 이름(차례: 왼쪽 아래 → 오른쪽 아래 → 오른쪽 위 → 왼쪽 위).
const List<String> kPlateCornerNames = ['왼쪽 아래', '오른쪽 아래', '오른쪽 위', '왼쪽 위'];

/// "x,y" 줄들을 꼭짓점으로(쉼표·공백·/ 로 나눔). 못 읽는 줄은 뺀다.
List<Offset> parsePlatePoints(String text) => [
  for (final (p, _) in parsePlateVertices(text)) p,
];

/// "x,y[,r10|c5|n20x15]" 줄들을 꼭짓점과 모서리 처리로. 셋째 칸이 없거나 못 읽으면 직각.
List<(Offset, PlateCorner)> parsePlateVertices(String text) {
  final out = <(Offset, PlateCorner)>[];
  for (final line in text.split(RegExp(r'[\n;]'))) {
    final parts = line
        .trim()
        .split(RegExp(r'[,\s/]+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length < 2) continue;
    final x = double.tryParse(parts[0]), y = double.tryParse(parts[1]);
    if (x == null || y == null) continue;
    final c = parts.length >= 3
        ? (PlateCorner.parseToken(parts.sublist(2).join()) ??
              PlateCorner.square)
        : PlateCorner.square;
    out.add((Offset(x, y), c));
  }
  return out;
}

/// 꼭짓점과 처리를 "x,y[,r10]" 줄 글로(자유 모양 칸에 넣는 글).
String platePointsText(List<Offset> pts, List<PlateCorner> corners) => [
  for (var i = 0; i < pts.length; i++)
    () {
      final c = i < corners.length ? corners[i].token : '';
      return '${_f(pts[i].dx)},${_f(pts[i].dy)}${c.isEmpty ? '' : ',$c'}';
    }(),
].join('\n');

/// 구멍 십자 치수 하나(10-10 사용자: "치수선이 십자로"): 구멍 가운데 [c]에서 판 왼쪽 끝·아래 끝까지.
/// [left]·[bottom]이 false면 같은 줄의 다른 구멍이 이미 그 치수를 달아 생략한다. [armX]·[armY]는 십자 중심선을
/// 구멍 밖으로 내는 반 길이(mm, 구멍·장공 크기).
class PlateHoleDim {
  final Offset c;
  final bool left, bottom;
  final double armX, armY;
  const PlateHoleDim(
    this.c, {
    required this.left,
    required this.bottom,
    this.armX = 0,
    this.armY = 0,
  });
}

/// 구멍마다 십자 치수를 정한다. 같은 높이(± [tol]) 구멍들은 아래 치수를 맨 왼쪽 하나에만,
/// 같은 가로 자리 구멍들은 왼쪽 치수를 맨 아래 하나에만 단다(도면이 덜 복잡하게).
List<PlateHoleDim> plateHoleDims(
  List<(Offset c, double armX, double armY)> holes, {
  double tol = 0.05,
}) => [
  for (var i = 0; i < holes.length; i++)
    () {
      final c = holes[i].$1;
      var left = true, bottom = true;
      for (var j = 0; j < holes.length; j++) {
        if (j == i) continue;
        final o = holes[j].$1;
        // 같은 세로줄: 더 아래(같으면 앞 번호) 구멍이 왼쪽 치수를 단다
        if ((o.dx - c.dx).abs() <= tol &&
            (o.dy < c.dy - tol || ((o.dy - c.dy).abs() <= tol && j < i))) {
          left = false;
        }
        // 같은 가로줄: 더 왼쪽(같으면 앞 번호) 구멍이 아래 치수를 단다
        if ((o.dy - c.dy).abs() <= tol &&
            (o.dx < c.dx - tol || ((o.dx - c.dx).abs() <= tol && j < i))) {
          bottom = false;
        }
      }
      return PlateHoleDim(
        c,
        left: left,
        bottom: bottom,
        armX: holes[i].$2,
        armY: holes[i].$3,
      );
    }(),
];
