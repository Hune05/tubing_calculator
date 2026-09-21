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
const Color _tossSubText = Color(0xFF8B95A1);
const Color _tossText = Color(0xFF191F28);

// 🚀 [핵심 해결] 측면 모드에서도 레이캐스트(Raycast) 물리 법칙 완벽 적용
class SmartGuidePainter extends CustomPainter {
  final PlacedItem item;
  final List<PlacedItem> allItems;
  final double panelWidth;
  final double panelHeight;
  final DimensionType currentType;

  SmartGuidePainter({
    required this.item,
    required this.allItems,
    required this.panelWidth,
    required this.panelHeight,
    required this.currentType,
  });

  void _drawGuideLine(
    Canvas canvas,
    Offset start,
    Offset end,
    double distance,
    Color color,
    String prefix,
  ) {
    drawCadDimensionLine(canvas, start, end, distance, color, prefix);
  }

  @override
  void paint(Canvas canvas, Size size) {
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

// 🚀 [수정] 산업 도면(CAD)처럼 얇은 치수선 + 끝단 눈금 + 항상 보이는
// 라벨로 통일. 예전엔 두꺼운 색상 알약(pill) 라벨이 10mm 미만
// 거리에서는 아예 안 보였는데, 라벨을 선 옆으로 살짝 띄워서 거리와
// 무관하게 항상 표시되게 한다.
void drawCadDimensionLine(
  Canvas canvas,
  Offset start,
  Offset end,
  double distance,
  Color color,
  String prefix, {
  double strokeWidth = 1.3,
}) {
  if (distance < 1) return; // 사실상 붙어있으면 표시할 게 없음

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
  final tick = Offset(px, py) * 5;
  canvas.drawLine(start - tick, start + tick, linePaint);
  canvas.drawLine(end - tick, end + tick, linePaint);

  final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
  final label = mid + Offset(px, py) * 15;

  final textSpan = TextSpan(
    text: "$prefix ${distance.toInt()} mm",
    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
  );
  final textPainter = TextPainter(
    text: textSpan,
    textDirection: TextDirection.ltr,
  )..layout();

  final bgRect = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: label,
      width: textPainter.width + 10,
      height: textPainter.height + 6,
    ),
    const Radius.circular(4),
  );
  // 라벨-치수선 연결용 짧은 리더선
  canvas.drawLine(
    mid,
    label,
    Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1,
  );
  canvas.drawRRect(bgRect, Paint()..color = const Color(0xFFFFFFFF));
  canvas.drawRRect(
    bgRect,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
  textPainter.paint(
    canvas,
    Offset(label.dx - textPainter.width / 2, label.dy - textPainter.height / 2),
  );
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

  DimensionPainter({
    required this.dimensions,
    this.activePoint,
    this.panelWidth = 0,
    this.panelHeight = 0,
    this.version = 0,
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
      );

      // 🚀 [신규] 치수선마다 번호 배지를 달아서, 도면이 복잡해져도
      // 사진/PDF로 내보낸 치수 목록표와 대조해볼 수 있게 한다.
      final Offset badgeCenter = endpoints.p1;
      canvas.drawCircle(badgeCenter, 8, Paint()..color = dColor);
      final numberSpan = TextSpan(
        text: "${i + 1}",
        style: const TextStyle(
          color: _pureWhite,
          fontSize: 9,
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
          style: const TextStyle(
            color: _tossSubText,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
          ),
        );
        final notePainter = TextPainter(
          text: noteSpan,
          textDirection: TextDirection.ltr,
        )..layout();
        final Offset noteCenter = mid + away * 15;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: noteCenter,
              width: notePainter.width + 8,
              height: notePainter.height + 4,
            ),
            const Radius.circular(3),
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
      canvas.drawCircle(activePoint!.center, 6, Paint()..color = _tossText);
      canvas.drawCircle(
        activePoint!.center,
        16,
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
        oldDelegate.version != version;
  }
}
