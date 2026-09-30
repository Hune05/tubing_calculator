// 결과 그림 둘: (1) 위에서 본 그림(네 발 심 판과 옆으로 밀 방향), (2) 옆에서 본 그림(네 발 심 판과 위아래 어긋남).
// 기계 그림은 alignment_machine_art.dart. 실제 크기 그림이 아니라 방향과 비율을 보이는 그림이다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'alignment_machine_art.dart';
import 'alignment_math.dart';
import 'alignment_scene_painter.dart';

void _txt(Canvas canvas, String t, Offset at, Color c, {double size = 11, bool center = true}) {
  final tp = TextPainter(
    text: TextSpan(text: t, style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: c)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, center ? at - Offset(tp.width / 2, tp.height / 2) : at);
}

/// 위에서 본 그림: 위쪽이 왼쪽, 아래쪽이 오른쪽(고정 쪽에서 모터를 바라볼 때).
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

  static double heightFor(double w) => alignTopHeightFor(w);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final lay = paintMachineTop(canvas, size, shimFront: shimFront, shimRear: shimRear);
    final my = lay.midY;
    final motor = lay.motor;

    // 지금 모터 위치(점선): 옆 어긋남을 크게 부풀린 것
    final zc = horizontal.at(0), zEnd = horizontal.at(xRear);
    final zMax = math.max(math.max(zc.abs(), zEnd.abs()), math.max(moveFront.abs(), moveRear.abs()));
    final zs = zMax < 1e-6 ? 0.0 : (h * 0.11) / zMax;
    final ghost = Path()
      ..moveTo(motor.left, motor.top + zc * zs)
      ..lineTo(motor.right, motor.top + zEnd * zs)
      ..lineTo(motor.right, motor.bottom + zEnd * zs)
      ..lineTo(motor.left, motor.bottom + zc * zs)
      ..close();
    alignDashPath(canvas, ghost, Paint()..color = alignCaution..style = PaintingStyle.stroke..strokeWidth = 2.4);

    // 목표 중심선(펌프 축)
    final target = Paint()..color = AppColors.text.withValues(alpha: 0.6)..strokeWidth = 1.5;
    for (var x = w * 0.03; x < w * 0.98; x += 12) {
      canvas.drawLine(Offset(x, my), Offset(x + 6, my), target);
    }

    // 네 발 표찰
    void chip(double cx, bool top, double mm, String tag) {
      final c = alignShimColor(mm);
      final edgeY = top ? my - lay.footHalfSpan : my + lay.footHalfSpan;
      final at = Offset((cx + (cx == lay.frontCx ? -7 : 7)).clamp(46.0, w - 46), top ? edgeY - 26 : edgeY + 26);
      canvas.drawLine(Offset(cx, edgeY), at + Offset(0, top ? 15 : -15), Paint()..color = c..strokeWidth = 1.3);
      alignLabel(canvas, '$tag\n${alignShimShort(mm)}', at, c, size: 10, minWidth: 58);
    }

    chip(lay.frontCx, true, shimFront, '앞·왼');
    chip(lay.rearCx, true, shimRear, '뒤·왼');
    chip(lay.frontCx, false, shimFront, '앞·오른');
    chip(lay.rearCx, false, shimRear, '뒤·오른');

    // 옆으로 미는 방향(앞·뒤)
    void arrow(double cx, double mm) {
      final at = Offset((cx + (cx == lay.frontCx ? -7 : 7)).clamp(46.0, w - 46), my + 40);
      if (mm.abs() < 0.005) {
        alignLabel(canvas, '옆 그대로', at, alignOk, size: 10);
        return;
      }
      final dir = mm > 0 ? 1.0 : -1.0;
      final p = Paint()..color = AppColors.brand..strokeWidth = 3.6..strokeCap = StrokeCap.round;
      final a = Offset(cx, my - dir * 16), b = Offset(cx, my + dir * 16);
      canvas.drawLine(a, b, p);
      canvas.drawLine(b, b + Offset(-6, -dir * 9), p);
      canvas.drawLine(b, b + Offset(6, -dir * 9), p);
      alignLabel(canvas, '옆 밀기\n${mm > 0 ? '오른쪽' : '왼쪽'} ${mm.abs().toStringAsFixed(2)}', at, AppColors.brand, size: 10, minWidth: 58);
    }

    arrow(lay.frontCx, moveFront);
    arrow(lay.rearCx, moveRear);

    _txt(canvas, '펌프 (고정)', Offset(w * 0.17, my + alignMachineScale(w) * 0.36 + 14), AppColors.textSub, size: 12);
    _txt(canvas, '왼쪽 ▲', const Offset(8, 4), AppColors.textSub, center: false);
    _txt(canvas, '오른쪽 ▼', Offset(8, h - 18), AppColors.textSub, center: false);
    _txt(canvas, '점선 = 지금 모터 위치(크게 부풀림)', Offset(w - 200, 4), alignCaution, center: false);
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

/// 옆에서 본 그림: 발 밑 심 판(넣기·빼기·그대로)과, 점선으로 지금 모터 위치(위아래 어긋남을 크게 부풀림).
class AlignSidePainter extends CustomPainter {
  final AxisLine vertical; // 모터 축의 위아래 어긋남(+ 위)
  final double xRear;
  final double shimFront;
  final double shimRear;
  AlignSidePainter({
    required this.vertical,
    required this.xRear,
    required this.shimFront,
    required this.shimRear,
  });

  static const double _topRoom = 34;
  static double heightFor(double w) => _topRoom + alignMachineScale(w) * 0.60 + 82;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final u = alignMachineScale(w);
    final lay = paintMachineSide(canvas, w, topRoom: _topRoom, shimFront: shimFront, shimRear: shimRear);
    final body = lay.motorBody;

    // 목표 중심선(펌프 축)
    final target = Paint()..color = AppColors.text.withValues(alpha: 0.6)..strokeWidth = 1.5;
    for (var x = w * 0.02; x < w * 0.98; x += 12) {
      canvas.drawLine(Offset(x, lay.axisY), Offset(x + 6, lay.axisY), target);
    }

    // 지금 모터 위치(점선): 위아래 어긋남을 크게 부풀린 것(+ 위쪽 = 화면 위)
    final vc = vertical.at(0), vEnd = vertical.at(xRear);
    final vMax = math.max(vc.abs(), vEnd.abs());
    final k = vMax < 1e-6 ? 0.0 : (u * 0.09) / vMax;
    final ghost = Path()
      ..moveTo(body.left, body.top - vc * k)
      ..lineTo(body.right, body.top - vEnd * k)
      ..lineTo(body.right, body.bottom - vEnd * k)
      ..lineTo(body.left, body.bottom - vc * k)
      ..close();
    alignDashPath(canvas, ghost, Paint()..color = alignCaution..style = PaintingStyle.stroke..strokeWidth = 2.4);

    // 심 표찰
    void chip(double x, double mm, String tag, double dx) {
      final c = alignShimColor(mm);
      final at = Offset((x + dx).clamp(50.0, w - 50), lay.ground + 40);
      canvas.drawLine(Offset(x, lay.baseTop), at - const Offset(0, 17), Paint()..color = c..strokeWidth = 1.3);
      alignLabel(canvas, '$tag\n심 ${alignShimShort(mm)}', at, c, size: 10, minWidth: 74);
    }

    chip(lay.frontX, shimFront, '앞발', -8);
    chip(lay.rearX, shimRear, '뒷발', 8);
    _txt(canvas, '펌프 (고정)', Offset(w * 0.17, lay.ground + 16), AppColors.textSub, size: 12);
    _txt(canvas, '점선 = 지금 모터 위치(크게 부풀림)', Offset(w - 200, 4), alignCaution, center: false);
  }

  @override
  bool shouldRepaint(covariant AlignSidePainter old) =>
      old.vertical.v0 != vertical.v0 ||
      old.vertical.slope != vertical.slope ||
      old.xRear != xRear ||
      old.shimFront != shimFront ||
      old.shimRear != shimRear;
}
