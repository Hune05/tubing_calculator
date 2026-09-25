// 수평계·각도기 그림. NixGame "Bubble Level" 앱 모양을 따랐다:
//  - 세웠을 때: 화면 전체를 두 색(흰·파랑)으로 나누고, 경계선이 늘 진짜 수직(추 방향)을
//    가리킨다. 폰 축(또는 잡아 둔 기준)과 수직 사이를 빨간 쐐기로 칠한다.
//  - 눕혔을 때: 초록 화면에 큰 원 기포, 가장자리 가운데 표시.
//  - 왼쪽 가장자리 cm 자.
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/field_view.dart';

// 색의 뜻(D-B): 앱의 주 색 하나(청록). 예전에는 이 화면만 파랑이었다.
const Color kLevelBlue = AppColors.brand;
const Color kLevelGreen = Color(0xFF00866E);
const Color kLevelRed = Color(0xFFFF1E1E);
const Color kLevelWhite = Colors.white;

/// 화면에서 "위쪽(추의 반대)"을 가리키는 방향. [rotationDeg]는 screenRotation 값
/// (세로로 세우면 0). 화면 y는 아래로 커진다.
Offset upOnScreen(double rotationDeg) {
  final r = rotationDeg * math.pi / 180;
  return Offset(math.sin(r), -math.cos(r));
}

/// 세웠을 때: 두 색 + 빨간 쐐기 + 가운데 십자.
class SplitLevelPainter extends CustomPainter {
  /// 지금 폰 돌림(°). 경계선은 이 각의 수직.
  final double rotationDeg;

  /// 쐐기 반대편 선(°). 없으면 쐐기를 안 그린다.
  final double? referenceDeg;

  /// 흰 쪽 바탕. 야간 보기에서는 어두운 색(눈부심 줄임, D-D).
  final Color background;

  SplitLevelPainter({
    required this.rotationDeg,
    this.referenceDeg,
    this.background = kLevelWhite,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final far = size.longestSide * 2;
    final up = upOnScreen(rotationDeg);
    final right = Offset(-up.dy, up.dx); // 위쪽에서 오른쪽으로 90°

    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    // 경계선 오른쪽(세로로 들었을 때)을 파랑으로.
    final blue = Path()
      ..moveTo((c + up * far).dx, (c + up * far).dy)
      ..lineTo((c + up * far + right * far).dx, (c + up * far + right * far).dy)
      ..lineTo((c - up * far + right * far).dx, (c - up * far + right * far).dy)
      ..lineTo((c - up * far).dx, (c - up * far).dy)
      ..close();
    canvas.drawPath(blue, Paint()..color = kLevelBlue);

    if (referenceDeg != null) {
      final ref = upOnScreen(referenceDeg!);
      final wedge = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo((c + ref * far).dx, (c + ref * far).dy)
        ..lineTo((c + up * far).dx, (c + up * far).dy)
        ..close()
        ..moveTo(c.dx, c.dy)
        ..lineTo((c - ref * far).dx, (c - ref * far).dy)
        ..lineTo((c - up * far).dx, (c - up * far).dy)
        ..close();
      canvas.drawPath(wedge, Paint()..color = kLevelRed);
    }

    // 가운데 십자와 가장자리 가운데 표시(폰 축)
    final mark = Paint()
      ..color = kLevelBlue.withValues(alpha: 0.9)
      ..strokeWidth = 1.5;
    canvas.drawLine(c - const Offset(36, 0), c + const Offset(36, 0), mark);
    canvas.drawLine(c - const Offset(0, 36), c + const Offset(0, 36), mark);
    final edge = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(c.dx, 0), Offset(c.dx, 44), mark);
    canvas.drawLine(
      Offset(c.dx, size.height - 64),
      Offset(c.dx, size.height),
      mark,
    );
    canvas.drawLine(
      Offset(size.width - 72, c.dy),
      Offset(size.width, c.dy),
      edge,
    );
  }

  @override
  bool shouldRepaint(SplitLevelPainter old) =>
      old.rotationDeg != rotationDeg ||
      old.referenceDeg != referenceDeg ||
      old.background != background;
}

/// 눕혔을 때: 초록 바탕 + 큰 원 기포.
class BubbleLevelPainter extends CustomPainter {
  /// 기포 자리(-1~1, 높은 쪽으로).
  final Offset bubble;
  final bool level;

  BubbleLevelPainter({required this.bubble, required this.level});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawRect(Offset.zero & size, Paint()..color = kLevelGreen);
    final r = size.width * 0.34;
    final travel = math.min(size.width, size.height) / 2 - r * 0.6;
    final pos = c + Offset(bubble.dx, bubble.dy) * travel;

    // 가운데 자리(기포가 여기 오면 수평)
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: level ? 0.9 : 0.35),
    );
    // 기포: 연한 원 두 겹(그림자처럼 조금 비껴)
    canvas.drawCircle(
      pos + Offset(-r * 0.05, r * 0.04),
      r,
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
    canvas.drawCircle(
      pos,
      r * 0.95,
      Paint()..color = Colors.white.withValues(alpha: level ? 0.45 : 0.3),
    );

    final mark = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(c.dx, 0), Offset(c.dx, 44), mark);
    canvas.drawLine(
      Offset(c.dx, size.height - 64),
      Offset(c.dx, size.height),
      mark,
    );
    canvas.drawLine(
      Offset(size.width - 72, c.dy),
      Offset(size.width, c.dy),
      mark,
    );
  }

  @override
  bool shouldRepaint(BubbleLevelPainter old) =>
      old.bubble != bubble || old.level != level;
}

/// 왼쪽 가장자리 cm 자. 화면 맨 위가 0. [dpPerMm]은 1mm가 몇 논리 픽셀인지(자 맞추기로 고친다).
class EdgeRulerPainter extends CustomPainter {
  final double dpPerMm;
  final Color color;
  EdgeRulerPainter({required this.dpPerMm, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (dpPerMm <= 0) return;
    final tick = Paint()
      ..color = color
      ..strokeWidth = 1;
    final maxMm = (size.height / dpPerMm).floor();
    for (int mm = 0; mm <= maxMm; mm++) {
      final y = mm * dpPerMm;
      final isCm = mm % 10 == 0;
      final len = isCm ? 18.0 : (mm % 5 == 0 ? 12.0 : 7.0);
      tick.strokeWidth = isCm ? 1.6 : 1;
      canvas.drawLine(Offset(0, y), Offset(len, y), tick);
      if (isCm) {
        final tp = TextPainter(
          text: TextSpan(
            text: "${mm ~/ 10}",
            style: TextStyle(fontSize: 13, color: color),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final ty = (y - tp.height / 2).clamp(0.0, size.height - tp.height);
        tp.paint(canvas, Offset(22, ty));
      }
    }
  }

  @override
  bool shouldRepaint(EdgeRulerPainter old) =>
      old.dpPerMm != dpPerMm || old.color != color;
}

/// 둥근 흰 단추(오른쪽 아래 세 개). NixGame 앱처럼 흰 동그라미에 색 아이콘.
class RoundToolButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String tooltip;
  final Color color;
  final bool active;

  const RoundToolButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.onLongPress,
    this.color = kLevelBlue,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? color : fc.surface,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, color: active ? Colors.white : color, size: 26),
          ),
        ),
      ),
    );
  }
}
