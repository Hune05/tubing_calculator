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
  final bool hasValues;

  _QuickUBendPainter({
    required this.t,
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

    final wallX = 20.0;
    final topY = h * 0.32;
    final gap = (h * 0.42).clamp(28.0, 60.0);
    final botY = topY + gap;
    final legLen = w * 0.42;
    final topEnd = Offset(wallX + legLen, topY);
    final botEnd = Offset(wallX + legLen, botY);
    final apexX = wallX + legLen + gap / 2;

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
    if (startT > 0.7) {
      paintPill(
        canvas,
        '시작 $startLabel',
        Offset(wallX + legLen * 0.5, topY - 14),
        color: AppColors.brand,
      );
    }

    final retT = stageT(t, 0.42, 0.68);
    paintPipeSegment(
      canvas,
      Offset(wallX, botY),
      botEnd,
      retT,
      kGuideOrange,
      width: 7,
    );
    if (retT > 0.7) {
      paintPill(
        canvas,
        '리턴 $returnLabel',
        Offset(wallX + legLen * 0.5, botY + 14),
        color: kGuideOrange,
      );
    }

    // U자 굽힘(반원).
    final archT = stageT(t, 0.36, 0.62);
    if (archT > 0) {
      final rect = Rect.fromCircle(
        center: Offset(wallX + legLen, (topY + botY) / 2),
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

    // C-C 폭(세로 안내선).
    final wT = stageT(t, 0.66, 0.84);
    if (wT > 0) {
      final x = apexX + 20;
      final dash = Paint()
        ..color = AppColors.textSub.withValues(alpha: 0.5)
        ..strokeWidth = 1.2;
      final endY = topY + (botY - topY) * wT;
      var y = topY;
      while (y < endY) {
        final segEnd = (y + 6).clamp(topY, endY);
        canvas.drawLine(Offset(x, y), Offset(x, segEnd), dash);
        y += 10;
      }
      if (wT > 0.75) {
        paintPill(
          canvas,
          'C-C $widthLabel',
          Offset(x - 4, (topY + botY) / 2),
          color: AppColors.textSub,
          size: 9.5,
        );
      }
    }

    // 최고점(Apex, 벽~U자 바깥 끝).
    final apexT = stageT(t, 0.80, 1.0);
    if (apexT > 0 && hasValues) {
      final y = botY + 22;
      final endX = wallX + (apexX - wallX) * apexT;
      canvas.drawLine(
        Offset(wallX, y),
        Offset(endX, y),
        Paint()
          ..color = kGuideOrange
          ..strokeWidth = 2,
      );
      canvas.drawLine(
        Offset(wallX, y - 4),
        Offset(wallX, y + 4),
        Paint()
          ..color = kGuideOrange
          ..strokeWidth = 2,
      );
      if (apexT > 0.9) {
        canvas.drawLine(
          Offset(endX, y - 4),
          Offset(endX, y + 4),
          Paint()
            ..color = kGuideOrange
            ..strokeWidth = 2,
        );
        paintPill(
          canvas,
          'Apex $apexLabel',
          Offset((wallX + endX) / 2, y + 14),
          color: kGuideOrange,
        );
      }
    }

    if (!hasValues && t > 0.6) {
      paintPill(
        canvas,
        '시작 직관을 넣으면 움직입니다',
        Offset(w / 2, h / 2),
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
      old.hasValues != hasValues;
}
