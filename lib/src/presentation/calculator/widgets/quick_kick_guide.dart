// 퀵 킥(단일 단차) 그림 설명. 롤링 오프셋·루프 전압과 같은 자동 재생 그림 —
// 시트를 열 때 한 번 움직이고, "다시 보기"로 처음부터 다시 본다.
//
// 뜻: 관을 한 번만 꺾어서(단일 단차) 높이 h만큼 올리며(또는 내리며) run만큼
// 가로로 나아가 장애물을 넘거나 목표 지점(포트 등)에 닿는다. 빗변(Travel)이
// 실제 관 길이(공제량 반영 전), 꺾는 자리의 각도가 벤딩 각도다.
import 'dart:math' as math;

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

    // 모양은 각도가 정한다: Travel을 1로 두면 Run = cos, Rise = sin. 높이·길이 값은 글자로만 쓴다.
    final th = degToRad((hasValues ? angleDeg : 30.0).clamp(5.0, 85.0));
    final run = math.cos(th), rise = math.sin(th);
    const pre = 0.7;
    const padL = 12.0, padR = 100.0, padT = 34.0, padB = 46.0;
    final unitsW = pre + run;
    final sc = math.min((w - padL - padR) / unitsW, (h - padT - padB) / rise);
    final x0 = padL + ((w - padL - padR) - unitsW * sc) / 2;
    final baseY = padT + ((h - padT - padB) - rise * sc) / 2 + rise * sc;
    final p0 = Offset(x0, baseY);
    final bend = Offset(x0 + pre * sc, baseY);
    final tip = Offset(bend.dx + run * sc, baseY - rise * sc);

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
    }

    // 대각(Travel) 관 — 실제 벤딩 구간.
    final travelT = stageT(t, 0.44, 0.74);
    paintPipeSegment(canvas, bend, tip, travelT, AppColors.brand, width: 7);

    // 치수선(화살표)과 같은 색 값표: Run·Rise는 안내선이 그려진 뒤, Travel은 관이 다 그려진 뒤.
    paintTriangleDims(
      canvas,
      size,
      low: bend,
      high: tip,
      runLabel: hasValues ? runLabel : null,
      riseLabel: hasValues ? heightLabel : null,
      travelLabel: hasValues ? travelLabel : null,
      runT: stageT(t, 0.20, 0.34),
      riseT: stageT(t, 0.32, 0.44),
      travelT: stageT(t, 0.66, 0.78),
    );

    // 목표 지점 표시(포트·장애물 위).
    if (travelT > 0.9) {
      paintGuideIcon(
        canvas,
        Icons.flag_rounded,
        tip + const Offset(0, -17),
        16,
        kGuideOrange,
      );
    }

    // 꺾는 자리 각도 호(실제로 그려진 기울기만큼 휜다).
    final angArcT = stageT(t, 0.76, 1.0);
    if (angArcT > 0 && hasValues) {
      final r = math.min(28.0, run * sc * 0.45);
      final path = Path()
        ..moveTo(bend.dx + r, bend.dy)
        ..arcTo(Rect.fromCircle(center: bend, radius: r), 0, -th * angArcT, false);
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
          bend + const Offset(-30, -18),
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
