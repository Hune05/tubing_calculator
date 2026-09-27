// 롤링 오프셋(굴림 오프셋) 그림 설명. 시트를 열 때 한 번 자동으로 움직여
// 장애물·Rise(수직)·Roll(수평)·회전각을 순서대로 보여 준다. 값을 바꿔도 그림은
// 그대로 있고, "다시 보기"를 누르면 처음부터 다시 움직인다(2026-09-27).
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
    duration: const Duration(milliseconds: 2600),
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
    height: 152,
    width: double.infinity,
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
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
  final bool hasValues;

  _RollingOffsetGuidePainter({
    required this.t,
    required this.riseLabel,
    required this.rollLabel,
    required this.offsetLabel,
    required this.rollAngleLabel,
    required this.hasValues,
  });

  static double _stage(double t, double a, double b) =>
      Curves.easeInOut.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  void _text(
    Canvas canvas,
    String s,
    Offset p, {
    Color color = AppColors.text,
    double size = 10,
    FontWeight weight = FontWeight.w700,
    TextAlign align = TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: color, fontSize: size, fontWeight: weight),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = align == TextAlign.center ? -tp.width / 2 : 0.0;
    canvas.drawRect(
      Rect.fromLTWH(p.dx + dx - 1, p.dy - 1, tp.width + 2, tp.height + 2),
      Paint()..color = AppColors.background.withValues(alpha: 0.85),
    );
    tp.paint(canvas, Offset(p.dx + dx, p.dy));
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    final d = (b - a).distance;
    if (d < 1) return;
    final dir = (b - a) / d;
    const dash = 5.0, gap = 4.0;
    var covered = 0.0;
    while (covered < d) {
      final segEnd = math.min(covered + dash, d);
      canvas.drawLine(a + dir * covered, a + dir * segEnd, paint);
      covered += dash + gap;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final leftW = w * 0.52;

    // ── 왼쪽: 장애물 + Rise(수직) + Roll(수평) + 대각선(True Offset) ──
    final baseY = h - 14;
    final p0 = Offset(14, baseY); // 시작점
    const riseLen = 58.0, rollLen = 46.0;
    final p1 = p0.translate(0, -riseLen); // Rise 다 간 자리
    final p2 = p1.translate(math.min(rollLen, leftW - 30), 0); // Roll 다 간 자리

    // 장애물(작은 상자): Rise·Roll이 감싸는 자리에 그린다.
    final obstacleT = _stage(t, 0, 0.18);
    if (obstacleT > 0) {
      final obw = 22.0, obh = riseLen * 0.5;
      final rect = Rect.fromLTWH(
        p0.dx + 6,
        p0.dy - obh - 4,
        obw,
        obh * obstacleT,
      );
      canvas.drawRect(
        rect,
        Paint()..color = AppColors.caution.withValues(alpha: 0.28),
      );
    }

    final axisPaint = Paint()
      ..color = AppColors.textSub
      ..strokeWidth = 1.4;
    final riseT = _stage(t, 0.10, 0.38);
    if (riseT > 0) {
      final tip = Offset.lerp(p0, p1, riseT)!;
      canvas.drawLine(p0, tip, axisPaint..color = AppColors.brand);
      if (riseT > 0.6) {
        _text(
          canvas,
          'Rise $riseLabel',
          tip.translate(4, -2),
          color: AppColors.brand,
        );
      }
    }
    final rollT = _stage(t, 0.42, 0.66);
    if (rollT > 0) {
      final tip = Offset.lerp(p1, p2, rollT)!;
      canvas.drawLine(p1, tip, axisPaint..color = fieldOrange);
      if (rollT > 0.6) {
        _text(
          canvas,
          'Roll $rollLabel',
          tip.translate(tip.dx > w - 40 ? -40 : 2, 4),
          color: fieldOrange,
        );
      }
    }
    final diagT = _stage(t, 0.68, 0.92);
    if (diagT > 0) {
      final tip = Offset.lerp(p0, p2, diagT)!;
      _dashedLine(
        canvas,
        p0,
        tip,
        Paint()
          ..color = AppColors.text
          ..strokeWidth = 1.6,
      );
      if (diagT > 0.7) {
        _text(
          canvas,
          '대각선 $offsetLabel',
          Offset(p0.dx, 4),
          color: AppColors.text,
          size: 9.5,
        );
      }
    }

    // ── 오른쪽: 관 단면(원) + 회전각 ──
    final cx = leftW + (w - leftW) / 2;
    final cy = h / 2 - 4;
    final r = math.min((w - leftW) / 2 - 14, h / 2 - 18).clamp(16.0, 34.0);
    final circleT = _stage(t, 0.55, 0.72);
    if (circleT > 0) {
      canvas.drawCircle(
        Offset(cx, cy),
        r * circleT,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = AppColors.textSub,
      );
    }
    if (circleT > 0.8) {
      // 기준면(위쪽, 12시)
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx, cy - r),
        Paint()
          ..color = AppColors.textSub.withValues(alpha: 0.6)
          ..strokeWidth = 1.2,
      );
      _text(
        canvas,
        '기준면',
        Offset(cx, cy - r - 12),
        color: AppColors.textSub,
        size: 9,
        align: TextAlign.center,
      );
    }
    final rotT = _stage(t, 0.74, 1.0);
    if (rotT > 0 && hasValues) {
      // 12시(위)에서 시계 방향으로 회전각만큼 돈 자리.
      final angleFromUp = rotT * _angleDegFromLabel(rollAngleLabel);
      final rad = (angleFromUp - 90) * math.pi / 180;
      final end = Offset(cx + r * math.cos(rad), cy + r * math.sin(rad));
      canvas.drawLine(
        Offset(cx, cy),
        end,
        Paint()
          ..color = fieldOrange
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(end, 3, Paint()..color = fieldOrange);
      if (rotT > 0.85) {
        _text(
          canvas,
          '회전각 $rollAngleLabel',
          Offset(math.max(2, cx - 30), h - 12),
          color: fieldOrange,
          size: 9.5,
        );
      }
    }
    if (!hasValues && t > 0.6) {
      _text(
        canvas,
        'Rise·Roll을 넣으면\n움직입니다',
        Offset(leftW + 8, cy - 10),
        color: AppColors.textSub,
        size: 9,
      );
    }
  }

  double _angleDegFromLabel(String s) =>
      double.tryParse(s.replaceAll('°', '')) ?? 0;

  @override
  bool shouldRepaint(_RollingOffsetGuidePainter old) =>
      old.t != t ||
      old.riseLabel != riseLabel ||
      old.rollLabel != rollLabel ||
      old.offsetLabel != offsetLabel ||
      old.rollAngleLabel != rollAngleLabel ||
      old.hasValues != hasValues;
}

/// 롤(Roll)·회전각에 쓰는 주황(현장 보기 테마 없이도 쓸 수 있게 고정값).
const Color fieldOrange = Color(0xFFEA580C);
