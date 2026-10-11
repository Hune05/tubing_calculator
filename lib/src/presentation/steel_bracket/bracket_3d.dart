// 형강 브라켓 입체 보기(10-11, 상용 앱 비교 19번): 부재마다 단면 조각(직사각형)을 부재 길이 방향으로 밀어 상자를 만들고
// (끝을 비스듬히 자른 것도 그대로), 판·리브·너트를 더한다. 철판 가공의 입체 보기(Plate3dView)가 돌려 보여 준다.
//  · 좌표: 그림 x → 입체 x, 그림 깊이 z → 입체 y, 그림 y(아래로) → 입체 z(위로, 부호 바꿈).
//  · 구멍은 그리지 않는다(앵글 방향·부재 자리 확인용).
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:vector_math/vector_math_64.dart' as vm;

import '../steel_plate/plate_3d.dart' show Plate3dFace;
import 'bracket_calc.dart';

vm.Vector3 _v(Offset p, double z) => vm.Vector3(p.dx, z, -p.dy);

/// 점 여덟 개 상자(두 고리 [a]·[b]가 마주 보는 면)를 면 여섯으로.
List<Plate3dFace> _prism(List<vm.Vector3> a, List<vm.Vector3> b, int kind) {
  final c = vm.Vector3.zero();
  for (final q in [...a, ...b]) {
    c.add(q);
  }
  c.scale(1 / (a.length + b.length));
  final faces = <Plate3dFace>[];
  void face(List<vm.Vector3> loop) {
    if (loop.length < 3) return;
    var n = (loop[1] - loop[0]).cross(loop[2] - loop[0]);
    if (n.length2 < 1e-18 && loop.length > 3) {
      n = (loop[2] - loop[0]).cross(loop[3] - loop[0]);
    }
    if (n.length2 < 1e-18) return;
    n.normalize();
    final fc = vm.Vector3.zero();
    for (final q in loop) {
      fc.add(q);
    }
    fc.scale(1 / loop.length);
    if (n.dot(fc - c) < 0) n.negate();
    faces.add(Plate3dFace(loop, n, kind: kind));
  }

  face(a);
  face(b.reversed.toList());
  final n = a.length;
  for (var k = 0; k < n; k++) {
    final k2 = (k + 1) % n;
    face([a[k], a[k2], b[k2], b[k]]);
  }
  return faces;
}

/// 브라켓 입체 면들.
List<Plate3dFace> bracket3dMesh(BracketPlan plan) {
  final out = <Plate3dFace>[];
  final i = plan.input;
  for (final m in plan.members) {
    final d = m.depth;
    if (d <= 0) continue;
    (double, double) span(double u) =>
        bracketSpanAt(
          m.local,
          u.clamp(math.min(1e-6, d / 2), d - math.min(1e-6, d / 2)),
        ) ??
        (0, 0);
    if (m.view.round) {
      // 전산볼트: 팔각 기둥, 가로대 게이지 자리
      final arm = plan.members.where((x) => x.name == '가로대');
      final zc = arm.isEmpty ? d / 2 : arm.first.view.gauge;
      final (x0, x1) = span(d / 2);
      final ring0 = <vm.Vector3>[], ring1 = <vm.Vector3>[];
      for (var k = 0; k < 8; k++) {
        final a = k * math.pi / 4;
        final du = d / 2 + d / 2 * math.cos(a), dz = d / 2 * math.sin(a);
        ring0.add(_v(m.at(x0, du), zc + dz));
        ring1.add(_v(m.at(x1, du), zc + dz));
      }
      out.addAll(_prism(ring0, ring1, 2));
      continue;
    }
    for (final Rect r in m.view.rects) {
      final u0 = r.left, u1 = r.right, z0 = r.top, z1 = r.bottom;
      final (s0, e0) = span(u0);
      final (s1, e1) = span(u1);
      // 길이 방향 양 끝 고리(끝면): 시작 쪽 [a], 끝 쪽 [b]
      final a = [
        _v(m.at(s0, u0), z0),
        _v(m.at(s1, u1), z0),
        _v(m.at(s1, u1), z1),
        _v(m.at(s0, u0), z1),
      ];
      final b = [
        _v(m.at(e0, u0), z0),
        _v(m.at(e1, u1), z0),
        _v(m.at(e1, u1), z1),
        _v(m.at(e0, u0), z1),
      ];
      out.addAll(_prism(a, b, 0));
    }
  }
  // 판·리브
  final pl = plan.plate;
  BracketMember? post;
  for (final m in plan.members) {
    if (m.name == '기둥') {
      post = m;
      break;
    }
  }
  final bp = post?.view.width ?? 0;
  List<vm.Vector3> box(double x0, double y0, double x1, double y1, double z) =>
      [
        _v(Offset(x0, y0), z),
        _v(Offset(x1, y0), z),
        _v(Offset(x1, y1), z),
        _v(Offset(x0, y1), z),
      ];
  if (pl != null && post != null) {
    if (pl.wall) {
      final zc = bp / 2;
      out.addAll(
        _prism(
          box(0, 0, pl.t, pl.l, zc - pl.w / 2),
          box(0, 0, pl.t, pl.l, zc + pl.w / 2),
          1,
        ),
      );
    } else {
      final h = i.b, tp = pl.t;
      final zc = bp / 2;
      final posts = plan.members.where((m) => m.name == '기둥');
      for (final m in posts) {
        final xs = m.poly.map((q) => q.dx);
        final x0 = xs.reduce(math.min), x1 = xs.reduce(math.max);
        final cx = (x0 + x1) / 2;
        out.addAll(
          _prism(
            box(cx - pl.w / 2, h - tp, cx + pl.w / 2, h, zc - pl.l / 2),
            box(cx - pl.w / 2, h - tp, cx + pl.w / 2, h, zc + pl.l / 2),
            1,
          ),
        );
        final rb = i.base;
        if (rb.ribs > 0) {
          for (final s in [-1.0, 1.0]) {
            final fx = s < 0 ? x0 : x1;
            List<vm.Vector3> tri(double z) => [
              _v(Offset(fx, h - tp), z),
              _v(Offset(fx + s * rb.ribL, h - tp), z),
              _v(Offset(fx, h - tp - rb.ribH), z),
            ];
            out.addAll(_prism(tri(zc - rb.ribT / 2), tri(zc + rb.ribT / 2), 1));
          }
          if (rb.ribs == 4) {
            for (final s in [-1.0, 1.0]) {
              final fz = s < 0 ? zc - bp / 2 : zc + bp / 2;
              List<vm.Vector3> tri(double x) => [
                vm.Vector3(x, fz, -(h - tp)),
                vm.Vector3(x, fz + s * rb.ribL, -(h - tp)),
                vm.Vector3(x, fz, -(h - tp - rb.ribH)),
              ];
              out.addAll(
                _prism(tri(cx - rb.ribT / 2), tri(cx + rb.ribT / 2), 1),
              );
            }
          }
        }
      }
    }
  }
  // 매달기 너트(그림의 너트 칸을 그대로 두께 있게)
  if (i.shape == BracketShape.hanger) {
    final arm = plan.members.where((x) => x.name == '가로대');
    final zc = arm.isEmpty ? 0.0 : arm.first.view.gauge;
    for (final p in plan.drawing.polys) {
      if (p.fill != BracketFill.nut) continue;
      final xs = p.pts.map((q) => q.dx), ys = p.pts.map((q) => q.dy);
      final x0 = xs.reduce(math.min), x1 = xs.reduce(math.max);
      final y0 = ys.reduce(math.min), y1 = ys.reduce(math.max);
      final hw = (x1 - x0) / 2;
      out.addAll(
        _prism(box(x0, y0, x1, y1, zc - hw), box(x0, y0, x1, y1, zc + hw), 2),
      );
    }
  }
  return out;
}
