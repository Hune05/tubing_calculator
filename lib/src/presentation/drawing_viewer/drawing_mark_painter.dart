// 도면 위 표시 그리기. 화면(보기)과 내보내기(PDF) 모두 이 그림을 쓴다. 좌표는 쪽 그림 픽셀.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'drawing_models.dart';

/// 쪽 크기에 맞춘 표시 크기.
class MarkScale {
  final double stamp; // 도장(확인·틀림·질문·문제) 지름
  final double stroke; // 선 굵기
  final double font; // 글자 크기
  const MarkScale(this.stamp, this.stroke, this.font);

  /// [viewScale]가 있으면(화면 보기) 화면에서 너무 작아지지 않게 최소 크기를 둔다.
  factory MarkScale.forPage(Size page, {double? viewScale}) {
    final l = math.max(page.width, page.height);
    var stamp = l / 45, stroke = math.max(2.0, l / 650), font = l / 80;
    if (viewScale != null && viewScale > 0) {
      stamp = math.min(math.max(stamp, 30 / viewScale), l / 10);
      stroke = math.max(stroke, 2.4 / viewScale);
      font = math.min(math.max(font, 13 / viewScale), l / 25);
    }
    return MarkScale(stamp, stroke, font);
  }
}

Offset markPoint(DrawingMark m, int i, Size page) => Offset(m.points[i].$1 * page.width, m.points[i].$2 * page.height);

/// 되풀이 구름(개정 구름): 네모 둘레를 작은 호로 두른다.
Path revisionCloud(Rect r, double bump) {
  final path = Path();
  final corners = [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
  var first = true;
  for (var e = 0; e < 4; e++) {
    final a = corners[e], b = corners[(e + 1) % 4];
    final len = (b - a).distance;
    final n = math.max(1, (len / (bump * 2)).round());
    final dir = (b - a) / len;
    final out = Offset(dir.dy, -dir.dx); // 네모 바깥쪽(시계 방향 둘레)
    for (var k = 0; k < n; k++) {
      final p = a + dir * (len * k / n);
      final q = a + dir * (len * (k + 1) / n);
      if (first) {
        path.moveTo(p.dx, p.dy);
        first = false;
      }
      final mid = (p + q) / 2 + out * (len / n) * 0.45;
      path.quadraticBezierTo(mid.dx, mid.dy, q.dx, q.dy);
    }
  }
  path.close();
  return path;
}

void _numberBadge(Canvas c, Offset at, int no, Color col, double d) {
  final r = d * 0.34;
  c.drawCircle(at, r, Paint()..color = Colors.white);
  c.drawCircle(at, r, Paint()..style = PaintingStyle.stroke..strokeWidth = d * 0.06..color = col);
  final tp = TextPainter(
    text: TextSpan(text: '$no', style: TextStyle(fontSize: r * 1.15, fontWeight: FontWeight.w900, color: col, height: 1)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
}

void _label(Canvas c, String text, Offset at, Color col, double font, {bool below = true}) {
  if (text.isEmpty) return;
  final tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(fontSize: font, fontWeight: FontWeight.w800, color: col, height: 1.2)),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: font * 22);
  final pad = font * 0.3;
  final box = Rect.fromLTWH(at.dx, below ? at.dy : at.dy - tp.height - pad * 2, tp.width + pad * 2, tp.height + pad * 2);
  c.drawRRect(RRect.fromRectAndRadius(box, Radius.circular(pad)), Paint()..color = Colors.white.withValues(alpha: 0.92));
  c.drawRRect(RRect.fromRectAndRadius(box, Radius.circular(pad)), Paint()..style = PaintingStyle.stroke..strokeWidth = font * 0.08..color = col);
  tp.paint(c, box.topLeft + Offset(pad, pad));
}

/// 표시 하나를 그린다.
void paintMark(Canvas c, DrawingMark m, Size page, {bool selected = false, double? viewScale}) {
  if (m.points.isEmpty) return;
  final s = MarkScale.forPage(page, viewScale: viewScale);
  final col = Color(m.color.argb).withValues(alpha: m.done ? 0.45 : 1);
  final p0 = markPoint(m, 0, page);
  final line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = s.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = col;

  if (selected) {
    final b = markBounds(m, page, viewScale: viewScale).inflate(s.stamp * 0.35);
    c.drawRRect(RRect.fromRectAndRadius(b, Radius.circular(s.stamp * 0.2)), Paint()..color = const Color(0x3300A0FF));
    c.drawRRect(RRect.fromRectAndRadius(b, Radius.circular(s.stamp * 0.2)), Paint()..style = PaintingStyle.stroke..strokeWidth = s.stroke * 0.8..color = const Color(0xFF0088FF));
  }

  switch (m.kind) {
    case MarkKind.ok:
    case MarkKind.wrong:
    case MarkKind.question:
      final d = s.stamp;
      c.drawCircle(p0 + Offset(d * 0.04, d * 0.06), d / 2, Paint()..color = Colors.black.withValues(alpha: 0.18));
      c.drawCircle(p0, d / 2, Paint()..color = Colors.white.withValues(alpha: 0.9));
      c.drawCircle(p0, d / 2, Paint()..style = PaintingStyle.stroke..strokeWidth = d * 0.09..color = col);
      final g = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = d * 0.12
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = col;
      if (m.kind == MarkKind.ok) {
        c.drawPath(
          Path()
            ..moveTo(p0.dx - d * 0.22, p0.dy + d * 0.01)
            ..lineTo(p0.dx - d * 0.05, p0.dy + d * 0.18)
            ..lineTo(p0.dx + d * 0.24, p0.dy - d * 0.17),
          g,
        );
      } else if (m.kind == MarkKind.wrong) {
        c.drawLine(p0 + Offset(-d * 0.18, -d * 0.18), p0 + Offset(d * 0.18, d * 0.18), g);
        c.drawLine(p0 + Offset(d * 0.18, -d * 0.18), p0 + Offset(-d * 0.18, d * 0.18), g);
      } else {
        final tp = TextPainter(
          text: TextSpan(text: '?', style: TextStyle(fontSize: d * 0.68, fontWeight: FontWeight.w900, color: col, height: 1)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, p0 - Offset(tp.width / 2, tp.height / 2));
      }
      if (m.no > 0) _numberBadge(c, p0 + Offset(d * 0.5, -d * 0.5), m.no, col, d);
    case MarkKind.issue:
      final d = s.stamp;
      // 핀: 끝이 p0을 찍는다
      final head = p0 - Offset(0, d * 0.95);
      final pin = Path()
        ..moveTo(p0.dx, p0.dy)
        ..quadraticBezierTo(head.dx - d * 0.55, head.dy + d * 0.25, head.dx - d * 0.5, head.dy)
        ..arcToPoint(head + Offset(d * 0.5, 0), radius: Radius.circular(d * 0.5))
        ..quadraticBezierTo(head.dx + d * 0.55, head.dy + d * 0.25, p0.dx, p0.dy)
        ..close();
      c.drawPath(pin.shift(Offset(d * 0.05, d * 0.07)), Paint()..color = Colors.black.withValues(alpha: 0.2));
      c.drawPath(pin, Paint()..color = col);
      _numberBadge(c, head, m.no, col, d * 1.25);
    case MarkKind.arrow:
      if (m.points.length < 2) break;
      final p1 = markPoint(m, 1, page);
      c.drawLine(p0, p1, line);
      final dir = p1 - p0;
      final len = dir.distance;
      if (len > 0) {
        final u = dir / len, n = Offset(-u.dy, u.dx);
        final h = s.stamp * 0.45;
        c.drawPath(Path()..moveTo(p1.dx, p1.dy)..lineTo((p1 - u * h + n * h * 0.5).dx, (p1 - u * h + n * h * 0.5).dy)..lineTo((p1 - u * h - n * h * 0.5).dx, (p1 - u * h - n * h * 0.5).dy)..close(), Paint()..color = col);
      }
      _label(c, m.text, p0 + Offset(s.stroke, s.stroke), col, s.font);
    case MarkKind.rect:
    case MarkKind.cloud:
      if (m.points.length < 2) break;
      final r = Rect.fromPoints(p0, markPoint(m, 1, page));
      if (m.kind == MarkKind.rect) {
        c.drawRect(r, line);
      } else {
        c.drawPath(revisionCloud(r, s.stamp * 0.28), line);
      }
      _label(c, m.text, r.bottomLeft + Offset(0, s.stroke * 2), col, s.font);
    case MarkKind.pen:
      if (m.points.length < 2) break;
      final path = Path()..moveTo(p0.dx, p0.dy);
      for (var i = 1; i < m.points.length; i++) {
        final q = markPoint(m, i, page);
        path.lineTo(q.dx, q.dy);
      }
      c.drawPath(path, line);
    case MarkKind.text:
      _label(c, m.text.isEmpty ? '글' : m.text, p0, col, s.font * 1.2);
  }
}

/// 표시가 차지하는 자리(누르기·선택 표시용).
Rect markBounds(DrawingMark m, Size page, {double? viewScale}) {
  final s = MarkScale.forPage(page, viewScale: viewScale);
  final p0 = markPoint(m, 0, page);
  switch (m.kind) {
    case MarkKind.ok:
    case MarkKind.wrong:
    case MarkKind.question:
      return Rect.fromCircle(center: p0, radius: s.stamp * 0.6);
    case MarkKind.issue:
      return Rect.fromLTRB(p0.dx - s.stamp * 0.6, p0.dy - s.stamp * 1.6, p0.dx + s.stamp * 0.6, p0.dy + s.stamp * 0.1);
    case MarkKind.text:
      return Rect.fromLTWH(p0.dx, p0.dy, math.max(s.font * 3, s.font * 0.7 * m.text.length), s.font * 1.8);
    default:
      var r = Rect.fromPoints(p0, p0);
      for (var i = 1; i < m.points.length; i++) {
        r = r.expandToInclude(Rect.fromPoints(markPoint(m, i, page), markPoint(m, i, page)));
      }
      return r.inflate(s.stroke * 3);
  }
}

/// 누른 자리에 있는 표시(위에 그린 것부터). 없으면 null.
DrawingMark? hitMark(List<DrawingMark> marks, int page, Offset at, Size pageSize, {double slop = 0, double? viewScale}) {
  for (final m in marks.reversed) {
    if (m.page != page) continue;
    if (markBounds(m, pageSize, viewScale: viewScale).inflate(slop).contains(at)) return m;
  }
  return null;
}

class DrawingMarksPainter extends CustomPainter {
  final List<DrawingMark> marks;
  final int page;
  final String? selectedId;
  final DrawingMark? draft;
  final double? viewScale;
  DrawingMarksPainter({required this.marks, required this.page, this.selectedId, this.draft, this.viewScale});

  @override
  void paint(Canvas canvas, Size size) {
    for (final m in marks) {
      if (m.page == page) paintMark(canvas, m, size, selected: m.id == selectedId, viewScale: viewScale);
    }
    if (draft != null) paintMark(canvas, draft!, size, viewScale: viewScale);
  }

  @override
  bool shouldRepaint(covariant DrawingMarksPainter old) => true;
}
