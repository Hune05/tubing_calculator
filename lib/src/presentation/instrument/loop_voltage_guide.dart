// 루프 전압 강하 그림(10-01 새로 그림). 위: 실제 루프(분배기 → HART 저항 → 배리어 → 케이블 → 지시계 → 전송기)와
// 그 위를 도는 전류 점. 아래: 같은 자리를 따라 전압이 계단처럼 깎여 내려가는 그래프와, 그 위를 움직이는 측정점(그 자리 전압 표시).
// 끝에서 전송기 단자 전압을 최소 동작 전압과 견줘 충분/부족을 보여 준다. "루프 전압" 탭을 열면 한 번 움직이고 멈춘다(다시 보기).
// 부품 그림은 "멀티미터로 4-20 mA 재기"와 같은 loop_paint_kit.dart를 쓴다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'loop_paint_kit.dart';

class LoopVoltageGuide extends StatefulWidget {
  final double supplyV;
  final double minV;
  final double wireV;
  final double hartV;
  final double barrierV;
  final double extraV;
  final double terminalV;
  final bool ok;

  /// 그래프 제목에 쓰는 확인 전류(mA). 없으면 생략.
  final double? checkMa;

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
    this.checkMa,
  });

  @override
  State<LoopVoltageGuide> createState() => _LoopVoltageGuideState();
}

class _LoopVoltageGuideState extends State<LoopVoltageGuide> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..forward();

  void _replay() => _c.forward(from: 0);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Container(
        key: const Key('loop_guide'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF7F9FA), Color(0xFFE9EDF0)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: AspectRatio(
                aspectRatio: 360 / 300,
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => CustomPaint(
                    painter: _LoopDropPainter(
                      t: _c.value,
                      supplyV: widget.supplyV,
                      minV: widget.minV,
                      wireV: widget.wireV,
                      hartV: widget.hartV,
                      barrierV: widget.barrierV,
                      extraV: widget.extraV,
                      terminalV: widget.terminalV,
                      ok: widget.ok,
                      checkMa: widget.checkMa,
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
                icon: const Icon(Icons.replay, color: AppColors.brand),
                onPressed: _replay,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

enum _Kind { hart, barrier, cable, meter }

class _Item {
  final _Kind kind;
  final String label;
  final double drop;
  double x0 = 0, x1 = 0;
  _Item(this.kind, this.label, this.drop);
  double get cx => (x0 + x1) / 2;
}

const _red = Color(0xFFD62828);
const _black = Color(0xFF26292D);
const _orange = Color(0xFFEA580C);

class _LoopDropPainter extends CustomPainter {
  final double t;
  final double supplyV, minV, wireV, hartV, barrierV, extraV, terminalV;
  final bool ok;
  final double? checkMa;
  const _LoopDropPainter({
    required this.t,
    required this.supplyV,
    required this.minV,
    required this.wireV,
    required this.hartV,
    required this.barrierV,
    required this.extraV,
    required this.terminalV,
    required this.ok,
    required this.checkMa,
  });

  static double _stage(double t, double a, double b) => Curves.easeInOutCubic.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  String _v(double v) => '${v.toStringAsFixed(1)} V';

  // 루프에 놓인 순서(분배기 쪽부터): HART 저항(DCS 카드) → 배리어 → 케이블 → 지시계. 강하가 없는 것은 그리지 않는다(케이블은 늘).
  List<_Item> _items() {
    final list = <_Item>[
      if (hartV > 0) _Item(_Kind.hart, 'HART', hartV),
      if (barrierV > 0) _Item(_Kind.barrier, '배리어', barrierV),
      _Item(_Kind.cable, '전선', math.max(0, wireV)),
      if (extraV > 0) _Item(_Kind.meter, '지시계', extraV),
    ];
    const left = 102.0, right = 278.0;
    final w = (right - left) / list.length;
    for (var i = 0; i < list.length; i++) {
      list[i].x0 = left + w * i + 4;
      list[i].x1 = left + w * (i + 1) - 4;
    }
    return list;
  }

  // ── 부품 그림 ──
  void _resistor(Canvas c, double cx, double y) {
    final body = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, y), width: 34, height: 13), const Radius.circular(6.5));
    lpShadow(c, body, blur: 2, off: const Offset(0, 2), a: .25);
    c.drawRRect(body, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF3E3C3), Color(0xFFD9BF8C), Color(0xFFB89A62)]).createShader(body.outerRect));
    // 250 Ω 색 띠: 빨강 초록 갈색 금
    const bands = [Color(0xFFC62828), Color(0xFF2E7D32), Color(0xFF6D4C41), Color(0xFFC9A227)];
    for (var i = 0; i < 4; i++) {
      final x = cx - 10 + i * 6 + (i == 3 ? 3 : 0);
      c.drawRect(Rect.fromLTWH(x, y - 6.5, 2.6, 13), Paint()..color = bands[i]);
    }
  }

  void _barrier(Canvas c, double cx, double y) {
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, y + 4), width: 30, height: 44), const Radius.circular(4));
    lpShadow(c, r, blur: 3, off: const Offset(1, 3), a: .28);
    c.drawRRect(r, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3A8F7E), Color(0xFF1F5E52)]).createShader(r.outerRect));
    c.drawRect(Rect.fromLTWH(cx - 15, y + 22, 30, 4), Paint()..color = const Color(0xFF9AA3AB)); // DIN 레일
    lpScrew(c, Offset(cx - 7, y - 11), r: 3.4);
    lpScrew(c, Offset(cx + 7, y - 11), r: 3.4);
    c.drawCircle(Offset(cx, y + 6), 2.2, Paint()..color = const Color(0xFF7CFC9A));
    lpText(c, 'Ex', Offset(cx, y + 14), size: 7, color: Colors.white);
  }

  void _cable(Canvas c, double x0, double x1, double y) {
    final r = RRect.fromRectAndRadius(Rect.fromLTRB(x0, y - 7, x1, y + 7), const Radius.circular(7));
    lpShadow(c, r, blur: 2, off: const Offset(0, 2), a: .2);
    c.drawRRect(r, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8C949C), Color(0xFF4F565D), Color(0xFF3A3F45)]).createShader(r.outerRect));
    c.drawLine(Offset(x0 + 6, y - 3.5), Offset(x1 - 6, y - 3.5), Paint()
      ..color = Colors.white.withValues(alpha: .25)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round);
  }

  void _panelMeter(Canvas c, double cx, double y) {
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, y), width: 34, height: 26), const Radius.circular(5));
    lpShadow(c, r, blur: 3, off: const Offset(1, 3), a: .28);
    c.drawRRect(r, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF4A5057), Color(0xFF24282D)]).createShader(r.outerRect));
    final lcd = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, y - 1), width: 26, height: 13), const Radius.circular(2));
    c.drawRRect(lcd, Paint()..color = const Color(0xFFC9D4C2));
    lpText(c, '50.0', Offset(cx, y - 1), size: 7.5, color: const Color(0xFF1B201A), w: FontWeight.w900);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (supplyV <= 0) return;
    final c = canvas;
    c.save();
    c.scale(size.width / 360, size.height / 300);
    final items = _items();

    // ── 위: 실제 루프 ──
    const sPlus = Offset(84, 62);
    const sMinus = Offset(84, 112);
    lpSupplyBox(c, const Rect.fromLTWH(6, 26, 88, 110), plus: sPlus, minus: sMinus, volt: '${supplyV.toStringAsFixed(supplyV % 1 == 0 ? 0 : 1)} V DC');
    c.save();
    c.translate(316, 28);
    c.scale(.72);
    final (tp, tm) = lpTransmitter(c, Offset.zero);
    c.restore();
    final tPlus = const Offset(316, 28) + tp * .72;
    final tMinus = const Offset(316, 28) + tm * .72;

    const wy = 62.0; // + 선 높이
    final plusWire = Path()
      ..moveTo(sPlus.dx, sPlus.dy)
      ..lineTo(278, wy)
      ..quadraticBezierTo(296, wy, tPlus.dx, tPlus.dy - 12)
      ..lineTo(tPlus.dx, tPlus.dy);
    final minusWire = Path()
      ..moveTo(sMinus.dx, sMinus.dy)
      ..lineTo(340, sMinus.dy)
      ..quadraticBezierTo(352, sMinus.dy, 352, sMinus.dy - 12)
      ..lineTo(352, tMinus.dy + 8)
      ..quadraticBezierTo(352, tMinus.dy, 342, tMinus.dy)
      ..lineTo(tMinus.dx, tMinus.dy);
    lpWire(c, minusWire, _black, w: 4);
    lpWire(c, plusWire, _red, w: 4);
    for (final it in items) {
      switch (it.kind) {
        case _Kind.hart:
          _resistor(c, it.cx, wy);
        case _Kind.barrier:
          _barrier(c, it.cx, wy);
        case _Kind.cable:
          _cable(c, it.x0, it.x1, wy);
        case _Kind.meter:
          _panelMeter(c, it.cx, wy);
      }
      // 칸이 좁으면(부품 셋 이상) 이름을 짧게.
      final wide = items.length <= 2;
      final name = switch (it.kind) {
        _Kind.cable => wide ? '전선 (왕복)' : '전선',
        _Kind.hart => wide ? 'HART 저항' : 'HART',
        _ => it.label,
      };
      lpText(c, name, Offset(it.cx, it.kind == _Kind.barrier ? 98 : 84), size: 8.5, color: AppColors.textSub, w: FontWeight.w800);
    }

    // 전류 점(+ 선 → 전송기 → − 선 → 분배기)
    final flow = Path()
      ..addPath(plusWire, Offset.zero)
      ..moveTo(tMinus.dx, tMinus.dy)
      ..lineTo(342, tMinus.dy)
      ..quadraticBezierTo(352, tMinus.dy, 352, tMinus.dy + 8)
      ..lineTo(352, sMinus.dy - 12)
      ..quadraticBezierTo(352, sMinus.dy, 340, sMinus.dy)
      ..lineTo(sMinus.dx, sMinus.dy);
    const gap = 15.0;
    final glow = Paint()
      ..color = const Color(0xFFFFB020).withValues(alpha: .5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final dot = Paint()..color = const Color(0xFFFFD166);
    final phase = (t * 6 * gap) % gap;
    for (final m in flow.computeMetrics()) {
      for (var d = phase; d < m.length; d += gap) {
        final tan = m.getTangentForOffset(d);
        if (tan == null) continue;
        c.drawCircle(tan.position, 3.4, glow);
        c.drawCircle(tan.position, 1.9, dot);
      }
    }
    if (checkMa != null) {
      lpText(c, '루프 전류 ${checkMa!.toStringAsFixed(checkMa! % 1 == 0 ? 0 : 2)} mA (어디서나 같음)', const Offset(200, 128), size: 8.5, color: const Color(0xFFB45309), w: FontWeight.w900);
    }

    // ── 아래: 전압 계단 그래프 ──
    const gTop = 174.0, gBot = 272.0, gLeft = 84.0, gRight = 316.0;
    double y(double v) => gBot - (v / supplyV).clamp(-0.05, 1.0) * (gBot - gTop);
    // 판
    final panel = RRect.fromRectAndRadius(const Rect.fromLTRB(8, 146, 352, 296), const Radius.circular(12));
    c.drawRRect(panel, Paint()..color = Colors.white.withValues(alpha: .85));
    c.drawRRect(panel, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.line);
    // 눈금: 전원, 0 V
    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    c.drawLine(Offset(gLeft, y(supplyV)), Offset(gRight, y(supplyV)), grid);
    c.drawLine(Offset(gLeft, y(0)), Offset(gRight, y(0)), grid);
    lpText(c, _v(supplyV), Offset(46, y(supplyV)), size: 8.5, color: AppColors.brand, w: FontWeight.w900);
    lpText(c, '0 V', Offset(46, y(0)), size: 8.5, color: AppColors.textSub);
    // 최소 동작 전압(점선) + 그 아래 붉은 영역
    if (minV > 0 && minV < supplyV) {
      final my = y(minV);
      c.drawRect(Rect.fromLTRB(gLeft, my, gRight, gBot), Paint()..color = AppColors.danger.withValues(alpha: .06));
      final dash = Paint()
        ..color = AppColors.danger.withValues(alpha: .8)
        ..strokeWidth = 1.3;
      for (var x = gLeft; x < gRight; x += 7) {
        c.drawLine(Offset(x, my), Offset(math.min(x + 4, gRight), my), dash);
      }
      lpText(c, '최소 ${_v(minV)}', Offset(46, my), size: 8, color: AppColors.danger, w: FontWeight.w900);
    }
    // 부품 자리 안내선(위 그림과 같은 x)
    final guide = Paint()
      ..color = AppColors.textFaint.withValues(alpha: .35)
      ..strokeWidth = 1;
    for (final it in items) {
      for (var yy = 104.0; yy < gBot; yy += 6) {
        if (yy > 142 && yy < 150) continue;
        c.drawLine(Offset(it.cx, yy), Offset(it.cx, yy + 3), guide);
      }
    }

    // 계단 선(분배기 + 단자 → 전송기 + 단자)
    final pts = <Offset>[Offset(gLeft, y(supplyV))];
    var v = supplyV;
    final dropMarks = <(Offset, double)>[];
    for (final it in items) {
      if (it.kind == _Kind.cable) {
        pts.add(Offset(it.x0, y(v)));
        final v2 = v - it.drop;
        pts.add(Offset(it.x1, y(v2)));
        if (it.drop > 0) dropMarks.add((Offset(it.cx, y(v) - 12), it.drop));
        v = v2;
      } else {
        pts.add(Offset(it.cx - 6, y(v)));
        final v2 = v - it.drop;
        pts.add(Offset(it.cx + 6, y(v2)));
        dropMarks.add((Offset(it.cx, y(v) - 12), it.drop));
        v = v2;
      }
    }
    pts.add(Offset(gRight, y(terminalV)));
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    final reveal = _stage(t, 0.08, 0.82);
    final metric = line.computeMetrics().first;
    final shown = metric.extractPath(0, metric.length * reveal);
    final endTan = metric.getTangentForOffset(metric.length * reveal);
    // 아래 채움
    if (endTan != null && reveal > 0) {
      final fill = Path.from(shown)
        ..lineTo(endTan.position.dx, gBot)
        ..lineTo(gLeft, gBot)
        ..close();
      c.drawPath(fill, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.brand.withValues(alpha: .28), AppColors.brand.withValues(alpha: .04)]).createShader(const Rect.fromLTRB(gLeft, gTop, gRight, gBot)));
    }
    c.drawPath(shown, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = AppColors.brand);
    // 강하 표시(지나간 것만)
    for (final (p, d) in dropMarks) {
      if (endTan == null || endTan.position.dx < p.dx) continue;
      lpPill(c, '−${d.toStringAsFixed(1)}V', p, _orange, size: 8); // 계단 위쪽(떨어지기 전 높이)
    }
    // 움직이는 측정점(그 자리 전압)
    if (endTan != null && reveal > 0 && reveal < 1) {
      final at = endTan.position;
      final vNow = supplyV * (gBot - at.dy) / (gBot - gTop);
      c.drawCircle(at, 7, Paint()
        ..color = AppColors.brand.withValues(alpha: .3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      c.drawCircle(at, 4.5, Paint()..color = Colors.white);
      c.drawCircle(at, 3, Paint()..color = AppColors.brand);
      lpPill(c, _v(vNow), at + const Offset(0, -16), AppColors.brand, size: 8.5);
    }
    // 끝: 단자 전압과 판정
    final endT = _stage(t, 0.84, 1.0);
    if (endT > 0) {
      final color = ok ? AppColors.ok : AppColors.danger;
      final at = Offset(gRight, y(terminalV));
      c.drawCircle(at, 5.5 * endT, Paint()..color = color);
      c.drawCircle(at, 5.5 * endT, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white);
      // 선 아래에 둔다(강하 표시는 선 위). 바닥에 가까우면 위로.
      final below = at.dy + 18 < gBot - 6;
      lpPill(c, '단자 ${_v(terminalV)} ${ok ? '충분' : '부족'}', Offset(gRight - 40, below ? at.dy + 18 : at.dy - 18), color, size: 9);
    }
    lpText(c, '분배기 +', const Offset(gLeft + 4, 284), size: 8, color: AppColors.textSub);
    lpText(c, '전송기 +', const Offset(gRight - 4, 284), size: 8, color: AppColors.textSub);
    c.restore();
  }

  @override
  bool shouldRepaint(_LoopDropPainter o) =>
      o.t != t ||
      o.supplyV != supplyV ||
      o.minV != minV ||
      o.wireV != wireV ||
      o.hartV != hartV ||
      o.barrierV != barrierV ||
      o.extraV != extraV ||
      o.terminalV != terminalV ||
      o.ok != ok ||
      o.checkMa != checkMa;
}
