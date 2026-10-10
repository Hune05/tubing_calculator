// 형강 브라켓 그림(10-10): bracket_calc.dart가 만든 부재 모양·구멍·용접 자리·치수선·글을 실제 비율로 그린다.
// 화면과 가공 지시서 PDF(그림을 PNG로 떠서 넣음)가 같은 그림을 쓴다.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'bracket_calc.dart';

const Color kBracketSteel = Color(0xFFB8C4CC);
const Color kBracketSteelEdge = Color(0xFF55636D);
const Color kBracketPlate = Color(0xFF94A3AE);
const Color kBracketWeld = Color(0xFFE08A1E);

class BracketPainter extends CustomPainter {
  final BracketDrawing drawing;
  final Color text, sub, bg;

  /// 글씨 크기 배수(PDF용 큰 그림에서 키운다).
  final double fontScale;

  BracketPainter({
    required this.drawing,
    required this.text,
    required this.sub,
    required this.bg,
    this.fontScale = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final (x0, y0, x1, y1) = drawing.bounds();
    // 여백: 왼쪽·위는 치수선 두 줄과 글, 아래는 베이스 판 치수, 오른쪽은 조금.
    final ml = 74.0 * fontScale, mt = 66.0 * fontScale;
    final mr = 20.0 * fontScale, mb = 42.0 * fontScale;
    final bw = math.max(x1 - x0, 1.0), bh = math.max(y1 - y0, 1.0);
    final s = math.min(
      (size.width - ml - mr) / bw,
      (size.height - mt - mb) / bh,
    );
    if (s <= 0 || !s.isFinite) return;
    final ox = ml + (size.width - ml - mr - bw * s) / 2 - x0 * s;
    final oy = mt + (size.height - mt - mb - bh * s) / 2 - y0 * s;
    Offset m(Offset p) => Offset(ox + p.dx * s, oy + p.dy * s);

    Path poly(List<Offset> pts) {
      final path = Path()..moveTo(m(pts.first).dx, m(pts.first).dy);
      for (final p in pts.skip(1)) {
        path.lineTo(m(p).dx, m(p).dy);
      }
      return path..close();
    }

    final edge = Paint()
      ..color = kBracketSteelEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * fontScale;
    for (final pl in drawing.plates) {
      final path = poly(pl);
      canvas.drawPath(path, Paint()..color = kBracketPlate);
      canvas.drawPath(path, edge);
    }
    for (final mb in drawing.members) {
      final path = poly(mb);
      canvas.drawPath(path, Paint()..color = kBracketSteel);
      canvas.drawPath(path, edge);
    }

    // 구멍: 흰 원 + 가운데 십자
    for (final h in drawing.holes) {
      final c = m(h.at);
      final r = math.max(h.dia / 2 * s, 3.0 * fontScale);
      canvas.drawCircle(c, r, Paint()..color = Colors.white);
      canvas.drawCircle(c, r, edge);
      final cross = Paint()
        ..color = kBracketSteelEdge
        ..strokeWidth = 0.8 * fontScale;
      canvas.drawLine(c - Offset(r + 3, 0), c + Offset(r + 3, 0), cross);
      canvas.drawLine(c - Offset(0, r + 3), c + Offset(0, r + 3), cross);
    }

    // 용접 자리: 주황 삼각
    for (final w in drawing.welds) {
      final c = m(w);
      final k = 6.0 * fontScale;
      final tri = Path()
        ..moveTo(c.dx, c.dy - k)
        ..lineTo(c.dx + k, c.dy + k * 0.8)
        ..lineTo(c.dx - k, c.dy + k * 0.8)
        ..close();
      canvas.drawPath(tri, Paint()..color = kBracketWeld);
    }

    // 치수선: 가로 치수는 위·아래, 세로 치수는 왼쪽·오른쪽에 화면 점으로 띄운다(작은 화면에서도 같은 간격).
    final dimPaint = Paint()
      ..color = sub
      ..strokeWidth = 1 * fontScale;
    void ext(Offset from, Offset to) {
      final v = to - from;
      final len = v.distance;
      if (len < 1) return;
      final u = v / len;
      canvas.drawLine(from + u * 3, to + u * 4, dimPaint);
    }

    for (final dm in drawing.dims) {
      final a = m(dm.a), b = m(dm.b);
      final o = dm.offset * fontScale;
      final Offset pa, pb;
      if (dm.vertical) {
        final x = (o < 0 ? math.min(a.dx, b.dx) : math.max(a.dx, b.dx)) + o;
        pa = Offset(x, a.dy);
        pb = Offset(x, b.dy);
      } else {
        final y = (o < 0 ? math.min(a.dy, b.dy) : math.max(a.dy, b.dy)) + o;
        pa = Offset(a.dx, y);
        pb = Offset(b.dx, y);
      }
      if ((pb - pa).distance < 1) continue;
      ext(a, pa);
      ext(b, pb);
      canvas.drawLine(pa, pb, dimPaint);
      final u = (pb - pa) / (pb - pa).distance;
      final n = Offset(-u.dy, u.dx);
      final t = 4.0 * fontScale;
      for (final p in [pa, pb]) {
        canvas.drawLine(p - (u + n) * t, p + (u + n) * t, dimPaint);
      }
      _text(
        canvas,
        dm.text,
        (pa + pb) / 2,
        dm.vertical ? -math.pi / 2 : 0,
        bold: true,
        color: text,
      );
    }

    for (final l in drawing.labels) {
      _text(canvas, l.text, m(l.at) + l.shift * fontScale, 0, color: sub);
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
          fontSize: 12 * fontScale,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // 글이 거꾸로 서지 않게(오른쪽에서 왼쪽·아래에서 위로 가는 선)
    var a = angle;
    if (a > math.pi / 2) a -= math.pi;
    if (a < -math.pi / 2) a += math.pi;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(a);
    final r = Rect.fromCenter(
      center: Offset.zero,
      width: tp.width + 6,
      height: tp.height + 2,
    );
    canvas.drawRect(r, Paint()..color = bg.withValues(alpha: 0.85));
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(BracketPainter old) =>
      old.drawing != drawing ||
      old.text != text ||
      old.sub != sub ||
      old.bg != bg ||
      old.fontScale != fontScale;
}

/// 지시서 PDF에 넣을 그림(흰 바탕 PNG).
Future<Uint8List> renderBracketPng(
  BracketDrawing drawing, {
  double width = 1400,
  double height = 900,
}) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(
    Offset.zero & Size(width, height),
    Paint()..color = Colors.white,
  );
  BracketPainter(
    drawing: drawing,
    text: const Color(0xFF1F2933),
    sub: const Color(0xFF55636D),
    bg: Colors.white,
    fontScale: 2.2,
  ).paint(canvas, Size(width, height));
  final img = await rec.endRecording().toImage(width.toInt(), height.toInt());
  final bd = await img.toByteData(format: ui.ImageByteFormat.png);
  return bd!.buffer.asUint8List();
}
