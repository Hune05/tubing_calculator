// GD402 수소 순도 가이드 그림 부품(10-01):
// ① 변환기(GD402G) 앞면: 상태 표시(HOLD·TEMP.MAN·FAIL), 숫자 표시, 메시지 표시, 키 조작 표시(YES·NO·▶·▲·ENT),
//    운전 레벨 목록(MODE…VALVE)과 ▶ 포인터, 설정·서비스 레벨 목록(RANGE·CAL DATA·ALARM·SERVICE), * 스위치, 키 7개, 접점 램프 4개.
// ② 가스 배관: 시료(발전기)·제로가스 H2(수소 용기 주황)·스팬가스 CO2(탄산가스 용기 청색) 밸브 → 유량계 → 검출기 GD40 → 대기.
// ③ 화면 따라하기(Gd402Walkthrough): 단계마다 누를 키에 빛, 표시창·포인터·램프·밸브가 그 단계 모습으로 바뀐다.
// 배치는 설명서 IM 11T03E01-01E 그림 3.1(GD402G 덮개 연 모습), 화면 글자는 7·10장 그림 그대로.
import 'package:flutter/material.dart';

import '../../core/theme/app_icon_set.dart';
import '../../core/theme/app_tokens.dart';
import '../reference/page/reference_widgets.dart';
import 'loop_paint_kit.dart';

/// 운전 레벨 목록(그림 3.1 순서). 포인터는 이 번호로 가리킨다.
const kGdOpList = ['MODE', 'DENSITY', 'DENSITY (COMP.)', 'SPEC GRAVITY', 'CALORIC VALUE', 'MOL.WEIGHT', 'VOL.% CONC.', 'MEASURE', 'SEL GAS RANGE', 'DISPLAY', 'SEMI CAL.', 'MANUAL CAL.', 'VALVE'];
const int kOpMeasure = 7, kOpSelGas = 8, kOpDisplay = 9, kOpManCal = 11;

/// 설정·서비스 레벨 목록.
const kGdSetList = ['RANGE', 'CAL DATA', 'ALARM', 'SERVICE'];

/// 키 이름: YES NO MODE > UP ENT *
enum GdKey { yes, no, mode, right, up, ent, star }

/// 밸브 상태(교정 그림).
class GdGas {
  final bool sample, zero, span;
  const GdGas({this.sample = false, this.zero = false, this.span = false});
  static const measuring = GdGas(sample: true);
  static const allClosed = GdGas();
  static const zeroFlow = GdGas(zero: true);
  static const spanFlow = GdGas(span: true);
}

/// 화면 따라하기 한 단계.
class GdStep {
  final String say; // 이 단계에서 할 일
  final GdKey? press; // 누를 키(빛남)
  final String data; // 숫자 표시
  final String msg; // 메시지 표시
  final Set<GdKey> keyOp; // 키 조작 표시에 켜질 것(yes·no·right·up·ent)
  final int? opPtr; // 운전 레벨 포인터
  final int? setPtr; // 설정·서비스 레벨 포인터
  final int? cursor; // 숫자 표시에서 바꾸는 자리(깜박이는 자리)
  final bool hold, fail;
  final Set<String> lamps; // MAINT, ALARM, CAL/SEL, FAIL
  final GdGas? gas;
  final String? warn;
  const GdStep({
    required this.say,
    this.press,
    this.data = '',
    this.msg = '',
    this.keyOp = const {},
    this.opPtr,
    this.setPtr,
    this.cursor,
    this.hold = false,
    this.fail = false,
    this.lamps = const {},
    this.gas,
    this.warn,
  });
}

String gdKeyName(GdKey k) => switch (k) {
  GdKey.yes => 'YES',
  GdKey.no => 'NO',
  GdKey.mode => 'MODE',
  GdKey.right => '>',
  GdKey.up => '∧',
  GdKey.ent => 'ENT',
  GdKey.star => '* (덮개 안 오른쪽 스위치)',
};

// ───────── 변환기 앞면 ─────────

void _tri(Canvas c, Offset center, double s, Color color, {bool up = false}) {
  final p = Path();
  if (up) {
    p
      ..moveTo(center.dx, center.dy - s)
      ..lineTo(center.dx + s, center.dy + s * .8)
      ..lineTo(center.dx - s, center.dy + s * .8);
  } else {
    p
      ..moveTo(center.dx + s, center.dy)
      ..lineTo(center.dx - s * .8, center.dy - s)
      ..lineTo(center.dx - s * .8, center.dy + s);
  }
  p.close();
  c.drawPath(p, Paint()..color = color);
}

/// 400 × 300 설계 좌표에 GD402G 앞면(덮개 연 모습)을 그린다.
void paintGd402(Canvas c, GdStep s) {
  // 함체
  final body = RRect.fromRectAndRadius(const Rect.fromLTWH(8, 6, 384, 288), const Radius.circular(16));
  lpShadow(c, body, blur: 10, off: const Offset(3, 7), a: .25);
  c.drawRRect(body, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF4F6F8), Color(0xFFD5DADF)]).createShader(body.outerRect));
  c.drawRRect(body, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = const Color(0xFF8E979F));
  // 경첩(왼쪽)
  for (final y in const [40.0, 250.0]) {
    final h = RRect.fromRectAndRadius(Rect.fromLTWH(10, y, 10, 22), const Radius.circular(3));
    c.drawRRect(h, Paint()..color = const Color(0xFF9AA3AB));
  }
  final inner = RRect.fromRectAndRadius(const Rect.fromLTWH(26, 16, 356, 268), const Radius.circular(10));
  c.drawRRect(inner, Paint()..color = const Color(0xFFE9ECEF));
  c.drawRRect(inner, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = const Color(0xFFB4BBC2));

  lpText(c, 'EXA', const Offset(66, 30), size: 12, color: const Color(0xFF2B3036), w: FontWeight.w900);
  lpText(c, 'GD402', const Offset(112, 30), size: 11, color: const Color(0xFF2B3036), w: FontWeight.w700);

  // 표시창 테두리
  final bezel = RRect.fromRectAndRadius(const Rect.fromLTWH(38, 40, 290, 108), const Radius.circular(8));
  c.drawRRect(bezel, Paint()..color = const Color(0xFF2E3338));
  final lcd = RRect.fromRectAndRadius(const Rect.fromLTWH(44, 46, 198, 96), const Radius.circular(5));
  c.drawRRect(lcd, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFD9E2D3), Color(0xFFB4BFAB)]).createShader(lcd.outerRect));
  const ink = Color(0xFF1B201A);
  final faint = ink.withValues(alpha: .13);
  // 상태 표시
  void tag(String t, double x, bool on) {
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, 56), width: t.length * 5.6 + 8, height: 11), const Radius.circular(2));
    c.drawRRect(r, Paint()..color = on ? ink : faint);
    lpText(c, t, Offset(x, 56), size: 7, color: on ? const Color(0xFFD9E2D3) : ink.withValues(alpha: .25), w: FontWeight.w900);
  }

  tag('HOLD', 64, s.hold);
  tag('TEMP.MAN', 116, false);
  tag('FAIL', 170, s.fail);
  // 숫자 표시(오른쪽 맞춤, 바꾸는 자리 밑줄)
  final dataStyle = const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: ink, fontFamily: 'monospace', letterSpacing: -1, fontFeatures: [FontFeature.tabularFigures()]);
  final ghost = TextPainter(text: TextSpan(text: '888888', style: dataStyle.copyWith(color: ink.withValues(alpha: .06))), textDirection: TextDirection.ltr)..layout();
  const dataRight = 232.0;
  ghost.paint(c, Offset(dataRight - ghost.width, 64));
  if (s.data.isNotEmpty) {
    final tp = TextPainter(text: TextSpan(text: s.data, style: dataStyle), textDirection: TextDirection.ltr)..layout();
    final x0 = dataRight - tp.width;
    if (s.cursor != null && s.cursor! < s.data.length) {
      final box = tp.getBoxesForSelection(TextSelection(baseOffset: s.cursor!, extentOffset: s.cursor! + 1));
      if (box.isNotEmpty) {
        final b = box.first.toRect().shift(Offset(x0, 64));
        c.drawRect(Rect.fromLTRB(b.left, b.bottom - 1, b.right, b.bottom + 2), Paint()..color = AppColors.brand);
        c.drawRect(b.inflate(1), Paint()..color = AppColors.brand.withValues(alpha: .18));
      }
    }
    tp.paint(c, Offset(x0, 64));
  }
  // 메시지 표시
  final msgStyle = const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ink, fontFamily: 'monospace', letterSpacing: .5);
  // 메시지 칸(배경 글자 없이, 가운데 맞춤 기준 폭만)
  final mg = TextPainter(text: TextSpan(text: 'MAN.CA', style: msgStyle), textDirection: TextDirection.ltr)..layout();
  if (s.msg.isNotEmpty) {
    final mp = TextPainter(text: TextSpan(text: s.msg, style: msgStyle), textDirection: TextDirection.ltr)..layout();
    mp.paint(c, Offset(52 + (mg.width - mp.width).clamp(0, 999) / 2, 116));
  }
  // 키 조작 표시(YES NO ▶ ▲ ENT)
  void kop(String t, double x, bool on, {int tri = 0}) {
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, 126), width: t.isEmpty ? 11 : t.length * 5.4 + 6, height: 11), const Radius.circular(2));
    c.drawRRect(r, Paint()..color = on ? ink : faint);
    final fg = on ? const Color(0xFFD9E2D3) : ink.withValues(alpha: .25);
    if (tri == 1) _tri(c, Offset(x, 126), 3, fg);
    if (tri == 2) _tri(c, Offset(x, 126), 3, fg, up: true);
    if (t.isNotEmpty) lpText(c, t, Offset(x, 126), size: 6.5, color: fg, w: FontWeight.w900);
  }

  kop('YES', 158, s.keyOp.contains(GdKey.yes));
  kop('NO', 178, s.keyOp.contains(GdKey.no));
  kop('', 194, s.keyOp.contains(GdKey.right), tri: 1);
  kop('', 208, s.keyOp.contains(GdKey.up), tri: 2);
  kop('ENT', 226, s.keyOp.contains(GdKey.ent));

  // 운전 레벨 목록
  final listRect = const Rect.fromLTWH(246, 46, 76, 96);
  c.drawRect(listRect, Paint()..color = const Color(0xFFF2F4F5));
  for (var i = 0; i < kGdOpList.length; i++) {
    final y = 49.5 + i * 7.1;
    final on = s.opPtr == i;
    if (on) c.drawRect(Rect.fromLTWH(252, y - 3.4, 69, 6.9), Paint()..color = AppColors.brand.withValues(alpha: .22));
    final tp = TextPainter(text: TextSpan(text: kGdOpList[i], style: TextStyle(fontSize: 5.2, fontWeight: on ? FontWeight.w900 : FontWeight.w600, color: on ? AppColors.brand : const Color(0xFF3A4046))), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, Offset(254, y - tp.height / 2));
    _tri(c, Offset(248.5, y), 2.2, on ? AppColors.brand : const Color(0xFF3A4046).withValues(alpha: .18));
  }

  // 설정·서비스 레벨 목록(오른쪽 따로) + * 스위치
  final setCard = RRect.fromRectAndRadius(const Rect.fromLTWH(336, 40, 40, 150), const Radius.circular(8));
  c.drawRRect(setCard, Paint()..color = const Color(0xFFDDE2E6));
  c.drawRRect(setCard, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = const Color(0xFFA9B1B8));
  c.drawRect(const Rect.fromLTWH(340, 70, 32, 34), Paint()..color = const Color(0xFFF2F4F5));
  for (var i = 0; i < kGdSetList.length; i++) {
    final y = 75.0 + i * 8;
    final on = s.setPtr == i;
    if (on) c.drawRect(Rect.fromLTWH(341, y - 3.6, 30, 7.2), Paint()..color = AppColors.brand.withValues(alpha: .22));
    lpText(c, kGdSetList[i], Offset(358, y), size: 4.6, color: on ? AppColors.brand : const Color(0xFF3A4046), w: on ? FontWeight.w900 : FontWeight.w600);
  }
  // * 스위치
  final star = RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(356, 150), width: 26, height: 12), const Radius.circular(6));
  if (s.press == GdKey.star) {
    c.drawRRect(star.inflate(6), Paint()
      ..color = AppColors.brand.withValues(alpha: .55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
  }
  lpText(c, '*', const Offset(356, 134), size: 13, color: const Color(0xFF2B3036), w: FontWeight.w900);
  c.drawRRect(star.shift(const Offset(0, 1.5)), Paint()..color = Colors.black.withValues(alpha: .3));
  c.drawRRect(star, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: s.press == GdKey.star ? [const Color(0xFF2FA3AD), AppColors.brand] : [Colors.white, const Color(0xFFBFC6CC)]).createShader(star.outerRect));

  // 키 7개(이름은 키 위에 인쇄)
  void key(String label, Offset center, GdKey k, {int glyph = 0}) {
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: 40, height: 15), const Radius.circular(7.5));
    final hot = s.press == k;
    if (hot) {
      c.drawRRect(r.inflate(6), Paint()
        ..color = AppColors.brand.withValues(alpha: .55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    }
    c.drawRRect(r.shift(const Offset(0, 2)), Paint()..color = Colors.black.withValues(alpha: .3));
    c.drawRRect(r, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: hot ? [const Color(0xFF2FA3AD), AppColors.brand] : [Colors.white, const Color(0xFFC3CAD0)]).createShader(r.outerRect));
    c.drawRRect(r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF7D868E));
    final lc = const Color(0xFF2B3036);
    final lp = center - const Offset(0, 15);
    if (glyph == 1) {
      // >
      c.drawPath(Path()
        ..moveTo(lp.dx - 3, lp.dy - 5)
        ..lineTo(lp.dx + 3, lp.dy)
        ..lineTo(lp.dx - 3, lp.dy + 5), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = lc);
    } else if (glyph == 2) {
      // ∧
      c.drawPath(Path()
        ..moveTo(lp.dx - 5, lp.dy + 3)
        ..lineTo(lp.dx, lp.dy - 3)
        ..lineTo(lp.dx + 5, lp.dy + 3), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = lc);
    } else {
      lpText(c, label, lp, size: 8, color: lc, w: FontWeight.w800);
    }
  }

  key('YES', const Offset(70, 186), GdKey.yes);
  key('NO', const Offset(122, 186), GdKey.no);
  key('MODE', const Offset(174, 186), GdKey.mode);
  key('', const Offset(70, 226), GdKey.right, glyph: 1);
  key('', const Offset(122, 226), GdKey.up, glyph: 2);
  key('ENT', const Offset(174, 226), GdKey.ent);

  // 접점 램프
  final cbox = RRect.fromRectAndRadius(const Rect.fromLTWH(216, 160, 74, 84), const Radius.circular(8));
  c.drawRRect(cbox, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..color = const Color(0xFF6B737B));
  lpText(c, 'contacts', const Offset(253, 170), size: 8, color: const Color(0xFF2B3036), w: FontWeight.w800);
  const lampNames = ['MAINT', 'ALARM', 'CAL/SEL', 'FAIL'];
  const lampColors = [Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF22C55E), Color(0xFFEF4444)];
  for (var i = 0; i < 4; i++) {
    final p = Offset(228, 184 + i * 15.0);
    final on = s.lamps.contains(lampNames[i]);
    if (on) {
      c.drawCircle(p, 7, Paint()
        ..color = lampColors[i].withValues(alpha: .5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
    c.drawCircle(p, 4.2, Paint()..color = on ? lampColors[i] : Colors.white);
    c.drawCircle(p, 4.2, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF4A5057));
    final tp = TextPainter(text: TextSpan(text: lampNames[i], style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: Color(0xFF2B3036))), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, Offset(236, p.dy - tp.height / 2));
  }
  lpText(c, 'YOKOGAWA', const Offset(84, 262), size: 9, color: const Color(0xFF2B3036), w: FontWeight.w900);
}

class Gd402PanelPainter extends CustomPainter {
  final GdStep step;
  const Gd402PanelPainter(this.step);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 400, size.height / 300);
    paintGd402(canvas, step);
    canvas.restore();
  }

  @override
  bool shouldRepaint(Gd402PanelPainter o) => o.step != step;
}

// ───────── 가스 배관 ─────────

const _h2Color = Color(0xFFF97316); // 수소 용기 주황
const _co2Color = Color(0xFF2563EB); // 탄산가스 용기 청색
const _sampleColor = Color(0xFF16A34A);

void _cylinder(Canvas c, Rect r, Color color, String gas) {
  final body = RRect.fromRectAndCorners(r, topLeft: Radius.circular(r.width / 2), topRight: Radius.circular(r.width / 2), bottomLeft: const Radius.circular(4), bottomRight: const Radius.circular(4));
  lpShadow(c, body, blur: 3, off: const Offset(1.5, 3), a: .25);
  c.drawRRect(body, Paint()..shader = LinearGradient(colors: [Color.lerp(color, Colors.black, .25)!, Color.lerp(color, Colors.white, .35)!, color, Color.lerp(color, Colors.black, .3)!], stops: const [0, .35, .6, 1]).createShader(r));
  lpText(c, gas, Offset(r.center.dx, r.center.dy + 6), size: 8, color: Colors.white, w: FontWeight.w900);
  // 밸브·조정기
  c.drawRect(Rect.fromCenter(center: Offset(r.center.dx, r.top - 4), width: 6, height: 8), Paint()..color = const Color(0xFF9AA3AB));
  c.drawCircle(Offset(r.center.dx, r.top - 10), 6, Paint()..shader = const RadialGradient(colors: [Colors.white, Color(0xFF8E979F)]).createShader(Rect.fromCircle(center: Offset(r.center.dx, r.top - 10), radius: 6)));
}

void _valve(Canvas c, Offset p, bool open) {
  final col = open ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
  final path = Path()
    ..moveTo(p.dx - 9, p.dy - 7)
    ..lineTo(p.dx + 9, p.dy + 7)
    ..lineTo(p.dx + 9, p.dy - 7)
    ..lineTo(p.dx - 9, p.dy + 7)
    ..close();
  c.drawPath(path, Paint()..color = col);
  c.drawPath(path, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = Colors.black.withValues(alpha: .4));
  c.drawLine(p, p - const Offset(0, 12), Paint()
    ..color = const Color(0xFF4A5057)
    ..strokeWidth = 2);
  c.drawLine(p - const Offset(6, 12), p - const Offset(-6, 12), Paint()
    ..color = const Color(0xFF4A5057)
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round);
  lpPill(c, open ? '열림' : '닫힘', p + const Offset(0, 17), col, size: 7);
}

/// 360 × 200 설계 좌표: 시료·제로(H2)·스팬(CO2) 세 줄 → 모음관 → 유량계 → 검출기 → 대기.
class GdGasPainter extends CustomPainter {
  final GdGas gas;
  const GdGasPainter(this.gas);

  @override
  void paint(Canvas canvas, Size size) {
    final c = canvas;
    c.save();
    c.scale(size.width / 360, size.height / 200);
    const ys = [44.0, 104.0, 164.0];
    final opens = [gas.sample, gas.zero, gas.span];
    final colors = [_sampleColor, _h2Color, _co2Color];
    Color? flowColor;
    for (var i = 0; i < 3; i++) {
      if (opens[i]) flowColor = colors[i];
    }
    final pipe = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFB4BBC2);
    Paint live(Color col) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = col;
    // 공급 쪽
    lpText(c, '시료 (발전기)', const Offset(40, 22), size: 8.5, color: AppColors.textSub, w: FontWeight.w800);
    c.drawRect(const Rect.fromLTWH(10, 38, 34, 12), Paint()..color = const Color(0xFFCBD2D8));
    _cylinder(c, const Rect.fromLTWH(22, 76, 26, 50), _h2Color, 'H2');
    _cylinder(c, const Rect.fromLTWH(22, 148, 26, 50), _co2Color, 'CO2');
    lpText(c, '제로가스', const Offset(70, 92), size: 8, color: _h2Color, w: FontWeight.w900);
    lpText(c, '스팬가스', const Offset(70, 152), size: 8, color: _co2Color, w: FontWeight.w900);
    for (var i = 0; i < 3; i++) {
      final y = ys[i];
      final start = i == 0 ? 44.0 : 48.0;
      final seg = Path()
        ..moveTo(start, y)
        ..lineTo(150, y);
      c.drawPath(seg, pipe);
      if (opens[i]) c.drawPath(seg, live(colors[i]));
    }
    // 모음관(세로) → 유량계
    c.drawLine(const Offset(150, 44), const Offset(150, 164), pipe);
    if (flowColor != null) {
      final yi = gas.sample ? 44.0 : (gas.zero ? 104.0 : 164.0);
      c.drawLine(Offset(150, yi), const Offset(150, 104), live(flowColor));
    }
    final main = Path()
      ..moveTo(150, 104)
      ..lineTo(330, 104);
    c.drawPath(main, pipe);
    if (flowColor != null) c.drawPath(main, live(flowColor));
    for (var i = 0; i < 3; i++) {
      _valve(c, Offset(108, ys[i]), opens[i]);
    }
    // 유량계(로터미터)
    final tube = RRect.fromRectAndRadius(const Rect.fromLTWH(180, 66, 18, 56), const Radius.circular(4));
    lpShadow(c, tube, blur: 2, off: const Offset(1, 2), a: .2);
    c.drawRRect(tube, Paint()..shader = LinearGradient(colors: [Colors.white.withValues(alpha: .9), const Color(0xFFDDE7EE), Colors.white.withValues(alpha: .8)]).createShader(tube.outerRect));
    c.drawRRect(tube, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF7D868E));
    for (var k = 0; k < 6; k++) {
      c.drawLine(Offset(181, 72.0 + k * 9), Offset(186, 72.0 + k * 9), Paint()..color = const Color(0xFF7D868E));
    }
    final fy = flowColor == null ? 116.0 : 88.0;
    c.drawCircle(Offset(189, fy), 4.5, Paint()..color = flowColor ?? const Color(0xFF9AA3AB));
    lpText(c, '유량계', const Offset(189, 58), size: 8, color: AppColors.textSub, w: FontWeight.w800);
    lpText(c, '0.1~1 L/min', const Offset(189, 132), size: 7, color: AppColors.textSub);
    // 검출기 GD40
    final det = RRect.fromRectAndRadius(const Rect.fromLTWH(232, 78, 52, 52), const Radius.circular(10));
    lpShadow(c, det, blur: 5, off: const Offset(2, 4), a: .3);
    c.drawRRect(det, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF4F6F8), Color(0xFFB9C0C7), Color(0xFF8E979F)]).createShader(det.outerRect));
    lpText(c, 'GD40', const Offset(258, 98), size: 10, color: const Color(0xFF2B3036), w: FontWeight.w900);
    lpText(c, '검출기', const Offset(258, 112), size: 8, color: const Color(0xFF4A5057), w: FontWeight.w800);
    // 압력 전송기
    c.drawLine(const Offset(302, 104), const Offset(302, 70), pipe);
    final pt = RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(302, 60), width: 30, height: 20), const Radius.circular(5));
    c.drawRRect(pt, Paint()..shader = const LinearGradient(colors: [Color(0xFF5B636B), Color(0xFF353A40)]).createShader(pt.outerRect));
    lpText(c, 'PT', const Offset(302, 60), size: 8, color: Colors.white, w: FontWeight.w900);
    lpText(c, '압력 전송기', const Offset(302, 40), size: 7.5, color: AppColors.textSub, w: FontWeight.w800);
    // 대기
    _tri(c, const Offset(338, 104), 6, flowColor ?? const Color(0xFFB4BBC2));
    lpText(c, '대기', const Offset(340, 124), size: 8, color: AppColors.textSub, w: FontWeight.w800);
    if (flowColor != null) {
      final name = gas.sample ? '시료가스' : (gas.zero ? 'H2 100% (제로)' : 'CO2 100% (스팬)');
      lpPill(c, '지금 흐르는 가스: $name', const Offset(260, 160), flowColor, size: 8.5);
    } else {
      lpPill(c, '모든 밸브 닫힘', const Offset(260, 160), const Color(0xFF6B737B), size: 8.5);
    }
    lpText(c, '교정 때 출구는 대기압', const Offset(260, 182), size: 7.5, color: AppColors.textSub);
    c.restore();
  }

  @override
  bool shouldRepaint(GdGasPainter o) => o.gas.sample != gas.sample || o.gas.zero != gas.zero || o.gas.span != gas.span;
}

// ───────── 화면 따라하기 ─────────

Widget _frame(Widget child, double aspect) => Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 560),
    child: Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF7F9FA), Color(0xFFE9EDF0)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.all(8),
      child: AspectRatio(aspectRatio: aspect, child: child),
    ),
  ),
);

/// 변환기 앞면 그림 한 장(따라하기 없이).
Widget gdPanelFigure(GdStep s, {Key? key}) => _frame(CustomPaint(key: key, painter: Gd402PanelPainter(s)), 400 / 300);

/// 가스 배관 그림 한 장.
Widget gdGasFigure(GdGas g, {Key? key}) => _frame(CustomPaint(key: key, painter: GdGasPainter(g)), 360 / 200);

class Gd402Walkthrough extends StatefulWidget {
  final String id;
  final List<GdStep> steps;
  const Gd402Walkthrough({super.key, required this.id, required this.steps});

  @override
  State<Gd402Walkthrough> createState() => _Gd402WalkthroughState();
}

class _Gd402WalkthroughState extends State<Gd402Walkthrough> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.steps[_i];
    final last = _i == widget.steps.length - 1;
    return Column(
      key: Key('gdw_${widget.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        gdPanelFigure(s, key: Key('gdw_panel_${widget.id}')),
        if (s.gas != null) ...[const SizedBox(height: 8), gdGasFigure(s.gas!)],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.brandSoft, borderRadius: BorderRadius.circular(20)),
                    child: Text('${_i + 1} / ${widget.steps.length}', key: Key('gdw_count_${widget.id}'), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.brand)),
                  ),
                  const SizedBox(width: 10),
                  if (s.press != null)
                    Flexible(
                      child: Text('누를 키: [${gdKeyName(s.press!)}]', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.text)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(s.say, style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.text, fontWeight: FontWeight.w600)),
              if (s.warn != null) ...[const SizedBox(height: 10), refWarnBox(s.warn!)],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: Key('gdw_prev_${widget.id}'),
                onPressed: _i == 0 ? null : () => setState(() => _i--),
                icon: const Icon(AppIcons.back),
                label: const Text('이전'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                key: Key('gdw_next_${widget.id}'),
                onPressed: () => setState(() => _i = last ? 0 : _i + 1),
                icon: Icon(last ? Icons.replay : AppIcons.forward),
                label: Text(last ? '처음부터' : '다음'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

