// 케이블 트레이 형상 그림(10-03): 옆에서 본 모양(장애물·트레이)과 자르기 전 측판 마킹.
// 계산은 cable_tray_route.dart. 그림은 실제 비율(옆 모습)이고, 마킹 그림만 높이를 키워 그린다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cable_tray.dart' show trayNum;
import 'cable_tray_route.dart';

const Color _metalLight = Color(0xFFD7DDE2);
const Color _metalMid = Color(0xFF9AA5AE);
const Color _metalDark = Color(0xFF5E6A73);
const Color _upColor = Color(0xFF0E7C86); // 위로 꺾기(윗변 V컷)
const Color _downColor = Color(0xFFE07A1F); // 아래로 꺾기(아랫변 V컷)

Color trayCornerColor(TrayCorner c) => c.up ? _upColor : _downColor;

void _label(
  Canvas canvas,
  String t,
  Offset at,
  Color color, {
  double size = 12,
  bool center = true,
  bool bold = true,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: t,
      style: TextStyle(
        fontSize: size,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, center ? at - Offset(tp.width / 2, tp.height / 2) : at);
}

void _badge(Canvas canvas, Offset c, int n, Color col) {
  canvas.drawCircle(
    c + const Offset(0.6, 1),
    9,
    Paint()..color = Colors.black.withValues(alpha: 0.2),
  );
  canvas.drawCircle(
    c,
    9,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        colors: [
          Color.lerp(col, Colors.white, 0.3)!,
          col,
          Color.lerp(col, Colors.black, 0.25)!,
        ],
      ).createShader(Rect.fromCircle(center: c, radius: 9)),
  );
  _label(canvas, '$n', c, Colors.white, size: 11);
}

/// 옆에서 본 모양. 바닥면 선(아래)과 측판 윗변(위)을 꺾는 점마다 이어 그린다.
/// 옆으로 비켜가기·옮겨가기는 위에서 본 모양(장애물 쪽 측판과 반대쪽 측판)으로 그린다.
class TrayRouteSidePainter extends CustomPainter {
  final TrayRoute route;

  /// 위에서 본 모양에서 장애물이 진행 방향 왼쪽이면 위아래를 뒤집는다(왼쪽이 위).
  final bool flip;

  /// 기성 엘보 모드: 부품(직선·엘보)마다 이음 자리 선과 번호를 그린다.
  final List<TrayPiece>? pieces;

  /// 장애물(넘어가기)이나 단(올라가기·내려가기): 시작점 기준 x 범위와 높이(mm, 지금 트레이 바닥 기준).
  final double? boxFrom, boxTo, boxHeight;
  final Color text, sub, line, bg;

  TrayRouteSidePainter({
    required this.route,
    this.flip = false,
    this.pieces,
    this.boxFrom,
    this.boxTo,
    this.boxHeight,
    required this.text,
    required this.sub,
    required this.line,
    required this.bg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pts = route.points;
    if (pts.length < 2) return;
    final h = route.rail;
    // 윗변 점: 꺾는 점마다 두 선(앞뒤 구간을 h만큼 왼쪽으로 민 선)의 교점
    final top = <Offset>[];
    for (var i = 0; i < pts.length; i++) {
      final p = Offset(pts[i].$1, pts[i].$2);
      final a = i > 0
          ? math.atan2(pts[i].$2 - pts[i - 1].$2, pts[i].$1 - pts[i - 1].$1)
          : null;
      final b = i < pts.length - 1
          ? math.atan2(pts[i + 1].$2 - pts[i].$2, pts[i + 1].$1 - pts[i].$1)
          : null;
      final dirA = a ?? b!, dirB = b ?? a!;
      final mid = (dirA + dirB) / 2;
      final half = (dirB - dirA) / 2;
      final k = h / math.cos(half);
      top.add(p + Offset(-math.sin(mid) * k, math.cos(mid) * k));
    }
    final plan = trayRouteIsPlan(route.kind);
    double fy(double y) => flip ? -y : y;
    var minX = 0.0, maxX = 0.0, minY = 0.0, maxY = 0.0;
    void grow(double x, double y) {
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, fy(y));
      maxY = math.max(maxY, fy(y));
    }

    for (final p in pts) {
      grow(p.$1, p.$2);
    }
    for (final p in top) {
      grow(p.dx, p.dy);
    }
    final bh = boxHeight;
    final hasBox =
        boxFrom != null &&
        bh != null &&
        (!trayRouteReturns(route.kind) || boxTo != null);
    // 위에서 본 장애물은 측판 줄 바깥으로도 조금 걸쳐 그린다
    final outside = plan && bh != null ? -math.max(120.0, bh * 0.5) : 0.0;
    if (hasBox) {
      grow(boxFrom!, route.kind == TrayRouteKind.down ? 0 : bh);
      if (boxTo != null) grow(boxTo!, 0);
      if (plan) grow(boxFrom!, outside);
    }
    // 위에서 본 모양은 옮기는 거리 치수를 시작점 왼쪽 바깥에 둔다
    final padL = 52.0;
    const padR = 18.0, padT = 26.0, padB = 34.0;
    final w = size.width - padL - padR, hh = size.height - padT - padB;
    final s = math.min(
      w / math.max(1, maxX - minX),
      hh / math.max(1, maxY - minY),
    );
    final ox = padL + (w - (maxX - minX) * s) / 2 - minX * s;
    final oy = padT + hh - (hh - (maxY - minY) * s) / 2 + minY * s;
    Offset m(double x, double y) => Offset(ox + x * s, oy - fy(y) * s);

    if (plan) {
      // 원래 가던 줄(곧게 갔다면 트레이가 놓일 자리)을 점선으로
      final dash = Paint()
        ..color = sub.withValues(alpha: 0.7)
        ..strokeWidth = 1;
      for (final y in [0.0, h]) {
        final y0 = m(0, y).dy;
        for (var x = m(0, 0).dx; x < m(maxX, 0).dx; x += 9) {
          canvas.drawLine(
            Offset(x, y0),
            Offset(math.min(x + 5, m(maxX, 0).dx), y0),
            dash,
          );
        }
      }
    }
    // 바닥(지금 트레이가 놓인 면)
    final floorY = route.kind == TrayRouteKind.down
        ? m(0, route.points.last.$2).dy
        : m(0, 0).dy;
    if (!plan) {
      final ground = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [line.withValues(alpha: 0.55), line.withValues(alpha: 0.05)],
        ).createShader(Rect.fromLTRB(0, floorY, size.width, floorY + 18));
      canvas.drawRect(
        Rect.fromLTRB(4, floorY, size.width - 4, floorY + 18),
        ground,
      );
      canvas.drawLine(
        Offset(4, floorY),
        Offset(size.width - 4, floorY),
        Paint()
          ..color = sub
          ..strokeWidth = 1.2,
      );
    }

    // 장애물·단: 콘크리트 느낌 그라데이션 + 그림자
    if (hasBox) {
      final r = switch (route.kind) {
        TrayRouteKind.over => Rect.fromPoints(m(boxFrom!, bh), m(boxTo!, 0)),
        TrayRouteKind.up => Rect.fromPoints(
          m(boxFrom!, bh),
          Offset(size.width - 4, m(0, 0).dy),
        ),
        TrayRouteKind.down => Rect.fromPoints(
          Offset(4, m(0, 0).dy),
          m(boxFrom!, route.points.last.$2),
        ),
        TrayRouteKind.aside => Rect.fromPoints(
          m(boxFrom!, bh),
          m(boxTo!, outside),
        ),
        TrayRouteKind.shift => Rect.fromPoints(
          m(boxFrom!, bh),
          Offset(size.width - 4, m(0, outside).dy),
        ),
        TrayRouteKind.tee => Rect.zero, // 티는 TrayTeePainter로 그린다
      };
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          r.shift(const Offset(2, 3)),
          const Radius.circular(3),
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.12),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(3)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB9B4AA), Color(0xFF8F8A80)],
          ).createShader(r),
      );
      canvas.drawLine(
        r.topLeft + const Offset(2, 1.5),
        r.topRight + const Offset(-2, 1.5),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..strokeWidth = 1.5,
      );
      if (trayRouteReturns(route.kind) || plan) {
        _label(canvas, '장애물', r.center, Colors.white);
      }
    }

    // 트레이 띠(측판 옆면)
    final band = Path()
      ..moveTo(
        m(pts.first.$1, pts.first.$2).dx,
        m(pts.first.$1, pts.first.$2).dy,
      );
    for (final p in pts.skip(1)) {
      final o = m(p.$1, p.$2);
      band.lineTo(o.dx, o.dy);
    }
    for (final t in top.reversed) {
      final o = m(t.dx, t.dy);
      band.lineTo(o.dx, o.dy);
    }
    band.close();
    canvas.drawPath(
      band.shift(const Offset(1.5, 2.5)),
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );
    final bounds = band.getBounds();
    canvas.drawPath(
      band,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_metalLight, _metalMid, _metalDark],
          stops: [0, 0.6, 1],
        ).createShader(bounds),
    );
    canvas.drawPath(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _metalDark,
    );
    // 윗변 하이라이트
    final hl = Path();
    for (var i = 0; i < top.length; i++) {
      final o = m(top[i].dx, top[i].dy) + const Offset(0, 1.2);
      i == 0 ? hl.moveTo(o.dx, o.dy) : hl.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      hl,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.6),
    );

    // 기성 엘보: 이음 자리(부품 경계) 선과 부품 번호
    final ps = pieces;
    if (ps != null) {
      Offset nrm(double d, double k) =>
          Offset(-math.sin(d) * k, math.cos(d) * k);
      final joint = Paint()
        ..color = _metalDark
        ..strokeWidth = 1.6;
      for (var i = 0; i < ps.length; i++) {
        final p = ps[i];
        if (i > 0) {
          final b = Offset(p.from.$1, p.from.$2);
          canvas.drawLine(
            m(b.dx, b.dy),
            m(b.dx + nrm(p.from.$3, h).dx, b.dy + nrm(p.from.$3, h).dy),
            joint,
          );
        }
      }
      var n = 0;
      final placedP = <Offset>[];
      for (final p in ps) {
        if (!p.elbow && p.length < 1e-6) continue;
        n++;
        final mx = (p.from.$1 + p.to.$1) / 2, my = (p.from.$2 + p.to.$2) / 2;
        final d = (p.from.$3 + p.to.$3) / 2;
        // 번호는 기준선 반대쪽(윗변 바깥)
        final o = nrm(d, h);
        final c = m(mx + o.dx, my + o.dy);
        final c0 = m(mx, my);
        final unit = (c - c0).distance == 0
            ? const Offset(0, -1)
            : (c - c0) / (c - c0).distance;
        var at = c + unit * 13;
        for (
          var k = 0;
          k < 4 && placedP.any((q) => (q - at).distance < 19);
          k++
        ) {
          at += unit * 18;
        }
        placedP.add(at);
        _badge(
          canvas,
          at,
          n,
          p.elbow ? (p.up ? _upColor : _downColor) : _metalDark,
        );
      }
    }

    // 꺾는 점: 접는 선(바닥면↔윗변)과 번호
    final placed = <Offset>[];
    for (var i = 0; i < route.corners.length; i++) {
      final c = route.corners[i];
      final j = pts.indexWhere(
        (p) => (p.$1 - c.x).abs() < 1e-6 && (p.$2 - c.y).abs() < 1e-6,
      );
      if (j < 0) continue;
      final b = m(c.x, c.y), t = m(top[j].dx, top[j].dy);
      canvas.drawLine(
        b,
        t,
        Paint()
          ..color = trayCornerColor(c)
          ..strokeWidth = 2.2,
      );
      // 번호는 V컷 쪽(위로 꺾기 = 윗변 바깥, 아래로 꺾기 = 바닥면 바깥)
      // 번호가 앞 번호와 겹치면 같은 방향으로 더 밀어낸다
      final from = c.up ? t : b;
      final unit = c.up
          ? (t - b) / (t - b).distance
          : (b - t) / (b - t).distance;
      var away = from + unit * 13;
      for (
        var k = 0;
        k < 4 && placed.any((p) => (p - away).distance < 19);
        k++
      ) {
        away += unit * 18;
      }
      placed.add(away);
      _badge(canvas, away, i + 1, trayCornerColor(c));
    }

    // 높이 치수: 번호와 겹치지 않게 시작 직선(좁으면 끝 직선) 가운데
    final rise = trayRouteReturns(route.kind)
        ? pts.map((p) => p.$2).reduce(math.max)
        : pts.last.$2;
    if (rise.abs() > 0 && pts.length > 2) {
      final firstX = route.corners.isNotEmpty
          ? route.corners.first.x
          : pts[1].$1;
      final a0 = m(0, 0).dx, a1 = m(firstX, 0).dx;
      // 시작 직선이 짧거나 옆 모양이면 시작점 왼쪽 바깥에(끝 직선은 장애물 위일 수 있어 안 씀)
      final x0 = !plan && a1 - a0 >= 60 ? (a0 + a1) / 2 : a0 - 26;
      final y0 = m(0, math.min(0, rise)).dy, y1 = m(0, math.max(0, rise)).dy;
      final dim = Paint()
        ..color = sub
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x0, y0), Offset(x0, y1), dim);
      for (final y in [y0, y1]) {
        canvas.drawLine(Offset(x0 - 4, y), Offset(x0 + 4, y), dim);
      }
      final tp = TextPainter(
        text: TextSpan(
          text: trayNum(rise.abs()),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: text,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final at = Offset(x0 - tp.width / 2, (y0 + y1) / 2 - tp.height / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(at.dx - 4, at.dy - 1, tp.width + 8, tp.height + 2),
          const Radius.circular(4),
        ),
        Paint()..color = bg,
      );
      tp.paint(canvas, at);
    }
    _label(canvas, '시작점', m(0, 0) + Offset(0, flip ? -12 : 12), sub, size: 11);
  }

  @override
  bool shouldRepaint(TrayRouteSidePainter o) =>
      o.route != route ||
      o.boxFrom != boxFrom ||
      o.boxTo != boxTo ||
      o.boxHeight != boxHeight ||
      o.flip != flip ||
      o.bg != bg;
}

/// 자르기 전 곧은 트레이 측판(옆면). 위로 꺾기는 윗변, 아래로 꺾기는 아랫변에 V컷을 그리고
/// 아랫변 마킹 거리를 적는다. 길이는 실제 비율, 높이는 보기 좋게 키웠다.
/// 옆으로 꺾을 때는 위에서 본 곧은 트레이(측판 두 줄 사이)로 보고, [flip]이면 마킹 기준 측판이 위.
class TrayRouteMarkPainter extends CustomPainter {
  final TrayRoute route;
  final Color text, sub, line, bg;

  /// V컷 반대쪽 테두리 이름과 마킹 기준 테두리 이름.
  final String farLabel, refLabel;
  final bool flip;

  TrayRouteMarkPainter({
    required this.route,
    this.farLabel = '측판 윗변',
    this.refLabel = '아랫변 (가로대 쪽, 마킹 기준)',
    this.flip = false,
    required this.text,
    required this.sub,
    required this.line,
    required this.bg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padX = 16.0;
    final len = math.max(1.0, route.material);
    final s = (size.width - padX * 2) / len;
    const railH = 46.0;
    final top = size.height / 2 - railH / 2 - 4;
    final bot = top + railH;
    double x(double mm) => padX + mm * s;
    final hScale = railH / route.rail; // 세로는 따로 키움

    // 측판 외곽: V컷을 판 모양. eT = 기준 반대쪽 테두리, eB = 마킹 기준 테두리
    final eT = flip ? bot : top, eB = flip ? top : bot;
    double inset(double v, double toward) => v + (toward > v ? 1.5 : -1.5);
    final path = Path()..moveTo(x(0), eT);
    final ups = route.corners.where((c) => c.up).toList()
      ..sort((a, b) => a.mark.compareTo(b.mark));
    final downs = route.corners.where((c) => !c.up).toList()
      ..sort((a, b) => a.mark.compareTo(b.mark));
    for (final c in ups) {
      final half = c.notch / 2 * s;
      path
        ..lineTo(x(c.mark) - half, eT)
        ..lineTo(x(c.mark), inset(eB, eT))
        ..lineTo(x(c.mark) + half, eT);
    }
    path.lineTo(x(len), eT);
    path.lineTo(x(len), eB);
    for (final c in downs.reversed) {
      final half = c.notch / 2 * s;
      path
        ..lineTo(x(c.mark) + half, eB)
        ..lineTo(x(c.mark), inset(eT, eB))
        ..lineTo(x(c.mark) - half, eB);
    }
    path
      ..lineTo(x(0), eB)
      ..close();
    final rect = Rect.fromLTRB(x(0), top, x(len), bot);
    canvas.drawPath(
      path.shift(const Offset(1.5, 2.5)),
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_metalLight, _metalMid, _metalDark],
          stops: [0, 0.6, 1],
        ).createShader(rect),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = _metalDark,
    );
    canvas.drawLine(
      Offset(x(0), top + 1.2),
      Offset(x(len), top + 1.2),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = 1.1,
    );
    _label(
      canvas,
      flip ? refLabel : farLabel,
      Offset(x(0), top - 16),
      sub,
      size: 10.5,
      center: false,
      bold: false,
    );
    _label(
      canvas,
      flip ? farLabel : refLabel,
      Offset(x(0), bot + 3),
      sub,
      size: 10.5,
      center: false,
      bold: false,
    );

    // 마킹: 번호와 거리. 번호는 V컷 쪽, 거리는 아래 줄에 엇갈려
    final sorted = [...route.corners]..sort((a, b) => a.mark.compareTo(b.mark));
    for (var k = 0; k < sorted.length; k++) {
      final c = sorted[k];
      final i = route.corners.indexOf(c);
      final col = trayCornerColor(c);
      final cx = x(c.mark);
      canvas.drawLine(
        Offset(cx, top - 2),
        Offset(cx, bot + 2),
        Paint()
          ..color = col
          ..strokeWidth = 1.6,
      );
      _badge(canvas, Offset(cx, c.up ? top - 24 : top - 24), i + 1, col);
      _label(
        canvas,
        trayNum(c.mark),
        Offset(cx, bot + 22 + (k.isOdd ? 14 : 0)),
        text,
        size: 11.5,
      );
    }
    _label(
      canvas,
      '전체 ${trayNum(len)}mm',
      Offset(size.width / 2, size.height - 14),
      sub,
      size: 11,
    );
    // 높이 키운 비율 표시(그림 아래 글 대신)
    if (hScale > s * 1.5) {
      _label(
        canvas,
        '높이는 키워 그림',
        Offset(x(len) - 50, top - 16),
        sub,
        size: 10,
        center: false,
        bold: false,
      );
    }
  }

  @override
  bool shouldRepaint(TrayRouteMarkPainter o) =>
      o.route != route ||
      o.bg != bg ||
      o.flip != flip ||
      o.farLabel != farLabel ||
      o.refLabel != refLabel;
}

/// 가지 내기(수평 티)를 위에서 본 모양. 본선(앞 직선·티·뒤 직선)과 가지 직선, 이음 자리, 부품 번호.
/// 좌표(mm): x = 본선 방향(시작점 0), y = 가지 쪽 측판이 0, 본선은 y 0~W, 가지는 y < 0.
/// [flip]이면 가지가 진행 방향 왼쪽(그림 위쪽).
class TrayTeePainter extends CustomPainter {
  final TrayTee tee;
  final bool flip;
  final Color text, sub, line, bg;

  TrayTeePainter({
    required this.tee,
    this.flip = false,
    required this.text,
    required this.sub,
    required this.line,
    required this.bg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = tee.width, r = tee.radius, t = tee.tangent;
    final x1 = tee.before, x2 = x1 + tee.a, total = x2 + tee.tail;
    final cx = x1 + tee.a / 2;
    final reach = math.max(tee.reach, r + t);
    const pad = 22.0;
    final spanX = math.max(1.0, total), spanY = w + reach;
    final s = math.min(
      (size.width - pad * 2) / spanX,
      (size.height - pad * 2) / spanY,
    );
    final ox = (size.width - spanX * s) / 2;
    // 그림 위쪽 = 본선 반대쪽 측판(y = W), flip이면 위아래 뒤집음
    final oyTop = (size.height - spanY * s) / 2;
    Offset m(double x, double y) {
      final fromTop = flip ? (y + reach) : (w - y);
      return Offset(ox + x * s, oyTop + fromTop * s);
    }

    // 본선 + 티 + 가지 바깥선
    final path = Path();
    void to(double x, double y) {
      final o = m(x, y);
      path.lineTo(o.dx, o.dy);
    }

    void arc(double ax, double ay, double from, double sweep) {
      // 중심 (ax, ay) mm, 반경 r, 각(rad, mm 좌표 기준)
      const n = 12;
      for (var k = 1; k <= n; k++) {
        final d = from + sweep * k / n;
        to(ax + r * math.cos(d), ay + r * math.sin(d));
      }
    }

    final start = m(0, w);
    path.moveTo(start.dx, start.dy);
    to(total, w);
    to(total, 0);
    to(x2, 0);
    to(x2 - t, 0);
    // 오른쪽 곡선: 중심 (x2 − t, −R), (x2 − t, 0) → (cx + W/2, −R)
    arc(x2 - t, -r, math.pi / 2, math.pi / 2);
    to(cx + w / 2, -(r + t));
    to(cx + w / 2, -reach);
    to(cx - w / 2, -reach);
    to(cx - w / 2, -(r + t));
    to(cx - w / 2, -r);
    // 왼쪽 곡선: 중심 (x1 + t, −R), (cx − W/2, −R) → (x1 + t, 0)
    arc(x1 + t, -r, 0, math.pi / 2);
    to(x1, 0);
    to(0, 0);
    path.close();
    final bounds = path.getBounds();
    canvas.drawPath(
      path.shift(const Offset(1.5, 2.5)),
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_metalLight, _metalMid, _metalDark],
          stops: [0, 0.6, 1],
        ).createShader(bounds),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _metalDark,
    );

    // 이음 자리: 티 양 끝면, 티 가지 끝면
    final joint = Paint()
      ..color = _metalDark
      ..strokeWidth = 1.8;
    if (x1 > 0) canvas.drawLine(m(x1, 0), m(x1, w), joint);
    if (tee.tail > 0) canvas.drawLine(m(x2, 0), m(x2, w), joint);
    if (tee.branch > 0) {
      canvas.drawLine(m(cx - w / 2, -(r + t)), m(cx + w / 2, -(r + t)), joint);
    }

    // 부품 번호: 1 앞 직선, 2 티, 3 뒤 직선, 4 가지 직선(길이 0이면 건너뜀)
    var n = 0;
    void badge(bool show, double x, double y, Color col) {
      if (!show) return;
      n++;
      _badge(canvas, m(x, y), n, col);
    }

    badge(x1 > 0, x1 / 2, w / 2, _metalDark);
    badge(true, cx, w / 2, _upColor);
    badge(tee.tail > 0, x2 + tee.tail / 2, w / 2, _metalDark);
    badge(tee.branch > 0, cx, -(r + t + tee.branch / 2), _metalDark);
    _label(canvas, '시작점', m(0, 0) + Offset(0, flip ? -12 : 12), sub, size: 11);
  }

  @override
  bool shouldRepaint(TrayTeePainter o) =>
      o.tee != tee || o.flip != flip || o.bg != bg;
}
