// 철판 전개도 그림(10-10): 외곽·구멍·장공(흰색), 꺾기선(주황 점선 + 번호·방향·각도), 전체 치수·꺾기선 위치 치수.
// 화면과 가공 지시서 PDF(PNG로 떠서)가 같은 그림을 쓴다. 좌표는 plate_calc.dart(왼쪽 아래 원점, y 위)를 화면으로 뒤집는다.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'plate_calc.dart';

const Color kPlateFill = Color(0xFFC9D3DA);
const Color kPlateEdge = Color(0xFF4B5A64);
const Color kPlateBend = Color(0xFFE08A1E);

/// 꺾은 모양(옆모습) 철 색: 밝은 쪽, 어두운 쪽.
const List<Color> kPlateSteelShade = [Color(0xFFCBD5DC), Color(0xFF6F7E88)];

String _f(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s;
}

class PlatePainter extends CustomPainter {
  final PlatePlan plan;
  final Color text, sub, bg;
  final double fontScale;

  PlatePainter({
    required this.plan,
    required this.text,
    required this.sub,
    required this.bg,
    this.fontScale = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = plan;
    final bw = math.max(p.maxX - p.minX, 1.0);
    final bh = math.max(p.maxY - p.minY, 1.0);
    final ml = 58.0 * fontScale, mt = 44.0 * fontScale;
    final mr = 16.0 * fontScale;
    final mb = (p.bends.isEmpty ? 16.0 : 44.0) * fontScale;
    final s = math.min(
      (size.width - ml - mr) / bw,
      (size.height - mt - mb) / bh,
    );
    if (s <= 0 || !s.isFinite) return;
    final ox = ml + (size.width - ml - mr - bw * s) / 2;
    final oy = mt + (size.height - mt - mb - bh * s) / 2;
    // 전개도 (x, y위) → 화면 (x, y아래)
    Offset m(Offset q) =>
        Offset(ox + (q.dx - p.minX) * s, oy + (p.maxY - q.dy) * s);

    final pts = plateOutlinePoints(p.outline);
    if (pts.length >= 3) {
      final path = Path()..moveTo(m(pts.first).dx, m(pts.first).dy);
      for (final q in pts.skip(1)) {
        path.lineTo(m(q).dx, m(q).dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = kPlateFill);
      canvas.drawPath(
        path,
        Paint()
          ..color = kPlateEdge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 * fontScale,
      );
    }

    // 구멍·장공
    final holeEdge = Paint()
      ..color = kPlateEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 * fontScale;
    for (final h in p.holes) {
      final c = m(h.c);
      if (h.slot <= 0) {
        final r = math.max(h.dia / 2 * s, 2.5 * fontScale);
        canvas.drawCircle(c, r, Paint()..color = Colors.white);
        canvas.drawCircle(c, r, holeEdge);
      } else {
        final w = h.slotAlongX ? h.slot * s : h.dia * s;
        final hh = h.slotAlongX ? h.dia * s : h.slot * s;
        final rr = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: c,
            width: math.max(w, 5),
            height: math.max(hh, 5),
          ),
          Radius.circular(math.max(h.dia / 2 * s, 2.5)),
        );
        canvas.drawRRect(rr, Paint()..color = Colors.white);
        canvas.drawRRect(rr, holeEdge);
      }
    }

    // 꺾기선: 점선 + 위에 번호·방향
    final bendPaint = Paint()
      ..color = kPlateBend
      ..strokeWidth = 1.6 * fontScale;
    for (var n = 0; n < p.bends.length; n++) {
      final b = p.bends[n];
      final top = m(Offset(b.center, p.maxY)),
          bot = m(Offset(b.center, p.minY));
      final dash = 6.0 * fontScale, gap = 4.0 * fontScale;
      for (var y = top.dy; y < bot.dy; y += dash + gap) {
        canvas.drawLine(
          Offset(top.dx, y),
          Offset(top.dx, math.min(y + dash, bot.dy)),
          bendPaint,
        );
      }
      _text(
        canvas,
        '${n + 1} ${b.turn >= 0 ? "위로" : "아래로"} ${_f(b.turn.abs())}°',
        Offset(top.dx, (top.dy + bot.dy) / 2),
        -math.pi / 2,
        color: kPlateBend,
        bold: true,
      );
    }

    // 치수: 전체 길이(위), 전체 폭(왼쪽), 꺾기선 위치(아래, 왼쪽 끝에서)
    final dimPaint = Paint()
      ..color = sub
      ..strokeWidth = 1 * fontScale;
    void hDim(double x1, double x2, double y, String t) {
      final a = Offset(x1, y), b = Offset(x2, y);
      canvas.drawLine(a, b, dimPaint);
      final k = 4.0 * fontScale;
      for (final q in [a, b]) {
        canvas.drawLine(q + Offset(-k, k), q + Offset(k, -k), dimPaint);
      }
      _text(canvas, t, (a + b) / 2, 0, color: text, bold: true);
    }

    final left = m(Offset(p.minX, p.maxY)), right = m(Offset(p.maxX, p.minY));
    final topY = left.dy - 24 * fontScale;
    canvas.drawLine(left, Offset(left.dx, topY - 4), dimPaint);
    canvas.drawLine(
      Offset(right.dx, left.dy),
      Offset(right.dx, topY - 4),
      dimPaint,
    );
    hDim(left.dx, right.dx, topY, _f(p.flatLength));
    final lx = left.dx - 26 * fontScale;
    canvas.drawLine(
      Offset(left.dx, left.dy),
      Offset(lx - 4, left.dy),
      dimPaint,
    );
    canvas.drawLine(
      Offset(left.dx, right.dy),
      Offset(lx - 4, right.dy),
      dimPaint,
    );
    canvas.drawLine(Offset(lx, left.dy), Offset(lx, right.dy), dimPaint);
    final k = 4.0 * fontScale;
    for (final y in [left.dy, right.dy]) {
      canvas.drawLine(Offset(lx - k, y + k), Offset(lx + k, y - k), dimPaint);
    }
    _text(
      canvas,
      _f(p.flatWidth),
      Offset(lx, (left.dy + right.dy) / 2),
      -math.pi / 2,
      color: text,
      bold: true,
    );
    if (p.bends.isNotEmpty) {
      final by = right.dy + 24 * fontScale;
      var prev = left.dx;
      var prevMm = p.minX;
      for (final b in p.bends) {
        final x = m(Offset(b.center, 0)).dx;
        canvas.drawLine(Offset(x, right.dy), Offset(x, by + 4), dimPaint);
        hDim(prev, x, by, _f(b.center - prevMm));
        prev = x;
        prevMm = b.center;
      }
      canvas.drawLine(
        Offset(left.dx, right.dy),
        Offset(left.dx, by + 4),
        dimPaint,
      );
      canvas.drawLine(
        Offset(right.dx, right.dy),
        Offset(right.dx, by + 4),
        dimPaint,
      );
      hDim(prev, right.dx, by, _f(p.maxX - prevMm));
    }
  }

  void _text(
    Canvas canvas,
    String s,
    Offset at,
    double angle, {
    bool bold = false,
    required Color color,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: 11.5 * fontScale,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset.zero,
        width: tp.width + 6,
        height: tp.height + 2,
      ),
      Paint()..color = bg.withValues(alpha: 0.85),
    );
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(PlatePainter old) =>
      old.plan != plan ||
      old.text != text ||
      old.sub != sub ||
      old.bg != bg ||
      old.fontScale != fontScale;
}

/// 아무 그림이나 흰 바탕 PNG로(지시서 PDF에 넣는다).
Future<Uint8List> renderPainterPng(
  CustomPainter painter, {
  double width = 1400,
  double height = 800,
}) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(
    Offset.zero & Size(width, height),
    Paint()..color = Colors.white,
  );
  painter.paint(canvas, Size(width, height));
  final img = await rec.endRecording().toImage(width.toInt(), height.toInt());
  final bd = await img.toByteData(format: ui.ImageByteFormat.png);
  return bd!.buffer.asUint8List();
}
