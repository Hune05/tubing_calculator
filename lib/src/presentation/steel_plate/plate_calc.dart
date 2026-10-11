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
//  · 직접 절곡(10-11, 사용자: "스케치도 절곡으로 넘기고, 절곡 위치·방향 지정"): 바깥 치수로 펴 그린 모양(좌표·스케치) 위에
//    나란한 절곡선(판 끝에서 그 절곡 바깥 꼭짓점까지 바깥 치수 · 각도 · UP/DOWN). 면 길이 = 절곡선 사이 바깥 치수라
//    ㄱ·ㄷ·Z·모자와 같은 계산을 쓰고, 외곽은 곧은 곳은 그대로 옮기고 절곡부(바깥 물림 두 개)는 원호 길이로 줄여 전개도를 만든다.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import '../electrical/busbar_bend.dart' show BusbarBendPlan, busbarBendPlan;

/// 모양. 원형([circle])·링([ring], 와셔처럼 가운데가 뚫린 원판)은 10-10 상용 앱 비교로 더함(끝에 붙여 저장 이름이 안 바뀌게).
/// 직접 절곡([custom], 10-11)도 끝에 붙임.
enum PlateShape { flat, rib, free, l, u, z, hat, circle, ring, custom }

/// 꺾는 모양인지(절단 + 절곡).
bool plateShapeBends(PlateShape s) =>
    s == PlateShape.l ||
    s == PlateShape.u ||
    s == PlateShape.z ||
    s == PlateShape.hat ||
    s == PlateShape.custom;

/// 직접 절곡의 절곡선 하나(10-11): 판 끝(세로선은 왼쪽, 가로선은 아래)에서 그 절곡의 바깥 꼭짓점까지 바깥 치수 [at],
/// 각도 [angle](°, 크기), 접는 쪽 [up](UP = 전개도를 위에서 본 쪽으로).
class PlateBendSpec {
  final double at, angle;
  final bool up;
  const PlateBendSpec({required this.at, this.angle = 90, this.up = true});

  /// 계산에 쓰는 각(+ UP, − DOWN).
  double get turn => up ? angle : -angle;

  PlateBendSpec copyWith({double? at, double? angle, bool? up}) =>
      PlateBendSpec(
        at: at ?? this.at,
        angle: angle ?? this.angle,
        up: up ?? this.up,
      );

  Map<String, Object> toJson() => {'at': at, 'a': angle, 'up': up};

  static PlateBendSpec? fromJson(Object? o) {
    if (o is! Map) return null;
    final at = o['at'], a = o['a'];
    if (at is! num) return null;
    return PlateBendSpec(
      at: at.toDouble(),
      angle: a is num ? a.toDouble() : 90,
      up: o['up'] != false,
    );
  }
}

/// 직접 절곡의 펴 그린 판(바깥 치수, 절곡선이 세로가 되게 돌린 자리, 왼쪽 아래 (0, 0))과 판 끝~끝 길이.
/// 계산([platePlan])과 같은 돌리기·옮기기다. 꼭짓점이 3개 미만이면 빈 판.
(List<Offset>, double) plateCustomOuter(PlateInput i) {
  if (i.points.length < 3) return (const <Offset>[], 0.0);
  final raw = [
    for (final p in plateOutlinePoints(
      plateCornerOutline(i.points, i.pointCorners, (_) {}),
    ))
      i.bendAxisH ? Offset(p.dy, -p.dx) : p,
  ];
  if (raw.length < 3) return (const <Offset>[], 0.0);
  // 기준점·판 끝은 꼭짓점(코너 처리 전)으로: 계산과 같게(점검 49 — 외곽 최솟값을 써서 끝 꼭짓점에 R·C가
  // 있으면 창의 판 폭이 짧고 미리보기 절곡선이 어긋났다)
  final vr = [for (final p in i.points) i.bendAxisH ? Offset(p.dy, -p.dx) : p];
  final o = Offset(
    vr.map((p) => p.dx).reduce(math.min),
    vr.map((p) => p.dy).reduce(math.min),
  );
  return (
    [for (final p in raw) p - o],
    vr.map((p) => p.dx).reduce(math.max) - o.dx,
  );
}

/// 꼭짓점 차례가 엇갈려 외곽선이 서로 꼬이는 두 변(1부터 센 변 번호). 안 꼬이면 null(점검 51).
(int, int)? plateSelfCrossing(List<Offset> pts) {
  final n = pts.length;
  if (n < 4) return null;
  double cross(Offset o, Offset a, Offset b) =>
      (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
  bool hit(Offset a, Offset b, Offset c, Offset d) {
    final d1 = cross(c, d, a), d2 = cross(c, d, b);
    final d3 = cross(a, b, c), d4 = cross(a, b, d);
    return ((d1 > 1e-9 && d2 < -1e-9) || (d1 < -1e-9 && d2 > 1e-9)) &&
        ((d3 > 1e-9 && d4 < -1e-9) || (d3 < -1e-9 && d4 > 1e-9));
  }

  for (var i = 0; i < n; i++) {
    for (var j = i + 2; j < n; j++) {
      if (i == 0 && j == n - 1) continue; // 이웃한 변(마지막 ↔ 첫)
      if (hit(pts[i], pts[(i + 1) % n], pts[j], pts[(j + 1) % n])) {
        return (i + 1, j + 1);
      }
    }
  }
  return null;
}

/// 세로선 x에서 다각형 판을 가로지르는 구간들(아래 → 위). 절곡선을 판이 있는 곳에만 긋는다(T자 같은 모양).
List<(double, double)> plateBendSpans(List<Offset> poly, double x) {
  final ys = <double>[];
  for (var i = 0; i < poly.length; i++) {
    final a = poly[i], b = poly[(i + 1) % poly.length];
    if ((a.dx <= x && b.dx > x) || (b.dx <= x && a.dx > x)) {
      ys.add(a.dy + (x - a.dx) / (b.dx - a.dx) * (b.dy - a.dy));
    }
  }
  ys.sort();
  return [for (var k = 0; k + 1 < ys.length; k += 2) (ys[k], ys[k + 1])];
}

enum PlateMaterial { steel, stainless, aluminum }

const Map<PlateMaterial, (String, double)> kPlateMaterials = {
  PlateMaterial.steel: ('철판', 7.85),
  PlateMaterial.stainless: ('SUS', 7.93),
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

/// 도면 코너 글 하나: 귀 자리(그림), 처리, 사각 판 귀인가(따내기를 가로 × 세로로 읽는가).
class PlateCornerMark {
  final Offset at;
  final PlateCorner corner;
  final bool rect;
  const PlateCornerMark(this.at, this.corner, {this.rect = true});

  /// 도면 글: "R10", "C5", 사각 판 따내기 "따냄 가로 20 × 세로 15", 좌표 판 따내기 "따냄 앞 변 20 × 다음 변 15".
  String get label => corner.kind == PlateCornerKind.notch
      ? (rect
            ? '따냄 가로 ${_f2(corner.a)} × 세로 ${_f2(corner.b <= 0 ? corner.a : corner.b)}'
            : '따냄 앞 변 ${_f2(corner.a)} × 다음 변 ${_f2(corner.b <= 0 ? corner.a : corner.b)}')
      : corner.label;
}

/// 모서리 처리(10-10): 직각, R(둥글게), C(빗기게 모따기), 따내기(앞 변으로 가로 [a] × 다음 변으로 [b] 사각을 따냄).
enum PlateCornerKind { none, round, chamfer, notch }

class PlateCorner {
  final PlateCornerKind kind;
  final double a, b;
  const PlateCorner([this.kind = PlateCornerKind.none, this.a = 0, this.b = 0]);

  static const square = PlateCorner();

  bool get isNone => kind == PlateCornerKind.none || a <= 0;

  /// 화면 글: "직각", "R10", "C5", "따내기 20×15"(소수 둘째 자리까지).
  String get label => switch (kind) {
    _ when isNone => '직각',
    PlateCornerKind.round => 'R${_f2(a)}',
    PlateCornerKind.chamfer => 'C${_f2(a)}',
    PlateCornerKind.notch => '따내기 ${_f2(a)}×${_f2(b <= 0 ? a : b)}',
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
          warn('${nameOf(i)}는 안쪽 코너라 따낼 수 없습니다.');
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
    // 0.01mm까지는 봐준다(DXF 반원을 R 코너 둘로 읽으면 사이 변이 꼭 맞게 다 쓰인다, 10-11)
    if (used > len + 0.01) {
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

  /// 판 밖(외곽 밖이거나 외곽선·내경에 걸림). 모양을 바꿔 밖으로 나간 홀을 알릴 때 쓴다(10-11).
  final bool out;

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
    this.out = false,
  });

  PlateHole flagged({bool? bad, bool? caution, bool? out}) => PlateHole(
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
    out: out ?? this.out,
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

  /// 원형·링: 외경 [dia], 링 내경 [innerDia].
  final double dia, innerDia;

  /// 직접 절곡: 절곡선들과, 절곡선이 가로인가(가로면 판을 시계로 90° 돌려 계산).
  final List<PlateBendSpec> bendLines;
  final bool bendAxisH;

  /// ㄱ·ㄷ·Z·모자: 절곡마다 방향을 뒤집는가(UP ↔ DOWN, 10-11).
  final List<bool> flips;

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
    this.dia = 0,
    this.innerDia = 0,
    this.bendLines = const [],
    this.bendAxisH = false,
    this.flips = const [],
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
    dia: dia,
    innerDia: innerDia,
    bendLines: bendLines,
    bendAxisH: bendAxisH,
    flips: flips,
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

  /// 모양에 딸린 안쪽 따냄(링 내경). 사용자 홀([holes])과 따로 둔다(홀 번호·편집과 섞이지 않게).
  final List<PlateHole> cutouts;

  /// 레이저 절단 길이(외곽 + 홀·장공·내경 둘레, mm)와 피어싱 수(외곽 1 + 안쪽 따냄마다 1).
  final double cutLength;
  final int pierces;

  /// 좌표로 넣은 판(좌표 입력·직접 절곡)의 꼭짓점(코너 처리 전, 그림·DXF 자리). 도면 변 길이 치수에 쓴다(10-11).
  /// 다른 모양은 빈 목록.
  final List<Offset> vertices;

  /// 코너 처리한 귀(그림 자리)와 처리. [PlateCornerMark.rect]면 따내기 a × b가 그림 가로 × 세로,
  /// 아니면(좌표로 넣은 판) 앞 변 × 다음 변. 도면 코너 글에 쓴다(10-11).
  final List<PlateCornerMark> cornerMarks;

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
    this.cutouts = const [],
    this.cutLength = 0,
    this.pierces = 0,
    this.vertices = const [],
    this.cornerMarks = const [],
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
/// [PlateInput.flips]가 켜진 절곡은 방향을 뒤집는다. 직접 절곡은 모양에서 구하므로 여기서는 빈 값.
(List<double>, List<double>) plateLegsTurns(PlateInput i) {
  final (legs, turns) = _legsTurns(i);
  return (
    legs,
    [
      for (var n = 0; n < turns.length; n++)
        n < i.flips.length && i.flips[n] ? -turns[n] : turns[n],
    ],
  );
}

(List<double>, List<double>) _legsTurns(PlateInput i) {
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
        '공제값 ${_f(i.bd90!)}mm는 두께 ${_f(t)}·내R ${_f(rr)}로는 나올 수 없는 값입니다(K값 ${k.toStringAsFixed(2)}). 공제값이나 반경을 확인하십시오.',
      );
      k = k.clamp(0.0, 1.0);
    }
  }
  final bd90 = plateBendDeduction90(t, rr, k);
  final isBent = plateShapeBends(i.shape);

  var outline = <PlateSeg>[];
  final inner = <(Offset, double)>[]; // 링 내경(가운데, 지름) — 돌리기 전 자리
  final bends = <PlateBendLine>[];
  BusbarBendPlan? bp;
  var faceNames = plateFaceNames(i.shape);
  var faceLengths = <double>[];
  final faceBase = <double>[];
  final faceSpans = <(double, double)>[];
  // 계산에 쓰는 홀(직접 절곡은 판 밖 절곡선을 뺀 면으로 다시 잡는다)
  var holeSpecs = i.holes;
  // 좌표로 넣은 판의 꼭짓점(그림 자리, 도면 변 길이 치수용)과 코너 처리한 귀(도면 코너 글)
  var verts = <Offset>[];
  var marks = <PlateCornerMark>[];
  List<PlateCornerMark> rectMarks(double w, double h, List<PlateCorner> cs) => [
    for (final (k, q) in [
      Offset.zero,
      Offset(w, 0),
      Offset(w, h),
      Offset(0, h),
    ].indexed)
      if (k < cs.length && !cs[k].isNone) PlateCornerMark(q, cs[k]),
  ];

  List<PlateSeg> rect(double w, double h) => [
    PlateLine(const Offset(0, 0), Offset(w, 0)),
    PlateLine(Offset(w, 0), Offset(w, h)),
    PlateLine(Offset(w, h), Offset(0, h)),
    PlateLine(Offset(0, h), const Offset(0, 0)),
  ];

  /// 사각 판(가로 [w] × 세로 [h])의 네 귀 처리. 평판·절곡 전개도가 같이 쓴다.
  /// 따내기는 가로 a × 세로 b로 받는다. 외곽은 앞 변 × 다음 변이라 왼쪽 아래·오른쪽 위는 바꿔 넣는다.
  List<PlateSeg> cornerRect(double w, double h, List<PlateCorner> cs) {
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
    return plateCornerOutline(
      [Offset.zero, Offset(w, 0), Offset(w, h), Offset(0, h)],
      cs2,
      warn,
      names: kPlateCornerNames,
    );
  }

  /// 꺾음 공통(ㄱ·ㄷ·Z·모자·직접): 면 바깥 치수 [legs]·각 [turns] → 중립선 → 절곡선·면 자리, 외곽은 [w] 폭 사각.
  void bentStrip(List<double> legs, List<double> turns, double w) {
    faceLengths = legs;
    double adj(double deg) => -(1 - k) * t * math.tan(_rad(deg.abs()) / 2);
    final neutral = [
      for (var n = 0; n < legs.length; n++)
        legs[n] +
            (n > 0 ? adj(turns[n - 1]) : 0) +
            (n < turns.length ? adj(turns[n]) : 0),
    ];
    final plan = busbarBendPlan(d: t, r: rr, k: k, legs: neutral, turns: turns);
    bp = plan;
    for (var n = 0; n < plan.straights.length; n++) {
      if (plan.straights[n] <= 0) {
        warn(
          '${faceNames[n]} 바깥 치수 ${_f(legs[n])}mm가 너무 짧아 절곡할 수 없습니다(절곡부보다 짧음).',
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
            : plan.bends[n - 1].end - plateOutsideSetback(t, rr, turns[n - 1]),
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
      outline = w > 0 && h > 0 ? cornerRect(w, h, cs) : rect(w, h);
      marks = rectMarks(w, h, cs);
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
      // 따낸 모서리·빗변 길이도 도면 변 치수로(10-11)
      if (a > 0 && b > 0) verts = List.of(pts);
      faceLengths = [a];
    case PlateShape.free:
      final pts = i.points;
      if (pts.length < 3) {
        warn('좌표 입력은 꼭짓점이 3개 이상이어야 합니다.');
      } else {
        outline = plateCornerOutline(pts, i.pointCorners, warn);
        verts = List.of(pts);
        marks = [
          for (var k = 0; k < pts.length && k < i.pointCorners.length; k++)
            if (!i.pointCorners[k].isNone)
              PlateCornerMark(pts[k], i.pointCorners[k], rect: false),
        ];
        if (_polyArea(pts) < 1) warn('좌표로 넣은 모양의 넓이가 없습니다. 꼭짓점을 확인하십시오.');
        final x = plateSelfCrossing(pts);
        if (x != null) {
          warn(
            '꼭짓점 차례가 엇갈려 외곽선이 꼬입니다(변 ${x.$1}과 변 ${x.$2}). 꼭짓점을 둘레를 따라 차례대로 넣으십시오.',
          );
        }
      }
    case PlateShape.circle:
    case PlateShape.ring:
      final d0 = i.dia;
      if (d0 <= 0) warn('외경을 넣으십시오.');
      if (d0 > 0) {
        final r0 = d0 / 2;
        outline = [PlateArc(Offset(r0, r0), r0, 0, 360)];
        if (i.shape == PlateShape.ring) {
          final di = i.innerDia;
          if (di <= 0) {
            warn('내경을 넣으십시오.');
          } else if (di >= d0) {
            warn('내경이 외경보다 크거나 같습니다.');
          } else {
            if ((d0 - di) / 2 < t) {
              notes.add(
                '링 폭(${_f((d0 - di) / 2)}mm)이 두께보다 좁습니다. 레이저 열로 휘거나 찢어질 수 있습니다.',
              );
            }
            inner.add((Offset(r0, r0), di));
          }
        }
      }
      faceLengths = [d0];
    case PlateShape.l:
    case PlateShape.u:
    case PlateShape.z:
    case PlateShape.hat:
      final (legs, turns) = plateLegsTurns(i);
      faceLengths = legs;
      final w = i.width;
      if (w <= 0) warn('폭을 넣으십시오.');
      if (i.shape == PlateShape.l && (i.angle <= 0 || i.angle >= 180)) {
        warn('절곡 각도는 0°와 180° 사이여야 합니다.');
      }
      bentStrip(legs, turns, w);
      // 전개도 네 귀 처리(10-11 사용자: "절곡 절단에서는 모서리 따는 기능이 없나?"): 평판과 같은 R·C·따내기.
      // 왼쪽 귀는 1면 끝, 오른쪽 귀는 마지막 면 끝이다. 절곡부까지 닿으면 알린다.
      final cs = i.corners.length == 4
          ? i.corners
          : List.filled(4, PlateCorner.square);
      final len = outline.isEmpty
          ? 0.0
          : plateOutlinePoints(outline).map((p) => p.dx).reduce(math.max);
      if (w > 0 && len > 0 && cs.any((c) => !c.isNone)) {
        outline = cornerRect(len, w, cs);
        marks = rectMarks(len, w, cs);
        // 코너가 길이 방향으로 차지하는 몫(따내기는 가로)
        double ext(PlateCorner c) => c.isNone ? 0 : c.a;
        if (bends.isNotEmpty) {
          for (final k in const [0, 3]) {
            if (ext(cs[k]) > bends.first.start + 1e-6) {
              warn(
                '${kPlateCornerNames[k]} 코너(${cs[k].label})가 1번 절곡부에 닿습니다. 판 끝에서 ${_f(bends.first.start)}mm 안으로 줄이십시오.',
              );
            }
          }
          for (final k in const [1, 2]) {
            if (len - ext(cs[k]) < bends.last.end - 1e-6) {
              warn(
                '${kPlateCornerNames[k]} 코너(${cs[k].label})가 ${bends.length}번 절곡부에 닿습니다. 판 끝에서 ${_f(len - bends.last.end)}mm 안으로 줄이십시오.',
              );
            }
          }
        }
      }
    case PlateShape.custom:
      // 바깥 치수로 펴 그린 판(좌표·스케치). 가로선이면 시계로 90° 돌려 절곡선이 세로가 되게, 왼쪽 아래를 (0, 0)으로.
      if (i.points.length < 3) {
        warn('판 모양(꼭짓점 3개 이상)을 넣으십시오.');
        break;
      }
      final x = plateSelfCrossing(i.points);
      if (x != null) {
        warn(
          '꼭짓점 차례가 엇갈려 외곽선이 꼬입니다(변 ${x.$1}과 변 ${x.$2}). 꼭짓점을 둘레를 따라 차례대로 넣으십시오.',
        );
      }
      Offset rot(Offset p) => i.bendAxisH ? Offset(p.dy, -p.dx) : p;
      var segs = [
        for (final g in plateCornerOutline(i.points, i.pointCorners, warn))
          switch (g) {
            PlateLine(:final a, :final b) => PlateLine(rot(a), rot(b)),
            PlateArc(:final c, :final r, :final start, :final sweep) =>
              PlateArc(rot(c), r, i.bendAxisH ? start - 90 : start, sweep),
          },
      ];
      final raw = plateOutlinePoints(segs);
      if (raw.length < 3) break;
      // 기준점은 꼭짓점(코너 처리 전)의 왼쪽 아래: 꼭짓점 표·홀·절곡선이 다 이 자리에서 잰 바깥 치수다
      // (외곽 최소점으로 잡으면 끝 꼭짓점에 R·C·따내기가 있을 때 홀이 어긋났다, 점검 39, 10-11).
      final vr = [for (final p in i.points) rot(p)];
      final o = Offset(
        vr.map((p) => p.dx).reduce(math.min),
        vr.map((p) => p.dy).reduce(math.min),
      );
      segs = [
        for (final g in segs)
          switch (g) {
            PlateLine(:final a, :final b) => PlateLine(a - o, b - o),
            PlateArc(:final c, :final r, :final start, :final sweep) =>
              PlateArc(c - o, r, start, sweep),
          },
      ];
      final wOut = vr.map((p) => p.dx).reduce(math.max) - o.dx;
      verts = [for (final p in vr) p - o];
      marks = [
        for (var k = 0; k < verts.length && k < i.pointCorners.length; k++)
          if (!i.pointCorners[k].isNone)
            PlateCornerMark(verts[k], i.pointCorners[k], rect: false),
      ];
      final specs = [
        for (final b in i.bendLines)
          if (b.at > 1e-6 && b.at < wOut - 1e-6) b,
      ]..sort((a, b) => a.at.compareTo(b.at));
      if (specs.length != i.bendLines.length) {
        warn('판 밖에 있는 절곡선이 있습니다. 절곡선은 판 끝에서 0 ~ ${_f(wOut)}mm 사이에 넣으십시오.');
      }
      for (var n = 1; n < specs.length; n++) {
        if (specs[n].at - specs[n - 1].at < 1e-6) {
          warn('같은 자리(${_f(specs[n].at)}mm)에 절곡선이 둘 있습니다.');
        }
      }
      for (final b in specs) {
        if (b.angle <= 0 || b.angle >= 180) {
          warn('절곡 각도는 0°와 180° 사이여야 합니다.');
        }
      }
      if (specs.length != i.bendLines.length) {
        // 판 밖 절곡선은 빼고 계산하므로 홀 면도 남은 절곡선으로 다시 잡는다(바깥 자리 그대로).
        // 그대로 두면 뒤 면 홀이 판 안 엉뚱한 자리에 그려지고 판 밖 경고도 없었다(점검 37, 10-11).
        final all = [
          0.0,
          ...([for (final b in i.bendLines) b.at]..sort()),
        ];
        final ok = [0.0, for (final b in specs) b.at];
        holeSpecs = [
          for (final h in i.holes)
            () {
              final x = all[h.face.clamp(0, all.length - 1)] + h.u;
              var f = 0;
              for (var k = 0; k < ok.length; k++) {
                if (ok[k] <= x + 1e-9) f = k;
              }
              return h.copyWith(face: f, u: x - ok[f]);
            }(),
        ];
      }
      if (specs.isEmpty) {
        // 절곡선을 넣기 전: 펴 그린 모양 그대로 한 면
        outline = segs;
        faceNames = const ['1면'];
        faceLengths = [wOut];
        faceBase.add(0);
        faceSpans.add((0, wOut));
        break;
      }
      final legs = [
        specs.first.at,
        for (var n = 1; n < specs.length; n++) specs[n].at - specs[n - 1].at,
        wOut - specs.last.at,
      ];
      faceNames = [for (var n = 0; n < legs.length; n++) '${n + 1}면'];
      bentStrip(legs, [for (final b in specs) b.turn], 0);
      // 바깥 치수 x → 전개도 x: 곧은 곳은 그대로 옮기고, 절곡부(꼭짓점 ± 바깥 물림)는 원호 길이(시작~끝선)로 줄인다
      final zones = [
        for (var n = 0; n < specs.length && n < bends.length; n++)
          (
            specs[n].at - plateOutsideSetback(t, rr, specs[n].turn),
            specs[n].at + plateOutsideSetback(t, rr, specs[n].turn),
            bends[n].start,
            bends[n].end,
          ),
      ];
      double fx(double x) {
        var po = 0.0, pf = 0.0;
        for (final (a, b, s0, e0) in zones) {
          if (x <= a) return pf + (x - po);
          if (x <= b) {
            return b - a < 1e-9 ? s0 : s0 + (x - a) / (b - a) * (e0 - s0);
          }
          po = b;
          pf = e0;
        }
        return pf + (x - po);
      }

      verts = [for (final q in verts) Offset(fx(q.dx), q.dy)];
      marks = [
        for (final m in marks)
          PlateCornerMark(Offset(fx(m.at.dx), m.at.dy), m.corner, rect: false),
      ];
      final cuts = [
        for (final (a, b, _, _) in zones) ...[a, b],
      ];
      bool inZone(double x) => zones.any((z) => x > z.$1 && x < z.$2);
      List<PlateSeg> mapLine(Offset a, Offset b) {
        final ts = <double>[0, 1];
        for (final c in cuts) {
          if ((a.dx - c) * (b.dx - c) < 0) ts.add((c - a.dx) / (b.dx - a.dx));
        }
        ts.sort();
        Offset m(double u) {
          final q = Offset.lerp(a, b, u)!;
          return Offset(fx(q.dx), q.dy);
        }

        return [
          for (var k = 0; k + 1 < ts.length; k++)
            if (ts[k + 1] - ts[k] > 1e-9) PlateLine(m(ts[k]), m(ts[k + 1])),
        ];
      }

      outline = [
        for (final g in segs)
          ...switch (g) {
            PlateLine(:final a, :final b) => mapLine(a, b),
            PlateArc(:final c, :final r, :final start, :final sweep) =>
              // 곧은 곳 안의 원호는 그대로 옮기고, 절곡부에 걸리면 잘게 나눠 옮긴다
              !inZone(c.dx) && !cuts.any((x) => x > c.dx - r && x < c.dx + r)
                  ? [PlateArc(Offset(fx(c.dx), c.dy), r, start, sweep)]
                  : [
                      for (
                        var k = 0, n = math.max(2, (sweep.abs() / 7.5).ceil());
                        k < n;
                        k++
                      )
                        ...mapLine(
                          g.at(start + sweep * k / n),
                          g.at(start + sweep * (k + 1) / n),
                        ),
                    ],
          },
      ];
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
    verts = [for (final v in verts) tr(v)];
    // 돌린 사각 판 따내기는 그림 가로·세로가 바뀐다
    marks = [
      for (final m in marks)
        PlateCornerMark(
          tr(m.at),
          m.rect && rotQ.isOdd && m.corner.kind == PlateCornerKind.notch
              ? PlateCorner(
                  m.corner.kind,
                  m.corner.b <= 0 ? m.corner.a : m.corner.b,
                  m.corner.a,
                )
              : m.corner,
          rect: m.rect,
        ),
    ];
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

  final cutouts = [
    for (final (c, d) in inner)
      PlateHole(
        label: '내경',
        c: plateRotate(c, rotQ) + shift,
        dia: d,
        slot: 0,
        angle: 0,
        face: 0,
        u: c.dx,
        v: c.dy,
      ),
  ];

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
  for (var n = 0; n < holeSpecs.length; n++) {
    final s = holeSpecs[n];
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
      notes.add('홀 ${n + 1}의 장공 길이가 지름 이하라 원형 홀로 봅니다.');
    }
  }

  // 구멍 검사: 판 밖, 가장자리, 꺾기 가까이, 서로 겹침
  final edgeRule = 2 * t + rr; // 절곡선(시작·끝)에서 홀 가장자리까지 일반 판금 규칙
  final outside = <String>[],
      nearEdge = <String>[],
      nearBend = <String>[],
      inBend = <String>[],
      faceOut = <String>[];
  final bad = <int>{}, caution = <int>{}, out = <int>{};
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
      out.add(n);
    } else if (edgeD - h.r < t - 1e-9) {
      nearEdge.add(h.label);
      caution.add(n);
    }
    for (final co in cutouts) {
      final gap = plateSegSegDist(h.p1, h.p2, co.c, co.c) - co.r - h.r;
      if (gap < -1e-9) {
        outside.add(h.label);
        bad.add(n);
        out.add(n);
      } else if (gap < t - 1e-9) {
        nearEdge.add(h.label);
        caution.add(n);
      }
    }
    var hitBend = false;
    for (final b in bends) {
      final lo = h.c.dx - h.halfX, hi = h.c.dx + h.halfX;
      if (hi > b.start - 1e-9 && lo < b.end + 1e-9) {
        inBend.add(h.label);
        bad.add(n);
        hitBend = true;
      } else {
        final d = hi < b.start ? b.start - hi : lo - b.end;
        if (d < edgeRule - 1e-9) {
          nearBend.add(h.label);
          caution.add(n);
        }
      }
    }
    // 자기 면 밖(점검 38, 10-11): 면 치수를 줄이거나 면이 없어지면 홀이 옆 면 자리로 넘어가는데도
    // "1면 60"처럼 남고 경고가 없었다. 판 밖·절곡부에 걸린 홀은 위에서 알린다.
    if (faceSpans.isNotEmpty && !hitBend && !out.contains(n)) {
      final (lo, hi) = faceSpans[h.face.clamp(0, faceSpans.length - 1)];
      if (holeSpecs[n].face != h.face ||
          h.c.dx < lo - 1e-6 ||
          h.c.dx > hi + 1e-6) {
        faceOut.add(h.label);
        bad.add(n);
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
    warn('판 밖으로 나오는 홀: ${names(outside)}. 자리를 확인하십시오.');
  }
  if (inBend.isNotEmpty) {
    warn('절곡부에 걸리는 홀: ${names(inBend)}. 홀을 절곡선에서 떼십시오.');
  }
  if (faceOut.isNotEmpty) {
    warn(
      '자기 면을 벗어난 홀: ${names(faceOut)}. 면 치수가 줄어 다른 면 자리에 있습니다. 홀 탭에서 다시 놓으십시오.',
    );
  }
  if (nearBend.isNotEmpty) {
    notes.add(
      '절곡선에서 ${_f(edgeRule)}mm(2 × 두께 + 내R)보다 가까운 홀: ${names(nearBend)}. 절곡할 때 홀이 늘어날 수 있습니다(일반 판금 규칙).',
    );
  }
  if (nearEdge.isNotEmpty) {
    notes.add(
      '판 끝에서 두께(${_f(t)}mm)보다 가까운 홀: ${names(nearEdge)}. 레이저 열로 찢어지거나 휠 수 있습니다.',
    );
  }
  final clash = <String>[], bridge = <String>[];
  for (var a = 0; a < holes.length; a++) {
    for (var b = a + 1; b < holes.length; b++) {
      final p = holes[a], q = holes[b];
      final gap = plateSegSegDist(p.p1, p.p2, q.p1, q.p2) - p.r - q.r;
      if (gap < -1e-9) {
        clash.add('${p.label}·${q.label}');
        bad.addAll([a, b]);
      } else if (gap < t - 1e-9) {
        // 홀 사이 살(브릿지)이 두께보다 좁으면 열로 휘거나 찢어지기 쉽다(일반 레이저 기준, 업체마다 다름)
        bridge.add('${p.label}·${q.label}');
        caution.addAll([a, b]);
      }
    }
  }
  if (clash.isNotEmpty) warn('서로 겹치는 홀: ${names(clash)}.');
  if (bridge.isNotEmpty) {
    notes.add(
      '홀 사이가 두께(${_f(t)}mm)보다 좁은 곳: ${names(bridge)}. 레이저 열로 휘거나 찢어질 수 있습니다.',
    );
  }
  final small = [
    for (var n = 0; n < holes.length; n++)
      if (holes[n].dia < t) n,
  ];
  if (small.isNotEmpty) {
    caution.addAll(small);
    notes.add(
      '두께보다 작은 홀: ${names([for (final n in small) holes[n].label])}. 레이저 업체에 따라 못 뚫거나 모양이 나쁠 수 있습니다.',
    );
  }
  holes = [
    for (var n = 0; n < holes.length; n++)
      holes[n].flagged(
        bad: bad.contains(n),
        caution: caution.contains(n),
        out: out.contains(n),
      ),
  ];

  // 넓이·무게. 판 밖 홀은 뚫을 자리가 없으니 넓이·절단 길이·피어싱에서 뺀다(점검 58).
  final cutHoles = [
    for (final h in holes)
      if (!h.out) h,
  ];
  final area = outline.isEmpty ? 0.0 : plateOutlineArea(outline);
  final holeArea = [...cutHoles, ...cutouts].fold(0.0, (s, h) => s + h.area);
  double segLen(PlateSeg e) => switch (e) {
    PlateLine(:final a, :final b) => (b - a).distance,
    PlateArc(:final r, :final sweep) => r * _rad(sweep.abs()),
  };
  double holeLen(PlateHole h) =>
      h.slot > h.dia ? 2 * (h.slot - h.dia) + math.pi * h.dia : math.pi * h.dia;
  final cutLen =
      outline.fold(0.0, (s, e) => s + segLen(e)) +
      [...cutHoles, ...cutouts].fold(0.0, (s, h) => s + holeLen(h));
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
    cutouts: cutouts,
    cutLength: cutLen,
    vertices: verts,
    cornerMarks: marks,
    pierces: (outline.isEmpty ? 0 : 1) + cutHoles.length + cutouts.length,
  );
}

/// 원판 한 장에 부품을 줄 맞춰 놓은 결과: 개수, 부품 자리(원판 왼쪽 아래 (0, 0) 기준), 사용률(부품 넓이 합 ÷ 원판 넓이).
class PlateNest {
  final int count;
  final List<Rect> parts;
  final double usage;
  const PlateNest(this.count, this.parts, this.usage);
}

/// 원판 [sheetW]×[sheetH]에 부품(외곽 상자 [w]×[h])을 간격 [gap]·가장자리 여유 [margin]으로 줄 맞춰 놓는다.
/// 바로·돌려 놓기, 한쪽을 놓고 남는 띠에 돌려 채우기까지 따져 가장 많이 나오는 것을 고른다(외곽 상자 기준이라
/// ㄱ·삼각 같은 모양은 실제 네스팅보다 적게 나온다). [partArea]는 사용률 계산용 부품 실제 넓이.
PlateNest plateNest({
  required double sheetW,
  required double sheetH,
  required double w,
  required double h,
  double gap = 5,
  double margin = 10,
  double partArea = 0,
}) {
  final aw = sheetW - 2 * margin, ah = sheetH - 2 * margin;
  if (w <= 0 || h <= 0 || aw <= 0 || ah <= 0) return const PlateNest(0, [], 0);
  List<Rect> grid(
    double x0,
    double y0,
    double gw,
    double gh,
    double pw,
    double ph,
  ) {
    final cols = ((gw + gap) / (pw + gap) + 1e-9).floor();
    final rows = ((gh + gap) / (ph + gap) + 1e-9).floor();
    if (cols <= 0 || rows <= 0) return const [];
    return [
      for (var r = 0; r < rows; r++)
        for (var c = 0; c < cols; c++)
          Rect.fromLTWH(x0 + c * (pw + gap), y0 + r * (ph + gap), pw, ph),
    ];
  }

  var best = <Rect>[];
  void take(List<Rect> l) {
    if (l.length > best.length) best = l;
  }

  for (final (pw, ph) in [(w, h), (h, w)]) {
    take(grid(margin, margin, aw, ah, pw, ph));
    // 앞쪽 n열은 이 방향, 남는 가로 띠는 돌려서
    final cols = ((aw + gap) / (pw + gap) + 1e-9).floor();
    for (var n = 1; n < cols; n++) {
      final used = n * (pw + gap);
      take([
        ...grid(margin, margin, used - gap, ah, pw, ph),
        ...grid(margin + used, margin, aw - used, ah, ph, pw),
      ]);
    }
    // 아래 n줄은 이 방향, 남는 세로 띠는 돌려서
    final rows = ((ah + gap) / (ph + gap) + 1e-9).floor();
    for (var n = 1; n < rows; n++) {
      final used = n * (ph + gap);
      take([
        ...grid(margin, margin, aw, used - gap, pw, ph),
        ...grid(margin, margin + used, aw, ah - used, ph, pw),
      ]);
    }
  }
  final a = partArea > 0 ? partArea : w * h;
  return PlateNest(best.length, best, best.length * a / (sheetW * sheetH));
}

/// 구멍 모양 글: "φ13.5", "장공 11×30(가로)", "장공 11×30(45°)".
String plateHoleKind(PlateHole h) {
  if (h.slot <= 0) return 'φ${_f2(h.dia)}';
  final a = ((h.angle % 180) + 180) % 180;
  final dir = a.abs() < 1e-6
      ? '가로'
      : ((a - 90).abs() < 1e-6 ? '세로' : '${_f(a)}°');
  return '장공 ${_f2(h.dia)}×${_f2(h.slot)}($dir)';
}

/// 평판 네 귀 이름(차례: 왼쪽 아래 → 오른쪽 아래 → 오른쪽 위 → 왼쪽 위).
const List<String> kPlateCornerNames = ['왼쪽 아래', '오른쪽 아래', '오른쪽 위', '왼쪽 위'];

/// 넓이 글(점검 32, 10-11): 1m² 아래는 cm²("123 cm²", 100 아래는 소수 한 자리), 그 위는 m² 소수 둘째.
/// 예전에는 "0.0123 m²"로 읽기 어려웠다.
String plateAreaText(double mm2) {
  final cm2 = mm2 / 100;
  if (cm2.round() >= 10000) return '${(mm2 / 1e6).toStringAsFixed(2)} m²';
  if (cm2 < 100) return '${_f(cm2)} cm²';
  final s = cm2.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '$b cm²';
}

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

/// 꼭짓점과 처리를 "x,y[,r10]" 줄 글로(자유 모양 칸에 넣는 글). 소수 둘째 자리까지(코너를 고치거나
/// 표를 오갈 때 넣은 15.25가 15.3으로 바뀌지 않게, 10-11).
String platePointsText(List<Offset> pts, List<PlateCorner> corners) => [
  for (var i = 0; i < pts.length; i++)
    () {
      final c = i < corners.length ? corners[i].token : '';
      return '${_f2(pts[i].dx)},${_f2(pts[i].dy)}${c.isEmpty ? '' : ',$c'}';
    }(),
].join('\n');

String _f2(double v) {
  var s = v.toStringAsFixed(2);
  while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
    s = s.substring(0, s.length - 1);
  }
  return s == '-0' ? '0' : s;
}
