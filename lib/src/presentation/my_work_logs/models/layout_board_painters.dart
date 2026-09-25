import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'layout_board_models.dart';

// 🚀 배치도 안내선(SmartGuidePainter)과 모눈(GridPainter) 그리기. 모바일·태블릿 화면이 함께 쓴다.
// 그린 그림은 test/layout_board_painters_test.dart 가 픽셀 단위로 지킨다.
const Color _guideCenterColor = Color(0xFF007580); // 가상선(센터): 파란색(틸)
const Color _edgeDimColor = Color(0xFFF68657); // 측면: 주황색
const Color _centerDimColor = Color(0xFF007580); // 센터: 파란색(틸)
const Color _diagonalDimColor = Color(0xFF8B5CF6); // 대각선: 보라색
const Color _warningRed = Color(0xFFF04438);
const Color _pureWhite = Color(0xFFFFFFFF);
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
      text: "$prefix ${distance.toInt()} mm",
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
    text: "$prefix ${distance.toInt()} mm",
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

  DimensionPainter({
    required this.dimensions,
    this.activePoint,
    this.panelWidth = 0,
    this.panelHeight = 0,
    this.version = 0,
    this.markScale = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < dimensions.length; i++) {
      final dim = dimensions[i];
      final endpoints = computeDimensionEndpoints(dim);

      Color dColor = dim.type == DimensionType.center
          ? _centerDimColor
          : _edgeDimColor;
      String labelPrefix = dim.type == DimensionType.center ? "센터" : "측면";

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
        labelPrefix = "대각 ${normalized.toInt()}°";
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
        labelPrefix = "⚠ 최소 ${dim.minGapMm!.toInt()}mm 미달";
      }

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
      );

      // 🚀 [신규] 치수선마다 번호 배지를 달아서, 도면이 복잡해져도
      // 사진/PDF로 내보낸 치수 목록표와 대조해볼 수 있게 한다.
      final Offset badgeCenter = endpoints.p1;
      canvas.drawCircle(badgeCenter, 8 * markScale, Paint()..color = dColor);
      final numberSpan = TextSpan(
        text: "${i + 1}",
        style: TextStyle(
          color: _pureWhite,
          fontSize: 9 * markScale,
          fontWeight: FontWeight.w800,
        ),
      );
      final numberPainter = TextPainter(
        text: numberSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      numberPainter.paint(
        canvas,
        Offset(
          badgeCenter.dx - numberPainter.width / 2,
          badgeCenter.dy - numberPainter.height / 2,
        ),
      );

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
        final Offset noteCenter = mid + away * 15 * markScale;
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
    }

    // 🚀 [개선] 예전엔 벽 기준점(WallPoint)일 때만 대기 중 표시를 그려서,
    // 모듈을 첫 지점으로 찍었을 땐 "측정 대기 중"이라는 표시가 전혀
    // 없었다. 그래서 다음 터치가 바로 두 번째 지점으로 이어져 치수가
    // 생기는 게 예상치 못하게 느껴졌다. 이제 첫 지점 종류와 상관없이
    // 항상 표시해서 측정이 진행 중임을 분명히 보여준다.
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

  // 🚀 [최적화] 예전엔 무조건 true라 모듈을 드래그해서 setState가 호출될
  // 때마다(프레임마다) 치수선과 무관한데도 이 레이어 전체가 매번 다시
  // 그려졌음(버벅임의 실제 원인). dimensions는 같은 List를 in-place로
  // add/remove하므로 참조 비교 대신 길이로, 나머지는 값이 바뀔 때 항상
  // 재할당되므로 값 비교로 실제 변경 여부를 판단한다.
  @override
  bool shouldRepaint(covariant DimensionPainter oldDelegate) {
    return oldDelegate.dimensions.length != dimensions.length ||
        oldDelegate.activePoint != activePoint ||
        oldDelegate.panelWidth != panelWidth ||
        oldDelegate.panelHeight != panelHeight ||
        oldDelegate.markScale != markScale ||
        oldDelegate.version != version;
  }
}

/// 치수 숫자 배율. 숫자는 도면 mm로 10mm 크기라, 화면에 맞춰 줄여 보면(스키드 0.13배 안팎)
/// 화면에서 1~2px로 작아져 크게 확대해야만 읽혔다. 줄여 볼 때는 화면에서 11px(보통 작은
/// 글씨) 아래로 작아지지 않게 키우고, 1.1배 넘게 확대하면 원래 크기(1)로 둔다.
double dimensionMarkScale(double zoom) =>
    zoom <= 0 ? 1 : (1.1 / zoom).clamp(1.0, 12.0);
