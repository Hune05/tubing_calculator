// 일반 오프셋(Offset, 평면 Z자 꺾기) 그림 설명. 롤링 오프셋의 "굴림(회전)" 없이
// 한 평면 안에서만 두 번 꺾어 높이 h만큼 옆으로 비켜 간다.
//
// 뜻: 시작 관 → 1번 꺾음(각도) → 대각(Travel) → 2번 꺾음(반대 각도) → 원래
// 방향으로 계속. 대각으로 가는 만큼 실제 필요한 수평 거리(Run)보다 관이
// 더 길게 들어가는데, 그 차이가 축소값(Shrink)이다(자재를 그만큼 당겨 잡아야 함).
import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:tubing_calculator/src/presentation/common/guide_paint_kit.dart';

class OffsetGuide extends StatefulWidget {
  final double heightMm;
  final double runMm;
  final double travelMm;
  final double shrinkMm;
  final double angleDeg;

  const OffsetGuide({
    super.key,
    required this.heightMm,
    required this.runMm,
    required this.travelMm,
    required this.shrinkMm,
    required this.angleDeg,
  });

  @override
  State<OffsetGuide> createState() => _OffsetGuideState();
}

class _OffsetGuideState extends State<OffsetGuide>
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
    replayKey: const Key('offset_guide_replay'),
    painterBuilder: (context, anim) => CustomPaint(
      size: Size.infinite,
      painter: _OffsetPainter(
        t: _c.value,
        heightLabel: _mm(widget.heightMm),
        runLabel: _mm(widget.runMm),
        travelLabel: _mm(widget.travelMm),
        shrinkLabel: _mm(widget.shrinkMm),
        angleLabel: _deg(widget.angleDeg),
        angleDeg: widget.angleDeg,
        hasValues: widget.heightMm > 0 && widget.angleDeg > 0,
      ),
    ),
  );
}

class _OffsetPainter extends CustomPainter {
  final double t;
  final String heightLabel;
  final String runLabel;
  final String travelLabel;
  final String shrinkLabel;
  final String angleLabel;
  final double angleDeg;
  final bool hasValues;

  _OffsetPainter({
    required this.t,
    required this.heightLabel,
    required this.runLabel,
    required this.travelLabel,
    required this.shrinkLabel,
    required this.angleLabel,
    required this.angleDeg,
    required this.hasValues,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    paintDotGrid(canvas, size);

    final baseY = h - 38;
    final topY = h * 0.22;
    final p0 = Offset(10, baseY);
    final bend1 = Offset(w * 0.28, baseY);
    final bend2 = Offset(w * 0.62, topY);
    final end = Offset(w - 12, topY);

    // 시작 관(수평).
    final leadT = stageT(t, 0, 0.16);
    paintPipeSegment(canvas, p0, bend1, leadT, AppColors.textSub);

    // Rise·Run 안내선.
    final guideT = stageT(t, 0.18, 0.36);
    if (guideT > 0) {
      final dash = Paint()
        ..color = AppColors.textSub.withValues(alpha: 0.45)
        ..strokeWidth = 1.2;
      void dashLine(Offset a, Offset b, double s) {
        final endP = Offset.lerp(a, b, s)!;
        final d = (endP - a).distance;
        if (d < 1) return;
        final dir = (endP - a) / d;
        const step = 6.0, gap = 4.0;
        var covered = 0.0;
        while (covered < d) {
          final segEnd = covered + step > d ? d : covered + step;
          canvas.drawLine(a + dir * covered, a + dir * segEnd, dash);
          covered += step + gap;
        }
      }

      dashLine(bend1, Offset(bend2.dx, bend1.dy), guideT); // Run(가로)
      dashLine(Offset(bend2.dx, bend1.dy), bend2, guideT); // Rise(세로)
    }

    // 대각(Travel) 관 — 실제 꺾이는 구간.
    final travelT = stageT(t, 0.38, 0.66);
    paintPipeSegment(canvas, bend1, bend2, travelT, AppColors.brand, width: 7);
    // 치수선(화살표)과 같은 색 값표: Run·Rise는 안내선이 그려진 뒤, Travel은 관이 다 그려진 뒤.
    paintTriangleDims(
      canvas,
      size,
      low: bend1,
      high: bend2,
      runLabel: hasValues ? runLabel : null,
      riseLabel: hasValues ? heightLabel : null,
      travelLabel: hasValues ? travelLabel : null,
      runT: stageT(t, 0.18, 0.32),
      riseT: stageT(t, 0.30, 0.42),
      travelT: stageT(t, 0.62, 0.74),
    );

    // 원래 방향으로 계속(끝 관).
    final tailT = stageT(t, 0.66, 0.82);
    paintPipeSegment(canvas, bend2, end, tailT, AppColors.textSub);

    // 두 꺾는 자리 각도(같은 각도, 반대 방향).
    final angT = stageT(t, 0.70, 0.88);
    if (angT > 0 && hasValues) {
      void arc(Offset center, double startAngle, double sign) {
        final path = Path()
          ..moveTo(center.dx + 26 * sign, center.dy)
          ..arcTo(
            Rect.fromCircle(center: center, radius: 26),
            startAngle,
            sign * (angleDeg / 180 * 3.14159) * angT,
            false,
          );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = kGuideOrange,
        );
      }

      arc(bend1, 0, -1);
      arc(bend2, 3.14159, -1);
      if (angT > 0.8) {
        paintPill(
          canvas,
          '∠ $angleLabel',
          bend1 + const Offset(-30, -18),
          color: kGuideOrange,
        );
      }
    }

    // 축소값(Shrink) 안내.
    final shrinkT = stageT(t, 0.86, 1.0);
    if (shrinkT > 0 && hasValues) {
      paintPill(
        canvas,
        '축소값 $shrinkLabel',
        const Offset(64, 14),
        color: kGuideOrange,
        size: 10.5,
      );
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
  bool shouldRepaint(_OffsetPainter old) =>
      old.t != t ||
      old.heightLabel != heightLabel ||
      old.runLabel != runLabel ||
      old.travelLabel != travelLabel ||
      old.shrinkLabel != shrinkLabel ||
      old.angleLabel != angleLabel ||
      old.angleDeg != angleDeg ||
      old.hasValues != hasValues;
}
