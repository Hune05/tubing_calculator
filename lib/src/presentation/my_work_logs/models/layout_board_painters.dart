import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'layout_board_models.dart';

// 🚀 배치도 안내선(SmartGuidePainter)과 모눈(GridPainter) 그리기. 모바일·태블릿 화면이 함께 쓴다.
// 그린 그림은 test/layout_board_painters_test.dart 가 픽셀 단위로 지킨다.
const Color _guideCenterColor = Color(0xFF007580); // 가상선(센터): 파란색(틸)
const Color _edgeDimColor = Color(0xFFF68657); // 측면: 주황색
const Color _centerDimColor = Color(0xFF007580); // 센터: 파란색(틸)
const Color _diagonalDimColor = Color(0xFF8B5CF6); // 대각선: 보라색
// 도면 그림 색은 토큰으로 바꾸지 않는다(그림 비교 테스트가 윈도·리눅스 값을 따로 들고 있다).
const Color _warningRed = Color(0xFFF04438);
const Color _tossSubText = Color(0xFF5F6B78);
const Color _tossText = Color(0xFF191F28);

// 🚀 [핵심 해결] 측면 모드에서도 레이캐스트(Raycast) 물리 법칙 완벽 적용
class SmartGuidePainter extends CustomPainter {
  final PlacedItem item;
  final List<PlacedItem> allItems;
  final double panelWidth;
  final double panelHeight;
  final DimensionType currentType;

  /// 숫자 글씨·눈금 배율([dimensionMarkScale]). 줄여 볼 때 숫자가 읽히는 크기로 남게 한다.
  final double markScale;

  SmartGuidePainter({
    required this.item,
    required this.allItems,
    required this.panelWidth,
    required this.panelHeight,
    required this.currentType,
    this.markScale = 1,
  });

  // 네 방향 선을 모았다가 긴 것부터 그린다. 짧은 선(바짝 붙은 쪽)의 숫자는 자리가 없어
  // 비켜 적는데, 먼저 적힌 숫자와도 안 겹치게 하려고 나중에 그린다.
  final List<(Offset, Offset, double, Color, String)> _lines = [];

  void _drawGuideLine(
    Canvas canvas,
    Offset start,
    Offset end,
    double distance,
    Color color,
    String prefix,
  ) {
    _lines.add((start, end, distance, color, prefix));
  }

  void _flushLines(Canvas canvas) {
    final List<Rect> avoid = [
      item.position & Size(item.width, item.height),
      for (final o in allItems)
        if (o.id != item.id) o.position & Size(o.width, o.height),
    ];
    // 제자리(선 옆 가운데)에 들어가는 숫자를 먼저, 비켜야 하는 숫자를 나중에.
    bool fits((Offset, Offset, double, Color, String) l) =>
        cadLabelFitsOnLine(l.$1, l.$2, l.$3, l.$5, scale: markScale);
    _lines.sort((a, b) {
      final int fa = fits(a) ? 0 : 1, fb = fits(b) ? 0 : 1;
      return fa != fb ? fa - fb : b.$3.compareTo(a.$3);
    });
    for (final (start, end, distance, color, prefix) in _lines) {
      final Rect? placed = drawCadDimensionLine(
        canvas,
        start,
        end,
        distance,
        color,
        prefix,
        avoid: avoid,
        bounds: Offset.zero & Size(panelWidth, panelHeight),
        scale: markScale,
      );
      if (placed != null) avoid.add(placed);
    }
    _lines.clear();
  }

  @override
  void paint(Canvas canvas, Size size) {
    _lines.clear();
    Color c = currentType == DimensionType.center
        ? _guideCenterColor
        : _edgeDimColor;
    String p = currentType == DimensionType.center ? "센터" : "측면";

    double cx = item.center.dx, cy = item.center.dy;
    double left = item.position.dx, right = item.position.dx + item.width;
    double top = item.position.dy, bottom = item.position.dy + item.height;

    double bL = 0, bR = panelWidth, bT = 0, bB = panelHeight;

    for (var other in allItems) {
      if (other.id == item.id) continue;

      double oLeft = other.position.dx,
          oRight = other.position.dx + other.width;
      double oTop = other.position.dy,
          oBottom = other.position.dy + other.height;

      bool hitVerticalRay = (cx >= oLeft) && (cx <= oRight);
      if (hitVerticalRay) {
        if (currentType == DimensionType.center) {
          if (other.center.dy <= cy && other.center.dy > bT) {
            bT = other.center.dy;
          }
          if (other.center.dy >= cy && other.center.dy < bB) {
            bB = other.center.dy;
          }
        } else {
          if (oBottom <= top && oBottom > bT) bT = oBottom;
          if (oTop >= bottom && oTop < bB) bB = oTop;
        }
      }

      bool hitHorizontalRay = (cy >= oTop) && (cy <= oBottom);
      if (hitHorizontalRay) {
        if (currentType == DimensionType.center) {
          if (other.center.dx <= cx && other.center.dx > bL) {
            bL = other.center.dx;
          }
          if (other.center.dx >= cx && other.center.dx < bR) {
            bR = other.center.dx;
          }
        } else {
          if (oRight <= left && oRight > bL) bL = oRight;
          if (oLeft >= right && oLeft < bR) bR = oLeft;
        }
      }
    }

    if (currentType == DimensionType.center) {
      _drawGuideLine(
        canvas,
        Offset(cx, cy),
        Offset(cx, bT),
        (cy - bT).abs(),
        c,
        p,
      );
      _drawGuideLine(
        canvas,
        Offset(cx, cy),
        Offset(cx, bB),
        (bB - cy).abs(),
        c,
        p,
      );
      _drawGuideLine(
        canvas,
        Offset(cx, cy),
        Offset(bL, cy),
        (cx - bL).abs(),
        c,
        p,
      );
      _drawGuideLine(
        canvas,
        Offset(cx, cy),
        Offset(bR, cy),
        (bR - cx).abs(),
        c,
        p,
      );
    } else {
      _drawGuideLine(
        canvas,
        Offset(cx, top),
        Offset(cx, bT),
        (top - bT).abs(),
        c,
        p,
      );
      _drawGuideLine(
        canvas,
        Offset(cx, bottom),
        Offset(cx, bB),
        (bB - bottom).abs(),
        c,
        p,
      );
      _drawGuideLine(
        canvas,
        Offset(left, cy),
        Offset(bL, cy),
        (left - bL).abs(),
        c,
        p,
      );
      _drawGuideLine(
        canvas,
        Offset(right, cy),
        Offset(bR, cy),
        (bR - right).abs(),
        c,
        p,
      );
    }
    _flushLines(canvas);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GridPainter extends CustomPainter {
  final double gridSize;
  GridPainter({required this.gridSize});

  @override
  void paint(Canvas canvas, Size size) {
    final lightPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 0.5;
    final boldPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.2;

    for (double i = 0; i <= size.width; i += gridSize) {
      bool isMajor = (i % (gridSize * 5) == 0);
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        isMajor ? boldPaint : lightPaint,
      );
    }
    for (double i = 0; i <= size.height; i += gridSize) {
      bool isMajor = (i % (gridSize * 5) == 0);
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        isMajor ? boldPaint : lightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 치수 숫자 글. 잘라 버리면 부동소수 오차로 300이 299로 보여 반올림한다(10-08).
String cadDimensionLabel(String prefix, double distance) =>
    "$prefix ${distance.round()} mm";

/// 치수 숫자 칸이 선 옆 가운데(제자리)에 들어가는지. [drawCadDimensionLine]과 같은 셈.
bool cadLabelFitsOnLine(
  Offset start,
  Offset end,
  double distance,
  String prefix, {
  double scale = 1,
}) {
  final double len = (end - start).distance;
  if (len == 0) return true;
  final tp = TextPainter(
    text: TextSpan(
      text: cadDimensionLabel(prefix, distance),
      style: TextStyle(fontSize: 10 * scale, fontWeight: FontWeight.w800),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final double ux = (end.dx - start.dx) / len, uy = (end.dy - start.dy) / len;
  final double along =
      ux.abs() * (tp.width + 10 * scale) + uy.abs() * (tp.height + 6 * scale);
  return along + 8 * scale <= len;
}

// 🚀 [수정] 산업 도면(CAD)처럼 얇은 치수선 + 끝단 눈금 + 항상 보이는
// 라벨로 통일. 예전엔 두꺼운 색상 알약(pill) 라벨이 10mm 미만
// 거리에서는 아예 안 보였는데, 라벨을 선 옆으로 살짝 띄워서 거리와
// 무관하게 항상 표시되게 한다.
/// [scale]은 숫자 글씨·눈금·칸 여백·선 굵기 배율([dimensionMarkScale]).
Rect? drawCadDimensionLine(
  Canvas canvas,
  Offset start,
  Offset end,
  double distance,
  Color color,
  String prefix, {
  double strokeWidth = 1.3,
  List<Rect> avoid = const [],
  Rect? bounds,
  double scale = 1,
  bool onLine = false,
  TextSpan? span,
}) {
  strokeWidth *= scale;
  if (distance < 1) return null; // 사실상 붙어있으면 표시할 게 없음

  final linePaint = Paint()
    ..color = color
    ..strokeWidth = strokeWidth
    ..style = PaintingStyle.stroke;
  canvas.drawLine(start, end, linePaint);

  final dx = end.dx - start.dx;
  final dy = end.dy - start.dy;
  final len = math.sqrt(dx * dx + dy * dy);
  final double px = len == 0 ? 0 : -dy / len;
  final double py = len == 0 ? 0 : dx / len;

  // 끝단 눈금(CAD 치수선의 tick mark)
  final tick = Offset(px, py) * 5 * scale;
  canvas.drawLine(start - tick, start + tick, linePaint);
  canvas.drawLine(end - tick, end + tick, linePaint);

  final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);

  final textSpan = TextSpan(
    text: span == null ? cadDimensionLabel(prefix, distance) : null,
    children: span == null ? null : [span],
    style: TextStyle(
      color: color,
      fontSize: 10 * scale,
      fontWeight: FontWeight.w800,
    ),
  );
  final textPainter = TextPainter(
    text: textSpan,
    textDirection: TextDirection.ltr,
  )..layout();

  // 숫자 칸이 선 길이보다 길면(부품이 벽·옆 부품에 바짝 붙었을 때) 선 옆 가운데에 두면
  // 부품을 가린다. 그때는 [bounds](도면) 안에서 [avoid](움직이는 부품·옆 부품)와 안 겹치는 자리를
  // 찾아 적는다: 끝점 너머 → 부품 위·아래(또는 옆)로 비켜서.
  final double ux = len == 0 ? 0 : dx / len, uy = len == 0 ? 0 : dy / len;
  final Size box = Size(
    textPainter.width + 10 * scale,
    textPainter.height + 6 * scale,
  );
  final double along = ux.abs() * box.width + uy.abs() * box.height;
  Rect boxAt(Offset c) =>
      Rect.fromCenter(center: c, width: box.width, height: box.height);
  Offset keepIn(Offset c) {
    final b = bounds;
    if (b == null) return c;
    final r = boxAt(c);
    double sx = 0, sy = 0;
    if (r.left < b.left) sx = b.left - r.left;
    if (r.right > b.right) sx = b.right - r.right;
    if (r.top < b.top) sy = b.top - r.top;
    if (r.bottom > b.bottom) sy = b.bottom - r.bottom;
    return c + Offset(sx, sy);
  }

  bool fits(Offset c) {
    final r = boxAt(c);
    if (bounds != null &&
        (r.left < bounds.left - 0.5 ||
            r.right > bounds.right + 0.5 ||
            r.top < bounds.top - 0.5 ||
            r.bottom > bounds.bottom + 0.5)) {
      return false;
    }
    return !avoid.any(r.overlaps);
  }

  // 10-16 [onLine]: 도면처럼 숫자를 선 위 가운데에 얹는다(세로 선은 글자를 세워서). 겹 치수가
  // 한 칸씩 붙어 쌓여도 숫자 칸이 옆 줄로 넘어가지 않는다. 선이 숫자보다 짧으면 아래 예전 방식.
  if (onLine && along + 8 * scale <= len) {
    final bool vertical = ux.abs() < 0.01;
    final Rect r = vertical
        ? Rect.fromCenter(center: mid, width: box.height, height: box.width)
        : Rect.fromCenter(center: mid, width: box.width, height: box.height);
    final rr = RRect.fromRectAndRadius(r, Radius.circular(4 * scale));
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawRRect(
      rr,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale,
    );
    canvas.save();
    canvas.translate(mid.dx, mid.dy);
    if (vertical) canvas.rotate(-math.pi / 2);
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
    canvas.restore();
    return r;
  }

  // 도면 가장자리 근처면 칸이 도면 밖으로 삐져 잘린다. 도면 안으로 당겨 넣는다.
  Offset label = keepIn(mid + Offset(px, py) * 15 * scale);
  Offset anchor = mid;
  if (along + 8 * scale > len) {
    final candidates = <Offset>[
      end + Offset(ux, uy) * (along / 2 + 8 * scale),
      for (double k = 15 * scale; k <= (15 + 2000) * scale; k += 5 * scale) ...[
        keepIn(mid + Offset(px, py) * k),
        keepIn(mid - Offset(px, py) * k),
      ],
    ];
    for (final c in candidates) {
      if (fits(c)) {
        label = c;
        break;
      }
    }
    if (label == candidates.first) anchor = end;
  }

  final bgRect = RRect.fromRectAndRadius(
    boxAt(label),
    Radius.circular(4 * scale),
  );
  // 라벨-치수선 연결용 짧은 리더선
  // 리더선은 숫자 칸의 가장 가까운 테두리까지만(가운데로 그으면 비킨 칸일 때 부품을 가로지른다).
  final Rect labelBox = boxAt(label);
  canvas.drawLine(
    anchor,
    Offset(
      anchor.dx.clamp(labelBox.left, labelBox.right),
      anchor.dy.clamp(labelBox.top, labelBox.bottom),
    ),
    Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = scale,
  );
  canvas.drawRRect(bgRect, Paint()..color = const Color(0xFFFFFFFF));
  canvas.drawRRect(
    bgRect,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = scale,
  );
  textPainter.paint(
    canvas,
    Offset(label.dx - textPainter.width / 2, label.dy - textPainter.height / 2),
  );
  return labelBox;
}

/// 부품을 피해 그리는 선(10-16): [a]→[b] 중 [rects](각각 [pad]만큼 키움) 안에 드는 구간은 끊고 나머지만.
/// 캐드처럼 보조선이 부품 테두리 앞에서 멈추고 다른 부품 위를 지나가지 않게 한다.
void drawLineAround(
  Canvas canvas,
  Offset a,
  Offset b,
  Paint paint,
  List<Rect> rects, {
  double pad = 0,
}) {
  final Offset d = b - a;
  if (d.distance < 0.5) return;
  final cuts = <(double, double)>[];
  for (final r0 in rects) {
    final r = r0.inflate(pad);
    double t0 = 0, t1 = 1;
    bool hit = true;
    for (final (p, lo, hi) in [
      (d.dx, r.left - a.dx, r.right - a.dx),
      (d.dy, r.top - a.dy, r.bottom - a.dy),
    ]) {
      if (p.abs() < 1e-9) {
        if (lo > 0 || hi < 0) hit = false;
      } else {
        double e0 = lo / p, e1 = hi / p;
        if (e0 > e1) (e0, e1) = (e1, e0);
        t0 = math.max(t0, e0);
        t1 = math.min(t1, e1);
      }
    }
    if (hit && t0 < t1) cuts.add((t0, t1));
  }
  cuts.sort((x, y) => x.$1.compareTo(y.$1));
  double t = 0;
  final double minT = 0.5 / d.distance;
  for (final (c0, c1) in cuts) {
    if (c0 - t > minT) canvas.drawLine(a + d * t, a + d * c0, paint);
    t = math.max(t, c1);
  }
  if (1 - t > minT) canvas.drawLine(a + d * t, b, paint);
}

/// 센터 표시(10-16): 부품 가운데 작은 십자. 치수가 센터를 잰다는 것만 보이고 선은 부품을 지나지 않는다.
void drawCenterMark(Canvas canvas, Offset c, double scale) {
  final p = Paint()
    ..color = const Color(0xFF8A949E)
    ..strokeWidth = 0.8 * scale;
  final double r = 4 * scale;
  canvas.drawLine(c - Offset(r, 0), c + Offset(r, 0), p);
  canvas.drawLine(c - Offset(0, r), c + Offset(0, r), p);
}

/// 캐드식 치수 하나(10-16): 원래 점에서 치수선까지 보조선(조금 띄우고 조금 넘게), 치수선 양끝 화살표,
/// 숫자는 상자 없이 선 위(세로 선은 세워서 왼쪽)에. 선이 짧으면 화살표는 바깥에서 안쪽으로.
void drawCadStyleDimension(
  Canvas canvas,
  DimensionLane l,
  String text,
  Color color, {
  double scale = 1,
  List<Rect> obstacles = const [],
}) {
  final ext = Paint()
    ..color = const Color(0xFF8A949E)
    ..strokeWidth = 0.8 * scale;
  for (final (o, p) in [(l.origin1, l.p1), (l.origin2, l.p2)]) {
    final Offset dv = p - o;
    final double len = dv.distance;
    if (len < 0.5) continue;
    final Offset u = dv / len;
    // 보조선은 부품 테두리 조금 앞에서 시작하고, 지나는 다른 부품 위에서는 끊는다.
    drawLineAround(
      canvas,
      o + u * (2 * scale),
      p + u * (3 * scale),
      ext,
      obstacles,
      pad: 2 * scale,
    );
    if (obstacles.any((r) => r.width > 0 && r.deflate(0.5).contains(o))) {
      drawCenterMark(canvas, o, scale);
    }
  }
  final line = Paint()
    ..color = color
    ..strokeWidth = 1.0 * scale;
  final Offset d = l.p2 - l.p1;
  final double len = d.distance;
  if (len < 0.5) return;
  final Offset u = d / len;
  final Offset n = Offset(-u.dy, u.dx);
  final double a = 6 * scale, w = 2.2 * scale;
  final bool inside = len >= a * 2.6;
  canvas.drawLine(l.p1, l.p2, line);
  void arrow(Offset tip, Offset dir) {
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((tip - dir * a + n * w).dx, (tip - dir * a + n * w).dy)
      ..lineTo((tip - dir * a - n * w).dx, (tip - dir * a - n * w).dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  if (inside) {
    arrow(l.p1, -u);
    arrow(l.p2, u);
  } else {
    // 짧은 선: 바깥에서 안쪽으로 화살표, 선을 조금 늘려 그린다.
    canvas.drawLine(l.p1 - u * (a * 1.6), l.p1, line);
    canvas.drawLine(l.p2, l.p2 + u * (a * 1.6), line);
    arrow(l.p1, u);
    arrow(l.p2, -u);
  }
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: 11 * scale,
        fontWeight: FontWeight.w700,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final bool vertical = u.dx.abs() < 0.01;
  final Offset mid = (l.p1 + l.p2) / 2;
  // 숫자가 선보다 길면 끝 너머에
  final bool fits = tp.width + 6 * scale <= len;
  final Offset at = fits ? mid : l.p2 + u * (tp.width / 2 + a * 2);
  canvas.save();
  canvas.translate(at.dx, at.dy);
  if (vertical) canvas.rotate(-math.pi / 2);
  // 선 위(세로는 세운 뒤 위 = 화면 왼쪽)에 얹는다. 보조선이 지나가도 읽히게 옅은 흰 바탕.
  final Rect r = Rect.fromLTWH(
    -tp.width / 2 - 2 * scale,
    -tp.height - 2 * scale,
    tp.width + 4 * scale,
    tp.height + 1 * scale,
  );
  canvas.drawRect(r, Paint()..color = const Color(0xD9FFFFFF));
  tp.paint(canvas, Offset(-tp.width / 2, -tp.height - 1.5 * scale));
  canvas.restore();
}

/// 좌표 치수(10-16): 위·왼쪽 벽을 0으로, 부품 센터까지 거리. 세로 값은 왼쪽 벽 안쪽에, 가로 값은 위 벽 안쪽에
/// 세워서 적고, 부품 센터까지 옅은 보조선. 값끼리 붙으면 비켜 적고 꺾은 보조선으로 잇는다.
void drawOrdinateDimensions(
  Canvas canvas,
  List<PlacedItem> items, {
  required double panelWidth,
  required double panelHeight,
  double scale = 1,
  Color color = const Color(0xFF2F3A40),
}) {
  final v = ordinateValues(items);
  final obstacles = dimObstacles(items);
  for (final (_, pts) in v.xs) {
    for (final c in pts) {
      drawCenterMark(canvas, c, scale);
    }
  }
  final lead = Paint()
    ..color = const Color(0x80697480)
    ..strokeWidth = 0.8 * scale;
  TextPainter label(String t) => TextPainter(
    text: TextSpan(
      text: t,
      style: TextStyle(
        color: color,
        fontSize: 10.5 * scale,
        fontWeight: FontWeight.w700,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final bg = Paint()..color = const Color(0xE6FFFFFF);
  // 0 표시(위·왼쪽 구석)
  final zero = label('0');
  canvas.drawRect(
    Rect.fromLTWH(1 * scale, 1 * scale, zero.width + 4 * scale, zero.height),
    bg,
  );
  zero.paint(canvas, Offset(3 * scale, 1 * scale));

  // 세로 값(왼쪽 벽 쪽): 위에서 아래로, 붙으면 아래로 비킨다.
  double lastBottom = zero.height + 3 * scale;
  for (final (y, pts) in v.ys) {
    final tp = label('${y.round()}');
    double top = y - tp.height / 2;
    if (top < lastBottom + 1 * scale) top = lastBottom + 1 * scale;
    lastBottom = top + tp.height;
    final double labelY = top + tp.height / 2;
    final double right = 3 * scale + tp.width + 3 * scale;
    final double tx = pts.map((p) => p.dx).reduce(math.min);
    // 보조선: 값 칸 → (꺾임) → 가장 왼쪽 부품 센터
    canvas.drawLine(Offset(right, labelY), Offset(right + 4 * scale, y), lead);
    drawLineAround(
      canvas,
      Offset(right + 4 * scale, y),
      Offset(tx, y),
      lead,
      obstacles,
      pad: 2 * scale,
    );
    canvas.drawRect(
      Rect.fromLTWH(1 * scale, top, tp.width + 4 * scale, tp.height),
      bg,
    );
    tp.paint(canvas, Offset(3 * scale, top));
  }
  // 가로 값(위 벽 쪽): 세워서, 왼쪽에서 오른쪽으로.
  double lastRight = zero.width + 6 * scale;
  for (final (x, pts) in v.xs) {
    final tp = label('${x.round()}');
    // 세운 글자의 화면 폭 = 글 높이
    double left = x - tp.height / 2;
    if (left < lastRight + 1 * scale) left = lastRight + 1 * scale;
    lastRight = left + tp.height;
    final double labelX = left + tp.height / 2;
    final double bottom = 3 * scale + tp.width + 3 * scale;
    final double ty = pts.map((p) => p.dy).reduce(math.min);
    canvas.drawLine(
      Offset(labelX, bottom),
      Offset(x, bottom + 4 * scale),
      lead,
    );
    drawLineAround(
      canvas,
      Offset(x, bottom + 4 * scale),
      Offset(x, ty),
      lead,
      obstacles,
      pad: 2 * scale,
    );
    canvas.save();
    canvas.translate(labelX, 3 * scale + tp.width / 2);
    canvas.rotate(-math.pi / 2);
    canvas.drawRect(
      Rect.fromLTWH(
        -tp.width / 2 - 2 * scale,
        -tp.height / 2,
        tp.width + 4 * scale,
        tp.height,
      ),
      bg,
    );
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }
}

// 🚀 치수선 그리기. panelWidth/panelHeight 는 모바일 화면만 넘기며 다시 그릴지 판단할 때만 쓴다.
class DimensionPainter extends CustomPainter {
  final List<PlacedDimension> dimensions;
  final MeasurePoint? activePoint;
  final double panelWidth;
  final double panelHeight;
  // 🚀 [신규] dimensions 리스트는 계속 같은 객체를 그 자리에서 바꿔쓰기
  // 때문에(add/remove 제외) 기준/메모/최소 간격만 바뀌었을 땐 길이 비교로
  // 감지가 안 된다. 그런 변경이 있을 때마다 이 값을 1씩 올려서 확실히
  // 다시 그려지게 한다.
  final int version;

  /// 숫자 글씨·번호·눈금 배율([dimensionMarkScale]).
  final double markScale;

  /// 지금 보는 부품(10-16). 주면 그 부품에서 나간 치수만 진하게, 나머지는 옅게.
  final String? focusId;

  /// 치수 모양(10-16): app·cad·ordinate([kDimStyles]). 좌표는 [items]로 그린다(찍은 치수는 숨김).
  final String style;
  final List<PlacedItem> items;

  DimensionPainter({
    required this.dimensions,
    this.activePoint,
    this.panelWidth = 0,
    this.panelHeight = 0,
    this.version = 0,
    this.markScale = 1,
    this.focusId,
    this.style = 'app',
    this.items = const [],
  });

  /// 겹 치수 한 칸 간격(도면 mm). 숫자 글씨 높이보다 넉넉하게.
  static double laneGap(double markScale) => 22 * markScale;

  @override
  void paint(Canvas canvas, Size size) {
    if (style == 'ordinate') {
      drawOrdinateDimensions(
        canvas,
        items,
        panelWidth: panelWidth,
        panelHeight: panelHeight,
        scale: markScale,
      );
      _paintActivePoint(canvas);
      return;
    }
    // 10-16: 같은 줄 위에서 겹치는 치수는 짧은 것부터 한 칸씩 바깥으로 띄워 그린다(캐드식은 부품 밖으로).
    final List<Rect> cadObstacles = style == 'cad'
        ? dimObstacles(items)
        : const [];
    final lanes = style == 'cad'
        ? layoutCadDimensionLanes(
            dimensions,
            gap: laneGap(markScale),
            panelWidth: panelWidth,
            panelHeight: panelHeight,
            obstacles: cadObstacles,
          )
        : layoutDimensionLanes(dimensions, gap: laneGap(markScale));
    final bool focusHasDims =
        focusId != null &&
        dimensions.any((d) => d.p1.id == focusId || d.p2.id == focusId);
    for (int i = 0; i < dimensions.length; i++) {
      final dim = dimensions[i];
      final DimensionLane lane = lanes[dim.id]!;
      final endpoints = (p1: lane.p1, p2: lane.p2, distance: lane.distance);
      // 지금 보는 부품과 상관없는 치수는 옅게(그 부품에 치수가 있을 때만).
      final bool faded =
          focusHasDims && dim.p1.id != focusId && dim.p2.id != focusId;
      if (faded) {
        canvas.saveLayer(null, Paint()..color = const Color(0x2E000000));
      }
      // 띄운 치수: 원래 점에서 띄운 선까지 옅은 점선(보조선).
      if (lane.shifted && style != 'cad') {
        final ext = Paint()
          ..color = const Color(0xFF9AA3AC)
          ..strokeWidth = 0.9 * markScale;
        for (final (a, b) in [
          (lane.origin1, lane.p1),
          (lane.origin2, lane.p2),
        ]) {
          final Offset dv = b - a;
          final double len = dv.distance;
          if (len < 0.5) continue;
          final Offset u = dv / len;
          final double dash = 4 * markScale, gapLen = 3 * markScale;
          for (double t = 0; t < len; t += dash + gapLen) {
            canvas.drawLine(a + u * t, a + u * math.min(t + dash, len), ext);
          }
        }
      }

      Color dColor = dim.type == DimensionType.center
          ? _centerDimColor
          : _edgeDimColor;
      // 10-16: 숫자 칸을 짧게 — "센터"·"측면"은 색으로 이미 구분되고 도면 단위는 mm라 뺀다.
      // 번호는 부품 위 동그라미 대신 칸 안 앞에 작게(동그라미가 부품 이름을 덮었다).
      String labelPrefix = "";

      // 🚀 [신규] 대각선 모드면 축 기준 대신 실제 각도를 라벨에 표시한다.
      if (dim.isDiagonal) {
        dColor = _diagonalDimColor;
        final double angleDeg =
            math.atan2(
              endpoints.p2.dy - endpoints.p1.dy,
              endpoints.p2.dx - endpoints.p1.dx,
            ) *
            180 /
            math.pi;
        final double normalized = angleDeg < 0 ? angleDeg + 360 : angleDeg;
        labelPrefix = "대각 ${normalized.toInt()}° ";
      }

      // 🚀 [신규] 안전 이격거리처럼 규정과 관련된 치수는 굵은 선 +
      // 방패 아이콘 표시로 다른 치수와 구분되게 한다.
      if (dim.isSafetyCritical) {
        labelPrefix = "🛡 $labelPrefix";
      }

      // 🚀 [신규] 최소 유지 간격을 설정해뒀는데 현재 거리가 그보다
      // 좁아지면(모듈을 옮기다가 실시간으로) 경고색으로 바뀌어 즉시
      // 눈에 띄게 한다(가장 시급한 정보이므로 다른 라벨보다 우선).
      final bool violatesMinGap =
          dim.minGapMm != null && endpoints.distance < dim.minGapMm!;
      if (violatesMinGap) {
        dColor = _warningRed;
        labelPrefix = "⚠ 최소 ${dim.minGapMm!.toInt()} 미달 ";
      }

      if (style == 'cad' && !dim.isDiagonal) {
        drawCadStyleDimension(
          canvas,
          lane,
          "$labelPrefix${endpoints.distance.round()}",
          dColor,
          scale: markScale,
          obstacles: cadObstacles,
        );
      } else {
        drawCadDimensionLine(
          canvas,
          endpoints.p1,
          endpoints.p2,
          endpoints.distance,
          dColor,
          labelPrefix,
          strokeWidth: dim.isSafetyCritical ? 2.4 : 1.3,
          bounds: panelWidth > 0 && panelHeight > 0
              ? Offset.zero & Size(panelWidth, panelHeight)
              : null,
          scale: markScale,
          onLine: true,
          span: TextSpan(
            children: [
              TextSpan(
                text: "${i + 1}  ",
                style: TextStyle(
                  fontSize: 8 * markScale,
                  fontWeight: FontWeight.w700,
                  color: dColor.withValues(alpha: 0.6),
                ),
              ),
              TextSpan(text: "$labelPrefix${endpoints.distance.round()}"),
            ],
          ),
        );
      }

      // 메모는 치수 글자와 겹치지 않게 선의 반대쪽에 그린다
      // (치수 글자는 drawCadDimensionLine이 선 한쪽으로 15 띄워 그린다).
      if (dim.note != null && dim.note!.trim().isNotEmpty) {
        final Offset mid = Offset(
          (endpoints.p1.dx + endpoints.p2.dx) / 2,
          (endpoints.p1.dy + endpoints.p2.dy) / 2,
        );
        final double ddx = endpoints.p2.dx - endpoints.p1.dx;
        final double ddy = endpoints.p2.dy - endpoints.p1.dy;
        final double dlen = math.sqrt(ddx * ddx + ddy * ddy);
        final Offset away = dlen == 0
            ? const Offset(0, -1)
            : Offset(ddy / dlen, -ddx / dlen);
        final noteSpan = TextSpan(
          text: dim.note,
          style: TextStyle(
            color: _tossSubText,
            fontSize: 9 * markScale,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
          ),
        );
        final notePainter = TextPainter(
          text: noteSpan,
          textDirection: TextDirection.ltr,
        )..layout();
        // 캐드식은 숫자가 늘 선 위(세로는 왼쪽)에 있으니 메모는 아래(세로는 오른쪽)에.
        final bool cadSide = style == 'cad' && !dim.isDiagonal;
        final Offset noteCenter = cadSide
            ? mid +
                  (ddx.abs() >= ddy.abs()
                      ? Offset(0, 9 * markScale)
                      : Offset(9 * markScale + notePainter.width / 2, 0))
            : mid + away * 15 * markScale;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: noteCenter,
              width: notePainter.width + 8 * markScale,
              height: notePainter.height + 4 * markScale,
            ),
            Radius.circular(3 * markScale),
          ),
          Paint()..color = const Color(0xE6FFFFFF),
        );
        notePainter.paint(
          canvas,
          Offset(
            noteCenter.dx - notePainter.width / 2,
            noteCenter.dy - notePainter.height / 2,
          ),
        );
      }
      if (faded) canvas.restore();
    }

    // 🚀 [개선] 예전엔 벽 기준점(WallPoint)일 때만 대기 중 표시를 그려서,
    // 모듈을 첫 지점으로 찍었을 땐 "측정 대기 중"이라는 표시가 전혀
    // 없었다. 그래서 다음 터치가 바로 두 번째 지점으로 이어져 치수가
    // 생기는 게 예상치 못하게 느껴졌다. 이제 첫 지점 종류와 상관없이
    // 항상 표시해서 측정이 진행 중임을 분명히 보여준다.
    _paintActivePoint(canvas);
  }

  // 🚀 [최적화] 예전엔 무조건 true라 모듈을 드래그해서 setState가 호출될
  // 때마다(프레임마다) 치수선과 무관한데도 이 레이어 전체가 매번 다시
  // 그려졌음(버벅임의 실제 원인). dimensions는 같은 List를 in-place로
  // add/remove하므로 참조 비교 대신 길이로, 나머지는 값이 바뀔 때 항상
  // 재할당되므로 값 비교로 실제 변경 여부를 판단한다.
  void _paintActivePoint(Canvas canvas) {
    if (activePoint != null) {
      canvas.drawCircle(
        activePoint!.center,
        6 * markScale,
        Paint()..color = _tossText,
      );
      canvas.drawCircle(
        activePoint!.center,
        16 * markScale,
        Paint()
          ..color = _tossText.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DimensionPainter oldDelegate) {
    return oldDelegate.dimensions.length != dimensions.length ||
        oldDelegate.activePoint != activePoint ||
        oldDelegate.panelWidth != panelWidth ||
        oldDelegate.panelHeight != panelHeight ||
        oldDelegate.markScale != markScale ||
        oldDelegate.version != version ||
        oldDelegate.focusId != focusId ||
        oldDelegate.style != style ||
        oldDelegate.items.length != items.length;
  }
}

/// 치수 숫자 배율. 숫자는 도면 mm로 10mm 크기라, 화면에 맞춰 줄여 보면(스키드 0.13배 안팎)
/// 화면에서 1~2px로 작아져 크게 확대해야만 읽혔다. 줄여 볼 때는 화면에서 11px(보통 작은
/// 글씨) 아래로 작아지지 않게 키우고, 1.1배 넘게 확대하면 원래 크기(1)로 둔다.
double dimensionMarkScale(double zoom) =>
    zoom <= 0 ? 1 : (1.1 / zoom).clamp(1.0, 12.0);
