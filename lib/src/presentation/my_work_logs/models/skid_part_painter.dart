import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'skid_presets.dart' show SkidShape;

// 🚀 스키드 부품(형강·정션박스·곤질레다·커플링·유니온 커플링)을 보는 방향마다 그린다.
// - top: 위에서 본 모습(평면). 긴 쪽이 가로, 칸이 세로로 길면 돌려서 그린다.
// - side: 옆에서 본 모습(정면·측면에서 부품이 보는 면과 나란할 때). 가로 = 길이, 세로 = 높이.
// - end: 끝에서 본 모습(부품이 보는 쪽으로 뻗어 있을 때). 형강은 단면(H·ㄷ·ㄱ·ㅁ).
// 곤질레다는 뚜껑이 위를 보게 놓은 모습이다(삼화기전 F-7 모양을 따른다).

enum SkidFace { top, side, end }

class SkidPartPainter extends CustomPainter {
  final String shape;
  final SkidFace face;
  final Color stroke;
  final double strokeWidth;

  /// 좌우를 뒤집어 그린다(우측면처럼 반대쪽에서 볼 때).
  final bool mirror;

  const SkidPartPainter({
    required this.shape,
    this.face = SkidFace.top,
    this.stroke = const Color(0xFF64748B),
    this.strokeWidth = 1.5,
    this.mirror = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    canvas.save();
    Size s = size;
    // 위에서 본 모습은 긴 쪽을 가로로 그린다. 칸이 세로로 길면(90° 돌려 놓음) 그림도 돌린다.
    if (face == SkidFace.top &&
        shape != SkidShape.jb &&
        size.height > size.width) {
      canvas.translate(size.width, 0);
      canvas.rotate(math.pi / 2);
      s = Size(size.height, size.width);
    }
    // 뒤집기는 돌린 뒤에 해서, 돌려 놓은 부품도 길이 방향으로 뒤집힌다.
    if (mirror) {
      canvas.translate(s.width, 0);
      canvas.scale(-1, 1);
    }
    drawSkidPart(canvas, s, shape, face, stroke, strokeWidth);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SkidPartPainter old) =>
      old.shape != shape ||
      old.face != face ||
      old.stroke != stroke ||
      old.strokeWidth != strokeWidth ||
      old.mirror != mirror;
}

const Color _body = Color(0xFFF8FAFC);
const Color _metal = Color(0xFFE2E8F0);
const Color _cover = Color(0xFFEEF2F6);

/// [s] 칸에 [shape]를 [face] 방향에서 본 모습으로 그린다(돌리기·뒤집기는 부르는 쪽이 한다).
void drawSkidPart(
  Canvas c,
  Size s,
  String shape,
  SkidFace face,
  Color stroke,
  double strokeWidth,
) {
  final _P p = _P(c, s, stroke, strokeWidth);
  if (SkidShape.isCondulet(shape)) {
    _condulet(p, shape, face);
    return;
  }
  switch (shape) {
    case SkidShape.coupling:
      _coupling(p, face);
    case SkidShape.union:
      _union(p, face);
    case SkidShape.jb:
      _jb(p, face);
    case SkidShape.conduit:
      if (face == SkidFace.end) {
        final double r = math.min(p.w, p.h) / 2;
        p.circle(p.center, r, _metal);
        p.circle(p.center, r * 0.78, _body);
      } else {
        p.part(Rect.fromLTWH(0, 0, p.w, p.h), _metal, p.h / 2);
        p.dashed(Offset(0, p.h / 2), Offset(p.w, p.h / 2));
      }
    case SkidShape.beam:
    case SkidShape.channel:
    case SkidShape.angle:
    case SkidShape.square:
    case SkidShape.strut:
      _steel(p, shape, face);
    default:
      p.part(Rect.fromLTWH(0, 0, p.w, p.h), _body, 3);
  }
}

// ───────────────────────── 형강 ─────────────────────────

void _steel(_P p, String shape, SkidFace face) {
  final double w = p.w, h = p.h;
  if (face == SkidFace.end) {
    final Path path = Path();
    switch (shape) {
      case SkidShape.beam: // I(H): 위아래 플랜지 + 가운데 웨브
        final double tf = h * 0.1, tw = math.max(w * 0.12, 1);
        path.addPolygon([
          Offset.zero,
          Offset(w, 0),
          Offset(w, tf),
          Offset((w + tw) / 2, tf),
          Offset((w + tw) / 2, h - tf),
          Offset(w, h - tf),
          Offset(w, h),
          Offset(0, h),
          Offset(0, h - tf),
          Offset((w - tw) / 2, h - tf),
          Offset((w - tw) / 2, tf),
          Offset(0, tf),
        ], true);
      case SkidShape.channel: // ㄷ: 왼쪽 웨브, 위아래 플랜지
        final double tf = h * 0.12, tw = w * 0.16;
        path.addPolygon([
          Offset.zero,
          Offset(w, 0),
          Offset(w, tf),
          Offset(tw, tf),
          Offset(tw, h - tf),
          Offset(w, h - tf),
          Offset(w, h),
          Offset(0, h),
        ], true);
      case SkidShape.angle: // ㄴ
        final double t = math.min(w, h) * 0.16;
        path.addPolygon([
          Offset.zero,
          Offset(t, 0),
          Offset(t, h - t),
          Offset(w, h - t),
          Offset(w, h),
          Offset(0, h),
        ], true);
      case SkidShape.square: // ㅁ(속이 빈 각파이프)
        final double t = math.min(w, h) * 0.1;
        path
          ..fillType = PathFillType.evenOdd
          ..addRect(Rect.fromLTWH(0, 0, w, h))
          ..addRect(Rect.fromLTWH(t, t, w - 2 * t, h - 2 * t));
      default: // 스트럿: 위가 열린 립 찬넬
        final double t = w * 0.1, lip = w * 0.26;
        path.addPolygon([
          Offset.zero,
          Offset(lip, 0),
          Offset(lip, t),
          Offset(t, t),
          Offset(t, h - t),
          Offset(w - t, h - t),
          Offset(w - t, t),
          Offset(w - lip, t),
          Offset(w - lip, 0),
          Offset(w, 0),
          Offset(w, h),
          Offset(0, h),
        ], true);
    }
    p.path(path, _metal);
    return;
  }
  // 위·옆에서 본 모습: 긴 막대 + 플랜지·벽 선.
  p.part(Rect.fromLTWH(0, 0, w, h), _metal, 0);
  switch (shape) {
    case SkidShape.beam:
      if (face == SkidFace.top) {
        p.dashed(Offset(0, h / 2), Offset(w, h / 2));
      } else {
        p.thinLine(Offset(0, h * 0.1), Offset(w, h * 0.1));
        p.thinLine(Offset(0, h * 0.9), Offset(w, h * 0.9));
      }
    case SkidShape.channel:
      p.thinLine(Offset(0, h * 0.12), Offset(w, h * 0.12));
      if (face == SkidFace.side) {
        p.thinLine(Offset(0, h * 0.88), Offset(w, h * 0.88));
      }
    case SkidShape.angle:
      p.thinLine(
        Offset(0, face == SkidFace.top ? h * 0.15 : h * 0.85),
        Offset(w, face == SkidFace.top ? h * 0.15 : h * 0.85),
      );
    case SkidShape.square:
      p.thinLine(Offset(0, h * 0.12), Offset(w, h * 0.12));
      p.thinLine(Offset(0, h * 0.88), Offset(w, h * 0.88));
    default:
      if (face == SkidFace.top) {
        p.part(Rect.fromLTWH(0, h * 0.3, w, h * 0.4), _body, 0);
      } else {
        p.thinLine(Offset(0, h * 0.2), Offset(w, h * 0.2));
      }
  }
}

// ───────────────────────── 정션박스 ─────────────────────────

void _jb(_P p, SkidFace face) {
  final double w = p.w, h = p.h;
  p.part(Rect.fromLTWH(0, 0, w, h), _body, 3);
  if (face == SkidFace.top) {
    p.part(Rect.fromLTWH(w * 0.06, h * 0.06, w * 0.88, h * 0.88), _body, 2);
    final double r = math.min(w, h) * 0.03 + 1;
    for (final dx in [0.12, 0.88]) {
      for (final dy in [0.12, 0.88]) {
        p.circle(p.at(dx, dy), r, _metal);
      }
    }
    return;
  }
  // 옆·끝: 위에 뚜껑 띠와 뚜껑 나사, 아래에 전선관 들어오는 허브 둘.
  final double band = math.max(h * 0.12, 2);
  p.part(Rect.fromLTWH(0, 0, w, band), _cover, 2);
  final double r = math.min(band * 0.3, w * 0.03) + 0.5;
  p.circle(Offset(w * 0.1, band / 2), r, _metal);
  p.circle(Offset(w * 0.9, band / 2), r, _metal);
  final double hub = math.min(w * 0.14, h * 0.22);
  for (final x in [0.3, 0.7]) {
    p.part(
      Rect.fromLTWH(w * x - hub / 2, h - hub * 0.45, hub, hub * 0.45),
      _metal,
      1,
    );
  }
}

// ───────────────────────── 곤질레다(삼화기전 F-7) ─────────────────────────
// 허브: 왼쪽 끝(endL)·오른쪽 끝(endR)·옆 위(sideA)·옆 아래(sideB)·뒤(back, 뚜껑 반대 = 아래).
// LB: 끝 + 뒤, LL: 끝 + 옆 위, LR: 끝 + 옆 아래, LT: 양 끝 + 옆 아래, LC: 양 끝, LX: 양 끝 + 양 옆.

class _Hubs {
  // 곤질레다는 모두 왼쪽 끝 허브가 있다.
  bool get endL => true;
  final bool endR, sideA, sideB, back;
  const _Hubs({
    this.endR = false,
    this.sideA = false,
    this.sideB = false,
    this.back = false,
  });
}

_Hubs _hubsOf(String shape) => switch (shape) {
  SkidShape.cdLB => const _Hubs(back: true),
  SkidShape.cdLL => const _Hubs(sideA: true),
  SkidShape.cdLR => const _Hubs(sideB: true),
  SkidShape.cdLT => const _Hubs(endR: true, sideB: true),
  SkidShape.cdLX => const _Hubs(endR: true, sideA: true, sideB: true),
  _ => const _Hubs(endR: true), // LC
};

/// 옆 허브가 한쪽이면 몸통이 칸 폭의 70%, 양쪽이면 54%(나머지는 허브가 튀어나온 만큼).
(double, double) _bandOf(_Hubs hb, double span) {
  if (hb.sideA && hb.sideB) return (span * 0.23, span * 0.54);
  if (hb.sideA) return (span * 0.3, span * 0.7);
  if (hb.sideB) return (0, span * 0.7);
  return (0, span);
}

void _condulet(_P p, String shape, SkidFace face) {
  final _Hubs hb = _hubsOf(shape);
  final double w = p.w, h = p.h;
  if (face == SkidFace.end) {
    // 끝에서 본 모습: 가로 = 폭(옆 허브 포함), 세로 = 높이(뒤 허브 포함).
    final (double x0, double bw) = _bandOf(hb, w);
    final double bh = hb.back ? h * 0.7 : h;
    final double hd = math.min(bw, bh) * 0.72;
    final Offset cc = Offset(x0 + bw / 2, bh / 2);
    if (hb.sideA) p.part(Rect.fromLTWH(0, cc.dy - hd / 2, x0, hd), _metal, 1);
    if (hb.sideB) {
      p.part(
        Rect.fromLTWH(x0 + bw, cc.dy - hd / 2, w - x0 - bw, hd),
        _metal,
        1,
      );
    }
    if (hb.back)
      p.part(Rect.fromLTWH(cc.dx - hd / 2, bh, hd, h - bh), _metal, 1);
    p.part(Rect.fromLTWH(x0, 0, bw, bh), _body, bw * 0.2);
    p.part(Rect.fromLTWH(x0, 0, bw, bh * 0.14), _cover, 2);
    p.circle(cc, hd / 2, _metal);
    p.circle(cc, hd * 0.34, _body);
    return;
  }
  // 위·옆: 가로 = 길이(끝 허브 포함).
  final double hl = w * 0.14;
  final double bl = hb.endL ? hl : 0;
  final double br = hb.endR ? w - hl : w;
  final double y0, bh;
  if (face == SkidFace.top) {
    (y0, bh) = _bandOf(hb, h);
  } else {
    y0 = 0;
    bh = hb.back ? h * 0.7 : h;
  }
  final double cy = y0 + bh / 2;
  final double hd = bh * 0.72;
  // 옆·뒤 허브 자리: LL·LR·LB는 막힌 쪽 끝, LT·LX는 가운데.
  final double hx = hb.endR ? (bl + br) / 2 : br - bh * 0.55;
  void endHub(double x) {
    p.part(Rect.fromLTWH(x, cy - hd / 2, hl, hd), _metal, 1);
    p.thinLine(
      Offset(x + hl * 0.35, cy - hd / 2),
      Offset(x + hl * 0.35, cy + hd / 2),
    );
    p.thinLine(
      Offset(x + hl * 0.65, cy - hd / 2),
      Offset(x + hl * 0.65, cy + hd / 2),
    );
  }

  if (hb.endL) endHub(0);
  if (hb.endR) endHub(w - hl);
  if (face == SkidFace.top) {
    if (hb.sideA) p.part(Rect.fromLTWH(hx - hd / 2, 0, hd, y0 + 1), _metal, 1);
    if (hb.sideB) {
      p.part(
        Rect.fromLTWH(hx - hd / 2, y0 + bh - 1, hd, h - y0 - bh + 1),
        _metal,
        1,
      );
    }
  } else if (hb.back) {
    p.part(Rect.fromLTWH(hx - hd / 2, bh - 1, hd, h - bh + 1), _metal, 1);
  }
  p.part(Rect.fromLTRB(bl, y0, br, y0 + bh), _body, bh * 0.28);
  if (face == SkidFace.top) {
    // 뚜껑과 나사 둘, 뒤 허브는 가려져 있어 점선 동그라미로.
    final Rect cv = Rect.fromLTRB(
      bl + bh * 0.12,
      y0 + bh * 0.12,
      br - bh * 0.12,
      y0 + bh * 0.88,
    );
    p.part(cv, _cover, bh * 0.2);
    final double r = bh * 0.06 + 0.5;
    p.circle(Offset(cv.left + bh * 0.18, cy), r, _metal);
    p.circle(Offset(cv.right - bh * 0.18, cy), r, _metal);
    if (hb.back) p.dashedCircle(Offset(hx, cy), hd * 0.4);
  } else {
    p.part(Rect.fromLTRB(bl, 0, br, bh * 0.14), _cover, 2);
    // 보는 쪽을 향한 옆 허브는 동그라미로 보인다.
    if (hb.sideA || hb.sideB) {
      p.circle(Offset(hx, cy + bh * 0.05), hd * 0.42, _metal);
      p.circle(Offset(hx, cy + bh * 0.05), hd * 0.26, _body);
    }
  }
}

// ───────────────────────── 커플링·유니온 커플링 ─────────────────────────

void _coupling(_P p, SkidFace face) {
  final double w = p.w, h = p.h;
  if (face == SkidFace.end) {
    final double r = math.min(w, h) / 2;
    p.circle(p.center, r, _metal);
    p.circle(p.center, r * 0.74, _body);
    return;
  }
  p.part(Rect.fromLTWH(0, 0, w, h), _metal, h * 0.12);
  p.thinLine(Offset(w * 0.14, 0), Offset(w * 0.14, h));
  p.thinLine(Offset(w * 0.86, 0), Offset(w * 0.86, h));
}

void _union(_P p, SkidFace face) {
  final double w = p.w, h = p.h;
  if (face == SkidFace.end) {
    final double r = math.min(w, h) / 2;
    final Path hex = Path();
    for (int i = 0; i < 6; i++) {
      final double a = math.pi / 6 + i * math.pi / 3;
      final Offset q = p.center + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? hex.moveTo(q.dx, q.dy) : hex.lineTo(q.dx, q.dy);
    }
    hex.close();
    p.path(hex, _metal);
    p.circle(p.center, r * 0.5, _body);
    return;
  }
  // 양 끝 몸통(가늘다) + 가운데 육각 너트.
  p.part(Rect.fromLTWH(0, h * 0.2, w * 0.32, h * 0.6), _metal, 1);
  p.part(Rect.fromLTWH(w * 0.68, h * 0.2, w * 0.32, h * 0.6), _metal, 1);
  p.part(Rect.fromLTWH(w * 0.28, 0, w * 0.44, h), _metal, 1);
  p.thinLine(Offset(w * 0.28, h * 0.25), Offset(w * 0.72, h * 0.25));
  p.thinLine(Offset(w * 0.28, h * 0.75), Offset(w * 0.72, h * 0.75));
}

// ───────────────────────── 그리기 도구 ─────────────────────────

class _P {
  final Canvas c;
  final double w, h;
  final Color stroke;
  final double sw;
  _P(this.c, Size s, this.stroke, this.sw) : w = s.width, h = s.height;

  Offset get center => Offset(w / 2, h / 2);
  Offset at(double x, double y) => Offset(w * x, h * y);

  Paint get _line => Paint()
    ..color = stroke
    ..style = PaintingStyle.stroke
    ..strokeWidth = sw;
  Paint get _thin => Paint()
    ..color = stroke.withValues(alpha: 0.7)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(sw * 0.6, 0.6);

  void part(Rect r, Color fill, double radius) {
    if (r.width <= 0 || r.height <= 0) return;
    final RRect rr = RRect.fromRectAndRadius(
      r,
      Radius.circular(math.max(0, math.min(radius, r.shortestSide / 2))),
    );
    c.drawRRect(rr, Paint()..color = fill);
    c.drawRRect(rr, _line);
  }

  void circle(Offset o, double r, Color fill) {
    if (r <= 0) return;
    c.drawCircle(o, r, Paint()..color = fill);
    c.drawCircle(o, r, _line);
  }

  void path(Path pth, Color fill) {
    c.drawPath(pth, Paint()..color = fill);
    c.drawPath(pth, _line);
  }

  void thinLine(Offset a, Offset b) => c.drawLine(a, b, _thin);

  void dashed(Offset a, Offset b) {
    final double len = (b - a).distance;
    if (len <= 0) return;
    final Offset d = (b - a) / len;
    const double dash = 8, gap = 5;
    for (double t = 0; t < len; t += dash + gap) {
      c.drawLine(a + d * t, a + d * math.min(t + dash, len), _thin);
    }
  }

  void dashedCircle(Offset o, double r) {
    const int n = 12;
    for (int i = 0; i < n; i += 1) {
      final double a0 = i * 2 * math.pi / n;
      c.drawArc(
        Rect.fromCircle(center: o, radius: r),
        a0,
        math.pi / n,
        false,
        _thin,
      );
    }
  }
}

/// "경로" 단추 그림: 꺾인 전선관(관 두 줄).
class SkidRouteIconPainter extends CustomPainter {
  final Color color;
  const SkidRouteIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width, h = size.height;
    final Path path = Path()
      ..moveTo(w * 0.12, h * 0.95)
      ..lineTo(w * 0.12, h * 0.45)
      ..quadraticBezierTo(w * 0.12, h * 0.2, w * 0.38, h * 0.2)
      ..lineTo(w * 0.92, h * 0.2);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.3
        ..strokeCap = StrokeCap.butt,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.12,
    );
  }

  @override
  bool shouldRepaint(covariant SkidRouteIconPainter old) => old.color != color;
}
