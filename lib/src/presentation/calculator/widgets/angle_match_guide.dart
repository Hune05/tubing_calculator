// 각도 역산(Field Matcher) 그림 설명: 이미 꺾어 놓은 관을 옆에서 본 모양. 관이 꺾여 올라간 만큼이
// Rise(파랑), 꺾인 구간을 관 따라 잰 길이가 Travel(초록), 수평으로 간 거리가 Run(보라)이고,
// 그 세 변이 만드는 직각삼각형의 아래 모서리 각도가 구하려는 각도(주황 호)다.
// 값을 넣으면 그 각도로 그림이 바뀌고, 비어 있으면 30°짜리 본보기로 그린다.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:tubing_calculator/src/presentation/common/guide_paint_kit.dart';

const Color _kRise = Color(0xFF2563EB);
const Color _kTravel = Color(0xFF16A34A);
const Color _kRun = Color(0xFF7C3AED);

class AngleMatchGuide extends StatefulWidget {
  /// 구한 각도(°). 값이 모자라면 null(본보기 30°로 그린다).
  final double? angle;
  final String riseLabel;
  final String travelLabel;
  final String runLabel;
  final String angleLabel;

  const AngleMatchGuide({
    super.key,
    required this.angle,
    required this.riseLabel,
    required this.travelLabel,
    required this.runLabel,
    required this.angleLabel,
  });

  @override
  State<AngleMatchGuide> createState() => _AngleMatchGuideState();
}

class _AngleMatchGuideState extends State<AngleMatchGuide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GuideFrame(
    animation: _c,
    height: 188,
    onReplay: () => _c.forward(from: 0),
    replayKey: const Key('angle_match_guide_replay'),
    painterBuilder: (context, anim) => CustomPaint(
      size: Size.infinite,
      painter: _AngleMatchPainter(
        t: _c.value,
        angle: widget.angle,
        riseLabel: widget.riseLabel,
        travelLabel: widget.travelLabel,
        runLabel: widget.runLabel,
        angleLabel: widget.angleLabel,
      ),
    ),
  );
}

class _AngleMatchPainter extends CustomPainter {
  final double t;
  final double? angle;
  final String riseLabel;
  final String travelLabel;
  final String runLabel;
  final String angleLabel;

  _AngleMatchPainter({
    required this.t,
    required this.angle,
    required this.riseLabel,
    required this.travelLabel,
    required this.runLabel,
    required this.angleLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    paintDotGrid(canvas, size);
    final has = angle != null;
    final th = degToRad((has ? angle! : 30.0).clamp(3.0, 87.0));
    // 단위 Travel 1로 그리고 화면에 맞춘다.
    final run = math.cos(th), rise = math.sin(th);
    const pre = 0.45, post = 0.4;
    const padL = 14.0, padR = 96.0, padT = 18.0, padB = 38.0;
    final sc = math.min((w - padL - padR) / (pre + run + post), (h - padT - padB) / rise);
    final totalW = (pre + run + post) * sc;
    final ox = padL + ((w - padL - padR) - totalW) / 2 + pre * sc;
    final oy = h - padB;
    Offset p(double x, double y) => Offset(ox + x * sc, oy - y * sc);

    final a = p(0, 0), b = p(run, rise), corner = p(run, 0);
    final preT = stageT(t, 0.0, 0.18);
    final diagT = stageT(t, 0.18, 0.45);
    final postT = stageT(t, 0.42, 0.55);
    final triT = stageT(t, 0.55, 0.68);

    // 바닥선(기준).
    canvas.drawLine(
      Offset(6, oy + 0.5),
      Offset(w - 6, oy + 0.5),
      Paint()
        ..color = AppColors.textSub.withValues(alpha: 0.25)
        ..strokeWidth = 1,
    );

    // 직각삼각형(점선): 아래쪽 Run 줄과 오른쪽 Rise 줄.
    final dash = Paint()
      ..color = AppColors.textSub.withValues(alpha: 0.55)
      ..strokeWidth = 1.2;
    void dashed(Offset from, Offset to, double s) {
      if (s <= 0) return;
      final end = Offset.lerp(from, to, s)!;
      final d = (end - from).distance;
      if (d < 1) return;
      final dir = (end - from) / d;
      var covered = 0.0;
      while (covered < d) {
        canvas.drawLine(from + dir * covered, from + dir * math.min(covered + 5, d), dash);
        covered += 9;
      }
    }

    dashed(a, corner, triT);
    dashed(corner, b, triT);

    paintPipeSegment(canvas, p(-pre, 0), a, preT, AppColors.textSub, width: 8);
    paintPipeSegment(canvas, a, b, diagT, AppColors.brand, width: 8);
    paintPipeSegment(canvas, b, p(run + post, rise), postT, AppColors.textSub, width: 8);

    // 치수선: Run(아래), Rise(오른쪽), Travel(관 따라 위쪽).
    final runT = stageT(t, 0.62, 0.74);
    final riseT = stageT(t, 0.72, 0.84);
    final travelT = stageT(t, 0.82, 0.92);
    paintDimLine(canvas, a + const Offset(0, 14), corner + const Offset(0, 14), runT, _kRun);
    paintDimLine(canvas, corner + const Offset(16, 0), b + const Offset(16, 0), riseT, _kRise);
    final dir = (b - a) / (b - a).distance;
    final n = Offset(dir.dy, -dir.dx); // 위쪽으로 띄운다
    paintDimLine(canvas, a + n * 15, b + n * 15, travelT, _kTravel);

    // 각도 호: 꺾이는 점에서 수평선과 관 사이.
    final angT = stageT(t, 0.88, 1.0);
    if (angT > 0) {
      const r = 34.0;
      final rect = Rect.fromCircle(center: a, radius: r);
      final fill = Path()
        ..moveTo(a.dx, a.dy)
        ..arcTo(rect, 0, -th * angT, false)
        ..close();
      canvas.drawPath(fill, Paint()..color = kGuideOrange.withValues(alpha: 0.2));
      canvas.drawArc(
        rect,
        0,
        -th * angT,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..color = kGuideOrange,
      );
    }

    // 꺾이는 점 표시.
    if (diagT > 0.9) {
      for (final q in [a, b]) {
        canvas.drawCircle(q, 4.2, Paint()..color = kGuideOrange);
        canvas.drawCircle(q, 1.6, Paint()..color = Colors.white);
      }
    }

    if (has) {
      if (riseT > 0.7) {
        paintPill(canvas, 'Rise $riseLabel', Offset(math.min(corner.dx + 62, w - 46), (corner.dy + b.dy) / 2), color: _kRise, size: 9.5);
      }
      if (runT > 0.7) {
        paintPill(canvas, 'Run $runLabel', Offset((a.dx + corner.dx) / 2, a.dy + 28), color: _kRun, size: 9.5);
      }
      if (travelT > 0.7) {
        final mid = Offset.lerp(a, b, 0.5)! + n * 36;
        paintPill(canvas, 'Travel $travelLabel', Offset(math.max(mid.dx - 6, 52), mid.dy), color: _kTravel, size: 9.5);
      }
      if (angT > 0.7) {
        paintPill(canvas, angleLabel, a + Offset(60, -16 - 12 * math.sin(th)), color: kGuideOrange, size: 10.5);
      }
    } else if (t > 0.6) {
      paintPill(canvas, '높이와 Travel(또는 Run)을 넣으면 각도가 나옵니다', Offset(w / 2, h - 12), color: AppColors.textSub, size: 9);
    }
  }

  @override
  bool shouldRepaint(_AngleMatchPainter old) =>
      old.t != t ||
      old.angle != angle ||
      old.riseLabel != riseLabel ||
      old.travelLabel != travelLabel ||
      old.runLabel != runLabel ||
      old.angleLabel != angleLabel;
}
