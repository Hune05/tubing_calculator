// 축 정렬 그림에 쓰는 펌프·모터 세트 그림: 은색 주물 펌프, 파란 베어링 브래킷, 커플링, 방열핀 모터, 단자함, 받침판.
// 옆에서 본 그림과 위에서 본 그림이 같은 부품 모양을 쓴다. 금속 원통은 가로줄 무늬(밝은 띠 + 어두운 가장자리)로 입체감을 준다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'alignment_scene_painter.dart';

const Color _silver = Color(0xFFC3CAD2);
const Color _silverDark = Color(0xFF9AA3AD);
const Color _bracketBlue = Color(0xFF2F63A0);
const Color _rubber = Color(0xFF30363D);
const Color _brass = Color(0xFFD8A63A);
const Color _edge = Color(0xFF2B333B);

/// 기계 그림 세로 크기(가로에 비례해 폰에서도 찌그러지지 않게).
double alignMachineScale(double w) => math.min(300.0, w * 0.42);

/// 축 방향이 가로인 원통: 위아래로 어두움-밝음-어두움.
void _cylH(Canvas c, Rect r, Color base, {double rad = 0, double edge = 1}) {
  final rr = RRect.fromRectAndRadius(r, Radius.circular(rad));
  c.drawRRect(
    rr,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [alignShade(base, -0.34), alignShade(base, -0.05), alignShade(base, 0.45), alignShade(base, 0.06), alignShade(base, -0.34)],
        stops: const [0, 0.17, 0.36, 0.68, 1],
      ).createShader(r),
  );
  c.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = edge..color = _edge.withValues(alpha: 0.7));
}

/// 축 방향이 세로인 원통: 좌우로 어두움-밝음-어두움.
void _cylV(Canvas c, Rect r, Color base, {double rad = 0, double edge = 1}) {
  final rr = RRect.fromRectAndRadius(r, Radius.circular(rad));
  c.drawRRect(
    rr,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [alignShade(base, -0.34), alignShade(base, -0.05), alignShade(base, 0.45), alignShade(base, 0.06), alignShade(base, -0.34)],
        stops: const [0, 0.17, 0.36, 0.68, 1],
      ).createShader(r),
  );
  c.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = edge..color = _edge.withValues(alpha: 0.7));
}

void _shadow(Canvas c, Rect r, {double dy = 3, double blur = 4, double alpha = 0.22, double rad = 4}) {
  c.drawRRect(
    RRect.fromRectAndRadius(r.shift(Offset(0, dy)), Radius.circular(rad)),
    Paint()..color = Colors.black.withValues(alpha: alpha)..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
  );
}

void _bolt(Canvas c, Offset o, double r) {
  c.drawCircle(o.translate(0.6, 0.9), r, Paint()..color = Colors.black.withValues(alpha: 0.3));
  c.drawCircle(
    o,
    r,
    Paint()
      ..shader = const RadialGradient(center: Alignment(-0.4, -0.4), colors: [Color(0xFFE8ECF0), Color(0xFF7D8791)]).createShader(Rect.fromCircle(center: o, radius: r)),
  );
  c.drawCircle(o, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 0.9..color = _edge.withValues(alpha: 0.8));
  c.drawLine(o.translate(-r * 0.5, 0), o.translate(r * 0.5, 0), Paint()..color = _edge.withValues(alpha: 0.6)..strokeWidth = 0.8);
}

/// 그림 위에 값을 올릴 때 쓸 위치들.
class SideLayout {
  final double axisY, ground, baseTop, footGap, frontX, rearX, xHubL, xC, xHubR, hubR;
  final Rect motorBody;
  const SideLayout({
    required this.axisY,
    required this.ground,
    required this.baseTop,
    required this.footGap,
    required this.frontX,
    required this.rearX,
    required this.xHubL,
    required this.xC,
    required this.xHubR,
    required this.hubR,
    required this.motorBody,
  });
}

/// 옆에서 본 펌프·모터 세트. 발 밑 틈에는 심 판(shimFront/shimRear가 있으면 색을 입힘)이 들어간다.
SideLayout paintMachineSide(Canvas canvas, double w, {required double topRoom, double? shimFront, double? shimRear}) {
  final u = alignMachineScale(w);
  final ay = topRoom + u * 0.38;
  final ground = topRoom + u * 0.60;
  final plateH = math.max(9.0, u * 0.05);
  final bt = ground - plateH;
  final hubR = u * 0.11;
  const gap = 7.0; // 발과 받침판 사이(심 판이 들어가는 틈)
  final frontX = w * 0.68, rearX = w * 0.86;
  final xHubL = w * 0.35, xC = w * 0.443, xHubR = w * 0.54;

  // 받침판 + 시멘트 몰탈
  canvas.drawRect(Rect.fromLTRB(w * 0.018, ground, w * 0.982, ground + 4), Paint()..color = const Color(0xFF7D858D));
  final plate = Rect.fromLTRB(w * 0.02, bt, w * 0.98, ground);
  _shadow(canvas, plate, dy: 2, blur: 3, alpha: 0.25, rad: 1);
  canvas.drawRect(
    plate,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [alignShade(_silver, 0.5), _silver, alignShade(_silver, -0.3)],
        stops: const [0, 0.35, 1],
      ).createShader(plate),
  );
  canvas.drawRect(plate, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = _edge.withValues(alpha: 0.7));

  // ── 펌프 ──
  // 케이싱 발
  _cylV(canvas, Rect.fromLTRB(w * 0.135, ay + u * 0.17, w * 0.195, bt), _silverDark, rad: 2);
  // 흡입 플랜지와 흡입관
  _cylH(canvas, Rect.fromLTRB(w * 0.03, ay - u * 0.20, w * 0.055, ay + u * 0.20), alignShade(_silver, -0.05), rad: 2);
  for (final s in [-1.0, 1.0]) {
    _bolt(canvas, Offset(w * 0.0425, ay + s * u * 0.17), math.max(2.6, u * 0.02));
  }
  _cylH(canvas, Rect.fromLTRB(w * 0.055, ay - u * 0.115, w * 0.105, ay + u * 0.115), _silver, rad: 2);
  // 케이싱(볼류트)
  final cas = Rect.fromLTRB(w * 0.10, ay - u * 0.20, w * 0.235, ay + u * 0.20);
  final casR = RRect.fromRectAndRadius(cas, Radius.circular(u * 0.17));
  _shadow(canvas, cas, dy: 4, blur: 5, alpha: 0.2, rad: u * 0.17);
  canvas.drawRRect(
    casR,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.5),
        radius: 1.05,
        colors: [alignShade(_silver, 0.6), _silver, alignShade(_silver, -0.38)],
        stops: const [0, 0.5, 1],
      ).createShader(cas),
  );
  canvas.drawRRect(casR, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.1..color = _edge.withValues(alpha: 0.75));
  canvas.drawRRect(casR.deflate(u * 0.035), Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.white.withValues(alpha: 0.35));
  // 토출 노즐(위)과 플랜지
  _cylV(canvas, Rect.fromLTRB(w * 0.128, ay - u * 0.31, w * 0.192, ay - u * 0.18), _silver, rad: 2);
  _cylV(canvas, Rect.fromLTRB(w * 0.115, ay - u * 0.335, w * 0.205, ay - u * 0.30), alignShade(_silver, -0.05), rad: 2);
  for (final x in [0.125, 0.16, 0.195]) {
    _bolt(canvas, Offset(w * x, ay - u * 0.3175), math.max(2.4, u * 0.017));
  }
  // 커버 플랜지
  _cylH(canvas, Rect.fromLTRB(w * 0.232, ay - u * 0.215, w * 0.25, ay + u * 0.215), alignShade(_silver, -0.08), rad: 2);
  // 베어링 받침(주물 다리)
  final ped = Path()
    ..moveTo(w * 0.262, ay + u * 0.10)
    ..lineTo(w * 0.312, ay + u * 0.10)
    ..lineTo(w * 0.328, bt)
    ..lineTo(w * 0.246, bt)
    ..close();
  canvas.drawPath(
    ped,
    Paint()
      ..shader = LinearGradient(colors: [alignShade(_silver, -0.35), alignShade(_silver, 0.35), alignShade(_silver, -0.3)], stops: const [0, 0.4, 1]).createShader(Rect.fromLTRB(w * 0.246, ay, w * 0.328, bt)),
  );
  canvas.drawPath(ped, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = _edge.withValues(alpha: 0.7));
  _cylH(canvas, Rect.fromLTRB(w * 0.238, bt - u * 0.03, w * 0.336, bt), alignShade(_silver, -0.08), rad: 1.5);
  for (final x in [0.248, 0.326]) {
    _bolt(canvas, Offset(w * x, bt - u * 0.015), math.max(2.4, u * 0.016));
  }
  // 베어링 브래킷(파랑)
  _cylH(canvas, Rect.fromLTRB(w * 0.25, ay - u * 0.115, w * 0.335, ay + u * 0.115), _bracketBlue, rad: 3);
  _cylH(canvas, Rect.fromLTRB(w * 0.25, ay - u * 0.13, w * 0.265, ay + u * 0.13), alignShade(_bracketBlue, -0.08), rad: 2);
  _cylH(canvas, Rect.fromLTRB(w * 0.32, ay - u * 0.125, w * 0.335, ay + u * 0.125), alignShade(_bracketBlue, -0.08), rad: 2);
  _cylV(canvas, Rect.fromLTRB(w * 0.285, ay - u * 0.165, w * 0.297, ay - u * 0.115), _brass, rad: 2); // 급유구

  // ── 축과 커플링 ──
  _cylH(canvas, Rect.fromLTRB(w * 0.335, ay - u * 0.03, xHubL + 2, ay + u * 0.03), alignShade(_silver, 0.15), rad: 1);
  _cylH(canvas, Rect.fromLTRB(xHubR - 2, ay - u * 0.03, w * 0.585, ay + u * 0.03), alignShade(_silver, 0.15), rad: 1);
  _cylH(canvas, Rect.fromLTRB(xHubL, ay - hubR, xC - 3, ay + hubR), _silver, rad: 3);
  _cylH(canvas, Rect.fromLTRB(xC + 3, ay - hubR, xHubR, ay + hubR), _silver, rad: 3);
  _cylH(canvas, Rect.fromLTRB(xC - 5, ay - hubR * 0.86, xC + 5, ay + hubR * 0.86), _rubber, rad: 2);

  // ── 모터 ──
  final body = Rect.fromLTRB(w * 0.62, ay - u * 0.145, w * 0.90, ay + u * 0.145);
  // 발(몸통 아래 → 받침판)
  void foot(double fx, double? shim) {
    final fw = w * 0.034;
    _cylV(canvas, Rect.fromLTRB(fx - fw, body.bottom - u * 0.03, fx + fw, bt - gap), alignShade(_silver, -0.06), rad: 2);
    _cylH(canvas, Rect.fromLTRB(fx - fw * 1.35, bt - gap - u * 0.03, fx + fw * 1.35, bt - gap), alignShade(_silver, -0.1), rad: 1.5);
    for (final s in [-1.0, 1.0]) {
      _bolt(canvas, Offset(fx + s * fw * 1.05, bt - gap - u * 0.015), math.max(2.4, u * 0.016));
    }
    // 심 판(발과 받침판 사이 틈)
    final pr = Rect.fromLTRB(fx - fw * 1.5, bt - gap, fx + fw * 1.5, bt);
    if (shim == null) {
      canvas.drawRect(pr, Paint()..color = const Color(0xFF808890));
    } else if (shim < -0.005) {
      canvas.drawRect(pr, Paint()..color = alignShimColor(shim).withValues(alpha: 0.25));
      alignDashPath(canvas, Path()..addRect(pr), Paint()..color = alignShimColor(shim)..style = PaintingStyle.stroke..strokeWidth = 2);
    } else {
      canvas.drawRect(pr, Paint()..color = alignShimColor(shim));
      canvas.drawRect(pr, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = _edge.withValues(alpha: 0.8));
    }
  }

  foot(frontX, shimFront);
  foot(rearX, shimRear);
  // 구동 쪽 앞판과 베어링 보스
  _cylH(canvas, Rect.fromLTRB(w * 0.552, ay - u * 0.075, w * 0.59, ay + u * 0.075), alignShade(_silver, -0.05), rad: 3);
  _shadow(canvas, body, dy: 4, blur: 5, alpha: 0.2, rad: 6);
  _cylH(canvas, Rect.fromLTRB(w * 0.585, ay - u * 0.17, w * 0.625, ay + u * 0.17), alignShade(_silver, -0.02), rad: 5);
  _cylH(canvas, body, _silver, rad: 5);
  for (var x = body.left + 7; x < body.right - 4; x += 6.5) {
    canvas.drawLine(Offset(x, body.top + 3), Offset(x, body.bottom - 3), Paint()..color = _edge.withValues(alpha: 0.28)..strokeWidth = 1.2);
    canvas.drawLine(Offset(x + 1.4, body.top + 3), Offset(x + 1.4, body.bottom - 3), Paint()..color = Colors.white.withValues(alpha: 0.35)..strokeWidth = 1);
  }
  // 팬 덮개
  _cylH(canvas, Rect.fromLTRB(w * 0.895, ay - u * 0.125, w * 0.965, ay + u * 0.125), alignShade(_silver, -0.04), rad: u * 0.07);
  for (var x = w * 0.912; x < w * 0.95; x += 5) {
    canvas.drawLine(Offset(x, ay - u * 0.09), Offset(x, ay + u * 0.09), Paint()..color = _edge.withValues(alpha: 0.25)..strokeWidth = 1);
  }
  // 고리(아이볼트)
  final eyeC = Offset(w * 0.715, body.top - u * 0.05);
  _cylV(canvas, Rect.fromCenter(center: Offset(eyeC.dx, body.top - u * 0.01), width: w * 0.02, height: u * 0.03), alignShade(_silver, -0.1), rad: 2);
  canvas.drawCircle(eyeC, u * 0.038, Paint()..style = PaintingStyle.stroke..strokeWidth = 4.2..color = _edge.withValues(alpha: 0.85));
  canvas.drawCircle(eyeC, u * 0.038, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.6..color = alignShade(_silver, 0.25));
  // 단자함(뚜껑 나사 네 개와 전선 구멍)
  final tb = Rect.fromLTRB(w * 0.752, ay - u * 0.105, w * 0.838, ay + u * 0.085);
  _shadow(canvas, tb, dy: 3, blur: 3, alpha: 0.3, rad: 3);
  final tbr = RRect.fromRectAndRadius(tb, const Radius.circular(3));
  canvas.drawRRect(
    tbr,
    Paint()
      ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [alignShade(_silver, 0.5), _silver, alignShade(_silver, -0.3)]).createShader(tb),
  );
  canvas.drawRRect(tbr, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.1..color = _edge.withValues(alpha: 0.8));
  canvas.drawRRect(tbr.deflate(5), Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = _edge.withValues(alpha: 0.35));
  for (final p in [tb.topLeft + const Offset(5, 5), tb.topRight + const Offset(-5, 5), tb.bottomLeft + const Offset(5, -5), tb.bottomRight + const Offset(-5, -5)]) {
    _bolt(canvas, p, 2.3);
  }
  canvas.drawCircle(Offset(tb.center.dx, tb.bottom + 1), 4, Paint()..color = _edge.withValues(alpha: 0.85));

  return SideLayout(
    axisY: ay,
    ground: ground,
    baseTop: bt,
    footGap: gap,
    frontX: frontX,
    rearX: rearX,
    xHubL: xHubL,
    xC: xC,
    xHubR: xHubR,
    hubR: hubR,
    motorBody: body,
  );
}

/// 위에서 본 그림에 필요한 위치.
class TopLayout {
  final double midY, frontCx, rearCx;
  final Rect motor;
  final double footHalfSpan; // 발 바깥 끝까지의 반높이
  const TopLayout({required this.midY, required this.frontCx, required this.rearCx, required this.motor, required this.footHalfSpan});
}

/// 위에서 본 그림에 필요한 높이.
double alignTopHeightFor(double w) => alignMachineScale(w) * 0.84 + 76;

/// 위에서 본 펌프·모터 세트. 위쪽이 왼쪽, 아래쪽이 오른쪽. 발 밑 심 판은 발 바깥으로 삐져나온 색 띠로 보인다.
TopLayout paintMachineTop(Canvas canvas, Size size, {double? shimFront, double? shimRear}) {
  final w = size.width;
  final u = alignMachineScale(w);
  final my = size.height / 2;
  final frontCx = w * 0.68, rearCx = w * 0.86;

  // ── 받침판(가운데가 잘록한 주물 판)
  final pl = u * 0.36, pm = u * 0.22;
  final plate = Path()
    ..moveTo(w * 0.02, my - pl)
    ..lineTo(w * 0.35, my - pl)
    ..lineTo(w * 0.375, my - pm)
    ..lineTo(w * 0.54, my - pm)
    ..lineTo(w * 0.565, my - pl)
    ..lineTo(w * 0.98, my - pl)
    ..lineTo(w * 0.98, my + pl)
    ..lineTo(w * 0.565, my + pl)
    ..lineTo(w * 0.54, my + pm)
    ..lineTo(w * 0.375, my + pm)
    ..lineTo(w * 0.35, my + pl)
    ..lineTo(w * 0.02, my + pl)
    ..close();
  canvas.drawPath(plate.shift(const Offset(0, 4)), Paint()..color = Colors.black.withValues(alpha: 0.22)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
  canvas.drawPath(
    plate,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [alignShade(_silver, 0.55), alignShade(_silver, 0.2), alignShade(_silver, -0.12)],
      ).createShader(Rect.fromLTRB(w * 0.02, my - pl, w * 0.98, my + pl)),
  );
  canvas.drawPath(plate, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..color = _edge.withValues(alpha: 0.75));
  for (final p in [
    Offset(w * 0.04, my - pl + 8), Offset(w * 0.04, my + pl - 8), Offset(w * 0.33, my - pl + 8), Offset(w * 0.33, my + pl - 8),
    Offset(w * 0.58, my - pl + 8), Offset(w * 0.58, my + pl - 8), Offset(w * 0.96, my - pl + 8), Offset(w * 0.96, my + pl - 8),
  ]) {
    _bolt(canvas, p, math.max(3.0, u * 0.022));
  }

  // ── 펌프 ──
  for (final s in [-1.0, 1.0]) {
    _cylV(canvas, Rect.fromCenter(center: Offset(w * 0.15, my + s * u * 0.225), width: w * 0.055, height: u * 0.06), alignShade(_silver, -0.06), rad: 2);
    _bolt(canvas, Offset(w * 0.15, my + s * u * 0.225), 2.4);
    _cylV(canvas, Rect.fromCenter(center: Offset(w * 0.20, my + s * u * 0.225), width: w * 0.055, height: u * 0.06), alignShade(_silver, -0.06), rad: 2);
    _bolt(canvas, Offset(w * 0.20, my + s * u * 0.225), 2.4);
  }
  _cylH(canvas, Rect.fromLTRB(w * 0.03, my - u * 0.20, w * 0.055, my + u * 0.20), alignShade(_silver, -0.05), rad: 2);
  for (final y in [-0.16, -0.06, 0.06, 0.16]) {
    _bolt(canvas, Offset(w * 0.0425, my + y * u), math.max(2.2, u * 0.016));
  }
  _cylH(canvas, Rect.fromLTRB(w * 0.055, my - u * 0.115, w * 0.105, my + u * 0.115), _silver, rad: 2);
  final cas = Rect.fromLTRB(w * 0.10, my - u * 0.20, w * 0.235, my + u * 0.20);
  final casR = RRect.fromRectAndRadius(cas, Radius.circular(u * 0.17));
  _shadow(canvas, cas, dy: 4, blur: 5, alpha: 0.2, rad: u * 0.17);
  canvas.drawRRect(
    casR,
    Paint()
      ..shader = RadialGradient(center: const Alignment(-0.3, -0.4), radius: 1.05, colors: [alignShade(_silver, 0.55), _silver, alignShade(_silver, -0.35)], stops: const [0, 0.5, 1]).createShader(cas),
  );
  canvas.drawRRect(casR, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.1..color = _edge.withValues(alpha: 0.75));
  // 토출 플랜지(위에서 보면 볼트 구멍이 있는 둥근 판)
  final dc = Offset(w * 0.168, my);
  final fr = u * 0.105;
  canvas.drawCircle(dc.translate(1, 3), fr, Paint()..color = Colors.black.withValues(alpha: 0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  canvas.drawCircle(dc, fr, Paint()..shader = RadialGradient(center: const Alignment(-0.4, -0.4), colors: [alignShade(_silver, 0.5), alignShade(_silver, -0.22)]).createShader(Rect.fromCircle(center: dc, radius: fr)));
  canvas.drawCircle(dc, fr, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = _edge.withValues(alpha: 0.8));
  canvas.drawCircle(dc, fr * 0.56, Paint()..shader = const RadialGradient(center: Alignment(-0.3, -0.3), colors: [Color(0xFF59636E), Color(0xFF1E252C)]).createShader(Rect.fromCircle(center: dc, radius: fr * 0.56)));
  for (var k = 0; k < 6; k++) {
    final a = 2 * math.pi * k / 6 + 0.3;
    _bolt(canvas, dc + Offset(math.cos(a), math.sin(a)) * (fr * 0.79), math.max(2.0, u * 0.014));
  }
  _cylH(canvas, Rect.fromLTRB(w * 0.232, my - u * 0.215, w * 0.25, my + u * 0.215), alignShade(_silver, -0.08), rad: 2);
  // 베어링 받침 발판과 브래킷
  for (final s in [-1.0, 1.0]) {
    _cylV(canvas, Rect.fromLTRB(w * 0.243, my + (s > 0 ? u * 0.10 : -u * 0.165), w * 0.335, my + (s > 0 ? u * 0.165 : -u * 0.10)), alignShade(_silver, -0.06), rad: 2);
    _bolt(canvas, Offset(w * 0.256, my + s * u * 0.133), 2.5);
    _bolt(canvas, Offset(w * 0.322, my + s * u * 0.133), 2.5);
  }
  _cylH(canvas, Rect.fromLTRB(w * 0.25, my - u * 0.115, w * 0.335, my + u * 0.115), _bracketBlue, rad: 3);
  _cylH(canvas, Rect.fromLTRB(w * 0.25, my - u * 0.13, w * 0.265, my + u * 0.13), alignShade(_bracketBlue, -0.08), rad: 2);
  _cylH(canvas, Rect.fromLTRB(w * 0.32, my - u * 0.125, w * 0.335, my + u * 0.125), alignShade(_bracketBlue, -0.08), rad: 2);
  final cup = Offset(w * 0.291, my - u * 0.02);
  canvas.drawCircle(cup, math.max(4.0, u * 0.03), Paint()..shader = RadialGradient(center: const Alignment(-0.4, -0.4), colors: [alignShade(_brass, 0.5), alignShade(_brass, -0.25)]).createShader(Rect.fromCircle(center: cup, radius: math.max(4.0, u * 0.03))));
  canvas.drawCircle(cup, math.max(4.0, u * 0.03), Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = _edge.withValues(alpha: 0.8));

  // ── 축과 커플링 ──
  final hubR = u * 0.11;
  _cylH(canvas, Rect.fromLTRB(w * 0.335, my - u * 0.03, w * 0.60, my + u * 0.03), alignShade(_silver, 0.15), rad: 1);
  _cylH(canvas, Rect.fromLTRB(w * 0.35, my - hubR, w * 0.44, my + hubR), _silver, rad: 3);
  _cylH(canvas, Rect.fromLTRB(w * 0.446, my - hubR, w * 0.54, my + hubR), _silver, rad: 3);
  _cylH(canvas, Rect.fromLTRB(w * 0.438, my - hubR * 0.86, w * 0.448, my + hubR * 0.86), _rubber, rad: 2);

  // ── 모터 네 발(먼저 심 판, 그 위에 발)
  final motor = Rect.fromLTRB(w * 0.62, my - u * 0.19, w * 0.90, my + u * 0.19);
  final footW = w * 0.085, footH = u * 0.085;
  final footCy = u * 0.215;
  void foot(double cx, double cy, double? shim) {
    final fr = Rect.fromCenter(center: Offset(cx, cy), width: footW, height: footH);
    if (shim != null) {
      final c = alignShimColor(shim);
      final sr = RRect.fromRectAndRadius(fr.inflate(5).translate(0, cy < my ? -3 : 3), const Radius.circular(3));
      if (shim < -0.005) {
        canvas.drawRRect(sr, Paint()..color = c.withValues(alpha: 0.25));
        alignDashPath(canvas, Path()..addRRect(sr), Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 2);
      } else {
        canvas.drawRRect(sr, Paint()..color = c);
        canvas.drawRRect(sr, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = _edge.withValues(alpha: 0.8));
      }
    }
    _cylV(canvas, fr, alignShade(_silver, -0.06), rad: 3);
    _bolt(canvas, fr.center, math.max(3.0, u * 0.022));
  }

  for (final (cx, shim) in [(frontCx, shimFront), (rearCx, shimRear)]) {
    foot(cx, my - footCy, shim);
    foot(cx, my + footCy, shim);
  }

  // ── 모터 몸통
  _shadow(canvas, motor, dy: 4, blur: 5, alpha: 0.2, rad: 10);
  _cylH(canvas, Rect.fromLTRB(w * 0.585, my - u * 0.215, w * 0.625, my + u * 0.215), alignShade(_silver, -0.02), rad: 6);
  _cylH(canvas, Rect.fromLTRB(w * 0.552, my - u * 0.075, w * 0.59, my + u * 0.075), alignShade(_silver, -0.05), rad: 3);
  _cylH(canvas, motor, _silver, rad: 10);
  for (var y = motor.top + 6; y < motor.bottom - 3; y += 5.5) {
    canvas.drawLine(Offset(motor.left + 8, y), Offset(motor.right - 8, y), Paint()..color = _edge.withValues(alpha: 0.25)..strokeWidth = 1.1);
    canvas.drawLine(Offset(motor.left + 8, y + 1.3), Offset(motor.right - 8, y + 1.3), Paint()..color = Colors.white.withValues(alpha: 0.32)..strokeWidth = 1);
  }
  _cylH(canvas, Rect.fromLTRB(w * 0.895, my - u * 0.15, w * 0.965, my + u * 0.15), alignShade(_silver, -0.04), rad: u * 0.08);
  for (var y = my - u * 0.11; y < my + u * 0.11; y += 5) {
    canvas.drawLine(Offset(w * 0.912, y), Offset(w * 0.95, y), Paint()..color = _edge.withValues(alpha: 0.25)..strokeWidth = 1);
  }
  // 고리(위에서 보면 작은 타원)와 단자함(오른쪽으로 튀어나옴)
  canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.715, my - u * 0.07), width: u * 0.07, height: u * 0.03), Paint()..style = PaintingStyle.stroke..strokeWidth = 3.4..color = _edge.withValues(alpha: 0.85));
  canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.715, my - u * 0.07), width: u * 0.07, height: u * 0.03), Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = alignShade(_silver, 0.25));
  final tb = Rect.fromLTRB(w * 0.752, my + u * 0.13, w * 0.838, my + u * 0.27);
  _shadow(canvas, tb, dy: 3, blur: 3, alpha: 0.3, rad: 3);
  final tbr = RRect.fromRectAndRadius(tb, const Radius.circular(3));
  canvas.drawRRect(tbr, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [alignShade(_silver, 0.5), _silver, alignShade(_silver, -0.3)]).createShader(tb));
  canvas.drawRRect(tbr, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.1..color = _edge.withValues(alpha: 0.8));
  canvas.drawRRect(tbr.deflate(5), Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = _edge.withValues(alpha: 0.35));
  for (final p in [tb.topLeft + const Offset(5, 5), tb.topRight + const Offset(-5, 5), tb.bottomLeft + const Offset(5, -5), tb.bottomRight + const Offset(-5, -5)]) {
    _bolt(canvas, p, 2.3);
  }

  return TopLayout(midY: my, frontCx: frontCx, rearCx: rearCx, motor: motor, footHalfSpan: footCy + footH / 2 + 8);
}
