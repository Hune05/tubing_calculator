// 롤링 오프셋(굴림 오프셋) 그림 설명. 시트를 열 때 한 번 자동으로 움직여
// 장애물·Rise(수직)·Roll(수평)·회전각을 순서대로 보여 준다. 값을 바꿔도 그림은
// 그대로 있고, "다시 보기"를 누르면 처음부터 다시 움직인다(2026-09-27, 09-27 저녁
// 그림 품질을 올렸다: 관을 입체감 있는 굵은 선으로, 회전각은 각도기 다이얼로).
//
// 실제 순서(스낵바 "꺾기 전에 관을 X° 굴려서 잡으십시오"와 같다):
//  ① 고른 기준면에서 회전각만큼 관을 돌려 벤더에 문다.
//  ② 그 자리에서 벤딩 각도로 꺾는다(1번 마킹).
//  ③ 관을 180° 굴려 반대로 돌린 뒤 같은 각도로 꺾는다(2번 마킹).
//  → 관이 위·옆으로 동시에 벌어져 장애물을 대각선으로 피한다.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';

class RollingOffsetGuide extends StatefulWidget {
  final double rise;
  final double roll;
  final double trueOffset;
  final double rollAngle;
  final double bendAngle;

  const RollingOffsetGuide({
    super.key,
    required this.rise,
    required this.roll,
    required this.trueOffset,
    required this.rollAngle,
    required this.bendAngle,
  });

  @override
  State<RollingOffsetGuide> createState() => _RollingOffsetGuideState();
}

class _RollingOffsetGuideState extends State<RollingOffsetGuide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  )..forward();

  void _replay() => _c.forward(from: 0);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String _mm(double v) => '${v.toStringAsFixed(0)}mm';
  String _deg(double v) => '${v.toStringAsFixed(0)}°';

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('rolling_guide'),
    height: 172,
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.background, AppColors.surface],
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                size: Size.infinite,
                painter: _RollingOffsetGuidePainter(
                  t: _c.value,
                  riseLabel: _mm(widget.rise),
                  rollLabel: _mm(widget.roll),
                  offsetLabel: _mm(widget.trueOffset),
                  rollAngleLabel: _deg(widget.rollAngle),
                  rollAngleDeg: widget.rollAngle,
                  hasValues: widget.rise > 0 || widget.roll > 0,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: IconButton(
            key: const Key('rolling_guide_replay'),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            tooltip: '다시 보기',
            icon: Icon(Icons.replay, color: AppColors.brand),
            onPressed: _replay,
          ),
        ),
      ],
    ),
  );
}

class _RollingOffsetGuidePainter extends CustomPainter {
  final double t;
  final String riseLabel;
  final String rollLabel;
  final String offsetLabel;
  final String rollAngleLabel;
  final double rollAngleDeg;
  final bool hasValues;

  _RollingOffsetGuidePainter({
    required this.t,
    required this.riseLabel,
    required this.rollLabel,
    required this.offsetLabel,
    required this.rollAngleLabel,
    required this.rollAngleDeg,
    required this.hasValues,
  });

  static double _stage(double t, double a, double b) =>
      Curves.easeOutCubic.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  void _pill(
    Canvas canvas,
    String s,
    Offset center, {
    required Color color,
    double size = 10.5,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w800,
          fontFamily: kAppFontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: tp.width + 12,
        height: tp.height + 6,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = AppColors.surface.withValues(alpha: 0.96)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.35),
    );
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _icon(
    Canvas canvas,
    IconData icon,
    Offset center,
    double size,
    Color color,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  /// 굵고 입체감 있는 "관" 한 구간. 가운데에 밝은 하이라이트 줄을 얹어 둥근 파이프처럼 보이게 한다.
  void _pipeSegment(Canvas canvas, Offset a, Offset b, double s, Color base) {
    final tip = Offset.lerp(a, b, s)!;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);
    canvas.drawLine(
      a + const Offset(0, 1.4),
      tip + const Offset(0, 1.4),
      shadow,
    );
    canvas.drawLine(
      a,
      tip,
      Paint()
        ..color = base
        ..strokeWidth = 6.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      a,
      tip,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final leftW = w * 0.54;

    // ── 배경: 아주 옅은 도면 느낌의 점 격자 ──
    final dotPaint = Paint()..color = AppColors.textSub.withValues(alpha: 0.08);
    for (double gx = 6; gx < w; gx += 14) {
      for (double gy = 6; gy < h; gy += 14) {
        canvas.drawCircle(Offset(gx, gy), 0.7, dotPaint);
      }
    }

    // ── 왼쪽: 장애물 + Rise(수직) 관 + Roll(수평) 관 + 대각선(True Offset) ──
    final baseY = h - 16;
    final p0 = Offset(16, baseY); // 시작점
    const riseLen = 64.0, rollLen = 50.0;
    final p1 = p0.translate(0, -riseLen); // Rise 다 간 자리
    final p2 = p1.translate(math.min(rollLen, leftW - 34), 0); // Roll 다 간 자리

    // 바닥선(기준면).
    canvas.drawLine(
      Offset(6, baseY),
      Offset(leftW - 8, baseY),
      Paint()
        ..color = AppColors.textSub.withValues(alpha: 0.4)
        ..strokeWidth = 1.2,
    );

    // 장애물: 관이 두르는 안쪽 모서리(Rise 오른쪽·Roll 아래쪽)에 그린다.
    // 그림자 있는 둥근 상자 + 대각 줄무늬(경고 표시).
    final obstacleT = _stage(t, 0, 0.16);
    if (obstacleT > 0) {
      const obw = 26.0, obh = 26.0;
      final cx = p1.dx + (p2.dx - p1.dx) * 0.46;
      final cy = p1.dy + (baseY - p1.dy) * 0.46;
      final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: obw,
        height: obh * obstacleT,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
      canvas.drawRRect(
        rrect.shift(const Offset(0, 1.6)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.caution.withValues(alpha: 0.85),
              AppColors.caution.withValues(alpha: 0.55),
            ],
          ).createShader(rect),
      );
      canvas.save();
      canvas.clipRRect(rrect);
      final stripe = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 3;
      for (double x = rect.left - obh; x < rect.right + obh; x += 7) {
        canvas.drawLine(
          Offset(x, rect.bottom),
          Offset(x + obh, rect.top),
          stripe,
        );
      }
      canvas.restore();
      if (obstacleT > 0.7) {
        _icon(
          canvas,
          Icons.warning_amber_rounded,
          rect.center,
          12,
          Colors.white,
        );
      }
    }

    // 위쪽 빈자리(관·장애물은 모두 그 아래에 있다)에 값표를 세로로 쌓아 겹치지 않게 한다.
    const legendX = 46.0;
    final riseT = _stage(t, 0.10, 0.36);
    if (riseT > 0) {
      _pipeSegment(canvas, p0, p1, riseT, AppColors.brand);
      if (riseT > 0.6) {
        _pill(
          canvas,
          'Rise $riseLabel',
          const Offset(legendX, 14),
          color: AppColors.brand,
        );
      }
    }
    final rollT = _stage(t, 0.40, 0.62);
    if (rollT > 0) {
      _pipeSegment(canvas, p1, p2, rollT, fieldOrange);
      if (rollT > 0.6) {
        _pill(
          canvas,
          'Roll $rollLabel',
          const Offset(legendX, 34),
          color: fieldOrange,
        );
      }
    }
    final diagT = _stage(t, 0.64, 0.90);
    if (diagT > 0) {
      final tip = Offset.lerp(p0, p2, diagT)!;
      final dash = Paint()
        ..color = AppColors.text
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      final d = (tip - p0).distance;
      if (d > 1) {
        final dir = (tip - p0) / d;
        const step = 8.0, gap = 5.0;
        var covered = 0.0;
        while (covered < d) {
          final segEnd = math.min(covered + step, d);
          canvas.drawLine(p0 + dir * covered, p0 + dir * segEnd, dash);
          covered += step + gap;
        }
      }
      if (diagT > 0.75) {
        _pill(
          canvas,
          '대각선 $offsetLabel',
          const Offset(legendX, 54),
          color: AppColors.text,
          size: 9.5,
        );
      }
    }

    // ── 오른쪽: 각도기 다이얼(관 단면 + 회전각) ──
    final cx = leftW + (w - leftW) / 2;
    final cy = h / 2 - 2;
    final r = math.min((w - leftW) / 2 - 16, h / 2 - 20).clamp(18.0, 36.0);
    final dialT = _stage(t, 0.50, 0.68);
    if (dialT > 0) {
      // 바깥 다이얼 판.
      canvas.drawCircle(
        Offset(cx, cy),
        r + 6,
        Paint()..color = AppColors.surface.withValues(alpha: 0.9 * dialT),
      );
      canvas.drawCircle(
        Offset(cx, cy),
        r + 6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.textSub.withValues(alpha: 0.5),
      );
      // 30°마다 눈금.
      for (var d = 0; d < 360; d += 30) {
        final rad = d * math.pi / 180;
        final a = Offset(cx + r * math.sin(rad), cy - r * math.cos(rad));
        final b = Offset(
          cx + (r + 4) * math.sin(rad),
          cy - (r + 4) * math.cos(rad),
        );
        canvas.drawLine(
          a,
          b,
          Paint()
            ..color = AppColors.textSub.withValues(alpha: 0.5 * dialT)
            ..strokeWidth = 1.2,
        );
      }
      canvas.drawCircle(
        Offset(cx, cy),
        r * dialT,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = AppColors.textSub,
      );
    }
    if (dialT > 0.85) {
      _icon(
        canvas,
        Icons.push_pin,
        Offset(cx, cy - r - 12),
        13,
        AppColors.textSub,
      );
    }
    final rotT = _stage(t, 0.70, 1.0);
    if (rotT > 0 && hasValues) {
      final sweepDeg = rotT * rollAngleDeg;
      final sweepRad = sweepDeg * math.pi / 180;
      // 회전한 만큼 부채꼴(반투명 주황)로 채워 "이만큼 돌린다"를 보인다.
      final path = Path()
        ..moveTo(cx, cy)
        ..lineTo(cx, cy - r)
        ..arcTo(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
          -math.pi / 2,
          sweepRad,
          false,
        )
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = fieldOrange.withValues(alpha: 0.18),
      );
      final end = Offset(
        cx + r * math.sin(sweepRad),
        cy - r * math.cos(sweepRad),
      );
      canvas.drawLine(
        Offset(cx, cy),
        end,
        Paint()
          ..color = fieldOrange
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(end, 5, Paint()..color = fieldOrange);
      canvas.drawCircle(
        end,
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Colors.white.withValues(alpha: 0.85),
      );
      canvas.drawCircle(
        Offset(cx, cy),
        3.5,
        Paint()..color = AppColors.textSub,
      );
      if (rotT > 0.8) {
        _pill(
          canvas,
          '회전각 $rollAngleLabel',
          Offset(cx, h - 8),
          color: fieldOrange,
        );
      }
    }
    if (!hasValues && t > 0.6) {
      _pill(
        canvas,
        'Rise·Roll을 넣으면 움직입니다',
        Offset(cx, cy),
        color: AppColors.textSub,
        size: 9,
      );
    }
  }

  @override
  bool shouldRepaint(_RollingOffsetGuidePainter old) =>
      old.t != t ||
      old.riseLabel != riseLabel ||
      old.rollLabel != rollLabel ||
      old.offsetLabel != offsetLabel ||
      old.rollAngleLabel != rollAngleLabel ||
      old.rollAngleDeg != rollAngleDeg ||
      old.hasValues != hasValues;
}

/// 롤(Roll)·회전각에 쓰는 주황(현장 보기 테마 없이도 쓸 수 있게 고정값).
const Color fieldOrange = Color(0xFFEA580C);
