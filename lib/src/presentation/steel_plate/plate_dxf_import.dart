// 철판 DXF 불러오기(10-10, 상용 레이저 주문 앱처럼 "도면 파일 올려 시작"): 레이저 업체용 DXF에서
// 바깥 외곽(가장 큰 닫힌 고리)은 좌표 입력 꼭짓점으로(접하는 원호는 코너 R, 직각 사이 짧은 45° 선은 코너 C),
// 원은 홀, 반원 둘 + 직선 둘은 장공으로 읽는다. 바깥이 원이면 원형, 가운데 같은 중심 원이 있으면 링.
// CUT 층이 있으면 그 층만 읽는다(이 앱이 만든 DXF의 센터선·절곡선·글은 다른 층). 단위는 mm로 본다.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'plate_calc.dart';

/// 불러온 결과.
class PlateDxfImport {
  final PlateShape shape; // free · circle · ring
  final List<Offset> points;
  final List<PlateCorner> corners;
  final double dia, innerDia;
  final List<PlateHoleSpec> holes;

  /// 읽지 못한 안쪽 모양(원·장공이 아닌 따냄) 수.
  final int skipped;
  final List<String> notes;

  const PlateDxfImport({
    required this.shape,
    this.points = const [],
    this.corners = const [],
    this.dia = 0,
    this.innerDia = 0,
    this.holes = const [],
    this.skipped = 0,
    this.notes = const [],
  });
}

/// 직선 또는 원호 한 토막(a → b). 원호는 가운데 [c]·반지름 [r]·[ccw](반시계면 true).
class _Prim {
  Offset a, b;
  final Offset? c;
  final double r;
  bool ccw;
  _Prim.line(this.a, this.b) : c = null, r = 0, ccw = true;
  _Prim.arc(this.a, this.b, Offset this.c, this.r, this.ccw);

  bool get isArc => c != null;

  void flip() {
    final t = a;
    a = b;
    b = t;
    ccw = !ccw;
  }

  /// 원호가 쓸어 가는 각(라디안, 0~2π).
  double get sweep {
    if (!isArc) return 0;
    final a0 = math.atan2(a.dy - c!.dy, a.dx - c!.dx);
    final a1 = math.atan2(b.dy - c!.dy, b.dx - c!.dx);
    var s = ccw ? a1 - a0 : a0 - a1;
    while (s <= 1e-9) {
      s += 2 * math.pi;
    }
    return s;
  }

  /// 시작·끝에서의 진행 방향(단위).
  Offset dirAt(bool start) {
    if (!isArc) {
      final d = b - a;
      return d / d.distance;
    }
    final p = start ? a : b;
    final v = p - c!;
    final t = ccw ? Offset(-v.dy, v.dx) : Offset(v.dy, -v.dx);
    return t / t.distance;
  }

  /// 원호를 점들로(끝점 b는 빼고).
  List<Offset> points(double stepRad) {
    if (!isArc) return [a];
    final a0 = math.atan2(a.dy - c!.dy, a.dx - c!.dx);
    final sw = sweep;
    final n = math.max(2, (sw / stepRad).ceil());
    return [
      for (var k = 0; k < n; k++)
        () {
          final t = a0 + (ccw ? 1 : -1) * sw * k / n;
          return c! + Offset(math.cos(t), math.sin(t)) * r;
        }(),
    ];
  }
}

class _Ent {
  final String type;
  final List<(int, String)> pairs = [];
  _Ent(this.type);

  String? str(int code) {
    for (final p in pairs) {
      if (p.$1 == code) return p.$2.trim();
    }
    return null;
  }

  double num(int code, [double def = 0]) =>
      double.tryParse(str(code) ?? '') ?? def;
}

double _deg(double r) => r * 180 / math.pi;

/// 볼록(bulge) 있는 폴리선 한 칸 → 원호.
_Prim _bulge(Offset p, Offset q, double bulge) {
  if (bulge.abs() < 1e-9) return _Prim.line(p, q);
  final d = q - p;
  final chord = d.distance;
  if (chord < 1e-12) return _Prim.line(p, q);
  final theta = 4 * math.atan(bulge); // + 반시계
  final r = chord / (2 * math.sin(theta / 2));
  final m = (p + q) / 2;
  final n = Offset(-d.dy, d.dx) / chord;
  final c = m + n * (r * math.cos(theta / 2));
  return _Prim.arc(p, q, c, r.abs(), theta > 0);
}

/// DXF 글을 읽는다. 읽을 외곽이 없으면 [FormatException](이유는 한글).
PlateDxfImport importPlateDxf(String text) {
  final lines = text.split(RegExp(r'\r?\n'));
  final pairs = <(int, String)>[];
  for (var k = 0; k + 1 < lines.length; k += 2) {
    final code = int.tryParse(lines[k].trim());
    if (code == null) continue;
    pairs.add((code, lines[k + 1]));
  }
  // ENTITIES 구역의 요소들
  final ents = <_Ent>[];
  var inEnt = false;
  _Ent? cur;
  for (var k = 0; k < pairs.length; k++) {
    final (code, v) = pairs[k];
    final val = v.trim();
    if (code == 0 && val == 'SECTION') {
      final next = k + 1 < pairs.length ? pairs[k + 1] : null;
      inEnt = next != null && next.$1 == 2 && next.$2.trim() == 'ENTITIES';
      cur = null;
      continue;
    }
    if (!inEnt) continue;
    if (code == 0) {
      if (val == 'ENDSEC') {
        inEnt = false;
        cur = null;
        continue;
      }
      cur = _Ent(val);
      ents.add(cur);
    } else {
      cur?.pairs.add((code, v));
    }
  }
  if (ents.isEmpty) throw const FormatException('DXF에서 도형을 찾지 못했습니다.');
  final notes = <String>[];
  if (ents.any((e) => e.type == 'INSERT')) {
    notes.add('블록(INSERT)은 읽지 않았습니다. 업체에 블록을 풀어(분해) 달라고 하십시오.');
  }

  // CUT 층이 있으면 그 층만
  final hasCut = ents.any((e) => (e.str(8) ?? '').toUpperCase() == 'CUT');
  bool use(_Ent e) => !hasCut || (e.str(8) ?? '').toUpperCase() == 'CUT';

  final prims = <_Prim>[];
  final circles = <(Offset, double)>[];
  for (var k = 0; k < ents.length; k++) {
    final e = ents[k];
    if (!use(e) && e.type != 'VERTEX' && e.type != 'SEQEND') continue;
    switch (e.type) {
      case 'LINE':
        final a = Offset(e.num(10), e.num(20)),
            b = Offset(e.num(11), e.num(21));
        if ((b - a).distance > 1e-9) prims.add(_Prim.line(a, b));
      case 'CIRCLE':
        final r = e.num(40);
        if (r > 0) circles.add((Offset(e.num(10), e.num(20)), r));
      case 'ARC':
        final c = Offset(e.num(10), e.num(20));
        final r = e.num(40);
        final a0 = e.num(50) * math.pi / 180, a1 = e.num(51) * math.pi / 180;
        if (r > 0) {
          prims.add(
            _Prim.arc(
              c + Offset(math.cos(a0), math.sin(a0)) * r,
              c + Offset(math.cos(a1), math.sin(a1)) * r,
              c,
              r,
              true,
            ),
          );
        }
      case 'LWPOLYLINE':
        final pts = <Offset>[];
        final bul = <double>[];
        double? x;
        for (final (code, v) in e.pairs) {
          final d = double.tryParse(v.trim()) ?? 0;
          if (code == 10) {
            x = d;
          } else if (code == 20 && x != null) {
            pts.add(Offset(x, d));
            bul.add(0);
            x = null;
          } else if (code == 42 && bul.isNotEmpty) {
            bul[bul.length - 1] = d;
          }
        }
        final closed = ((int.tryParse(e.str(70) ?? '') ?? 0) & 1) == 1;
        final n = closed ? pts.length : pts.length - 1;
        for (var s = 0; s < n; s++) {
          final p = pts[s], q = pts[(s + 1) % pts.length];
          if ((q - p).distance > 1e-9) prims.add(_bulge(p, q, bul[s]));
        }
      case 'POLYLINE':
        if (!use(e)) break;
        final closed = ((int.tryParse(e.str(70) ?? '') ?? 0) & 1) == 1;
        final pts = <Offset>[];
        final bul = <double>[];
        var m = k + 1;
        while (m < ents.length && ents[m].type == 'VERTEX') {
          pts.add(Offset(ents[m].num(10), ents[m].num(20)));
          bul.add(ents[m].num(42));
          m++;
        }
        k = m < ents.length && ents[m].type == 'SEQEND' ? m : m - 1;
        final n = closed ? pts.length : pts.length - 1;
        for (var s = 0; s < n; s++) {
          final p = pts[s], q = pts[(s + 1) % pts.length];
          if ((q - p).distance > 1e-9) prims.add(_bulge(p, q, bul[s]));
        }
    }
  }

  // 토막을 이어 닫힌 고리로
  var span = 0.0;
  for (final p in prims) {
    span = math.max(span, math.max(p.a.distance, p.b.distance));
  }
  for (final (c, r) in circles) {
    span = math.max(span, c.distance + r);
  }
  final tol = math.max(0.02, span * 1e-6);
  final used = List.filled(prims.length, false);
  final loops = <List<_Prim>>[];
  for (var s = 0; s < prims.length; s++) {
    if (used[s]) continue;
    used[s] = true;
    final loop = [prims[s]];
    final start = prims[s].a;
    var end = prims[s].b;
    var closed = (end - start).distance < tol;
    while (!closed) {
      var found = -1;
      for (var q = 0; q < prims.length; q++) {
        if (used[q]) continue;
        if ((prims[q].a - end).distance < tol) {
          found = q;
          break;
        }
        if ((prims[q].b - end).distance < tol) {
          prims[q].flip();
          found = q;
          break;
        }
      }
      if (found < 0) break;
      used[found] = true;
      loop.add(prims[found]);
      end = prims[found].b;
      closed = (end - start).distance < tol;
    }
    if (closed) loops.add(loop);
  }

  // 고리 → 원·장공·다각형
  (Offset, double)? asCircle(List<_Prim> l) {
    if (l.isEmpty || l.any((p) => !p.isArc)) return null;
    final c = l.first.c!, r = l.first.r;
    if (l.any((p) => (p.c! - c).distance > tol || (p.r - r).abs() > tol)) {
      return null;
    }
    final total = l.fold(0.0, (s, p) => s + p.sweep);
    return (total - 2 * math.pi).abs() < 0.01 ? (c, r) : null;
  }

  PlateHoleSpec? asSlot(List<_Prim> l) {
    if (l.length != 4) return null;
    final arcs = l.where((p) => p.isArc).toList();
    final ls = l.where((p) => !p.isArc).toList();
    if (arcs.length != 2 || ls.length != 2) return null;
    if ((arcs[0].r - arcs[1].r).abs() > tol) return null;
    if (arcs.any((a) => (a.sweep - math.pi).abs() > 0.02)) return null;
    final c1 = arcs[0].c!, c2 = arcs[1].c!;
    final r = arcs[0].r;
    final len = (c2 - c1).distance;
    if (len < tol) return null;
    final mid = (c1 + c2) / 2;
    var ang = _deg(math.atan2(c2.dy - c1.dy, c2.dx - c1.dx));
    ang = ((ang % 180) + 180) % 180;
    if ((ang - 180).abs() < 1e-6) ang = 0;
    return PlateHoleSpec(
      u: mid.dx,
      v: mid.dy,
      dia: 2 * r,
      slot: len + 2 * r,
      angle: double.parse(ang.toStringAsFixed(2)),
    );
  }

  Rect boxOf(List<Offset> pts) {
    var l = double.infinity, b = double.infinity;
    var r = -double.infinity, t = -double.infinity;
    for (final p in pts) {
      l = math.min(l, p.dx);
      r = math.max(r, p.dx);
      b = math.min(b, p.dy);
      t = math.max(t, p.dy);
    }
    return Rect.fromLTRB(l, b, r, t);
  }

  // 가장 큰 닫힌 모양이 바깥(고리 또는 원)
  final loopPts = [
    for (final l in loops) l.expand((p) => p.points(0.2)).toList(),
  ];
  final loopBox = [for (final p in loopPts) boxOf(p)];
  double areaOf(Rect r) => r.width * r.height;
  var outerLoop = -1;
  var outerArea = 0.0;
  for (var k = 0; k < loops.length; k++) {
    if (areaOf(loopBox[k]) > outerArea) {
      outerArea = areaOf(loopBox[k]);
      outerLoop = k;
    }
  }
  var outerCircle = -1;
  for (var k = 0; k < circles.length; k++) {
    final d = 2 * circles[k].$2;
    if (d * d > outerArea) {
      outerArea = d * d;
      outerCircle = k;
      outerLoop = -1;
    }
  }
  // 바깥 고리가 사실 원(원호 토막들)이면 원으로
  if (outerLoop >= 0) {
    final c = asCircle(loops[outerLoop]);
    if (c != null) {
      circles.add(c);
      outerCircle = circles.length - 1;
      loops.removeAt(outerLoop);
      loopPts.removeAt(outerLoop);
      loopBox.removeAt(outerLoop);
      outerLoop = -1;
    }
  }
  if (outerLoop < 0 && outerCircle < 0) {
    throw const FormatException(
      'DXF에서 닫힌 외곽을 찾지 못했습니다. 외곽선이 끊겨 있지 않은지 확인하십시오.',
    );
  }

  final holes = <PlateHoleSpec>[];
  var skipped = 0;
  late Rect outerBox;
  List<Offset> pts = const [];
  List<PlateCorner> corners = const [];
  var shape = PlateShape.free;
  var dia = 0.0, innerDia = 0.0;

  bool insideOuter(Offset q) {
    if (outerLoop >= 0) return _inPoly(q, loopPts[outerLoop]);
    final (c, r) = circles[outerCircle];
    return (q - c).distance < r - 1e-9;
  }

  if (outerLoop >= 0) {
    (pts, corners) = _vertices(loops[outerLoop], tol);
    outerBox = boxOf(loopPts[outerLoop]);
  } else {
    final (c, r) = circles[outerCircle];
    shape = PlateShape.circle;
    dia = 2 * r;
    outerBox = Rect.fromCircle(center: c, radius: r);
    // 같은 가운데의 가장 큰 안쪽 원 → 링 내경
    var best = -1;
    for (var k = 0; k < circles.length; k++) {
      if (k == outerCircle) continue;
      if ((circles[k].$1 - c).distance < tol && circles[k].$2 < r) {
        if (best < 0 || circles[k].$2 > circles[best].$2) best = k;
      }
    }
    if (best >= 0) {
      shape = PlateShape.ring;
      innerDia = 2 * circles[best].$2;
      circles.removeAt(best);
      if (best < outerCircle) outerCircle--;
    }
  }

  for (var k = 0; k < circles.length; k++) {
    if (k == outerCircle) continue;
    final (c, r) = circles[k];
    if (!insideOuter(c)) continue;
    holes.add(PlateHoleSpec(u: c.dx, v: c.dy, dia: 2 * r));
  }
  for (var k = 0; k < loops.length; k++) {
    if (k == outerLoop) continue;
    final ctr = loopBox[k].center;
    if (!insideOuter(ctr)) continue;
    final c = asCircle(loops[k]);
    if (c != null) {
      holes.add(PlateHoleSpec(u: c.$1.dx, v: c.$1.dy, dia: 2 * c.$2));
      continue;
    }
    final sl = asSlot(loops[k]);
    if (sl != null) {
      holes.add(sl);
      continue;
    }
    skipped++;
  }
  if (skipped > 0) {
    notes.add(
      '원·장공이 아닌 안쪽 따냄 $skipped곳은 읽지 못했습니다. 홀 탭에서 넣거나 업체 DXF를 그대로 보내십시오.',
    );
  }
  if (outerBox.width > 20000 || outerBox.height > 20000) {
    notes.add('크기가 너무 큽니다. DXF 단위가 mm인지 확인하십시오.');
  }

  // 왼쪽 아래를 (0, 0)으로
  final o = outerBox.topLeft; // Rect: top = 가장 작은 y
  double r1(double v) => double.parse(v.toStringAsFixed(2));
  Offset sh(Offset p) => Offset(r1(p.dx - o.dx), r1(p.dy - o.dy));
  return PlateDxfImport(
    shape: shape,
    points: [for (final p in pts) sh(p)],
    corners: corners,
    dia: r1(dia),
    innerDia: r1(innerDia),
    holes: [
      for (final h in holes)
        h.copyWith(
          u: r1(h.u - o.dx),
          v: r1(h.v - o.dy),
          dia: r1(h.dia),
          slot: r1(h.slot),
        ),
    ],
    skipped: skipped,
    notes: notes,
  );
}

bool _inPoly(Offset p, List<Offset> poly) {
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

/// 두 직선(점·방향)의 만나는 점(평행이면 null).
Offset? _meet(Offset p, Offset d, Offset q, Offset e) {
  final den = d.dx * e.dy - d.dy * e.dx;
  if (den.abs() < 1e-12) return null;
  final t = ((q.dx - p.dx) * e.dy - (q.dy - p.dy) * e.dx) / den;
  return p + d * t;
}

/// 바깥 고리 → 꼭짓점·코너 처리. 앞뒤 직선에 접하는 원호는 코너 R(꼭짓점은 두 직선이 만나는 자리),
/// 서로 직각인 두 직선 사이 짧은 45° 직선은 코너 C, 나머지 원호는 잘게 나눈 꼭짓점.
(List<Offset>, List<PlateCorner>) _vertices(List<_Prim> l, double tol) {
  final n = l.length;
  _Prim at(int i) => l[(i % n + n) % n];
  bool tangent(Offset u, Offset v) =>
      (u.dx * v.dx + u.dy * v.dy) > math.cos(2 * math.pi / 180);

  final kind = List<String>.filled(n, ''); // 'R' 필렛, 'C' 모따기
  for (var i = 0; i < n; i++) {
    final p = at(i - 1), q = at(i), r = at(i + 1);
    if (p.isArc || r.isArc) continue;
    if (q.isArc) {
      if (tangent(p.dirAt(false), q.dirAt(true)) &&
          tangent(q.dirAt(false), r.dirAt(true)) &&
          q.sweep < math.pi - 1e-3) {
        kind[i] = 'R';
      }
      continue;
    }
    // 모따기: 앞뒤 직선이 서로 직각, 이 직선은 짧고 둘 다와 45°
    final dp = p.dirAt(true), dq = q.dirAt(true), dr = r.dirAt(true);
    final perp =
        (dp.dx * dr.dx + dp.dy * dr.dy).abs() < math.sin(1 * math.pi / 180);
    final c45 = math.cos(math.pi / 4);
    final ang1 = (dp.dx * dq.dx + dp.dy * dq.dy - c45).abs() < 0.02;
    final ang2 = (dq.dx * dr.dx + dq.dy * dr.dy - c45).abs() < 0.02;
    final short =
        (q.b - q.a).distance <
        0.5 * math.min((p.b - p.a).distance, (r.b - r.a).distance);
    if (perp && ang1 && ang2 && short) kind[i] = 'C';
  }
  // 모따기·필렛이 서로 붙어 있으면(앞뒤가 직선이 아님) 위에서 걸러졌다.
  final pts = <Offset>[];
  final cs = <PlateCorner>[];
  for (var i = 0; i < n; i++) {
    final q = at(i);
    if (kind[i] == 'R' || kind[i] == 'C') {
      final p = at(i - 1), r = at(i + 1);
      final x = _meet(p.a, p.dirAt(true), r.a, r.dirAt(true));
      if (x == null) {
        pts.add(q.a);
        cs.add(PlateCorner.square);
        continue;
      }
      pts.add(x);
      cs.add(
        kind[i] == 'R'
            ? PlateCorner(
                PlateCornerKind.round,
                double.parse(q.r.toStringAsFixed(2)),
              )
            : PlateCorner(
                PlateCornerKind.chamfer,
                double.parse((q.a - x).distance.toStringAsFixed(2)),
              ),
      );
      continue;
    }
    // 앞 토막이 필렛·모따기면 이 토막 시작점은 그 끝(접점)이라 넣지 않는다
    final prevKind = kind[(i - 1 + n) % n];
    if (!q.isArc) {
      if (prevKind.isEmpty) {
        pts.add(q.a);
        cs.add(PlateCorner.square);
      }
      continue;
    }
    final ps = q.points(10 * math.pi / 180);
    for (var k = 0; k < ps.length; k++) {
      if (k == 0 && prevKind.isNotEmpty) continue;
      pts.add(ps[k]);
      cs.add(PlateCorner.square);
    }
  }
  // 한 줄 위에 있는 군더더기 꼭짓점 빼기
  var changed = true;
  while (changed && pts.length > 3) {
    changed = false;
    for (var i = 0; i < pts.length; i++) {
      if (!cs[i].isNone) continue;
      final a = pts[(i - 1 + pts.length) % pts.length], b = pts[i];
      final c = pts[(i + 1) % pts.length];
      final ab = b - a, bc = c - b;
      final cr = (ab.dx * bc.dy - ab.dy * bc.dx).abs();
      if (ab.distance < tol || cr < tol * math.max(ab.distance, bc.distance)) {
        pts.removeAt(i);
        cs.removeAt(i);
        changed = true;
        break;
      }
    }
  }
  return (pts, cs);
}
