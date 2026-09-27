// 새들(Saddle) 그림 설명. 롤링 오프셋 등과 같은 자동 재생 그림.
//
// 뜻: 지나가는 관·장애물을 넘으려고 산 모양으로 두 번(3점, 뾰족한 봉우리) 또는
// 네 번(4점, 평평한 마루) 꺾어 넘었다가 원래 높이로 돌아온다. [flatWidthMm]가
// 0이면 3점(뾰족), 0보다 크면 4점(평평한 구간이 있음)으로 그린다.
import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:tubing_calculator/src/presentation/common/guide_paint_kit.dart';

class SaddleGuide extends StatefulWidget {
  final double heightMm;
  final double travelMm;
  final double shrinkMm;

  /// 다리(발) 쪽 굽는 자리 각도 — 3점이면 센터 각도의 절반, 4점이면 네 굽는
  /// 자리 모두 이 각도(같은 값)다.
  final double cornerAngleDeg;

  /// 봉우리(센터) 각도 — 3점에만 있다(4점은 봉우리 하나가 아니라 평평한
  /// 마루라 따로 없음). null이면 안 보여준다.
  final double? peakAngleDeg;
  final double flatWidthMm;

  const SaddleGuide({
    super.key,
    required this.heightMm,
    required this.travelMm,
    required this.shrinkMm,
    required this.cornerAngleDeg,
    this.peakAngleDeg,
    this.flatWidthMm = 0,
  });

  @override
  State<SaddleGuide> createState() => _SaddleGuideState();
}

class _SaddleGuideState extends State<SaddleGuide>
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
    replayKey: const Key('saddle_guide_replay'),
    painterBuilder: (context, anim) => CustomPaint(
      size: Size.infinite,
      painter: _SaddlePainter(
        t: _c.value,
        heightLabel: _mm(widget.heightMm),
        travelLabel: _mm(widget.travelMm),
        shrinkLabel: _mm(widget.shrinkMm),
        cornerAngleLabel: _deg(widget.cornerAngleDeg),
        peakAngleLabel: widget.peakAngleDeg == null
            ? null
            : _deg(widget.peakAngleDeg!),
        hasFlat: widget.flatWidthMm > 0,
        hasValues: widget.heightMm > 0 && widget.cornerAngleDeg > 0,
      ),
    ),
  );
}

class _SaddlePainter extends CustomPainter {
  final double t;
  final String heightLabel;
  final String travelLabel;
  final String shrinkLabel;
  final String cornerAngleLabel;
  final String? peakAngleLabel;
  final bool hasFlat;
  final bool hasValues;

  _SaddlePainter({
    required this.t,
    required this.heightLabel,
    required this.travelLabel,
    required this.shrinkLabel,
    required this.cornerAngleLabel,
    required this.peakAngleLabel,
    required this.hasFlat,
    required this.hasValues,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    paintDotGrid(canvas, size);

    final baseY = h - 18;
    final topY = h * 0.24;
    final flat = hasFlat ? w * 0.14 : 0.0;
    final midX = w / 2;
    final p0 = Offset(10, baseY);
    final up1 = Offset(midX - flat / 2 - w * 0.14, baseY);
    final peak1 = Offset(midX - flat / 2, topY);
    final peak2 = Offset(midX + flat / 2, topY);
    final down1 = Offset(midX + flat / 2 + w * 0.14, baseY);
    final end = Offset(w - 10, baseY);

    // 지나가는 관(장애물) — 봉우리 아래 가운데.
    final obT = stageT(t, 0, 0.14);
    if (obT > 0) {
      paintObstacle(
        canvas,
        Offset(midX, baseY - 6),
        obT,
        width: 30,
        height: 16,
      );
    }

    // 시작 관.
    final leadT = stageT(t, 0.14, 0.28);
    paintPipeSegment(canvas, p0, up1, leadT, AppColors.textSub);

    // 올라가는 관.
    final upT = stageT(t, 0.28, 0.48);
    paintPipeSegment(canvas, up1, peak1, upT, AppColors.brand, width: 7);

    // 마루(4점일 때만 평평한 구간).
    final flatT = stageT(t, 0.48, 0.58);
    if (hasFlat) {
      paintPipeSegment(canvas, peak1, peak2, flatT, AppColors.brand, width: 7);
    }

    // 내려가는 관.
    final downT = stageT(t, hasFlat ? 0.58 : 0.48, 0.74);
    paintPipeSegment(canvas, peak2, down1, downT, AppColors.brand, width: 7);
    if (downT > 0.8) {
      paintPill(
        canvas,
        'Travel $travelLabel',
        Offset.lerp(up1, peak1, 0.5)! + const Offset(-8, -12),
        color: AppColors.brand,
        size: 9.5,
      );
    }

    // 끝 관.
    final tailT = stageT(t, 0.74, 0.86);
    paintPipeSegment(canvas, down1, end, tailT, AppColors.textSub);

    // 높이 안내선.
    final hgT = stageT(t, 0.60, 0.78);
    if (hgT > 0) {
      final dash = Paint()
        ..color = AppColors.textSub.withValues(alpha: 0.45)
        ..strokeWidth = 1.2;
      final endY = baseY - (baseY - topY) * hgT;
      var y = baseY;
      while (y > endY) {
        final segEnd = (y - 6).clamp(endY, baseY);
        canvas.drawLine(
          Offset(peak2.dx + 14, y),
          Offset(peak2.dx + 14, segEnd),
          dash,
        );
        y -= 10;
      }
      if (hgT > 0.7) {
        paintPill(
          canvas,
          'H $heightLabel',
          Offset(peak2.dx + 30, (baseY + topY) / 2),
          color: AppColors.textSub,
          size: 9.5,
        );
      }
    }

    // 각도 표시(다리 굽는 자리 — 3점이면 센터의 절반, 4점이면 네 자리 모두 같은 값).
    final angT = stageT(t, 0.80, 0.92);
    if (angT > 0 && hasValues) {
      if (peakAngleLabel != null) {
        paintPill(
          canvas,
          '봉우리 ∠ $peakAngleLabel',
          Offset(peak1.dx, topY - 16),
          color: kGuideOrange,
          size: 9.5,
        );
      }
      paintPill(
        canvas,
        '∠ $cornerAngleLabel',
        up1 + const Offset(-4, -20),
        color: kGuideOrange,
        size: 9.5,
      );
    }

    // 축소값.
    final shrinkT = stageT(t, 0.88, 1.0);
    if (shrinkT > 0 && hasValues) {
      paintPill(
        canvas,
        '축소값 $shrinkLabel',
        Offset(w - 56, h - 6),
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
  bool shouldRepaint(_SaddlePainter old) =>
      old.t != t ||
      old.heightLabel != heightLabel ||
      old.travelLabel != travelLabel ||
      old.shrinkLabel != shrinkLabel ||
      old.cornerAngleLabel != cornerAngleLabel ||
      old.peakAngleLabel != peakAngleLabel ||
      old.hasFlat != hasFlat ||
      old.hasValues != hasValues;
}
