// 축 정렬 안내 그림: 3시·6시·9시와 보는 방향을 보여 주는 시계 그림. 입력칸 번호(①②③④)는 측정 그림과 같다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

const Color _dialA = Color(0xFFE08A00);

/// 그림에 나오는 번호 글자.
const List<String> kAlignNumbers = ['①', '②', '③', '④'];

void _text(Canvas canvas, String s, Offset at, {double size = 12, Color color = AppColors.text, FontWeight w = FontWeight.w800, TextAlign align = TextAlign.center, double maxW = 140}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color, fontWeight: w, height: 1.2)),
    textAlign: align,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxW);
  tp.paint(canvas, Offset(at.dx - tp.width / 2, at.dy - tp.height / 2));
}

/// 시계 그림: 고정 쪽(펌프)에서 이동 쪽(모터)을 바라본 모양의 축 끝. 12·3·6·9시와 읽는 순서.
/// 시각 이름은 눈금 안쪽, 방향 이름(위·오른쪽·아래·왼쪽)은 바깥에 둔다.
class AlignClockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 30;

    // 판(그림자 + 그라데이션 + 하이라이트)
    canvas.drawCircle(c.translate(0, 3), r, Paint()..color = Colors.black.withValues(alpha: 0.16)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFFFFFF), Color(0xFFE4EEF0)],
        ).createShader(rect),
    );
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = AppColors.brand);
    // 가운데: 축 끝
    canvas.drawCircle(c, r * 0.22, Paint()..color = const Color(0xFFB9C4CE));
    canvas.drawCircle(c, r * 0.22, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.black26);
    canvas.drawCircle(c, 2.4, Paint()..color = Colors.black54);

    // 읽는 순서: 시계 방향 호(12 → 3 → 6 → 9). 눈금 안쪽 가까이에 둔다.
    final arc = Paint()
      ..color = _dialA
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final ar = r * 0.66;
    const startAng = -math.pi / 2 + 0.32;
    const sweep = math.pi * 1.5 - 0.64;
    canvas.drawArc(Rect.fromCircle(center: c, radius: ar), startAng, sweep, false, arc);
    final endAng = startAng + sweep; // 9시 근처
    final tip = c + Offset(math.cos(endAng), math.sin(endAng)) * ar;
    final back = endAng + math.pi; // 화살촉은 진행 방향 뒤쪽으로 벌린다
    final tang = endAng + math.pi / 2;
    for (final d in [0.55, -0.55]) {
      final dir = Offset(math.cos(tang + math.pi + d), math.sin(tang + math.pi + d));
      canvas.drawLine(tip, tip + dir * 9, arc);
    }
    if (back.isNaN) return;

    // 눈금·시각 이름(안쪽)·방향 이름(바깥)
    final marks = <(double, String, String, Color)>[
      (0, '12시', '위', AppColors.text),
      (90, '3시', '오른쪽', AppColors.brand),
      (180, '6시', '아래', AppColors.brand),
      (270, '9시', '왼쪽', AppColors.brand),
    ];
    for (final (deg, name, dirName, color) in marks) {
      final a = (deg - 90) * math.pi / 180;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        c + dir * (r - 8),
        c + dir * r,
        Paint()
          ..color = color
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      _text(canvas, name, c + dir * (r * 0.84 - 4), size: 11, color: color, w: FontWeight.w900, maxW: 40);
      _text(canvas, dirName, c + dir * (r + 15), size: 11, color: AppColors.textSub, w: FontWeight.w700, maxW: 50);
    }
    // 12시는 0으로 맞춘다는 표시
    _text(canvas, '0 맞춤', c + const Offset(0, -1) * (r * 0.4), size: 10, color: _dialA, w: FontWeight.w800, maxW: 50);
  }

  @override
  bool shouldRepaint(covariant AlignClockPainter old) => false;
}
