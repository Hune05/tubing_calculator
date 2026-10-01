// 멀티미터로 4-20 mA 루프 재는 법(HIOKI DT4282 기준). 실물에 가까운 그림 세 장:
// ① 계기 세팅(로터리 mA, SHIFT, 빨강 μA mA·검정 COM) ② 루프에 직렬로 끼운 모습(전류가 미터를 지나 한 바퀴) ③ 틀린 연결(+와 − 사이에 댐).
// 계기 값은 사용자가 준 DT4282 설명서: 3.11 전류(SHIFT로 DC→AC→4-20mA), 3.13 4-20 mA % 변환,
// 정확도표(DCmA 60 mA ±0.05%rdg ±5dgt, 분류 1 Ω + 퓨즈 약 1.2 Ω), 퓨즈 점검(630 mA, 약 1.2 Ω 이하 정상).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../reference/page/reference_widgets.dart';

class MeterLoopGuidePage extends StatefulWidget {
  const MeterLoopGuidePage({super.key});

  @override
  State<MeterLoopGuidePage> createState() => _MeterLoopGuidePageState();
}

class _MeterLoopGuidePageState extends State<MeterLoopGuidePage> with SingleTickerProviderStateMixin {
  // 전류 흐름 점: 2초씩 다섯 번 돌고 멈춘다(계속 돌면 배터리를 먹고 시험이 끝나지 않는다). "다시 보기"로 다시.
  late final AnimationController _flow = AnimationController(vsync: this, duration: const Duration(seconds: 2));
  int _loops = 0;
  double _ma = 12.0;
  bool _pct = false;

  @override
  void initState() {
    super.initState();
    _flow.addStatusListener((s) {
      if (s == AnimationStatus.completed && ++_loops < 5) _flow.forward(from: 0);
    });
    _flow.forward();
  }

  void _replay() {
    _loops = 0;
    _flow.forward(from: 0);
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  String get _reading => _pct ? ((_ma - 4) / 16 * 100).toStringAsFixed(2) : _ma.toStringAsFixed(3);
  String get _unit => _pct ? '%' : 'mA';
  String get _mode => _pct ? '4-20mA' : 'DC';

  Widget _figure(Key key, double aspect, CustomPainter painter) => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF7F9FA), Color(0xFFE9EDF0)]),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.line),
    ),
    padding: const EdgeInsets.all(8),
    child: AspectRatio(aspectRatio: aspect, child: CustomPaint(key: key, painter: painter)),
  );

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
  );

  @override
  Widget build(BuildContext context) {
    final reading = _reading;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('멀티미터로 4-20 mA 재기')),
      body: ListView(
        key: const Key('mlg_list'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          refIntroBadge('루프 선 하나를 풀고 그 사이에 멀티미터를 끼워(직렬) 잽니다. 그림은 HIOKI DT4282 기준이고, 다른 멀티미터도 단자 이름만 다르고 방법은 같습니다.'),
          _title('1. 계기 세팅'),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: _figure(const Key('mlg_meter'), 360 / 520, _MeterFacePainter(reading: reading, unit: _unit, mode: _mode, shiftGlow: _pct)),
            ),
          ),
          const SizedBox(height: 10),
          refChips(
            items: const ['DC mA로 보기', '4-20mA %로 보기'],
            selected: _pct ? '4-20mA %로 보기' : 'DC mA로 보기',
            onSelected: (v) => setState(() => _pct = v.startsWith('4-20')),
          ),
          const SizedBox(height: 10),
          Text('전송기 출력 ${_ma.toStringAsFixed(1)} mA (${((_ma - 4) / 16 * 100).toStringAsFixed(1)}%)', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSub)),
          Slider(key: const Key('mlg_slider'), min: 4, max: 20, divisions: 32, value: _ma, onChanged: (v) => setState(() => _ma = v)),
          refStep(1, '로터리 스위치를 mA 자리로 (A 자리 아님). 4-20 mA는 600 mA 이하라 mA 자리에서 잽니다'),
          refStep(2, '표시창에 DC 확인. mA 자리에서 SHIFT를 누를 때마다 DC → AC → 4-20mA(%) 순서로 바뀜'),
          refStep(3, '빨강 리드 → μA mA 단자, 검정 리드 → COM 단자'),
          const SizedBox(height: 6),
          refTipBox('4-20mA(%) 표시: 4 mA = 0%, 20 mA = 100%. 20 mA를 넘으면 350%까지 표시. 이때는 60 mA 범위로 고정'),

          _title('2. 루프에 직렬로 끼우기'),
          AnimatedBuilder(
            animation: _flow,
            builder: (context, _) => _figure(const Key('mlg_loop'), 360 / 270, _LoopScenePainter(t: _flow.value, reading: reading, unit: _unit, mode: _mode)),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(key: const Key('mlg_replay'), onPressed: _replay, icon: const Icon(Icons.replay, size: 18), label: const Text('전류 흐름 다시 보기')),
          ),
          refStep(4, '가능하면 루프 전원을 끄고 연결한 뒤 켬 (설명서 권장). 못 끄면 제어실과 맞추고 진행'),
          refStep(5, '전송기 + 단자의 선 하나만 풂 (− 쪽은 그대로)'),
          refStep(6, '빨강 집게 → 풀어낸 선 (전원 쪽), 검정 집게 → 전송기 + 단자'),
          refStep(7, '값 읽기: 4 mA = 0%, 12 mA = 50%, 20 mA = 100%. 마이너스가 뜨면 빨강·검정이 바뀐 것'),
          const SizedBox(height: 6),
          refTipBox('미터를 끼워도 루프에 걸리는 전압은 20 mA에서 약 0.05 V (분류 저항 1 Ω + 퓨즈 약 1.2 Ω). 루프 동작에는 영향 없음'),

          _title('3. 이렇게 대면 안 됨'),
          _figure(const Key('mlg_wrong'), 360 / 200, const _WrongPainter()),
          const SizedBox(height: 10),
          refWarnBox('mA 단자에 꽂은 채로 + 와 − 사이(전압 재듯이)에 대면 전원이 바로 합선. 퓨즈(630 mA)가 끊어지고, 루프 신호가 0 mA로 떨어져 경보·인터록이 걸릴 수 있음. 전압을 재려면 빨강 리드를 V 단자로 옮기고 로터리를 V로'),

          _title('4. 끝낼 때'),
          refStep(1, '집게 빼기 전에 제어실에 알림'),
          refStep(2, '집게 빼고 풀었던 선을 + 단자에 다시 물리고 조임 확인 (당겨 봄)'),
          refStep(3, 'DCS·지시계 값이 다시 정상인지 확인, 바이패스 해제'),
          refStep(4, '리드를 먼저 뺀 뒤 로터리 OFF (전류 자리에서 리드 꽂은 채 돌리면 단자 셔터가 상할 수 있음)'),
          refStep(5, '측정값은 "교정 점검" 탭에 기록'),

          _title('5. 값이 이상할 때'),
          refDataRow('0 mA', '퓨즈 끊김, μA mA 단자가 아님, 루프 단선\n퓨즈는 빼서 저항을 재면 약 1.2 Ω 이하가 정상'),
          refGap(),
          refDataRow('마이너스', '빨강·검정이 바뀜'),
          refGap(),
          refDataRow('3.6 mA 이하', '고장 신호(하한): 단선·전송기 고장 점검 (NAMUR NE43)'),
          refGap(),
          refDataRow('21 mA 이상', '고장 신호(상한): 전송기 설정·센서 점검'),
          refGap(),
          refDataRow('값이 튐', '집게 접촉 불량, 단자 조임 불량'),
          refGap(),
          refDataRow('OL·과대 표시', '범위 초과: 로터리 자리 확인'),
          const SizedBox(height: 14),
          refTipBox('전송기에 TEST 단자가 있으면 선을 풀지 않고 그 단자에 mA계를 대고 잴 수 있음. 단자 이름과 짝은 전송기마다 다르니 전송기 설명서대로'),
          const SizedBox(height: 10),
          refDataRow('DT4282 정확도', 'DC 60 mA 범위 ±0.05% rdg ±5 dgt (느린 표시)\n보통 표시는 ±20 dgt 더함. 4-20mA(%) 표시는 ±0.1% rdg ±20 dgt'),
        ],
      ),
    );
  }
}

// ───────── 그림 공통 ─────────

void _text(Canvas c, String s, Offset center, {double size = 10, Color color = Colors.white, FontWeight w = FontWeight.w700}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color, fontWeight: w, height: 1.1)),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout();
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

void _shadow(Canvas c, RRect r, {double blur = 8, Offset off = const Offset(0, 4), double a = .28}) {
  c.drawRRect(r.shift(off), Paint()
    ..color = Colors.black.withValues(alpha: a)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur));
}

void _pill(Canvas c, String s, Offset center, Color bg, {Color fg = Colors.white, double size = 9.5}) {
  final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(fontSize: size, color: fg, fontWeight: FontWeight.w800)), textDirection: TextDirection.ltr)..layout();
  final r = RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: tp.width + 14, height: tp.height + 8), const Radius.circular(20));
  _shadow(c, r, blur: 3, off: const Offset(0, 1.5), a: .2);
  c.drawRRect(r, Paint()..color = bg);
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

void _badge(Canvas c, int n, Offset p) {
  c.drawCircle(p + const Offset(0, 1.5), 11, Paint()
    ..color = Colors.black.withValues(alpha: .25)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  c.drawCircle(p, 11, Paint()..color = Colors.white);
  c.drawCircle(p, 9, Paint()..color = AppColors.brand);
  _text(c, '$n', p, size: 11, w: FontWeight.w900);
}

/// 나사 단자(위에서 본 둥근 머리 + 홈).
void _screw(Canvas c, Offset p, {double r = 7}) {
  c.drawCircle(p + const Offset(0, 1), r + 1, Paint()..color = Colors.black.withValues(alpha: .25));
  c.drawCircle(p, r, Paint()..shader = RadialGradient(center: const Alignment(-.4, -.4), colors: [Colors.white, const Color(0xFFB9C0C7), const Color(0xFF7A828B)]).createShader(Rect.fromCircle(center: p, radius: r)));
  c.drawLine(p + Offset(-r * .6, r * .2), p + Offset(r * .6, -r * .2), Paint()
    ..color = const Color(0xFF4A5057)
    ..strokeWidth = 1.6);
}

/// 전선(피복 그라데이션 느낌: 굵은 바탕 + 가는 하이라이트).
void _wire(Canvas c, Path p, Color color, {double w = 5}) {
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
void _clip(Canvas c, Offset tip, double angle, Color color) {
  c.save();
  c.translate(tip.dx, tip.dy);
  c.rotate(angle);
  final body = RRect.fromRectAndRadius(const Rect.fromLTWH(-30, -6, 26, 12), const Radius.circular(4));
  _shadow(c, body, blur: 2, off: const Offset(0, 2), a: .3);
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
  _shadow(c, holster, blur: 12, off: const Offset(4, 10), a: .32);
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
  _text(c, 'HIOKI', const Offset(180, 49), size: 17, w: FontWeight.w900);

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
  _text(c, mode, const Offset(104, 87), size: 11, color: ink, w: FontWeight.w900);
  _text(c, 'AUTO', const Offset(262, 87), size: 9, color: ink.withValues(alpha: .7));
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
  _text(c, unit, const Offset(272, 160), size: 15, color: ink, w: FontWeight.w900);

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
    _text(c, s, center, size: 7.5, w: FontWeight.w800);
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
    (276, '▶|'),
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
      _text(c, 'mA', p + const Offset(3, -3), size: 11, w: FontWeight.w900);
      _text(c, '4-20mA', p + const Offset(3, 9), size: 6.5, w: FontWeight.w800);
    } else {
      _text(c, s, p, size: s.length > 3 ? 7.5 : 9.5, color: const Color(0xFFDDE1E5));
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
      _text(c, s, Offset(x, 433), size: 8.5, color: const Color(0xFF1D2025), w: FontWeight.w900);
    } else {
      _text(c, s, Offset(x, 433), size: 9.5, color: const Color(0xFFE6E8EA), w: FontWeight.w900);
    }
    c.drawCircle(p, 16, Paint()..color = const Color(0xFF111316));
    c.drawCircle(p, 12, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..shader = const LinearGradient(colors: [Color(0xFFD2D7DC), Color(0xFF6D757D)]).createShader(Rect.fromCircle(center: p, radius: 12)));
    c.drawCircle(p, 5, Paint()..color = Colors.black);
  }
  _text(c, '10A', const Offset(92, 478), size: 6.5, color: const Color(0xFFB4BAC0));
  _text(c, '600mA FUSED', const Offset(146, 478), size: 6.5, color: const Color(0xFFB4BAC0));

  if (leads) {
    void plug(double x, Color col, double endX) {
      final p = Offset(x, 458);
      final cable = Path()
        ..moveTo(x, 470)
        ..cubicTo(x, 500, endX, 495, endX, 520);
      _wire(c, cable, col, w: 8);
      c.drawCircle(p + const Offset(0, 2), 14, Paint()..color = Colors.black.withValues(alpha: .4));
      c.drawCircle(p, 13, Paint()..shader = RadialGradient(center: const Alignment(-.4, -.5), colors: [Color.lerp(col, Colors.white, .45)!, col, Color.lerp(col, Colors.black, .4)!]).createShader(Rect.fromCircle(center: p, radius: 13)));
      c.drawCircle(p, 5, Paint()..color = Color.lerp(col, Colors.black, .5)!);
    }

    plug(146, const Color(0xFFD62828), 128);
    plug(210, const Color(0xFF26292D), 232);
  }
  if (callouts) {
    _badge(c, 1, const Offset(300, 318));
    _badge(c, 2, const Offset(318, 272));
    _badge(c, 3, const Offset(118, 506));
    _badge(c, 4, const Offset(258, 506));
  }
}

class _MeterFacePainter extends CustomPainter {
  final String reading, unit, mode;
  final bool shiftGlow;
  const _MeterFacePainter({required this.reading, required this.unit, required this.mode, required this.shiftGlow});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 360, size.height / 520);
    paintMeterFace(canvas, reading: reading, unit: unit, mode: mode, callouts: true, shiftGlow: shiftGlow);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MeterFacePainter o) => o.reading != reading || o.unit != unit || o.mode != mode || o.shiftGlow != shiftGlow;
}

// ───────── 루프 장면 ─────────

/// 분배기(전원) 상자. 오른쪽 가장자리에 + / − 단자.
void _supplyBox(Canvas c, Rect box, {required Offset plus, required Offset minus}) {
  final r = RRect.fromRectAndRadius(box, const Radius.circular(10));
  _shadow(c, r, blur: 6, off: const Offset(2, 4), a: .25);
  c.drawRRect(r, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF1F3F5), Color(0xFFC6CDD3)]).createShader(box));
  c.drawRRect(r, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = const Color(0xFF9AA3AB));
  _text(c, '분배기', Offset(box.center.dx - 8, box.top + 16), size: 11, color: const Color(0xFF2B3036), w: FontWeight.w900);
  _text(c, '24 V DC', Offset(box.center.dx - 8, box.top + 32), size: 9, color: const Color(0xFF5F6B78));
  c.drawCircle(Offset(box.left + 18, box.top + 52), 4, Paint()..color = const Color(0xFF22C55E));
  c.drawCircle(Offset(box.left + 18, box.top + 52), 7, Paint()
    ..color = const Color(0xFF22C55E).withValues(alpha: .25)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  _text(c, '+', plus - const Offset(16, 0), size: 13, color: const Color(0xFFD62828), w: FontWeight.w900);
  _text(c, '−', minus - const Offset(16, 0), size: 13, color: const Color(0xFF26292D), w: FontWeight.w900);
  _screw(c, plus);
  _screw(c, minus);
}

/// 2선식 압력 전송기(머리 + 단자함 + 공정 연결). 단자 위치를 돌려준다.
(Offset, Offset) _transmitter(Canvas c, Offset head) {
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
  _shadow(c, box, blur: 5, off: const Offset(2, 3), a: .25);
  c.drawRRect(box, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF5B636B), Color(0xFF353A40)]).createShader(box.outerRect));
  final inner = RRect.fromRectAndRadius(box.outerRect.deflate(7), const Radius.circular(6));
  c.drawRRect(inner, Paint()..color = const Color(0xFF23272C));
  final plus = head + const Offset(-20, 80);
  final minus = head + const Offset(20, 80);
  _text(c, '+', plus - const Offset(0, 16), size: 11, color: const Color(0xFFFF6B6B), w: FontWeight.w900);
  _text(c, '−', minus - const Offset(0, 16), size: 11, color: Colors.white, w: FontWeight.w900);
  _screw(c, plus, r: 6);
  _screw(c, minus, r: 6);
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
  _text(c, 'PT', head, size: 9, color: const Color(0xFF23302A), w: FontWeight.w900);
  return (plus, minus);
}

class _LoopScenePainter extends CustomPainter {
  final double t;
  final String reading, unit, mode;
  const _LoopScenePainter({required this.t, required this.reading, required this.unit, required this.mode});

  @override
  void paint(Canvas canvas, Size size) {
    final c = canvas;
    c.save();
    c.scale(size.width / 360, size.height / 270);

    const sPlus = Offset(102, 100);
    const sMinus = Offset(102, 164);
    _supplyBox(c, const Rect.fromLTWH(10, 56, 102, 140), plus: sPlus, minus: sMinus);
    final (tPlus, tMinus) = _transmitter(c, const Offset(298, 70));

    // − 선: 분배기 − → 전송기 − (그대로 둠)
    final minusWire = Path()
      ..moveTo(sMinus.dx, sMinus.dy)
      ..lineTo(150, sMinus.dy)
      ..quadraticBezierTo(162, sMinus.dy, 162, 176)
      ..lineTo(162, 222)
      ..quadraticBezierTo(162, 234, 174, 234)
      ..lineTo(336, 234)
      ..quadraticBezierTo(348, 234, 348, 222)
      ..lineTo(348, 162)
      ..quadraticBezierTo(348, 150, tMinus.dx + 10, tMinus.dy)
      ..lineTo(tMinus.dx, tMinus.dy);
    _wire(c, minusWire, const Color(0xFF26292D));

    // + 선: 분배기 + → 풀어낸 끝(전송기 + 단자 앞)
    const freeEnd = Offset(250, 128);
    final plusWire = Path()
      ..moveTo(sPlus.dx, sPlus.dy)
      ..lineTo(124, sPlus.dy)
      ..quadraticBezierTo(134, sPlus.dy, 134, 110)
      ..lineTo(134, 122)
      ..quadraticBezierTo(134, 132, 144, 132)
      ..lineTo(232, 132)
      ..quadraticBezierTo(244, 132, freeEnd.dx, freeEnd.dy);
    _wire(c, plusWire, const Color(0xFFD62828));
    // 벗긴 구리선
    c.drawLine(freeEnd, freeEnd + const Offset(7, -4), Paint()
      ..color = const Color(0xFFD08A45)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round);
    // 풀어낸 자리 표시
    c.drawCircle(freeEnd + const Offset(4, -2), 15, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFFEA580C));

    // 미터(작게)
    c.save();
    c.translate(144, 2);
    c.scale(.19);
    paintMeterFace(c, reading: reading, unit: unit, mode: mode, leads: false);
    c.restore();
    const redJack = Offset(144 + 146 * .19, 2 + 458 * .19);
    const comJack = Offset(144 + 210 * .19, 2 + 458 * .19);

    // 리드
    final redLead = Path()
      ..moveTo(redJack.dx, redJack.dy)
      ..cubicTo(redJack.dx - 6, 150, 236, 160, freeEnd.dx + 2, freeEnd.dy + 18);
    _wire(c, redLead, const Color(0xFFD62828), w: 3.6);
    final blackLead = Path()
      ..moveTo(comJack.dx, comJack.dy)
      ..cubicTo(comJack.dx + 20, 120, tPlus.dx - 16, 104, tPlus.dx - 2, tPlus.dy - 10);
    _wire(c, blackLead, const Color(0xFF26292D), w: 3.6);
    _clip(c, freeEnd + const Offset(5, -2), math.pi / 2 + .5, const Color(0xFFD62828));
    _clip(c, tPlus, -math.pi / 2 - .3, const Color(0xFF26292D));
    c.drawCircle(redJack, 3, Paint()..color = const Color(0xFFD62828));
    c.drawCircle(comJack, 3, Paint()..color = const Color(0xFF26292D));

    // 전류 흐름(분배기 + → 미터 → 전송기 → − → 분배기)
    final flow = Path()
      ..addPath(plusWire, Offset.zero)
      ..moveTo(freeEnd.dx + 2, freeEnd.dy + 18)
      ..cubicTo(236, 160, redJack.dx - 6, 150, redJack.dx, redJack.dy)
      ..moveTo(comJack.dx, comJack.dy)
      ..cubicTo(comJack.dx + 20, 120, tPlus.dx - 16, 104, tPlus.dx - 2, tPlus.dy - 10)
      ..moveTo(tMinus.dx, tMinus.dy)
      ..lineTo(tMinus.dx + 10, tMinus.dy)
      ..quadraticBezierTo(348, 150, 348, 162)
      ..lineTo(348, 222)
      ..quadraticBezierTo(348, 234, 336, 234)
      ..lineTo(174, 234)
      ..quadraticBezierTo(162, 234, 162, 222)
      ..lineTo(162, 176)
      ..quadraticBezierTo(162, sMinus.dy, 150, sMinus.dy)
      ..lineTo(sMinus.dx, sMinus.dy);
    const gap = 16.0;
    final glow = Paint()
      ..color = const Color(0xFFFFB020).withValues(alpha: .55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final dot = Paint()..color = const Color(0xFFFFD166);
    for (final m in flow.computeMetrics()) {
      for (var d = (t * gap) % gap; d < m.length; d += gap) {
        final tan = m.getTangentForOffset(d);
        if (tan == null) continue;
        c.drawCircle(tan.position, 4, glow);
        c.drawCircle(tan.position, 2.2, dot);
      }
    }

    _pill(c, '빨강 = 풀어낸 선 (전원 쪽)', const Offset(96, 252), const Color(0xFFD62828));
    _pill(c, '검정 = 전송기 + 단자', const Offset(268, 252), const Color(0xFF26292D));
    _pill(c, '여기 한 곳만 풀기', const Offset(226, 104), const Color(0xFFEA580C), size: 8.5);
    _text(c, '전류 →', const Offset(110, 120), size: 8.5, color: const Color(0xFFB45309), w: FontWeight.w900);
    c.restore();
  }

  @override
  bool shouldRepaint(_LoopScenePainter o) => o.t != t || o.reading != reading || o.unit != unit || o.mode != mode;
}

class _WrongPainter extends CustomPainter {
  const _WrongPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = canvas;
    c.save();
    c.scale(size.width / 360, size.height / 200);
    const sPlus = Offset(96, 70);
    const sMinus = Offset(96, 130);
    _supplyBox(c, const Rect.fromLTWH(8, 30, 98, 130), plus: sPlus, minus: sMinus);
    // 전송기는 단자함만 간단히
    final box = RRect.fromRectAndRadius(const Rect.fromLTWH(282, 54, 70, 92), const Radius.circular(10));
    _shadow(c, box, blur: 5, off: const Offset(2, 3), a: .25);
    c.drawRRect(box, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF5B636B), Color(0xFF353A40)]).createShader(box.outerRect));
    _text(c, '전송기', const Offset(317, 44), size: 9.5, color: const Color(0xFF2B3036), w: FontWeight.w900);
    const tPlus = Offset(300, 70);
    const tMinus = Offset(300, 130);
    _screw(c, tPlus, r: 6);
    _screw(c, tMinus, r: 6);
    final pw = Path()
      ..moveTo(sPlus.dx, sPlus.dy)
      ..lineTo(tPlus.dx, tPlus.dy);
    final mw = Path()
      ..moveTo(sMinus.dx, sMinus.dy)
      ..lineTo(tMinus.dx, tMinus.dy);
    _wire(c, pw, const Color(0xFFD62828));
    _wire(c, mw, const Color(0xFF26292D));
    // 미터(+와 − 사이에 댐)
    c.save();
    c.translate(166, 6);
    c.scale(.15);
    paintMeterFace(c, reading: '0.000', unit: 'mA', mode: 'DC', leads: false);
    c.restore();
    const redJack = Offset(166 + 146 * .15, 6 + 458 * .15);
    const comJack = Offset(166 + 210 * .15, 6 + 458 * .15);
    _wire(c, Path()
      ..moveTo(redJack.dx, redJack.dy)
      ..cubicTo(redJack.dx - 10, 90, 180, 80, 196, 70), const Color(0xFFD62828), w: 3);
    _wire(c, Path()
      ..moveTo(comJack.dx, comJack.dy)
      ..cubicTo(comJack.dx + 14, 100, 230, 110, 236, 130), const Color(0xFF26292D), w: 3);
    // 불꽃
    for (final p in const [Offset(196, 70), Offset(236, 130)]) {
      c.drawCircle(p, 12, Paint()
        ..color = const Color(0xFFFFB020).withValues(alpha: .6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      final star = Path();
      for (var i = 0; i < 16; i++) {
        final a = i * math.pi / 8;
        final r = i.isEven ? 10.0 : 4.0;
        final q = p + Offset(math.cos(a), math.sin(a)) * r;
        i == 0 ? star.moveTo(q.dx, q.dy) : star.lineTo(q.dx, q.dy);
      }
      star.close();
      c.drawPath(star, Paint()..color = const Color(0xFFFFD166));
    }
    // 큰 X
    final xp = Paint()
      ..color = const Color(0xFFDC2626)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    c.drawLine(const Offset(160, 20), const Offset(250, 160), xp);
    c.drawLine(const Offset(250, 20), const Offset(160, 160), xp);
    _pill(c, 'mA 단자로 + / − 사이에 대기 금지 (합선)', const Offset(180, 184), const Color(0xFFDC2626), size: 9);
    c.restore();
  }

  @override
  bool shouldRepaint(_WrongPainter o) => false;
}
