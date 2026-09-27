// 4-20mA 루프 잡는 법 그림 설명. "루프 전압" 탭을 열면 한 번 자동으로 움직여
// ① 루프가 병렬이 아니라 직렬(전류가 한 바퀴를 돈다)이라는 것과
// ② 전원 전압을 전선·HART·배리어·기타가 나눠 먹고 남는 만큼만 계기에 간다는 것을
// 순서대로 보여 준다. 값을 바꿔도 그림은 그대로 있고, "다시 보기"를 누르면 다시 움직인다
// (2026-09-27, rolling_offset_guide.dart와 같은 방식. 09-27 저녁 그림 품질을 올렸다:
// 둥근 회로선 + 부품 기호, 그라데이션 전압 막대 + 합격/불합격 아이콘).
import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';

class LoopVoltageGuide extends StatefulWidget {
  final double supplyV;
  final double minV;
  final double wireV;
  final double hartV;
  final double barrierV;
  final double extraV;
  final double terminalV;
  final bool ok;

  const LoopVoltageGuide({
    super.key,
    required this.supplyV,
    required this.minV,
    required this.wireV,
    required this.hartV,
    required this.barrierV,
    required this.extraV,
    required this.terminalV,
    required this.ok,
  });

  @override
  State<LoopVoltageGuide> createState() => _LoopVoltageGuideState();
}

class _LoopVoltageGuideState extends State<LoopVoltageGuide>
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

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('loop_guide'),
    height: 184,
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
                painter: _LoopGuidePainter(
                  t: _c.value,
                  supplyV: widget.supplyV,
                  minV: widget.minV,
                  wireV: widget.wireV,
                  hartV: widget.hartV,
                  barrierV: widget.barrierV,
                  extraV: widget.extraV,
                  terminalV: widget.terminalV,
                  ok: widget.ok,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: IconButton(
            key: const Key('loop_guide_replay'),
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

const Color _loopOrange = Color(0xFFEA580C);

class _LoopGuidePainter extends CustomPainter {
  final double t;
  final double supplyV, minV, wireV, hartV, barrierV, extraV, terminalV;
  final bool ok;
  _LoopGuidePainter({
    required this.t,
    required this.supplyV,
    required this.minV,
    required this.wireV,
    required this.hartV,
    required this.barrierV,
    required this.extraV,
    required this.terminalV,
    required this.ok,
  });

  String _v(double v) => '${v.toStringAsFixed(1)}V';

  static double _stage(double t, double a, double b) =>
      Curves.easeOutCubic.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  void _pill(
    Canvas canvas,
    String s,
    Offset center, {
    required Color color,
    double size = 9.5,
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
        width: tp.width + 10,
        height: tp.height + 5,
      ),
      const Radius.circular(7),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = AppColors.surface.withValues(alpha: 0.96),
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

  /// 저항 기호(지그재그). 회로 위 한 자리에 HART·배리어 표시로 쓴다.
  void _zigzag(Canvas canvas, Offset center, double w, double h, Color color) {
    final path = Path()..moveTo(center.dx - w / 2, center.dy);
    const teeth = 5;
    for (var i = 0; i < teeth; i++) {
      final x = center.dx - w / 2 + w * (i + 1) / (teeth + 1);
      final y = center.dy + (i.isEven ? -h / 2 : h / 2);
      path.lineTo(x, y);
    }
    path.lineTo(center.dx + w / 2, center.dy);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final leftW = w * 0.48;

    // ── 배경: 아주 옅은 도면 느낌의 점 격자 ──
    final dotPaint = Paint()..color = AppColors.textSub.withValues(alpha: 0.08);
    for (double gx = 6; gx < w; gx += 14) {
      for (double gy = 6; gy < h; gy += 14) {
        canvas.drawCircle(Offset(gx, gy), 0.7, dotPaint);
      }
    }

    // ── 왼쪽: 루프 회로(직렬 한 바퀴, 둥근 모서리) + 흐르는 전류 점 ──
    const pad = 15.0;
    final rrOuter = RRect.fromRectAndRadius(
      Rect.fromLTWH(pad, pad, leftW - pad * 1.5, h - pad * 2 - 16),
      const Radius.circular(10),
    );
    final rect = rrOuter.outerRect;
    final pathT = _stage(t, 0, 0.18);
    if (pathT > 0) {
      canvas.drawShadow(
        Path()..addRRect(rrOuter),
        Colors.black.withValues(alpha: 0.15),
        1.5,
        false,
      );
      final metric = (Path()..addRRect(rrOuter)).computeMetrics().first;
      final drawPath = metric.extractPath(0, metric.length * pathT);
      canvas.drawPath(
        drawPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = AppColors.textSub,
      );
    }
    if (pathT > 0.9) {
      _icon(
        canvas,
        Icons.battery_charging_full,
        Offset(rect.left, rect.center.dy),
        16,
        AppColors.brand,
      );
      _pill(
        canvas,
        _v(supplyV),
        Offset(rect.left, rect.center.dy + 16),
        color: AppColors.brand,
      );
      _icon(
        canvas,
        Icons.speed,
        Offset(rect.right, rect.center.dy),
        16,
        AppColors.text,
      );
      _pill(
        canvas,
        '전송기',
        Offset(rect.right, rect.center.dy + 16),
        color: AppColors.text,
      );
      _zigzag(
        canvas,
        Offset(rect.center.dx - 14, rect.bottom),
        22,
        5,
        _loopOrange,
      );
      _zigzag(
        canvas,
        Offset(rect.center.dx + 14, rect.bottom),
        22,
        5,
        _loopOrange,
      );
      _pill(
        canvas,
        'HART · 배리어',
        Offset(rect.center.dx, rect.bottom + 12),
        color: _loopOrange,
        size: 8.5,
      );
    }
    // 전류 점: 위→오른쪽→아래→왼쪽으로 한 바퀴 흐른다(직렬 = 어디서나 같은 전류).
    final flowT = _stage(t, 0.22, 0.9);
    if (flowT > 0) {
      final metric = (Path()..addRRect(rrOuter)).computeMetrics().first;
      final tangent = metric.getTangentForOffset(metric.length * flowT);
      if (tangent != null) {
        final at = tangent.position;
        canvas.drawCircle(
          at,
          7,
          Paint()
            ..color = _loopOrange.withValues(alpha: 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
        canvas.drawCircle(at, 4.2, Paint()..color = _loopOrange);
        canvas.drawCircle(
          at,
          4.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = Colors.white.withValues(alpha: 0.9),
        );
      }
    }

    // ── 오른쪽: 전압을 나눠 먹는 막대(위 전원 → 아래로 소모 → 남는 전압) ──
    final barLeft = leftW + 30;
    const barW = 24.0;
    const barTop = 10.0;
    final barBottom = h - 40;
    final barH = barBottom - barTop;
    if (supplyV <= 0) return;
    double yFor(double v) => barBottom - (v / supplyV).clamp(0.0, 1.2) * barH;

    // 바깥 테두리(전체 = 전원 전압), 둥근 모서리.
    final outlineT = _stage(t, 0.15, 0.3);
    if (outlineT > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barLeft, barTop, barW, barH * outlineT.clamp(0, 1)),
          const Radius.circular(6),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = AppColors.textSub,
      );
    }

    double top = supplyV;
    void seg(double from, double to, double drop, Color color, String label) {
      if (drop <= 0) return;
      final s = _stage(t, from, to);
      if (s <= 0) return;
      final segTop = top;
      final segBottom = top - drop * s;
      final r = Rect.fromLTWH(
        barLeft,
        yFor(segTop),
        barW,
        yFor(segBottom) - yFor(segTop),
      );
      canvas.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.75),
              color.withValues(alpha: 0.55),
            ],
          ).createShader(r),
      );
      if (s > 0.8) {
        _pill(
          canvas,
          '$label −${drop.toStringAsFixed(1)}V',
          Offset(barLeft + barW + 38, (yFor(segTop) + yFor(segBottom)) / 2),
          color: AppColors.textSub,
          size: 8.3,
        );
      }
    }

    // 위에서부터 순서대로 먹는다: 전선 → HART → 배리어 → 기타.
    seg(0.34, 0.46, wireV, AppColors.textSub, '전선');
    top -= wireV;
    seg(0.46, 0.58, hartV, _loopOrange, 'HART');
    top -= hartV;
    seg(0.58, 0.68, barrierV, _loopOrange, '배리어');
    top -= barrierV;
    seg(0.68, 0.78, extraV, AppColors.textSub, '기타');
    top -= extraV;

    // 남는 전압(계기 단자): 파랑/빨강 그라데이션 + 합격·불합격 아이콘.
    final remT = _stage(t, 0.80, 1.0);
    if (remT > 0) {
      final color = ok ? AppColors.brand : AppColors.danger;
      final r = Rect.fromLTWH(
        barLeft,
        yFor(top * remT),
        barW,
        barBottom - yFor(top * remT),
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          r,
          bottomLeft: const Radius.circular(6),
          bottomRight: const Radius.circular(6),
        ),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.65),
              color.withValues(alpha: 0.95),
            ],
          ).createShader(r),
      );
      if (remT > 0.7) {
        _icon(
          canvas,
          ok ? Icons.check_circle : Icons.cancel,
          Offset(barLeft + barW / 2, barBottom + 12),
          14,
          color,
        );
        _pill(
          canvas,
          '단자 ${_v(terminalV)}',
          Offset(barLeft + barW / 2, barBottom + 28),
          color: color,
        );
      }
      // 최소 동작 전압 기준선.
      if (minV > 0 && minV < supplyV) {
        final my = yFor(minV);
        final dash = Paint()
          ..color = AppColors.text
          ..strokeWidth = 1.4;
        var x = barLeft - 5;
        while (x < barLeft + barW + 5) {
          canvas.drawLine(Offset(x, my), Offset(x + 3, my), dash);
          x += 5;
        }
      }
    }
  }

  @override
  bool shouldRepaint(_LoopGuidePainter old) =>
      old.t != t ||
      old.supplyV != supplyV ||
      old.minV != minV ||
      old.wireV != wireV ||
      old.hartV != hartV ||
      old.barrierV != barrierV ||
      old.extraV != extraV ||
      old.terminalV != terminalV ||
      old.ok != ok;
}
