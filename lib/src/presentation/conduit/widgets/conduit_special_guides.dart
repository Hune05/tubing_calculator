// 전선관 특수 벤딩 그림 설명(분할 90°·백투백 90°·스터브업). 킥은 튜브 쪽 퀵 킥 그림을 그대로 쓴다.
// 롤링 오프셋·퀵 킥과 같은 틀(GuideFrame)과 조각(guide_paint_kit.dart)을 쓰고, 시트를 열 때 한 번 움직인 뒤
// "다시 보기"로 처음부터 다시 본다.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:tubing_calculator/src/presentation/common/guide_paint_kit.dart';

/// 점선 호(원의 일부). [start]에서 [sweep]만큼(라디안).
void _dashedArc(Canvas canvas, Rect rect, double start, double sweep, Paint paint) {
  const double step = 0.12, gap = 0.08;
  double a = 0;
  final double total = sweep.abs();
  final double dir = sweep < 0 ? -1 : 1;
  while (a < total) {
    final double len = math.min(step, total - a);
    canvas.drawArc(rect, start + dir * a, dir * len, false, paint);
    a += step + gap;
  }
}

void _dashedLine(Canvas canvas, Offset a, Offset b, double s, Paint paint) {
  final end = Offset.lerp(a, b, s)!;
  final d = (end - a).distance;
  if (d < 1) return;
  final dir = (end - a) / d;
  const step = 6.0, gap = 4.0;
  var covered = 0.0;
  while (covered < d) {
    final segEnd = covered + step > d ? d : covered + step;
    canvas.drawLine(a + dir * covered, a + dir * segEnd, paint);
    covered += step + gap;
  }
}

abstract class _GuideBase extends StatefulWidget {
  const _GuideBase({super.key});
}

mixin _Replay<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  late final AnimationController c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..forward();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }
}

// ───────────────────────── 분할 90° ─────────────────────────

class SegmentedGuide extends _GuideBase {
  final double radiusMm;
  final int bends;
  final double spacingMm;
  final double angleDeg;

  const SegmentedGuide({
    super.key,
    required this.radiusMm,
    required this.bends,
    required this.spacingMm,
    required this.angleDeg,
  });

  @override
  State<SegmentedGuide> createState() => _SegmentedGuideState();
}

class _SegmentedGuideState extends State<SegmentedGuide>
    with SingleTickerProviderStateMixin, _Replay<SegmentedGuide> {
  @override
  Widget build(BuildContext context) => GuideFrame(
    animation: c,
    onReplay: () => c.forward(from: 0),
    replayKey: const Key('segmented_guide_replay'),
    painterBuilder: (context, anim) => CustomPaint(
      size: Size.infinite,
      painter: _SegmentedPainter(
        t: c.value,
        radius: widget.radiusMm,
        bends: widget.bends,
        spacing: widget.spacingMm,
        angle: widget.angleDeg,
      ),
    ),
  );
}

class _SegmentedPainter extends CustomPainter {
  final double t;
  final double radius;
  final int bends;
  final double spacing;
  final double angle;

  _SegmentedPainter({
    required this.t,
    required this.radius,
    required this.bends,
    required this.spacing,
    required this.angle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    paintDotGrid(canvas, size);
    final bool has = radius > 0 && bends >= 2;
    final int k = has ? bends : 5;
    // 그림은 반경 1로 그리고 화면에 맞춰 키운다(실제 값은 글자로).
    const double R = 1.0;
    final double th = degToRad(90.0 / k);
    final double tn = math.tan(th / 2);
    final double lead = R * (1 - tn);
    final double s = 2 * R * tn;
    const double upLeg = 1.1;
    // 높이에 맞춰 크기를 정하고, 가로 관은 화면 절반쯤 되게 길이를 잡는다(오른쪽은 값표 자리).
    final double sc = (h - 44) / (lead + upLeg + 0.25);
    final double cornerX = w * 0.52, cornerY = h - 20;
    final double leftLeg = math.max(1.4, (cornerX - 22) / sc);
    final pts = <Offset>[Offset(-leftLeg, 0), Offset(-lead, 0)];
    for (var j = 1; j < k; j++) {
      final double a = -th * j;
      pts.add(pts.last + Offset(math.cos(a), math.sin(a)) * s);
    }
    pts.add(pts.last + const Offset(0, -upLeg));
    Offset q(Offset p) => Offset(cornerX, cornerY) + p * sc;

    // 호(원): 중심 (-R, -R), 왼쪽 접점 (-R, 0) → 위쪽 접점 (0, -R)
    final arcT = stageT(t, 0.0, 0.22);
    if (arcT > 0) {
      final rect = Rect.fromCircle(center: q(const Offset(-R, -R)), radius: R * sc);
      _dashedArc(
        canvas,
        rect,
        math.pi / 2,
        -math.pi / 2 * arcT,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = AppColors.textSub.withValues(alpha: 0.55),
      );
    }

    // 직선 → 분할 구간 → 직선 순서로 관을 그린다.
    paintPipeSegment(canvas, q(pts[0]), q(pts[1]), stageT(t, 0.16, 0.34), AppColors.textSub);
    final n = pts.length - 1;
    for (var i = 1; i < n; i++) {
      final a = 0.34 + (0.46 * (i - 1) / (n - 2));
      final b = 0.34 + (0.46 * i / (n - 2));
      paintPipeSegment(canvas, q(pts[i]), q(pts[i + 1]), stageT(t, a, b), AppColors.brand, width: 7);
    }
    paintPipeSegment(canvas, q(pts[n - 1]), q(pts[n]), stageT(t, 0.8, 0.92), AppColors.textSub);

    // 꺾이는 점 표시.
    if (stageT(t, 0.84, 1.0) > 0.3) {
      for (var i = 1; i <= k; i++) {
        final p = q(pts[i]);
        canvas.drawCircle(p, 3.8, Paint()..color = kGuideOrange);
        canvas.drawCircle(p, 1.5, Paint()..color = Colors.white);
      }
    }

    // 값표는 오른쪽 빈 자리에 쌓는다.
    if (has && t > 0.85) {
      final double x = cornerX + (w - cornerX) * 0.5 + 6;
      paintPill(canvas, 'R ${radius.toStringAsFixed(0)}', q(const Offset(-R * 0.55, -R * 0.55)), color: AppColors.textSub, size: 9.5);
      paintPill(canvas, '∠ ${angle.toStringAsFixed(angle % 1 == 0 ? 0 : 1)}° × $k번', Offset(x, h * 0.28), color: kGuideOrange);
      paintPill(canvas, '간격 ${spacing.toStringAsFixed(0)}', Offset(x, h * 0.50), color: AppColors.brand, size: 9.5);
    }
    if (!has && t > 0.6) {
      paintPill(canvas, '반경·모서리 거리를 넣으면 움직입니다', Offset(cornerX + (w - cornerX) * 0.5, h * 0.4), color: AppColors.textSub, size: 9);
    }
  }

  @override
  bool shouldRepaint(_SegmentedPainter old) =>
      old.t != t || old.radius != radius || old.bends != bends || old.spacing != spacing || old.angle != angle;
}

// ───────────────────────── 백투백 90° ─────────────────────────

class BackToBackGuide extends _GuideBase {
  final double spacingMm;
  final double distanceMm;
  final double firstMm;
  final bool outside;

  const BackToBackGuide({
    super.key,
    required this.spacingMm,
    required this.distanceMm,
    required this.firstMm,
    required this.outside,
  });

  @override
  State<BackToBackGuide> createState() => _BackToBackGuideState();
}

class _BackToBackGuideState extends State<BackToBackGuide>
    with SingleTickerProviderStateMixin, _Replay<BackToBackGuide> {
  @override
  Widget build(BuildContext context) => GuideFrame(
    animation: c,
    onReplay: () => c.forward(from: 0),
    replayKey: const Key('backtoback_guide_replay'),
    painterBuilder: (context, anim) => CustomPaint(
      size: Size.infinite,
      painter: _BackToBackPainter(
        t: c.value,
        spacing: widget.spacingMm,
        distance: widget.distanceMm,
        first: widget.firstMm,
        outside: widget.outside,
      ),
    ),
  );
}

class _BackToBackPainter extends CustomPainter {
  final double t;
  final double spacing;
  final double distance;
  final double first;
  final bool outside;

  _BackToBackPainter({
    required this.t,
    required this.spacing,
    required this.distance,
    required this.first,
    required this.outside,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    paintDotGrid(canvas, size);
    final bool has = spacing > 0 && distance > 0;
    // 관 끝(왼쪽 아래) → 위로 → 오른쪽 → 아래로 내려오는 U자.
    final double left = w * 0.30, right = w * 0.70;
    final double top = 34, bottom = h - 22;
    final a = Offset(left, bottom);
    final v1 = Offset(left, top);
    final v2 = Offset(right, top);
    final e = Offset(right, bottom);
    const double pipeW = 8;

    paintPipeSegment(canvas, a, v1, stageT(t, 0.0, 0.28), AppColors.textSub, width: pipeW);
    paintPipeSegment(canvas, v1, v2, stageT(t, 0.28, 0.58), AppColors.brand, width: pipeW);
    paintPipeSegment(canvas, v2, e, stageT(t, 0.58, 0.82), AppColors.textSub, width: pipeW);

    // 꺾이는 점.
    if (t > 0.3) {
      for (final p in [v1, v2]) {
        canvas.drawCircle(p, 4, Paint()..color = kGuideOrange);
        canvas.drawCircle(p, 1.5, Paint()..color = Colors.white);
      }
    }

    // 간격(꺾이는 점 사이)과 거리(바깥~바깥 또는 안쪽~안쪽) 치수선.
    final dimT = stageT(t, 0.80, 1.0);
    if (dimT > 0) {
      final dim = Paint()
        ..color = AppColors.textSub.withValues(alpha: 0.6)
        ..strokeWidth = 1.2;
      // 간격: 두 꺾이는 점 위쪽.
      final yS = top - 14;
      _dashedLine(canvas, Offset(left, top - 4), Offset(left, yS), dimT, dim);
      _dashedLine(canvas, Offset(right, top - 4), Offset(right, yS), dimT, dim);
      canvas.drawLine(Offset(left, yS), Offset.lerp(Offset(left, yS), Offset(right, yS), dimT)!, dim);
      // 거리: 바깥이면 관 두께의 바깥 끝끼리, 안쪽이면 안쪽 끝끼리, 아래쪽에 잰다.
      final double off = pipeW / 2 + 1;
      final double xl = outside ? left - off : left + off;
      final double xr = outside ? right + off : right - off;
      final yD = bottom - 12;
      canvas.drawLine(Offset(xl, yD), Offset.lerp(Offset(xl, yD), Offset(xr, yD), dimT)!, dim);
      canvas.drawLine(Offset(xl, yD - 4), Offset(xl, yD + 4), dim);
      if (dimT > 0.9) canvas.drawLine(Offset(xr, yD - 4), Offset(xr, yD + 4), dim);
    }

    if (has && t > 0.9) {
      paintPill(canvas, '간격 ${spacing.toStringAsFixed(0)}', Offset((left + right) / 2, 12), color: AppColors.brand, size: 9.5);
      paintPill(canvas, '${outside ? '바깥~바깥' : '안쪽~안쪽'} ${distance.toStringAsFixed(0)}', Offset((left + right) / 2, bottom - 26), color: kGuideOrange, size: 9.5);
      if (first > 0) {
        paintPill(canvas, '첫 다리 ${first.toStringAsFixed(0)}', Offset(left - 44, (top + bottom) / 2), color: AppColors.textSub, size: 9.5);
      }
    }
    if (t > 0.9) {
      paintPill(canvas, '90°', v1 + const Offset(-22, 14), color: kGuideOrange, size: 9.5);
      paintPill(canvas, '90°', v2 + const Offset(22, 14), color: kGuideOrange, size: 9.5);
    }
    if (!has && t > 0.6) {
      paintPill(canvas, '두 다리 사이 거리와 관 지름을 넣으면 값이 나옵니다', Offset(w / 2, h / 2), color: AppColors.textSub, size: 9);
    }
  }

  @override
  bool shouldRepaint(_BackToBackPainter old) =>
      old.t != t || old.spacing != spacing || old.distance != distance || old.first != first || old.outside != outside;
}

// ───────────────────────── 스터브업 ─────────────────────────

class StubUpGuide extends _GuideBase {
  final double stubMm;
  final double markMm;

  const StubUpGuide({super.key, required this.stubMm, required this.markMm});

  @override
  State<StubUpGuide> createState() => _StubUpGuideState();
}

class _StubUpGuideState extends State<StubUpGuide>
    with SingleTickerProviderStateMixin, _Replay<StubUpGuide> {
  @override
  Widget build(BuildContext context) => GuideFrame(
    animation: c,
    onReplay: () => c.forward(from: 0),
    replayKey: const Key('stubup_guide_replay'),
    painterBuilder: (context, anim) => CustomPaint(
      size: Size.infinite,
      painter: _StubUpPainter(t: c.value, stub: widget.stubMm, mark: widget.markMm),
    ),
  );
}

class _StubUpPainter extends CustomPainter {
  final double t;
  final double stub;
  final double mark;

  _StubUpPainter({required this.t, required this.stub, required this.mark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    paintDotGrid(canvas, size);
    final bool has = stub > 0;
    final baseY = h - 26;
    final p0 = Offset(w * 0.18, baseY);
    final bend = Offset(w * 0.62, baseY);
    final tip = Offset(bend.dx, 22);

    // 관 끝에서 꺾이는 점까지(스터브 길이), 거기서 위로 90°.
    paintPipeSegment(canvas, p0, bend, stageT(t, 0.0, 0.32), AppColors.textSub, width: 8);
    paintPipeSegment(canvas, bend, tip, stageT(t, 0.34, 0.66), AppColors.brand, width: 8);

    // 치수선: 스터브 길이(관 끝 ~ 꺾이는 점).
    final dimT = stageT(t, 0.62, 0.84);
    if (dimT > 0) {
      final dim = Paint()
        ..color = AppColors.textSub.withValues(alpha: 0.6)
        ..strokeWidth = 1.2;
      final y = baseY + 14;
      canvas.drawLine(Offset(p0.dx, y), Offset.lerp(Offset(p0.dx, y), Offset(bend.dx, y), dimT)!, dim);
      canvas.drawLine(Offset(p0.dx, y - 4), Offset(p0.dx, y + 4), dim);
      if (dimT > 0.9) canvas.drawLine(Offset(bend.dx, y - 4), Offset(bend.dx, y + 4), dim);
    }

    // 마킹 자리(꺾이는 점보다 테이크업만큼 앞).
    final markT = stageT(t, 0.80, 0.95);
    if (markT > 0.3 && has) {
      final double frac = stub > 0 ? (mark / stub).clamp(0.0, 1.0) : 1.0;
      final mx = p0.dx + (bend.dx - p0.dx) * frac;
      canvas.drawLine(Offset(mx, baseY - 11), Offset(mx, baseY + 11), Paint()..color = kGuideOrange..strokeWidth = 2.2);
    }

    if (t > 0.9) {
      paintPill(canvas, has ? '스터브 ${stub.toStringAsFixed(0)}' : '스터브 길이', Offset((p0.dx + bend.dx) / 2, baseY + 12 + 14 > h - 6 ? h - 8 : baseY + 26), color: AppColors.textSub, size: 9.5);
      if (has) {
        paintPill(canvas, '마킹 ${mark.toStringAsFixed(0)}', Offset(p0.dx + (bend.dx - p0.dx) * (stub > 0 ? (mark / stub).clamp(0.0, 1.0) : 1.0), baseY - 22), color: kGuideOrange, size: 9.5);
      }
      paintPill(canvas, '90°', bend + const Offset(26, -16), color: kGuideOrange, size: 9.5);
    }
    if (!has && t > 0.6) {
      paintPill(canvas, '스터브 길이를 넣으면 마킹 자리가 나옵니다', Offset(w * 0.40, h * 0.40), color: AppColors.textSub, size: 9);
    }
  }

  @override
  bool shouldRepaint(_StubUpPainter old) => old.t != t || old.stub != stub || old.mark != mark;
}
