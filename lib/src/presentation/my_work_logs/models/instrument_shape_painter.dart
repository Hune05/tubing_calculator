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

  /// ABS 배선 덕트: 양쪽 벽에 빗살(전선 빼는 홈), 가운데 뚜껑. 원래 세로로 길다.
  static const String duct = 'duct';

  /// 비카 MA 같은 방폭 압력 스위치: 옆에서 본 둥근 통(청색), 왼쪽 케이블 입구,
  /// 아래 받침판과 가운데 접속구. 원래 가로가 길다.
  static const String exdSwitch = 'exd_switch';

  /// SOR 방수형(NN·RN) 압력 스위치: 네모 상자(뚜껑 나사 4개, 아래 양쪽 귀, 오른쪽 배관 허브),
  /// 아래로 목·육각·접속구(피스톤).
  static const String sorPiston = 'sor_piston';

  /// SOR 작은 다이어프램(4·54).
  static const String sorDiaphragm = 'sor_diaphragm';

  /// SOR 저압 넓은 다이어프램(12·52, 지름 94.5 원판).
  static const String sorWide = 'sor_wide';

  /// SOR 101 차압: 상자 아래 둥근 차압 몸통, 아래 HI·옆 LO 구멍.
  static const String sorDp = 'sor_dp';

  /// SOR 방폭(B3·B6): 둥근 뚜껑 양옆 허브, 아래 네모 설정칸, 목·접속구.
  static const String sorExp = 'sor_exp';

  /// 원래 가로가 긴 모양인지(돌려 놓았는지 가리는 데 쓴다).
  static bool isLandscape(String shape) =>
      shape == dpSide || shape == exdSwitch;
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
      case InstrumentShape.duct:
        _duct(canvas, s);
      case InstrumentShape.exdSwitch:
        _exdSwitch(canvas, s);
      case InstrumentShape.sorPiston:
      case InstrumentShape.sorDiaphragm:
      case InstrumentShape.sorWide:
      case InstrumentShape.sorDp:
        _sorBox(canvas, s, shape);
      case InstrumentShape.sorExp:
        _sorExp(canvas, s);
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

  // 비카 MA 정면(PV 31.11 p.8 왼쪽 그림): 가운데 선이 왼쪽에서 87/161 자리.
  void _exdSwitch(Canvas c, Size s) {
    final double w = s.width, h = s.height;
    const Color blue = Color(0xFFD6E4F5);
    final double cx = w * 87 / 161;
    // 뚜껑 위 도드라진 부분과 통
    _part(c, Rect.fromLTRB(w * 0.36, 0, w * 0.82, h * 0.1), blue, radius: 2);
    _part(c, Rect.fromLTRB(w * 0.14, h * 0.08, w, h * 0.2), blue, radius: 2);
    _part(c, Rect.fromLTRB(w * 0.14, h * 0.2, w, h * 0.78), blue, radius: 3);
    // 왼쪽 케이블 입구, 오른쪽 뚜껑 잠금 고리
    _part(c, Rect.fromLTRB(0, h * 0.4, w * 0.15, h * 0.64), _metal, radius: 2);
    _circle(c, Offset(w * 0.075, h * 0.52), math.min(w, h) * 0.05, _body);
    _part(c, Rect.fromLTRB(w * 0.9, h * 0.44, w * 0.97, h * 0.6), _body);
    // 받침판(볼트)과 접속구
    final Rect base = Rect.fromLTRB(w * 0.12, h * 0.78, w, h * 0.86);
    _part(c, base, _metal, radius: 1);
    for (final px in [0.22, 0.4, 0.72, 0.9]) {
      final double bx = w * px;
      c.drawLine(Offset(bx, base.top), Offset(bx, base.bottom), _line);
    }
    _hexAndThread(
      c,
      Rect.fromLTRB(cx - w * 0.08, h * 0.86, cx + w * 0.08, h * 0.93),
      Rect.fromLTRB(cx - w * 0.04, h * 0.93, cx + w * 0.04, h),
    );
  }

  static const Color _sorBlue = Color(0xFFCFE3F3);

  // SOR NN·RN(CAT216 p.21·22): 오른쪽 허브를 뺀 상자 폭은 전체의 약 0.82.
  void _sorBox(Canvas c, Size s, String kind) {
    final double w = s.width, h = s.height;
    final double boxR = w * 0.82;
    final double boxB = kind == InstrumentShape.sorPiston ? h * 0.66 : h * 0.6;
    final double cx = boxR / 2;
    _part(c, Rect.fromLTRB(0, 0, boxR, boxB), _sorBlue, radius: boxR * 0.08);
    // 뚜껑 나사 4개
    final double sr = math.min(boxR, boxB) * 0.035;
    for (final dx in [0.1, 0.9]) {
      for (final dy in [0.08, 0.84]) {
        _circle(c, Offset(boxR * dx, boxB * dy), sr, _body);
      }
    }
    // 오른쪽 배관 허브
    _part(
      c,
      Rect.fromLTRB(boxR, boxB * 0.42, w, boxB * 0.62),
      _metal,
      radius: 1,
    );
    // 아래 양쪽 귀(긴 구멍)
    for (final left in [true, false]) {
      final Rect ear = left
          ? Rect.fromLTRB(0, boxB * 0.9, boxR * 0.2, boxB + h * 0.03)
          : Rect.fromLTRB(boxR * 0.8, boxB * 0.9, boxR, boxB + h * 0.03);
      _part(c, ear, _sorBlue, radius: 2);
    }
    final double neckW = boxR * 0.4;
    Rect hex(double top, double bottom) =>
        Rect.fromLTRB(cx - boxR * 0.15, h * top, cx + boxR * 0.15, h * bottom);
    Rect thread(double top) =>
        Rect.fromLTRB(cx - boxR * 0.075, h * top, cx + boxR * 0.075, h);
    switch (kind) {
      case InstrumentShape.sorWide:
        _part(
          c,
          Rect.fromLTRB(cx - neckW / 2, boxB, cx + neckW / 2, h * 0.7),
          _metal,
          radius: 0,
        );
        final Rect disc = Rect.fromLTRB(0, h * 0.7, boxR, h * 0.86);
        _part(c, disc, _metal, radius: 3);
        for (final px in [0.12, 0.35, 0.65, 0.88]) {
          _circle(
            c,
            Offset(boxR * px, disc.center.dy),
            math.min(boxR, h) * 0.025,
            _body,
          );
        }
        _hexAndThread(c, hex(0.86, 0.93), thread(0.93));
      case InstrumentShape.sorDiaphragm:
        _part(
          c,
          Rect.fromLTRB(cx - neckW / 2, boxB, cx + neckW / 2, h * 0.7),
          _metal,
          radius: 0,
        );
        _part(
          c,
          Rect.fromLTRB(cx - boxR * 0.26, h * 0.7, cx + boxR * 0.26, h * 0.85),
          _metal,
          radius: 4,
        );
        _hexAndThread(c, hex(0.85, 0.93), thread(0.93));
      case InstrumentShape.sorDp:
        _part(
          c,
          Rect.fromLTRB(cx - boxR * 0.15, boxB, cx + boxR * 0.15, h * 0.7),
          _metal,
          radius: 0,
        );
        final Rect body = Rect.fromLTRB(
          cx - boxR * 0.3,
          h * 0.7,
          cx + boxR * 0.3,
          h * 0.92,
        );
        _part(c, body, _metal, radius: 5);
        // 옆 LO, 아래 HI
        _part(
          c,
          Rect.fromLTRB(body.left - boxR * 0.1, h * 0.77, body.left, h * 0.85),
          _metal,
          radius: 0,
        );
        _part(
          c,
          Rect.fromLTRB(cx - boxR * 0.07, h * 0.92, cx + boxR * 0.07, h),
          _metal,
          radius: 0,
        );
      default:
        _part(
          c,
          Rect.fromLTRB(cx - neckW / 2, boxB, cx + neckW / 2, h * 0.84),
          _metal,
          radius: 0,
        );
        _hexAndThread(c, hex(0.84, 0.92), thread(0.92));
    }
  }

  // SOR B3·B6(CAT216 p.28): 둥근 뚜껑 약 Ø120 양옆 허브, 아래 설정칸 약 71×72.
  void _sorExp(Canvas c, Size s) {
    final double w = s.width, h = s.height;
    final double hub = w * 0.1;
    final double coverD = math.min(w - hub * 2, h * 0.54);
    final Offset cc = Offset(w / 2, coverD / 2);
    final double hubT = cc.dy - coverD * 0.1, hubB = cc.dy + coverD * 0.1;
    _part(c, Rect.fromLTRB(0, hubT, hub + 2, hubB), _metal, radius: 1);
    _part(c, Rect.fromLTRB(w - hub - 2, hubT, w, hubB), _metal, radius: 1);
    _circle(c, cc, coverD / 2, _sorBlue);
    _circle(c, cc, coverD * 0.38, _body);
    final double boxW = w * 0.48;
    final Rect set = Rect.fromLTRB(
      w / 2 - boxW / 2,
      coverD * 0.95,
      w / 2 + boxW / 2,
      h * 0.8,
    );
    _part(c, set, _sorBlue, radius: 3);
    final double br = boxW * 0.05;
    for (final dx in [0.14, 0.86]) {
      for (final dy in [0.14, 0.86]) {
        _circle(
          c,
          Offset(set.left + set.width * dx, set.top + set.height * dy),
          br,
          _body,
        );
      }
    }
    _hexAndThread(
      c,
      Rect.fromLTRB(w * 0.4, h * 0.8, w * 0.6, h * 0.9),
      Rect.fromLTRB(w * 0.45, h * 0.9, w * 0.55, h),
    );
  }

  void _duct(Canvas c, Size s) {
    final double w = s.width, h = s.height;
    _part(c, Offset.zero & s, _metal, radius: 1);
    // 양쪽 벽 두께와 빗살 간격(실물 홈 간격 12mm 안팎, 도면 1칸 = 1mm).
    final double wall = math.min(w * 0.2, 10);
    final double pitch = math.max(12, h / 40);
    final Paint slot = _line..strokeWidth = math.max(1, strokeWidth * 0.8);
    for (double y = pitch; y < h - pitch / 2; y += pitch) {
      c.drawLine(Offset(0, y), Offset(wall, y), slot);
      c.drawLine(Offset(w - wall, y), Offset(w, y), slot);
    }
    // 가운데 뚜껑
    _part(c, Rect.fromLTRB(wall, 0, w - wall, h), _body, radius: 0);
  }

  @override
  bool shouldRepaint(covariant InstrumentShapePainter old) =>
      old.shape != shape ||
      old.stroke != stroke ||
      old.strokeWidth != strokeWidth;
}
