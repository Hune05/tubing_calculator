import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../models/instrument_shape_painter.dart' show InstrumentShape;
import '../models/layout_board_models.dart';
import '../models/skid_iso.dart';
import '../models/skid_route.dart';

// 🚀 스키드 입체 보기(보기 전용). 평면에 놓은 부품과 전선관 경로를 그대로 세워 한 화면에 보여 준다.
// 한 손가락으로 돌리고, 두 손가락으로 확대·이동하고, 부품을 누르면 이름과 크기가 나온다.
// 계산은 models/skid_iso.dart, 이 파일은 그리기(그림자·면 명암·관 입체감·치수선·이름)와 손가락 움직임만 맡는다.

/// 그리는 동안 알아낸 "어디를 누르면 어느 부품인가". 그린 차례대로 쌓이고 마지막이 맨 앞이다.
class IsoHits {
  final List<(String, Path)> shapes = [];
  void clear() => shapes.clear();

  String? partAt(Offset p) {
    for (var i = shapes.length - 1; i >= 0; i--) {
      if (shapes[i].$2.contains(p)) return shapes[i].$1;
    }
    return null;
  }
}

/// 색 밝기를 [f]배로(1보다 크면 밝게, 작으면 어둡게).
Color _shade(Color c, double f) {
  int ch(double v) => (v * 255 * f).round().clamp(0, 255);
  return Color.fromARGB(255, ch(c.r), ch(c.g), ch(c.b));
}

class _Chunk {
  final double near;
  final IsoBox? box;
  final IsoPipe? pipe;
  _Chunk(this.near, {this.box, this.pipe});
}

/// 조각이 이만큼 넘게 많으면 긴 부품을 자르지 않는다(느려지지 않게).
const int _kSplitOffAbove = 700;

/// 볼록 껍질(그림자 모양). 점이 몇 개 안 돼서 단순한 방법으로 충분하다.
List<Offset> _hull(List<Offset> pts) {
  final p = [...pts]
    ..sort((a, b) => a.dx != b.dx ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy));
  double cross(Offset o, Offset a, Offset b) =>
      (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
  final lower = <Offset>[];
  for (final q in p) {
    while (lower.length >= 2 &&
        cross(lower[lower.length - 2], lower.last, q) <= 0) {
      lower.removeLast();
    }
    lower.add(q);
  }
  final upper = <Offset>[];
  for (final q in p.reversed) {
    while (upper.length >= 2 &&
        cross(upper[upper.length - 2], upper.last, q) <= 0) {
      upper.removeLast();
    }
    upper.add(q);
  }
  lower.removeLast();
  upper.removeLast();
  return [...lower, ...upper];
}

class SkidIsoPainter extends CustomPainter {
  final IsoScene scene;
  final IsoView view;
  final IsoFit fit;
  final double zoom;
  final Offset pan;
  final String? selectedId;
  final IsoHits hits;
  final bool dark;
  final bool showLabels;
  final Map<String, String> labels;

  const SkidIsoPainter({
    required this.scene,
    required this.view,
    required this.fit,
    required this.zoom,
    required this.pan,
    required this.selectedId,
    required this.hits,
    required this.dark,
    required this.showLabels,
    required this.labels,
  });

  Color get _edge => dark ? const Color(0x80FFFFFF) : const Color(0x66000000);
  Color get _text => dark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);
  static const Color _accent = Color(0xFFF97316);

  /// 상자 하나를 길이 방향(가장 긴 수평 변)으로 조각낸다.
  List<IsoBox> _splitBox(IsoBox b, bool allow) {
    if (!allow) return [b];
    final double lx = b.x1 - b.x0, ly = b.y1 - b.y0;
    final bool alongX = lx >= ly;
    final double len = alongX ? lx : ly;
    final double other = alongX ? ly : lx;
    final double step = math.max(other * 2, 400);
    final int n = math.min(8, (len / step).ceil());
    if (n <= 1) return [b];
    return [
      for (var i = 0; i < n; i++)
        alongX
            ? IsoBox(
                b.x0 + len * i / n,
                b.y0,
                b.z0,
                b.x0 + len * (i + 1) / n,
                b.y1,
                b.z1,
                b.color,
                partId: b.partId,
                cutLo: i > 0,
                cutHi: i < n - 1,
                cutAlongX: true,
              )
            : IsoBox(
                b.x0,
                b.y0 + len * i / n,
                b.z0,
                b.x1,
                b.y0 + len * (i + 1) / n,
                b.z1,
                b.color,
                partId: b.partId,
                cutLo: i > 0,
                cutHi: i < n - 1,
                cutAlongX: false,
              ),
    ];
  }

  List<IsoPipe> _splitPipe(IsoPipe p, bool allow) {
    if (!allow) return [p];
    final vm.Vector3 d = p.b - p.a;
    final double len = d.length;
    final int n = math.min(8, (len / math.max(p.od * 8, 400)).ceil());
    if (n <= 1) return [p];
    return [
      for (var i = 0; i < n; i++)
        IsoPipe(
          p.a + d * (i / n),
          p.a + d * ((i + 1) / n),
          p.od,
          p.color,
          partId: p.partId,
          round: p.round,
        ),
    ];
  }

  void _label(
    Canvas canvas,
    String text,
    Offset center, {
    double size = 11,
    Color? color,
    Color? bg,
    List<Rect>? taken,
    bool force = true,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: color ?? _text,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 140);
    final Rect r = Rect.fromCenter(
      center: center,
      width: tp.width + 10,
      height: tp.height + 5,
    );
    if (!force && taken != null && taken.any((t) => t.overlaps(r))) return;
    taken?.add(r);
    if (bg != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(6)),
        Paint()..color = bg,
      );
    }
    tp.paint(canvas, r.topLeft + const Offset(5, 2.5));
  }

  @override
  void paint(Canvas canvas, Size size) {
    hits.clear();
    final b = scene.bounds;
    final vm.Vector3 c = (b.min + b.max) * 0.5;
    final double scale = fit.scale * zoom;
    final Offset origin =
        Offset(size.width / 2, size.height / 2) + fit.shift * zoom + pan;
    Offset pt(double x, double y, double z) {
      final q = view.project(vm.Vector3(x, y, z), c);
      return Offset(origin.dx + q.sx * scale, origin.dy + q.sy * scale);
    }

    Offset pv(vm.Vector3 v) => pt(v.x, v.y, v.z);

    final double cyw = math.cos(view.yaw), syw = math.sin(view.yaw);
    final bool showTop = view.pitch > 0.01;
    final double fl = scene.floorLength, fw = scene.floorWidth;
    final double diag = (b.max - b.min).length;

    // 상자 한 면을 그린다. [v]는 네 모서리(스키드 좌표), [f]는 밝기 배수.
    // 길이 방향으로 자른 이음 자리의 테두리는 긋지 않는다.
    void drawFace(
      IsoBox bx,
      List<(double, double, double)> v,
      Color base,
      double f, {
      required bool top,
    }) {
      final pts = [for (final q in v) pt(q.$1, q.$2, q.$3)];
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      path.close();
      // 면 안 명암: 위 면은 비스듬히 밝은→약간 어두운, 옆면은 위가 밝고 아래가 어둡다.
      final fill = Paint();
      if (top) {
        final a = pts[0], z = pts[2];
        if ((a - z).distance > 0.5) {
          fill.shader = ui.Gradient.linear(a, z, [
            _shade(base, f * 1.1),
            _shade(base, f * 0.93),
          ]);
        } else {
          fill.color = _shade(base, f);
        }
      } else {
        double lo = pts[0].dy, hi = pts[0].dy;
        for (final q in pts) {
          lo = math.min(lo, q.dy);
          hi = math.max(hi, q.dy);
        }
        if (hi - lo > 0.5) {
          fill.shader = ui.Gradient.linear(Offset(0, lo), Offset(0, hi), [
            _shade(base, f * 1.04),
            _shade(base, f * 0.78),
          ]);
        } else {
          fill.color = _shade(base, f);
        }
      }
      canvas.drawPath(path, fill);
      // 조각 사이 틈이 비쳐 보이지 않게 같은 색으로 살짝 덮는다.
      canvas.drawPath(
        path,
        Paint()
          ..color = _shade(base, f)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
      final bool sel = bx.partId != null && bx.partId == selectedId;
      final edge = Paint()
        ..color = sel ? _accent : _edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = sel ? 2.0 : 0.6
        ..strokeCap = StrokeCap.round;
      bool onCut(double a, double b2, double lo, double hi) =>
          (bx.cutLo && a == lo && b2 == lo) || (bx.cutHi && a == hi && b2 == hi);
      for (var i = 0; i < 4; i++) {
        final a = v[i], b2 = v[(i + 1) % 4];
        final bool seam = bx.cutAlongX
            ? onCut(a.$1, b2.$1, bx.x0, bx.x1)
            : onCut(a.$2, b2.$2, bx.y0, bx.y1);
        if (!seam) canvas.drawLine(pts[i], pts[(i + 1) % 4], edge);
      }
      // 위 면의 앞쪽 모서리에 밝은 선을 한 줄 더해 각진 느낌을 낸다.
      if (top && !sel) {
        canvas.drawLine(
          pts[2],
          pts[3],
          Paint()
            ..color = const Color(0x55FFFFFF)
            ..strokeWidth = 1.0,
        );
      }
      if (bx.partId != null) hits.shapes.add((bx.partId!, path));
    }

    void drawBox(IsoBox bx) {
      final x0 = bx.x0, x1 = bx.x1, y0 = bx.y0, y1 = bx.y1;
      final z0 = bx.z0, z1 = bx.z1;
      final sides = <(double, double, List<(double, double, double)>)>[
        (-1, 0, [(x0, y0, z0), (x0, y1, z0), (x0, y1, z1), (x0, y0, z1)]),
        (1, 0, [(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)]),
        (0, -1, [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)]),
        (0, 1, [(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)]),
      ];
      for (final s in sides) {
        // 잘린 이음 면은 안쪽이라 그리지 않는다.
        if (bx.cutAlongX) {
          if ((s.$1 == -1 && bx.cutLo) || (s.$1 == 1 && bx.cutHi)) continue;
        } else {
          if ((s.$2 == -1 && bx.cutLo) || (s.$2 == 1 && bx.cutHi)) continue;
        }
        final double nyr = s.$1 * syw + s.$2 * cyw;
        if (nyr <= 1e-6) continue;
        final double nxr = s.$1 * cyw - s.$2 * syw;
        drawFace(bx, s.$3, bx.color, 0.76 - 0.16 * nxr, top: false);
      }
      if (showTop) {
        drawFace(
          bx,
          [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)],
          bx.color,
          1.0,
          top: true,
        );
      }
    }

    // ── 바닥 판(두께 있는 철판) + 격자 ──
    if (fl > 0 && fw > 0) {
      final slab = IsoBox(
        0,
        0,
        -math.max(30.0, diag * 0.012),
        fl,
        fw,
        0,
        dark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
      );
      drawBox(slab);
      final double step = niceGridStep(math.max(fl, fw));
      final grid = Paint()
        ..color = dark ? const Color(0x26FFFFFF) : const Color(0x26000000)
        ..strokeWidth = 0.6
        ..style = PaintingStyle.stroke;
      if (showTop) {
        for (double x = step; x < fl - 1e-6; x += step) {
          canvas.drawLine(pt(x, 0, 0), pt(x, fw, 0), grid);
        }
        for (double y = step; y < fw - 1e-6; y += step) {
          canvas.drawLine(pt(0, y, 0), pt(fl, y, 0), grid);
        }

        // 그림자: 한 번에 모아 그려서 겹쳐도 더 진해지지 않게 한다.
        final clip = Path()
          ..moveTo(pt(0, 0, 0).dx, pt(0, 0, 0).dy)
          ..lineTo(pt(fl, 0, 0).dx, pt(fl, 0, 0).dy)
          ..lineTo(pt(fl, fw, 0).dx, pt(fl, fw, 0).dy)
          ..lineTo(pt(0, fw, 0).dx, pt(0, fw, 0).dy)
          ..close();
        canvas.save();
        canvas.clipPath(clip);
        canvas.saveLayer(
          null,
          Paint()..color = Colors.black.withValues(alpha: dark ? 0.45 : 0.24),
        );
        final black = Paint()..color = Colors.black;
        const double kx = 0.45, ky = -0.30;
        for (final bx in scene.boxes) {
          final double h = math.max(bx.z1, 0);
          if (h <= 0) continue;
          final pts = <Offset>[
            for (final xy in [
              (bx.x0, bx.y0),
              (bx.x1, bx.y0),
              (bx.x1, bx.y1),
              (bx.x0, bx.y1),
            ]) ...[pt(xy.$1, xy.$2, 0), pt(xy.$1 + kx * h, xy.$2 + ky * h, 0)],
          ];
          final hull = _hull(pts);
          if (hull.length < 3) continue;
          final path = Path()..moveTo(hull[0].dx, hull[0].dy);
          for (var i = 1; i < hull.length; i++) {
            path.lineTo(hull[i].dx, hull[i].dy);
          }
          canvas.drawPath(path..close(), black);
        }
        for (final pp in scene.pipes) {
          final double h0 = math.max(pp.a.z, 0), h1 = math.max(pp.b.z, 0);
          canvas.drawLine(
            pt(pp.a.x + kx * h0, pp.a.y + ky * h0, 0),
            pt(pp.b.x + kx * h1, pp.b.y + ky * h1, 0),
            Paint()
              ..color = Colors.black
              ..strokeWidth = math.max(pp.od * scale * 0.9, 2)
              ..strokeCap = StrokeCap.round,
          );
        }
        canvas.restore();
        canvas.restore();
      }
    }

    // ── 조각 줄 세우기(먼 것부터) ──
    final bool allowSplit =
        scene.boxes.length + scene.pipes.length < _kSplitOffAbove;
    final chunks = <_Chunk>[];
    for (final box in scene.boxes) {
      for (final s in _splitBox(box, allowSplit)) {
        final q = view.project(vm.Vector3(s.cx, s.cy, s.cz), c);
        chunks.add(_Chunk(q.near, box: s));
      }
    }
    for (final pipe in scene.pipes) {
      for (final s in _splitPipe(pipe, allowSplit)) {
        final m = (s.a + s.b) * 0.5;
        chunks.add(_Chunk(view.project(m, c).near, pipe: s));
      }
    }
    chunks.sort((a, b) => a.near.compareTo(b.near));

    for (final ch in chunks) {
      final bx = ch.box;
      if (bx != null) {
        drawBox(bx);
        continue;
      }
      final p = ch.pipe!;
      final Offset a = pv(p.a), e = pv(p.b);
      final double w = math.max(p.od * scale, 3.0);
      final bool sel = p.partId != null && p.partId == selectedId;
      final StrokeCap cap = p.round ? StrokeCap.round : StrokeCap.butt;
      // 관 방향이 보는 방향과 거의 같으면(끝이 정면으로 보임) 동그라미로 그린다.
      final double len3 = (p.b - p.a).length * scale;
      if (!p.round && len3 > 0 && (e - a).distance < len3 * 0.22) {
        final Offset mid = (a + e) / 2;
        final Rect rr = Rect.fromCircle(center: mid, radius: w / 2);
        if (sel) {
          canvas.drawCircle(mid, w / 2 + 2.5, Paint()..color = _accent);
        }
        canvas.drawCircle(
          mid,
          w / 2,
          Paint()
            ..shader = ui.Gradient.radial(
              mid.translate(-w * 0.15, -w * 0.15),
              w * 0.7,
              [_shade(p.color, 1.15), _shade(p.color, 0.7)],
            ),
        );
        canvas.drawCircle(
          mid,
          w / 2,
          Paint()
            ..color = _edge
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.6,
        );
        if (p.partId != null) {
          hits.shapes.add((p.partId!, Path()..addOval(rr)));
        }
        continue;
      }
      if (sel) {
        canvas.drawLine(
          a,
          e,
          Paint()
            ..color = _accent
            ..strokeWidth = w + 5
            ..strokeCap = cap,
        );
      }
      // 관을 둥글게 보이게: 어두운 바탕 → 본색 → 밝은 줄(왼쪽 위에서 빛이 온다).
      canvas.drawLine(
        a,
        e,
        Paint()
          ..color = _shade(p.color, 0.62)
          ..strokeWidth = w
          ..strokeCap = cap,
      );
      canvas.drawLine(
        a,
        e,
        Paint()
          ..color = _shade(p.color, 1.0)
          ..strokeWidth = w * 0.72
          ..strokeCap = cap,
      );
      canvas.drawLine(
        a.translate(-w * 0.1, -w * 0.18),
        e.translate(-w * 0.1, -w * 0.18),
        Paint()
          ..color = const Color(0x66FFFFFF)
          ..strokeWidth = math.max(w * 0.22, 1.2)
          ..strokeCap = cap,
      );
      if (p.partId != null) {
        final Offset d = e - a;
        final double len = d.distance;
        final Offset nrm = len < 1e-6
            ? Offset(0, w / 2)
            : Offset(-d.dy / len * w / 2, d.dx / len * w / 2);
        final quad = Path()
          ..moveTo((a + nrm).dx, (a + nrm).dy)
          ..lineTo((e + nrm).dx, (e + nrm).dy)
          ..lineTo((e - nrm).dx, (e - nrm).dy)
          ..lineTo((a - nrm).dx, (a - nrm).dy)
          ..close();
        hits.shapes.add((p.partId!, quad));
      }
    }

    // ── 치수선(길이·폭·높이) ──
    if (fl > 0 && fw > 0) {
      final double off = math.max(diag * 0.06, 80);
      final Paint dimPaint = Paint()
        ..color = _text.withValues(alpha: 0.75)
        ..strokeWidth = 1.0;
      final taken = <Rect>[];
      void dim(vm.Vector3 p0, vm.Vector3 p1, vm.Vector3 out, String text) {
        final vm.Vector3 q0 = p0 + out * off, q1 = p1 + out * off;
        final Offset s0 = pv(p0), s1 = pv(p1), t0 = pv(q0), t1 = pv(q1);
        canvas.drawLine(s0, pv(p0 + out * (off * 1.12)), dimPaint);
        canvas.drawLine(s1, pv(p1 + out * (off * 1.12)), dimPaint);
        canvas.drawLine(t0, t1, dimPaint);
        final Offset d = t1 - t0;
        final double len = d.distance;
        if (len > 1) {
          final Offset n = Offset(-d.dy / len, d.dx / len) * 5;
          canvas.drawLine(t0 - n, t0 + n, dimPaint);
          canvas.drawLine(t1 - n, t1 + n, dimPaint);
        }
        _label(
          canvas,
          text,
          (t0 + t1) / 2,
          size: 11,
          bg: dark ? const Color(0xE60F172A) : const Color(0xE6FFFFFF),
          taken: taken,
        );
      }

      String mm(double v) => v.round().toString();
      dim(
        vm.Vector3(0, fw, 0),
        vm.Vector3(fl, fw, 0),
        vm.Vector3(0, 1, 0),
        mm(fl),
      );
      dim(
        vm.Vector3(fl, 0, 0),
        vm.Vector3(fl, fw, 0),
        vm.Vector3(1, 0, 0),
        mm(fw),
      );
      if (b.max.z > 1 && view.pitch < math.pi / 2 - 0.05) {
        final double s = math.sqrt1_2;
        dim(
          vm.Vector3(fl, fw, 0),
          vm.Vector3(fl, fw, b.max.z),
          vm.Vector3(s * 1.8, s * 1.8, 0),
          mm(b.max.z),
        );
      }
    }

    // ── 부품 이름 ──
    if (showLabels) {
      final spans = <String, ({vm.Vector3 min, vm.Vector3 max})>{};
      void grow(String id, vm.Vector3 lo, vm.Vector3 hi) {
        final cur = spans[id];
        if (cur == null) {
          spans[id] = (min: lo.clone(), max: hi.clone());
        } else {
          spans[id] = (
            min: vm.Vector3(
              math.min(cur.min.x, lo.x),
              math.min(cur.min.y, lo.y),
              math.min(cur.min.z, lo.z),
            ),
            max: vm.Vector3(
              math.max(cur.max.x, hi.x),
              math.max(cur.max.y, hi.y),
              math.max(cur.max.z, hi.z),
            ),
          );
        }
      }

      for (final bx in scene.boxes) {
        if (bx.partId != null) {
          grow(
            bx.partId!,
            vm.Vector3(bx.x0, bx.y0, bx.z0),
            vm.Vector3(bx.x1, bx.y1, bx.z1),
          );
        }
      }
      for (final pp in scene.pipes) {
        if (pp.partId != null) {
          final h = pp.od / 2;
          grow(
            pp.partId!,
            vm.Vector3(
              math.min(pp.a.x, pp.b.x) - h,
              math.min(pp.a.y, pp.b.y) - h,
              math.min(pp.a.z, pp.b.z) - h,
            ),
            vm.Vector3(
              math.max(pp.a.x, pp.b.x) + h,
              math.max(pp.a.y, pp.b.y) + h,
              math.max(pp.a.z, pp.b.z) + h,
            ),
          );
        }
      }
      final taken = <Rect>[];
      double vol(String id) {
        final s = spans[id]!;
        final d = s.max - s.min;
        return d.x * d.y + d.x * d.z + d.y * d.z;
      }

      // 큰 부품부터 이름을 달아 작은 것이 큰 것 이름을 가리지 않게 한다.
      final ids = spans.keys.toList()..sort((a, b2) => vol(b2).compareTo(vol(a)));
      for (final id in ids) {
        final s = spans[id]!;
        final text = labels[id];
        if (text == null || text.isEmpty) continue;
        final Offset at = pt(
          (s.min.x + s.max.x) / 2,
          (s.min.y + s.max.y) / 2,
          s.max.z,
        ).translate(0, -10);
        final bool sel = id == selectedId;
        _label(
          canvas,
          text,
          at,
          size: 10.5,
          color: sel ? Colors.white : _text,
          bg: sel
              ? _accent
              : (dark ? const Color(0xCC0F172A) : const Color(0xD9FFFFFF)),
          taken: taken,
          force: sel,
        );
      }
    }

    // ── 방향 표시(왼쪽 아래): 길이·폭·높이 방향이 지금 시점에서 어디로 향하는지 ──
    {
      final Offset o = Offset(34, size.height - 34);
      final q0 = view.project(vm.Vector3.zero(), vm.Vector3.zero());
      void axis(vm.Vector3 u, Color col, String name) {
        final q = view.project(u, vm.Vector3.zero());
        final Offset d = Offset(q.sx - q0.sx, q.sy - q0.sy) * 24;
        canvas.drawLine(
          o,
          o + d,
          Paint()
            ..color = col
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round,
        );
        final double len = d.distance;
        _label(
          canvas,
          name,
          o + (len < 1 ? Offset.zero : d * (1 + 9 / len)),
          size: 10,
          color: col,
        );
      }

      axis(vm.Vector3(1, 0, 0), const Color(0xFFEF4444), '길이');
      axis(vm.Vector3(0, 1, 0), const Color(0xFF22C55E), '폭');
      axis(vm.Vector3(0, 0, 1), const Color(0xFF3B82F6), '높이');
    }
  }

  @override
  bool shouldRepaint(covariant SkidIsoPainter old) =>
      old.scene != scene ||
      old.view.yaw != view.yaw ||
      old.view.pitch != view.pitch ||
      old.zoom != zoom ||
      old.pan != pan ||
      old.fit != fit ||
      old.selectedId != selectedId ||
      old.dark != dark ||
      old.showLabels != showLabels;
}

class SkidIsoPage extends StatefulWidget {
  /// 평면 부품(메모 포함, 메모는 걸러서 그린다).
  final List<PlacedItem> plan;
  final List<ConduitRoute> routes;

  /// 스키드 평면 크기(길이 × 폭, mm).
  final double length;
  final double width;

  const SkidIsoPage({
    super.key,
    required this.plan,
    required this.routes,
    required this.length,
    required this.width,
  });

  @override
  State<SkidIsoPage> createState() => _SkidIsoPageState();
}

class _SkidIsoPageState extends State<SkidIsoPage> {
  late final IsoScene _scene = buildSkidIsoScene(
    widget.plan,
    widget.routes,
    length: widget.length,
    width: widget.width,
  );
  late final Map<String, String> _labels = {
    for (final it in widget.plan)
      if (it.shape != InstrumentShape.note) it.id: it.label,
  };
  final IsoHits _hits = IsoHits();
  IsoView _view = IsoView.standard;
  double _zoom = 1;
  double _zoom0 = 1;
  Offset _pan = Offset.zero;
  String? _selected;
  bool _showLabels = false;
  IsoFit? _fit;
  Size? _fitSize;

  static const _presets = <(String, String, IsoView)>[
    ('iso_standard', '입체', IsoView.standard),
    ('iso_front', '정면', IsoView.front),
    ('iso_right', '오른쪽', IsoView.right),
    ('iso_left', '왼쪽', IsoView.left),
    ('iso_back', '뒤', IsoView.back),
    ('iso_top', '위', IsoView.top),
  ];

  void _setView(IsoView v) => setState(() {
    _view = v;
    _zoom = 1;
    _pan = Offset.zero;
    _fit = null;
  });

  bool _isPreset(IsoView v) =>
      (_view.yaw - v.yaw).abs() < 1e-6 && (_view.pitch - v.pitch).abs() < 1e-6;

  PlacedItem? get _selectedItem {
    for (final it in widget.plan) {
      if (it.id == _selected) return it;
    }
    return null;
  }

  String _mm(double v) => v.round().toString();

  String _info() {
    final it = _selectedItem;
    if (it != null) {
      final double v = skidVerticalSize(it);
      final double zc = it.elevation ?? v / 2;
      final String noH = it.elevation == null
          ? '\n바닥에서 높이를 안 넣어 바닥에 놓은 것으로 그렸습니다.'
          : '';
      return '${it.label}\n'
          '평면 ${_mm(it.width)} × ${_mm(it.height)}mm · 높이 ${_mm(v)}mm · 바닥에서 ${_mm(zc - v / 2)}~${_mm(zc + v / 2)}mm$noH';
    }
    final b = _scene.bounds;
    final d = b.max - b.min;
    final String noH = _scene.noHeightCount > 0
        ? '\n바닥에서 높이를 안 넣은 부품 ${_scene.noHeightCount}개는 바닥에 놓은 것으로 그렸습니다.'
        : '';
    return '전체 ${_mm(d.x)} × ${_mm(d.y)} × 높이 ${_mm(b.max.z)}mm\n'
        '부품 ${_scene.partCount}개 · 전선관 경로 ${_scene.routeCount}줄$noH';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('입체 보기')),
      body: SafeArea(
        child: _scene.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '스키드 평면에 놓은 부품이 없습니다.\n형강이나 전선관을 놓으면 여기에 입체로 보입니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                ),
              )
            : Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Wrap(
                      alignment: WrapAlignment.start,
                      spacing: 6,
                      runSpacing: 0,
                      children: [
                        for (final p in _presets)
                          ChoiceChip(
                            key: Key(p.$1),
                            label: Text(p.$2),
                            visualDensity: VisualDensity.compact,
                            selected: _isPreset(p.$3),
                            onSelected: (_) => _setView(p.$3),
                          ),
                        FilterChip(
                          key: const Key('iso_labels'),
                          label: const Text('이름'),
                          visualDensity: VisualDensity.compact,
                          selected: _showLabels,
                          onSelected: (v) => setState(() => _showLabels = v),
                        ),
                        ActionChip(
                          key: const Key('iso_fit'),
                          label: const Text('맞춤'),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _setView(_view),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final size = Size(box.maxWidth, box.maxHeight);
                        if (_fit == null || _fitSize != size) {
                          _fit = fitIso(_scene, _view, size);
                          _fitSize = size;
                        }
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: dark
                                  ? const [Color(0xFF0F172A), Color(0xFF1E293B)]
                                  : const [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
                            ),
                          ),
                          child: GestureDetector(
                            key: const Key('iso_canvas'),
                            behavior: HitTestBehavior.opaque,
                            onScaleStart: (_) => _zoom0 = _zoom,
                            onScaleUpdate: (d) => setState(() {
                              if (d.pointerCount >= 2) {
                                _zoom = (_zoom0 * d.scale).clamp(0.3, 30.0);
                                _pan += d.focalPointDelta;
                              } else {
                                _view = _view.copyWith(
                                  yaw: _view.yaw + d.focalPointDelta.dx * 0.01,
                                  pitch:
                                      (_view.pitch + d.focalPointDelta.dy * 0.006)
                                          .clamp(0.0, math.pi / 2),
                                );
                              }
                            }),
                            onTapUp: (d) => setState(
                              () => _selected = _hits.partAt(d.localPosition),
                            ),
                            child: CustomPaint(
                              size: size,
                              painter: SkidIsoPainter(
                                scene: _scene,
                                view: _view,
                                fit: _fit!,
                                zoom: _zoom,
                                pan: _pan,
                                selectedId: _selected,
                                hits: _hits,
                                dark: dark,
                                showLabels: _showLabels,
                                labels: _labels,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    key: const Key('iso_info'),
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _info(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '한 손가락으로 돌리고, 두 손가락으로 키우고 옮깁니다. 보기 전용입니다.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
