// 접지바 그림: 위에서 본 부스바와 구멍(실제 비율). 계산은 busbar_ground.dart.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'busbar_ground.dart';
import 'elec_form_parts.dart' show fmt;

class GroundBarPainter extends CustomPainter {
  GroundBarPainter({
    required this.plan,
    required this.width,
    required this.holeDia,
    required this.text,
    required this.sub,
    required this.bg,
    this.lugNumbers = const {},
  });

  final GroundBarPlan plan;
  final double width, holeDia;
  final Color text, sub, bg;

  /// 러그를 붙이는 구멍: 구멍 번호(id) → 러그 번호.
  final Map<String, int> lugNumbers;

  void _label(
    Canvas canvas,
    String s,
    Offset c,
    Color color, {
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: 11.5,
          color: color,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 16.0;
    final len = math.max(plan.length, 1.0);
    final sc = math.min(
      math.min((size.width - 2 * pad) / len, 3.0),
      (size.height - 66) / math.max(width, 1.0),
    );
    final barW = len * sc;
    final h = width * sc;
    final x0 = (size.width - barW) / 2;
    final y0 = 28 + (size.height - 66 - h) / 2;
    final bar = Rect.fromLTWH(x0, y0, barW, h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        bar.shift(const Offset(0, 2.5)),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, const Radius.circular(3)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE9A878), Color(0xFFB66A3C)],
        ).createShader(bar),
    );
    for (final b in plan.bends) {
      final zone = Rect.fromLTRB(
        x0 + b.start * sc,
        y0,
        x0 + math.max(b.end * sc, b.start * sc + 2),
        y0 + h,
      );
      canvas.drawRect(zone, Paint()..color = const Color(0x8C0F9D8F));
      for (final x in [b.start, b.end]) {
        canvas.drawLine(
          Offset(x0 + x * sc, y0 - 4),
          Offset(x0 + x * sc, y0 + h + 4),
          Paint()
            ..color = const Color(0xFF0F9D8F)
            ..strokeWidth = 1.6,
        );
      }
    }
    for (final hole in [...plan.tabHoleList, ...plan.groundHoles]) {
      final c = Offset(x0 + hole.x * sc, y0 + hole.y * sc);
      final rad = math.max(hole.dia * sc / 2, 2.5);
      canvas.drawCircle(c, rad, Paint()..color = bg);
      canvas.drawCircle(
        c,
        rad,
        Paint()
          ..color = hole.custom
              ? const Color(0xFFE08A1E)
              : const Color(0x66000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = hole.custom ? 2 : 1,
      );
      final lug = lugNumbers[hole.id];
      if (lug != null) {
        canvas.drawCircle(
          c,
          rad + 3,
          Paint()
            ..color = const Color(0xFF2563EB)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        _label(
          canvas,
          'L$lug',
          c - Offset(0, rad + 10),
          const Color(0xFF2563EB),
          bold: true,
        );
      }
    }
    final dim = Paint()
      ..color = sub
      ..strokeWidth = 1;
    final yd = y0 + h + 14;
    void dimLine(double a, double b, String s) {
      final xa = x0 + a * sc, xb = x0 + b * sc;
      canvas.drawLine(Offset(xa, yd), Offset(xb, yd), dim);
      canvas.drawLine(Offset(xa, yd - 4), Offset(xa, yd + 4), dim);
      canvas.drawLine(Offset(xb, yd - 4), Offset(xb, yd + 4), dim);
      if (xb - xa > 28) {
        _label(canvas, s, Offset((xa + xb) / 2, yd + 12), text, bold: true);
      }
    }

    if (plan.holes > 0) {
      dimLine(plan.flatStart, plan.positions.first, fmt(plan.endLeft, 1));
      if (plan.holes > 1) {
        dimLine(
          plan.positions.first,
          plan.positions[1],
          fmt(plan.positions[1] - plan.positions.first, 1),
        );
      }
      dimLine(
        plan.flatEnd - plan.endRight,
        plan.flatEnd,
        fmt(plan.endRight, 1),
      );
    }
    _label(
      canvas,
      '${fmt(plan.length, 1)} mm × ${fmt(width)} mm · 구멍 ${plan.groundHoles.length}개',
      Offset(size.width / 2, 14),
      sub,
    );
  }

  @override
  bool shouldRepaint(GroundBarPainter o) =>
      o.plan != plan ||
      o.width != width ||
      o.holeDia != holeDia ||
      o.lugNumbers != lugNumbers;
}
