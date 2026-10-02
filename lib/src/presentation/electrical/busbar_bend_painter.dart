// 부스바 절곡 그림: 꺾은 뒤 옆모습, 자르기 전 곧은 부스바의 마킹. 계산은 busbar_bend.dart.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'busbar_bend.dart';
import 'elec_form_parts.dart' show fmt;

const Color _copperLight = Color(0xFFE9A878);
const Color _copperDark = Color(0xFFB66A3C);
const Color _markUp = Color(0xFF0F9D8F);
const Color _markDown = Color(0xFFE08A1E);

Color busbarBendColor(double turn) => turn >= 0 ? _markUp : _markDown;

void _label(
  Canvas canvas,
  String s,
  Offset at,
  Color color, {
  double size = 11.5,
  bool center = true,
  bool bold = false,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontSize: size,
        color: color,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, center ? at - Offset(tp.width / 2, tp.height / 2) : at);
}

Paint _copperPaint(Rect r) => Paint()
  ..shader = const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [_copperLight, _copperDark],
  ).createShader(r);

/// 꺾은 뒤 옆모습. 실제 비율이고, 두께는 판 두께 [thickness]로 그린다.
class BusbarShapePainter extends CustomPainter {
  BusbarShapePainter({
    required this.plan,
    required this.rho,
    required this.thickness,
    required this.text,
    required this.sub,
    required this.line,
  });

  final BusbarBendPlan plan;
  final double rho, thickness;
  final Color text, sub, line;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = busbarShape(plan, rho);
    var minX = 0.0, maxX = 0.0, minY = 0.0, maxY = 0.0;
    for (final p in pts) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    const pad = 22.0;
    final w = math.max(maxX - minX, 1.0), h = math.max(maxY - minY, 1.0);
    final sc = math.min(
      (size.width - 2 * pad) / w,
      (size.height - 2 * pad) / h,
    );
    final ox = (size.width - w * sc) / 2 - minX * sc;
    final oy = (size.height + h * sc) / 2 + minY * sc;
    Offset map(math.Point<double> p) => Offset(ox + p.x * sc, oy - p.y * sc);

    final path = Path()..moveTo(map(pts.first).dx, map(pts.first).dy);
    for (final p in pts.skip(1)) {
      final o = map(p);
      path.lineTo(o.dx, o.dy);
    }
    final bar = math.max(thickness * sc, 5.0);
    canvas.drawPath(
      path.shift(const Offset(0, 2.5)),
      Paint()
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = bar
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_copperLight, _copperDark],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeWidth = bar
        ..strokeJoin = StrokeJoin.round,
    );
    // 꺾는 곳 번호(호 가운데)
    for (var i = 0; i < plan.bends.length; i++) {
      final b = plan.bends[i];
      // 호 가운데 좌표: pts에서 직선 + 호 절반 지점을 다시 구하지 않고 가까운 점을 찾는다.
      final mid = _pointAtLength(pts, b.center);
      final o = map(mid);
      canvas.drawCircle(o, 9, Paint()..color = busbarBendColor(b.turn));
      _label(canvas, '${i + 1}', o, Colors.white, bold: true);
    }
    _label(
      canvas,
      '옆에서 본 모양 · 중립선 길이 ${fmt(plan.cutLength)}mm',
      const Offset(10, 6),
      sub,
      center: false,
    );
  }

  @override
  bool shouldRepaint(BusbarShapePainter o) =>
      o.plan != plan || o.rho != rho || o.thickness != thickness;
}

/// 꺾은선 위에서 시작점으로부터 길이 [len]인 점.
math.Point<double> _pointAtLength(List<math.Point<double>> pts, double len) {
  var acc = 0.0;
  for (var i = 1; i < pts.length; i++) {
    final seg = pts[i].distanceTo(pts[i - 1]);
    if (acc + seg >= len || i == pts.length - 1) {
      final t = seg == 0 ? 0.0 : ((len - acc) / seg).clamp(0.0, 1.0);
      return math.Point(
        pts[i - 1].x + (pts[i].x - pts[i - 1].x) * t,
        pts[i - 1].y + (pts[i].y - pts[i - 1].y) * t,
      );
    }
    acc += seg;
  }
  return pts.last;
}

/// 자르기 전 곧은 부스바와 꺾기 시작·끝선 마킹.
class BusbarMarkPainter extends CustomPainter {
  BusbarMarkPainter({
    required this.plan,
    required this.text,
    required this.sub,
    required this.line,
  });

  final BusbarBendPlan plan;
  final Color text, sub, line;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 16.0;
    final len = math.max(plan.cutLength, 1.0);
    final sc = (size.width - 2 * pad) / len;
    final y0 = size.height / 2 - 14;
    const barH = 26.0;
    final bar = Rect.fromLTWH(pad, y0, len * sc, barH);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        bar.shift(const Offset(0, 2)),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, const Radius.circular(3)),
      _copperPaint(bar),
    );
    for (var i = 0; i < plan.bends.length; i++) {
      final b = plan.bends[i];
      final col = busbarBendColor(b.turn);
      final zone = Rect.fromLTRB(
        pad + b.start * sc,
        y0,
        pad + math.max(b.end * sc, b.start * sc + 2),
        y0 + barH,
      );
      canvas.drawRect(zone, Paint()..color = col.withValues(alpha: 0.55));
      for (final x in [b.start, b.end]) {
        canvas.drawLine(
          Offset(pad + x * sc, y0 - 6),
          Offset(pad + x * sc, y0 + barH + 6),
          Paint()
            ..color = col
            ..strokeWidth = 1.6,
        );
      }
      _label(
        canvas,
        '${i + 1}',
        zone.center,
        Colors.white,
        bold: true,
        size: 12,
      );
      final above = i.isEven;
      _label(
        canvas,
        fmt(b.start),
        Offset(pad + b.start * sc, above ? y0 - 16 : y0 + barH + 16),
        text,
        bold: true,
      );
    }
    _label(canvas, '0', Offset(pad, y0 + barH + 16), sub);
    _label(
      canvas,
      fmt(plan.cutLength),
      Offset(pad + len * sc, y0 + barH + 16),
      sub,
    );
    _label(
      canvas,
      '자르기 전 곧은 부스바 · 숫자는 한쪽 끝에서 잰 꺾기 시작선(mm)',
      const Offset(10, 6),
      sub,
      center: false,
    );
  }

  @override
  bool shouldRepaint(BusbarMarkPainter o) => o.plan != plan;
}
