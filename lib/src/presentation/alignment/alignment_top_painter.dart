// 결과 그림: 펌프·커플링·모터를 위에서 바로 본 단면도 느낌 그림. 모터 네 발 밑 심 판(넣기·빼기·그대로 색)과
// 옆으로 밀 방향을 붙인다. 위쪽이 왼쪽, 아래쪽이 오른쪽(고정 쪽에서 모터를 바라볼 때).
// 실제 크기 그림이 아니라 방향과 비율을 보이는 그림이다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'alignment_math.dart';
import 'alignment_scene_painter.dart';

class AlignTopPainter extends CustomPainter {
  final AxisLine horizontal; // 모터 축의 옆 어긋남(+ 오른쪽)
  final double xRear;
  final double shimFront;
  final double shimRear;
  final double moveFront;
  final double moveRear;
  AlignTopPainter({
    required this.horizontal,
    required this.xRear,
    required this.shimFront,
    required this.shimRear,
    required this.moveFront,
    required this.moveRear,
  });

  void _txt(Canvas canvas, String t, Offset at, Color c, {double size = 11, bool center = true}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: c)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center ? at - Offset(tp.width / 2, tp.height / 2) : at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final midY = h * 0.5;
    final line = Paint()..color = alignOutline.withValues(alpha: 0.35)..strokeWidth = 1;

    // ── 받침판(I빔 두 줄)
    alignBody(canvas, Rect.fromLTRB(w * 0.02, h * 0.10, w * 0.98, h * 0.90), const Color(0xFFEEF0F2), radius: 6, stroke: 1.5);
    for (final y in [h * 0.155, h * 0.845]) {
      alignBody(canvas, Rect.fromLTRB(w * 0.03, y - 6, w * 0.97, y + 6), alignBasePlate, radius: 2);
    }

    // ── 펌프(초록)
    final pumpDark = alignShade(alignPumpGreen, -0.12);
    for (final s in [-1.0, 1.0]) {
      alignBody(canvas, Rect.fromCenter(center: Offset(w * 0.15, midY + s * h * 0.205), width: w * 0.06, height: h * 0.06), pumpDark, radius: 2);
      alignBody(canvas, Rect.fromCenter(center: Offset(w * 0.215, midY + s * h * 0.205), width: w * 0.06, height: h * 0.06), pumpDark, radius: 2);
    }
    alignBody(canvas, Rect.fromLTRB(w * 0.06, midY - h * 0.13, w * 0.06 + 7, midY + h * 0.13), pumpDark, radius: 2);
    alignBody(canvas, Rect.fromLTRB(w * 0.06 + 7, midY - h * 0.08, w * 0.115, midY + h * 0.08), alignPumpGreen, radius: 2);
    alignBody(canvas, Rect.fromLTRB(w * 0.11, midY - h * 0.18, w * 0.25, midY + h * 0.18), alignPumpGreen, radius: 20);
    final dc = Offset(w * 0.18, midY);
    canvas.drawCircle(dc, h * 0.095, Paint()..color = pumpDark);
    canvas.drawCircle(dc, h * 0.095, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.3..color = alignOutline);
    canvas.drawCircle(dc, h * 0.055, Paint()..color = const Color(0xFF2E3A44));
    for (var k = 0; k < 6; k++) {
      final a = 2 * math.pi * k / 6;
      canvas.drawCircle(dc + Offset(math.cos(a), math.sin(a)) * (h * 0.078), 2.2, Paint()..color = alignOutline);
    }
    alignBody(canvas, Rect.fromLTRB(w * 0.25, midY - h * 0.19, w * 0.265, midY + h * 0.19), pumpDark, radius: 2);
    alignBody(canvas, Rect.fromLTRB(w * 0.265, midY - h * 0.10, w * 0.33, midY + h * 0.10), alignPumpGreen, radius: 6);
    for (final x in [0.28, 0.295, 0.31]) {
      canvas.drawLine(Offset(w * x, midY - h * 0.10 + 4), Offset(w * x, midY + h * 0.10 - 4), line);
    }

    // ── 축과 커플링
    alignBody(canvas, Rect.fromLTRB(w * 0.33, midY - 6, w * 0.60, midY + 6), alignSteel, radius: 2);
    alignBody(canvas, Rect.fromLTRB(w * 0.40, midY - h * 0.075, w * 0.455, midY + h * 0.075), alignShade(alignSteel, -0.08), radius: 4);
    alignBody(canvas, Rect.fromLTRB(w * 0.462, midY - h * 0.075, w * 0.52, midY + h * 0.075), alignSteel, radius: 4);

    // ── 모터 네 발(먼저 심 판, 그 위에 발)
    final frontCx = w * 0.64, rearCx = w * 0.87;
    final footW = w * 0.095, footH = h * 0.095;
    final motorTop = midY - h * 0.21, motorBottom = midY + h * 0.21;
    void foot(double cx, double cy, double mm, String tag, bool top) {
      final c = alignShimColor(mm);
      final fr = Rect.fromCenter(center: Offset(cx, cy), width: footW, height: footH);
      final shimR = fr.inflate(5).translate(0, top ? -3 : 3);
      final rr = RRect.fromRectAndRadius(shimR, const Radius.circular(3));
      if (mm < -0.005) {
        canvas.drawRRect(rr, Paint()..color = c.withValues(alpha: 0.25));
        alignDashPath(canvas, Path()..addRRect(rr), Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 2);
      } else {
        canvas.drawRRect(rr, Paint()..color = c);
        canvas.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.3..color = alignOutline);
      }
      alignBody(canvas, fr, alignShade(alignMotorBlue, -0.10), radius: 3);
      canvas.drawCircle(fr.center, 3.6, Paint()..color = alignOutline);
      final chip = Offset(cx + (cx == frontCx ? -7 : 7), top ? fr.top - 36 : fr.bottom + 36);
      canvas.drawLine(Offset(cx, top ? fr.top - 8 : fr.bottom + 8), chip + Offset(0, top ? 16 : -16), Paint()..color = c..strokeWidth = 1.3);
      alignLabel(canvas, '$tag\n${alignShimShort(mm)}', chip, c, size: 10, minWidth: 58);
    }

    foot(frontCx, motorTop, shimFront, '앞·왼', true);
    foot(rearCx, motorTop, shimRear, '뒤·왼', true);
    foot(frontCx, motorBottom, shimFront, '앞·오른', false);
    foot(rearCx, motorBottom, shimRear, '뒤·오른', false);

    // ── 모터(파랑)
    final motor = Rect.fromLTRB(w * 0.575, motorTop, w * 0.94, motorBottom);
    alignBody(canvas, motor, alignMotorBlue, radius: 14);
    for (var y = motor.top + 8; y < motor.bottom - 4; y += 7) {
      canvas.drawLine(Offset(motor.left + 8, y), Offset(motor.right - 8, y), Paint()..color = alignOutline.withValues(alpha: 0.22)..strokeWidth = 1.2);
    }
    alignBody(canvas, Rect.fromLTRB(w * 0.552, midY - h * 0.235, w * 0.59, midY + h * 0.235), alignShade(alignMotorBlue, -0.12), radius: 6);
    alignBody(canvas, Rect.fromLTRB(w * 0.93, midY - h * 0.16, w * 0.972, midY + h * 0.16), alignShade(alignMotorBlue, -0.16), radius: 10);
    alignBody(canvas, Rect.fromLTRB(w * 0.71, midY - h * 0.095, w * 0.81, midY + h * 0.095), alignShade(alignMotorBlue, -0.08), radius: 4);
    canvas.drawRect(Rect.fromLTRB(w * 0.725, midY - h * 0.075, w * 0.795, midY + h * 0.075), Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = alignOutline.withValues(alpha: 0.4));

    // ── 지금 모터 위치(점선): 옆 어긋남을 크게 부풀린 것
    final zc = horizontal.at(0), zEnd = horizontal.at(xRear);
    final zMax = math.max(math.max(zc.abs(), zEnd.abs()), math.max(moveFront.abs(), moveRear.abs()));
    final zs = zMax < 1e-6 ? 0.0 : (h * 0.10) / zMax;
    final ghost = Path()
      ..moveTo(motor.left, motor.top + zc * zs)
      ..lineTo(motor.right, motor.top + zEnd * zs)
      ..lineTo(motor.right, motor.bottom + zEnd * zs)
      ..lineTo(motor.left, motor.bottom + zc * zs)
      ..close();
    alignDashPath(canvas, ghost, Paint()..color = alignCaution..style = PaintingStyle.stroke..strokeWidth = 2.2);

    // 목표 중심선(펌프 축)
    final target = Paint()..color = AppColors.text.withValues(alpha: 0.55)..strokeWidth = 1.4;
    for (var x = w * 0.04; x < w * 0.96; x += 12) {
      canvas.drawLine(Offset(x, midY), Offset(x + 6, midY), target);
    }

    // ── 옆으로 미는 방향(앞·뒤)
    void arrow(double cx, double mm) {
      final at = Offset(cx + (cx == frontCx ? -7 : 7), midY + 40);
      if (mm.abs() < 0.005) {
        alignLabel(canvas, '옆 그대로', at, alignOk, size: 10);
        return;
      }
      final dir = mm > 0 ? 1.0 : -1.0;
      final p = Paint()..color = AppColors.brand..strokeWidth = 3.4..strokeCap = StrokeCap.round;
      final a = Offset(cx, midY - dir * 16), b = Offset(cx, midY + dir * 16);
      canvas.drawLine(a, b, p);
      canvas.drawLine(b, b + Offset(-6, -dir * 9), p);
      canvas.drawLine(b, b + Offset(6, -dir * 9), p);
      alignLabel(canvas, '옆 밀기\n${mm > 0 ? '오른쪽' : '왼쪽'} ${mm.abs().toStringAsFixed(2)}', at, AppColors.brand, size: 10, minWidth: 58);
    }

    arrow(frontCx, moveFront);
    arrow(rearCx, moveRear);

    // ── 이름과 방향
    _txt(canvas, '펌프 (고정)', Offset(w * 0.18, midY + h * 0.30), AppColors.textSub, size: 12);
    _txt(canvas, '왼쪽 ▲', Offset(8, 6), AppColors.textSub, center: false);
    _txt(canvas, '오른쪽 ▼', Offset(8, h - 20), AppColors.textSub, center: false);
    _txt(canvas, '점선 = 지금 모터 위치(크게 부풀림)', Offset(w - 196, 6), alignCaution, center: false);
  }

  @override
  bool shouldRepaint(covariant AlignTopPainter old) =>
      old.horizontal.v0 != horizontal.v0 ||
      old.horizontal.slope != horizontal.slope ||
      old.xRear != xRear ||
      old.shimFront != shimFront ||
      old.shimRear != shimRear ||
      old.moveFront != moveFront ||
      old.moveRear != moveRear;
}
