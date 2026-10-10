// 철판 모양 그림 카드(10-10, 상용 레이저 주문 앱처럼 모양을 그림으로 고른다).
// 카드마다 작은 실루엣(평판·원형·링·삼각 리브·좌표 입력·ㄱ·ㄷ·Z·모자 옆모습) + 이름.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/field_view.dart';
import 'plate_calc.dart';

class PlateShapeCard extends StatelessWidget {
  const PlateShapeCard({
    super.key,
    required this.shape,
    required this.label,
    required this.selected,
    required this.onTap,
    this.width = 92,
  });

  /// 카드 폭(모양 수에 맞춰 한 줄에 들어가게 부른 쪽이 정한다).
  final double width;
  final PlateShape shape;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: width < 76 ? 76 : 84,
    child: Material(
      color: selected ? fc.brandSoft : fc.fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? fc.brand : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: width < 76
              ? const EdgeInsets.fromLTRB(3, 7, 3, 5)
              : const EdgeInsets.fromLTRB(6, 8, 6, 6),
          child: Column(
            children: [
              Expanded(
                child: CustomPaint(
                  painter: PlateShapeIconPainter(
                    shape,
                    line: selected ? fc.brand : fc.textSub,
                    fill: selected
                        ? fc.brand.withValues(alpha: 0.18)
                        : fc.textSub.withValues(alpha: 0.12),
                    hole: selected ? fc.brandSoft : fc.fill,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: width < 76 ? 12 : 13,
                  fontWeight: FontWeight.w800,
                  color: selected ? fc.brand : fc.text,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 모양 실루엣(가운데에 맞춤).
class PlateShapeIconPainter extends CustomPainter {
  PlateShapeIconPainter(
    this.shape, {
    required this.line,
    required this.fill,
    required this.hole,
  });

  final PlateShape shape;
  final Color line, fill, hole;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 56, size.height / 40);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s);
    // 56 × 40 칸, 가운데 (0, 0)
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 / s
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final body = Paint()..color = fill;
    final holeP = Paint()..color = hole;
    void poly(List<Offset> pts) {
      final p = Path()..addPolygon(pts, true);
      canvas.drawPath(p, body);
      canvas.drawPath(p, stroke);
    }

    void dot(Offset c, double r) {
      canvas.drawCircle(c, r, holeP);
      canvas.drawCircle(c, r, stroke);
    }

    void profile(List<Offset> pts) {
      final p = Path()..addPolygon(pts, false);
      canvas.drawPath(
        p,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    switch (shape) {
      case PlateShape.flat:
        final r = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-24, -15, 48, 30),
          const Radius.circular(4),
        );
        canvas.drawRRect(r, body);
        canvas.drawRRect(r, stroke);
        dot(const Offset(-16, 0), 3);
        dot(const Offset(16, 0), 3);
      case PlateShape.circle:
        canvas.drawCircle(Offset.zero, 17, body);
        canvas.drawCircle(Offset.zero, 17, stroke);
        for (var k = 0; k < 4; k++) {
          final a = math.pi / 4 + k * math.pi / 2;
          dot(Offset(math.cos(a), math.sin(a)) * 11, 2.4);
        }
      case PlateShape.ring:
        canvas.drawCircle(Offset.zero, 17, body);
        canvas.drawCircle(Offset.zero, 17, stroke);
        dot(Offset.zero, 8);
      case PlateShape.rib:
        poly(const [Offset(-18, 16), Offset(20, 16), Offset(-18, -16)]);
      case PlateShape.free:
        poly(const [
          Offset(-24, 14),
          Offset(-8, 14),
          Offset(-8, 4),
          Offset(8, 4),
          Offset(8, 14),
          Offset(24, 14),
          Offset(24, -2),
          Offset(10, -2),
          Offset(10, -15),
          Offset(-10, -15),
          Offset(-10, -2),
          Offset(-24, -2),
        ]);
      case PlateShape.l:
        profile(const [Offset(-18, -14), Offset(-18, 14), Offset(18, 14)]);
      case PlateShape.u:
        profile(const [
          Offset(-16, -14),
          Offset(-16, 14),
          Offset(16, 14),
          Offset(16, -14),
        ]);
      case PlateShape.z:
        profile(const [
          Offset(-22, -14),
          Offset(-4, -14),
          Offset(-4, 14),
          Offset(16, 14),
        ]);
      case PlateShape.hat:
        profile(const [
          Offset(-25, 14),
          Offset(-13, 14),
          Offset(-13, -13),
          Offset(13, -13),
          Offset(13, 14),
          Offset(25, 14),
        ]);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PlateShapeIconPainter old) =>
      old.shape != shape ||
      old.line != line ||
      old.fill != fill ||
      old.hole != hole;
}
