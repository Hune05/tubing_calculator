/// 메인 메뉴 아이콘(직접 그림). 기본 아이콘 대신 메뉴마다 하는 일을
/// 그림으로 보이게 한다. 24칸 격자에 같은 굵기의 선으로 그려 한 벌처럼 보인다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

enum MenuGlyph {
  /// 내 프로젝트: 체크리스트 달린 클립보드(작업 일지·이슈).
  project,

  /// 내 일정 관리: 체크 표시된 달력.
  schedule,

  /// 전선관 벤딩 마킹: 두꺼운 관(두 줄)을 90°로 굽힌 것 + 마킹 선.
  conduitBend,

  /// 벤딩 마킹 계산기(튜브): 가는 튜브를 굽힌 것 + 피팅 + 눈금.
  tubeBend,

  /// 튜브 컷팅: 두 토막 난 관 + 튜브 커터 날.
  tubeCut,

  /// 형강 컷팅: 찬넬(ㄷ)과 앵글(ㄴ) 단면.
  steel,

  /// 작업 배치도: 중판에 레일 두 줄과 부품.
  layout,

  /// 현장 도면 스캔: 스캔 모서리 + QR.
  scan,

  /// 벤딩 리모컨: 리모컨 + 전파.
  remote,

  /// 튜브 규격·실측 도표: 관 단면(바깥·안) + 치수선.
  tubeSpec,

  /// 자재 현황: 선반 위 상자.
  stock,

  /// 자재 통합 관리: 상자 + 연필(등록·고치기).
  stockAdmin,
}

class MenuIcon extends StatelessWidget {
  final MenuGlyph glyph;
  final double size;
  final Color color;

  const MenuIcon(
    this.glyph, {
    super.key,
    this.size = 28,
    this.color = const Color(0xFF0F172A),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MenuIconPainter(glyph, color)),
    );
  }
}

class _MenuIconPainter extends CustomPainter {
  final MenuGlyph glyph;
  final Color color;
  _MenuIconPainter(this.glyph, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final double k = size.width / 24.0;
    canvas.save();
    canvas.scale(k);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final soft = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    void l(double x1, double y1, double x2, double y2, [Paint? p]) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), p ?? line);
    void rr(double x, double y, double w, double h, double r, [Paint? p]) =>
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, w, h),
            Radius.circular(r),
          ),
          p ?? line,
        );
    Path poly(List<double> xy, {bool close = true}) {
      final path = Path()..moveTo(xy[0], xy[1]);
      for (int i = 2; i < xy.length; i += 2) {
        path.lineTo(xy[i], xy[i + 1]);
      }
      if (close) path.close();
      return path;
    }

    switch (glyph) {
      case MenuGlyph.project:
        rr(4.5, 4.5, 15, 17, 2.2);
        rr(8.5, 2.6, 7, 3.6, 1.2, soft);
        rr(8.5, 2.6, 7, 3.6, 1.2);
        canvas.drawPath(
          poly([7.4, 11.4, 8.9, 12.9, 11.4, 10.2], close: false),
          line,
        );
        l(13.4, 11.6, 16.6, 11.6);
        canvas.drawPath(
          poly([7.4, 16.4, 8.9, 17.9, 11.4, 15.2], close: false),
          line,
        );
        l(13.4, 16.6, 16.6, 16.6);

      case MenuGlyph.schedule:
        rr(3.5, 5, 17, 15.5, 2.5);
        rr(3.5, 5, 17, 4.5, 2.5, soft);
        l(3.5, 9.5, 20.5, 9.5);
        l(8, 3, 8, 6.6);
        l(16, 3, 16, 6.6);
        canvas.drawPath(
          poly([8.6, 14.8, 10.9, 17.0, 15.6, 12.4], close: false),
          line,
        );

      case MenuGlyph.conduitBend:
        // 두꺼운 관(바깥·안 두 줄)을 90°로 굽혔다.
        final outer = Path()
          ..moveTo(2.8, 4.6)
          ..lineTo(11, 4.6)
          ..arcToPoint(
            const Offset(19.6, 13.2),
            radius: const Radius.circular(8.6),
          )
          ..lineTo(19.6, 21.2);
        final inner = Path()
          ..moveTo(2.8, 9.8)
          ..lineTo(11, 9.8)
          ..arcToPoint(
            const Offset(14.4, 13.2),
            radius: const Radius.circular(3.4),
          )
          ..lineTo(14.4, 21.2);
        final body = Path()
          ..addPath(outer, Offset.zero)
          ..lineTo(14.4, 21.2)
          ..lineTo(14.4, 13.2)
          ..arcToPoint(
            const Offset(11, 9.8),
            radius: const Radius.circular(3.4),
            clockwise: false,
          )
          ..lineTo(2.8, 9.8)
          ..close();
        canvas.drawPath(body, soft);
        canvas.drawPath(outer, line);
        canvas.drawPath(inner, line);
        l(2.8, 4.6, 2.8, 9.8);
        l(14.4, 21.2, 19.6, 21.2);
        // 마킹 선.
        l(6.8, 2.6, 6.8, 11.8, line..strokeWidth = 2.2);
        line.strokeWidth = 1.8;

      case MenuGlyph.tubeBend:
        // 눈금자.
        l(3, 3.6, 14, 3.6);
        for (final x in [3.0, 5.75, 8.5, 11.25, 14.0]) {
          l(x, 3.6, x, x == 8.5 ? 6.4 : 5.4);
        }
        // 굽힌 튜브(한 줄, 굵게) + 피팅.
        final tube = Path()
          ..moveTo(3, 10)
          ..lineTo(10.5, 10)
          ..arcToPoint(const Offset(16.5, 16), radius: const Radius.circular(6))
          ..lineTo(16.5, 18.2);
        canvas.drawPath(
          tube,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round,
        );
        rr(13.6, 18.2, 5.8, 3.6, 1, soft);
        rr(13.6, 18.2, 5.8, 3.6, 1);
        // 마킹 점.
        canvas.drawCircle(const Offset(8.5, 10), 1.6, fill);

      case MenuGlyph.tubeCut:
        // 두 토막 난 관과, 자른 자리에 얹힌 커터 날.
        rr(2.5, 12.2, 8.2, 5.2, 1.2, soft);
        rr(2.5, 12.2, 8.2, 5.2, 1.2);
        rr(13.3, 12.2, 8.2, 5.2, 1.2, soft);
        rr(13.3, 12.2, 8.2, 5.2, 1.2);
        canvas.drawCircle(
          const Offset(12, 8.6),
          3.6,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(const Offset(12, 8.6), 3.6, line);
        canvas.drawCircle(const Offset(12, 8.6), 1.0, fill);

      case MenuGlyph.steel:
        final channel = poly([
          3.5, 4.5, 10.8, 4.5, 10.8, 7.6, 6.6, 7.6, //
          6.6, 16.4, 10.8, 16.4, 10.8, 19.5, 3.5, 19.5,
        ]);
        final angle = poly([
          13.4,
          4.5,
          16.5,
          4.5,
          16.5,
          16.4,
          20.6,
          16.4,
          20.6,
          19.5,
          13.4,
          19.5,
        ]);
        canvas.drawPath(channel, soft);
        canvas.drawPath(channel, line);
        canvas.drawPath(angle, soft);
        canvas.drawPath(angle, line);

      case MenuGlyph.layout:
        // 중판에 레일 두 줄, 레일마다 부품.
        rr(3.5, 3.5, 17, 17, 2.2);
        l(6.0, 9.0, 18.0, 9.0);
        l(6.0, 15.6, 18.0, 15.6);
        for (final (x, y, w) in [
          (6.6, 6.4, 4.4),
          (12.6, 6.4, 4.8),
          (6.6, 13.0, 6.2),
        ]) {
          rr(x, y, w, 5.2, 0.8, Paint()..color = Colors.white);
          rr(x, y, w, 5.2, 0.8, soft);
          rr(x, y, w, 5.2, 0.8);
        }

      case MenuGlyph.scan:
        for (final (x, y, dx, dy) in [
          (3.0, 3.0, 1.0, 1.0),
          (21.0, 3.0, -1.0, 1.0),
          (3.0, 21.0, 1.0, -1.0),
          (21.0, 21.0, -1.0, -1.0),
        ]) {
          canvas.drawPath(
            poly([x, y + dy * 4.8, x, y, x + dx * 4.8, y], close: false),
            line,
          );
        }
        for (final (x, y) in [(7.4, 7.4), (13.1, 7.4), (7.4, 13.1)]) {
          rr(x, y, 3.5, 3.5, 0.6);
        }
        rr(13.3, 13.3, 1.5, 1.5, 0.3, fill);
        rr(15.4, 15.4, 1.3, 1.3, 0.3, fill);
        rr(13.3, 15.6, 1.2, 1.2, 0.3, fill);
        rr(15.6, 13.3, 1.2, 1.2, 0.3, fill);

      case MenuGlyph.remote:
        rr(4, 6.5, 9.5, 15, 2.4);
        rr(6.2, 8.7, 5.1, 3, 0.8, soft);
        rr(6.2, 8.7, 5.1, 3, 0.8);
        canvas.drawCircle(const Offset(8.75, 16.2), 2.1, line);
        canvas.drawCircle(const Offset(8.75, 16.2), 0.7, fill);
        for (final r in [4.0, 7.0]) {
          canvas.drawArc(
            Rect.fromCircle(center: const Offset(13.2, 7.2), radius: r),
            -math.pi * 0.47,
            math.pi * 0.42,
            false,
            line,
          );
        }

      case MenuGlyph.tubeSpec:
        canvas.drawCircle(const Offset(12, 9.4), 6.4, soft);
        canvas.drawCircle(const Offset(12, 9.4), 6.4, line);
        canvas.drawCircle(
          const Offset(12, 9.4),
          3.8,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(const Offset(12, 9.4), 3.8, line);
        l(5.6, 19.4, 18.4, 19.4);
        l(5.6, 17.6, 5.6, 21.2);
        l(18.4, 17.6, 18.4, 21.2);
        canvas.drawPath(
          poly([7.8, 18.3, 5.8, 19.4, 7.8, 20.5], close: false),
          line,
        );
        canvas.drawPath(
          poly([16.2, 18.3, 18.2, 19.4, 16.2, 20.5], close: false),
          line,
        );

      case MenuGlyph.stock:
        l(2.8, 20.8, 21.2, 20.8);
        for (final (x, y, w, h) in [
          (4.2, 12.4, 7.2, 8.4),
          (12.6, 12.4, 7.2, 8.4),
          (8.4, 4.0, 7.2, 8.4),
        ]) {
          rr(x, y, w, h, 1.2, soft);
          rr(x, y, w, h, 1.2);
          l(x + w / 2, y, x + w / 2, y + 3.0);
        }

      case MenuGlyph.stockAdmin:
        rr(3.5, 9.4, 11.4, 11.4, 1.6, soft);
        rr(3.5, 9.4, 11.4, 11.4, 1.6);
        l(3.5, 13.0, 14.9, 13.0);
        l(9.2, 9.4, 9.2, 13.0);
        // 연필.
        final pencil = poly([
          18.4, 3.2, 20.8, 5.6, 14.6, 11.8, 11.6, 12.6, 12.4, 9.6, //
        ]);
        canvas.drawPath(pencil, Paint()..color = Colors.white);
        canvas.drawPath(pencil, line);
        l(16.6, 5.0, 19.0, 7.4);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MenuIconPainter old) =>
      old.glyph != glyph || old.color != color;
}
