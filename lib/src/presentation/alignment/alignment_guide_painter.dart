// 축 정렬 안내 그림: 보는 자리와 방향. 펌프 쪽에서 본 커플링 끝에 다이얼이 12·3·6·9시로 도는 모습을 그린다.
// 입력칸 번호(①②③④)는 측정 그림과 같다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/field_view.dart';
import 'alignment_dial_painter.dart';

const Color _dialA = Color(0xFFE08A00);
const Color _edge = Color(0xFF2A3139);

/// 그림에 나오는 번호 글자.
const List<String> kAlignNumbers = ['①', '②', '③', '④'];

/// 표찰. [side]가 −1이면 오른쪽 끝을, +1이면 왼쪽 끝을 [at]에 맞춘다(0은 가운데).
void _chip(Canvas canvas, String title, String sub, Offset at0, Color color, {int side = 0}) {
  final tp = TextPainter(
    text: TextSpan(children: [
      TextSpan(text: title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: color)),
      TextSpan(text: '  $sub', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSub)),
    ]),
    textDirection: TextDirection.ltr,
  )..layout();
  final at = at0 + Offset(side * (tp.width / 2 + 8), 0);
  final r = RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: tp.width + 16, height: tp.height + 8), const Radius.circular(10));
  canvas.drawRRect(r.shift(const Offset(0, 1.5)), Paint()..color = Colors.black.withValues(alpha: 0.10));
  canvas.drawRRect(r, Paint()..color = Colors.white);
  canvas.drawRRect(r, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.3..color = color);
  tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
}

/// 펌프 쪽에 서서 모터 쪽을 본 커플링 끝. 다이얼을 12시에서 0으로 맞추고 3시(오른쪽) → 6시(아래) → 9시(왼쪽)로 돌려 읽는다.
/// 10-15 연동: [values]를 주면 바늘이 넣은 값(3·6·9시)을 가리키고, [highlight](0=12시 1=3시 2=6시 3=9시)
/// 자리를 강조한다. 값이 없으면 읽은 예(0, −0.10, −0.20, −0.10)를 보인다.
class AlignClockPainter extends CustomPainter {
  final List<double?>? values; // [3시, 6시, 9시]
  final int? highlight;
  final String? title; // 예: "다이얼 A"
  AlignClockPainter({this.values, this.highlight, this.title});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w / 2, h / 2);
    // 커플링 바깥 반지름. 위아래 표찰(다이얼 + 17 + 표찰 반 높이 약 14)까지 칸 안에 들게(10-15 폰 가로에서 6시 표찰이 넘쳤다).
    final R = math.max(10.0, math.min(math.min(h * 0.17, (h / 2 - 34) / 2.26), w * 0.14));
    final rd = R * 0.40; // 다이얼 반지름
    final dist = R + rd * 2.15; // 다이얼 중심까지

    // ── 커플링 끝(은색 원판, 볼트, 축, 키 홈)
    canvas.drawCircle(c.translate(2, 4), R, Paint()..color = Colors.black.withValues(alpha: 0.22)..maskFilter = MaskFilter.blur(BlurStyle.normal, R * 0.08));
    canvas.drawCircle(c, R, Paint()..shader = const RadialGradient(center: Alignment(-0.35, -0.4), colors: [Color(0xFFF1F3F5), Color(0xFFB4BBC3), Color(0xFF7E8790)], stops: [0, 0.6, 1]).createShader(Rect.fromCircle(center: c, radius: R)));
    canvas.drawCircle(c, R, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..color = _edge.withValues(alpha: 0.8));
    canvas.drawCircle(c, R * 0.9, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.white.withValues(alpha: 0.5));
    for (var k = 0; k < 6; k++) {
      final a = math.pi / 6 + 2 * math.pi * k / 6;
      final o = c + Offset(math.cos(a), math.sin(a)) * (R * 0.68);
      canvas.drawCircle(o, R * 0.085, Paint()..shader = const RadialGradient(center: Alignment(-0.4, -0.4), colors: [Color(0xFFE9ECEF), Color(0xFF6D7680)]).createShader(Rect.fromCircle(center: o, radius: R * 0.085)));
      canvas.drawCircle(o, R * 0.085, Paint()..style = PaintingStyle.stroke..strokeWidth = 0.8..color = _edge.withValues(alpha: 0.8));
    }
    canvas.drawCircle(c, R * 0.42, Paint()..shader = const RadialGradient(center: Alignment(-0.35, -0.4), colors: [Color(0xFFDDE1E5), Color(0xFF8C959E)]).createShader(Rect.fromCircle(center: c, radius: R * 0.42)));
    canvas.drawCircle(c, R * 0.42, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = _edge.withValues(alpha: 0.7));
    canvas.drawCircle(c, R * 0.24, Paint()..shader = const RadialGradient(center: Alignment(-0.35, -0.4), colors: [Color(0xFFF6F7F8), Color(0xFF9AA3AC)]).createShader(Rect.fromCircle(center: c, radius: R * 0.24)));
    canvas.drawCircle(c, R * 0.24, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = _edge.withValues(alpha: 0.8));
    canvas.drawRect(Rect.fromCenter(center: c.translate(0, -R * 0.24), width: R * 0.12, height: R * 0.1), Paint()..color = const Color(0xFF3A424A)); // 키

    // ── 돌리는 방향(12 → 3 → 6 → 9)
    final arc = Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(2.4, R * 0.05)..color = _dialA..strokeCap = StrokeCap.round;
    final ar = Rect.fromCircle(center: c, radius: R * 1.2);
    for (var q = 0; q < 3; q++) {
      final start = -math.pi / 2 + q * math.pi / 2 + 0.34;
      const sweep = math.pi / 2 - 0.68;
      canvas.drawArc(ar, start, sweep, false, arc);
      final end = start + sweep;
      final e = c + Offset(math.cos(end), math.sin(end)) * (R * 1.2);
      final t = Offset(-math.sin(end), math.cos(end));
      final n = Offset(math.cos(end), math.sin(end));
      canvas.drawLine(e, e - t * (R * 0.16) + n * (R * 0.1), arc);
      canvas.drawLine(e, e - t * (R * 0.16) - n * (R * 0.1), arc);
    }

    // ── 네 자리의 다이얼(같은 다이얼이 도는 것): 읽은 예와 같은 값
    final vs = values;
    String sub(String place, double? v) => vs == null
        ? place
        : (v == null ? '$place · —' : '$place · ${v > 0 ? '+' : ''}${v.toStringAsFixed(2)}');
    final spots = [
      (const Offset(0, -1), 0.0, '12시', vs == null ? '위 · 0 맞춤' : '0 맞춤', _dialA),
      (const Offset(1, 0), vs == null ? -0.10 : (vs[0] ?? 0), '3시', sub('오른쪽', vs?[0]), AppColors.brand),
      (const Offset(0, 1), vs == null ? -0.20 : (vs[1] ?? 0), '6시', sub('아래', vs?[1]), AppColors.brand),
      (const Offset(-1, 0), vs == null ? -0.10 : (vs[2] ?? 0), '9시', sub('왼쪽', vs?[2]), AppColors.brand),
    ];
    if (title != null) {
      final tp = TextPainter(
        text: TextSpan(text: title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: fc.text)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, const Offset(6, 4));
    }
    for (var i = 0; i < spots.length; i++) {
      final (u, v, title, sub, col0) = spots[i];
      final on = highlight == i;
      final col = highlight == null || on ? col0 : col0.withValues(alpha: 0.45);
      final dc = c + u * dist;
      if (on) {
        canvas.drawCircle(dc, rd * 1.35, Paint()..color = AppColors.brand.withValues(alpha: 0.14));
        canvas.drawCircle(dc, rd * 1.35, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = AppColors.brand);
      }
      paintDialGauge(canvas, dc, rd, value: v, stemTo: c + u * (R * 1.02), tag: col, numbers: false);
      if (u.dy != 0) {
        _chip(canvas, title, sub, dc + Offset(0, u.dy * (rd + 17)), col);
      } else {
        // 옆 자리 표찰은 다이얼 밑, 돌리는 화살표에 안 걸리게 바깥쪽으로
        _chip(canvas, title, sub, Offset(c.dx + u.dx * R * 1.38, dc.dy + rd + 18), col, side: u.dx > 0 ? 1 : -1);
      }
    }
  }

  @override
  bool shouldRepaint(covariant AlignClockPainter old) =>
      old.highlight != highlight ||
      old.title != title ||
      (old.values ?? const []).join('|') != (values ?? const []).join('|');
}
