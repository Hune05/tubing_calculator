/// 앱에서 쓰는 직접 그린 아이콘(메인 메뉴, 계산기 아래 탭, 특수 벤딩 등).
/// 기본 아이콘 대신 하는 일을 그림으로 보이게 한다. 24칸 격자에 같은 굵기의
/// 선으로 그려 한 벌처럼 보인다. 닫기·뒤로·추가·지우기처럼 어느 앱에서나 같은
/// 모양이라 바로 알아보는 단추는 기본 아이콘을 그대로 쓴다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

enum AppGlyph {
  // ── 메인 메뉴 ──
  /// 내 프로젝트: 체크리스트 달린 클립보드(작업 일지·이슈).
  project,

  /// 내 일정 관리: 체크 표시된 달력.
  schedule,

  /// 전선관 벤딩 마킹: 두꺼운 관(두 줄)을 90°로 굽힌 것 + 마킹 선.
  conduitBend,

  /// 벤딩 마킹 계산기(튜브): 가는 튜브를 굽힌 것 + 피팅 + 눈금.
  tubeBend,

  /// 튜브 컷팅 / 절단: 두 토막 난 관 + 커터 날.
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

  // ── 계산기 아래 탭 ──
  /// 입력: 구간 목록 + 연필.
  navInput,

  /// 마킹: 관 위에 마킹 점 세 개.
  navMarking,

  /// 보관함: 서랍 상자.
  navStorage,

  /// 현장: 줄자.
  navField,

  /// 아이소: 입체 상자(3D).
  navIso,

  // ── 구간·특수 벤딩 ──
  /// 직관 구간: 곧은 관 + 길이 치수선.
  straightPipe,

  /// 퀵 킥: 한 번 꺾은 관.
  kick,

  /// U-벤딩(180°).
  uBend,

  /// 오프셋: 두 번 꺾어 옆으로 비킨 관.
  offset,

  /// 롤링 오프셋: 오프셋 + 굴림 화살표.
  rollingOffset,

  /// 새들: 걸림(관) 위로 넘는 세 번 꺾음.
  saddle,

  /// 평행·축소: 나란히 가는 오프셋 두 줄.
  parallel,

  // ── 현장 탭 위 막대 ──
  /// 누적: 0점에서 잰 치수선 셋.
  fieldCumulative,

  /// 간격: 이어 잰 치수선.
  fieldGap,

  /// 햇빛: 반쯤 채운 해(밝게 보기).
  fieldSun,

  /// 한 단계씩: 번호 동그라미 셋.
  fieldSteps,

  // ── 튜브 컷팅: 부속 ──
  fitElbow,
  fitTee,
  fitCross,
  fitValve,
  fitReducer,
  fitBulkhead,
  fitCap,
  fitUnion,
  fitAdapter,

  /// 그 밖의 부속: 육각 너트.
  fitOther,

  /// 원자재(관 묶음 단면).
  rawBars,

  // ── 형강 단면 ──
  stAngle,
  stUnequal,
  stChannel,
  stLipC,
  stStrut,
  stFlat,
  stSquare,
  stRound,
  stBar,
  stRod,
  stBeam,

  // ── 자재 입출고 ──
  stockIn,
  stockOut,
  stockAudit,
  stockReturn,
  stockNew,
}

/// 기본 아이콘(IconData)과 직접 그린 아이콘(AppGlyph)을 같은 자리에 쓸 때.
Widget anyIcon(Object icon, {double? size, Color? color}) => icon is AppGlyph
    ? AppIcon(icon, size: size == null ? null : size + 2, color: color)
    : Icon(icon as IconData, size: size, color: color);

class AppIcon extends StatelessWidget {
  final AppGlyph glyph;

  /// 없으면 둘레의 아이콘 크기(IconTheme, 기본 24).
  final double? size;

  /// 없으면 둘레의 아이콘 색(IconTheme). 아래 탭처럼 고를 때 색이 바뀌는 곳에서 쓴다.
  final Color? color;

  /// 속을 옅게 채운다(고른 탭, 메뉴). false면 선만.
  final bool filled;

  const AppIcon(
    this.glyph, {
    super.key,
    this.size,
    this.color,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final double s = size ?? theme.size ?? 24;
    final Color c = color ?? theme.color ?? const Color(0xFF0F172A);
    return SizedBox(
      width: s,
      height: s,
      child: CustomPaint(painter: _AppIconPainter(glyph, c, filled)),
    );
  }
}

class _AppIconPainter extends CustomPainter {
  final AppGlyph glyph;
  final Color color;
  final bool filled;
  _AppIconPainter(this.glyph, this.color, this.filled);

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
      ..color = color.withValues(alpha: filled ? 0.18 : 0.0)
      ..style = PaintingStyle.fill;
    // 굽힌 관(한 줄 굵게).
    final pipe = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

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

    // 꺾이는 점을 둥글게 이은 관 경로(굽힘 반경 r).
    Path bent(List<Offset> pts, double r) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length - 1; i++) {
        final a = pts[i - 1], b = pts[i], c = pts[i + 1];
        final v1 = (a - b), v2 = (c - b);
        final d1 = v1.distance, d2 = v2.distance;
        final t = math.min(r, math.min(d1, d2) / 2);
        final p1 = b + v1 / d1 * t;
        final p2 = b + v2 / d2 * t;
        path.lineTo(p1.dx, p1.dy);
        path.quadraticBezierTo(b.dx, b.dy, p2.dx, p2.dy);
      }
      path.lineTo(pts.last.dx, pts.last.dy);
      return path;
    }

    // 부속에 붙는 관(더 굵게).
    final thick = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.round;

    // 가로 화살촉(dir 1: 오른쪽, -1: 왼쪽).
    void arrowHead(Offset tip, double dir) {
      canvas.drawPath(
        poly([
          tip.dx - dir * 1.8, tip.dy - 1.6, tip.dx, tip.dy, //
          tip.dx - dir * 1.8, tip.dy + 1.6,
        ], close: false),
        line..strokeWidth = 1.4,
      );
      line.strokeWidth = 1.8;
    }

    // 세로 화살촉(dir 1: 아래, -1: 위).
    void arrowHeadV(Offset tip, double dir) {
      canvas.drawPath(
        poly([
          tip.dx - 2.6, tip.dy - dir * 2.6, tip.dx, tip.dy, //
          tip.dx + 2.6, tip.dy - dir * 2.6,
        ], close: false),
        line,
      );
    }

    Path hexagon(Offset c, double r) {
      final path = Path();
      for (int i = 0; i < 6; i++) {
        final a = math.pi / 6 + i * math.pi / 3;
        final p = c + Offset(r * math.cos(a), r * math.sin(a));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      return path..close();
    }

    // 형강 단면(옅게 채우고 테두리).
    void section(List<double> xy) {
      final p = poly(xy);
      canvas.drawPath(p, soft);
      canvas.drawPath(p, line);
    }

    // 자재 상자.
    void box({double right = 20}) {
      rr(4, 11, right - 4, 10, 1.4, soft);
      rr(4, 11, right - 4, 10, 1.4);
      l(4, 14.2, right, 14.2);
    }

    switch (glyph) {
      case AppGlyph.project:
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

      case AppGlyph.schedule:
        rr(3.5, 5, 17, 15.5, 2.5);
        rr(3.5, 5, 17, 4.5, 2.5, soft);
        l(3.5, 9.5, 20.5, 9.5);
        l(8, 3, 8, 6.6);
        l(16, 3, 16, 6.6);
        canvas.drawPath(
          poly([8.6, 14.8, 10.9, 17.0, 15.6, 12.4], close: false),
          line,
        );

      case AppGlyph.conduitBend:
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

      case AppGlyph.tubeBend:
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

      case AppGlyph.tubeCut:
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

      case AppGlyph.steel:
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

      case AppGlyph.layout:
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

      case AppGlyph.scan:
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

      case AppGlyph.remote:
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

      case AppGlyph.tubeSpec:
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

      case AppGlyph.stock:
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

      case AppGlyph.stockAdmin:
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
      case AppGlyph.navInput:
        l(3.5, 6.0, 10.5, 6.0);
        l(3.5, 11.0, 9.0, 11.0);
        l(3.5, 16.0, 7.5, 16.0);
        final pen = poly([
          18.2, 3.4, 20.9, 6.1, 12.4, 14.6, 9.0, 15.6, 10.0, 12.2, //
        ]);
        canvas.drawPath(pen, soft);
        canvas.drawPath(pen, line);
        l(16.4, 5.2, 19.1, 7.9);
        l(3.5, 20.5, 20.5, 20.5);

      case AppGlyph.navMarking:
        rr(2.5, 13.0, 19, 5.4, 1.6, soft);
        rr(2.5, 13.0, 19, 5.4, 1.6);
        for (final x in [7.0, 12.0, 17.0]) {
          l(x, 9.2, x, 16.4, line..strokeWidth = 2.0);
          canvas.drawCircle(Offset(x, 5.6), 1.4, fill);
        }
        line.strokeWidth = 1.8;

      case AppGlyph.navStorage:
        rr(3.2, 4.0, 17.6, 5.2, 1.4, soft);
        rr(3.2, 4.0, 17.6, 5.2, 1.4);
        rr(4.4, 9.2, 15.2, 11.2, 1.6);
        l(9.6, 13.4, 14.4, 13.4);

      case AppGlyph.navField:
        // 줄자: 둥근 몸통 + 뽑은 테이프.
        rr(2.6, 5.6, 13.0, 13.0, 4.2, soft);
        rr(2.6, 5.6, 13.0, 13.0, 4.2);
        canvas.drawCircle(const Offset(9.1, 12.1), 2.4, line);
        rr(13.0, 15.0, 8.6, 3.8, 0.6, Paint()..color = Colors.white);
        rr(13.0, 15.0, 8.6, 3.8, 0.6);
        for (final x in [15.6, 18.0]) {
          l(x, 15.0, x, 16.6, line..strokeWidth = 1.3);
        }
        line.strokeWidth = 1.8;
        l(21.6, 14.0, 21.6, 19.8);

      case AppGlyph.navIso:
        final top = poly([12, 3, 19.8, 7.5, 12, 12, 4.2, 7.5]);
        canvas.drawPath(top, soft);
        canvas.drawPath(
          poly([12, 3, 19.8, 7.5, 19.8, 16.5, 12, 21, 4.2, 16.5, 4.2, 7.5]),
          line,
        );
        l(12, 12, 12, 21);
        l(12, 12, 4.2, 7.5);
        l(12, 12, 19.8, 7.5);

      case AppGlyph.straightPipe:
        rr(2.6, 6.6, 18.8, 5.6, 1.6, soft);
        rr(2.6, 6.6, 18.8, 5.6, 1.6);
        l(3.0, 17.8, 21.0, 17.8, line..strokeWidth = 1.4);
        l(3.0, 16.0, 3.0, 19.6);
        l(21.0, 16.0, 21.0, 19.6);
        line.strokeWidth = 1.8;

      case AppGlyph.kick:
        canvas.drawPath(
          bent(const [Offset(2.6, 18), Offset(12.5, 18), Offset(20.4, 7.2)], 4),
          pipe,
        );

      case AppGlyph.uBend:
        final u = Path()
          ..moveTo(6.2, 3.4)
          ..lineTo(6.2, 13.2)
          ..arcToPoint(
            const Offset(17.8, 13.2),
            radius: const Radius.circular(5.8),
            clockwise: false,
          )
          ..lineTo(17.8, 3.4);
        canvas.drawPath(u, pipe);

      case AppGlyph.offset:
        canvas.drawPath(
          bent(const [
            Offset(2.4, 18.2), Offset(8.2, 18.2), //
            Offset(15.8, 6.6), Offset(21.6, 6.6),
          ], 3.4),
          pipe,
        );

      case AppGlyph.rollingOffset:
        canvas.drawPath(
          bent(const [
            Offset(2.4, 19.2), Offset(9.0, 19.2), //
            Offset(15.4, 9.6), Offset(21.6, 9.6),
          ], 3.2),
          pipe,
        );
        // 굴림(관을 돌려 물림).
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(6.6, 7.4), radius: 3.6),
          math.pi * 0.9,
          math.pi * 1.5,
          false,
          line,
        );
        canvas.drawPath(
          poly([8.6, 2.6, 10.2, 4.4, 7.8, 5.2], close: false),
          line,
        );

      case AppGlyph.saddle:
        canvas.drawCircle(const Offset(12, 18.6), 2.6, soft);
        canvas.drawCircle(const Offset(12, 18.6), 2.6, line);
        canvas.drawPath(
          bent(const [
            Offset(2.2, 16.4), Offset(6.4, 16.4), Offset(12, 8.6), //
            Offset(17.6, 16.4), Offset(21.8, 16.4),
          ], 2.8),
          pipe,
        );

      case AppGlyph.parallel:
        for (final dy in [0.0, 5.6]) {
          canvas.drawPath(
            bent([
              Offset(2.4, 14.6 + dy), Offset(6.8 + dy * 0.5, 14.6 + dy), //
              Offset(12.6 + dy * 0.5, 5.0 + dy), Offset(21.6, 5.0 + dy),
            ], 2.8),
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2
              ..strokeCap = StrokeCap.round,
          );
        }
      // ── 현장 탭 위 막대 ──
      case AppGlyph.fieldCumulative:
        l(3, 4, 3, 20);
        for (final (y, x) in [(7.0, 10.0), (12.0, 15.5), (17.0, 21.0)]) {
          l(3, y, x, y);
          l(x, y - 2, x, y + 2);
        }

      case AppGlyph.fieldGap:
        l(3, 12, 21, 12);
        for (final x in [3.0, 9.0, 15.0, 21.0]) {
          l(x, 8, x, 16);
        }
        for (final (a, b) in [(3.0, 9.0), (9.0, 15.0), (15.0, 21.0)]) {
          arrowHead(Offset(a + 1.2, 12), -1);
          arrowHead(Offset(b - 1.2, 12), 1);
        }

      case AppGlyph.fieldSun:
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(12, 12), radius: 4.4),
          math.pi / 2,
          math.pi,
          true,
          fill,
        );
        canvas.drawCircle(const Offset(12, 12), 4.4, line);
        for (int i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          l(
            12 + 7.0 * math.cos(a),
            12 + 7.0 * math.sin(a),
            12 + 9.4 * math.cos(a),
            12 + 9.4 * math.sin(a),
          );
        }

      case AppGlyph.fieldSteps:
        l(7.6, 12, 9.4, 12);
        l(14.6, 12, 16.4, 12);
        canvas.drawCircle(const Offset(4.8, 12), 2.8, fill);
        canvas.drawCircle(const Offset(12, 12), 2.8, line);
        canvas.drawCircle(const Offset(19.2, 12), 2.8, line);

      // ── 부속 ──
      case AppGlyph.fitElbow:
        canvas.drawPath(
          bent(const [Offset(3, 7), Offset(16.5, 7), Offset(16.5, 21)], 5.5),
          thick,
        );
        rr(2.2, 4.2, 3.2, 5.6, 0.8, fill);
        rr(13.7, 18.4, 5.6, 3.2, 0.8, fill);

      case AppGlyph.fitTee:
        l(3, 15, 21, 15, thick);
        l(12, 15, 12, 4, thick);
        rr(2.2, 12.2, 3.2, 5.6, 0.8, fill);
        rr(18.6, 12.2, 3.2, 5.6, 0.8, fill);
        rr(9.2, 2.6, 5.6, 3.2, 0.8, fill);

      case AppGlyph.fitCross:
        l(3, 12, 21, 12, thick);
        l(12, 3, 12, 21, thick);
        rr(2.2, 9.2, 3.2, 5.6, 0.8, fill);
        rr(18.6, 9.2, 3.2, 5.6, 0.8, fill);
        rr(9.2, 2.2, 5.6, 3.2, 0.8, fill);
        rr(9.2, 18.6, 5.6, 3.2, 0.8, fill);

      case AppGlyph.fitValve:
        l(2.5, 15.5, 21.5, 15.5, thick);
        final bow = poly([6.5, 11.5, 12, 15.5, 6.5, 19.5]);
        final bow2 = poly([17.5, 11.5, 12, 15.5, 17.5, 19.5]);
        for (final b in [bow, bow2]) {
          canvas.drawPath(b, Paint()..color = Colors.white);
          canvas.drawPath(b, soft);
          canvas.drawPath(b, line);
        }
        l(12, 15.5, 12, 6);
        l(7.5, 5, 16.5, 5, line..strokeWidth = 2.4);
        line.strokeWidth = 1.8;

      case AppGlyph.fitReducer:
        final red = poly([
          2.5, 7, 9.5, 7, 14.5, 10.2, 21.5, 10.2, //
          21.5, 13.8, 14.5, 13.8, 9.5, 17, 2.5, 17,
        ]);
        canvas.drawPath(red, soft);
        canvas.drawPath(red, line);

      case AppGlyph.fitBulkhead:
        rr(10.4, 2.6, 3.2, 18.8, 0.6, soft);
        rr(10.4, 2.6, 3.2, 18.8, 0.6);
        l(2.5, 12, 21.5, 12, thick);
        rr(6.6, 8.6, 3.0, 6.8, 0.6, fill);
        rr(14.4, 8.6, 3.0, 6.8, 0.6, fill);

      case AppGlyph.fitCap:
        l(2.5, 12, 12, 12, thick);
        rr(12, 7, 8, 10, 2.4, soft);
        rr(12, 7, 8, 10, 2.4);

      case AppGlyph.fitUnion:
        l(2.5, 12, 21.5, 12, thick);
        final hex = hexagon(const Offset(12, 12), 6.2);
        canvas.drawPath(hex, Paint()..color = Colors.white);
        canvas.drawPath(hex, soft);
        canvas.drawPath(hex, line);
        l(12, 6.6, 12, 17.4);

      case AppGlyph.fitAdapter:
        l(2.5, 12, 10, 12, thick);
        rr(10, 7.6, 5.2, 8.8, 1, soft);
        rr(10, 7.6, 5.2, 8.8, 1);
        rr(15.2, 9.6, 6.4, 4.8, 0.6);
        for (final x in [16.8, 18.6, 20.4]) {
          l(x, 9.6, x - 0.8, 14.4, line..strokeWidth = 1.2);
        }
        line.strokeWidth = 1.8;

      case AppGlyph.fitOther:
        final hex = hexagon(const Offset(12, 12), 8.4);
        canvas.drawPath(hex, soft);
        canvas.drawPath(hex, line);
        canvas.drawCircle(const Offset(12, 12), 3.6, line);

      case AppGlyph.rawBars:
        for (final c in const [
          Offset(8, 15.6),
          Offset(16, 15.6),
          Offset(12, 8.6),
        ]) {
          canvas.drawCircle(c, 4.0, soft);
          canvas.drawCircle(c, 4.0, line);
          canvas.drawCircle(c, 1.5, line);
        }

      // ── 형강 단면 ──
      case AppGlyph.stAngle:
        section([5, 4, 9, 4, 9, 16, 20, 16, 20, 20, 5, 20]);
      case AppGlyph.stUnequal:
        section([5, 4, 8.6, 4, 8.6, 16.6, 15, 16.6, 15, 20, 5, 20]);
      case AppGlyph.stChannel:
        section([
          18,
          4,
          5,
          4,
          5,
          20,
          18,
          20,
          18,
          16.8,
          8.6,
          16.8,
          8.6,
          7.2,
          18,
          7.2,
        ]);
      case AppGlyph.stLipC:
        section([
          18, 4, 5, 4, 5, 20, 18, 20, 18, 15.4, 15.4, 15.4, 15.4, 17.2, //
          7.8, 17.2, 7.8, 6.8, 15.4, 6.8, 15.4, 8.6, 18, 8.6,
        ]);
      case AppGlyph.stStrut:
        section([
          4, 6, 9, 6, 9, 9, 7, 9, 7, 17, 17, 17, 17, 9, 15, 9, 15, 6, //
          20, 6, 20, 20, 4, 20,
        ]);
      case AppGlyph.stFlat:
        rr(3, 9.4, 18, 5.2, 0.8, soft);
        rr(3, 9.4, 18, 5.2, 0.8);
      case AppGlyph.stSquare:
        rr(4, 4, 16, 16, 2.2, soft);
        rr(4, 4, 16, 16, 2.2);
        rr(7.6, 7.6, 8.8, 8.8, 1, Paint()..color = Colors.white);
        rr(7.6, 7.6, 8.8, 8.8, 1);
      case AppGlyph.stRound:
        canvas.drawCircle(const Offset(12, 12), 8.2, soft);
        canvas.drawCircle(const Offset(12, 12), 8.2, line);
        canvas.drawCircle(
          const Offset(12, 12),
          5.2,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(const Offset(12, 12), 5.2, line);
      case AppGlyph.stBar:
        canvas.drawCircle(
          const Offset(12, 12),
          8.2,
          Paint()..color = color.withValues(alpha: filled ? 0.4 : 0.0),
        );
        canvas.drawCircle(const Offset(12, 12), 8.2, line);
      case AppGlyph.stRod:
        rr(2.5, 9.2, 19, 5.6, 1, soft);
        rr(2.5, 9.2, 19, 5.6, 1);
        for (double x = 5.2; x < 21; x += 2.6) {
          l(x, 9.2, x - 1.4, 14.8, line..strokeWidth = 1.2);
        }
        line.strokeWidth = 1.8;
      case AppGlyph.stBeam:
        section([
          4, 4, 20, 4, 20, 7.2, 13.6, 7.2, 13.6, 16.8, 20, 16.8, 20, 20, //
          4, 20, 4, 16.8, 10.4, 16.8, 10.4, 7.2, 4, 7.2,
        ]);

      // ── 자재 입출고 ──
      case AppGlyph.stockIn:
        box();
        l(12, 2.4, 12, 9.4);
        arrowHeadV(const Offset(12, 9.6), 1);
      case AppGlyph.stockOut:
        box();
        l(12, 9.6, 12, 2.6);
        arrowHeadV(const Offset(12, 2.4), -1);
      case AppGlyph.stockAudit:
        box(right: 15.2);
        canvas.drawCircle(
          const Offset(18, 7),
          4.4,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(const Offset(18, 7), 4.4, line);
        canvas.drawPath(
          poly([15.8, 7.1, 17.4, 8.7, 20.3, 5.6], close: false),
          line,
        );
      case AppGlyph.stockReturn:
        box();
        final back = Path()
          ..moveTo(17, 8.6)
          ..lineTo(17, 5.6)
          ..arcToPoint(
            const Offset(8.6, 5.6),
            radius: const Radius.circular(4.2),
            clockwise: false,
          )
          ..lineTo(8.6, 8.6);
        canvas.drawPath(back, line);
        arrowHeadV(const Offset(8.6, 9.2), 1);
      case AppGlyph.stockNew:
        box(right: 15.2);
        canvas.drawCircle(
          const Offset(18, 7),
          4.4,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(const Offset(18, 7), 4.4, line);
        l(18, 4.8, 18, 9.2);
        l(15.8, 7, 20.2, 7);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AppIconPainter old) =>
      old.glyph != glyph || old.color != color || old.filled != filled;
}
