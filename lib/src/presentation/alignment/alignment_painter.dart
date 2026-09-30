// 축 정렬 그림: 옆에서 본 모양(위아래)과 위에서 본 모양(좌우)에서 두 축이 어긋난 것을 크게 부풀려 그리고,
// 앞발·뒷발에 넣고 뺄 심과 밀 양을 화살표로 보여 준다. 실제 값이 아니라 어긋난 방향과 크기 비율을 보이는 그림이다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'alignment_math.dart';

/// 한 방향(위아래 또는 옆)의 그림.
class AlignAxisPainter extends CustomPainter {
  final AxisLine line;
  final double xFront;
  final double xRear;
  final double shimFront;
  final double shimRear;
  final String title;
  final bool vertical; // true면 "넣기/빼기", false면 "오른쪽/왼쪽"
  final double couplingX; // 그림 안에서 커플링 위치(0 ~ 1)

  AlignAxisPainter({
    required this.line,
    required this.xFront,
    required this.xRear,
    required this.shimFront,
    required this.shimRear,
    required this.title,
    required this.vertical,
    this.couplingX = 0.34,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final midY = h * 0.5;
    final cx = w * couplingX;

    // 길이 축(x, mm)을 화면에 놓는다: 커플링 중심 0 → cx, 뒷발이 오른쪽 끝 근처.
    final span = math.max(xRear, 1.0);
    final pxPerMm = (w * 0.94 - cx) / span;
    double sx(double xmm) => cx + xmm * pxPerMm;

    // 세로(어긋남) 배율: 가장 큰 어긋남이 그림 높이의 30%쯤 되게 부풀린다.
    final vMax = math.max(
      math.max(line.at(-span * 0.35).abs(), line.at(xRear).abs()),
      math.max(shimFront.abs(), shimRear.abs()),
    );
    final vScale = vMax < 1e-6 ? 0.0 : (h * 0.30) / vMax;
    double sy(double vmm) => midY - vmm * vScale * (vertical ? 1 : -1);

    // 바탕 눈금선
    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, midY), Offset(w, midY), grid);

    // 고정 쪽 축(회색, 왼쪽에서 커플링까지)과 이동 쪽 축 그림자·본체·하이라이트
    void shaft(Offset a, Offset b, Color base, double thick) {
      final shadow = Paint()
        ..color = Colors.black.withValues(alpha: 0.14)
        ..strokeWidth = thick + 2
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawLine(a.translate(0, 3), b.translate(0, 3), shadow);
      final body = Paint()
        ..color = base
        ..strokeWidth = thick
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(a, b, body);
      final hi = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = thick * 0.28
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(a.translate(0, -thick * 0.22), b.translate(0, -thick * 0.22), hi);
    }

    const thick = 12.0;
    shaft(Offset(w * 0.04, midY), Offset(cx, midY), const Color(0xFF8A96A3), thick);
    final mStart = Offset(cx, sy(line.at(0)));
    final mEnd = Offset(sx(span * 1.02), sy(line.at(span * 1.02)));
    shaft(mStart, mEnd, AppColors.brand, thick);

    // 커플링 표시
    final cp = Paint()
      ..color = AppColors.text.withValues(alpha: 0.55)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(cx, midY - h * 0.36), Offset(cx, midY + h * 0.36), cp);

    // 발: 가고 싶은 위치(고정 쪽 축 높이)까지 화살표
    void foot(double xmm, double shim, String name) {
      final x = sx(xmm);
      final yNow = sy(line.at(xmm));
      final yGoal = midY;
      final p = Paint()
        ..color = shim.abs() < 0.005 ? AppColors.ok : AppColors.caution
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, yNow), Offset(x, yGoal), p);
      canvas.drawCircle(Offset(x, yNow), 4.5, Paint()..color = AppColors.brand);
      canvas.drawCircle(Offset(x, yGoal), 4.5, p);
      // 화살촉
      final dir = yGoal >= yNow ? 1.0 : -1.0;
      if ((yGoal - yNow).abs() > 8) {
        final tip = Offset(x, yGoal);
        canvas.drawLine(tip, Offset(x - 5, yGoal - dir * 8), p);
        canvas.drawLine(tip, Offset(x + 5, yGoal - dir * 8), p);
      }
      final text = vertical ? shimText(shim) : moveText(shim);
      final tp = TextPainter(
        text: TextSpan(
          text: '$name\n$text',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.text, height: 1.25),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 110);
      final below = yNow >= midY;
      final ty = below ? math.min(h - tp.height - 2, yNow + 10) : math.max(2.0, yNow - tp.height - 10);
      tp.paint(canvas, Offset((x - tp.width / 2).clamp(2.0, w - tp.width - 2), ty));
    }

    foot(xFront, shimFront, '앞발');
    foot(xRear, shimRear, '뒷발');

    final label = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textSub),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, const Offset(8, 4));
    final s = TextPainter(
      text: const TextSpan(
        text: '고정 쪽',
        style: TextStyle(fontSize: 11, color: AppColors.textFaint),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    s.paint(canvas, Offset(w * 0.04, midY + 12));
    final m = TextPainter(
      text: const TextSpan(
        text: '이동 쪽(모터)',
        style: TextStyle(fontSize: 11, color: AppColors.brand),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    m.paint(canvas, Offset(cx + 8, midY + h * 0.36 - 14));
  }

  @override
  bool shouldRepaint(covariant AlignAxisPainter old) =>
      old.line.v0 != line.v0 ||
      old.line.slope != line.slope ||
      old.shimFront != shimFront ||
      old.shimRear != shimRear ||
      old.xFront != xFront ||
      old.xRear != xRear;
}
