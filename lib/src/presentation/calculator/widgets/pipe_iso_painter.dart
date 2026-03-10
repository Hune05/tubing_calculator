import 'package:flutter/material.dart';
import 'dart:math' as math;

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (double i = 0; i < size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PipeIsoPainter extends CustomPainter {
  final int mode;
  final int innerTab;
  final double val1;
  final double val2;
  final double angle;
  final Color themeColor;

  PipeIsoPainter({
    required this.mode,
    required this.innerTab,
    required this.val1,
    required this.val2,
    required this.angle,
    required this.themeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final paint = Paint()
      ..color = themeColor
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final double startX = size.width * 0.15;
    final double midY = size.height * 0.55;

    double dynamicH = (val1 > 0 ? val1 : 50).clamp(20, 70).toDouble();
    double safeAngle = (angle > 0 ? angle : 45).clamp(10, 80).toDouble();
    double rad = safeAngle * (math.pi / 180);
    double runX = dynamicH / math.tan(rad);
    runX = runX.clamp(10, size.width * 0.5).toDouble();

    path.moveTo(startX, midY);

    if (mode == 0) {
      path.lineTo(size.width * 0.85, midY);
    } else if (mode == 1) {
      path.lineTo(size.width * 0.5, midY);
      path.arcToPoint(
        Offset(size.width * 0.5 + 40, midY - 40),
        radius: const Radius.circular(40),
        clockwise: false,
      );
      path.lineTo(size.width * 0.5 + 40, size.height * 0.1);
    } else if (mode == 2) {
      path.lineTo(size.width * 0.35, midY);
      path.lineTo(size.width * 0.35 + runX, midY - dynamicH);
      path.lineTo(size.width * 0.85, midY - dynamicH);
    } else if (mode == 3) {
      path.lineTo(size.width * 0.25, midY);
      if (innerTab == 0) {
        path.lineTo(size.width * 0.25 + runX, midY - dynamicH);
        path.lineTo(size.width * 0.25 + (runX * 2), midY);
      } else {
        double w = (val2 > 0 ? val2 : 30).clamp(10, 60).toDouble();
        path.lineTo(size.width * 0.25 + runX, midY - dynamicH);
        path.lineTo(size.width * 0.25 + runX + w, midY - dynamicH);
        path.lineTo(size.width * 0.25 + (runX * 2) + w, midY);
      }
      path.lineTo(size.width * 0.85, midY);
    } else if (mode == 4) {
      path.lineTo(size.width * 0.3, midY);
      path.lineTo(size.width * 0.3 + runX, midY - dynamicH + 15);
      path.lineTo(size.width * 0.85, midY - dynamicH + 15);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = themeColor.withValues(alpha: 0.3)
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant PipeIsoPainter oldDelegate) {
    return oldDelegate.val1 != val1 ||
        oldDelegate.val2 != val2 ||
        oldDelegate.angle != angle ||
        oldDelegate.mode != mode ||
        oldDelegate.innerTab != innerTab;
  }
}
