import 'dart:math' as math;

import 'package:flutter/material.dart';

// 🚀 배치도 계기 모듈의 정면 모양. 제조사 치수 도면(GS·PDS·카탈로그)의 앞 그림을 보고
// 몸통·뚜껑·목·플랜지·육각·포크의 자리와 비율을 옮겼다. 치수를 재는 그림이 아니라
// 알아보기 위한 그림이다(외곽은 모듈 가로×세로 그대로). 비율은 그림 안에서 0~1로 적는다.

/// 계기 모양 종류. ModulePreset·PlacedItem의 shape 칸에 이 이름을 적는다.
class InstrumentShape {
  // ── 모델별 모양(제조사 도면을 따른 것) ──
  /// 로즈마운트 3051C·2051C 코플래너(PDS 00813-0100-4001 Fig.8).
  static const String rmCoplanar = 'rm_coplanar';

  /// 로즈마운트 3051C 재래식 플랜지(Fig.12): 왼쪽 드레인·벤트, 양옆 플랜지판.
  static const String rmTraditional = 'rm_trad';

  /// 로즈마운트 3051T·2051T 인라인(Fig.15): 브래킷 보스 둘, 아래 육각.
  static const String rmInline = 'rm_inline';

  /// 오토롤 APT3100(C3100 p.12): 앞에서 보이는 타원 플랜지 둘(L·H).
  static const String autrolDp = 'autrol_dp';

  /// 오토롤 APT3200(C3200 p.8): 몸통 아래 목·육각.
  static const String autrolPt = 'autrol_pt';

  /// 요꼬가와 EJA 수평 배관(GS p.14 F05E): 위 몸통(Ø78 창), 아래 타원 플랜지 둘.
  static const String ykHorizontal = 'yk_horizontal';

  /// 요꼬가와 EJA 수직 배관(GS p.14 F04E): 왼쪽 캡슐(아래로 접속구), 오른쪽 몸통.
  static const String ykVertical = 'yk_vertical';

  /// 요꼬가와 EJA530E 인라인(GS p.11).
  static const String ykInline = 'yk_inline';

  /// 로즈마운트 2120 알루미늄 통(PDS p.23 B): 옆에서 본 통, 오른쪽 케이블 입구.
  static const String fork2120 = 'fork_2120';

  /// 로즈마운트 2120 나일론 통(PDS p.23 A): 오른쪽 글랜드가 길게 나옴.
  static const String fork2120Nylon = 'fork_2120n';

  /// 로즈마운트 2130 표준(2130***M).
  static const String fork2130 = 'fork_2130';

  /// 로즈마운트 2130 고온 긴 목(2130***E).
  static const String fork2130Long = 'fork_2130e';

  // ── 예전 이름(저장된 배치도에 남아 있다) ──
  static const String dp = 'dp';
  static const String gp = 'gp';
  static const String dpTraditional = 'dp_trad';
  static const String dpSide = 'dp_side';
  static const String inline = 'inline';
  static const String fork = 'fork';

  /// ABS 배선 덕트: 양쪽 벽에 빗살(전선 빼는 홈), 가운데 뚜껑. 원래 세로로 길다.
  static const String duct = 'duct';

  /// 비카 MA 방폭 압력 스위치(PV 31.11 p.8): 옆에서 본 청색 통, 왼쪽 케이블 입구.
  static const String exdSwitch = 'exd_switch';

  /// SOR 방수형(NN·RN, CAT216 p.21·22): 네모 상자, 아래 피스톤 목·육각.
  static const String sorPiston = 'sor_piston';

  /// SOR 작은 다이어프램(4·54).
  static const String sorDiaphragm = 'sor_diaphragm';

  /// SOR 저압 넓은 다이어프램(12·52, Ø94.5 원판).
  static const String sorWide = 'sor_wide';

  /// SOR 101 차압(CAT468 p.14).
  static const String sorDp = 'sor_dp';

  /// SOR 방폭(B3·B6, CAT216 p.28): 둥근 뚜껑, 아래 네모 설정칸.
  static const String sorExp = 'sor_exp';

  // ── 튜브 피팅(하이록 H-200TF·스웨즈락 MS-01-140, 옆에서 본 모습) ──
  static const String fitUnion = 'fit_union';
  static const String fitElbow = 'fit_elbow';
  static const String fitTee = 'fit_tee';
  static const String fitCross = 'fit_cross';
  static const String fitMale = 'fit_male';
  static const String fitMaleElbow = 'fit_male_elbow';
  static const String fitBulkhead = 'fit_bulkhead';

  // ── 매니폴드·게이지 밸브(정면, 손잡이 다 연 상태) ──
  static const String mv2 = 'mv2';
  static const String mv3 = 'mv3';
  static const String mv3Flange = 'mv3_flange';
  static const String mv5 = 'mv5';
  static const String mv5Flange = 'mv5_flange';
  static const String gv1 = 'gv1';
  static const String gv2 = 'gv2';
  static const String swV2 = 'sw_v2';
  static const String swV3 = 'sw_v3';
  static const String swV5 = 'sw_v5';

  static const Set<String> _landscape = {
    mv2,
    mv3,
    mv3Flange,
    mv5,
    mv5Flange,
    swV2,
    swV3,
    swV5,
    dpSide,
    ykVertical,
    exdSwitch,
    fitUnion,
    fitTee,
    fitMale,
    fitMaleElbow,
    fitBulkhead,
  };

  /// 원래 가로가 긴 모양인지(돌려 놓았는지 가리는 데 쓴다).
  static bool isLandscape(String shape) => _landscape.contains(shape);
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
  static const Color _sorBlue = Color(0xFFCFE3F3);
  static const Color _maBlue = Color(0xFFD6E4F5);

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
    final _Box b = _Box(canvas, s);
    switch (shape) {
      case InstrumentShape.rmCoplanar:
      case InstrumentShape.dp:
      case InstrumentShape.gp:
        _rmCoplanar(b);
      case InstrumentShape.rmTraditional:
      case InstrumentShape.dpTraditional:
        _rmTraditional(b);
      case InstrumentShape.rmInline:
      case InstrumentShape.inline:
        _rmInline(b);
      case InstrumentShape.autrolDp:
        _autrolDp(b);
      case InstrumentShape.autrolPt:
        _autrolPt(b);
      case InstrumentShape.ykHorizontal:
        _ykHorizontal(b);
      case InstrumentShape.ykVertical:
      case InstrumentShape.dpSide:
        _ykVertical(b);
      case InstrumentShape.ykInline:
        _ykInline(b);
      case InstrumentShape.fork2120:
      case InstrumentShape.fork:
        _fork(b, gland: false, longNeck: false);
      case InstrumentShape.fork2120Nylon:
        _fork(b, gland: true, longNeck: false);
      case InstrumentShape.fork2130:
        _fork(b, gland: false, longNeck: false, sideEntry: true);
      case InstrumentShape.fork2130Long:
        _fork(b, gland: false, longNeck: true, sideEntry: true);
      case InstrumentShape.duct:
        _duct(b);
      case InstrumentShape.exdSwitch:
        _exdSwitch(b);
      case InstrumentShape.sorPiston:
      case InstrumentShape.sorDiaphragm:
      case InstrumentShape.sorWide:
      case InstrumentShape.sorDp:
        _sorBox(b, shape);
      case InstrumentShape.sorExp:
        _sorExp(b);
      case InstrumentShape.fitUnion:
        _fitUnion(b);
      case InstrumentShape.fitElbow:
        _fitElbow(b);
      case InstrumentShape.fitTee:
        _fitTee(b);
      case InstrumentShape.fitCross:
        _fitCross(b);
      case InstrumentShape.fitMale:
        _fitMale(b);
      case InstrumentShape.fitMaleElbow:
        _fitMaleElbow(b);
      case InstrumentShape.fitBulkhead:
        _fitBulkhead(b);
      case InstrumentShape.mv2:
        _mv2(b);
      case InstrumentShape.mv3:
        _mv35(b, five: false);
      case InstrumentShape.mv3Flange:
        _mv35(b, five: false, flange: true);
      case InstrumentShape.mv5:
        _mv35(b, five: true);
      case InstrumentShape.mv5Flange:
        _mv35(b, five: true, flange: true);
      case InstrumentShape.gv1:
        _gv1(b);
      case InstrumentShape.gv2:
        _gv2(b);
      case InstrumentShape.swV2:
        _swV(b, 2);
      case InstrumentShape.swV3:
        _swV(b, 3);
      case InstrumentShape.swV5:
        _swV(b, 5);
      default:
        _part(canvas, Offset.zero & s, _body, radius: 4);
    }
    canvas.restore();
  }

  Paint get _line => Paint()
    ..color = stroke
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth;

  Paint get _thin => Paint()
    ..color = stroke
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.6, strokeWidth * 0.6);

  void _part(Canvas c, Rect r, Color fill, {double radius = 2}) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    c.drawRRect(rr, Paint()..color = fill);
    c.drawRRect(rr, _line);
  }

  void _circle(Canvas c, Offset center, double r, Color fill) {
    c.drawCircle(center, r, Paint()..color = fill);
    c.drawCircle(center, r, _line);
  }

  void _oval(Canvas c, Rect r, Color fill) {
    c.drawOval(r, Paint()..color = fill);
    c.drawOval(r, _line);
  }

  void _poly(Canvas c, List<Offset> pts, Color fill) {
    final p = Path()..addPolygon(pts, true);
    c.drawPath(p, Paint()..color = fill);
    c.drawPath(p, _line);
  }

  /// 둥근 나사 뚜껑: 바깥 원, 안쪽 원, 둘레에 손잡이 홈 8개.
  void _ribCover(Canvas c, Offset center, double r, {bool lcd = false}) {
    _circle(c, center, r, _body);
    for (int i = 0; i < 8; i++) {
      final double a = i * math.pi / 4 + math.pi / 8;
      c.drawLine(
        center + Offset(math.cos(a), math.sin(a)) * r * 0.8,
        center + Offset(math.cos(a), math.sin(a)) * r,
        _thin,
      );
    }
    _circle(c, center, r * 0.78, _glass);
    if (lcd) {
      _part(
        c,
        Rect.fromCenter(center: center, width: r * 0.9, height: r * 0.55),
        _body,
        radius: 1,
      );
    } else {
      _circle(c, center, r * 0.5, _body);
    }
  }

  /// 육각(세로 줄 둘로 면을 나눈다).
  void _hex(Canvas c, Rect hex) {
    _part(c, hex, _metal, radius: 1);
    final double third = hex.width / 3;
    for (final x in [hex.left + third, hex.right - third]) {
      c.drawLine(Offset(x, hex.top), Offset(x, hex.bottom), _thin);
    }
  }

  /// 나사(빗금).
  void _thread(Canvas c, Rect t) {
    _part(c, t, _metal, radius: 0);
    final int n = math.max(2, (t.height / 5).floor());
    for (int i = 1; i < n; i++) {
      final double y = t.top + t.height * i / n;
      c.drawLine(Offset(t.left, y + 1.2), Offset(t.right, y - 1.2), _thin);
    }
  }

  // ───────────────────────── 로즈마운트 3051·2051 ─────────────────────────

  /// 로즈마운트 몸통: 둥근 뚜껑 + 위 양쪽 배관 귀(사다리꼴) + 아래 띠.
  void _rmHousing(_Box b, double l, double t, double r, double bottom) {
    final Canvas c = b.c;
    final double w = (r - l) * b.w;
    // 위 양쪽 귀
    for (final left in [true, false]) {
      final double x0 = left ? l : r - 0.2 * (r - l);
      final double x1 = left ? l + 0.2 * (r - l) : r;
      final double inner = left ? x1 : x0;
      final double outer = left ? x0 : x1;
      _poly(c, [
        b.p(outer, t + 0.02),
        b.p(inner, t),
        b.p(inner, t + (bottom - t) * 0.45),
        b.p(outer, t + (bottom - t) * 0.38),
      ], _metal);
    }
    _part(
      c,
      b.r(
        l + 0.14 * (r - l),
        t + (bottom - t) * 0.04,
        r - 0.14 * (r - l),
        bottom,
      ),
      _body,
      radius: 3,
    );
    final double rad = math.min(w * 0.4, (bottom - t) * b.h * 0.47);
    _ribCover(c, b.p((l + r) / 2, t + (bottom - t) * 0.5), rad);
  }

  /// 전자부 목(네모)과 아래 가운데 접지 나사.
  void _rmModule(_Box b, double l, double t, double r, double bottom) {
    _part(b.c, b.r(l, t, r, bottom), _body, radius: 1);
    _circle(
      b.c,
      b.p((l + r) / 2, bottom - (bottom - t) * 0.18),
      math.min(b.w, b.h) * 0.03,
      _metal,
    );
  }

  void _rmCoplanar(_Box b) {
    _rmHousing(b, 0, 0, 1, 0.45);
    _rmModule(b, 0.19, 0.45, 0.83, 0.63);
    // 센서 몸통(V 홈 둘)과 코플래너 플랜지
    _part(b.c, b.r(0.2, 0.63, 0.82, 0.74), _metal, radius: 1);
    for (final x in [0.33, 0.69]) {
      _poly(b.c, [
        b.p(x - 0.07, 0.63),
        b.p(x + 0.07, 0.63),
        b.p(x, 0.71),
      ], _body);
    }
    _part(b.c, b.r(0.2, 0.74, 0.82, 0.93), _metal, radius: 2);
    _circle(b.c, b.p(0.46, 0.85), math.min(b.w, b.h) * 0.06, _body);
    // 볼트 머리 둘
    _part(b.c, b.r(0.24, 0.93, 0.37, 1), _metal, radius: 1);
    _part(b.c, b.r(0.65, 0.93, 0.78, 1), _metal, radius: 1);
  }

  void _rmTraditional(_Box b) {
    // Fig.12: 왼쪽 드레인·벤트 29, 플랜지 86. 몸통은 플랜지 위 가운데.
    _rmHousing(b, 0.14, 0, 1, 0.41);
    _rmModule(b, 0.3, 0.41, 0.86, 0.58);
    _part(b.c, b.r(0.33, 0.58, 0.83, 0.66), _metal, radius: 1);
    // 가운데 몸통과 양옆 재래식 플랜지판(볼트 머리)
    _part(b.c, b.r(0.36, 0.66, 0.8, 0.88), _metal, radius: 1);
    for (final x in [0.26, 0.8]) {
      _part(b.c, b.r(x, 0.62, x + 0.1, 0.94), _metal, radius: 2);
      _part(b.c, b.r(x + 0.1, 0.66, x + 0.14, 0.72), _body, radius: 1);
      _part(b.c, b.r(x + 0.1, 0.84, x + 0.14, 0.9), _body, radius: 1);
    }
    // 왼쪽 드레인·벤트 밸브
    _part(b.c, b.r(0.1, 0.75, 0.26, 0.81), _metal, radius: 1);
    _part(b.c, b.r(0, 0.74, 0.1, 0.82), _metal, radius: 1);
  }

  void _rmInline(_Box b) {
    _rmHousing(b, 0, 0, 1, 0.45);
    _rmModule(b, 0.19, 0.45, 0.83, 0.64);
    // 브래킷 보스 둘(작은 구멍)
    _part(b.c, b.r(0.3, 0.64, 0.66, 0.79), _metal, radius: 6);
    _circle(b.c, b.p(0.38, 0.715), math.min(b.w, b.h) * 0.035, _body);
    _circle(b.c, b.p(0.58, 0.715), math.min(b.w, b.h) * 0.035, _body);
    _part(b.c, b.r(0.42, 0.79, 0.54, 0.84), _metal, radius: 0);
    _hex(b.c, b.r(0.34, 0.84, 0.62, 1));
  }

  // ───────────────────────── 오토롤 ─────────────────────────

  /// 오토롤 몸통: 네모 몸통 위 작은 귀, 큰 둥근 뚜껑 안 LCD, 아래 띠(접지 보스).
  void _autrolHousing(_Box b, double bottom) {
    final double coverB = bottom * 0.78;
    _part(b.c, b.r(0.02, 0.04 * bottom, 0.98, coverB), _body, radius: 3);
    _part(b.c, b.r(0.08, 0, 0.18, 0.05 * bottom), _metal, radius: 1);
    _part(b.c, b.r(0.82, 0, 0.92, 0.05 * bottom), _metal, radius: 1);
    final double rad = math.min(b.w * 0.46, coverB * b.h * 0.47);
    _ribCover(b.c, b.p(0.5, coverB * 0.52), rad, lcd: true);
    _part(b.c, b.r(0.1, coverB, 0.9, bottom), _body, radius: 1);
    _circle(
      b.c,
      b.p(0.5, bottom - (bottom - coverB) * 0.35),
      math.min(b.w, b.h) * 0.05,
      _metal,
    );
  }

  /// 앞에서 보이는 타원 플랜지(볼트 구멍 위아래, 가운데 접속구).
  void _ovalFlange(_Box b, double l, double t, double r, double bottom) {
    _oval(b.c, b.r(l, t, r, bottom), _metal);
    final double cx = (l + r) / 2;
    final double rr = math.min((r - l) * b.w, (bottom - t) * b.h) * 0.13;
    _circle(b.c, b.p(cx, t + (bottom - t) * 0.2), rr, _body);
    _circle(b.c, b.p(cx, t + (bottom - t) * 0.8), rr, _body);
    _circle(b.c, b.p(cx, (t + bottom) / 2), rr * 1.5, _body);
    _circle(b.c, b.p(cx, (t + bottom) / 2), rr * 0.8, _metal);
  }

  void _autrolDp(_Box b) {
    // C3100 p.12: 몸통 114 / 캡슐 80(합 194).
    _autrolHousing(b, 0.59);
    _part(b.c, b.r(0.4, 0.59, 0.6, 0.66), _metal, radius: 0);
    _part(b.c, b.r(0.1, 0.66, 0.9, 0.98), _metal, radius: 2);
    _ovalFlange(b, 0, 0.64, 0.34, 1);
    _ovalFlange(b, 0.66, 0.64, 1, 1);
  }

  void _autrolPt(_Box b) {
    // C3200 p.8: 몸통 114 / 전체 160.
    _autrolHousing(b, 0.71);
    _part(b.c, b.r(0.33, 0.71, 0.67, 0.86), _metal, radius: 1);
    _hex(b.c, b.r(0.3, 0.86, 0.7, 0.93));
    _thread(b.c, b.r(0.4, 0.93, 0.6, 1));
  }

  // ───────────────────────── 요꼬가와 EJA ─────────────────────────

  /// 요꼬가와 몸통을 정면에서: 네모 몸통 위 Ø78 창 뚜껑, 오른쪽 위 배관 입구.
  void _ykHousingFront(_Box b, double l, double t, double r, double bottom) {
    _part(b.c, b.r(l, t + (bottom - t) * 0.05, r, bottom), _body, radius: 4);
    _part(
      b.c,
      b.r(r - 0.1 * (r - l), t + (bottom - t) * 0.1, r, t + (bottom - t) * 0.3),
      _metal,
      radius: 1,
    );
    final double rad = math.min((r - l) * b.w * 0.42, (bottom - t) * b.h * 0.5);
    final Offset cc = b.p((l + r) / 2, t + (bottom - t) * 0.5);
    _ribCover(b.c, cc, rad, lcd: true);
  }

  void _ykHorizontal(_Box b) {
    // F05E: 위 몸통 약 95폭, 아래 캡슐 + 앞으로 보이는 접속구 둘.
    _ykHousingFront(b, 0.08, 0, 0.92, 0.5);
    _part(b.c, b.r(0.4, 0.5, 0.6, 0.56), _metal, radius: 0);
    _part(b.c, b.r(0.12, 0.56, 0.88, 0.92), _metal, radius: 3);
    _ovalFlange(b, 0.02, 0.56, 0.4, 0.92);
    _ovalFlange(b, 0.6, 0.56, 0.98, 0.92);
    // 아래 배수 플러그
    _part(b.c, b.r(0.2, 0.92, 0.28, 1), _metal, radius: 1);
    _part(b.c, b.r(0.72, 0.92, 0.8, 1), _metal, radius: 1);
  }

  void _ykVertical(_Box b) {
    // F04E(원래 가로): 왼쪽 캡슐(접속구 아래로), 가운데 목, 오른쪽 몸통(Ø78 뚜껑).
    _part(b.c, b.r(0.02, 0.18, 0.4, 0.84), _metal, radius: 3);
    b.c.drawLine(b.p(0.21, 0.18), b.p(0.21, 0.84), _thin);
    for (final x in [0.1, 0.32]) {
      for (final y in [0.26, 0.76]) {
        _circle(b.c, b.p(x, y), math.min(b.w, b.h) * 0.03, _body);
      }
    }
    _part(b.c, b.r(0.08, 0.84, 0.16, 1), _metal, radius: 0);
    _part(b.c, b.r(0.26, 0.84, 0.34, 1), _metal, radius: 0);
    _part(b.c, b.r(0.4, 0.4, 0.5, 0.6), _metal, radius: 0);
    // 옆에서 본 몸통: 앞 뚜껑(창) 쪽이 왼쪽, 단자함 뚜껑이 오른쪽.
    _part(b.c, b.r(0.5, 0.08, 0.98, 0.82), _body, radius: 5);
    _ribCover(
      b.c,
      b.p(0.74, 0.45),
      math.min(b.w * 0.22, b.h * 0.37),
      lcd: true,
    );
  }

  void _ykInline(_Box b) {
    // GS 01C31F01 p.11: 몸통 126 / 전체 159.
    _ykHousingFront(b, 0.02, 0, 0.98, 0.62);
    _part(b.c, b.r(0.36, 0.62, 0.64, 0.72), _metal, radius: 1);
    _part(b.c, b.r(0.26, 0.72, 0.74, 0.78), _metal, radius: 1);
    _hex(b.c, b.r(0.3, 0.78, 0.7, 0.88));
    _thread(b.c, b.r(0.4, 0.88, 0.6, 1));
  }

  // ───────────────────────── 로즈마운트 2120·2130 포크 ─────────────────────────

  /// 옆에서 본 통: 위 톱니 뚜껑, 아래로 좁아지는 몸통, 옆 케이블 입구, 목·육각·나사·포크.
  void _fork(
    _Box b, {
    required bool gland,
    required bool longNeck,
    bool sideEntry = false,
  }) {
    final Canvas c = b.c;
    final double h = b.h;
    // 포크 69mm(도면 1칸 = 1mm), 작게 줄였을 때는 비율로.
    final double forkT = 1 - math.min(69, h * 0.32) / h;
    final double headB = longNeck ? 0.2 : (gland ? 0.5 : 0.48);
    final double bodyR = gland ? 0.78 : 0.86;
    final double bodyL = gland ? 0.06 : 0.06;
    // 뚜껑(톱니)
    final double lidB = headB * 0.28;
    _part(c, b.r(bodyL, 0, bodyR, lidB), _body, radius: 3);
    final int ribs = 9;
    for (int i = 1; i < ribs; i++) {
      final double x = bodyL + (bodyR - bodyL) * i / ribs;
      c.drawLine(b.p(x, lidB * 0.2), b.p(x, lidB * 0.85), _thin);
    }
    _part(
      c,
      b.r(bodyL - 0.02, lidB, bodyR + 0.02, lidB * 1.25),
      _metal,
      radius: 1,
    );
    // 몸통(아래로 좁아짐)
    _poly(c, [
      b.p(bodyL + 0.02, lidB * 1.25),
      b.p(bodyR - 0.02, lidB * 1.25),
      b.p(bodyR - 0.02, headB * 0.8),
      b.p((bodyL + bodyR) / 2 + 0.14, headB),
      b.p((bodyL + bodyR) / 2 - 0.14, headB),
      b.p(bodyL + 0.02, headB * 0.8),
    ], _body);
    final double cx = (bodyL + bodyR) / 2;
    // 케이블 입구
    if (gland) {
      _part(
        c,
        b.r(bodyR - 0.02, headB * 0.5, 0.92, headB * 0.64),
        _metal,
        radius: 1,
      );
      _part(c, b.r(0.92, headB * 0.47, 1, headB * 0.67), _metal, radius: 1);
    } else {
      final Offset e = sideEntry
          ? b.p(bodyR - 0.02, headB * 0.5)
          : b.p(bodyR - 0.02, headB * 0.5);
      final double er = math.min(b.w * 0.12, h * headB * 0.12);
      _circle(c, e, er, _metal);
      _circle(c, e, er * 0.55, _body);
    }
    // 목(고온형은 길다)
    final double hexT = forkT - 0.1;
    if (hexT > headB) {
      _part(c, b.r(cx - 0.1, headB, cx + 0.1, hexT), _metal, radius: 0);
    }
    _hex(c, b.r(cx - 0.17, hexT, cx + 0.17, hexT + 0.045));
    _thread(c, b.r(cx - 0.12, hexT + 0.045, cx + 0.12, forkT));
    // 두 갈래 포크(가늘게)
    for (final dx in [-0.05, 0.05]) {
      _part(
        c,
        b.r(cx + dx - 0.035, forkT, cx + dx + 0.035, 1),
        _metal,
        radius: b.w * 0.035,
      );
    }
  }

  // ───────────────────────── 덕트·스위치 ─────────────────────────

  void _duct(_Box b) {
    final Canvas c = b.c;
    final double w = b.w, h = b.h;
    _part(c, Offset.zero & Size(w, h), _metal, radius: 1);
    // 양쪽 벽 두께와 빗살 간격(실물 홈 간격 20~25mm, 도면 1칸 = 1mm).
    final double wall = math.min(w * 0.2, 10);
    final double pitch = math.max(12, h / 40);
    for (double y = pitch; y < h - pitch / 2; y += pitch) {
      c.drawLine(Offset(0, y), Offset(wall, y), _thin);
      c.drawLine(Offset(w - wall, y), Offset(w, y), _thin);
    }
    _part(c, Rect.fromLTRB(wall, 0, w - wall, h), _body, radius: 0);
  }

  // 비카 MA 정면(PV 31.11 p.8 왼쪽 그림): 가운데 선이 왼쪽에서 87/161 자리.
  void _exdSwitch(_Box b) {
    final double cx = 87 / 161;
    _part(b.c, b.r(0.36, 0, 0.82, 0.1), _maBlue, radius: 2);
    _part(b.c, b.r(0.14, 0.08, 1, 0.2), _maBlue, radius: 2);
    _part(b.c, b.r(0.14, 0.2, 1, 0.78), _maBlue, radius: 3);
    _part(b.c, b.r(0, 0.4, 0.15, 0.64), _metal, radius: 2);
    _circle(b.c, b.p(0.075, 0.52), math.min(b.w, b.h) * 0.05, _body);
    _part(b.c, b.r(0.9, 0.44, 0.97, 0.6), _body);
    final Rect base = b.r(0.12, 0.78, 1, 0.86);
    _part(b.c, base, _metal, radius: 1);
    for (final px in [0.22, 0.4, 0.72, 0.9]) {
      b.c.drawLine(b.p(px, 0.78), b.p(px, 0.86), _thin);
    }
    _hex(b.c, b.r(cx - 0.08, 0.86, cx + 0.08, 0.93));
    _thread(b.c, b.r(cx - 0.04, 0.93, cx + 0.04, 1));
  }

  // SOR NN·RN(CAT216 p.21·22): 앞에서는 뚜껑 판(나사 4개·안쪽 테두리)과
  // 상자 아래 양쪽 긴 구멍만 보인다. 배관 허브는 옆면이라 앞에서 안 보인다.
  void _sorBox(_Box b, String kind) {
    final bool piston = kind == InstrumentShape.sorPiston;
    final double boxB = piston ? 0.63 : 0.6;
    _part(b.c, b.r(0, 0, 1, boxB), _sorBlue, radius: b.w * 0.07);
    _part(
      b.c,
      b.r(0.1, boxB * 0.08, 0.9, boxB * 0.72),
      _sorBlue,
      radius: b.w * 0.04,
    );
    final double sr = math.min(b.w, b.h) * 0.03;
    for (final dx in [0.06, 0.94]) {
      for (final dy in [0.05, 0.78]) {
        _circle(b.c, b.p(dx, boxB * dy), sr, _body);
      }
    }
    // 아래 양쪽 긴 구멍(설치용)
    for (final x in [0.1, 0.66]) {
      _oval(b.c, b.r(x, boxB * 0.82, x + 0.24, boxB * 0.95), _body);
    }
    const double cx = 0.5;
    switch (kind) {
      case InstrumentShape.sorWide:
        _part(b.c, b.r(0.36, boxB, 0.64, 0.7), _metal, radius: 0);
        _part(b.c, b.r(0.06, 0.7, 0.94, 0.85), _metal, radius: 3);
        for (final px in [0.14, 0.38, 0.62, 0.86]) {
          _circle(b.c, b.p(px, 0.83), math.min(b.w, b.h) * 0.02, _body);
        }
        _hex(b.c, b.r(cx - 0.12, 0.85, cx + 0.12, 0.92));
        _thread(b.c, b.r(cx - 0.06, 0.92, cx + 0.06, 1));
      case InstrumentShape.sorDiaphragm:
        _part(b.c, b.r(0.36, boxB, 0.64, 0.68), _metal, radius: 0);
        _part(b.c, b.r(0.25, 0.68, 0.75, 0.84), _metal, radius: 6);
        _hex(b.c, b.r(cx - 0.12, 0.84, cx + 0.12, 0.92));
        _thread(b.c, b.r(cx - 0.06, 0.92, cx + 0.06, 1));
      case InstrumentShape.sorDp:
        _part(b.c, b.r(0.4, boxB, 0.6, 0.66), _metal, radius: 0);
        _hex(b.c, b.r(0.36, 0.66, 0.64, 0.71));
        _part(b.c, b.r(0.22, 0.71, 0.78, 0.92), _metal, radius: 6);
        _part(b.c, b.r(0.1, 0.77, 0.22, 0.86), _metal, radius: 0);
        _part(b.c, b.r(cx - 0.06, 0.92, cx + 0.06, 1), _metal, radius: 0);
      default:
        _part(b.c, b.r(0.34, boxB, 0.66, 0.9), _metal, radius: 0);
        _hex(b.c, b.r(cx - 0.16, 0.9, cx + 0.16, 0.96));
        _thread(b.c, b.r(cx - 0.07, 0.96, cx + 0.07, 1));
    }
  }

  // SOR B3·B6(CAT216 p.28): 둥근 뚜껑과 양옆 보스, 아래 설정칸(구멍 4), 목, 육각.
  void _sorExp(_Box b) {
    _part(b.c, b.r(0, 0.2, 0.14, 0.3), _metal, radius: 1);
    _part(b.c, b.r(0.86, 0.2, 1, 0.3), _metal, radius: 1);
    final double rad = math.min(b.w * 0.4, b.h * 0.24);
    final Offset cc = b.p(0.5, 0.25);
    _circle(b.c, cc, rad, _sorBlue);
    _circle(b.c, cc, rad * 0.86, _sorBlue);
    // 뚜껑 위 긴 구멍 무늬
    for (final dx in [-0.35, 0.35]) {
      for (final dy in [-0.4, 0.0, 0.4]) {
        _oval(
          b.c,
          Rect.fromCenter(
            center: cc + Offset(dx * rad, dy * rad),
            width: rad * 0.18,
            height: rad * 0.3,
          ),
          _body,
        );
      }
    }
    final Rect set = b.r(0.24, 0.5, 0.76, 0.72);
    _part(b.c, set, _sorBlue, radius: 3);
    for (final dx in [0.3, 0.7]) {
      for (final dy in [0.54, 0.68]) {
        _circle(b.c, b.p(dx, dy), math.min(b.w, b.h) * 0.02, _body);
      }
    }
    _part(b.c, b.r(0.39, 0.72, 0.61, 0.9), _metal, radius: 0);
    _hex(b.c, b.r(0.36, 0.9, 0.64, 0.96));
    _thread(b.c, b.r(0.44, 0.96, 0.56, 1));
  }

  // ───────────────────────── 튜브 피팅(하이록·스웨즈락) ─────────────────────────
  // 옆에서 본 모습: 너트(육각, 면 셋)·몸통 육각·나사. 너트 길이는 관 1/4" 12.7,
  // 3/8" 14.2, 1/2" 17.5(두 회사 같다). 비율은 모듈 가로·세로에서 잡는다.

  /// 축이 가로인 육각(모서리 방향으로 본 면 셋: 가로 줄 둘).
  void _hexH(Canvas c, Rect r) {
    _part(c, r, _metal, radius: 1);
    for (final y in [r.top + r.height * 0.25, r.bottom - r.height * 0.25]) {
      c.drawLine(Offset(r.left, y), Offset(r.right, y), _thin);
    }
  }

  /// 축이 세로인 육각(세로 줄 둘).
  void _hexV(Canvas c, Rect r) {
    _part(c, r, _metal, radius: 1);
    for (final x in [r.left + r.width * 0.25, r.right - r.width * 0.25]) {
      c.drawLine(Offset(x, r.top), Offset(x, r.bottom), _thin);
    }
  }

  /// 가로 나사(세로 빗금).
  void _threadH(Canvas c, Rect t) {
    _part(c, t, _metal, radius: 0);
    final int n = math.max(2, (t.width / 4).floor());
    for (int i = 1; i < n; i++) {
      final double x = t.left + t.width * i / n;
      c.drawLine(Offset(x - 1, t.top), Offset(x + 1, t.bottom), _thin);
    }
  }

  // 유니언: 너트 | 몸통 육각 | 너트 (CUA / -6).
  void _fitUnion(_Box b) {
    const double nut = 0.31;
    _hexH(b.c, b.r(0, 0, nut, 1));
    _hexH(b.c, b.r(1 - nut, 0, 1, 1));
    _hexH(b.c, b.r(nut, 0.06, 1 - nut, 0.94));
  }

  // 유니언 엘보: 왼쪽 위 몸통, 오른쪽·아래로 너트 (CLA / -9).
  void _fitElbow(_Box b) {
    const double body = 0.38, nut = 0.38;
    _part(b.c, b.r(body, body * 0.15, 1 - nut, body * 0.85), _metal, radius: 0);
    _part(b.c, b.r(body * 0.15, body, body * 0.85, 1 - nut), _metal, radius: 0);
    _part(b.c, b.r(0, 0, body, body), _metal, radius: 2);
    _hexH(b.c, b.r(1 - nut, -0.04, 1, body + 0.04));
    _hexV(b.c, b.r(-0.04, 1 - nut, body + 0.04, 1));
  }

  // 유니언 티: 가운데 위 몸통, 양옆·아래로 너트 (CTA / -3).
  void _fitTee(_Box b) {
    // 원래 가로가 길다(2A × (A+h/2)).
    const double nutW = 0.24;
    final double body = 0.38 * b.h / b.w; // 몸통 폭(가로 비율)
    const double bodyH = 0.38;
    _part(
      b.c,
      b.r(nutW, bodyH * 0.15, 1 - nutW, bodyH * 0.85),
      _metal,
      radius: 0,
    );
    _part(
      b.c,
      b.r(0.5 - body * 0.35, bodyH, 0.5 + body * 0.35, 0.62),
      _metal,
      radius: 0,
    );
    _part(
      b.c,
      b.r(0.5 - body / 2, 0, 0.5 + body / 2, bodyH),
      _metal,
      radius: 2,
    );
    _hexH(b.c, b.r(0, -0.04, nutW, bodyH + 0.04));
    _hexH(b.c, b.r(1 - nutW, -0.04, 1, bodyH + 0.04));
    _hexV(b.c, b.r(0.5 - body / 2 - 0.02, 0.62, 0.5 + body / 2 + 0.02, 1));
  }

  // 유니언 크로스: 가운데 몸통, 네 방향 너트 (CXA / -4).
  void _fitCross(_Box b) {
    const double nut = 0.24, body = 0.2;
    _part(
      b.c,
      b.r(nut, 0.5 - body * 0.35, 1 - nut, 0.5 + body * 0.35),
      _metal,
      radius: 0,
    );
    _part(
      b.c,
      b.r(0.5 - body * 0.35, nut, 0.5 + body * 0.35, 1 - nut),
      _metal,
      radius: 0,
    );
    _part(
      b.c,
      b.r(0.5 - body / 2, 0.5 - body / 2, 0.5 + body / 2, 0.5 + body / 2),
      _metal,
      radius: 2,
    );
    _hexH(b.c, b.r(0, 0.5 - body / 2 - 0.02, nut, 0.5 + body / 2 + 0.02));
    _hexH(b.c, b.r(1 - nut, 0.5 - body / 2 - 0.02, 1, 0.5 + body / 2 + 0.02));
    _hexV(b.c, b.r(0.5 - body / 2 - 0.02, 0, 0.5 + body / 2 + 0.02, nut));
    _hexV(b.c, b.r(0.5 - body / 2 - 0.02, 1 - nut, 0.5 + body / 2 + 0.02, 1));
  }

  // 메일 커넥터: 너트 | 몸통 육각 | 수나사 (CMC / -1).
  void _fitMale(_Box b) {
    _hexH(b.c, b.r(0, 0, 0.34, 1));
    _hexH(b.c, b.r(0.34, 0, 0.52, 1));
    _threadH(b.c, b.r(0.52, 0.2, 1, 0.8));
  }

  // 메일 엘보: 왼쪽 너트 → 오른쪽 위 몸통, 아래로 수나사 (CLMA / -2).
  void _fitMaleElbow(_Box b) {
    const double body = 0.34;
    const double nut = 0.36;
    _part(b.c, b.r(nut, body * 0.15, 1 - body, body * 0.85), _metal, radius: 0);
    _part(b.c, b.r(1 - body, 0, 1, body), _metal, radius: 2);
    _hexH(b.c, b.r(0, -0.02, nut, body + 0.02));
    _threadV(b.c, b.r(1 - body * 0.82, body, 1 - body * 0.18, 1));
  }

  /// 세로 나사(가로 빗금).
  void _threadV(Canvas c, Rect t) => _thread(c, t);

  // 벌크헤드 유니언: 너트 | 몸통 육각 | 나사 몸통 + 잠금 너트 | 너트 (CBU / -61).
  void _fitBulkhead(_Box b) {
    const double nut = 0.23;
    _threadH(b.c, b.r(0.33, 0.14, 1 - nut, 0.86));
    _hexH(b.c, b.r(0, 0.05, nut, 0.95));
    _hexH(b.c, b.r(nut, 0, 0.33, 1));
    _hexH(b.c, b.r(0.55, 0, 0.64, 1));
    _hexH(b.c, b.r(1 - nut, 0.05, 1, 0.95));
  }

  // ───────────────────────── 매니폴드·게이지 밸브 ─────────────────────────
  // 하이록 H-120MV(2023)·스웨즈락 MS-02-445 "Front" 그림: 몸통 블록, 옆으로 나온 격리 밸브,
  // 위로 선 균압·벤트 밸브. 손잡이는 다 연 상태(카탈로그 "Open" 치수)로 그린다.

  /// 위로 선 밸브: 보닛 육각 → 가는 축 → 가로 T 손잡이. [x]는 가운데, [top]~[bottom] 세로.
  void _stemUp(
    _Box b,
    double x,
    double top,
    double bottom, {
    bool down = false,
  }) {
    final double len = bottom - top;
    final double bw = 0.1 * b.h / b.w; // 보닛 폭(세로 길이 기준 비율)
    double y(double f) => down ? bottom - len * f : top + len * f;
    Rect span(double f0, double f1, double half) {
      final double a = y(f0), c = y(f1);
      return b.r(x - half, math.min(a, c), x + half, math.max(a, c));
    }

    _hexV(b.c, span(1, 0.62, bw * 0.55));
    _part(b.c, span(0.62, 0.42, bw * 0.4), _metal, radius: 0);
    _part(b.c, span(0.42, 0.34, bw * 0.55), _metal, radius: 1);
    _part(b.c, span(0.34, 0.12, bw * 0.14), _metal, radius: 0);
    _part(b.c, span(0.12, 0, bw * 1.3), _metal, radius: 3);
  }

  /// 옆으로 나온 밸브(격리): 보닛 → 축 → 세로 T 손잡이. [y]는 가운데.
  void _stemSide(_Box b, double y, double from, double to) {
    final bool right = to > from;
    final double len = (to - from).abs();
    final double bh = 0.1 * b.w / b.h;
    double x(double f) => right ? from + len * f : from - len * f;
    Rect span(double f0, double f1, double half) {
      final double a = x(f0), c = x(f1);
      return b.r(math.min(a, c), y - half, math.max(a, c), y + half);
    }

    _hexH(b.c, span(0, 0.38, bh * 0.55));
    _part(b.c, span(0.38, 0.58, bh * 0.4), _metal, radius: 0);
    _part(b.c, span(0.58, 0.66, bh * 0.55), _metal, radius: 1);
    _part(b.c, span(0.66, 0.88, bh * 0.14), _metal, radius: 0);
    _part(b.c, span(0.88, 1, bh * 1.3), _metal, radius: 3);
  }

  /// 블록 앞면의 접속구(나사 구멍).
  void _port(_Box b, double x, double y, double rMm) {
    final double r = math.min(rMm, math.min(b.w, b.h) * 0.12);
    _circle(b.c, b.p(x, y), r, _body);
    _circle(b.c, b.p(x, y), r * 0.45, _metal);
  }

  void _block(
    _Box b,
    double l,
    double t,
    double r,
    double bottom, {
    bool bolts = false,
  }) {
    _part(b.c, b.r(l, t, r, bottom), _metal, radius: 2);
    if (bolts) {
      final double br = math.min(b.w, b.h) * 0.03;
      for (final px in [0.14, 0.86]) {
        for (final py in [0.12, 0.88]) {
          _circle(b.c, b.p(l + (r - l) * px, t + (bottom - t) * py), br, _body);
        }
      }
    }
  }

  // 하이록 VM2VTV8N(p.18 Front 104×85): 왼쪽 블록 51, 위 벤트, 오른쪽 격리.
  void _mv2(_Box b) {
    const double bodyR = 51 / 104, bodyT = 1 - 32 / 85;
    _stemUp(b, bodyR / 2, 0, bodyT);
    _stemSide(b, (bodyT + 1) / 2, bodyR, 1);
    _block(b, 0, bodyT, bodyR, 1);
    _port(b, bodyR / 2, (bodyT + 1) / 2, 10);
  }

  // 하이록 VM3V·VM5V 원격형(p.23·28 Front 192×85): 가운데 블록 86, 양옆 격리.
  void _mv35(_Box b, {required bool five, bool flange = false}) {
    const double bodyL = 53 / 192, bodyR = 139 / 192;
    final double bodyT = flange ? 1 - 62 / (five ? 101 : 96) : 1 - 32 / 85;
    final double midY = (bodyT + 1) / 2;
    if (five) {
      for (final x in [0.37, 0.5, 0.63]) {
        _stemUp(b, x, 0, bodyT);
      }
    } else {
      _stemUp(b, 0.5, 0, bodyT);
    }
    _stemSide(b, midY, bodyL, 0);
    _stemSide(b, midY, bodyR, 1);
    _block(b, bodyL, bodyT, bodyR, 1, bolts: flange);
    _port(b, 0.5 - 27 / 192, midY, 10);
    _port(b, 0.5 + 27 / 192, midY, 10);
    if (five) _port(b, 0.5, midY + (1 - bodyT) * 0.12, 5);
  }

  // 하이록 VGVTVF8N 게이지 밸브(p.11, L 67 × O 69): 육각 몸통 위에 밸브 하나.
  void _gv1(_Box b) {
    const double bodyT = 1 - 32 / 69;
    _stemUp(b, 0.5, 0, bodyT);
    _hexH(b.c, b.r(0, bodyT, 1, 1));
  }

  // 하이록 VGV2TV-F8N 게이지 2밸브(p.13, L 78 × O 138): 위 벤트, 아래 격리.
  void _gv2(_Box b) {
    const double half = 16 / 138;
    _stemUp(b, 0.5, 0, 0.5 - half);
    _stemUp(b, 0.5, 0.5 + half, 1, down: true);
    _part(b.c, b.r(0, 0.5 - half, 1, 0.5 + half), _metal, radius: 1);
    b.c.drawLine(b.p(0.12, 0.5 - half), b.p(0.12, 0.5 + half), _thin);
    b.c.drawLine(b.p(0.88, 0.5 - half), b.p(0.88, 0.5 + half), _thin);
  }

  // 스웨즈락 V 시리즈(MS-02-445 p.6·10·12 Side): 격리 손잡이는 세로 T(블록 높이만큼).
  void _swV(_Box b, int valves) {
    switch (valves) {
      case 2: // SS-V2BF8 97×78: 오른쪽 블록, 왼쪽 격리, 위 벤트
        const double l = 1 - 54 / 97, t = 0.42;
        _stemUp(b, (l + 1) / 2, 0, t);
        _stemSide(b, (t + 1) / 2, l, 0);
        _block(b, l, t, 1, 1);
        _port(b, (l + 1) / 2, (t + 1) / 2, 11);
      case 3: // SS-V3NBF8 229×104
        const double l = 70 / 229, r = 159 / 229, t = 1 - 63.5 / 104;
        _stemUp(b, 0.5, 0, t);
        _stemSide(b, (t + 1) / 2, l, 0);
        _stemSide(b, (t + 1) / 2, r, 1);
        _block(b, l, t, r, 1, bolts: true);
        _port(b, 0.5 - 27 / 229, (t + 1) / 2, 11);
        _port(b, 0.5 + 27 / 229, (t + 1) / 2, 11);
      default: // SS-V5NBF8 226×78
        const double l = 70 / 226, r = 156 / 226, t = 1 - 50.8 / 78;
        for (final x in [0.44, 0.5, 0.56]) {
          _stemUp(b, x, 0, t);
        }
        _stemSide(b, (t + 1) / 2, l, 0);
        _stemSide(b, (t + 1) / 2, r, 1);
        _block(b, l, t, r, 1);
        _port(b, 0.5 - 27 / 226, (t + 1) / 2, 11);
        _port(b, 0.5 + 27 / 226, (t + 1) / 2, 11);
        _port(b, 0.5, (t + 1) / 2, 5);
    }
  }

  @override
  bool shouldRepaint(covariant InstrumentShapePainter old) =>
      old.shape != shape ||
      old.stroke != stroke ||
      old.strokeWidth != strokeWidth;
}

/// 그림 안에서 0~1 비율로 자리를 적는 도우미.
class _Box {
  final Canvas c;
  final double w;
  final double h;
  _Box(this.c, Size s) : w = s.width, h = s.height;

  Offset p(double x, double y) => Offset(w * x, h * y);
  Rect r(double l, double t, double rr, double b) =>
      Rect.fromLTRB(w * l, h * t, w * rr, h * b);
}
