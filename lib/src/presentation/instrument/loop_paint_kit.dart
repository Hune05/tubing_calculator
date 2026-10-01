// 계기·루프 그림 공용 부품: 글자·그림자·알약 표시·나사 단자·전선·악어 집게·멀티미터(DT4282) 앞면·분배기·2선식 전송기.
// "멀티미터로 4-20 mA 재기"와 "루프 전압" 그림이 같이 쓴다(10-01).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

// ───────── 그림 공통 ─────────

void lpText(Canvas c, String s, Offset center, {double size = 10, Color color = Colors.white, FontWeight w = FontWeight.w700}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color, fontWeight: w, height: 1.1)),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout();
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

void lpShadow(Canvas c, RRect r, {double blur = 8, Offset off = const Offset(0, 4), double a = .28}) {
  c.drawRRect(r.shift(off), Paint()
    ..color = Colors.black.withValues(alpha: a)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur));
}

void lpPill(Canvas c, String s, Offset center, Color bg, {Color fg = Colors.white, double size = 9.5}) {
  final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(fontSize: size, color: fg, fontWeight: FontWeight.w800)), textDirection: TextDirection.ltr)..layout();
  final r = RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: tp.width + 14, height: tp.height + 8), const Radius.circular(20));
  lpShadow(c, r, blur: 3, off: const Offset(0, 1.5), a: .2);
  c.drawRRect(r, Paint()..color = bg);
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

void lpBadge(Canvas c, int n, Offset p) {
  c.drawCircle(p + const Offset(0, 1.5), 11, Paint()
    ..color = Colors.black.withValues(alpha: .25)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  c.drawCircle(p, 11, Paint()..color = Colors.white);
  c.drawCircle(p, 9, Paint()..color = AppColors.brand);
  lpText(c, '$n', p, size: 11, w: FontWeight.w900);
}

/// 나사 단자(위에서 본 둥근 머리 + 홈).
void lpScrew(Canvas c, Offset p, {double r = 7}) {
  c.drawCircle(p + const Offset(0, 1), r + 1, Paint()..color = Colors.black.withValues(alpha: .25));
  c.drawCircle(p, r, Paint()..shader = RadialGradient(center: const Alignment(-.4, -.4), colors: [Colors.white, const Color(0xFFB9C0C7), const Color(0xFF7A828B)]).createShader(Rect.fromCircle(center: p, radius: r)));
  c.drawLine(p + Offset(-r * .6, r * .2), p + Offset(r * .6, -r * .2), Paint()
    ..color = const Color(0xFF4A5057)
    ..strokeWidth = 1.6);
}

/// 전선(피복 그라데이션 느낌: 굵은 바탕 + 가는 하이라이트).
void lpWire(Canvas c, Path p, Color color, {double w = 5}) {
  c.drawPath(p, Paint()
    ..color = Colors.black.withValues(alpha: .18)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w + 2
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
  c.drawPath(p, Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round);
  c.drawPath(p.shift(const Offset(-.6, -1.1)), Paint()
    ..color = Colors.white.withValues(alpha: .35)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * .28
    ..strokeCap = StrokeCap.round);
}

/// 악어 집게(끝이 [tip]을 문다, [angle] 방향에서 들어옴).
void lpClip(Canvas c, Offset tip, double angle, Color color) {
  c.save();
  c.translate(tip.dx, tip.dy);
  c.rotate(angle);
  final body = RRect.fromRectAndRadius(const Rect.fromLTWH(-30, -6, 26, 12), const Radius.circular(4));
  lpShadow(c, body, blur: 2, off: const Offset(0, 2), a: .3);
  c.drawRRect(body, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(color, Colors.white, .35)!, color, Color.lerp(color, Colors.black, .35)!]).createShader(body.outerRect));
  // 금속 턱
  final jaw = Path()
    ..moveTo(-6, -5)
    ..lineTo(2, -2)
    ..lineTo(2, 2)
    ..lineTo(-6, 5)
    ..close();
  c.drawPath(jaw, Paint()..shader = const LinearGradient(colors: [Color(0xFFE5E8EB), Color(0xFF8B939B)]).createShader(const Rect.fromLTWH(-6, -5, 8, 10)));
  for (var x = -5.0; x < 2; x += 2) {
    c.drawLine(Offset(x, -3), Offset(x + 1, -1.5), Paint()
      ..color = const Color(0xFF5B636B)
      ..strokeWidth = .8);
  }
  c.restore();
}

// ───────── 멀티미터 앞면 ─────────

/// 360 × 520 설계 좌표에 DT4282 앞면을 그린다. [leads]면 빨강·검정 리드가 꽂혀 아래로 나간다.
void paintMeterFace(Canvas c, {required String reading, required String unit, required String mode, bool leads = true, bool callouts = false, bool shiftGlow = false}) {
  final holster = RRect.fromRectAndRadius(const Rect.fromLTWH(22, 8, 316, 492), const Radius.circular(40));
  lpShadow(c, holster, blur: 12, off: const Offset(4, 10), a: .32);
  c.drawRRect(holster, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6E757C), Color(0xFF41464C), Color(0xFF2A2E33)]).createShader(holster.outerRect));
  c.drawRRect(holster.deflate(3), Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = Colors.white.withValues(alpha: .14));
  final face = RRect.fromRectAndRadius(const Rect.fromLTWH(42, 26, 276, 456), const Radius.circular(24));
  c.drawRRect(face, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF363B41), Color(0xFF1D2025)]).createShader(face.outerRect));
  c.drawRRect(face, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..color = Colors.black.withValues(alpha: .7));
  c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(46, 30, 268, 110), const Radius.circular(22)),
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white.withValues(alpha: .10), Colors.white.withValues(alpha: 0)]).createShader(const Rect.fromLTWH(46, 30, 268, 110)));
  lpText(c, 'HIOKI', const Offset(180, 49), size: 17, w: FontWeight.w900);

  // 표시창
  final bezel = RRect.fromRectAndRadius(const Rect.fromLTWH(62, 64, 236, 124), const Radius.circular(12));
  c.drawRRect(bezel, Paint()..color = const Color(0xFF0D0F12));
  final lcd = RRect.fromRectAndRadius(const Rect.fromLTWH(70, 72, 220, 108), const Radius.circular(7));
  c.drawRRect(lcd, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFD8E1D2), Color(0xFFB2BDA9)]).createShader(lcd.outerRect));
  c.drawRRect(lcd.deflate(1), Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = Colors.black.withValues(alpha: .16));
  const ink = Color(0xFF1B201A);
  lpText(c, mode, const Offset(104, 87), size: 11, color: ink, w: FontWeight.w900);
  lpText(c, 'AUTO', const Offset(262, 87), size: 9, color: ink.withValues(alpha: .7));
  final tp = TextPainter(
    text: TextSpan(text: reading, style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w700, color: ink, fontFamily: 'monospace', letterSpacing: -1.5, fontFeatures: [FontFeature.tabularFigures()])),
    textDirection: TextDirection.ltr,
  )..layout();
  final scale = tp.width > 176 ? 176 / tp.width : 1.0;
  c.save();
  c.translate(252 - tp.width * scale, 100);
  c.scale(scale);
  tp.paint(c, Offset.zero);
  c.restore();
  lpText(c, unit, const Offset(272, 160), size: 15, color: ink, w: FontWeight.w900);

  // 조작 단추
  void key(String s, Offset center, double w, {bool glow = false}) {
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: w, height: 20), const Radius.circular(10));
    if (glow) {
      c.drawRRect(r.inflate(4), Paint()
        ..color = AppColors.brand.withValues(alpha: .55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
    c.drawRRect(r.shift(const Offset(0, 1.5)), Paint()..color = Colors.black.withValues(alpha: .5));
    c.drawRRect(r, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: glow ? [const Color(0xFF2FA3AD), AppColors.brand] : [const Color(0xFF555A61), const Color(0xFF2E3237)]).createShader(r.outerRect));
    lpText(c, s, center, size: 7.5, w: FontWeight.w800);
  }

  key('MAX/MIN', const Offset(94, 210), 48);
  key('CLEAR', const Offset(150, 210), 48);
  key('READ', const Offset(206, 210), 48);
  key('▲', const Offset(266, 210), 40);
  key('RANGE', const Offset(94, 240), 48);
  key('HOLD', const Offset(150, 240), 48);
  key('MEM', const Offset(206, 240), 48);
  key('▼', const Offset(266, 240), 40);
  key('SHIFT', const Offset(270, 272), 52, glow: shiftGlow);

  // 로터리 스위치
  const ctr = Offset(176, 346);
  c.drawCircle(ctr, 94, Paint()..color = const Color(0xFF26292E));
  c.drawCircle(ctr, 94, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = Colors.white.withValues(alpha: .08));
  final labels = <(double, String)>[
    (180, 'OFF'),
    (204, 'ACV'),
    (228, 'DCV'),
    (252, 'AC+DC'),
    (276, '→|'),
    (298, 'Ω'),
    (320, 'nS'),
    (340, 'μA'),
    (0, 'mA'),
    (24, 'A'),
  ];
  for (final (deg, s) in labels) {
    final a = deg * math.pi / 180;
    final p = ctr + Offset(math.cos(a), math.sin(a)) * 78;
    if (s == 'mA') {
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: p + const Offset(3, 2), width: 38, height: 30), const Radius.circular(8));
      c.drawRRect(r, Paint()..color = AppColors.brand);
      lpText(c, 'mA', p + const Offset(3, -3), size: 11, w: FontWeight.w900);
      lpText(c, '4-20mA', p + const Offset(3, 9), size: 6.5, w: FontWeight.w800);
    } else {
      lpText(c, s, p, size: s.length > 3 ? 7.5 : 9.5, color: const Color(0xFFDDE1E5));
    }
  }
  // 손잡이
  c.drawCircle(ctr + const Offset(0, 4), 58, Paint()
    ..color = Colors.black.withValues(alpha: .5)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
  c.drawCircle(ctr, 56, Paint()..shader = const RadialGradient(center: Alignment(-.35, -.4), colors: [Color(0xFF6A7078), Color(0xFF33373D), Color(0xFF1C1F23)]).createShader(Rect.fromCircle(center: ctr, radius: 56)));
  c.drawCircle(ctr, 56, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = Colors.black);
  // 가로 막대(가리키는 끝은 오른쪽 = mA)
  final bar = RRect.fromRectAndRadius(Rect.fromCenter(center: ctr, width: 104, height: 24), const Radius.circular(12));
  c.drawRRect(bar.shift(const Offset(0, 2)), Paint()..color = Colors.black.withValues(alpha: .45));
  c.drawRRect(bar, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF5C6269), Color(0xFF2A2D32)]).createShader(bar.outerRect));
  c.drawLine(ctr + const Offset(24, 0), ctr + const Offset(48, 0), Paint()
    ..color = Colors.white
    ..strokeWidth = 3.4
    ..strokeCap = StrokeCap.round);

  // 단자
  const jacks = <(double, String)>[(92, 'A'), (146, 'μA mA'), (210, 'COM'), (266, 'V Ω')];
  for (final (x, s) in jacks) {
    final p = Offset(x, 458);
    if (s == 'COM') {
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, 433), width: 34, height: 13), const Radius.circular(3));
      c.drawRRect(r, Paint()..color = const Color(0xFFE6E8EA));
      lpText(c, s, Offset(x, 433), size: 8.5, color: const Color(0xFF1D2025), w: FontWeight.w900);
    } else {
      lpText(c, s, Offset(x, 433), size: 9.5, color: const Color(0xFFE6E8EA), w: FontWeight.w900);
    }
    c.drawCircle(p, 16, Paint()..color = const Color(0xFF111316));
    c.drawCircle(p, 12, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..shader = const LinearGradient(colors: [Color(0xFFD2D7DC), Color(0xFF6D757D)]).createShader(Rect.fromCircle(center: p, radius: 12)));
    c.drawCircle(p, 5, Paint()..color = Colors.black);
  }
  lpText(c, '10A', const Offset(92, 478), size: 6.5, color: const Color(0xFFB4BAC0));
  lpText(c, '600mA FUSED', const Offset(146, 478), size: 6.5, color: const Color(0xFFB4BAC0));

  if (leads) {
    void plug(double x, Color col, double endX) {
      final p = Offset(x, 458);
      final cable = Path()
        ..moveTo(x, 470)
        ..cubicTo(x, 500, endX, 495, endX, 520);
      lpWire(c, cable, col, w: 8);
      c.drawCircle(p + const Offset(0, 2), 14, Paint()..color = Colors.black.withValues(alpha: .4));
      c.drawCircle(p, 13, Paint()..shader = RadialGradient(center: const Alignment(-.4, -.5), colors: [Color.lerp(col, Colors.white, .45)!, col, Color.lerp(col, Colors.black, .4)!]).createShader(Rect.fromCircle(center: p, radius: 13)));
      c.drawCircle(p, 5, Paint()..color = Color.lerp(col, Colors.black, .5)!);
    }

    plug(146, const Color(0xFFD62828), 128);
    plug(210, const Color(0xFF26292D), 232);
  }
  if (callouts) {
    lpBadge(c, 1, const Offset(300, 318));
    lpBadge(c, 2, const Offset(318, 272));
    lpBadge(c, 3, const Offset(118, 506));
    lpBadge(c, 4, const Offset(258, 506));
  }
}


// ───────── 루프 장면 ─────────

/// 분배기(전원) 상자. 오른쪽 가장자리에 + / − 단자.
void lpSupplyBox(Canvas c, Rect box, {required Offset plus, required Offset minus, String volt = '24 V DC'}) {
  final r = RRect.fromRectAndRadius(box, const Radius.circular(10));
  lpShadow(c, r, blur: 6, off: const Offset(2, 4), a: .25);
  c.drawRRect(r, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF1F3F5), Color(0xFFC6CDD3)]).createShader(box));
  c.drawRRect(r, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = const Color(0xFF9AA3AB));
  lpText(c, '분배기', Offset(box.center.dx - 8, box.top + 16), size: 11, color: const Color(0xFF2B3036), w: FontWeight.w900);
  lpText(c, volt, Offset(box.center.dx - 8, box.top + 32), size: 9, color: const Color(0xFF5F6B78));
  c.drawCircle(Offset(box.left + 18, box.top + 52), 4, Paint()..color = const Color(0xFF22C55E));
  c.drawCircle(Offset(box.left + 18, box.top + 52), 7, Paint()
    ..color = const Color(0xFF22C55E).withValues(alpha: .25)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  lpText(c, '+', plus - const Offset(16, 0), size: 13, color: const Color(0xFFD62828), w: FontWeight.w900);
  lpText(c, '−', minus - const Offset(16, 0), size: 13, color: const Color(0xFF26292D), w: FontWeight.w900);
  lpScrew(c, plus);
  lpScrew(c, minus);
}

/// 2선식 압력 전송기(머리 + 단자함 + 공정 연결). 단자 위치를 돌려준다.
(Offset, Offset) lpTransmitter(Canvas c, Offset head) {
  // 공정 연결
  final neck = Rect.fromLTWH(head.dx - 8, head.dy + 104, 16, 22);
  c.drawRect(neck, Paint()..shader = const LinearGradient(colors: [Color(0xFFDDE1E5), Color(0xFF8E969E)]).createShader(neck));
  final nut = Path();
  for (var i = 0; i < 6; i++) {
    final a = i * math.pi / 3;
    final p = Offset(head.dx + math.cos(a) * 15, head.dy + 132 + math.sin(a) * 6);
    i == 0 ? nut.moveTo(p.dx, p.dy) : nut.lineTo(p.dx, p.dy);
  }
  nut.close();
  c.drawPath(nut, Paint()..color = const Color(0xFFA4ACB4));
  final pipe = Rect.fromLTWH(head.dx - 6, head.dy + 136, 12, 30);
  c.drawRect(pipe, Paint()..shader = const LinearGradient(colors: [Color(0xFFE8EBEE), Color(0xFF7F878F)]).createShader(pipe));
  // 단자함
  final box = RRect.fromRectAndRadius(Rect.fromCenter(center: head + const Offset(0, 72), width: 84, height: 66), const Radius.circular(10));
  lpShadow(c, box, blur: 5, off: const Offset(2, 3), a: .25);
  c.drawRRect(box, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF5B636B), Color(0xFF353A40)]).createShader(box.outerRect));
  final inner = RRect.fromRectAndRadius(box.outerRect.deflate(7), const Radius.circular(6));
  c.drawRRect(inner, Paint()..color = const Color(0xFF23272C));
  final plus = head + const Offset(-20, 80);
  final minus = head + const Offset(20, 80);
  lpText(c, '+', plus - const Offset(0, 16), size: 11, color: const Color(0xFFFF6B6B), w: FontWeight.w900);
  lpText(c, '−', minus - const Offset(0, 16), size: 11, color: Colors.white, w: FontWeight.w900);
  lpScrew(c, plus, r: 6);
  lpScrew(c, minus, r: 6);
  // 머리(둥근 몸통)
  c.drawCircle(head + const Offset(2, 5), 38, Paint()
    ..color = Colors.black.withValues(alpha: .25)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
  c.drawCircle(head, 36, Paint()..shader = const RadialGradient(center: Alignment(-.4, -.45), colors: [Colors.white, Color(0xFFC9CFD5), Color(0xFF8A939B)]).createShader(Rect.fromCircle(center: head, radius: 36)));
  c.drawCircle(head, 26, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = const Color(0xFF9CA4AC));
  final win = RRect.fromRectAndRadius(Rect.fromCenter(center: head, width: 30, height: 18), const Radius.circular(3));
  c.drawRRect(win, Paint()..color = const Color(0xFF9FB3A2));
  lpText(c, 'PT', head, size: 9, color: const Color(0xFF23302A), w: FontWeight.w900);
  return (plus, minus);
}

