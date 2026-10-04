// 평행(Stagger) & 축소값(Shrink) 그림 설명. 롤링 오프셋 등과 같은 자동 재생 그림.
// 한 시트 안에 서로 다른 두 계산이 있어(토글로 전환) 그림도 둘로 나눈다.
//
// 평행: 나란히 가는 관 여러 개를 한꺼번에 같은 각도로 굽힐 때, 기준(중심)
// 파이프 말고 옆 파이프는 굽는 자리를 스태거(어긋난 만큼)만큼 당기거나
// 밀어야 굽힌 뒤에도 나란해진다.
// 축소값: 관 하나가 각도만큼 꺾일 때, 꼭짓점(이론 교차점)보다 실제 마킹 자리가
// 얼마나 안쪽으로 들어오는지(줄어드는지)를 보여준다.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:tubing_calculator/src/presentation/common/guide_paint_kit.dart';

enum ParallelShrinkMode { parallel, shrink }

class ParallelShrinkGuide extends StatefulWidget {
  final ParallelShrinkMode mode;
  final double angleDeg;
  // 평행 모드.
  final double spacingMm;
  final double staggerMm;
  // 축소값 모드.
  final double riseMm;
  final double shrinkMm;

  const ParallelShrinkGuide.parallel({
    super.key,
    required this.angleDeg,
    required this.spacingMm,
    required this.staggerMm,
  }) : mode = ParallelShrinkMode.parallel,
       riseMm = 0,
       shrinkMm = 0;

  const ParallelShrinkGuide.shrink({
    super.key,
    required this.angleDeg,
    required this.riseMm,
    required this.shrinkMm,
  }) : mode = ParallelShrinkMode.shrink,
       spacingMm = 0,
       staggerMm = 0;

  @override
  State<ParallelShrinkGuide> createState() => _ParallelShrinkGuideState();
}

class _ParallelShrinkGuideState extends State<ParallelShrinkGuide>
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
    replayKey: const Key('parallel_shrink_guide_replay'),
    painterBuilder: (context, anim) => CustomPaint(
      size: Size.infinite,
      painter: widget.mode == ParallelShrinkMode.parallel
          ? _ParallelPainter(
              t: _c.value,
              angleLabel: _deg(widget.angleDeg),
              angleDeg: widget.angleDeg,
              spacingLabel: _mm(widget.spacingMm),
              staggerLabel: _mm(widget.staggerMm),
              hasValues: widget.angleDeg > 0 && widget.spacingMm > 0,
            )
          : _ShrinkPainter(
              t: _c.value,
              angleLabel: _deg(widget.angleDeg),
              angleDeg: widget.angleDeg,
              riseLabel: _mm(widget.riseMm),
              shrinkLabel: _mm(widget.shrinkMm),
              hasValues: widget.angleDeg > 0 && widget.riseMm > 0,
            ),
    ),
  );
}

class _ParallelPainter extends CustomPainter {
  final double t;
  final String angleLabel;
  final double angleDeg;
  final String spacingLabel;
  final String staggerLabel;
  final bool hasValues;

  _ParallelPainter({
    required this.t,
    required this.angleLabel,
    required this.angleDeg,
    required this.spacingLabel,
    required this.staggerLabel,
    required this.hasValues,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    paintDotGrid(canvas, size);

    final topY = h * 0.34;
    final botY = h * 0.64;
    final refX = w * 0.48;
    // 모양은 각도가 정한다: 두 관이 같은 각도로 꺾여 올라가고, 옆 관이 앞당겨 꺾는 폭(스태거)은
    // 간격 × tan(각도 ÷ 2) 비율이다(시트의 계산식과 같다). 값이 없으면 30°로 그린다.
    final th = degToRad((hasValues ? angleDeg : 30.0).clamp(5.0, 70.0));
    final staggerPx = ((botY - topY) * math.tan(th / 2)).clamp(6.0, 70.0);
    final tailLen = math.min(86.0, (topY - 10) / math.sin(th));
    final dx = tailLen * math.cos(th), dy = tailLen * math.sin(th);

    // 기준(중심) 파이프 — refX에서 그대로 꺾인다.
    final leadT = stageT(t, 0, 0.2);
    paintPipeSegment(
      canvas,
      Offset(10, topY),
      Offset(refX, topY),
      leadT,
      AppColors.brand,
      width: 6,
    );
    final tailT = stageT(t, 0.22, 0.4);
    final tailEnd1 = Offset(refX + dx, topY - dy);
    paintPipeSegment(
      canvas,
      Offset(refX, topY),
      tailEnd1,
      tailT,
      AppColors.brand,
      width: 6,
    );
    if (tailT > 0.7) {
      paintPill(
        canvas,
        '기준',
        Offset(refX - 30, topY - 14),
        color: AppColors.brand,
        size: 9.5,
      );
    }

    // 옆 파이프 — refX보다 staggerPx만큼 당겨(또는 밀어) 꺾인다.
    final bendX2 = refX - staggerPx;
    final lead2T = stageT(t, 0.42, 0.6);
    paintPipeSegment(
      canvas,
      Offset(10, botY),
      Offset(bendX2, botY),
      lead2T,
      kGuideOrange,
      width: 6,
    );
    final tail2T = stageT(t, 0.62, 0.78);
    final tailEnd2 = Offset(bendX2 + dx, botY - dy);
    paintPipeSegment(
      canvas,
      Offset(bendX2, botY),
      tailEnd2,
      tail2T,
      kGuideOrange,
      width: 6,
    );
    if (tail2T > 0.7) {
      paintPill(
        canvas,
        '옆',
        Offset(math.max(bendX2 - 70, 34), botY + 16),
        color: kGuideOrange,
        size: 9.5,
      );
    }

    // 간격(spacing) 표시.
    final spT = stageT(t, 0.2, 0.4);
    if (spT > 0) {
      paintDimLine(
        canvas,
        Offset(20, topY),
        Offset(20, botY),
        spT,
        kGuideRiseColor,
      );
      if (spT > 0.7 && hasValues) {
        paintPill(
          canvas,
          '간격 $spacingLabel',
          Offset(58, (topY + botY) / 2),
          color: kGuideRiseColor,
          size: 9.5,
        );
      }
    }

    // 스태거(굽는 자리 차이) 표시.
    final stT = stageT(t, 0.8, 1.0);
    if (stT > 0 && hasValues) {
      // 기준 관의 꺾는 각도 호.
      final arcR = math.min(24.0, dx * 0.5);
      canvas.drawPath(
        Path()
          ..moveTo(refX + arcR, topY)
          ..arcTo(Rect.fromCircle(center: Offset(refX, topY), radius: arcR), 0, -th * stT, false),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = kGuideOrange,
      );
      final dash = Paint()
        ..color = kGuideOrange
        ..strokeWidth = 1.4;
      canvas.drawLine(Offset(refX, topY + 10), Offset(refX, botY - 10), dash);
      canvas.drawLine(
        Offset(bendX2, topY + 10),
        Offset(bendX2, botY - 10),
        dash,
      );
      final midY = (topY + botY) / 2;
      paintDimLine(
        canvas,
        Offset(bendX2, midY),
        Offset(refX, midY),
        stT,
        kGuideOrange,
        width: 2.2,
      );
      if (stT > 0.7) {
        paintPill(
          canvas,
          '스태거 $staggerLabel',
          Offset((refX + bendX2) / 2, botY + 22),
          color: kGuideOrange,
        );
      }
    }

    if (hasValues && t > 0.1) {
      paintPill(
        canvas,
        '∠ $angleLabel',
        Offset(w - 40, h - 12),
        color: AppColors.textSub,
        size: 9.5,
      );
    }
    if (!hasValues && t > 0.6) {
      paintPill(
        canvas,
        '간격·각도를 넣으면 움직입니다',
        Offset(w / 2, h / 2),
        color: AppColors.textSub,
        size: 9,
      );
    }
  }

  @override
  bool shouldRepaint(_ParallelPainter old) =>
      old.t != t ||
      old.angleLabel != angleLabel ||
      old.angleDeg != angleDeg ||
      old.spacingLabel != spacingLabel ||
      old.staggerLabel != staggerLabel ||
      old.hasValues != hasValues;
}

class _ShrinkPainter extends CustomPainter {
  final double t;
  final String angleLabel;
  final double angleDeg;
  final String riseLabel;
  final String shrinkLabel;
  final bool hasValues;

  _ShrinkPainter({
    required this.t,
    required this.angleLabel,
    required this.angleDeg,
    required this.riseLabel,
    required this.shrinkLabel,
    required this.hasValues,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    paintDotGrid(canvas, size);

    // 모양은 각도가 정한다: 높이(Rise)를 한 변으로 한 삼각형. 이론 교차점은 굽는 자리에서
    // 높이 × tan(각도 ÷ 2)만큼 나가 있다(= 축소값). 값이 없으면 30°로 그린다.
    final th = degToRad((hasValues ? angleDeg : 30.0).clamp(5.0, 85.0));
    final baseY = h - 26;
    final p0 = Offset(14, baseY);
    final bend = Offset(w * 0.30, baseY);
    final risePx = math.min(baseY - 24, (w - 84 - bend.dx) * math.tan(th));
    final tip = Offset(bend.dx + risePx / math.tan(th), baseY - risePx);
    // 이론 교차점(꺾지 않고 곧장 갔다면 만났을 자리) — 실제 굽는 자리보다 더 나가 있다.
    final theoretical = Offset(bend.dx + risePx * math.tan(th / 2), baseY);

    final leadT = stageT(t, 0, 0.2);
    paintPipeSegment(canvas, p0, bend, leadT, AppColors.textSub);

    // 이론 교차점까지 이어지는 점선(실제로는 안 그렇게 꺾지만, 비교용).
    final theoT = stageT(t, 0.22, 0.4);
    if (theoT > 0) {
      final dash = Paint()
        ..color = AppColors.textSub.withValues(alpha: 0.4)
        ..strokeWidth = 1.2;
      canvas.drawLine(bend, Offset.lerp(bend, theoretical, theoT)!, dash);
      canvas.drawLine(theoretical, Offset.lerp(theoretical, tip, theoT)!, dash);
    }

    final travelT = stageT(t, 0.42, 0.7);
    paintPipeSegment(canvas, bend, tip, travelT, AppColors.brand, width: 7);
    if (travelT > 0.8) {
      paintPill(
        canvas,
        '∠ $angleLabel',
        bend + const Offset(-34, -18),
        color: kGuideOrange,
        size: 9.5,
      );
    }

    // Rise 안내선(세로).
    final riseT = stageT(t, 0.5, 0.7);
    if (riseT > 0) {
      paintDimLine(
        canvas,
        Offset(tip.dx + 16, baseY),
        Offset(tip.dx + 16, tip.dy),
        riseT,
        kGuideRiseColor,
      );
      if (riseT > 0.7 && hasValues) {
        paintPillBeside(
          canvas,
          size,
          'Rise $riseLabel',
          tip.dx + 16,
          (baseY + tip.dy) / 2,
          color: kGuideRiseColor,
        );
      }
    }

    // 축소값(이론 교차점 ↔ 실제 굽는 자리 차이) — 관 위쪽에 살짝 띄운 눈금줄로.
    final shrinkT = stageT(t, 0.74, 0.94);
    if (shrinkT > 0 && hasValues) {
      final y = baseY - 14;
      paintDimLine(
        canvas,
        Offset(bend.dx, y),
        Offset(theoretical.dx, y),
        shrinkT,
        kGuideOrange,
        width: 2.4,
      );
      canvas.drawLine(
        Offset(bend.dx, y - 4),
        Offset(bend.dx, y + 4),
        Paint()
          ..color = kGuideOrange
          ..strokeWidth = 2,
      );
      if (shrinkT > 0.9) {
        canvas.drawLine(
          Offset(theoretical.dx, y - 4),
          Offset(theoretical.dx, y + 4),
          Paint()
            ..color = kGuideOrange
            ..strokeWidth = 2,
        );
      }
      if (shrinkT > 0.8) {
        paintPill(
          canvas,
          '축소값 $shrinkLabel',
          Offset((bend.dx + theoretical.dx) / 2, baseY + 16),
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
  bool shouldRepaint(_ShrinkPainter old) =>
      old.t != t ||
      old.angleLabel != angleLabel ||
      old.angleDeg != angleDeg ||
      old.riseLabel != riseLabel ||
      old.shrinkLabel != shrinkLabel ||
      old.hasValues != hasValues;
}
