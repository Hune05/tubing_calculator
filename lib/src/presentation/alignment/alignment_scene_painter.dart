// 축 정렬 그림에 함께 쓰는 색·글씨·표찰 도구. 그림 자체는 alignment_render.dart에 있다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

const Color alignCaution = AppColors.caution; // 넣기(호박색)
const Color alignRemove = Color(0xFFE5484D); // 빼기(빨강)
const Color alignOk = AppColors.ok; // 그대로(초록)

Color alignShimColor(double mm) => mm.abs() < 0.005 ? alignOk : (mm > 0 ? alignCaution : alignRemove);

String alignShimShort(double mm) {
  if (mm.abs() < 0.005) return '그대로';
  return '${mm > 0 ? '넣기' : '빼기'} ${mm.abs().toStringAsFixed(2)}';
}

String alignMoveShort(double mm) {
  if (mm.abs() < 0.005) return '옆 그대로';
  return '${mm > 0 ? '오른쪽' : '왼쪽'} ${mm.abs().toStringAsFixed(2)}';
}

/// 테두리 있는 흰 표찰 하나(그림 위에 값을 붙일 때).
void alignLabel(Canvas canvas, String text, Offset at, Color color, {double size = 11, double minWidth = 0}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(fontSize: size, color: color, fontWeight: FontWeight.w900, height: 1.2)),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 130);
  final r = Rect.fromCenter(center: at, width: math.max(tp.width + 12, minWidth), height: tp.height + 6);
  final rr = RRect.fromRectAndRadius(r, const Radius.circular(8));
  canvas.drawRRect(rr.shift(const Offset(0, 1.5)), Paint()..color = Colors.black.withValues(alpha: 0.14));
  canvas.drawRRect(rr, Paint()..color = Colors.white);
  canvas.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..color = color);
  tp.paint(canvas, Offset(at.dx - tp.width / 2, at.dy - tp.height / 2));
}

void alignDashPath(Canvas canvas, Path path, Paint paint) {
  for (final m in path.computeMetrics()) {
    var d = 0.0;
    while (d < m.length) {
      canvas.drawPath(m.extractPath(d, math.min(d + 7, m.length)), paint);
      d += 12;
    }
  }
}
