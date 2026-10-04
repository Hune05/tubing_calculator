// 롤링 오프셋(굴림 오프셋) 그림 설명. 시트를 열 때 한 번 자동으로 움직여
// 입체 상자 안에서 관이 꺾여 올라가는 모습과 Run·Rise·Roll·대각선·Travel·회전각을
// 순서대로 보여 준다. 값을 바꿔도 그림은 그대로 있고, "다시 보기"를 누르면 처음부터
// 다시 움직인다. (2026-10-04: 평면 그림을 입체 상자 그림으로 바꿨다. 상자의 세 변이
// Run(관 방향)·Rise(위)·Roll(안쪽)이고, 관은 상자 한쪽 모서리에서 반대쪽 모서리로
// 대각선을 가로지른다. 관 길이 = Travel, 끝면의 대각선 = True Offset.)
//
// 실제 순서(스낵바 "꺾기 전에 관을 X° 굴려서 잡으십시오"와 같다):
//  ① 고른 기준면에서 회전각만큼 관을 돌려 벤더에 문다.
//  ② 그 자리에서 벤딩 각도로 꺾는다(1번 마킹).
//  ③ 관을 180° 굴려 반대로 돌린 뒤 같은 각도로 꺾는다(2번 마킹).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:tubing_calculator/src/presentation/common/guide_paint_kit.dart';

/// 입력 칸을 눌렀을 때 그림에서 강조할 값(칸 ↔ 그림 연동).
enum RollingFocus { rise, roll, start, travel, bend }

class RollingOffsetGuide extends StatefulWidget {
  final double rise;
  final double roll;
  final double trueOffset;
  final double rollAngle;
  final double bendAngle;

  /// 지금 고르고 있는 입력 칸. 있으면 그림에서 그 값만 진하게, 나머지는 흐리게 보인다.
  final RollingFocus? focus;

  const RollingOffsetGuide({
    super.key,
    required this.rise,
    required this.roll,
    required this.trueOffset,
    required this.rollAngle,
    required this.bendAngle,
    this.focus,
  });

  @override
  State<RollingOffsetGuide> createState() => _RollingOffsetGuideState();
}

class _RollingOffsetGuideState extends State<RollingOffsetGuide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4600),
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
  Widget build(BuildContext context) {
    final bend = widget.bendAngle;
    final validBend = bend > 0 && bend < 180;
    final travel = validBend && widget.trueOffset > 0
        ? widget.trueOffset / math.sin(degToRad(bend))
        : 0.0;
    final run = validBend && bend != 90 && widget.trueOffset > 0
        ? widget.trueOffset / math.tan(degToRad(bend))
        : 0.0;
    return Container(
      key: const Key('rolling_guide'),
      height: guideHeightFor(context, 272),
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
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => CustomPaint(
                  size: Size.infinite,
                  painter: _RollingOffsetGuidePainter(
                    t: _c.value,
                    rise: widget.rise,
                    roll: widget.roll,
                    run: run,
                    bendAngle: validBend ? bend : 0,
                    focus: widget.focus,
                    riseLabel: _mm(widget.rise),
                    rollLabel: _mm(widget.roll),
                    runLabel: _mm(run),
                    offsetLabel: _mm(widget.trueOffset),
                    travelLabel: _mm(travel),
                    rollAngleLabel: _deg(widget.rollAngle),
                    bendLabel: _deg(bend),
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
}

const Color _kRunColor = Color(0xFF7C3AED);
const Color _kRiseColor = Color(0xFF2563EB);
const Color _kRollColor = Color(0xFFDC2626);
const Color _kTravelColor = Color(0xFF16A34A);

class _RollingOffsetGuidePainter extends CustomPainter {
  final double t;
  final double rise;
  final double roll;
  final double run;
  final double bendAngle;
  final String riseLabel;
  final String rollLabel;
  final String runLabel;
  final String offsetLabel;
  final String travelLabel;
  final String rollAngleLabel;
  final String bendLabel;
  final bool hasValues;
  final RollingFocus? focus;

  _RollingOffsetGuidePainter({
    required this.t,
    required this.rise,
    required this.roll,
    required this.run,
    required this.bendAngle,
    required this.riseLabel,
    required this.rollLabel,
    required this.runLabel,
    required this.offsetLabel,
    required this.travelLabel,
    required this.rollAngleLabel,
    required this.bendLabel,
    required this.hasValues,
    required this.focus,
  });

  // 화면 투영(기준 그림과 같은 각도): 앞쪽 왼편 위에서 본다. x(관 방향)는 오른쪽 위로,
  // y는 위로, 앞→뒤(z)는 왼쪽 위로 간다. 그래서 끝면의 Rise·Roll·대각선이 관 뒤가 아니라
  // 오른쪽 바깥으로 펼쳐져 화살표끼리 겹치지 않는다.
  static const Offset _ex = Offset(0.94, -0.24);
  static const Offset _ey = Offset(0, -1);
  static const Offset _ez = Offset(0.5, 0.32);

  static Offset _raw(double x, double y, double z) =>
      _ex * x + _ey * y + _ez * z;

  /// 화살촉 달린 치수선. [s]는 0~1(그려지는 정도).
  void _dim(
    Canvas canvas,
    Offset a,
    Offset b,
    double s,
    Color color, {
    double width = 1.8,
    bool dashed = false,
    bool emph = false,
  }) {
    if (s <= 0) return;
    final tip = Offset.lerp(a, b, s)!;
    if (emph) {
      canvas.drawLine(
        a,
        tip,
        Paint()
          ..color = color.withValues(alpha: 0.28)
          ..strokeWidth = width + 7
          ..strokeCap = StrokeCap.round,
      );
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    if (dashed) {
      final d = (tip - a).distance;
      if (d > 1) {
        final dir = (tip - a) / d;
        var covered = 0.0;
        while (covered < d) {
          canvas.drawLine(
            a + dir * covered,
            a + dir * math.min(covered + 5, d),
            paint,
          );
          covered += 8;
        }
      }
    } else {
      canvas.drawLine(a, tip, paint);
    }
    if (s > 0.96) {
      final d = (b - a);
      final len = d.distance;
      if (len < 14) return;
      final dir = d / len;
      final n = Offset(-dir.dy, dir.dx);
      void head(Offset p, Offset towards) {
        final path = Path()
          ..moveTo(p.dx, p.dy)
          ..lineTo(
            p.dx - towards.dx * 7 + n.dx * 3.2,
            p.dy - towards.dy * 7 + n.dy * 3.2,
          )
          ..lineTo(
            p.dx - towards.dx * 7 - n.dx * 3.2,
            p.dy - towards.dy * 7 - n.dy * 3.2,
          )
          ..close();
        canvas.drawPath(path, Paint()..color = color);
      }

      head(b, dir);
      head(a, -dir);
    }
  }

  void _dashedLine(
    Canvas canvas,
    Offset a,
    Offset b,
    double s,
    Paint paint, {
    double dash = 4,
    double gap = 4,
  }) {
    if (s <= 0) return;
    final tip = Offset.lerp(a, b, s)!;
    final d = (tip - a).distance;
    if (d < 1) return;
    final dir = (tip - a) / d;
    var covered = 0.0;
    while (covered < d) {
      canvas.drawLine(
        a + dir * covered,
        a + dir * math.min(covered + dash, d),
        paint,
      );
      covered += dash + gap;
    }
  }

  /// 번호가 든 주황 점(1번·2번 마킹 자리).
  void _marker(Canvas canvas, Offset p, String label, double s) {
    if (s <= 0) return;
    final r = 8.0 * s;
    canvas.drawCircle(
      p + const Offset(0, 1.5),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawCircle(p, r, Paint()..color = kGuideOrange);
    canvas.drawCircle(
      p,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white,
    );
    if (s > 0.8) {
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            fontFamily: kAppFontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  /// 3차원에서 두 방향 사이를 둥글게 잇는 호(각도 표시).
  void _arc3(
    Canvas canvas,
    Offset Function(double, double, double) map,
    List<double> center,
    List<double> u,
    List<double> v,
    double r,
    double s,
    Color color, {
    double strokeWidth = 2,
  }) {
    if (s <= 0) return;
    double dot(List<double> a, List<double> b) =>
        a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
    final phi = math.acos(dot(u, v).clamp(-1.0, 1.0));
    if (phi < 0.01) return;
    final pts = <Offset>[];
    const steps = 24;
    for (var i = 0; i <= steps * s; i++) {
      final q = i / steps;
      final a = math.sin((1 - q) * phi) / math.sin(phi);
      final b = math.sin(q * phi) / math.sin(phi);
      pts.add(
        map(
          center[0] + r * (a * u[0] + b * v[0]),
          center[1] + r * (a * u[1] + b * v[1]),
          center[2] + r * (a * u[2] + b * v[2]),
        ),
      );
    }
    if (pts.length < 2) return;
    // 호 안쪽을 옅게 채워 "이만큼 돌린다"를 보인다.
    final fill = Path()
      ..moveTo(
        map(center[0], center[1], center[2]).dx,
        map(center[0], center[1], center[2]).dy,
      );
    for (final p in pts) {
      fill.lineTo(p.dx, p.dy);
    }
    fill.close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.2));
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    paintDotGrid(canvas, size);

    // ── 장면의 크기: 값이 없으면 보기 좋은 본보기(150·200·45°)로 그린다 ──
    final riseV = hasValues ? rise : 150.0;
    final rollV = hasValues ? roll : 200.0;
    final off = math.sqrt(riseV * riseV + rollV * rollV);
    final th = bendAngle > 0 ? bendAngle : 45.0;
    final runV = hasValues && run > 0
        ? run
        : (th >= 89.5 ? 0.0 : off / math.tan(degToRad(th)));
    final m = math.max(1.0, math.max(runV, math.max(riseV, rollV)));
    double fr(double v) => math.max(v / m, 0.22);
    final dx = fr(runV), dy = fr(riseV), dz = fr(rollV);
    final pre = 0.5, post = 0.42;

    // ── 화면에 꽉 차게 맞추기 ──
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final x in [-pre, dx + post]) {
      for (final y in [0.0, dy]) {
        for (final z in [0.0, dz]) {
          final p = _raw(x, y, z);
          minX = math.min(minX, p.dx);
          maxX = math.max(maxX, p.dx);
          minY = math.min(minY, p.dy);
          maxY = math.max(maxY, p.dy);
        }
      }
    }
    // 값표가 들어갈 가장자리 여백.
    // 값표는 그림 아래 범례 줄에 모아 둔다(선 색과 같은 색 점으로 구분).
    final chips = <_Chip>[
      _Chip('Run $runLabel', _kRunColor, 0.56),
      _Chip('Rise $riseLabel', _kRiseColor, 0.65, RollingFocus.rise),
      _Chip('Roll $rollLabel', _kRollColor, 0.74, RollingFocus.roll),
      _Chip('대각선 $offsetLabel', kGuideOrange, 0.83),
      _Chip('Travel $travelLabel', _kTravelColor, 0.46, RollingFocus.travel),
      _Chip('회전각 $rollAngleLabel', kGuideOrange, 0.90),
      if (bendAngle > 0)
        _Chip('벤딩 $bendLabel', AppColors.brand, 0.90, RollingFocus.bend),
    ];
    final legend = _layoutLegend(chips, w);
    const padL = 12.0, padR = 12.0, padT = 14.0;
    final padB = legend.height + 10;
    final sc = math.min(
      (w - padL - padR) / (maxX - minX),
      (h - padT - padB) / (maxY - minY),
    );
    final ox = padL + ((w - padL - padR) - (maxX - minX) * sc) / 2 - minX * sc;
    final oy = padT + ((h - padT - padB) - (maxY - minY) * sc) / 2 - minY * sc;
    Offset map(double x, double y, double z) {
      final p = _raw(x, y, z);
      return Offset(ox + p.dx * sc, oy + p.dy * sc);
    }

    // z는 앞(0)→뒤(dz). 화면에서는 앞이 오른쪽 아래, 뒤가 왼쪽 위다.
    Offset c(double x, double y, double z) => map(x, y, dz - z);

    // ── 단계별 진행 ──
    final boxT = stageT(t, 0.0, 0.14);
    final preT = stageT(t, 0.08, 0.22);
    final diagT = stageT(t, 0.22, 0.44);
    final postT = stageT(t, 0.40, 0.52);
    final travelT = stageT(t, 0.46, 0.56);
    final runT = stageT(t, 0.56, 0.65);
    final riseT = stageT(t, 0.65, 0.74);
    final rollT = stageT(t, 0.74, 0.83);
    final offT = stageT(t, 0.83, 0.91);
    final angT = stageT(t, 0.90, 1.0);

    // 입력 칸을 고른 값은 항상 보이게 하고 진하게, 나머지는 흐리게(칸 ↔ 그림 연동).
    final fc = focus;
    bool on(RollingFocus f) => fc == f;
    Color tone(RollingFocus? f, Color c) =>
        fc == null || fc == f ? c : c.withValues(alpha: 0.28);
    double seen(RollingFocus f, double v) => fc == f ? 1.0 : v;

    // ── 상자(바닥·뒷면·왼쪽 면은 진하게, 앞쪽 면은 유리처럼 옅게) ──
    void face(List<Offset> pts, double alpha, Color color) {
      if (boxT <= 0) return;
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: alpha * boxT));
    }

    const boxColor = Color(0xFFF5D547);
    final floorC = AppColors.textSub;
    face([c(0, 0, 0), c(dx, 0, 0), c(dx, 0, dz), c(0, 0, dz)], 0.10, floorC);
    face([c(0, 0, dz), c(dx, 0, dz), c(dx, dy, dz), c(0, dy, dz)], 0.22, boxColor);
    face([c(0, 0, 0), c(0, 0, dz), c(0, dy, dz), c(0, dy, 0)], 0.14, boxColor);
    face([c(0, 0, 0), c(dx, 0, 0), c(dx, dy, 0), c(0, dy, 0)], 0.10, boxColor);
    face([c(dx, 0, 0), c(dx, 0, dz), c(dx, dy, dz), c(dx, dy, 0)], 0.16, boxColor);
    face([c(0, dy, 0), c(dx, dy, 0), c(dx, dy, dz), c(0, dy, dz)], 0.12, boxColor);

    // 가려진 모서리(점선)와 보이는 모서리(실선).
    final hiddenPaint = Paint()
      ..color = AppColors.textSub.withValues(alpha: 0.55)
      ..strokeWidth = 1.1;
    final edgePaint = Paint()
      ..color = AppColors.textSub.withValues(alpha: 0.75)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    _dashedLine(canvas, c(dx, 0, 0), c(dx, 0, dz), boxT, hiddenPaint);
    _dashedLine(canvas, c(0, 0, dz), c(dx, 0, dz), boxT, hiddenPaint);
    _dashedLine(canvas, c(dx, 0, dz), c(dx, dy, dz), boxT, hiddenPaint);

    // ── 바닥에 비친 관 그림자와 내려오는 점선(높이를 읽기 쉽게) ──
    if (diagT > 0) {
      final shadow = Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..strokeWidth = 1.4;
      _dashedLine(canvas, c(0, 0, 0), c(dx, 0, dz), diagT, shadow, dash: 3, gap: 3);
      _dashedLine(canvas, c(dx, dy, dz), c(dx, 0, dz), diagT, shadow, dash: 2, gap: 3);
      if (postT > 0) {
        _dashedLine(canvas, c(dx, 0, dz), c(dx + post, 0, dz), postT, shadow, dash: 3, gap: 3);
      }
    }

    // ── 관 ──
    const pipeW = 9.0;
    paintPipeSegment(canvas, c(-pre, 0, 0), c(0, 0, 0), preT, AppColors.textSub, width: pipeW);
    paintPipeSegment(canvas, c(0, 0, 0), c(dx, dy, dz), diagT, AppColors.brand, width: pipeW);
    paintPipeSegment(canvas, c(dx, dy, dz), c(dx + post, dy, dz), postT, AppColors.textSub, width: pipeW);

    // 관 끝 단면(열린 입구).
    if (preT > 0.3) {
      final e = c(-pre, 0, 0);
      canvas.drawOval(
        Rect.fromCenter(center: e, width: 6, height: pipeW + 1),
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
      canvas.drawOval(
        Rect.fromCenter(center: e, width: 6, height: pipeW + 1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = AppColors.textSub,
      );
    }

    // 보이는 모서리를 관 위에 얇게 한 번 더(상자 형태가 또렷하도록).
    void edge(Offset a, Offset b) {
      if (boxT <= 0) return;
      canvas.drawLine(a, Offset.lerp(a, b, boxT)!, edgePaint);
    }

    edge(c(0, 0, 0), c(dx, 0, 0));
    edge(c(0, 0, 0), c(0, 0, dz));
    edge(c(0, 0, dz), c(0, dy, dz));
    edge(c(dx, dy, 0), c(dx, dy, dz));
    edge(c(0, dy, 0), c(dx, dy, 0));
    edge(c(0, dy, 0), c(0, dy, dz));
    edge(c(0, dy, dz), c(dx, dy, dz));
    edge(c(0, 0, 0), c(0, dy, 0));
    edge(c(dx, 0, 0), c(dx, dy, 0));

    // 1번·2번 마킹 점.
    if (on(RollingFocus.start)) {
      final p = c(0, 0, 0);
      canvas.drawCircle(
        p,
        15,
        Paint()..color = kGuideOrange.withValues(alpha: 0.25),
      );
      canvas.drawCircle(
        p,
        15,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = kGuideOrange,
      );
    }
    _marker(
      canvas,
      c(0, 0, 0),
      '1',
      seen(RollingFocus.start, stageT(t, 0.20, 0.28)),
    );
    _marker(canvas, c(dx, dy, dz), '2', stageT(t, 0.40, 0.48));

    // ── 치수선(색은 범례의 점과 같다) ──
    // Travel: 관을 따라 안쪽(왼쪽 위)으로 띄운 초록 선.
    final a0 = c(0, 0, 0), b0 = c(dx, dy, dz);
    final dirAB = (b0 - a0) / (b0 - a0).distance;
    var nAB = Offset(dirAB.dy, -dirAB.dx);
    if (nAB.dy > 0) nAB = -nAB; // 항상 위쪽으로 띄운다
    final travelShift = nAB * 24;
    _dim(
      canvas,
      a0 + travelShift,
      b0 + travelShift,
      seen(RollingFocus.travel, travelT),
      tone(RollingFocus.travel, _kTravelColor),
      width: on(RollingFocus.travel) ? 3.2 : 1.8,
      emph: on(RollingFocus.travel),
    );

    // Run: 바닥 앞 모서리를 따라(보라).
    const runShift = Offset(0, 15);
    _dim(
      canvas,
      c(0, 0, 0) + runShift,
      c(dx, 0, 0) + runShift,
      runT,
      tone(null, _kRunColor),
    );

    // Rise: 앞쪽 오른 세로 모서리(파랑).
    const riseShift = Offset(13, 0);
    _dim(
      canvas,
      c(dx, 0, 0) + riseShift,
      c(dx, dy, 0) + riseShift,
      seen(RollingFocus.rise, riseT),
      tone(RollingFocus.rise, _kRiseColor),
      width: on(RollingFocus.rise) ? 3.2 : 1.8,
      emph: on(RollingFocus.rise),
    );

    // Roll: 위쪽 안으로 들어가는 모서리(빨강).
    const rollShift = Offset(5, -9);
    _dim(
      canvas,
      c(dx, dy, 0) + rollShift,
      c(dx, dy, dz) + rollShift,
      seen(RollingFocus.roll, rollT),
      tone(RollingFocus.roll, _kRollColor),
      width: on(RollingFocus.roll) ? 3.2 : 1.8,
      emph: on(RollingFocus.roll),
    );

    // 끝면의 대각선(True Offset, 주황 점선).
    _dim(
      canvas,
      c(dx, 0, 0),
      c(dx, dy, dz),
      offT,
      tone(null, kGuideOrange),
      width: 2.2,
      dashed: true,
    );

    // 각도: 끝면 아래 모서리의 회전각(주황), 1번 마킹의 벤딩 각도(청록).
    final diagLen = math.sqrt(dy * dy + dz * dz);
    final bendS = seen(RollingFocus.bend, angT);
    if (bendS > 0) {
      _arc3(
        canvas,
        c,
        [dx, 0, 0],
        [0, 1, 0],
        [0, dy / diagLen, dz / diagLen],
        math.min(0.26, diagLen * 0.5),
        angT,
        tone(null, kGuideOrange),
      );
      final full3 = math.sqrt(dx * dx + dy * dy + dz * dz);
      _arc3(
        canvas,
        c,
        [0, 0, 0],
        [1, 0, 0],
        [dx / full3, dy / full3, dz / full3],
        on(RollingFocus.bend) ? 0.3 : 0.2,
        bendS,
        tone(RollingFocus.bend, AppColors.brand),
        strokeWidth: on(RollingFocus.bend) ? 3.4 : 2,
      );
    }

    // ── 범례(값표) ──
    if (hasValues) {
      for (var i = 0; i < chips.length; i++) {
        final k = chips[i].focus != null && chips[i].focus == fc
            ? 1.0
            : stageT(t, chips[i].at - 0.04, chips[i].at + 0.06);
        if (k <= 0) continue;
        final r = legend.rects[i];
        canvas.save();
        canvas.translate(0, (1 - k) * 6);
        _paintChip(
          canvas,
          chips[i],
          legend.painters[i],
          r.shift(Offset(0, h - legend.height - 2)),
          k,
          emph: fc != null && chips[i].focus == fc,
          dim: fc != null && chips[i].focus != fc,
        );
        canvas.restore();
      }
    } else if (t > 0.6) {
      paintPill(
        canvas,
        'Rise·Roll을 넣으면 값이 나옵니다',
        Offset(w / 2, h - 14),
        color: AppColors.textSub,
        size: 9,
      );
    }
  }

  /// 범례 칩들을 폭에 맞춰 줄바꿈하며 가운데 정렬로 놓는다(보이기 전에도 자리는 고정).
  _Legend _layoutLegend(List<_Chip> chips, double w) {
    const padX = 8.0, dot = 14.0, hgap = 6.0, vgap = 6.0, hh = 20.0;
    final tps = <TextPainter>[
      for (final c in chips)
        TextPainter(
          text: TextSpan(
            text: c.label,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              fontFamily: kAppFontFamily,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    final rows = <List<int>>[[]];
    var x = 0.0;
    for (var i = 0; i < chips.length; i++) {
      final cw = tps[i].width + padX * 2 + dot - 4;
      if (rows.last.isNotEmpty && x + cw > w - 8) {
        rows.add([]);
        x = 0;
      }
      rows.last.add(i);
      x += cw + hgap;
    }
    final rects = List<Rect>.filled(chips.length, Rect.zero);
    for (var r = 0; r < rows.length; r++) {
      var total = -hgap;
      for (final i in rows[r]) {
        total += tps[i].width + padX * 2 + dot - 4 + hgap;
      }
      var cx = (w - total) / 2;
      for (final i in rows[r]) {
        final cw = tps[i].width + padX * 2 + dot - 4;
        rects[i] = Rect.fromLTWH(cx, r * (hh + vgap), cw, hh);
        cx += cw + hgap;
      }
    }
    return _Legend(rects, tps, rows.length * hh + (rows.length - 1) * vgap + 4);
  }

  void _paintChip(
    Canvas canvas,
    _Chip chip,
    TextPainter tp,
    Rect r,
    double k, {
    bool emph = false,
    bool dim = false,
  }) {
    if (dim) k *= 0.45;
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(10));
    canvas.drawRRect(
      rr,
      Paint()..color = AppColors.surface.withValues(alpha: 0.96 * k),
    );
    if (emph) {
      canvas.drawRRect(rr, Paint()..color = chip.color.withValues(alpha: 0.14));
    }
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = emph ? 2 : 1
        ..color = chip.color.withValues(alpha: (emph ? 0.95 : 0.45) * k),
    );
    canvas.drawCircle(
      Offset(r.left + 10, r.center.dy),
      4,
      Paint()..color = chip.color.withValues(alpha: k),
    );
    if (dim) {
      canvas.saveLayer(r, Paint()..color = Colors.white.withValues(alpha: 0.5));
      tp.paint(canvas, Offset(r.left + 18, r.center.dy - tp.height / 2));
      canvas.restore();
    } else {
      tp.paint(canvas, Offset(r.left + 18, r.center.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RollingOffsetGuidePainter old) =>
      old.t != t ||
      old.rise != rise ||
      old.roll != roll ||
      old.run != run ||
      old.bendAngle != bendAngle ||
      old.riseLabel != riseLabel ||
      old.rollLabel != rollLabel ||
      old.runLabel != runLabel ||
      old.offsetLabel != offsetLabel ||
      old.travelLabel != travelLabel ||
      old.rollAngleLabel != rollAngleLabel ||
      old.bendLabel != bendLabel ||
      old.hasValues != hasValues ||
      old.focus != focus;
}

class _Chip {
  final String label;
  final Color color;
  final double at;
  final RollingFocus? focus;
  const _Chip(this.label, this.color, this.at, [this.focus]);
}

class _Legend {
  final List<Rect> rects;
  final List<TextPainter> painters;
  final double height;
  const _Legend(this.rects, this.painters, this.height);
}
