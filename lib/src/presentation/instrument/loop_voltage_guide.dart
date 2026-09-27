// 4-20mA 루프 잡는 법 그림 설명. "루프 전압" 탭을 열면 한 번 자동으로 움직여
// ① 루프가 병렬이 아니라 직렬(전류가 한 바퀴를 돈다)이라는 것과
// ② 전원 전압을 전선·HART·배리어·기타가 나눠 먹고 남는 만큼만 계기에 간다는 것을
// 순서대로 보여 준다. 값을 바꿔도 그림은 그대로 있고, "다시 보기"를 누르면 다시 움직인다
// (2026-09-27, rolling_offset_guide.dart와 같은 방식).
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
    duration: const Duration(milliseconds: 2800),
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
    height: 168,
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
      Curves.easeInOut.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  void _text(
    Canvas canvas,
    String s,
    Offset p, {
    Color color = AppColors.text,
    double size = 9.5,
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

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final leftW = w * 0.46;

    // ── 왼쪽: 루프 회로(직렬 한 바퀴) + 흐르는 전류 점 ──
    final pad = 14.0;
    final rect = Rect.fromLTWH(pad, pad, leftW - pad * 1.4, h - pad * 2 - 12);
    final pathT = _stage(t, 0, 0.16);
    final loopPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.textSub;
    if (pathT > 0) {
      // 네 변을 순서대로(위→오른쪽→아래→왼쪽) 그려 "한 바퀴"임을 보인다.
      void side(Offset a, Offset b, double from, double to) {
        final s = ((pathT - from) / (to - from)).clamp(0.0, 1.0);
        if (s <= 0) return;
        canvas.drawLine(a, Offset.lerp(a, b, s)!, loopPaint);
      }

      final tl = rect.topLeft, tr = rect.topRight;
      final br = rect.bottomRight, bl = rect.bottomLeft;
      side(tl, tr, 0.0, 0.25);
      side(tr, br, 0.25, 0.5);
      side(br, bl, 0.5, 0.75);
      side(bl, tl, 0.75, 1.0);
    }
    if (pathT > 0.9) {
      _text(
        canvas,
        '전원 ${_v(supplyV)}',
        Offset(rect.left - 6, rect.center.dy - 6),
        size: 9,
      );
      _text(
        canvas,
        '전송기',
        Offset(rect.right - 30, rect.center.dy - 6),
        size: 9,
      );
      _text(
        canvas,
        'HART·배리어',
        Offset(rect.center.dx - 24, rect.bottom + 2),
        size: 8.5,
        color: AppColors.textSub,
      );
    }
    // 전류 점: 위→오른쪽→아래→왼쪽으로 한 바퀴 흐른다(직렬 = 어디서나 같은 전류).
    final flowT = _stage(t, 0.2, 0.86);
    if (flowT > 0) {
      final perim = 2 * (rect.width + rect.height);
      final d = flowT * perim;
      Offset at;
      if (d < rect.width) {
        at = rect.topLeft + Offset(d, 0);
      } else if (d < rect.width + rect.height) {
        at = rect.topRight + Offset(0, d - rect.width);
      } else if (d < 2 * rect.width + rect.height) {
        at = rect.bottomRight - Offset(d - rect.width - rect.height, 0);
      } else {
        at = rect.bottomLeft - Offset(0, d - 2 * rect.width - rect.height);
      }
      canvas.drawCircle(at, 4.5, Paint()..color = _loopOrange);
    }

    // ── 오른쪽: 전압을 나눠 먹는 막대(위 전원 → 아래로 소모 → 남는 전압) ──
    final barLeft = leftW + 26;
    final barW = 22.0;
    final barTop = 10.0;
    final barBottom = h - 14;
    final barH = barBottom - barTop;
    if (supplyV <= 0) return;
    double yFor(double v) => barBottom - (v / supplyV).clamp(0.0, 1.2) * barH;

    // 바깥 테두리(전체 = 전원 전압)
    final outlineT = _stage(t, 0.15, 0.3);
    if (outlineT > 0) {
      canvas.drawRect(
        Rect.fromLTWH(barLeft, barTop, barW, barH * outlineT.clamp(0, 1)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
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
      canvas.drawRect(
        Rect.fromLTWH(
          barLeft,
          yFor(segTop),
          barW,
          yFor(segBottom) - yFor(segTop),
        ),
        Paint()..color = color.withValues(alpha: 0.7),
      );
      if (s > 0.8) {
        _text(
          canvas,
          '$label −${drop.toStringAsFixed(1)}V',
          Offset(barLeft + barW + 4, (yFor(segTop) + yFor(segBottom)) / 2 - 6),
          size: 8.5,
          color: AppColors.textSub,
        );
      }
    }

    // 위에서부터 순서대로 먹는다: 전선 → HART → 배리어 → 기타.
    seg(0.32, 0.44, wireV, AppColors.textSub, '전선');
    top -= wireV;
    seg(0.44, 0.56, hartV, _loopOrange, 'HART');
    top -= hartV;
    seg(0.56, 0.66, barrierV, _loopOrange, '배리어');
    top -= barrierV;
    seg(0.66, 0.76, extraV, AppColors.textSub, '기타');
    top -= extraV;

    // 남는 전압(계기 단자): 파랑/빨강으로 강조.
    final remT = _stage(t, 0.78, 1.0);
    if (remT > 0) {
      final color = ok ? AppColors.brand : AppColors.danger;
      canvas.drawRect(
        Rect.fromLTWH(
          barLeft,
          yFor(top * remT),
          barW,
          barBottom - yFor(top * remT),
        ),
        Paint()..color = color.withValues(alpha: 0.85),
      );
      if (remT > 0.7) {
        _text(
          canvas,
          '단자 ${_v(terminalV)}',
          Offset(barLeft - 6, barBottom + 2),
          size: 9,
          color: color,
        );
      }
      // 최소 동작 전압 기준선(점선 대신 짧은 눈금).
      if (minV > 0 && minV < supplyV) {
        final my = yFor(minV);
        canvas.drawLine(
          Offset(barLeft - 4, my),
          Offset(barLeft + barW + 4, my),
          Paint()
            ..color = AppColors.text
            ..strokeWidth = 1,
        );
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
