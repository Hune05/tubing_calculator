// 철판 입체(3D) 모양 만들기(10-10, 사용자: "탭에 만들어진 결과물을 3D로 돌려 볼 수 있는 걸 만들자").
// 전개도(plate_calc.dart의 PlatePlan)를 두께만큼 세운 면들로 바꾼다. 꺾는 판은 꺾기선마다 그 각도로 접는다
// (꺾는 부분은 원호를 몇 토막으로). 구멍·장공은 앞뒤 면에 뚫린 자리와 구멍 벽으로 만든다.
// 좌표: x = 전개도 길이 방향, y = 폭(전개도 세로), z = 판 두께·꺾어 올라가는 쪽. 단위 mm. 화면 그리기는 plate_3d_view.dart.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:vector_math/vector_math_64.dart' as vm;

import 'plate_calc.dart';

/// 입체 면 하나: 바깥 고리 [loop](차례대로), 뚫린 자리 [holes], 바깥쪽을 향한 [normal]. [kind]: 0 큰 면, 1 옆면, 2 구멍 벽.
class Plate3dFace {
  final List<vm.Vector3> loop;
  final List<List<vm.Vector3>> holes;
  final vm.Vector3 normal;
  final int kind;
  const Plate3dFace(
    this.loop,
    this.normal, {
    this.holes = const [],
    this.kind = 0,
  });
}

/// 구멍(둥근 구멍·장공) 둘레 점들(전개도 평면, 반시계).
List<Offset> plateHoleLoop(PlateHole h, {int seg = 24}) {
  if (h.slot <= h.dia) {
    return [
      for (var k = 0; k < seg; k++)
        h.c +
            Offset(
                  math.cos(2 * math.pi * k / seg),
                  math.sin(2 * math.pi * k / seg),
                ) *
                h.r,
    ];
  }
  final a = h.angle * math.pi / 180;
  final half = seg ~/ 2;
  final out = <Offset>[];
  // p2 쪽 반원(-90° → +90°), p1 쪽 반원(+90° → +270°)
  for (var k = 0; k <= half; k++) {
    final t = a - math.pi / 2 + math.pi * k / half;
    out.add(h.p2 + Offset(math.cos(t), math.sin(t)) * h.r);
  }
  for (var k = 0; k <= half; k++) {
    final t = a + math.pi / 2 + math.pi * k / half;
    out.add(h.p1 + Offset(math.cos(t), math.sin(t)) * h.r);
  }
  return out;
}

/// 점이 다각형 안에 있는가(판 밖에 잘못 놓인 구멍은 입체에서 뺀다).
bool _inside(List<Offset> poly, Offset q) {
  var c = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i], b = poly[j];
    if ((a.dy > q.dy) != (b.dy > q.dy) &&
        q.dx < (b.dx - a.dx) * (q.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      c = !c;
    }
  }
  return c;
}

double _area2(List<Offset> p) {
  var s = 0.0;
  for (var i = 0; i < p.length; i++) {
    final a = p[i], b = p[(i + 1) % p.length];
    s += a.dx * b.dy - b.dx * a.dy;
  }
  return s;
}

/// 꺾은 판의 옆모습 한 토막(전개도 x 범위 → 옆모습 평면 (x, z)의 곧은 길 또는 원호).
class _Seg {
  final double x0, x1;
  final Offset p0; // 시작점(옆모습 평면)
  final Offset d0; // 시작 방향(단위)
  final double turn; // 라디안(+ 위로), 0이면 곧은 길
  final double r; // 원호 반경(판 두께 가운데), 0이면 전개도 길이로
  const _Seg(this.x0, this.x1, this.p0, this.d0, this.turn, [this.r = 0]);
}

/// 옆모습 길: 전개도 x → 가운데 면의 자리와 방향(단위).
class _Path {
  final List<_Seg> segs;
  _Path(this.segs);

  (Offset, Offset) at(double x) {
    var s = segs.first;
    for (final g in segs) {
      if (x >= g.x0 - 1e-9) s = g;
    }
    final len = s.x1 - s.x0;
    final f = len < 1e-9
        ? (x >= s.x1 ? 1.0 : 0.0)
        : ((x - s.x0) / len).clamp(0.0, 1.0);
    if (s.turn == 0) return (s.p0 + s.d0 * (f * len), s.d0);
    // 원호: 가운데는 시작점에서 왼쪽(+각) 또는 오른쪽(−각). 반경은 실제 판 두께 가운데
    // (안쪽 반경 + t/2). 전개도 꺾는 길이(중립축)로 반경을 잡으면 바깥 치수가 조금 짧게 나온다
    final r = s.r > 0 ? s.r : len / s.turn.abs();
    final nrm = Offset(-s.d0.dy, s.d0.dx) * (s.turn > 0 ? 1.0 : -1.0);
    final c = s.p0 + nrm * r;
    final th = s.turn * f;
    Offset rot(Offset v) => Offset(
      v.dx * math.cos(th) - v.dy * math.sin(th),
      v.dx * math.sin(th) + v.dy * math.cos(th),
    );
    return (c + rot(s.p0 - c), rot(s.d0));
  }

  /// 원호 토막은 [step]° 안팎으로 나눈 x 자리들(곧은 길은 두 끝만).
  List<double> samples({double step = 15}) {
    final xs = <double>[];
    for (final g in segs) {
      final n = g.turn == 0
          ? 1
          : math.max(2, (g.turn.abs() * 180 / math.pi / step).ceil());
      for (var k = 0; k < n; k++) {
        xs.add(g.x0 + (g.x1 - g.x0) * k / n);
      }
    }
    xs.add(segs.last.x1);
    return xs;
  }
}

_Path _foldPath(PlatePlan p, double rMid) {
  final bends = [...p.bends]..sort((a, b) => a.start.compareTo(b.start));
  final segs = <_Seg>[];
  var x = p.minX;
  var pos = Offset.zero;
  var dir = const Offset(1, 0);
  for (final b in bends) {
    if (b.start > x) {
      segs.add(_Seg(x, b.start, pos, dir, 0));
      pos += dir * (b.start - x);
      x = b.start;
    }
    final th = b.turn * math.pi / 180;
    final s = _Seg(x, b.end, pos, dir, th, rMid);
    segs.add(s);
    final (p1, d1) = _Path([s]).at(b.end);
    pos = p1;
    dir = d1;
    x = b.end;
  }
  segs.add(_Seg(x, math.max(x, p.maxX), pos, dir, 0));
  return _Path(segs);
}

/// 전개도와 두께 [t]로 입체 면들을 만든다.
List<Plate3dFace> plate3dMesh(PlatePlan p, {required double t}) {
  final h = math.max(t, 0.1) / 2;
  final faces = <Plate3dFace>[];
  // 사용자 홀 + 모양에 딸린 안쪽 따냄(링 내경)
  final allHoles = [...p.holes, ...p.cutouts];
  final holeLoops = [for (final hole in allHoles) plateHoleLoop(hole)];

  if (p.bends.isEmpty) {
    // 평판·리브·자유 모양: 외곽을 위아래 면으로, 둘레를 옆면으로, 구멍마다 벽
    var out = plateOutlinePoints(p.outline);
    if (out.length < 3) return faces;
    if (_area2(out) < 0) out = out.reversed.toList();
    vm.Vector3 v(Offset q, double z) => vm.Vector3(q.dx, q.dy, z);
    // 판 밖에 놓인 구멍(빨간 테두리)은 뚫을 판이 없으니 뺀다(허공에 구멍 벽이 뜨고 크기가 커지던 것)
    final loops = [
      for (var k = 0; k < allHoles.length; k++)
        if (_inside(out, allHoles[k].c)) holeLoops[k],
    ];
    final holesTop = [
      for (final l in loops) [for (final q in l) v(q, h)],
    ];
    final holesBot = [
      for (final l in loops) [for (final q in l) v(q, -h)],
    ];
    faces.add(
      Plate3dFace(
        [for (final q in out) v(q, h)],
        vm.Vector3(0, 0, 1),
        holes: holesTop,
      ),
    );
    faces.add(
      Plate3dFace(
        [for (final q in out.reversed) v(q, -h)],
        vm.Vector3(0, 0, -1),
        holes: holesBot,
      ),
    );
    for (var i = 0; i < out.length; i++) {
      final a = out[i], b = out[(i + 1) % out.length];
      final d = b - a;
      if (d.distance < 1e-9) continue;
      final n = vm.Vector3(d.dy, -d.dx, 0)..normalize(); // 반시계 외곽의 바깥쪽
      faces.add(
        Plate3dFace([v(a, -h), v(b, -h), v(b, h), v(a, h)], n, kind: 1),
      );
    }
    for (final l0 in loops) {
      final l = _area2(l0) < 0 ? l0.reversed.toList() : l0;
      for (var i = 0; i < l.length; i++) {
        final a = l[i], b = l[(i + 1) % l.length];
        final d = b - a;
        if (d.distance < 1e-9) continue;
        final n = vm.Vector3(-d.dy, d.dx, 0)..normalize(); // 홀 가운데 쪽
        faces.add(
          Plate3dFace([v(a, -h), v(a, h), v(b, h), v(b, -h)], n, kind: 2),
        );
      }
    }
    return faces;
  }

  // 꺾는 판: 전개도 x를 옆모습 길로 접는다(폭 y는 그대로)
  final path = _foldPath(p, p.rUsed + h);
  vm.Vector3 at(double x, double y, double off) {
    final (pt, d) = path.at(x);
    final n = Offset(-d.dy, d.dx);
    return vm.Vector3(pt.dx + n.dx * off, y, pt.dy + n.dy * off);
  }

  vm.Vector3 nrm(double x, double sign) {
    final (_, d) = path.at(x);
    return vm.Vector3(-d.dy * sign, 0, d.dx * sign);
  }

  final y0 = p.minY, y1 = p.maxY;
  // 직접 절곡의 L·T자처럼 사각이 아닌 판은 외곽을 토막마다 잘라 접는다(10-11)
  final outPts = plateOutlinePoints(p.outline);
  final boxArea = (p.maxX - p.minX) * (p.maxY - p.minY);
  if (outPts.length >= 3 &&
      (_area2(outPts).abs() / 2 - boxArea).abs() > 1e-6 * boxArea + 1e-6) {
    return _foldPolygon(p, path, h, outPts, allHoles, holeLoops, at, nrm);
  }
  // 큰 면: 곧은 토막은 구멍 뚫린 한 면, 원호 토막은 띠 여러 개
  for (final g in path.segs) {
    if (g.turn == 0) {
      final hs = [
        for (var k = 0; k < allHoles.length; k++)
          if (allHoles[k].c.dx > g.x0 &&
              allHoles[k].c.dx < g.x1 &&
              allHoles[k].c.dy > y0 &&
              allHoles[k].c.dy < y1)
            holeLoops[k],
      ];
      for (final s in [1.0, -1.0]) {
        final loop = [
          at(g.x0, y0, s * h),
          at(g.x1, y0, s * h),
          at(g.x1, y1, s * h),
          at(g.x0, y1, s * h),
        ];
        faces.add(
          Plate3dFace(
            s > 0 ? loop : loop.reversed.toList(),
            nrm((g.x0 + g.x1) / 2, s),
            holes: [
              for (final l in hs) [for (final q in l) at(q.dx, q.dy, s * h)],
            ],
          ),
        );
      }
    } else {
      final n = math.max(2, (g.turn.abs() * 180 / math.pi / 15).ceil());
      for (var k = 0; k < n; k++) {
        final xa = g.x0 + (g.x1 - g.x0) * k / n;
        final xb = g.x0 + (g.x1 - g.x0) * (k + 1) / n;
        for (final s in [1.0, -1.0]) {
          final loop = [
            at(xa, y0, s * h),
            at(xb, y0, s * h),
            at(xb, y1, s * h),
            at(xa, y1, s * h),
          ];
          faces.add(
            Plate3dFace(
              s > 0 ? loop : loop.reversed.toList(),
              nrm((xa + xb) / 2, s),
            ),
          );
        }
      }
    }
  }
  // 옆면(폭 양 끝 띠)과 두 끝 막음
  final xs = path.samples();
  for (var i = 0; i + 1 < xs.length; i++) {
    final xa = xs[i], xb = xs[i + 1];
    faces.add(
      Plate3dFace(
        [at(xa, y0, -h), at(xb, y0, -h), at(xb, y0, h), at(xa, y0, h)],
        vm.Vector3(0, -1, 0),
        kind: 1,
      ),
    );
    faces.add(
      Plate3dFace(
        [at(xa, y1, h), at(xb, y1, h), at(xb, y1, -h), at(xa, y1, -h)],
        vm.Vector3(0, 1, 0),
        kind: 1,
      ),
    );
  }
  for (final (x, s) in [(p.minX, -1.0), (p.maxX, 1.0)]) {
    final (_, d) = path.at(x);
    faces.add(
      Plate3dFace(
        [at(x, y0, -h), at(x, y0, h), at(x, y1, h), at(x, y1, -h)],
        vm.Vector3(d.dx * s, 0, d.dy * s),
        kind: 1,
      ),
    );
  }
  // 구멍 벽(곧은 면에 있는 구멍만)
  for (var k = 0; k < allHoles.length; k++) {
    final cx = allHoles[k].c.dx, cy = allHoles[k].c.dy;
    if (cy <= y0 || cy >= y1) continue; // 판 밖
    if (!path.segs.any((g) => g.turn == 0 && cx > g.x0 && cx < g.x1)) continue;
    final l0 = holeLoops[k];
    final l = _area2(l0) < 0 ? l0.reversed.toList() : l0;
    final (_, d) = path.at(cx);
    for (var i = 0; i < l.length; i++) {
      final a = l[i], b = l[(i + 1) % l.length];
      final e = b - a;
      if (e.distance < 1e-9) continue;
      // 구멍 가운데 쪽(전개도 평면) → 입체: 길이 방향은 그 자리 방향 d로
      final inX = -e.dy, inY = e.dx;
      final n = vm.Vector3(d.dx * inX, inY, d.dy * inX)..normalize();
      faces.add(
        Plate3dFace(
          [
            at(a.dx, a.dy, -h),
            at(a.dx, a.dy, h),
            at(b.dx, b.dy, h),
            at(b.dx, b.dy, -h),
          ],
          n,
          kind: 2,
        ),
      );
    }
  }
  return faces;
}

/// 다각형 [poly]를 x 띠 [lo, hi]로 자른다(서덜랜드–호지먼). 3개 미만이면 빈 것.
List<Offset> _clipX(List<Offset> poly, double lo, double hi) {
  Offset cut(Offset a, Offset b, double x) =>
      Offset(x, a.dy + (x - a.dx) / (b.dx - a.dx) * (b.dy - a.dy));
  List<Offset> side(List<Offset> pts, bool Function(Offset) inside, double x) {
    final out = <Offset>[];
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i], b = pts[(i + 1) % pts.length];
      final ia = inside(a), ib = inside(b);
      if (ia) out.add(a);
      if (ia != ib) out.add(cut(a, b, x));
    }
    return out;
  }

  var r = side(poly, (q) => q.dx >= lo - 1e-9, lo);
  if (r.length < 3) return const [];
  r = side(r, (q) => q.dx <= hi + 1e-9, hi);
  return r.length < 3 ? const [] : r;
}

/// 사각이 아닌 꺾는 판: 큰 면은 옆모습 토막마다 외곽을 잘라 접고, 옆면은 외곽 변을 토막 자리에서 나눠 세운다.
List<Plate3dFace> _foldPolygon(
  PlatePlan p,
  _Path path,
  double h,
  List<Offset> out0,
  List<PlateHole> allHoles,
  List<List<Offset>> holeLoops,
  vm.Vector3 Function(double x, double y, double off) at,
  vm.Vector3 Function(double x, double sign) nrm,
) {
  final faces = <Plate3dFace>[];
  final out = _area2(out0) < 0 ? out0.reversed.toList() : out0;
  bool onFlat(int k) =>
      _inside(out, allHoles[k].c) &&
      path.segs.any(
        (g) =>
            g.turn == 0 && allHoles[k].c.dx > g.x0 && allHoles[k].c.dx < g.x1,
      );
  void band(double xa, double xb, List<List<Offset>> hs) {
    final piece = _clipX(out, xa, xb);
    if (piece.isEmpty) return;
    for (final s in [1.0, -1.0]) {
      final loop = [for (final q in piece) at(q.dx, q.dy, s * h)];
      faces.add(
        Plate3dFace(
          s > 0 ? loop : loop.reversed.toList(),
          nrm((xa + xb) / 2, s),
          holes: [
            for (final l in hs) [for (final q in l) at(q.dx, q.dy, s * h)],
          ],
        ),
      );
    }
  }

  for (final g in path.segs) {
    if (g.turn == 0) {
      band(g.x0, g.x1, [
        for (var k = 0; k < allHoles.length; k++)
          if (allHoles[k].c.dx > g.x0 && allHoles[k].c.dx < g.x1 && onFlat(k))
            holeLoops[k],
      ]);
    } else {
      final n = math.max(2, (g.turn.abs() * 180 / math.pi / 15).ceil());
      for (var k = 0; k < n; k++) {
        band(
          g.x0 + (g.x1 - g.x0) * k / n,
          g.x0 + (g.x1 - g.x0) * (k + 1) / n,
          const [],
        );
      }
    }
  }
  // 옆면: 외곽 변마다, 접히는 자리(토막 경계)에서 나눠서
  final xs = path.samples();
  for (var i = 0; i < out.length; i++) {
    final a = out[i], b = out[(i + 1) % out.length];
    final d = b - a;
    if (d.distance < 1e-9) continue;
    final ts = <double>[0, 1];
    for (final x in xs) {
      if ((a.dx - x) * (b.dx - x) < 0) ts.add((x - a.dx) / (b.dx - a.dx));
    }
    ts.sort();
    final o = Offset(d.dy, -d.dx) / d.distance; // 반시계 외곽의 바깥쪽(전개도)
    for (var k = 0; k + 1 < ts.length; k++) {
      final q0 = Offset.lerp(a, b, ts[k])!, q1 = Offset.lerp(a, b, ts[k + 1])!;
      if ((q1 - q0).distance < 1e-9) continue;
      final mid = (q0 + q1) / 2;
      final n3 =
          at(mid.dx + o.dx * 0.01, mid.dy + o.dy * 0.01, 0) -
          at(mid.dx, mid.dy, 0);
      if (n3.length < 1e-12) continue;
      n3.normalize();
      faces.add(
        Plate3dFace(
          [
            at(q0.dx, q0.dy, -h),
            at(q1.dx, q1.dy, -h),
            at(q1.dx, q1.dy, h),
            at(q0.dx, q0.dy, h),
          ],
          n3,
          kind: 1,
        ),
      );
    }
  }
  // 구멍 벽(곧은 면에 있는 구멍만)
  for (var k = 0; k < allHoles.length; k++) {
    if (!onFlat(k)) continue;
    final cx = allHoles[k].c.dx;
    final l0 = holeLoops[k];
    final l = _area2(l0) < 0 ? l0.reversed.toList() : l0;
    final (_, d) = path.at(cx);
    for (var i = 0; i < l.length; i++) {
      final a = l[i], b = l[(i + 1) % l.length];
      final e = b - a;
      if (e.distance < 1e-9) continue;
      final inX = -e.dy, inY = e.dx;
      final n = vm.Vector3(d.dx * inX, inY, d.dy * inX)..normalize();
      faces.add(
        Plate3dFace(
          [
            at(a.dx, a.dy, -h),
            at(a.dx, a.dy, h),
            at(b.dx, b.dy, h),
            at(b.dx, b.dy, -h),
          ],
          n,
          kind: 2,
        ),
      );
    }
  }
  return faces;
}

/// 면들을 감싸는 상자(최소·최대).
(vm.Vector3, vm.Vector3) plate3dBounds(List<Plate3dFace> faces) {
  final lo = vm.Vector3.all(double.infinity),
      hi = vm.Vector3.all(-double.infinity);
  for (final f in faces) {
    for (final q in f.loop) {
      lo.x = math.min(lo.x, q.x);
      lo.y = math.min(lo.y, q.y);
      lo.z = math.min(lo.z, q.z);
      hi.x = math.max(hi.x, q.x);
      hi.y = math.max(hi.y, q.y);
      hi.z = math.max(hi.z, q.z);
    }
  }
  return (lo, hi);
}
