// ignore_for_file: library_private_types_in_public_api
// 축 정렬 그림: 참고 그림(은색 주물 펌프, 파란 베어링 브래킷, 고무 커플링, 방열핀 모터, 주물 받침판)과 같은 모양을
// 부품으로 만들어 두고, 세 방향에서 그린다.
//  - 측정 그림: 비스듬히 위에서(참고 그림 각도) + 다이얼 설치 + 재는 거리 ①~④
//  - 옆에서 본 그림: 발 밑 심 판과 위아래 어긋남
//  - 위에서 본 그림: 네 발 심 판과 옆으로 밀 방향
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'alignment_dial_painter.dart';
import 'alignment_guide_painter.dart';
import 'alignment_math.dart';
import 'alignment_scene_painter.dart';

class _V {
  final double x, y, z;
  const _V(this.x, this.y, this.z);
  _V operator +(_V o) => _V(x + o.x, y + o.y, z + o.z);
  _V operator -(_V o) => _V(x - o.x, y - o.y, z - o.z);
  _V operator *(double k) => _V(x * k, y * k, z * k);
  double dot(_V o) => x * o.x + y * o.y + z * o.z;
  _V cross(_V o) => _V(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => math.sqrt(x * x + y * y + z * z);
  _V get unit {
    final l = length;
    return l < 1e-9 ? this : _V(x / l, y / l, z / l);
  }
}

class _Tri {
  final _V a, b, c, na, nb, nc;
  final double r, g, bl, spec;
  const _Tri(this.a, this.b, this.c, this.na, this.nb, this.nc, this.r, this.g, this.bl, this.spec);
}

class _Builder {
  final tris = <_Tri>[];

  void tri(_V a, _V b, _V c, _V na, _V nb, _V nc, Color col, double spec) {
    tris.add(_Tri(a, b, c, na, nb, nc, col.r * 255, col.g * 255, col.b * 255, spec));
  }

  void quad(_V a, _V b, _V c, _V d, _V n, Color col, double spec) {
    tri(a, b, c, n, n, n, col, spec);
    tri(a, c, d, n, n, n, col, spec);
  }

  void face(_V o, _V u, _V v, _V n, Color col, double spec, double step) {
    final nu = math.max(1, (u.length / step).ceil());
    final nv = math.max(1, (v.length / step).ceil());
    for (var i = 0; i < nu; i++) {
      for (var j = 0; j < nv; j++) {
        final p00 = o + u * (i / nu) + v * (j / nv);
        final p10 = o + u * ((i + 1) / nu) + v * (j / nv);
        final p11 = o + u * ((i + 1) / nu) + v * ((j + 1) / nv);
        final p01 = o + u * (i / nu) + v * ((j + 1) / nv);
        quad(p00, p10, p11, p01, n, col, spec);
      }
    }
  }

  void box(double x0, double y0, double z0, double x1, double y1, double z1, Color col, {double spec = 0.3, double step = 0.6}) {
    final dx = _V(x1 - x0, 0, 0), dy = _V(0, y1 - y0, 0), dz = _V(0, 0, z1 - z0);
    face(_V(x1, y0, z0), dy, dz, const _V(1, 0, 0), col, spec, step);
    face(_V(x0, y0, z0), dz, dy, const _V(-1, 0, 0), col, spec, step);
    face(_V(x0, y1, z0), dz, dx, const _V(0, 1, 0), col, spec, step);
    face(_V(x0, y0, z0), dx, dz, const _V(0, -1, 0), col, spec, step);
    face(_V(x0, y0, z1), dx, dy, const _V(0, 0, 1), col, spec, step);
    face(_V(x0, y0, z0), dy, dx, const _V(0, 0, -1), col, spec, step);
  }

  static (_V, _V) basis(_V d) {
    final h = d.y.abs() < 0.9 ? const _V(0, 1, 0) : const _V(1, 0, 0);
    final e1 = d.cross(h).unit;
    final e2 = d.cross(e1).unit;
    return (e1, e2);
  }

  /// a에서 b까지 원통(끝 반지름이 다르면 원뿔).
  void cyl(_V a, _V b, double ra, double rb, Color col, {int seg = 44, double step = 0.45, bool capA = true, bool capB = true, double spec = 0.7}) {
    final axis = b - a;
    final len = axis.length;
    final d = axis.unit;
    final (e1, e2) = basis(d);
    final rings = math.max(1, (len / step).ceil());
    _V ringPt(int i, int j) {
      final t = i / rings;
      final r = ra + (rb - ra) * t;
      final ang = 2 * math.pi * j / seg;
      return a + d * (len * t) + (e1 * math.cos(ang) + e2 * math.sin(ang)) * r;
    }

    _V ringN(int j) {
      final ang = 2 * math.pi * j / seg;
      final u = e1 * math.cos(ang) + e2 * math.sin(ang);
      return (u * len - d * (rb - ra)).unit;
    }

    for (var i = 0; i < rings; i++) {
      for (var j = 0; j < seg; j++) {
        final p00 = ringPt(i, j), p01 = ringPt(i, j + 1), p11 = ringPt(i + 1, j + 1), p10 = ringPt(i + 1, j);
        final n0 = ringN(j), n1 = ringN(j + 1);
        tri(p00, p10, p11, n0, n0, n1, col, spec);
        tri(p00, p11, p01, n0, n1, n1, col, spec);
      }
    }
    void cap(_V c, double r, _V n) {
      for (var j = 0; j < seg; j++) {
        final a0 = 2 * math.pi * j / seg, a1 = 2 * math.pi * (j + 1) / seg;
        tri(c, c + (e1 * math.cos(a0) + e2 * math.sin(a0)) * r, c + (e1 * math.cos(a1) + e2 * math.sin(a1)) * r, n, n, n, col, spec * 0.7);
      }
    }

    if (capA) cap(a, ra, d * -1);
    if (capB) cap(b, rb, d);
  }

  /// x축 방향 다각형 기둥(방열핀). poly = (y, z) 점들.
  void prismX(double x0, double x1, List<(double, double)> poly, Color col, {double spec = 0.4, double step = 1.4}) {
    final n = poly.length;
    var cy = 0.0, cz = 0.0;
    for (final p in poly) {
      cy += p.$1;
      cz += p.$2;
    }
    cy /= n;
    cz /= n;
    for (var i = 0; i < n; i++) {
      final p = poly[i], q = poly[(i + 1) % n];
      final ey = q.$1 - p.$1, ez = q.$2 - p.$2;
      var ny = ez, nz = -ey;
      if (((p.$1 + q.$1) / 2 - cy) * ny + ((p.$2 + q.$2) / 2 - cz) * nz < 0) {
        ny = -ny;
        nz = -nz;
      }
      face(_V(x0, p.$1, p.$2), _V(x1 - x0, 0, 0), _V(0, ey, ez), _V(0, ny, nz).unit, col, spec, step);
    }
    for (final (x, nx) in [(x0, -1.0), (x1, 1.0)]) {
      for (var i = 1; i < n - 1; i++) {
        quad(_V(x, poly[0].$1, poly[0].$2), _V(x, poly[i].$1, poly[i].$2), _V(x, poly[i + 1].$1, poly[i + 1].$2), _V(x, poly[0].$1, poly[0].$2), _V(nx, 0, 0), col, spec);
      }
    }
  }

  /// 원 둘레 볼트 머리.
  void bolts(_V center, _V outward, double ringR, int count, double boltR, double height, Color col) {
    final (e1, e2) = basis(outward);
    for (var k = 0; k < count; k++) {
      final ang = 2 * math.pi * (k + 0.5) / count;
      final p = center + (e1 * math.cos(ang) + e2 * math.sin(ang)) * ringR;
      cyl(p, p + outward * height, boltR, boltR, col, seg: 8, step: 1, spec: 0.8);
    }
  }

  /// 위를 향한 볼트 머리 하나.
  void boltUp(double x, double y, double z, double r) => cyl(_V(x, y, z), _V(x, y + r * 0.8, z), r, r * 0.9, _nut, seg: 8, step: 1, spec: 0.9);

  /// 고리(아이볼트): 세운 원을 짧은 원통 여러 개로.
  void ring(_V c, double R, double r, Color col) {
    const n = 16;
    for (var k = 0; k < n; k++) {
      final a0 = 2 * math.pi * k / n, a1 = 2 * math.pi * (k + 1) / n;
      cyl(c + _V(math.cos(a0) * R, math.sin(a0) * R, 0), c + _V(math.cos(a1) * R, math.sin(a1) * R, 0), r, r, col, seg: 10, step: 1, spec: 0.8);
    }
  }
}

const Color _silver = Color(0xFFB9C0C8);
const Color _cast = Color(0xFFAEB5BD);
const Color _plateCol = Color(0xFFBCC2C9);
const Color _blue = Color(0xFF2E5D96);
const Color _nut = Color(0xFF8E979F);
const Color _dark = Color(0xFF262B31);
const Color _rubber = Color(0xFF30353B);
const Color _dialA = Color(0xFFE08A00);
const Color _dialB = Color(0xFF2F6FE0);

Color _mix(Color c, double t) => t >= 0 ? Color.lerp(c, Colors.white, t)! : Color.lerp(c, Colors.black, -t)!;

/// 장면에 쓰는 치수(모델 단위). 커플링 중심 x = 0, 펌프는 −, 모터는 +.
class AlignGeo {
  static const double ya = 2.3; // 축 높이
  static const double plateTop = 0.6;
  static const double shimTop = 0.76;
  static const double footTop = 1.0;
  static const double hubR = 0.62;
  static const double xB = -0.55; // 다이얼 B가 읽는 펌프 쪽 허브 림
  static const double xA = 0.55; // 다이얼 A(림 다이얼)가 읽는 모터 쪽 허브 림
  static const double front = 2.65; // 모터 앞발 가운데
  static const double rear = 5.25; // 모터 뒷발 가운데
  static const double footLen = 1.0;
  static const double footZ0 = 1.05, footZ1 = 2.0; // 발(오른쪽) z 범위, 왼쪽은 부호 반대
  static const double motorX0 = 2.05, motorX1 = 6.1, motorR = 1.42;
}

enum _Setup { none, reverse, rimFace }

class _Scene {
  final List<_Tri> tris;
  final _V lo, hi; // 모든 점을 감싸는 상자
  const _Scene(this.tris, this.lo, this.hi);
}

final Map<String, _Scene> _sceneCache = {};

_Scene _scene({_Setup setup = _Setup.none, double? shimFront, double? shimRear}) {
  final key = '$setup|${shimFront?.toStringAsFixed(3)}|${shimRear?.toStringAsFixed(3)}';
  final hit = _sceneCache[key];
  if (hit != null) return hit;
  if (_sceneCache.length > 12) _sceneCache.clear();
  final s = _build(setup, shimFront, shimRear);
  _sceneCache[key] = s;
  return s;
}

_Scene _build(_Setup setup, double? shimFront, double? shimRear) {
  final b = _Builder();
  const ya = AlignGeo.ya, pt = AlignGeo.plateTop;

  // ── 주물 받침판: 펌프 쪽은 좁고 모터 쪽은 넓다. 아래 테두리(치마)와 윗판.
  void plate(double x0, double x1, double hz) {
    b.box(x0 - 0.08, 0, -hz - 0.08, x1 + 0.08, pt - 0.14, hz + 0.08, _mix(_plateCol, -0.12), spec: 0.3);
    b.box(x0, pt - 0.14, -hz, x1, pt, hz, _plateCol, spec: 0.45);
  }

  plate(-6.9, -1.35, 1.7);
  plate(-1.35, 1.6, 1.25);
  plate(1.6, 7.5, 2.3);
  for (final (x, z) in [(-6.55, 1.4), (-6.55, -1.4), (-1.7, 1.4), (-1.7, -1.4), (1.95, 2.0), (1.95, -2.0), (7.15, 2.0), (7.15, -2.0)]) {
    b.boltUp(x, pt, z, 0.13);
  }

  // ── 펌프: 흡입 플랜지(−x) → 볼류트 케이싱 → 뒤판 → 파란 브래킷 → 베어링 하우징
  b.cyl(const _V(-6.62, ya, 0), const _V(-6.36, ya, 0), 1.18, 1.18, _mix(_silver, 0.05));
  b.cyl(const _V(-6.68, ya, 0), const _V(-6.62, ya, 0), 0.66, 0.66, _dark, spec: 0.1);
  b.bolts(const _V(-6.62, ya, 0), const _V(-1, 0, 0), 0.94, 8, 0.075, 0.08, _nut);
  b.cyl(const _V(-6.36, ya, 0), const _V(-5.7, ya, 0), 0.72, 0.9, _silver);
  b.cyl(const _V(-5.7, ya, 0), const _V(-4.55, ya, 0), 1.62, 1.62, _cast); // 볼류트
  b.cyl(const _V(-5.8, ya, 0), const _V(-5.7, ya, 0), 1.3, 1.62, _cast, capA: false, capB: false);
  // 토출 노즐(위)과 플랜지
  b.cyl(const _V(-5.25, ya + 1.1, 0.2), const _V(-5.25, ya + 2.25, 0.2), 0.58, 0.58, _cast);
  b.cyl(const _V(-5.25, ya + 2.25, 0.2), const _V(-5.25, ya + 2.47, 0.2), 1.0, 1.0, _mix(_silver, 0.05));
  b.cyl(const _V(-5.25, ya + 2.47, 0.2), const _V(-5.25, ya + 2.53, 0.2), 0.52, 0.52, _dark, spec: 0.1);
  b.bolts(const _V(-5.25, ya + 2.47, 0.2), const _V(0, 1, 0), 0.8, 8, 0.075, 0.08, _nut);
  // 케이싱 발
  b.box(-5.55, pt, -0.95, -4.7, 0.95, 0.95, _cast);
  b.box(-5.7, pt, -1.25, -4.55, pt + 0.12, 1.25, _mix(_cast, -0.05));
  for (final z in [-1.02, 1.02]) {
    b.boltUp(-5.12, pt + 0.12, z, 0.1);
  }
  // 뒤판(케이싱 커버)과 파란 브래킷(원뿔)
  b.cyl(const _V(-4.55, ya, 0), const _V(-4.3, ya, 0), 1.7, 1.7, _mix(_cast, -0.04));
  b.bolts(const _V(-4.3, ya, 0), const _V(1, 0, 0), 1.52, 12, 0.07, 0.07, _nut);
  b.cyl(const _V(-4.3, ya, 0), const _V(-3.1, ya, 0), 1.4, 0.86, _blue, spec: 0.55);
  b.cyl(const _V(-3.1, ya, 0), const _V(-1.75, ya, 0), 0.86, 0.8, _blue, spec: 0.55);
  b.cyl(const _V(-1.95, ya, 0), const _V(-1.75, ya, 0), 0.9, 0.9, _mix(_blue, -0.1), spec: 0.5);
  b.cyl(const _V(-2.6, ya + 0.8, 0), const _V(-2.6, ya + 1.05, 0), 0.14, 0.14, const Color(0xFFD8A63A), seg: 14, step: 1); // 급유구
  // 베어링 받침 다리
  b.box(-2.95, pt + 0.12, -0.34, -2.25, ya - 0.7, 0.34, _cast);
  b.box(-3.25, pt, -0.85, -1.95, pt + 0.12, 0.85, _mix(_cast, -0.05));
  for (final z in [-0.62, 0.62]) {
    b.boltUp(-2.6, pt + 0.12, z, 0.1);
  }
  // 펌프 축
  b.cyl(const _V(-1.75, ya, 0), const _V(-0.9, ya, 0), 0.27, 0.27, _mix(_silver, 0.2), seg: 20, step: 1);

  // ── 커플링: 허브 둘 + 가운데 고무(스파이더)
  b.cyl(const _V(-0.9, ya, 0), const _V(-0.12, ya, 0), AlignGeo.hubR, AlignGeo.hubR, _mix(_silver, 0.1), spec: 0.9);
  b.cyl(const _V(-0.12, ya, 0), const _V(0.12, ya, 0), 0.46, 0.46, _rubber, spec: 0.2);
  b.cyl(const _V(0.12, ya, 0), const _V(0.9, ya, 0), AlignGeo.hubR, AlignGeo.hubR, _mix(_silver, 0.1), spec: 0.9);
  b.cyl(const _V(0.9, ya, 0), const _V(1.62, ya, 0), 0.27, 0.27, _mix(_silver, 0.2), seg: 20, step: 1);

  // ── 모터: 앞 엔드실드 → 핀 달린 몸통 → 뒤 엔드실드 → 팬 덮개
  const mx0 = AlignGeo.motorX0, mx1 = AlignGeo.motorX1, mr = AlignGeo.motorR;
  b.cyl(const _V(1.62, ya, 0), const _V(1.8, ya, 0), 0.45, 0.45, _mix(_silver, -0.05));
  b.cyl(const _V(1.8, ya, 0), const _V(mx0, ya, 0), 1.05, mr + 0.1, _mix(_silver, -0.02));
  b.cyl(const _V(mx0, ya, 0), const _V(mx1, ya, 0), mr - 0.06, mr - 0.06, _mix(_silver, -0.08), step: 0.8);
  const finCount = 40;
  for (var k = 0; k < finCount; k++) {
    final ang = 2 * math.pi * k / finCount;
    final cy = math.sin(ang), cz = math.cos(ang);
    if (cy < -0.72) continue; // 발 쪽 아래는 핀 없음
    const r0 = mr - 0.1, r1 = mr + 0.12, th = 0.04;
    b.prismX(mx0 + 0.1, mx1 - 0.1, [
      (ya + cy * r0 - cz * th, cz * r0 + cy * th),
      (ya + cy * r1 - cz * th, cz * r1 + cy * th),
      (ya + cy * r1 + cz * th, cz * r1 - cy * th),
      (ya + cy * r0 + cz * th, cz * r0 - cy * th),
    ], _mix(_silver, 0.02));
  }
  b.cyl(const _V(mx1, ya, 0), const _V(mx1 + 0.3, ya, 0), mr + 0.1, mr + 0.1, _mix(_silver, -0.02));
  b.cyl(const _V(mx1 + 0.3, ya, 0), const _V(7.25, ya, 0), mr + 0.02, mr - 0.12, _mix(_silver, 0.06), step: 0.3);
  b.cyl(const _V(7.25, ya, 0), const _V(7.4, ya, 0), mr - 0.12, 0.9, _mix(_silver, 0.06));
  // 고리(아이볼트)
  b.cyl(const _V(3.55, ya + mr + 0.08, 0), const _V(3.55, ya + mr + 0.25, 0), 0.16, 0.16, _nut, seg: 14, step: 1);
  b.ring(const _V(3.55, ya + mr + 0.5, 0), 0.24, 0.06, _mix(_silver, -0.05));
  // 단자함(앞쪽 +z로 튀어나옴) + 뚜껑 + 전선 구멍
  b.box(3.7, ya - 0.45, mr - 0.2, 5.0, ya + 0.75, mr + 0.55, _mix(_silver, 0.02), spec: 0.5);
  b.box(3.78, ya - 0.37, mr + 0.55, 4.92, ya + 0.67, mr + 0.62, _mix(_silver, 0.12), spec: 0.6);
  for (final (x, y) in [(3.88, ya + 0.57), (4.82, ya + 0.57), (3.88, ya - 0.27), (4.82, ya - 0.27)]) {
    b.cyl(_V(x, y, mr + 0.62), _V(x, y, mr + 0.68), 0.05, 0.05, _nut, seg: 8, step: 1);
  }
  b.cyl(const _V(4.35, ya - 0.45, mr + 0.18), const _V(4.35, ya - 0.62, mr + 0.18), 0.16, 0.16, _dark, seg: 12, step: 1);
  // 명판
  b.box(2.6, ya + 0.35, -0.3, 3.3, ya + mr + 0.13, 0.3, _mix(_silver, 0.25), spec: 0.4, step: 1);

  // ── 모터 네 발과 심 판
  final xs = [AlignGeo.front, AlignGeo.rear];
  final shims = [shimFront, shimRear];
  for (var i = 0; i < 2; i++) {
    final xc = xs[i];
    const fl = AlignGeo.footLen;
    for (final s in [-1.0, 1.0]) {
      final z0 = s > 0 ? AlignGeo.footZ0 : -AlignGeo.footZ1, z1 = s > 0 ? AlignGeo.footZ1 : -AlignGeo.footZ0;
      final sh = shims[i];
      final col = sh == null ? const Color(0xFF8A939B) : alignShimColor(sh);
      b.box(xc - fl / 2 - 0.12, pt, z0 - 0.12, xc + fl / 2 + 0.12, AlignGeo.shimTop, z1 + 0.12, col, spec: 0.5, step: 0.5);
      b.box(xc - fl / 2, AlignGeo.shimTop, z0, xc + fl / 2, AlignGeo.footTop, z1, _cast, spec: 0.5, step: 0.5);
      final w0 = s > 0 ? 0.9 : -1.3, w1 = s > 0 ? 1.3 : -0.9;
      b.box(xc - fl / 2 + 0.08, AlignGeo.footTop, w0, xc + fl / 2 - 0.08, ya - 0.6, w1, _cast, spec: 0.4);
      b.boltUp(xc, AlignGeo.footTop, s * 1.65, 0.14);
    }
  }

  // ── 다이얼 브래킷(측정 그림에만)
  if (setup != _Setup.none) {
    const top = ya + AlignGeo.hubR;
    // A(또는 림 다이얼): 펌프 쪽 허브에 물려 모터 쪽 림 위로
    b.box(AlignGeo.xB - 0.16, top - 0.06, 0.12, AlignGeo.xB + 0.16, top + 0.12, 0.44, _dialA, spec: 0.5, step: 1);
    b.box(AlignGeo.xB - 0.05, top + 0.12, 0.23, AlignGeo.xB + 0.05, ya + 1.55, 0.33, _dialA, spec: 0.6, step: 1);
    b.box(AlignGeo.xB - 0.05, ya + 1.45, 0.23, AlignGeo.xA + 0.05, ya + 1.55, 0.33, _dialA, spec: 0.6, step: 1);
    if (setup == _Setup.reverse) {
      // B: 모터 쪽 허브에 물려 펌프 쪽 림 위로(뒤쪽에)
      b.box(AlignGeo.xA - 0.16, top - 0.06, -0.44, AlignGeo.xA + 0.16, top + 0.12, -0.12, _dialB, spec: 0.5, step: 1);
      b.box(AlignGeo.xA - 0.05, top + 0.12, -0.33, AlignGeo.xA + 0.05, ya + 2.15, -0.23, _dialB, spec: 0.6, step: 1);
      b.box(AlignGeo.xB - 0.05, ya + 2.05, -0.33, AlignGeo.xA + 0.05, ya + 2.15, -0.23, _dialB, spec: 0.6, step: 1);
    } else {
      // 페이스 다이얼 팔: 같은 클램프에서 앞으로 내려온다
      b.box(AlignGeo.xB - 0.05, ya + 0.1, 0.33, AlignGeo.xB + 0.05, top + 0.12, 0.43, _dialA, spec: 0.6, step: 1);
      b.box(AlignGeo.xB - 0.05, ya + 0.1, 0.43, AlignGeo.xB + 0.05, ya + 0.2, 1.05, _dialA, spec: 0.6, step: 1);
    }
  }

  var lo = const _V(1e9, 1e9, 1e9), hi = const _V(-1e9, -1e9, -1e9);
  for (final t in b.tris) {
    for (final v in [t.a, t.b, t.c]) {
      lo = _V(math.min(lo.x, v.x), math.min(lo.y, v.y), math.min(lo.z, v.z));
      hi = _V(math.max(hi.x, v.x), math.max(hi.y, v.y), math.max(hi.z, v.z));
    }
  }
  return _Scene(b.tris, lo, hi);
}

/// 카메라: 비스듬히(원근) 또는 정면(평행 투영).
class _Cam {
  final _V right, up, d;
  final _V? pos; // null이면 평행 투영
  _Cam(this.right, this.up, this.d, this.pos);

  factory _Cam.iso() {
    const yaw = 0.52, pitch = 0.36;
    final cp = math.cos(pitch), sp = math.sin(pitch);
    final d = _V(cp * math.sin(yaw), -sp, -cp * math.cos(yaw));
    final right = d.cross(const _V(0, 1, 0)).unit;
    final up = right.cross(d).unit;
    return _Cam(right, up, d, const _V(0.3, 1.8, 0) - d * 34);
  }
  factory _Cam.side() => _Cam(const _V(1, 0, 0), const _V(0, 1, 0), const _V(0, 0, -1), null);
  factory _Cam.top() => _Cam(const _V(1, 0, 0), const _V(0, 0, -1), const _V(0, -1, 0), null);

  (double, double) proj(_V v) {
    final p = pos;
    if (p == null) return (v.dot(right), -v.dot(up));
    final rel = v - p;
    final z = rel.dot(d);
    return (rel.dot(right) / z * 34, -rel.dot(up) / z * 34);
  }

  double depth(_V v) => pos == null ? v.dot(d) : (v - pos!).dot(d);
  bool facing(_V centroid, _V n) => pos == null ? n.dot(d) < 0 : n.dot(pos! - centroid) > 0;
}

/// 장면을 [box] 안에 맞춰 그리고, 3D 점 → 화면 점 함수를 돌려준다.
Offset Function(_V) _render(Canvas canvas, _Scene scene, _Cam cam, Rect box, {List<_V> extra = const []}) {
  var minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9;
  void grow(_V v) {
    final p = cam.proj(v);
    minX = math.min(minX, p.$1);
    maxX = math.max(maxX, p.$1);
    minY = math.min(minY, p.$2);
    maxY = math.max(maxY, p.$2);
  }

  for (final x in [scene.lo.x, scene.hi.x]) {
    for (final y in [scene.lo.y, scene.hi.y]) {
      for (final z in [scene.lo.z, scene.hi.z]) {
        grow(_V(x, y, z));
      }
    }
  }
  extra.forEach(grow);
  final scale = math.min(box.width / (maxX - minX), box.height / (maxY - minY));
  final ox = box.center.dx - (minX + maxX) / 2 * scale;
  final oy = box.center.dy - (minY + maxY) / 2 * scale;
  Offset toScreen(_V v) {
    final p = cam.proj(v);
    return Offset(ox + p.$1 * scale, oy + p.$2 * scale);
  }

  // 바닥 그림자
  final sh = Path()
    ..addPolygon([
      toScreen(_V(scene.lo.x - 0.2, 0, scene.lo.z - 0.2)),
      toScreen(_V(scene.hi.x + 0.2, 0, scene.lo.z - 0.2)),
      toScreen(_V(scene.hi.x + 0.2, 0, scene.hi.z + 0.2)),
      toScreen(_V(scene.lo.x - 0.2, 0, scene.hi.z + 0.2)),
    ], true);
  if (cam.d.y > -0.99) canvas.drawPath(sh.shift(const Offset(0, 5)), Paint()..color = Colors.black.withValues(alpha: 0.14)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

  final light = (cam.right * -0.45 + cam.up * 0.85 + cam.d * -0.6).unit;
  final half = (light - cam.d).unit;
  final tris = scene.tris;
  final keep = <int>[];
  final depth = Float64List(tris.length);
  for (var i = 0; i < tris.length; i++) {
    final t = tris[i];
    final c = _V((t.a.x + t.b.x + t.c.x) / 3, (t.a.y + t.b.y + t.c.y) / 3, (t.a.z + t.b.z + t.c.z) / 3);
    final n = t.na + t.nb + t.nc;
    if (!cam.facing(c, n)) continue;
    depth[i] = cam.depth(c);
    keep.add(i);
  }
  keep.sort((p, q) => depth[q].compareTo(depth[p]));
  final pos = Float32List(keep.length * 6);
  final cols = Int32List(keep.length * 3);
  for (var k = 0; k < keep.length; k++) {
    final t = tris[keep[k]];
    final vs = [t.a, t.b, t.c];
    final ns = [t.na, t.nb, t.nc];
    for (var j = 0; j < 3; j++) {
      final o = toScreen(vs[j]);
      pos[k * 6 + j * 2] = o.dx;
      pos[k * 6 + j * 2 + 1] = o.dy;
      final n = ns[j];
      final diff = math.max(0.0, n.dot(light));
      final hemi = 0.5 + 0.5 * n.dot(cam.up);
      final spec = t.spec * math.pow(math.max(0.0, n.dot(half)), 36).toDouble() * 235;
      final inten = 0.36 + 0.58 * diff + 0.16 * hemi;
      int ch(double base) => (base * inten + spec).round().clamp(0, 255);
      cols[k * 3 + j] = (0xFF << 24) | (ch(t.r) << 16) | (ch(t.g) << 8) | ch(t.bl);
    }
  }
  canvas.drawVertices(ui.Vertices.raw(ui.VertexMode.triangles, pos, colors: cols), BlendMode.dst, Paint()..isAntiAlias = true);
  return toScreen;
}

void _txt(Canvas canvas, String t, Offset at, Color c, {double size = 11, bool center = true, FontWeight w = FontWeight.w800}) {
  final tp = TextPainter(
    text: TextSpan(text: t, style: TextStyle(fontSize: size, fontWeight: w, color: c)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, center ? at - Offset(tp.width / 2, tp.height / 2) : at);
}

void _badge(Canvas canvas, String n, Offset c, Color color) {
  canvas.drawCircle(c.translate(0, 1), 10, Paint()..color = Colors.black.withValues(alpha: 0.18));
  canvas.drawCircle(c, 10, Paint()..color = color);
  _txt(canvas, n, c, Colors.white, size: 12, w: FontWeight.w900);
}

void _dashLine(Canvas canvas, Offset a, Offset b, Paint p) => alignDashPath(canvas, Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy), p);

// ─────────────────────────── 측정 그림 ───────────────────────────


class AlignSetupRenderPainter extends CustomPainter {
  final AlignMethod method;
  AlignSetupRenderPainter(this.method);

  static const double _dimsH = 122;
  static double heightFor(double w) => (w * 0.52).clamp(250.0, 520.0) + _dimsH;

  @override
  void paint(Canvas canvas, Size size) {
    final reverse = method == AlignMethod.reverse;
    final scene = _scene(setup: reverse ? _Setup.reverse : _Setup.rimFace);
    final cam = _Cam.iso();
    const ya = AlignGeo.ya, top = ya + AlignGeo.hubR;
    final extra = [const _V(0.5, ya + 2.7, 0)];
    final toS = _render(canvas, scene, cam, Rect.fromLTWH(8, 8, size.width - 16, size.height - 16 - _dimsH), extra: extra);
    final u = (toS(const _V(0, ya, 0)) - toS(const _V(1, ya, 0))).distance; // 모델 1단위의 화면 길이

    // ── 다이얼(실물 모양)
    final dialR = (u * 0.46).clamp(12.0, 46.0);
    if (reverse) {
      final bC = toS(const _V(AlignGeo.xB, ya + 2.1, -0.28)) + Offset(0, -dialR * 0.6);
      paintDialGauge(canvas, bC, dialR, value: 0, stemTo: toS(const _V(AlignGeo.xB, top - 0.02, -0.28)), tag: _dialB, numbers: false);
      _chip(canvas, 'B', bC + Offset(-dialR * 1.55, -dialR * 0.2), _dialB);
    }
    final aC = toS(const _V(AlignGeo.xA, ya + 1.5, 0.28)) + Offset(0, -dialR * 0.6);
    paintDialGauge(canvas, aC, dialR, value: 0, stemTo: toS(const _V(AlignGeo.xA, top - 0.02, 0.28)), tag: _dialA, numbers: false);
    _chip(canvas, reverse ? 'A' : '림', aC + Offset(dialR * 1.6, -dialR * 0.2), _dialA);
    if (!reverse) {
      // 페이스 다이얼: 팔 끝에서 모터 쪽 허브 옆면을 누른다
      final contact = toS(const _V(0.12, ya + 0.12, 0.5));
      final fC = toS(const _V(AlignGeo.xB, ya + 0.15, 1.05)) + Offset(-dialR * 0.9, dialR * 0.2);
      paintDialGauge(canvas, fC, dialR * 0.9, value: 0, stemTo: contact, tag: _dialA, numbers: false);
      _chip(canvas, '페이스', fC + Offset(-dialR * 1.2, -dialR * 1.35), _dialA);
      // ④ 페이스가 닿는 반지름
      final c0 = toS(const _V(0.12, ya, 0)), c1 = toS(const _V(0.12, ya + 0.12, 0.5));
      final p = Paint()..color = AppColors.text..strokeWidth = 1.6;
      canvas.drawLine(c0, c1, p);
      canvas.drawCircle(c0, 2.5, Paint()..color = AppColors.text);
      _badge(canvas, kAlignNumbers[3], (c0 + c1) / 2 + const Offset(0, 16), AppColors.text);
    }

    // ── 재는 거리
    final dims = reverse
        ? [
            (AlignGeo.xB, AlignGeo.xA, 'A·B 두 접촉면 사이', _dialB),
            (AlignGeo.xB, 0.0, 'B면 → 커플링 중심', AppColors.text),
            (AlignGeo.xA, AlignGeo.front, 'A면 → 앞발', _dialA),
            (AlignGeo.xA, AlignGeo.rear, 'A면 → 뒷발', _dialA),
          ]
        : [
            (AlignGeo.xA, 0.0, '림면 → 커플링 중심', AppColors.text),
            (AlignGeo.xA, AlignGeo.front, '림면 → 앞발', _dialA),
            (AlignGeo.xA, AlignGeo.rear, '림면 → 뒷발', _dialA),
          ];
    final ext = Paint()..color = AppColors.textSub.withValues(alpha: 0.7)..strokeWidth = 1..style = PaintingStyle.stroke;
    _V featureAt(double x) {
      if (x == AlignGeo.front || x == AlignGeo.rear) return _V(x, AlignGeo.footTop, 1.65);
      return _V(x, ya - AlignGeo.hubR * 0.7, AlignGeo.hubR * 0.7);
    }

    for (var i = 0; i < dims.length; i++) {
      final (x0, x1, label, col) = dims[i];
      final ly = size.height - _dimsH + 16 + i * 27.0;
      final f0 = toS(featureAt(x0)), f1 = toS(featureAt(x1));
      _dashLine(canvas, f0, Offset(f0.dx, ly + 6), ext);
      _dashLine(canvas, f1, Offset(f1.dx, ly + 6), ext);
      canvas.drawCircle(f0, 2.4, Paint()..color = col);
      canvas.drawCircle(f1, 2.4, Paint()..color = col);
      final a = Offset(f0.dx, ly), bb = Offset(f1.dx, ly);
      final p = Paint()..color = col..strokeWidth = 2..strokeCap = StrokeCap.round;
      canvas.drawLine(a, bb, p);
      final l = math.min(a.dx, bb.dx), r = math.max(a.dx, bb.dx);
      for (final (x, sgn) in [(l, 1.0), (r, -1.0)]) {
        canvas.drawLine(Offset(x, ly), Offset(x + 7 * sgn, ly - 3.5), p);
        canvas.drawLine(Offset(x, ly), Offset(x + 7 * sgn, ly + 3.5), p);
      }
      _badge(canvas, kAlignNumbers[i], Offset((l + r) / 2, ly), col);
      final tp = TextPainter(
        text: TextSpan(text: label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: col)),
        textDirection: TextDirection.ltr,
      )..layout();
      var tx = math.max(r + 8, (l + r) / 2 + 14);
      if (tx + tp.width > size.width - 4) tx = math.min(l, (l + r) / 2 - 14) - 8 - tp.width;
      tp.paint(canvas, Offset(tx.clamp(2.0, size.width - tp.width - 2), ly - tp.height / 2));
    }

    _txt(canvas, '펌프 (고정)', toS(const _V(-4.6, ya + 3.1, 0)), AppColors.textSub, size: 12);
    _txt(canvas, '모터 (이동, 발에 심)', toS(const _V(4.4, ya + 2.35, 0)), AppColors.textSub, size: 12);
  }

  void _chip(Canvas canvas, String t, Offset at, Color c) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
      textDirection: TextDirection.ltr,
    )..layout();
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: tp.width + 12, height: tp.height + 4), const Radius.circular(9));
    canvas.drawRRect(r, Paint()..color = c);
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant AlignSetupRenderPainter old) => old.method != method;
}

// ─────────────────────────── 결과: 옆에서 본 그림 ───────────────────────────

class AlignSideRenderPainter extends CustomPainter {
  final AxisLine vertical; // 모터 축 위아래 어긋남(+ 위)
  final double xRear;
  final double shimFront, shimRear;
  AlignSideRenderPainter({required this.vertical, required this.xRear, required this.shimFront, required this.shimRear});

  static double heightFor(double w) => (w * 0.36).clamp(210.0, 360.0) + 70;

  @override
  void paint(Canvas canvas, Size size) {
    final scene = _scene(shimFront: shimFront, shimRear: shimRear);
    final toS = _render(canvas, scene, _Cam.side(), Rect.fromLTWH(8, 24, size.width - 16, size.height - 24 - 70));
    const ya = AlignGeo.ya;

    // 목표 중심선(펌프 축)
    final c0 = toS(const _V(-7.2, ya, 0)), c1 = toS(const _V(7.7, ya, 0));
    _dashLine(canvas, c0, c1, Paint()..color = AppColors.text.withValues(alpha: 0.6)..strokeWidth = 1.5..style = PaintingStyle.stroke);

    // 지금 모터 위치(점선): 위아래 어긋남을 크게 부풀린 것
    final vc = vertical.at(0), vEnd = vertical.at(xRear);
    final vMax = math.max(vc.abs(), vEnd.abs());
    final k = vMax < 1e-6 ? 0.0 : 0.35 / vMax;
    const r = AlignGeo.motorR + 0.12;
    final ghost = Path()
      ..addPolygon([
        toS(_V(AlignGeo.motorX0, ya + r + vc * k, 0)),
        toS(_V(AlignGeo.motorX1, ya + r + vEnd * k, 0)),
        toS(_V(AlignGeo.motorX1, ya - r + vEnd * k, 0)),
        toS(_V(AlignGeo.motorX0, ya - r + vc * k, 0)),
      ], true);
    alignDashPath(canvas, ghost, Paint()..color = alignCaution..style = PaintingStyle.stroke..strokeWidth = 2.4);

    // 발마다 심 표찰
    void chip(double x, double mm, String tag, double dx) {
      final c = alignShimColor(mm);
      final a = toS(_V(x, (AlignGeo.plateTop + AlignGeo.shimTop) / 2, 2.4));
      final at = Offset((a.dx + dx).clamp(52.0, size.width - 52), size.height - 30);
      canvas.drawLine(a, at - const Offset(0, 20), Paint()..color = c..strokeWidth = 1.4);
      canvas.drawCircle(a, 3, Paint()..color = c);
      alignLabel(canvas, '$tag\n심 ${alignShimShort(mm)}', at, c, size: size.width < 600 ? 10 : 11, minWidth: size.width < 600 ? 70 : 90);
    }

    chip(AlignGeo.front, shimFront, '앞발', size.width < 600 ? -28 : -10);
    chip(AlignGeo.rear, shimRear, '뒷발', size.width < 600 ? 28 : 10);
    _txt(canvas, '펌프 (고정)', Offset(toS(const _V(-4.5, 0, 0)).dx, size.height - 30), AppColors.textSub, size: 12);
    _txt(canvas, '점선 = 지금 모터 위치(크게 부풀림)', Offset(size.width - 202, 4), alignCaution, center: false);
  }

  @override
  bool shouldRepaint(covariant AlignSideRenderPainter old) =>
      old.vertical.v0 != vertical.v0 || old.vertical.slope != vertical.slope || old.xRear != xRear || old.shimFront != shimFront || old.shimRear != shimRear;
}

// ─────────────────────────── 결과: 위에서 본 그림 ───────────────────────────

/// 위쪽이 왼쪽, 아래쪽이 오른쪽(고정 쪽에서 모터를 바라볼 때).
class AlignTopRenderPainter extends CustomPainter {
  final AxisLine horizontal; // 모터 축 옆 어긋남(+ 오른쪽)
  final double xRear;
  final double shimFront, shimRear, moveFront, moveRear;
  AlignTopRenderPainter({
    required this.horizontal,
    required this.xRear,
    required this.shimFront,
    required this.shimRear,
    required this.moveFront,
    required this.moveRear,
  });

  static double heightFor(double w) => (w * 0.34).clamp(170.0, 330.0) + 130;

  @override
  void paint(Canvas canvas, Size size) {
    final scene = _scene(shimFront: shimFront, shimRear: shimRear);
    final narrow = size.width < 600;
    final toS = _render(canvas, scene, _Cam.top(), Rect.fromLTWH(8, 66, size.width - 16, size.height - 132));
    const y = AlignGeo.ya + AlignGeo.motorR + 0.2;

    final c0 = toS(const _V(-7.2, y, 0)), c1 = toS(const _V(7.7, y, 0));
    _dashLine(canvas, c0, c1, Paint()..color = AppColors.text.withValues(alpha: 0.6)..strokeWidth = 1.5..style = PaintingStyle.stroke);

    // 지금 모터 위치(점선): 옆 어긋남을 크게 부풀린 것(+ 오른쪽 = 화면 아래)
    final zc = horizontal.at(0), zEnd = horizontal.at(xRear);
    final zMax = math.max(math.max(zc.abs(), zEnd.abs()), math.max(moveFront.abs(), moveRear.abs()));
    final k = zMax < 1e-6 ? 0.0 : 0.4 / zMax;
    const r = AlignGeo.motorR + 0.12;
    final ghost = Path()
      ..addPolygon([
        toS(_V(AlignGeo.motorX0, y, -r + zc * k)),
        toS(_V(AlignGeo.motorX1, y, -r + zEnd * k)),
        toS(_V(AlignGeo.motorX1, y, r + zEnd * k)),
        toS(_V(AlignGeo.motorX0, y, r + zc * k)),
      ], true);
    alignDashPath(canvas, ghost, Paint()..color = alignCaution..style = PaintingStyle.stroke..strokeWidth = 2.4);

    // 네 발 표찰
    void chip(double x, double side, double mm, String tag) {
      final c = alignShimColor(mm);
      final a = toS(_V(x, AlignGeo.footTop, side * (AlignGeo.footZ1 + 0.12)));
      final at = Offset((a.dx + (x == AlignGeo.front ? (narrow ? -22 : -8) : (narrow ? 22 : 8))).clamp(40.0, size.width - 40), side < 0 ? 30 : size.height - 30);
      canvas.drawLine(a, at + Offset(0, side < 0 ? 18 : -18), Paint()..color = c..strokeWidth = 1.4);
      canvas.drawCircle(a, 3, Paint()..color = c);
      alignLabel(canvas, '$tag\n${alignShimShort(mm)}', at, c, size: narrow ? 10 : 11, minWidth: narrow ? 56 : 74);
    }

    chip(AlignGeo.front, -1, shimFront, narrow ? '앞·왼' : '앞발 왼쪽');
    chip(AlignGeo.rear, -1, shimRear, narrow ? '뒤·왼' : '뒷발 왼쪽');
    chip(AlignGeo.front, 1, shimFront, narrow ? '앞·오른' : '앞발 오른쪽');
    chip(AlignGeo.rear, 1, shimRear, narrow ? '뒤·오른' : '뒷발 오른쪽');

    // 옆으로 미는 방향
    void arrow(double x, double mm) {
      final o = toS(_V(x, y, 0));
      final at = Offset((o.dx + (x == AlignGeo.front ? -8 : 8)).clamp(48.0, size.width - 48), o.dy + 34);
      if (mm.abs() < 0.005) {
        alignLabel(canvas, '옆 그대로', o, alignOk, size: 11);
        return;
      }
      final dir = mm > 0 ? 1.0 : -1.0;
      final p = Paint()..color = AppColors.brand..strokeWidth = 4..strokeCap = StrokeCap.round;
      final a = o - Offset(0, dir * 18), b = o + Offset(0, dir * 18);
      canvas.drawLine(a, b, p);
      canvas.drawLine(b, b + Offset(-7, -dir * 10), p);
      canvas.drawLine(b, b + Offset(7, -dir * 10), p);
      alignLabel(canvas, '옆으로 ${mm > 0 ? '오른쪽' : '왼쪽'}\n${mm.abs().toStringAsFixed(2)} mm', dir > 0 ? at : Offset(at.dx, o.dy - 34), AppColors.brand, size: narrow ? 10 : 11, minWidth: narrow ? 56 : 74);
    }

    arrow(AlignGeo.front, moveFront);
    arrow(AlignGeo.rear, moveRear);

    _txt(canvas, '왼쪽 ▲', const Offset(6, 4), AppColors.textSub, center: false);
    _txt(canvas, '오른쪽 ▼', Offset(6, size.height - 18), AppColors.textSub, center: false);
    _txt(canvas, '펌프 (고정)', toS(const _V(-4.5, y, 2.4)) + const Offset(0, 14), AppColors.textSub, size: 12);
  }

  @override
  bool shouldRepaint(covariant AlignTopRenderPainter old) =>
      old.horizontal.v0 != horizontal.v0 ||
      old.horizontal.slope != horizontal.slope ||
      old.xRear != xRear ||
      old.shimFront != shimFront ||
      old.shimRear != shimRear ||
      old.moveFront != moveFront ||
      old.moveRear != moveRear;
}
