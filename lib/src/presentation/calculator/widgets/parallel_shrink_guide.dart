// 평행(Stagger) & 축소값(Shrink) 그림 설명. 롤링 오프셋 등과 같은 자동 재생 그림.
// 한 시트 안에 서로 다른 두 계산이 있어(토글로 전환) 그림도 둘로 나눈다.
//
// 평행: 나란히 가는 관 여러 개를 한꺼번에 같은 각도로 굽힐 때, 기준(중심)
// 파이프 말고 옆 파이프는 굽는 자리를 스태거(어긋난 만큼)만큼 당기거나
// 밀어야 굽힌 뒤에도 나란해진다.
// 축소값: 관 하나가 각도만큼 꺾일 때, 꼭짓점(이론 교차점)보다 실제 마킹 자리가
// 얼마나 안쪽으로 들어오는지(줄어드는지)를 보여준다.
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
              spacingLabel: _mm(widget.spacingMm),
              staggerLabel: _mm(widget.staggerMm),
              hasValues: widget.angleDeg > 0 && widget.spacingMm > 0,
            )
          : _ShrinkPainter(
              t: _c.value,
              angleLabel: _deg(widget.angleDeg),
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
  final String spacingLabel;
  final String staggerLabel;
  final bool hasValues;

  _ParallelPainter({
    required this.t,
    required this.angleLabel,
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
    final staggerPx = 26.0;
    // 두 파이프 다 같은(짧고 완만한) 기울기로 꺾여 나간다 — 캔버스 크기와
    // 무관하게 고정 길이만큼만 올라가 위로 넘치지 않는다.
    const dx = 70.0, dy = 30.0;

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
        Offset(bendX2 - 24, botY + 16),
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
          Offset((refX + bendX2) / 2, midY - 16),
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
      old.spacingLabel != spacingLabel ||
      old.staggerLabel != staggerLabel ||
      old.hasValues != hasValues;
}

class _ShrinkPainter extends CustomPainter {
  final double t;
  final String angleLabel;
  final String riseLabel;
  final String shrinkLabel;
  final bool hasValues;

  _ShrinkPainter({
    required this.t,
    required this.angleLabel,
    required this.riseLabel,
    required this.shrinkLabel,
    required this.hasValues,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    paintDotGrid(canvas, size);

    final baseY = h - 20;
    final p0 = Offset(14, baseY);
    final bend = Offset(w * 0.42, baseY);
    final tip = Offset(w * 0.7, 20.0);
    // 이론 교차점(꺾지 않고 곧장 갔다면 만났을 자리) — 실제 굽는 자리보다 더 나가 있다.
    final theoretical = Offset(bend.dx + 26, baseY);

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
        bend + const Offset(46, 16),
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
          Offset((bend.dx + theoretical.dx) / 2, y - 16),
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
      old.riseLabel != riseLabel ||
      old.shrinkLabel != shrinkLabel ||
      old.hasValues != hasValues;
}
