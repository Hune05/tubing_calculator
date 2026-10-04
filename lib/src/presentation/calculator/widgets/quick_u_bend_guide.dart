// 퀵 U-Bend(180°) 그림 설명. 롤링 오프셋·퀵 킥과 같은 자동 재생 그림.
//
// 뜻: 벽(피팅 면)에서 나온 관이 시작 직관만큼 가다가 180°로 굴러(U자) 되돌아와
// 리턴 직관만큼 간다. C-C 폭은 반경의 2배로 고정, 최고점(Apex)은 벽에서
// U자 바깥 끝까지 튀어나온 거리다.
import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:tubing_calculator/src/presentation/common/guide_paint_kit.dart';

class QuickUBendGuide extends StatefulWidget {
  final double startMm;
  final double returnMm;
  final double cToCWidthMm;
  final double apexMm;

  const QuickUBendGuide({
    super.key,
    required this.startMm,
    required this.returnMm,
    required this.cToCWidthMm,
    required this.apexMm,
  });

  @override
  State<QuickUBendGuide> createState() => _QuickUBendGuideState();
}

class _QuickUBendGuideState extends State<QuickUBendGuide>
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

  @override
  Widget build(BuildContext context) => GuideFrame(
    animation: _c,
    height: 204,
    onReplay: () => _c.forward(from: 0),
    replayKey: const Key('quick_ubend_guide_replay'),
    painterBuilder: (context, anim) => CustomPaint(
      size: Size.infinite,
      painter: _QuickUBendPainter(
        t: _c.value,
        startLabel: _mm(widget.startMm),
        returnLabel: _mm(widget.returnMm),
        widthLabel: _mm(widget.cToCWidthMm),
        apexLabel: _mm(widget.apexMm),
        startValue: widget.startMm,
        returnValue: widget.returnMm,
        widthValue: widget.cToCWidthMm,
        hasValues: widget.startMm > 0,
      ),
    ),
  );
}

class _QuickUBendPainter extends CustomPainter {
  final double t;
  final String startLabel;
  final String returnLabel;
  final String widthLabel;
  final String apexLabel;
  final double startValue;
  final double returnValue;
  final double widthValue;
  final bool hasValues;

  _QuickUBendPainter({
    required this.t,
    required this.startValue,
    required this.returnValue,
    required this.widthValue,
    required this.startLabel,
    required this.returnLabel,
    required this.widthLabel,
    required this.apexLabel,
    required this.hasValues,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    paintDotGrid(canvas, size);

    // 모양은 값이 정한다: 시작 직관 대비 C-C 폭(U자 안쪽 간격)과 리턴 직관의 길이 비율.
    // 리턴 직관은 U자가 끝나는 자리에서 벽 쪽으로 돌아오는 길이다(시작보다 길면 벽까지만 그린다).
    final wallX = 22.0;
    final topY = h * 0.24;
    final legLen = w * 0.44;
    final startMm = startValue, retMm = returnValue, ccMm = widthValue;
    final double gap = (hasValues && startMm > 0 && ccMm > 0)
        ? (legLen * ccMm / startMm).clamp(26.0, 64.0)
        : (h * 0.28).clamp(28.0, 56.0);
    final double retFrac = (hasValues && startMm > 0 && retMm > 0)
        ? (retMm / startMm).clamp(0.2, 1.0)
        : 1.0;
    final botY = topY + gap;
    final arcX = wallX + legLen;
    final topEnd = Offset(arcX, topY);
    final botStart = Offset(arcX - legLen * retFrac, botY);
    final botEnd = Offset(arcX, botY);
    final apexX = arcX + gap / 2;

    // 벽(빗금 있는 면).
    final wallT = stageT(t, 0, 0.1);
    if (wallT > 0) {
      canvas.drawLine(
        Offset(wallX, topY - 18 * wallT),
        Offset(wallX, botY + 18 * wallT),
        Paint()
          ..color = AppColors.textSub
          ..strokeWidth = 4,
      );
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(wallX - 10, topY - 20, 10, (botY - topY) + 40),
      );
      final hatch = Paint()
        ..color = AppColors.textSub.withValues(alpha: 0.5)
        ..strokeWidth = 1.4;
      for (double y = topY - 24; y < botY + 24; y += 7) {
        canvas.drawLine(Offset(wallX - 10, y + 10), Offset(wallX, y), hatch);
      }
      canvas.restore();
    }

    // 시작 직관(위) · 리턴 직관(아래).
    final startT = stageT(t, 0.12, 0.4);
    paintPipeSegment(
      canvas,
      Offset(wallX, topY),
      topEnd,
      startT,
      AppColors.brand,
      width: 7,
    );
    final retT = stageT(t, 0.42, 0.68);
    paintPipeSegment(
      canvas,
      botEnd,
      botStart,
      retT,
      kGuideOrange,
      width: 7,
    );

    // U자 굽힘(반원).
    final archT = stageT(t, 0.36, 0.62);
    if (archT > 0) {
      final rect = Rect.fromCircle(
        center: Offset(arcX, (topY + botY) / 2),
        radius: gap / 2,
      );
      canvas.drawArc(
        rect.shift(const Offset(0, 1.4)),
        -1.5708,
        3.1416 * archT,
        false,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
      );
      canvas.drawArc(
        rect,
        -1.5708,
        3.1416 * archT,
        false,
        Paint()
          ..color = AppColors.brand
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // 치수선(화살표). 시작: 위 관 위쪽, 리턴: 아래 관 아래쪽, C-C: U자 오른쪽, Apex: 맨 아래.
    final sT = stageT(t, 0.40, 0.56);
    paintDimLine(canvas, Offset(wallX, topY - 14), Offset(arcX, topY - 14), sT, AppColors.brand);
    final rT = stageT(t, 0.66, 0.78);
    paintDimLine(canvas, botStart + const Offset(0, 14), botEnd + const Offset(0, 14), rT, kGuideOrange);
    final wT = stageT(t, 0.76, 0.88);
    paintDimLine(canvas, Offset(apexX + 16, topY), Offset(apexX + 16, botY), wT, kGuideRiseColor);
    final apexT = stageT(t, 0.84, 1.0);
    paintDimLine(canvas, Offset(wallX, botY + 44), Offset(apexX, botY + 44), apexT, kGuideRunColor);

    if (hasValues) {
      if (sT > 0.7) {
        paintPill(canvas, '시작 $startLabel', Offset((wallX + arcX) / 2, topY - 29), color: AppColors.brand, size: 9.5);
      }
      if (rT > 0.7) {
        paintPill(canvas, '리턴 $returnLabel', Offset((botStart.dx + botEnd.dx) / 2, botY + 29), color: kGuideOrange, size: 9.5);
      }
      if (wT > 0.7) {
        paintPillBeside(canvas, size, 'C-C $widthLabel', apexX + 16, (topY + botY) / 2, color: kGuideRiseColor);
      }
      if (apexT > 0.7) {
        paintPill(canvas, 'Apex $apexLabel', Offset((wallX + apexX) / 2, botY + 60), color: kGuideRunColor, size: 9.5);
      }
    } else if (t > 0.6) {
      paintPill(
        canvas,
        '시작 직관을 넣으면 움직입니다',
        Offset(w / 2, h - 12),
        color: AppColors.textSub,
        size: 9,
      );
    }
  }

  @override
  bool shouldRepaint(_QuickUBendPainter old) =>
      old.t != t ||
      old.startLabel != startLabel ||
      old.returnLabel != returnLabel ||
      old.widthLabel != widthLabel ||
      old.apexLabel != apexLabel ||
      old.startValue != startValue ||
      old.returnValue != returnValue ||
      old.widthValue != widthValue ||
      old.hasValues != hasValues;
}
