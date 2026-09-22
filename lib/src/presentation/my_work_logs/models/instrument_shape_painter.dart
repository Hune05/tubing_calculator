import 'dart:math' as math;

import 'package:flutter/material.dart';

// 🚀 배치도 계기 모듈의 정면 모양. 네모 대신 몸통(지시계 창)·목·플랜지·
// 육각·나사·포크를 대강 그려서, 목록과 도면에서 어떤 계기인지 눈으로 알아보게 한다.
// 치수를 재는 그림이 아니라 알아보기 위한 그림이다(외곽은 모듈 가로×세로 그대로).

/// 계기 모양 종류. ModulePreset·PlacedItem의 shape 칸에 이 이름을 적는다.
class InstrumentShape {
  /// 코플래너 플랜지 DP(아래에 H·L 두 구멍).
  static const String dp = 'dp';

  /// 코플래너 플랜지 게이지(아래에 구멍 하나).
  static const String gp = 'gp';

  /// 재래식 플랜지 DP(플랜지 양옆에 어댑터).
  static const String dpTraditional = 'dp_trad';

  /// 요꼬가와 수직 배관: 왼쪽 캡슐(아래로 두 구멍), 오른쪽 몸통. 원래 가로가 길다.
  static const String dpSide = 'dp_side';

  /// 인라인 압력: 몸통 아래 목·육각·나사.
  static const String inline = 'inline';

  /// 포크 레벨 스위치: 둥근 머리, 목, 육각·나사, 두 갈래 포크.
  static const String fork = 'fork';

  /// 원래 가로가 긴 모양인지(돌려 놓았는지 가리는 데 쓴다).
  static bool isLandscape(String shape) => shape == dpSide;
}

class InstrumentShapePainter extends CustomPainter {
  final String shape;
  final Color stroke;
  final double strokeWidth;

  const InstrumentShapePainter({
    required this.shape,
    this.stroke = const Color(0xFF64748B),
    this.strokeWidth = 1.5,
  });

  static const Color _body = Color(0xFFF8FAFC);
  static const Color _metal = Color(0xFFE2E8F0);
  static const Color _glass = Color(0xFFDDEFF1);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    // 모듈을 90° 돌려 가로·세로가 바뀌었으면 그림도 돌려서 그린다.
    final bool boxLandscape = size.width > size.height;
    final bool rotate =
        boxLandscape != InstrumentShape.isLandscape(shape) &&
        size.width != size.height;
    canvas.save();
    Size s = size;
    if (rotate) {
      canvas.translate(size.width, 0);
      canvas.rotate(math.pi / 2);
      s = Size(size.height, size.width);
    }
    switch (shape) {
      case InstrumentShape.dp:
        _coplanar(canvas, s, ports: 2, adapters: false);
      case InstrumentShape.gp:
        _coplanar(canvas, s, ports: 1, adapters: false);
      case InstrumentShape.dpTraditional:
        _coplanar(canvas, s, ports: 2, adapters: true);
      case InstrumentShape.dpSide:
        _dpSide(canvas, s);
      case InstrumentShape.inline:
        _inline(canvas, s);
      case InstrumentShape.fork:
        _fork(canvas, s);
      default:
        _part(canvas, Offset.zero & s, _body, radius: 4);
    }
    canvas.restore();
  }

  Paint get _line => Paint()
    ..color = stroke
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth;

  void _part(Canvas c, Rect r, Color fill, {double radius = 2}) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    c.drawRRect(rr, Paint()..color = fill);
    c.drawRRect(rr, _line);
  }

  void _circle(Canvas c, Offset center, double r, Color fill) {
    c.drawCircle(center, r, Paint()..color = fill);
    c.drawCircle(center, r, _line);
  }

  /// 몸통(위 칸)과 지시계 창.
  void _housing(Canvas c, Rect r) {
    _part(c, r, _body, radius: math.min(r.width, r.height) * 0.18);
    final double rad = math.min(r.width, r.height) * 0.34;
    _circle(c, r.center, rad, _glass);
    _circle(c, r.center, rad * 0.62, _body);
  }

  /// 육각(가로 줄 두 개로 면을 나눈다)과 그 아래 나사(빗금).
  void _hexAndThread(Canvas c, Rect hex, Rect thread) {
    _part(c, hex, _metal, radius: 1);
    final double third = hex.width / 3;
    c.drawLine(
      Offset(hex.left + third, hex.top),
      Offset(hex.left + third, hex.bottom),
      _line,
    );
    c.drawLine(
      Offset(hex.right - third, hex.top),
      Offset(hex.right - third, hex.bottom),
      _line,
    );
    _part(c, thread, _metal, radius: 0);
    final int n = math.max(2, (thread.height / 5).floor());
    for (int i = 1; i < n; i++) {
      final double y = thread.top + thread.height * i / n;
      c.drawLine(
        Offset(thread.left, y + 1.5),
        Offset(thread.right, y - 1.5),
        _line,
      );
    }
  }

  void _coplanar(
    Canvas c,
    Size s, {
    required int ports,
    required bool adapters,
  }) {
    final double w = s.width, h = s.height;
    final double side = adapters ? w * 0.16 : 0;
    final double bodyL = side, bodyR = w - side;
    final double bw = bodyR - bodyL;
    _housing(
      c,
      Rect.fromLTRB(bodyL + bw * 0.06, 0, bodyR - bw * 0.06, h * 0.46),
    );
    _part(
      c,
      Rect.fromLTRB(bodyL + bw * 0.36, h * 0.46, bodyR - bw * 0.36, h * 0.55),
      _metal,
      radius: 0,
    );
    // 센서 몸통 + 플랜지
    final Rect flange = Rect.fromLTRB(bodyL, h * 0.55, bodyR, h * 0.86);
    _part(c, flange, _metal, radius: 3);
    final double bolt = math.min(bw, h) * 0.045;
    for (final dx in [0.12, 0.88]) {
      for (final dy in [0.2, 0.8]) {
        _circle(
          c,
          Offset(
            flange.left + flange.width * dx,
            flange.top + flange.height * dy,
          ),
          bolt,
          _body,
        );
      }
    }
    // 아래 구멍(H·L)
    final double pw = bw * 0.14;
    final List<double> xs = ports == 2 ? [0.28, 0.72] : [0.5];
    for (final px in xs) {
      final double cx = bodyL + bw * px;
      _part(
        c,
        Rect.fromLTRB(cx - pw / 2, h * 0.86, cx + pw / 2, h),
        _metal,
        radius: 0,
      );
    }
    // 재래식 플랜지 양옆 어댑터
    if (adapters) {
      for (final left in [true, false]) {
        final Rect a = left
            ? Rect.fromLTRB(0, h * 0.62, side, h * 0.79)
            : Rect.fromLTRB(w - side, h * 0.62, w, h * 0.79);
        _part(c, a, _metal, radius: 1);
      }
    }
  }

  void _dpSide(Canvas c, Size s) {
    final double w = s.width, h = s.height;
    // 왼쪽 캡슐 + 아래로 두 구멍
    final Rect cap = Rect.fromLTRB(0, h * 0.12, w * 0.4, h * 0.84);
    _part(c, cap, _metal, radius: 4);
    final double bolt = math.min(cap.width, cap.height) * 0.07;
    for (final dy in [0.18, 0.82]) {
      _circle(c, Offset(cap.center.dx, cap.top + cap.height * dy), bolt, _body);
    }
    final double pw = cap.width * 0.18;
    for (final px in [0.28, 0.72]) {
      final double cx = cap.left + cap.width * px;
      _part(
        c,
        Rect.fromLTRB(cx - pw / 2, h * 0.84, cx + pw / 2, h),
        _metal,
        radius: 0,
      );
    }
    // 목 + 오른쪽 몸통
    _part(
      c,
      Rect.fromLTRB(w * 0.4, h * 0.38, w * 0.48, h * 0.58),
      _metal,
      radius: 0,
    );
    _housing(c, Rect.fromLTRB(w * 0.48, 0, w, h * 0.92));
  }

  void _inline(Canvas c, Size s) {
    final double w = s.width, h = s.height;
    _housing(c, Rect.fromLTRB(w * 0.04, 0, w * 0.96, h * 0.5));
    _part(
      c,
      Rect.fromLTRB(w * 0.4, h * 0.5, w * 0.6, h * 0.6),
      _metal,
      radius: 0,
    );
    _part(c, Rect.fromLTRB(w * 0.24, h * 0.6, w * 0.76, h * 0.8), _metal);
    _hexAndThread(
      c,
      Rect.fromLTRB(w * 0.2, h * 0.8, w * 0.8, h * 0.89),
      Rect.fromLTRB(w * 0.36, h * 0.89, w * 0.64, h),
    );
  }

  void _fork(Canvas c, Size s) {
    final double w = s.width, h = s.height;
    // 포크 길이는 실물 69mm 안팎(도면 1칸 = 1mm). 작게 줄였을 때는 비율로.
    final double forkLen = math.min(69, h * 0.32);
    final double headH = math.min(w * 0.85, h * 0.46);
    final double forkTop = h - forkLen;
    // 머리(둥근 뚜껑) + 옆 케이블 글랜드
    final double gland = w * 0.12;
    final Rect head = Rect.fromLTRB(w * 0.02, 0, w - gland, headH);
    _part(c, head, _body, radius: head.width * 0.3);
    _circle(c, head.center, math.min(head.width, head.height) * 0.3, _metal);
    _part(
      c,
      Rect.fromLTRB(w - gland, headH * 0.35, w, headH * 0.6),
      _metal,
      radius: 1,
    );
    // 목(고온형은 길다)
    final double hexH = h * 0.06, threadH = h * 0.06;
    final double hexTop = forkTop - threadH - hexH;
    if (hexTop > headH) {
      _part(
        c,
        Rect.fromLTRB(w * 0.4, headH, w * 0.6, hexTop),
        _metal,
        radius: 0,
      );
    }
    _hexAndThread(
      c,
      Rect.fromLTRB(w * 0.24, hexTop, w * 0.76, hexTop + hexH),
      Rect.fromLTRB(w * 0.34, hexTop + hexH, w * 0.66, forkTop),
    );
    // 두 갈래 포크
    final double tw = w * 0.11;
    for (final px in [0.41, 0.59]) {
      final double cx = w * px;
      _part(
        c,
        Rect.fromLTRB(cx - tw / 2, forkTop, cx + tw / 2, h),
        _metal,
        radius: tw / 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant InstrumentShapePainter old) =>
      old.shape != shape ||
      old.stroke != stroke ||
      old.strokeWidth != strokeWidth;
}
