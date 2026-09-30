// ignore_for_file: library_private_types_in_public_api
// 축 정렬 입체 그림: 펌프·커플링·모터·I빔 받침판을 3D 부품으로 만들어 조명·원근을 넣어 그린다.
// 모터 네 발 밑에 심 판(넣기·빼기·그대로 색)이 깔리고, 좌우로 끌면 돌려 볼 수 있다.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
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

  void box(double x0, double y0, double z0, double x1, double y1, double z1, Color col, {double spec = 0.25, double step = 0.7}) {
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

  /// a에서 b까지 이어진 원통(끝 반지름이 다르면 원뿔). 옆면은 부드러운 법선으로 매끈하게 보인다.
  void cyl(_V a, _V b, double ra, double rb, Color col, {int seg = 40, double step = 0.5, bool capA = true, bool capB = true, double spec = 0.6}) {
    final axis = b - a;
    final len = axis.length;
    final d = axis.unit;
    final (e1, e2) = basis(d);
    final rings = math.max(1, (len / step).ceil());
    _V ringPt(int i, int j) {
      final t = i / rings;
      final r = ra + (rb - ra) * t;
      final ang = 2 * math.pi * j / seg;
      final u = e1 * math.cos(ang) + e2 * math.sin(ang);
      return a + d * (len * t) + u * r;
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
        final p0 = c + (e1 * math.cos(a0) + e2 * math.sin(a0)) * r;
        final p1 = c + (e1 * math.cos(a1) + e2 * math.sin(a1)) * r;
        tri(c, p0, p1, n, n, n, col, spec * 0.7);
      }
    }

    if (capA) cap(a, ra, d * -1);
    if (capB) cap(b, rb, d);
  }

  /// x축 방향으로 뻗은 다각형 기둥(방열핀 같은 것). poly는 (y, z) 점들.
  void prismX(double x0, double x1, List<(double, double)> poly, Color col, {double spec = 0.35, double step = 1.2}) {
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
      final mid = ((p.$1 + q.$1) / 2 - cy) * ny + ((p.$2 + q.$2) / 2 - cz) * nz;
      if (mid < 0) {
        ny = -ny;
        nz = -nz;
      }
      final n3 = _V(0, ny, nz).unit;
      face(_V(x0, p.$1, p.$2), _V(x1 - x0, 0, 0), _V(0, ey, ez), n3, col, spec, step);
    }
    for (final (x, nx) in [(x0, -1.0), (x1, 1.0)]) {
      for (var i = 1; i < n - 1; i++) {
        quad(_V(x, poly[0].$1, poly[0].$2), _V(x, poly[i].$1, poly[i].$2), _V(x, poly[i + 1].$1, poly[i + 1].$2), _V(x, poly[0].$1, poly[0].$2), _V(nx, 0, 0), col, spec);
      }
    }
  }

  /// 플랜지 둘레의 볼트 머리.
  void bolts(_V center, _V outward, double ringR, int count, double boltR, double height, Color col) {
    final (e1, e2) = basis(outward);
    for (var k = 0; k < count; k++) {
      final ang = 2 * math.pi * (k + 0.5) / count;
      final p = center + (e1 * math.cos(ang) + e2 * math.sin(ang)) * ringR;
      cyl(p, p + outward * height, boltR, boltR, col, seg: 8, step: 1, spec: 0.7);
    }
  }
}

/// 만들어 둔 장면: 삼각형과, 심 판 자리(라벨 지시선용).
class AlignScene {
  final List<_Tri> tris;
  final _V frontShimAnchor, rearShimAnchor;
  const AlignScene._(this.tris, this.frontShimAnchor, this.rearShimAnchor);

  static const double ya = 2.1; // 축 높이
  static const double beamTop = 0.5;
  static const double shimTop = 0.64;

  static AlignScene build({required double shimFront, required double shimRear}) {
    final b = _Builder();
    const dark = Color(0xFF3A3F47);
    const steelDark = Color(0xFF59626D);
    const pumpBlue = Color(0xFF2F72AE);
    const pumpBlueDark = Color(0xFF265F93);
    const motorSteel = Color(0xFF7C97B1);
    const motorFin = Color(0xFF93AAC2);
    const cast = Color(0xFF6E7883);
    const black = Color(0xFF1C2026);
    const teal = Color(0xFF14A0AB);
    const hubSteel = Color(0xFFB4BCC6);

    // ── 받침판: I빔 두 줄 + 가로대
    void ibeamX(double x0, double x1, double zc) {
      b.box(x0, 0, zc - 0.27, x1, 0.07, zc + 0.27, dark, spec: 0.35);
      b.box(x0, 0.43, zc - 0.27, x1, 0.5, zc + 0.27, dark, spec: 0.35);
      b.box(x0, 0.07, zc - 0.035, x1, 0.43, zc + 0.035, _mix(dark, 0.06), spec: 0.2);
    }

    void ibeamZ(double xc, double z0, double z1) {
      b.box(xc - 0.24, 0, z0, xc + 0.24, 0.07, z1, dark, spec: 0.35);
      b.box(xc - 0.24, 0.43, z0, xc + 0.24, 0.5, z1, dark, spec: 0.35);
      b.box(xc - 0.03, 0.07, z0, xc + 0.03, 0.43, z1, _mix(dark, 0.06), spec: 0.2);
    }

    ibeamX(-6.7, 7.5, -1.62);
    ibeamX(-6.7, 7.5, 1.62);
    for (final x in [-6.4, -3.9, -1.1, 0.9, 3.7, 7.2]) {
      ibeamZ(x, -1.35, 1.35);
    }

    // ── 펌프
    // 흡입 노즐(왼쪽 끝)과 플랜지
    b.cyl(const _V(-6.15, ya, 0), const _V(-5.2, ya, 0), 0.72, 0.85, pumpBlue);
    b.cyl(const _V(-6.35, ya, 0), const _V(-6.15, ya, 0), 1.12, 1.12, _mix(pumpBlue, 0.12));
    b.cyl(const _V(-6.43, ya, 0), const _V(-6.35, ya, 0), 0.62, 0.62, black, spec: 0.1);
    b.bolts(const _V(-6.35, ya, 0), const _V(-1, 0, 0), 0.9, 8, 0.07, 0.08, black);
    // 케이싱(볼류트)
    b.cyl(const _V(-5.2, ya, 0), const _V(-3.3, ya, 0), 1.55, 1.55, pumpBlue);
    b.cyl(const _V(-3.3, ya, 0), const _V(-3.05, ya, 0), 1.66, 1.66, pumpBlueDark);
    b.bolts(const _V(-3.05, ya, 0), const _V(1, 0, 0), 1.5, 12, 0.07, 0.07, black);
    // 토출 노즐(위로)과 플랜지
    b.cyl(const _V(-4.2, ya + 1.3, 0), const _V(-4.2, ya + 2.0, 0), 0.62, 0.62, pumpBlue);
    b.cyl(const _V(-4.2, ya + 2.0, 0), const _V(-4.2, ya + 2.2, 0), 0.98, 0.98, _mix(pumpBlue, 0.12));
    b.cyl(const _V(-4.2, ya + 2.2, 0), const _V(-4.2, ya + 2.28, 0), 0.5, 0.5, black, spec: 0.1);
    b.bolts(const _V(-4.2, ya + 2.2, 0), const _V(0, 1, 0), 0.8, 8, 0.07, 0.08, black);
    // 케이싱 발과 받침
    for (final s in [-1.0, 1.0]) {
      b.box(-4.9, beamTop, s > 0 ? 1.1 : -1.95, -3.5, 1.1, s > 0 ? 1.95 : -1.1, cast);
      b.box(-4.9, 1.1, s > 0 ? 1.1 : -1.5, -3.5, 1.8, s > 0 ? 1.5 : -1.1, cast);
    }
    // 베어링 하우징(브래킷)
    b.cyl(const _V(-3.05, ya, 0), const _V(-1.95, ya, 0), 0.95, 0.82, steelDark);
    b.cyl(const _V(-1.95, ya, 0), const _V(-1.75, ya, 0), 1.0, 1.0, _mix(steelDark, 0.1));
    b.box(-3.0, beamTop, -0.6, -2.1, ya - 0.55, 0.6, cast);
    // 급유창(작은 원통)
    b.cyl(const _V(-2.5, ya + 0.9, 0), const _V(-2.5, ya + 1.18, 0), 0.16, 0.16, const Color(0xFFE1B24A), seg: 16, step: 1);
    // 펌프 축
    b.cyl(const _V(-1.75, ya, 0), const _V(-1.0, ya, 0), 0.28, 0.28, hubSteel, seg: 20, step: 1);

    // ── 커플링
    b.cyl(const _V(-1.0, ya, 0), const _V(-0.14, ya, 0), 0.7, 0.7, hubSteel);
    b.cyl(const _V(-0.14, ya, 0), const _V(0.14, ya, 0), 0.76, 0.76, teal);
    b.cyl(const _V(0.14, ya, 0), const _V(1.0, ya, 0), 0.7, 0.7, hubSteel);
    for (final x in [-0.55, 0.55]) {
      b.bolts(_V(x, ya + 0.7, 0), const _V(0, 1, 0), 0.0, 1, 0.09, 0.06, black);
    }
    // 모터 축
    b.cyl(const _V(1.0, ya, 0), const _V(1.75, ya, 0), 0.28, 0.28, hubSteel, seg: 20, step: 1);

    // ── 다이얼 게이지 두 개(고정 쪽 A 주황, 이동 쪽 B 파랑)
    void dial(double x0, double x1, double zc, Color col, bool contactDown) {
      b.box(x0, ya + 0.78, zc - 0.09, x1, ya + 0.86, zc + 0.09, col, spec: 0.5, step: 0.5);
      final hubX = x1;
      b.box(x0 - 0.02, ya + 0.66, zc - 0.09, x0 + 0.1, ya + 0.86, zc + 0.09, col, spec: 0.5);
      b.cyl(_V(hubX, ya + 0.86, zc), _V(hubX, ya + 1.18, zc), 0.05, 0.05, hubSteel, seg: 12, step: 1);
      // 다이얼 몸통(옆으로 세운 원통)과 하얀 얼굴
      final c = _V(hubX, ya + 1.5, zc);
      b.cyl(c - const _V(0, 0, 0.12), c + const _V(0, 0, 0.12), 0.32, 0.32, col, seg: 28, step: 1, spec: 0.7);
      b.cyl(c + const _V(0, 0, 0.12), c + const _V(0, 0, 0.13), 0.26, 0.26, const Color(0xFFF4F6F8), seg: 28, step: 1, spec: 0.2);
      b.cyl(c - const _V(0, 0, 0.13), c - const _V(0, 0, 0.12), 0.26, 0.26, const Color(0xFFF4F6F8), seg: 28, step: 1, spec: 0.2);
      // 접촉 자리(허브 위)
      b.cyl(_V(hubX, ya + 0.7, zc), _V(hubX, ya + 0.86, zc), 0.03, 0.03, black, seg: 8, step: 1);
    }

    dial(-0.9, 0.5, 0.34, const Color(0xFFE08A1E), true);
    dial(0.9, -0.5, -0.34, const Color(0xFF2F6FE0), false);

    // ── 모터
    // 앞판(구동 쪽 엔드실드)
    b.cyl(const _V(1.75, ya, 0), const _V(2.05, ya, 0), 1.0, 1.42, _mix(motorSteel, -0.1));
    b.cyl(const _V(2.05, ya, 0), const _V(2.3, ya, 0), 1.42, 1.42, _mix(motorSteel, -0.05));
    // 몸통
    b.cyl(const _V(2.3, ya, 0), const _V(6.2, ya, 0), 1.3, 1.3, motorSteel, step: 0.7);
    // 방열핀(축 방향)
    const finCount = 36;
    for (var k = 0; k < finCount; k++) {
      final ang = 2 * math.pi * k / finCount;
      final cy = math.sin(ang), cz = math.cos(ang);
      const r0 = 1.26, r1 = 1.5, th = 0.045;
      final poly = <(double, double)>[
        (ya + cy * r0 - cz * th, cz * r0 + cy * th),
        (ya + cy * r1 - cz * th, cz * r1 + cy * th),
        (ya + cy * r1 + cz * th, cz * r1 - cy * th),
        (ya + cy * r0 + cz * th, cz * r0 - cy * th),
      ];
      b.prismX(2.4, 6.1, poly, motorFin, step: 1.4);
    }
    // 뒤 엔드실드와 팬 덮개
    b.cyl(const _V(6.2, ya, 0), const _V(6.5, ya, 0), 1.42, 1.42, _mix(motorSteel, -0.05));
    b.cyl(const _V(6.5, ya, 0), const _V(7.35, ya, 0), 1.3, 1.08, _mix(motorSteel, -0.12));
    b.cyl(const _V(7.348, ya, 0), const _V(7.36, ya, 0), 0.72, 0.72, black, spec: 0.1);
    // 단자함
    b.box(3.3, ya + 1.32, -0.62, 4.9, ya + 2.05, 0.62, _mix(motorSteel, -0.08), spec: 0.4);
    b.box(3.2, ya + 2.05, -0.72, 5.0, ya + 2.16, 0.72, _mix(motorSteel, 0.05), spec: 0.4);
    // 명판
    b.box(2.9, ya + 0.2, 1.31, 3.5, ya + 0.62, 1.34, const Color(0xFFD7DCE2), spec: 0.5, step: 1);

    // ── 모터 네 발과 심 판
    const footX = 1.0; // 발 길이
    final fronts = [2.4, 4.6]; // 앞발·뒷발 가운데 x
    final shims = [shimFront, shimRear];
    _V front = const _V(0, 0, 0), rear = const _V(0, 0, 0);
    for (var i = 0; i < 2; i++) {
      final xc = fronts[i];
      final col = alignShimColor(shims[i]);
      for (final s in [-1.0, 1.0]) {
        final z0 = s > 0 ? 1.02 : -1.98, z1 = s > 0 ? 1.98 : -1.02;
        // 심 판(발보다 살짝 커서 바깥으로 색이 보인다)
        b.box(xc - footX / 2 - 0.14, beamTop, z0 - 0.1, xc + footX / 2 + 0.14, shimTop, z1 + 0.1, col, spec: 0.5, step: 0.5);
        // 발 판
        b.box(xc - footX / 2, shimTop, z0, xc + footX / 2, shimTop + 0.24, z1, motorSteel, spec: 0.5, step: 0.5);
        // 발 세로 살
        final w0 = s > 0 ? 0.95 : -1.32, w1 = s > 0 ? 1.32 : -0.95;
        b.box(xc - footX / 2, shimTop + 0.24, w0, xc + footX / 2, ya + 0.15, w1, motorSteel, spec: 0.4);
        // 볼트
        final bc = _V(xc, shimTop + 0.24, s * 1.6);
        b.cyl(bc, bc + const _V(0, 0.16, 0), 0.13, 0.13, black, seg: 8, step: 1, spec: 0.8);
        if (s > 0) {
          final anchor = _V(xc, beamTop + 0.07, s * 2.04);
          if (i == 0) {
            front = anchor;
          } else {
            rear = anchor;
          }
        }
      }
    }
    return AlignScene._(b.tris, front, rear);
  }

  static Color _mix(Color c, double t) => t >= 0 ? Color.lerp(c, Colors.white, t)! : Color.lerp(c, Colors.black, -t)!;
}

class AlignRenderPainter extends CustomPainter {
  final AlignScene scene;
  final double yaw, pitch;
  final double shimFront, shimRear, moveFront, moveRear;
  final bool top; // 위에서 본 그림
  final AxisLine? horizontal;
  final double xRear;
  AlignRenderPainter({
    required this.scene,
    required this.yaw,
    required this.pitch,
    required this.shimFront,
    required this.shimRear,
    required this.moveFront,
    required this.moveRear,
    this.top = false,
    this.horizontal,
    this.xRear = 0,
  });

  static const _target = _V(0.4, 1.2, 0);
  static const double _dist = 30;

  @override
  void paint(Canvas canvas, Size size) {
    final cp = math.cos(pitch), sp = math.sin(pitch);
    // 카메라가 보는 방향 d(카메라 → 장면). yaw 0 = 앞쪽(+z)에서 봄, 늘리면 펌프 쪽으로 돈다.
    final d = _V(cp * math.sin(yaw), -sp, -cp * math.cos(yaw));
    final right = d.cross(const _V(0, 1, 0)).unit;
    final up = right.cross(d).unit;
    final cam = _target - d * _dist;
    final light = (right * -0.5 + up * 0.8 + d * -0.55).unit;
    final half = (light - d).unit;

    final padTop = top ? 44.0 : 6.0;
    final padBottom = top ? 44.0 : 72.0;
    final availH = size.height - padTop - padBottom;

    // 화면 좌표(단위 크기): 원근
    (double, double, double) proj(_V v) {
      final rel = v - cam;
      final z = rel.dot(d);
      return (rel.dot(right) / z, -rel.dot(up) / z, z);
    }

    // 장면이 딱 들어오게 상자 모서리로 크기를 맞춘다
    var minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9;
    for (final x in top ? [-2.9, 7.8] : [-6.7, 7.5]) {
      for (final y in top ? [0.0, 3.0] : [0.0, 5.0]) {
        for (final z in [-2.4, 2.4]) {
          final p = proj(_V(x, y, z));
          minX = math.min(minX, p.$1);
          maxX = math.max(maxX, p.$1);
          minY = math.min(minY, p.$2);
          maxY = math.max(maxY, p.$2);
        }
      }
    }
    final scale = math.min((size.width - 16) / (maxX - minX), availH / (maxY - minY));
    final ox = size.width / 2 - (minX + maxX) / 2 * scale;
    final oy = padTop + availH / 2 - (minY + maxY) / 2 * scale;
    Offset toScreen(_V v) {
      final p = proj(v);
      return Offset(ox + p.$1 * scale, oy + p.$2 * scale);
    }

    if (top) canvas.clipRect(Offset.zero & size);

    // 바닥 그림자
    final shadow = Path()
      ..addPolygon([toScreen(const _V(-6.9, 0, -2.5)), toScreen(const _V(7.7, 0, -2.5)), toScreen(const _V(7.7, 0, 2.5)), toScreen(const _V(-6.9, 0, 2.5))], true);
    canvas.drawPath(shadow.shift(const Offset(0, 6)), Paint()..color = Colors.black.withValues(alpha: 0.16)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));

    // 앞뒤 정렬(먼 것부터)과 조명
    final tris = scene.tris;
    final keep = <int>[];
    final depth = Float64List(tris.length);
    for (var i = 0; i < tris.length; i++) {
      final t = tris[i];
      final cx = (t.a.x + t.b.x + t.c.x) / 3, cy = (t.a.y + t.b.y + t.c.y) / 3, cz = (t.a.z + t.b.z + t.c.z) / 3;
      final nx = t.na.x + t.nb.x + t.nc.x, ny = t.na.y + t.nb.y + t.nc.y, nz = t.na.z + t.nb.z + t.nc.z;
      final toCam = _V(cam.x - cx, cam.y - cy, cam.z - cz);
      if (nx * toCam.x + ny * toCam.y + nz * toCam.z <= 0) continue;
      depth[i] = (cx - cam.x) * d.x + (cy - cam.y) * d.y + (cz - cam.z) * d.z;
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
        final hemi = 0.5 + 0.5 * n.y;
        final spec = t.spec * math.pow(math.max(0.0, n.dot(half)), 40).toDouble() * 255;
        final inten = 0.34 + 0.6 * diff + 0.14 * hemi;
        int ch(double base) => (base * inten + spec).round().clamp(0, 255);
        cols[k * 3 + j] = (0xFF << 24) | (ch(t.r) << 16) | (ch(t.g) << 8) | ch(t.bl);
      }
    }
    final verts = ui.Vertices.raw(ui.VertexMode.triangles, pos, colors: cols);
    canvas.drawVertices(verts, BlendMode.dst, Paint()..isAntiAlias = true);

    if (top) {
      _paintTopOverlay(canvas, size, toScreen);
      return;
    }

    // 심 표시 지시선과 라벨(앞발·뒷발은 오른쪽·왼쪽 발이 같은 값)
    void footLabel(_V anchor, double mm, double moveMm, String row, Offset at) {
      final a = toScreen(anchor);
      final c = alignShimColor(mm);
      canvas.drawLine(a, at - const Offset(0, 24), Paint()..color = c..strokeWidth = 1.4);
      canvas.drawCircle(a, 3, Paint()..color = c);
      alignLabel(canvas, '$row\n심 ${alignShimShort(mm)}\n${alignMoveShort(moveMm)}', at, c, minWidth: 108);
    }

    Offset clampChip(Offset o) => Offset(o.dx.clamp(58.0, size.width - 58), o.dy.clamp(30.0, size.height - 32));
    final fa = toScreen(scene.frontShimAnchor), ra = toScreen(scene.rearShimAnchor);
    var frontAt = clampChip(Offset(fa.dx - 62, fa.dy + 52));
    var rearAt = clampChip(Offset(ra.dx + 62, ra.dy + 52));
    if (rearAt.dx - frontAt.dx < 118) {
      final mid = (rearAt.dx + frontAt.dx) / 2;
      frontAt = clampChip(Offset(mid - 59, frontAt.dy));
      rearAt = clampChip(Offset(mid + 59, rearAt.dy));
    }
    footLabel(scene.frontShimAnchor, shimFront, moveFront, '앞발', frontAt);
    footLabel(scene.rearShimAnchor, shimRear, moveRear, '뒷발', rearAt);

    // 이름표
    void name(String t, _V at, Color c) {
      final tp = TextPainter(
        text: TextSpan(text: t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: c)),
        textDirection: TextDirection.ltr,
      )..layout();
      final o = toScreen(at);
      tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
    }

    name('펌프 (고정)', const _V(-4.2, 5.3, 0), AppColors.textSub);
    name('모터 (이동)', const _V(4.6, 4.9, 0), AppColors.textSub);
  }

  void _paintTopOverlay(Canvas canvas, Size size, Offset Function(_V) toScreen) {
    // 지금 모터 위치(점선): 옆 어긋남을 크게 부풀린 것
    final h = horizontal;
    if (h != null) {
      final zc = h.at(0), zEnd = h.at(xRear);
      final zMax = math.max(math.max(zc.abs(), zEnd.abs()), math.max(moveFront.abs(), moveRear.abs()));
      final k = zMax < 1e-6 ? 0.0 : 0.55 / zMax;
      const yTop = AlignScene.ya + 1.32;
      final ghost = Path()
        ..addPolygon([
          toScreen(_V(2.3, yTop, -1.5 + zc * k)),
          toScreen(_V(6.2, yTop, -1.5 + zEnd * k)),
          toScreen(_V(6.2, yTop, 1.5 + zEnd * k)),
          toScreen(_V(2.3, yTop, 1.5 + zc * k)),
        ], true);
      alignDashPath(canvas, ghost, Paint()..color = alignCaution..style = PaintingStyle.stroke..strokeWidth = 2.2);
    }
    // 목표 중심선(펌프 축)
    final c0 = toScreen(const _V(-7.0, AlignScene.ya + 1.6, 0)), c1 = toScreen(const _V(7.6, AlignScene.ya + 1.6, 0));
    alignDashPath(canvas, Path()..moveTo(c0.dx, c0.dy)..lineTo(c1.dx, c1.dy), Paint()..color = AppColors.text.withValues(alpha: 0.55)..style = PaintingStyle.stroke..strokeWidth = 1.4);

    // 네 발 심 표찰
    final xs = [2.4, 4.6];
    final shims = [shimFront, shimRear];
    for (var i = 0; i < 2; i++) {
      for (final s in [-1.0, 1.0]) {
        final a = toScreen(_V(xs[i], AlignScene.shimTop + 0.24, s * 2.0));
        final at = a + Offset(i == 0 ? -7 : 7, s * 32);
        final c = alignShimColor(shims[i]);
        canvas.drawLine(a, at - Offset(0, s * 14), Paint()..color = c..strokeWidth = 1.3);
        alignLabel(canvas, '${i == 0 ? '앞' : '뒤'}·${s < 0 ? '왼' : '오른'}\n${alignShimShort(shims[i])}', at, c, size: 10, minWidth: 58);
      }
    }
    // 옆으로 미는 방향
    final moves = [moveFront, moveRear];
    for (var i = 0; i < 2; i++) {
      final mm = moves[i];
      final o = toScreen(_V(xs[i], AlignScene.ya + 1.6, 0));
      if (mm.abs() < 0.005) {
        alignLabel(canvas, '옆 그대로', o, alignOk, size: 10);
        continue;
      }
      final dir = mm > 0 ? 1.0 : -1.0;
      final p = Paint()..color = AppColors.brand..strokeWidth = 3.4..strokeCap = StrokeCap.round;
      final a = o - Offset(0, dir * 18), b = o + Offset(0, dir * 18);
      canvas.drawLine(a, b, p);
      canvas.drawLine(b, b + Offset(-6, -dir * 9), p);
      canvas.drawLine(b, b + Offset(6, -dir * 9), p);
      alignLabel(canvas, '옆 밀기\n${mm > 0 ? '오른쪽' : '왼쪽'} ${mm.abs().toStringAsFixed(2)}', o + Offset(i == 0 ? -7 : 7, dir * 46), AppColors.brand, size: 10, minWidth: 58);
    }
    void txt(String t, Offset at, Color c) {
      final tp = TextPainter(
        text: TextSpan(text: t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at);
    }

    txt('왼쪽 ▲', const Offset(8, 6), AppColors.textSub);
    txt('오른쪽 ▼', Offset(8, size.height - 20), AppColors.textSub);
    txt('점선 = 지금 모터 위치(크게 부풀림)', Offset(size.width - 196, 6), alignCaution);
    txt('◀ 펌프(고정) 쪽', Offset(8, size.height - 38), AppColors.textSub);
    final mn = toScreen(const _V(7.3, 0.2, 2.75));
    txt('모터 (이동)', mn - const Offset(28, -2), AppColors.textSub);
  }

  @override
  bool shouldRepaint(covariant AlignRenderPainter old) =>
      old.top != top ||
      old.xRear != xRear ||
      old.horizontal?.v0 != horizontal?.v0 ||
      old.horizontal?.slope != horizontal?.slope ||
      old.yaw != yaw ||
      old.pitch != pitch ||
      old.scene != scene ||
      old.shimFront != shimFront ||
      old.shimRear != shimRear ||
      old.moveFront != moveFront ||
      old.moveRear != moveRear;
}

/// 좌우로 끌면 돌아가는 입체 그림. 두 번 누르면 처음 각도로 돌아온다.
class AlignRenderView extends StatefulWidget {
  final double shimFront, shimRear, moveFront, moveRear;
  final bool top;
  final AxisLine? horizontal;
  final double xRear;
  const AlignRenderView({
    super.key,
    required this.shimFront,
    required this.shimRear,
    required this.moveFront,
    required this.moveRear,
    this.top = false,
    this.horizontal,
    this.xRear = 0,
  });

  @override
  State<AlignRenderView> createState() => _AlignRenderViewState();
}

class _AlignRenderViewState extends State<AlignRenderView> {
  static const _yaw0 = 0.62, _pitch0 = 0.40, _topPitch = 1.53;
  double _yaw = _yaw0;
  final double _pitch = _pitch0;
  late AlignScene _scene;

  @override
  void initState() {
    super.initState();
    _scene = AlignScene.build(shimFront: widget.shimFront, shimRear: widget.shimRear);
  }

  @override
  void didUpdateWidget(covariant AlignRenderView old) {
    super.didUpdateWidget(old);
    if (old.shimFront != widget.shimFront || old.shimRear != widget.shimRear) {
      _scene = AlignScene.build(shimFront: widget.shimFront, shimRear: widget.shimRear);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: widget.top ? null : (d) => setState(() => _yaw = (_yaw - d.delta.dx * 0.008).clamp(-1.4, 1.9)),
      onDoubleTap: widget.top ? null : () => setState(() => _yaw = _yaw0),
      child: CustomPaint(
        size: Size.infinite,
        painter: AlignRenderPainter(
          scene: _scene,
          yaw: widget.top ? 0 : _yaw,
          pitch: widget.top ? _topPitch : _pitch,
          top: widget.top,
          horizontal: widget.horizontal,
          xRear: widget.xRear,
          shimFront: widget.shimFront,
          shimRear: widget.shimRear,
          moveFront: widget.moveFront,
          moveRear: widget.moveRear,
        ),
      ),
    );
  }
}
