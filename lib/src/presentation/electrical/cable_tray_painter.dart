// 케이블 트레이 단면 그림(10-03): 케이블을 실제 외경 비율로 트레이 단면에 놓아 보여 준다.
// 놓는 방법은 단순한 "줄 쌓기": 굵은 것부터 바닥에 왼쪽→오른쪽으로 깔고, 폭을 넘으면 그 위 줄로.
// 한 층 규칙이면 한 줄만 깐다. 깊이·폭을 넘친 케이블은 빨간 테두리로 보인다.
// 그림은 눈으로 보는 참고이고, 합격·불합격은 cable_tray.dart의 판정을 따른다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cable_tray.dart';

/// 그림에 놓인 케이블 한 가닥.
class TrayDot {
  final double x, y, r; // 트레이 안 좌표(mm). x는 왼쪽 벽, y는 바닥에서.
  final int row; // 케이블 목록의 줄 번호(0부터)
  final bool over; // 폭이나 깊이를 넘쳤는지
  const TrayDot(this.x, this.y, this.r, this.row, this.over);
}

class TrayLayout {
  final List<TrayDot> dots;
  final int hidden; // 너무 많아 그리지 않은 가닥 수
  const TrayLayout(this.dots, this.hidden);
  bool get anyOver => dots.any((d) => d.over);
}

/// 그림에 그리는 가닥 수 상한(넘으면 나머지는 수만 적는다).
const int kTrayDrawMax = 300;

/// 줄 쌓기로 놓는다. [singleLayer]면 바닥 한 줄만 쓴다.
TrayLayout layoutTray(List<TrayCable> cables, double width, double depth, {required bool singleLayer}) {
  final items = <(double d, int row)>[];
  var total = 0;
  for (var i = 0; i < cables.length; i++) {
    // 가닥 수만큼 돌지 않는다(10-07: 오타로 1억을 넣으면 칠 때마다 1억 번씩 돌아 화면이 멈췄다).
    final c = cables[i].count;
    if (c > 0) total += c;
    final draw = math.min(math.max(c, 0), kTrayDrawMax - items.length);
    for (var k = 0; k < draw; k++) {
      items.add((cables[i].od, i));
    }
  }
  items.sort((a, b) => b.$1.compareTo(a.$1));
  final dots = <TrayDot>[];
  var x = 0.0, shelfY = 0.0, shelfH = 0.0;
  for (final (d, row) in items) {
    if (x + d > width + 1e-9 && x > 0 && !singleLayer) {
      shelfY += shelfH;
      x = 0;
      shelfH = 0;
    }
    final r = d / 2;
    final over = x + d > width + 1e-9 || shelfY + d > depth + 1e-9;
    dots.add(TrayDot(x + r, shelfY + r, r, row, over));
    x += d;
    shelfH = math.max(shelfH, d);
  }
  return TrayLayout(dots, total - items.length);
}

/// 줄 번호별 색(목록의 번호 칩과 같은 색).
const List<Color> kTrayRowColors = [
  Color(0xFF0E7C86),
  Color(0xFFE07A1F),
  Color(0xFF5B6CCF),
  Color(0xFF2E9D52),
  Color(0xFFC0397A),
  Color(0xFF8A6D1F),
  Color(0xFF3B8FD1),
  Color(0xFF7A4BC2),
  Color(0xFF9C5B3A),
  Color(0xFF4F7F2A),
  Color(0xFFB2443A),
  Color(0xFF51606F),
];

Color trayRowColor(int i) => kTrayRowColors[i % kTrayRowColors.length];

class TraySectionPainter extends CustomPainter {
  final TrayType type;
  final double width, depth;
  final TrayLayout layout;
  final Color text, sub, line, bg;

  TraySectionPainter({
    required this.type,
    required this.width,
    required this.depth,
    required this.layout,
    required this.text,
    required this.sub,
    required this.line,
    required this.bg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 넘친 케이블이 위·옆으로 나가도 보이게 여유를 둔다.
    var maxX = width, maxY = depth;
    for (final d in layout.dots) {
      maxX = math.max(maxX, d.x + d.r);
      maxY = math.max(maxY, d.y + d.r);
    }
    const padL = 14.0, padR = 14.0, padT = 22.0, padB = 30.0;
    final s = math.min((size.width - padL - padR) / maxX, (size.height - padT - padB) / maxY);
    final ox = padL + ((size.width - padL - padR) - maxX * s) / 2;
    final oy = size.height - padB; // 바닥(y=0)의 화면 위치
    Offset p(double x, double y) => Offset(ox + x * s, oy - y * s);

    // 트레이: 바닥판과 양쪽 측판(금속 느낌의 그라데이션 + 그림자).
    final wall = math.max(3.0, 2.2 * s);
    final trayRect = Rect.fromPoints(p(0, depth), p(width, 0));
    canvas.drawRRect(
      RRect.fromRectAndRadius(trayRect.inflate(wall).shift(const Offset(2, 3)), const Radius.circular(3)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRect(trayRect, Paint()..color = bg);
    final metal = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFD7DDE2), Color(0xFF9AA5AE), Color(0xFF7D8993)],
      ).createShader(trayRect.inflate(wall));
    final u = Path()
      ..moveTo(trayRect.left - wall, trayRect.top - wall * 0.6)
      ..lineTo(trayRect.left - wall, trayRect.bottom + wall)
      ..lineTo(trayRect.right + wall, trayRect.bottom + wall)
      ..lineTo(trayRect.right + wall, trayRect.top - wall * 0.6)
      ..lineTo(trayRect.right, trayRect.top - wall * 0.6)
      ..lineTo(trayRect.right, trayRect.bottom)
      ..lineTo(trayRect.left, trayRect.bottom)
      ..lineTo(trayRect.left, trayRect.top - wall * 0.6)
      ..close();
    canvas.drawPath(u, metal);
    canvas.drawPath(u, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF5E6A73));
    // 사다리형·펀칭형·메시형은 바닥에 구멍(가로대 사이)이 보이게 점선.
    if (!isSolidTray(type)) {
      final hole = Paint()..color = bg;
      final y0 = trayRect.bottom + wall * 0.25, y1 = trayRect.bottom + wall * 0.75;
      for (var x = trayRect.left + 6; x < trayRect.right - 6; x += 14) {
        canvas.drawRect(Rect.fromLTRB(x, y0, math.min(x + 7, trayRect.right - 4), y1), hole);
      }
    }

    // 케이블: 시스(검정 계열 그라데이션) + 줄 색 테두리 + 하이라이트.
    for (final d in layout.dots) {
      final c = p(d.x, d.y);
      final r = d.r * s;
      final col = trayRowColor(d.row);
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawCircle(c + Offset(r * 0.08, r * 0.12), r, Paint()..color = Colors.black.withValues(alpha: 0.18));
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.4),
            colors: [Color.lerp(col, Colors.white, 0.35)!, col, Color.lerp(col, Colors.black, 0.35)!],
            stops: const [0, 0.55, 1],
          ).createShader(rect),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = d.over ? 2.2 : 0.8
          ..color = d.over ? const Color(0xFFE53935) : Colors.black.withValues(alpha: 0.35),
      );
      if (r >= 7) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${d.row + 1}',
            style: TextStyle(fontSize: math.min(12, r * 0.9), fontWeight: FontWeight.w900, color: Colors.white),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
      }
    }

    // 치수: 아래 폭, 왼쪽 위 깊이.
    void label(String t, Offset at, {Color? color, bool center = true}) {
      final tp = TextPainter(
        text: TextSpan(text: t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color ?? sub)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center ? at - Offset(tp.width / 2, 0) : at);
    }

    final dim = Paint()
      ..color = sub
      ..strokeWidth = 1;
    final yDim = oy + wall + 10;
    canvas.drawLine(Offset(trayRect.left, yDim), Offset(trayRect.right, yDim), dim);
    for (final x in [trayRect.left, trayRect.right]) {
      canvas.drawLine(Offset(x, yDim - 4), Offset(x, yDim + 4), dim);
    }
    label('폭 ${trayNum(width)}', Offset(trayRect.center.dx, yDim + 3));
    label('깊이 ${trayNum(depth)}', Offset(trayRect.left, trayRect.top - wall - 17), center: false);
    if (layout.hidden > 0) {
      label('+${layout.hidden}가닥 더 (그림 생략)', Offset(trayRect.right - 70, trayRect.top - wall - 17), color: text);
    }
  }

  @override
  bool shouldRepaint(TraySectionPainter o) =>
      o.type != type || o.width != width || o.depth != depth || o.layout != layout || o.bg != bg;
}
