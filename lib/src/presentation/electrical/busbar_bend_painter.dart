// 부스바 절곡 그림: 측면도(수직절곡은 평면도), 전개도(마킹). 계산은 busbar_bend.dart.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'busbar_bend.dart';
import 'elec_form_parts.dart' show fmt;

const Color _copperLight = Color(0xFFE9A878);
const Color _copperDark = Color(0xFFB66A3C);
const Color _markUp = Color(0xFF0F9D8F);
const Color _markDown = Color(0xFFE08A1E);

Color busbarBendColor(double turn) => turn >= 0 ? _markUp : _markDown;

void _label(
  Canvas canvas,
  String s,
  Offset at,
  Color color, {
  double size = 11.5,
  bool center = true,
  bool bold = false,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontSize: size,
        color: color,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, center ? at - Offset(tp.width / 2, tp.height / 2) : at);
}

Paint _copperPaint(Rect r) => Paint()
  ..shader = const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [_copperLight, _copperDark],
  ).createShader(r);

/// 측면도(절곡한 뒤 모양). 실제 비율이고, 띠 폭은 [thickness](평절곡은 판 두께, 수직절곡은 폭)로 그린다.
/// 10-12: 두 면(가장자리)을 따로 그려 넓은 띠도 화면 안에 다 들어오고 테두리·꺾는 구간이 보인다.
/// [innerRadius]를 주면 안쪽 면이 그 반경이 되게 그리고, 없으면 예전처럼 가운데선을 [rho]로 걷는다.
class BusbarShapePainter extends CustomPainter {
  BusbarShapePainter({
    required this.plan,
    required this.rho,
    required this.thickness,
    this.innerRadius,
    this.edge = false,
    this.startHeadingDeg = 0,
    required this.text,
    required this.sub,
    required this.line,
    this.metal = const [_copperLight, _copperDark],
  });

  final BusbarBendPlan plan;
  final double rho, thickness, startHeadingDeg;
  final double? innerRadius;

  /// 수직절곡: 평면도(넓은 면, 글만 다르다).
  final bool edge;
  final Color text, sub, line;

  /// 판 색(밝은 쪽, 어두운 쪽). 기본은 구리. 철판 가공은 철 색을 넘긴다(10-10).
  final List<Color> metal;

  @override
  void paint(Canvas canvas, Size size) {
    final half0 = math.max(thickness, 0.0) / 2;
    final strip = busbarStrip(
      plan,
      innerRadius != null ? innerRadius! + half0 : rho,
      startHeadingDeg: startHeadingDeg,
    );
    final l0 = strip.left(half0), r0 = strip.right(half0);
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final p in [...l0, ...r0]) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    const pad = 22.0, padTop = 30.0;
    final w = math.max(maxX - minX, 1.0), h = math.max(maxY - minY, 1.0);
    final sc = math.min(
      (size.width - 2 * pad) / w,
      (size.height - pad - padTop) / h,
    );
    final ox = (size.width - w * sc) / 2 - minX * sc;
    final oy = padTop + (size.height - pad - padTop + h * sc) / 2 + minY * sc;
    Offset map(math.Point<double> p) => Offset(ox + p.x * sc, oy - p.y * sc);

    // 얇은 판은 5px보다 가늘면 안 보여 그림만 5px로 굵힌다.
    final half = math.max(half0, 2.5 / sc);
    final left = half == half0 ? l0 : strip.left(half);
    final right = half == half0 ? r0 : strip.right(half);
    Path band(int from, int to) {
      final path = Path()..moveTo(map(left[from]).dx, map(left[from]).dy);
      for (var i = from + 1; i <= to; i++) {
        final o = map(left[i]);
        path.lineTo(o.dx, o.dy);
      }
      for (var i = to; i >= from; i--) {
        final o = map(right[i]);
        path.lineTo(o.dx, o.dy);
      }
      return path..close();
    }

    final body = band(0, strip.center.length - 1);
    final box = body.getBounds();
    canvas.drawPath(
      body.shift(const Offset(0, 2.5)),
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: metal,
        ).createShader(box),
    );
    // 꺾는 구간(호): 밝게, 시작선·끝선은 마킹 그림과 같은 색으로
    for (var i = 0; i < plan.bends.length; i++) {
      final (s0, _, s1) = strip.bends[i];
      final col = busbarBendColor(plan.bends[i].turn);
      canvas.drawPath(band(s0, s1), Paint()..color = const Color(0x40FFFFFF));
      for (final j in [s0, s1]) {
        canvas.drawLine(
          map(left[j]),
          map(right[j]),
          Paint()
            ..color = col
            ..strokeWidth = 2,
        );
      }
    }
    // 하이라이트(왼쪽 면 안쪽으로 살짝)와 테두리
    final hl = Path();
    for (var i = 0; i < left.length; i++) {
      final a = map(left[i]), b = map(right[i]);
      final o =
          a + (b - a) * math.min(0.18, 1.6 / math.max((b - a).distance, 1));
      i == 0 ? hl.moveTo(o.dx, o.dy) : hl.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      hl,
      Paint()
        ..color = const Color(0x66FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawPath(
      body,
      Paint()
        ..color = metal.last
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round,
    );
    // 꺾는 곳 번호(호 가운데)
    for (var i = 0; i < plan.bends.length; i++) {
      final o = map(strip.center[strip.bends[i].$2]);
      canvas.drawCircle(
        o,
        9,
        Paint()..color = busbarBendColor(plan.bends[i].turn),
      );
      _label(canvas, '${i + 1}', o, Colors.white, bold: true);
    }
    _label(
      canvas,
      innerRadius == null
          ? '측면도 · 중립선 길이 ${fmt(plan.cutLength)}mm'
          : edge
          ? '평면도(넓은 면, 수직절곡) · 내R ${fmt(innerRadius!)}mm'
          : '측면도(평절곡) · 내R ${fmt(innerRadius!)}mm',
      const Offset(10, 6),
      sub,
      center: false,
    );
  }

  @override
  bool shouldRepaint(BusbarShapePainter o) =>
      o.plan != plan ||
      o.rho != rho ||
      o.thickness != thickness ||
      o.innerRadius != innerRadius ||
      o.edge != edge ||
      o.startHeadingDeg != startHeadingDeg ||
      o.metal != metal;
}

/// 꺾은선 위에서 시작점으로부터 길이 [len]인 점.

/// 전개도: 절곡 전 부스바와 절곡 시작선·끝선 마킹.
class BusbarMarkPainter extends CustomPainter {
  BusbarMarkPainter({
    required this.plan,
    required this.text,
    required this.sub,
    required this.line,
  });

  final BusbarBendPlan plan;
  final Color text, sub, line;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 16.0;
    final len = math.max(plan.cutLength, 1.0);
    final sc = (size.width - 2 * pad) / len;
    final y0 = size.height / 2 - 6;
    const barH = 26.0;
    final bar = Rect.fromLTWH(pad, y0, len * sc, barH);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        bar.shift(const Offset(0, 2)),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, const Radius.circular(3)),
      _copperPaint(bar),
    );
    for (var i = 0; i < plan.bends.length; i++) {
      final b = plan.bends[i];
      final col = busbarBendColor(b.turn);
      final zone = Rect.fromLTRB(
        pad + b.start * sc,
        y0,
        pad + math.max(b.end * sc, b.start * sc + 2),
        y0 + barH,
      );
      canvas.drawRect(zone, Paint()..color = col.withValues(alpha: 0.55));
      for (final x in [b.start, b.end]) {
        canvas.drawLine(
          Offset(pad + x * sc, y0 - 6),
          Offset(pad + x * sc, y0 + barH + 6),
          Paint()
            ..color = col
            ..strokeWidth = 1.6,
        );
      }
      _label(
        canvas,
        '${i + 1}',
        zone.center,
        Colors.white,
        bold: true,
        size: 12,
      );
      final above = i.isEven;
      _label(
        canvas,
        fmt(b.start),
        Offset(pad + b.start * sc, above ? y0 - 16 : y0 + barH + 16),
        text,
        bold: true,
      );
    }
    _label(canvas, '0', Offset(pad, y0 + barH + 16), sub);
    _label(
      canvas,
      fmt(plan.cutLength),
      Offset(pad + len * sc, y0 + barH + 16),
      sub,
    );
    _label(
      canvas,
      '전개도 · 숫자는 한쪽 끝 기준 절곡 시작선 위치(mm)',
      const Offset(10, 6),
      sub,
      center: false,
    );
  }

  @override
  bool shouldRepaint(BusbarMarkPainter o) => o.plan != plan;
}
