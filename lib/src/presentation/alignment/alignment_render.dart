// 축 정렬 그림(평면 2D): 참고 그림과 같은 펌프·모터 세트(은색 주물 펌프, 파란 원뿔 브래킷, 고무 커플링,
// 방열핀 모터, 고리, 단자함, 받침판)를 옆에서 본 그림과 위에서 본 그림으로 그린다.
//  - 측정 그림: 옆에서 본 그림 + 실물 모양 다이얼 설치 + 재는 거리 ①~④
//  - 결과: 옆에서 본 그림(발 밑 심 판, 위아래 어긋남), 위에서 본 그림(네 발 심 판, 옆으로 밀 방향)
// 옆·위 그림은 같은 치수(AlignGeo)를 쓴다. 실제 크기 그림이 아니라 방향과 비율을 보이는 그림이다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'alignment_dial_painter.dart';
import 'alignment_guide_painter.dart';
import 'alignment_math.dart';
import 'alignment_scene_painter.dart';

const Color _silver = Color(0xFFBCC3CB);
const Color _cast = Color(0xFFB0B7BF);
const Color _plateCol = Color(0xFFC3C9CF);
const Color _blue = Color(0xFF2E5D96);
const Color _dark = Color(0xFF262B31);
const Color _rubber = Color(0xFF30353B);
const Color _edge = Color(0xFF2A3139);
const Color _dialA = Color(0xFFE08A00);
const Color _dialB = Color(0xFF2F6FE0);

Color _mix(Color c, double t) => t >= 0 ? Color.lerp(c, Colors.white, t)! : Color.lerp(c, Colors.black, -t)!;

/// 그림 치수. 1 = 100 mm. 커플링 중심 x = 0, 펌프는 −, 모터는 +. y = 위(받침판 밑이 0), z = 오른쪽(고정 쪽에서 볼 때).
/// 비율은 규격 치수표를 따른다.
///  - 모터: IEC 60072 프레임 160M(2극) — 축 높이 H 160, 발 구멍 앞뒤 간격 B 210, 축 어깨~앞발 구멍 C 108,
///    발 구멍 좌우 간격 A 254, 축 지름 D 42, 축 길이 E 110. 몸통 지름·전체 길이는 흔한 값(몸통 약 314, 길이 약 600).
///  - 펌프: ISO 2858 65-40-250 — 흡입 DN65, 토출 DN40, a 100(흡입면~토출 중심), f 500(토출 중심~축 끝),
///    h1 180(발 밑~축 중심), h2 225(축 중심~토출 플랜지 면). 플랜지는 PN16(DN65 바깥지름 185, DN40 150).
///  - 펌프 축 높이 180과 모터 축 높이 160의 차이 20 mm는 모터 받침(패드)과 심으로 맞춘다.
class AlignGeo {
  static const double plateTop = 0.8; // 받침판 윗면(두께 80)
  static const double ya = plateTop + 1.8; // 축 높이(펌프 h1 180)
  static const double padTop = 0.9; // 모터 받침 패드 윗면(심 두께는 보이게 키워 그린다)
  static const double shimTop = ya - 1.6; // 모터 발 밑(모터 H 160)
  static const double footTop = shimTop + 0.25; // 발 판 두께 25
  static const double hubR = 0.64; // 커플링 허브 바깥지름 128
  static const double xB = -0.4; // 다이얼 B가 읽는 펌프 쪽 허브 림
  static const double xA = 0.4; // 다이얼 A(림 다이얼)가 읽는 모터 쪽 허브 림
  static const double shoulder = 1.2; // 모터 축 어깨(허브 끝 0.1 + E 110)
  static const double front = shoulder + 1.08; // 앞발 구멍(C 108)
  static const double rear = front + 2.1; // 뒷발 구멍(B 210)
  static const double footLen = 0.6; // 발 앞뒤 길이
  static const double footZ0 = 1.0, footZ1 = 1.52; // 발 좌우 범위(AB 304의 반), 구멍은 A/2 = 1.27
  static const double motorX0 = 1.55, motorX1 = 5.6, motorR = 1.57; // 몸통(AC 314)
  static const double fanEnd = 7.2; // 팬 덮개 끝(어깨에서 약 600)
  static const double xDischarge = -5.1; // 토출 중심(축 끝 −0.1에서 f 500)
  static const double xSuction = xDischarge - 1.0; // 흡입 플랜지 면(a 100)
  static const double casingR = 1.65; // 볼류트 바깥 반지름(지름 약 330)
  static const double x0 = -6.5, x1 = 7.6; // 그림 가로 범위(받침판)
}

/// 모델 좌표 → 화면. 옆 그림은 (x, y), 위 그림은 (x, z)이며 z가 크면 화면 아래.
class _Map {
  final double s, ox, oy;
  final bool top;
  const _Map(this.s, this.ox, this.oy, this.top);

  factory _Map.fit(Rect box, {required bool top, required double v0, required double v1}) {
    const w = AlignGeo.x1 - AlignGeo.x0;
    final s = math.min(box.width / w, box.height / (v1 - v0));
    final ox = box.center.dx - (AlignGeo.x0 + w / 2) * s;
    final oy = top ? box.center.dy - (v0 + v1) / 2 * s : box.center.dy + (v0 + v1) / 2 * s;
    return _Map(s, ox, oy, top);
  }

  Offset p(double x, double v) => Offset(ox + x * s, top ? oy + v * s : oy - v * s);
  Rect r(double x0, double v0, double x1, double v1) => Rect.fromPoints(p(x0, v0), p(x1, v1));
}

// ─────────────────────────── 그리기 도구 ───────────────────────────

Paint get _line => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1.1
  ..color = _edge.withValues(alpha: 0.75)
  ..strokeJoin = StrokeJoin.round;

/// 축이 가로인 원통(끝 반지름이 다르면 원뿔): 가운데가 밝고 가장자리가 어두운 금속 띠.
void _cyl(Canvas c, _Map m, double x0, double x1, double r0, double r1, Color base, {double at = 0, bool round = false}) {
  final Path path;
  if (round) {
    path = Path()..addRRect(RRect.fromRectAndRadius(m.r(x0, at - r0, x1, at + r0), Radius.circular(math.min(r0, x1 - x0) * m.s * 0.55)));
  } else {
    path = Path()..addPolygon([m.p(x0, at + r0), m.p(x1, at + r1), m.p(x1, at - r1), m.p(x0, at - r0)], true);
  }
  c.drawPath(
    path,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_mix(base, -0.38), _mix(base, -0.02), _mix(base, 0.55), _mix(base, 0.08), _mix(base, -0.42)],
        stops: const [0, 0.18, 0.36, 0.66, 1],
      ).createShader(path.getBounds()),
  );
  c.drawPath(path, _line);
}

/// 평평한 면(상자 앞면): 위가 조금 밝다.
void _flat(Canvas c, Rect r, Color base, {double rad = 1.5, bool horizontal = false}) {
  final rr = RRect.fromRectAndRadius(r, Radius.circular(rad));
  c.drawRRect(
    rr,
    Paint()
      ..shader = LinearGradient(
        begin: horizontal ? Alignment.centerLeft : Alignment.topCenter,
        end: horizontal ? Alignment.centerRight : Alignment.bottomCenter,
        colors: [_mix(base, 0.35), base, _mix(base, -0.22)],
        stops: const [0, 0.45, 1],
      ).createShader(r),
  );
  c.drawRRect(rr, _line);
}

void _bolt(Canvas c, Offset o, double r) {
  c.drawCircle(o.translate(0.6, 0.8), r, Paint()..color = Colors.black.withValues(alpha: 0.3));
  c.drawCircle(o, r, Paint()..shader = const RadialGradient(center: Alignment(-0.4, -0.4), colors: [Color(0xFFEFF2F4), Color(0xFF7A838C)]).createShader(Rect.fromCircle(center: o, radius: r)));
  c.drawCircle(o, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 0.8..color = _edge.withValues(alpha: 0.8));
}

/// 옆에서 본 볼트 머리(위로 볼록한 작은 머리).
void _nutSide(Canvas c, _Map m, double x, double y, double r) => _flat(c, m.r(x - r, y, x + r, y + r * 0.9), const Color(0xFF9AA2AA), rad: 1);

// ─────────────────────────── 옆에서 본 펌프·모터 ───────────────────────────

void _paintSide(Canvas c, _Map m, {double? shimFront, double? shimRear}) {
  const ya = AlignGeo.ya, pt = AlignGeo.plateTop, mr = AlignGeo.motorR;
  const xs = AlignGeo.xSuction, xd = AlignGeo.xDischarge, cr = AlignGeo.casingR;
  final a = m.p(AlignGeo.x0 + 0.1, 0), b = m.p(AlignGeo.x1 - 0.1, 0);
  c.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTRB(a.dx, a.dy - 2, b.dx, a.dy + 8), const Radius.circular(6)),
    Paint()..color = Colors.black.withValues(alpha: 0.18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );

  // 받침판(두께 80): 옆면 + 윗판 테두리, 가운데(좁은 곳)는 안쪽이라 어둡게
  _flat(c, m.r(AlignGeo.x0, 0, AlignGeo.x1, pt - 0.12), _mix(_plateCol, -0.1));
  _flat(c, m.r(AlignGeo.x0, pt - 0.12, -1.3, pt), _plateCol);
  _flat(c, m.r(-1.3, pt - 0.12, 1.0, pt), _mix(_plateCol, -0.1));
  _flat(c, m.r(1.0, pt - 0.12, AlignGeo.x1, pt), _plateCol);
  for (final x in [-6.2, -1.6, 1.3, 7.3]) {
    _nutSide(c, m, x, pt, 0.12);
  }

  // ── 펌프(ISO 2858 65-40-250)
  // 베어링 받침 다리
  final leg = Path()..addPolygon([m.p(-2.35, ya - 0.72), m.p(-1.85, ya - 0.72), m.p(-1.7, pt + 0.12), m.p(-2.5, pt + 0.12)], true);
  c.drawPath(leg, Paint()..shader = LinearGradient(colors: [_mix(_cast, -0.3), _mix(_cast, 0.35), _mix(_cast, -0.25)]).createShader(leg.getBounds()));
  c.drawPath(leg, _line);
  _flat(c, m.r(-2.6, pt, -1.6, pt + 0.12), _mix(_cast, -0.05));
  for (final x in [-2.45, -1.75]) {
    _nutSide(c, m, x, pt + 0.12, 0.09);
  }
  // 케이싱 발(발 밑 = 받침판 윗면, 축까지 h1 180)
  _flat(c, m.r(-5.5, pt + 0.12, -4.7, ya - cr + 0.3), _mix(_cast, -0.08));
  _flat(c, m.r(-5.65, pt, -4.55, pt + 0.12), _mix(_cast, -0.05));
  for (final x in [-5.5, -4.7]) {
    _nutSide(c, m, x, pt + 0.12, 0.09);
  }
  // 흡입 플랜지(DN65, 바깥지름 185, 두께 20)와 흡입구
  _cyl(c, m, xs + 0.2, -5.55, 0.42, 0.62, _silver, at: ya);
  _cyl(c, m, xs, xs + 0.2, 0.925, 0.925, _mix(_silver, 0.04), at: ya);
  for (final y in [ya + 0.725, ya - 0.725]) {
    _bolt(c, m.p(xs + 0.1, y), math.max(1.8, m.s * 0.07));
  }
  // 토출 노즐과 플랜지(DN40, 바깥지름 150, 면 높이 h2 225)
  _flat(c, m.r(xd - 0.33, ya + cr - 0.3, xd + 0.33, ya + 2.25 - 0.18), _cast, horizontal: true);
  _flat(c, m.r(xd - 0.75, ya + 2.25 - 0.18, xd + 0.75, ya + 2.25), _mix(_silver, 0.05));
  for (final x in [xd - 0.55, xd + 0.55]) {
    _nutSide(c, m, x, ya + 2.25, 0.07);
  }
  // 볼류트 케이싱(둥근 몸통)
  _cyl(c, m, -5.6, -4.5, cr, cr, _cast, at: ya, round: true);
  final vol = m.r(-5.45, ya - cr + 0.25, -4.65, ya + cr - 0.25);
  c.drawRRect(RRect.fromRectAndRadius(vol, Radius.circular(vol.width * 0.45)), Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.white.withValues(alpha: 0.45));
  // 케이싱 커버
  _cyl(c, m, -4.5, -4.25, 1.55, 1.55, _mix(_cast, -0.03), at: ya);
  for (final y in [ya + 1.38, ya - 1.38, ya + 0.7, ya - 0.7]) {
    _bolt(c, m.p(-4.375, y), math.max(1.6, m.s * 0.06));
  }
  // 파란 브래킷(원뿔)과 베어링 하우징(지름 150)
  _cyl(c, m, -4.25, -3.0, 1.3, 0.75, _blue, at: ya);
  _cyl(c, m, -3.0, -1.5, 0.75, 0.72, _blue, at: ya);
  _cyl(c, m, -1.62, -1.4, 0.8, 0.8, _mix(_blue, -0.1), at: ya);
  _flat(c, m.r(-2.3, ya + 0.72, -2.1, ya + 0.95), const Color(0xFFD8A63A), horizontal: true); // 급유구
  // 펌프 축(지름 32)
  _cyl(c, m, -1.4, -0.7, 0.16, 0.16, _mix(_silver, 0.2), at: ya);

  // ── 커플링(허브 바깥지름 128, 가운데 고무)
  _cyl(c, m, -0.7, -0.1, AlignGeo.hubR, AlignGeo.hubR, _mix(_silver, 0.1), at: ya);
  _cyl(c, m, -0.1, 0.1, 0.5, 0.5, _rubber, at: ya);
  _cyl(c, m, 0.1, 0.7, AlignGeo.hubR, AlignGeo.hubR, _mix(_silver, 0.1), at: ya);
  _cyl(c, m, 0.7, AlignGeo.shoulder, 0.21, 0.21, _mix(_silver, 0.2), at: ya); // 모터 축(D 42)

  // ── 모터(IEC 160M)
  _flat(c, m.r(AlignGeo.front - 0.45, pt, AlignGeo.rear + 0.45, AlignGeo.padTop), _mix(_cast, -0.1)); // 받침 패드
  _cyl(c, m, AlignGeo.shoulder, 1.35, 0.6, 0.6, _mix(_silver, -0.05), at: ya);
  _cyl(c, m, 1.35, AlignGeo.motorX0, 1.0, mr, _mix(_silver, -0.02), at: ya);
  _motorBody(c, m, ya);
  _cyl(c, m, AlignGeo.motorX1, AlignGeo.motorX1 + 0.2, mr, mr, _mix(_silver, -0.02), at: ya);
  _cyl(c, m, AlignGeo.motorX1 + 0.2, AlignGeo.fanEnd - 0.12, mr - 0.07, mr - 0.2, _mix(_silver, 0.06), at: ya);
  _cyl(c, m, AlignGeo.fanEnd - 0.12, AlignGeo.fanEnd, mr - 0.2, 1.0, _mix(_silver, 0.06), at: ya);
  for (var x = AlignGeo.motorX1 + 0.35; x < AlignGeo.fanEnd - 0.2; x += 0.1) {
    c.drawLine(m.p(x, ya + mr - 0.3), m.p(x, ya - mr + 0.3), Paint()..color = _edge.withValues(alpha: 0.22)..strokeWidth = 1);
  }
  // 고리
  _flat(c, m.r(3.2, ya + mr - 0.02, 3.4, ya + mr + 0.14), const Color(0xFF9AA2AA), horizontal: true);
  final eye = m.p(3.3, ya + mr + 0.36);
  c.drawCircle(eye, 0.2 * m.s, Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(3, 0.1 * m.s)..color = _edge.withValues(alpha: 0.85));
  c.drawCircle(eye, 0.2 * m.s, Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(1.8, 0.06 * m.s)..color = _mix(_silver, 0.25));
  // 단자함(옆으로 튀어나온 상자, 뚜껑 나사 넷, 전선 구멍)
  final tb = m.r(2.95, ya - 0.3, 4.0, ya + 0.7);
  c.drawRRect(RRect.fromRectAndRadius(tb.shift(const Offset(2, 3)), const Radius.circular(3)), Paint()..color = Colors.black.withValues(alpha: 0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  _flat(c, tb, _mix(_silver, 0.05), rad: 3);
  final lid = m.r(3.03, ya - 0.22, 3.92, ya + 0.62);
  c.drawRRect(RRect.fromRectAndRadius(lid, const Radius.circular(2)), Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = _edge.withValues(alpha: 0.4));
  for (final (x, y) in [(3.1, ya + 0.55), (3.85, ya + 0.55), (3.1, ya - 0.15), (3.85, ya - 0.15)]) {
    _bolt(c, m.p(x, y), math.max(1.6, m.s * 0.045));
  }
  _flat(c, m.r(3.35, ya - 0.45, 3.6, ya - 0.3), _dark, rad: 1);

  // ── 모터 발(몸통 옆으로 튀어나와 앞에 보인다)과 심 판
  for (final (x, sh) in [(AlignGeo.front, shimFront), (AlignGeo.rear, shimRear)]) {
    const fl = AlignGeo.footLen;
    _flat(c, m.r(x - fl / 2 + 0.06, AlignGeo.footTop, x + fl / 2 - 0.06, AlignGeo.footTop + 0.28), _cast, horizontal: true);
    _flat(c, m.r(x - fl / 2, AlignGeo.shimTop, x + fl / 2, AlignGeo.footTop), _mix(_cast, -0.04));
    _nutSide(c, m, x, AlignGeo.footTop, 0.12);
    _shimSide(c, m, x, sh);
  }
}

void _motorBody(Canvas c, _Map m, double at) {
  const mr = AlignGeo.motorR;
  _cyl(c, m, AlignGeo.motorX0, AlignGeo.motorX1, mr, mr, _mix(_silver, -0.02), at: at);
  // 축 방향 방열핀: 옆(위)에서 보면 가로줄(가장자리로 갈수록 촘촘)
  for (var k = 1; k < 18; k++) {
    final v = at + (mr - 0.02) * math.cos(math.pi * k / 18);
    final a = m.p(AlignGeo.motorX0 + 0.1, v), b = m.p(AlignGeo.motorX1 - 0.1, v);
    c.drawLine(a, b, Paint()..color = _edge.withValues(alpha: 0.32)..strokeWidth = 1.2);
    c.drawLine(a.translate(0, 1.3), b.translate(0, 1.3), Paint()..color = Colors.white.withValues(alpha: 0.4)..strokeWidth = 1);
  }
}

void _shimSide(Canvas c, _Map m, double x, double? sh) {
  const fl = AlignGeo.footLen;
  final r = m.r(x - fl / 2 - 0.08, AlignGeo.padTop, x + fl / 2 + 0.08, AlignGeo.shimTop);
  if (sh == null) {
    _flat(c, r, const Color(0xFF8A939B), rad: 1);
  } else if (sh < -0.005) {
    c.drawRect(r, Paint()..color = alignShimColor(sh).withValues(alpha: 0.3));
    alignDashPath(c, Path()..addRect(r), Paint()..color = alignShimColor(sh)..style = PaintingStyle.stroke..strokeWidth = 2);
  } else {
    _flat(c, r, alignShimColor(sh), rad: 1);
  }
}

// ─────────────────────────── 위에서 본 펌프·모터 ───────────────────────────

void _paintTop(Canvas c, _Map m, {required double shimFront, required double shimRear}) {
  const mr = AlignGeo.motorR;
  const xs = AlignGeo.xSuction, xd = AlignGeo.xDischarge, cr = AlignGeo.casingR;
  // 받침판(펌프 쪽, 가운데 좁은 곳, 모터 쪽)
  final plate = Path()
    ..addPolygon([
      m.p(AlignGeo.x0, -1.9), m.p(-1.3, -1.9), m.p(-1.3, -1.3), m.p(1.0, -1.3), m.p(1.0, -2.05), m.p(AlignGeo.x1, -2.05),
      m.p(AlignGeo.x1, 2.05), m.p(1.0, 2.05), m.p(1.0, 1.3), m.p(-1.3, 1.3), m.p(-1.3, 1.9), m.p(AlignGeo.x0, 1.9),
    ], true);
  c.drawPath(plate.shift(const Offset(2, 4)), Paint()..color = Colors.black.withValues(alpha: 0.18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
  c.drawPath(plate, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_mix(_plateCol, 0.45), _plateCol, _mix(_plateCol, -0.15)]).createShader(plate.getBounds()));
  c.drawPath(plate, _line..strokeWidth = 1.3);
  for (final (x, z) in [(-6.2, 1.6), (-6.2, -1.6), (-1.6, 1.6), (-1.6, -1.6), (1.3, 1.78), (1.3, -1.78), (7.3, 1.78), (7.3, -1.78)]) {
    _bolt(c, m.p(x, z), math.max(2.2, m.s * 0.09));
  }

  // 펌프 발판(케이싱 발 좌우 320, 구멍 250 / 베어링 받침 발)
  _flat(c, m.r(-5.65, -1.6, -4.55, 1.6), _mix(_cast, -0.04));
  _flat(c, m.r(-2.6, -1.1, -1.6, 1.1), _mix(_cast, -0.04));
  for (final (x, z) in [(-5.1, 1.25), (-5.1, -1.25), (-2.1, 0.85), (-2.1, -0.85)]) {
    _bolt(c, m.p(x, z), math.max(2.0, m.s * 0.07));
  }

  // 모터 받침 패드와 네 발, 심 판(몸통 밑이라 먼저)
  _flat(c, m.r(AlignGeo.front - 0.45, -1.75, AlignGeo.rear + 0.45, -0.85), _mix(_cast, -0.1), rad: 1);
  _flat(c, m.r(AlignGeo.front - 0.45, 0.85, AlignGeo.rear + 0.45, 1.75), _mix(_cast, -0.1), rad: 1);

  // 펌프: 흡입 플랜지, 흡입구, 볼류트, 커버, 파란 브래킷
  _cyl(c, m, xs + 0.2, -5.55, 0.42, 0.62, _silver);
  _cyl(c, m, xs, xs + 0.2, 0.925, 0.925, _mix(_silver, 0.04));
  for (final z in [0.725, -0.725, 0.28, -0.28]) {
    _bolt(c, m.p(xs + 0.1, z), math.max(1.6, m.s * 0.06));
  }
  _cyl(c, m, -5.6, -4.5, cr, cr, _cast, round: true);
  _cyl(c, m, -4.5, -4.25, 1.55, 1.55, _mix(_cast, -0.03));
  _cyl(c, m, -4.25, -3.0, 1.3, 0.75, _blue);
  _cyl(c, m, -3.0, -1.5, 0.75, 0.72, _blue);
  _cyl(c, m, -1.62, -1.4, 0.8, 0.8, _mix(_blue, -0.1));
  // 토출 플랜지(DN40, 위에서 보면 볼트 구멍 있는 둥근 판)
  final dc = m.p(xd, 0);
  final fr = 0.75 * m.s;
  c.drawCircle(dc.translate(1.5, 3), fr, Paint()..color = Colors.black.withValues(alpha: 0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  c.drawCircle(dc, fr, Paint()..shader = RadialGradient(center: const Alignment(-0.4, -0.4), colors: [_mix(_silver, 0.5), _mix(_silver, -0.25)]).createShader(Rect.fromCircle(center: dc, radius: fr)));
  c.drawCircle(dc, fr, _line);
  c.drawCircle(dc, 0.22 * m.s, Paint()..shader = const RadialGradient(center: Alignment(-0.3, -0.3), colors: [Color(0xFF59636E), Color(0xFF1B2127)]).createShader(Rect.fromCircle(center: dc, radius: 0.22 * m.s)));
  for (var k = 0; k < 4; k++) {
    final a = 2 * math.pi * (k + 0.5) / 4;
    _bolt(c, dc + Offset(math.cos(a), math.sin(a)) * (0.55 * m.s), math.max(1.8, m.s * 0.07)); // 볼트 원 110, 4개
  }
  final cup = m.p(-2.2, 0);
  final cupR = math.max(3.0, m.s * 0.11);
  c.drawCircle(cup, cupR, Paint()..shader = RadialGradient(center: const Alignment(-0.4, -0.4), colors: [_mix(const Color(0xFFD8A63A), 0.5), _mix(const Color(0xFFD8A63A), -0.25)]).createShader(Rect.fromCircle(center: cup, radius: cupR)));
  _cyl(c, m, -1.4, -0.7, 0.16, 0.16, _mix(_silver, 0.2));

  // 커플링
  _cyl(c, m, -0.7, -0.1, AlignGeo.hubR, AlignGeo.hubR, _mix(_silver, 0.1));
  _cyl(c, m, -0.1, 0.1, 0.5, 0.5, _rubber);
  _cyl(c, m, 0.1, 0.7, AlignGeo.hubR, AlignGeo.hubR, _mix(_silver, 0.1));
  _cyl(c, m, 0.7, AlignGeo.shoulder, 0.21, 0.21, _mix(_silver, 0.2));

  // 모터
  _cyl(c, m, AlignGeo.shoulder, 1.35, 0.6, 0.6, _mix(_silver, -0.05));
  _cyl(c, m, 1.35, AlignGeo.motorX0, 1.0, mr, _mix(_silver, -0.02));
  // 단자함(오른쪽 = 화면 아래로 튀어나옴): 몸통보다 먼저 그려 옆으로 보이게
  _flat(c, m.r(2.95, mr - 0.25, 4.0, mr + 0.4), _mix(_silver, 0.05), rad: 3);
  for (final (x, z) in [(3.1, mr + 0.28), (3.85, mr + 0.28)]) {
    _bolt(c, m.p(x, z), math.max(1.6, m.s * 0.045));
  }
  _motorBody(c, m, 0);
  _cyl(c, m, AlignGeo.motorX1, AlignGeo.motorX1 + 0.2, mr, mr, _mix(_silver, -0.02));
  _cyl(c, m, AlignGeo.motorX1 + 0.2, AlignGeo.fanEnd - 0.12, mr - 0.07, mr - 0.2, _mix(_silver, 0.06));
  _cyl(c, m, AlignGeo.fanEnd - 0.12, AlignGeo.fanEnd, mr - 0.2, 1.0, _mix(_silver, 0.06));
  // 모터 네 발과 심 판: 위에서 보면 몸통 밑에 가려지므로 비치게(발은 점선 윤곽) 그린다
  for (final (x, sh) in [(AlignGeo.front, shimFront), (AlignGeo.rear, shimRear)]) {
    const fl = AlignGeo.footLen;
    for (final sgn in [-1.0, 1.0]) {
      final z0 = sgn > 0 ? AlignGeo.footZ0 - 0.2 : -AlignGeo.footZ1, z1 = sgn > 0 ? AlignGeo.footZ1 : -AlignGeo.footZ0 + 0.2;
      final sr = m.r(x - fl / 2 - 0.1, z0 - 0.1, x + fl / 2 + 0.1, z1 + 0.1);
      final col = alignShimColor(sh);
      c.drawRect(sr, Paint()..color = col.withValues(alpha: sh < -0.005 ? 0.28 : 0.55));
      alignDashPath(c, Path()..addRect(sr), Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = 2);
      final fr = m.r(x - fl / 2, z0, x + fl / 2, z1);
      alignDashPath(c, Path()..addRect(fr), Paint()..color = _edge.withValues(alpha: 0.8)..style = PaintingStyle.stroke..strokeWidth = 1.3);
      _bolt(c, m.p(x, sgn * 1.27), math.max(2.4, m.s * 0.1)); // 발 구멍 좌우 간격 A 254
    }
  }
  // 명판과 고리(위에서 본 모양)
  _flat(c, m.r(2.1, -0.28, 2.8, 0.28), _mix(_silver, 0.3), rad: 2);
  final eye = m.p(3.3, 0);
  final eyeR = Rect.fromCenter(center: eye, width: 0.46 * m.s, height: 0.16 * m.s);
  c.drawOval(eyeR, Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(3, 0.09 * m.s)..color = _edge.withValues(alpha: 0.85));
  c.drawOval(eyeR, Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(1.8, 0.05 * m.s)..color = _mix(_silver, 0.25));
}

// ─────────────────────────── 글씨·표시 도구 ───────────────────────────

void _txt(Canvas canvas, String t, Offset at, Color c, {double size = 11, bool center = true, FontWeight w = FontWeight.w800}) {
  final tp = TextPainter(
    text: TextSpan(text: t, style: TextStyle(fontSize: size, fontWeight: w, color: c)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, center ? at - Offset(tp.width / 2, tp.height / 2) : at);
}

void _badge(Canvas canvas, String n, Offset c, Color color) {
  canvas.drawCircle(c.translate(0, 1), 10, Paint()..color = Colors.black.withValues(alpha: 0.18));
  canvas.drawCircle(c, 10, Paint()..color = color);
  _txt(canvas, n, c, Colors.white, size: 12, w: FontWeight.w900);
}

void _chip(Canvas canvas, String t, Offset at, Color c) {
  final tp = TextPainter(
    text: TextSpan(text: t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
    textDirection: TextDirection.ltr,
  )..layout();
  final r = RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: tp.width + 12, height: tp.height + 4), const Radius.circular(9));
  canvas.drawRRect(r, Paint()..color = c);
  tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
}

void _dashLine(Canvas canvas, Offset a, Offset b, Paint p) => alignDashPath(canvas, Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy), p);

/// 브래킷 막대(색 띠 + 어두운 테두리).
void _rod(Canvas c, Offset a, Offset b, Color col, double w) {
  c.drawLine(a, b, Paint()..color = _edge..strokeWidth = w + 2..strokeCap = StrokeCap.round);
  c.drawLine(a, b, Paint()..color = col..strokeWidth = w..strokeCap = StrokeCap.round);
}

// ─────────────────────────── 측정 그림 ───────────────────────────

class AlignSetupRenderPainter extends CustomPainter {
  final AlignMethod method;
  AlignSetupRenderPainter(this.method);

  static const double _dimsH = 122;
  static double heightFor(double w) => math.min(w * 0.40, 440.0) + _dimsH;

  @override
  void paint(Canvas canvas, Size size) {
    final reverse = method == AlignMethod.reverse;
    const ya = AlignGeo.ya, top = ya + AlignGeo.hubR;
    final m = _Map.fit(Rect.fromLTWH(8, 8, size.width - 16, size.height - 16 - _dimsH), top: false, v0: 0, v1: ya + 2.95);
    _paintSide(canvas, m);
    final dialR = (m.s * 0.42).clamp(12.0, 44.0);
    final rodW = math.max(3.0, m.s * 0.1);

    // ── 다이얼과 브래킷
    if (reverse) {
      // B: 모터 쪽 허브에 물려 펌프 쪽 림을 읽는다(위쪽 줄)
      const bTop = ya + 2.2;
      _rod(canvas, m.p(AlignGeo.xA + 0.12, top), m.p(AlignGeo.xA + 0.12, bTop), _dialB, rodW);
      _rod(canvas, m.p(AlignGeo.xA + 0.12, bTop), m.p(AlignGeo.xB, bTop), _dialB, rodW);
      _flat(canvas, m.r(AlignGeo.xA - 0.05, top - 0.04, AlignGeo.xA + 0.3, top + 0.16), _dialB, rad: 2);
      final bC = m.p(AlignGeo.xB, bTop) + Offset(0, -dialR * 0.15);
      paintDialGauge(canvas, bC, dialR, value: 0, stemTo: m.p(AlignGeo.xB, top), tag: _dialB, numbers: false);
      _chip(canvas, 'B', bC + Offset(-dialR * 1.55, -dialR * 0.3), _dialB);
    }
    // A(림 다이얼): 펌프 쪽 허브에 물려 모터 쪽 림을 읽는다
    const aTop = ya + 1.45;
    _rod(canvas, m.p(AlignGeo.xB - 0.12, top), m.p(AlignGeo.xB - 0.12, aTop), _dialA, rodW);
    _rod(canvas, m.p(AlignGeo.xB - 0.12, aTop), m.p(AlignGeo.xA, aTop), _dialA, rodW);
    _flat(canvas, m.r(AlignGeo.xB - 0.3, top - 0.04, AlignGeo.xB + 0.05, top + 0.16), _dialA, rad: 2);
    final aC = m.p(AlignGeo.xA, aTop) + Offset(0, -dialR * 0.15);
    paintDialGauge(canvas, aC, dialR, value: 0, stemTo: m.p(AlignGeo.xA, top), tag: _dialA, numbers: false);
    _chip(canvas, reverse ? 'A' : '림', aC + Offset(dialR * 1.6, -dialR * 0.3), _dialA);

    if (!reverse) {
      // 페이스 다이얼: 같은 클램프에서 내려온 팔 끝, 스핀들이 축과 나란히 모터 쪽 허브 옆면을 누른다
      final contact = m.p(0.1, ya + 0.56);
      final fC = m.p(-1.35, ya + 1.0);
      _rod(canvas, m.p(AlignGeo.xB - 0.12, aTop), m.p(-1.35, aTop), _dialA, rodW);
      _rod(canvas, m.p(-1.35, aTop), fC, _dialA, rodW);
      paintDialGauge(canvas, fC, dialR * 0.9, value: 0, stemTo: contact, tag: _dialA, numbers: false);
      _chip(canvas, '페이스', fC + Offset(-dialR * 1.7, dialR * 0.2), _dialA);
      // ④ 페이스가 닿는 반지름
      final r0 = m.p(0.25, ya), r1 = m.p(0.25, ya + 0.56);
      final p = Paint()..color = AppColors.text..strokeWidth = 1.6;
      canvas.drawLine(r0, r1, p);
      canvas.drawLine(r0 - const Offset(4, 0), r0 + const Offset(4, 0), p);
      canvas.drawLine(r1 - const Offset(4, 0), r1 + const Offset(4, 0), p);
      _badge(canvas, kAlignNumbers[3], r0 + Offset(16, (r1.dy - r0.dy) / 2), AppColors.text);
    }

    // 커플링 중심선
    _dashLine(canvas, m.p(0, top + 0.1), m.p(0, 0), Paint()..color = AppColors.text.withValues(alpha: 0.55)..strokeWidth = 1.3..style = PaintingStyle.stroke);

    // ── 재는 거리
    final dims = reverse
        ? [
            (AlignGeo.xB, AlignGeo.xA, 'A·B 두 접촉면 사이', _dialB),
            (AlignGeo.xB, 0.0, 'B면 → 커플링 중심', AppColors.text),
            (AlignGeo.xA, AlignGeo.front, 'A면 → 앞발', _dialA),
            (AlignGeo.xA, AlignGeo.rear, 'A면 → 뒷발', _dialA),
          ]
        : [
            (AlignGeo.xA, 0.0, '림면 → 커플링 중심', AppColors.text),
            (AlignGeo.xA, AlignGeo.front, '림면 → 앞발', _dialA),
            (AlignGeo.xA, AlignGeo.rear, '림면 → 뒷발', _dialA),
          ];
    final ext = Paint()..color = AppColors.textSub.withValues(alpha: 0.7)..strokeWidth = 1..style = PaintingStyle.stroke;
    Offset featureAt(double x) {
      if (x == AlignGeo.front || x == AlignGeo.rear) return m.p(x, AlignGeo.shimTop);
      if (x == 0) return m.p(0, 0);
      return m.p(x, ya - AlignGeo.hubR);
    }

    _txt(canvas, '앞발', m.p(AlignGeo.front, 0) + const Offset(0, 11), AppColors.textSub);
    _txt(canvas, '뒷발', m.p(AlignGeo.rear, 0) + const Offset(0, 11), AppColors.textSub);
    for (var i = 0; i < dims.length; i++) {
      final (x0, x1, label, col) = dims[i];
      final ly = size.height - _dimsH + 22 + i * 26.0;
      final f0 = featureAt(x0), f1 = featureAt(x1);
      _dashLine(canvas, f0, Offset(f0.dx, ly + 6), ext);
      _dashLine(canvas, f1, Offset(f1.dx, ly + 6), ext);
      final p = Paint()..color = col..strokeWidth = 2..strokeCap = StrokeCap.round;
      final l = math.min(f0.dx, f1.dx), r = math.max(f0.dx, f1.dx);
      canvas.drawLine(Offset(l, ly), Offset(r, ly), p);
      for (final (x, sgn) in [(l, 1.0), (r, -1.0)]) {
        canvas.drawLine(Offset(x, ly), Offset(x + 7 * sgn, ly - 3.5), p);
        canvas.drawLine(Offset(x, ly), Offset(x + 7 * sgn, ly + 3.5), p);
      }
      _badge(canvas, kAlignNumbers[i], Offset((l + r) / 2, ly), col);
      final tp = TextPainter(
        text: TextSpan(text: label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: col)),
        textDirection: TextDirection.ltr,
      )..layout();
      var tx = math.max(r + 8, (l + r) / 2 + 14);
      if (tx + tp.width > size.width - 4) tx = math.min(l, (l + r) / 2 - 14) - 8 - tp.width;
      tp.paint(canvas, Offset(tx.clamp(2.0, size.width - tp.width - 2), ly - tp.height / 2));
    }

    _txt(canvas, '펌프 (고정)', m.p(-2.6, ya + 1.55), AppColors.textSub, size: 12);
    _txt(canvas, '모터 (이동)', m.p(5.2, ya + AlignGeo.motorR) + const Offset(0, -12), AppColors.textSub, size: 12);
  }

  @override
  bool shouldRepaint(covariant AlignSetupRenderPainter old) => old.method != method;
}

// ─────────────────────────── 결과: 옆에서 본 그림 ───────────────────────────

class AlignSideRenderPainter extends CustomPainter {
  final AxisLine vertical; // 모터 축 위아래 어긋남(+ 위)
  final double xRear;
  final double shimFront, shimRear;
  AlignSideRenderPainter({required this.vertical, required this.xRear, required this.shimFront, required this.shimRear});

  static double heightFor(double w) => math.min(w * 0.36, 400.0) + 76;

  @override
  void paint(Canvas canvas, Size size) {
    const ya = AlignGeo.ya;
    final m = _Map.fit(Rect.fromLTWH(8, 22, size.width - 16, size.height - 22 - 70), top: false, v0: 0, v1: ya + 2.6);
    _paintSide(canvas, m, shimFront: shimFront, shimRear: shimRear);

    // 목표 중심선(펌프 축)
    _dashLine(canvas, m.p(AlignGeo.x0, ya), m.p(AlignGeo.x1, ya), Paint()..color = AppColors.text.withValues(alpha: 0.6)..strokeWidth = 1.5..style = PaintingStyle.stroke);

    // 지금 모터 위치(점선): 위아래 어긋남을 크게 부풀린 것
    final vc = vertical.at(0), vEnd = vertical.at(xRear);
    final vMax = math.max(vc.abs(), vEnd.abs());
    final k = vMax < 1e-6 ? 0.0 : 0.35 / vMax;
    const r = AlignGeo.motorR + 0.12;
    final ghost = Path()
      ..addPolygon([
        m.p(AlignGeo.motorX0, ya + r + vc * k),
        m.p(AlignGeo.motorX1, ya + r + vEnd * k),
        m.p(AlignGeo.motorX1, ya - r + vEnd * k),
        m.p(AlignGeo.motorX0, ya - r + vc * k),
      ], true);
    alignDashPath(canvas, ghost, Paint()..color = alignCaution..style = PaintingStyle.stroke..strokeWidth = 2.4);

    // 발마다 심 표찰
    final narrow = size.width < 600;
    void chip(double x, double mm, String tag, double dx) {
      final c = alignShimColor(mm);
      final a = m.p(x, (AlignGeo.padTop + AlignGeo.shimTop) / 2);
      final at = Offset((a.dx + dx).clamp(52.0, size.width - 52), size.height - 30);
      canvas.drawLine(a, at - const Offset(0, 20), Paint()..color = c..strokeWidth = 1.4);
      canvas.drawCircle(a, 3, Paint()..color = c);
      alignLabel(canvas, '$tag\n심 ${alignShimShort(mm)}', at, c, size: narrow ? 10 : 11, minWidth: narrow ? 70 : 90);
    }

    chip(AlignGeo.front, shimFront, '앞발', narrow ? -28 : -10);
    chip(AlignGeo.rear, shimRear, '뒷발', narrow ? 28 : 10);
    _txt(canvas, '펌프 (고정)', Offset(m.p(-4.5, 0).dx, size.height - 30), AppColors.textSub, size: 12);
    _txt(canvas, '점선 = 지금 모터 위치(크게 부풀림)', Offset(size.width - 202, 4), alignCaution, center: false);
  }

  @override
  bool shouldRepaint(covariant AlignSideRenderPainter old) =>
      old.vertical.v0 != vertical.v0 || old.vertical.slope != vertical.slope || old.xRear != xRear || old.shimFront != shimFront || old.shimRear != shimRear;
}

// ─────────────────────────── 결과: 위에서 본 그림 ───────────────────────────

/// 위쪽이 왼쪽, 아래쪽이 오른쪽(고정 쪽에서 모터를 바라볼 때).
class AlignTopRenderPainter extends CustomPainter {
  final AxisLine horizontal; // 모터 축 옆 어긋남(+ 오른쪽)
  final double xRear;
  final double shimFront, shimRear, moveFront, moveRear;
  AlignTopRenderPainter({
    required this.horizontal,
    required this.xRear,
    required this.shimFront,
    required this.shimRear,
    required this.moveFront,
    required this.moveRear,
  });

  static double heightFor(double w) => math.min(w * 0.32, 360.0) + 130;

  @override
  void paint(Canvas canvas, Size size) {
    final narrow = size.width < 600;
    final m = _Map.fit(Rect.fromLTWH(8, 66, size.width - 16, size.height - 132), top: true, v0: -2.15, v1: 2.15);
    _paintTop(canvas, m, shimFront: shimFront, shimRear: shimRear);

    _dashLine(canvas, m.p(AlignGeo.x0, 0), m.p(AlignGeo.x1, 0), Paint()..color = AppColors.text.withValues(alpha: 0.6)..strokeWidth = 1.5..style = PaintingStyle.stroke);

    // 지금 모터 위치(점선): 옆 어긋남을 크게 부풀린 것(+ 오른쪽 = 화면 아래)
    final zc = horizontal.at(0), zEnd = horizontal.at(xRear);
    final zMax = math.max(math.max(zc.abs(), zEnd.abs()), math.max(moveFront.abs(), moveRear.abs()));
    final k = zMax < 1e-6 ? 0.0 : 0.4 / zMax;
    const r = AlignGeo.motorR + 0.12;
    final ghost = Path()
      ..addPolygon([
        m.p(AlignGeo.motorX0, -r + zc * k),
        m.p(AlignGeo.motorX1, -r + zEnd * k),
        m.p(AlignGeo.motorX1, r + zEnd * k),
        m.p(AlignGeo.motorX0, r + zc * k),
      ], true);
    alignDashPath(canvas, ghost, Paint()..color = alignCaution..style = PaintingStyle.stroke..strokeWidth = 2.4);

    // 네 발 표찰
    void chip(double x, double side, double mm, String tag) {
      final c = alignShimColor(mm);
      final a = m.p(x, side * (AlignGeo.footZ1 + 0.1));
      final at = Offset((a.dx + (x == AlignGeo.front ? (narrow ? -22 : -8) : (narrow ? 22 : 8))).clamp(40.0, size.width - 40), side < 0 ? 30 : size.height - 30);
      canvas.drawLine(a, at + Offset(0, side < 0 ? 18 : -18), Paint()..color = c..strokeWidth = 1.4);
      canvas.drawCircle(a, 3, Paint()..color = c);
      alignLabel(canvas, '$tag\n${alignShimShort(mm)}', at, c, size: narrow ? 10 : 11, minWidth: narrow ? 56 : 74);
    }

    chip(AlignGeo.front, -1, shimFront, narrow ? '앞·왼' : '앞발 왼쪽');
    chip(AlignGeo.rear, -1, shimRear, narrow ? '뒤·왼' : '뒷발 왼쪽');
    chip(AlignGeo.front, 1, shimFront, narrow ? '앞·오른' : '앞발 오른쪽');
    chip(AlignGeo.rear, 1, shimRear, narrow ? '뒤·오른' : '뒷발 오른쪽');

    // 옆으로 미는 방향
    void arrow(double x, double mm) {
      final o = m.p(x, 0);
      final side = x == AlignGeo.front ? -1.0 : 1.0; // 앞발은 왼쪽, 뒷발은 오른쪽 옆에 글
      final at = Offset(o.dx + side * (narrow ? 38 : 48), o.dy);
      if (mm.abs() < 0.005) {
        alignLabel(canvas, '옆 그대로', o, alignOk, size: 11);
        return;
      }
      final dir = mm > 0 ? 1.0 : -1.0;
      final p = Paint()..color = AppColors.brand..strokeWidth = 4..strokeCap = StrokeCap.round;
      final a = o - Offset(0, dir * 18), b = o + Offset(0, dir * 18);
      canvas.drawLine(a, b, p);
      canvas.drawLine(b, b + Offset(-7, -dir * 10), p);
      canvas.drawLine(b, b + Offset(7, -dir * 10), p);
      alignLabel(canvas, '옆으로 ${mm > 0 ? '오른쪽' : '왼쪽'}\n${mm.abs().toStringAsFixed(2)} mm', at, AppColors.brand, size: narrow ? 10 : 11, minWidth: narrow ? 56 : 74);
    }

    if (moveFront.abs() < 0.005 && moveRear.abs() < 0.005) {
      alignLabel(canvas, '옆으로는 그대로', m.p((AlignGeo.front + AlignGeo.rear) / 2, 0), alignOk, size: 11);
    } else {
      arrow(AlignGeo.front, moveFront);
      arrow(AlignGeo.rear, moveRear);
    }

    _txt(canvas, '왼쪽 ▲', const Offset(6, 4), AppColors.textSub, center: false);
    _txt(canvas, '오른쪽 ▼', Offset(6, size.height - 18), AppColors.textSub, center: false);
    _txt(canvas, '펌프 (고정)', m.p(-4.0, 1.9) + const Offset(0, 14), AppColors.textSub, size: 12);
  }

  @override
  bool shouldRepaint(covariant AlignTopRenderPainter old) =>
      old.horizontal.v0 != horizontal.v0 ||
      old.horizontal.slope != horizontal.slope ||
      old.xRear != xRear ||
      old.shimFront != shimFront ||
      old.shimRear != shimRear ||
      old.moveFront != moveFront ||
      old.moveRear != moveRear;
}
