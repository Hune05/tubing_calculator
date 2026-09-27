// 퀵 킥(단일 단차) 그림 설명. 롤링 오프셋·루프 전압과 같은 자동 재생 그림 —
// 시트를 열 때 한 번 움직이고, "다시 보기"로 처음부터 다시 본다.
//
// 뜻: 관을 한 번만 꺾어서(단일 단차) 높이 h만큼 올리며(또는 내리며) run만큼
// 가로로 나아가 장애물을 넘거나 목표 지점(포트 등)에 닿는다. 빗변(Travel)이
// 실제 관 길이(공제량 반영 전), 꺾는 자리의 각도가 벤딩 각도다.
import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:tubing_calculator/src/presentation/common/guide_paint_kit.dart';

class QuickKickGuide extends StatefulWidget {
  final double heightMm;
  final double runMm;
  final double travelMm;
  final double angleDeg;

  const QuickKickGuide({
    super.key,
    required this.heightMm,
    required this.runMm,
    required this.travelMm,
    required this.angleDeg,
  });

  @override
  State<QuickKickGuide> createState() => _QuickKickGuideState();
}

class _QuickKickGuideState extends State<QuickKickGuide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String _mm(double v) => '${v.toStringAsFixed(0)}mm';
  String _deg(double v) => '${v.toStringAsFixed(0)}°';

  @override
  Widget build(BuildContext context) => GuideFrame(
    animation: _c,
    onReplay: () => _c.forward(from: 0),
    replayKey: const Key('quick_kick_guide_replay'),
    painterBuilder: (context, anim) => CustomPaint(
      size: Size.infinite,
      painter: _QuickKickPainter(
        t: _c.value,
        heightLabel: _mm(widget.heightMm),
        runLabel: _mm(widget.runMm),
        travelLabel: _mm(widget.travelMm),
        angleLabel: _deg(widget.angleDeg),
        angleDeg: widget.angleDeg,
        hasValues: widget.heightMm > 0 && widget.angleDeg > 0,
      ),
    ),
  );
}

class _QuickKickPainter extends CustomPainter {
  final double t;
  final String heightLabel;
  final String runLabel;
  final String travelLabel;
  final String angleLabel;
  final double angleDeg;
  final bool hasValues;

  _QuickKickPainter({
    required this.t,
    required this.heightLabel,
    required this.runLabel,
    required this.travelLabel,
    required this.angleLabel,
    required this.angleDeg,
    required this.hasValues,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    paintDotGrid(canvas, size);

    final baseY = h - 20;
    final p0 = Offset(14, baseY);
    final bend = Offset(w * 0.32, baseY);
    // 각도가 클수록(가파를수록) 높이 비율을 키워 보이게(그림 안에서만, 실제 값과는 별개).
    final angT = hasValues ? (angleDeg / 90).clamp(0.15, 0.9) : 0.5;
    final tip = Offset(bend.dx + (w * 0.5) * (1 - angT), 18.0);

    // 시작 수평 관.
    final leadT = stageT(t, 0, 0.18);
    paintPipeSegment(canvas, p0, bend, leadT, AppColors.textSub);

    // Rise·Run 안내선(점선) — 벤딩 관보다 먼저 살짝 보여 삼각형을 알려준다.
    final guideT = stageT(t, 0.20, 0.42);
    if (guideT > 0) {
      final dash = Paint()
        ..color = AppColors.textSub.withValues(alpha: 0.45)
        ..strokeWidth = 1.2;
      void dashLine(Offset a, Offset b, double s) {
        final end = Offset.lerp(a, b, s)!;
        final d = (end - a).distance;
        if (d < 1) return;
        final dir = (end - a) / d;
        const step = 6.0, gap = 4.0;
        var covered = 0.0;
        while (covered < d) {
          final segEnd = covered + step > d ? d : covered + step;
          canvas.drawLine(a + dir * covered, a + dir * segEnd, dash);
          covered += step + gap;
        }
      }

      dashLine(bend, Offset(tip.dx, bend.dy), guideT); // Run(가로)
      dashLine(Offset(tip.dx, bend.dy), tip, guideT); // Rise(세로)
      if (guideT > 0.7) {
        paintPill(
          canvas,
          'Run $runLabel',
          Offset((bend.dx + tip.dx) / 2, bend.dy + 12),
          color: AppColors.textSub,
          size: 9.5,
        );
        paintPill(
          canvas,
          'Rise $heightLabel',
          Offset(tip.dx + 24, (bend.dy + tip.dy) / 2),
          color: AppColors.textSub,
          size: 9.5,
        );
      }
    }

    // 대각(Travel) 관 — 실제 벤딩 구간.
    final travelT = stageT(t, 0.44, 0.74);
    paintPipeSegment(canvas, bend, tip, travelT, AppColors.brand, width: 7);
    if (travelT > 0.75) {
      paintPill(
        canvas,
        'Travel $travelLabel',
        Offset.lerp(bend, tip, 0.5)! + const Offset(0, -14),
        color: AppColors.brand,
      );
    }

    // 목표 지점 표시(포트·장애물 위).
    if (travelT > 0.9) {
      paintGuideIcon(
        canvas,
        Icons.flag_rounded,
        tip + const Offset(10, -4),
        16,
        kGuideOrange,
      );
    }

    // 꺾는 자리 각도 호.
    final angArcT = stageT(t, 0.76, 1.0);
    if (angArcT > 0 && hasValues) {
      final dir = (tip - bend);
      final fullAngle = dir.direction; // 라디안, 기준 +x축, 시계방향이 +y.
      final sweep = fullAngle * angArcT; // 0(수평)에서 실제 각도까지.
      final path = Path()
        ..moveTo(bend.dx + 28, bend.dy)
        ..arcTo(Rect.fromCircle(center: bend, radius: 28), 0, sweep, false);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = kGuideOrange,
      );
      if (angArcT > 0.8) {
        paintPill(
          canvas,
          '∠ $angleLabel',
          bend + const Offset(44, 20),
          color: kGuideOrange,
        );
      }
    }

    if (!hasValues && t > 0.6) {
      paintPill(
        canvas,
        '높이·각도를 넣으면 움직입니다',
        Offset(w / 2, h / 2),
        color: AppColors.textSub,
        size: 9,
      );
    }
  }

  @override
  bool shouldRepaint(_QuickKickPainter old) =>
      old.t != t ||
      old.heightLabel != heightLabel ||
      old.runLabel != runLabel ||
      old.travelLabel != travelLabel ||
      old.angleLabel != angleLabel ||
      old.angleDeg != angleDeg ||
      old.hasValues != hasValues;
}
