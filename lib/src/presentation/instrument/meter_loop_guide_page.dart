// 멀티미터로 4-20 mA 루프 재는 법(HIOKI DT4282 기준). 실물에 가까운 그림 세 장:
// ① 계기 세팅(로터리 mA, SHIFT, 빨강 μA mA·검정 COM) ② 루프에 직렬로 끼운 모습(전류가 미터를 지나 한 바퀴) ③ 틀린 연결(+와 − 사이에 댐).
// 계기 값은 사용자가 준 DT4282 설명서: 3.11 전류(SHIFT로 DC→AC→4-20mA), 3.13 4-20 mA % 변환,
// 정확도표(DCmA 60 mA ±0.05%rdg ±5dgt, 분류 1 Ω + 퓨즈 약 1.2 Ω), 퓨즈 점검(630 mA, 약 1.2 Ω 이하 정상).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../reference/page/reference_widgets.dart';
import 'loop_paint_kit.dart';

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

  // 태블릿에서 그림이 너무 커지지 않게 폭을 560까지로.
  Widget _figure(Key key, double aspect, CustomPainter painter) => Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF7F9FA), Color(0xFFE9EDF0)]),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.line),
    ),
    padding: const EdgeInsets.all(8),
    child: AspectRatio(aspectRatio: aspect, child: CustomPaint(key: key, painter: painter)),
  )));

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
    lpSupplyBox(c, const Rect.fromLTWH(10, 56, 102, 140), plus: sPlus, minus: sMinus);
    final (tPlus, tMinus) = lpTransmitter(c, const Offset(298, 70));

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
    lpWire(c, minusWire, const Color(0xFF26292D));

    // + 선: 분배기 + → 풀어낸 끝(전송기 + 단자에서 뺀 선)
    const freeEnd = Offset(214, 140);
    final plusWire = Path()
      ..moveTo(sPlus.dx, sPlus.dy)
      ..lineTo(124, sPlus.dy)
      ..quadraticBezierTo(134, sPlus.dy, 134, 110)
      ..lineTo(134, 130)
      ..quadraticBezierTo(134, 140, 144, 140)
      ..lineTo(freeEnd.dx, freeEnd.dy);
    lpWire(c, plusWire, const Color(0xFFD62828));
    // 벗긴 구리선
    const copper = Offset(222, 140);
    c.drawLine(freeEnd, copper, Paint()
      ..color = const Color(0xFFD08A45)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round);
    // 풀어낸 자리 표시
    c.drawCircle(const Offset(218, 140), 15, Paint()
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

    // 집게: 끝(물리는 곳)과 꼬리(리드가 들어오는 곳). 꼬리 = 끝 − 30 × (cos, sin)
    const redAngle = 1.0;
    final redTail = copper - Offset(math.cos(redAngle), math.sin(redAngle)) * 30;
    const blackAngle = 1.2;
    final blackTail = tPlus - Offset(math.cos(blackAngle), math.sin(blackAngle)) * 30;

    // 리드(미터에서 곧게 내려와 집게로)
    final redLead = Path()
      ..moveTo(redJack.dx, redJack.dy)
      ..cubicTo(redJack.dx, 104, redTail.dx - 10, 104, redTail.dx, redTail.dy);
    lpWire(c, redLead, const Color(0xFFD62828), w: 3.6);
    final blackLead = Path()
      ..moveTo(comJack.dx, comJack.dy)
      ..cubicTo(comJack.dx + 30, 90, blackTail.dx - 6, 95, blackTail.dx, blackTail.dy);
    lpWire(c, blackLead, const Color(0xFF26292D), w: 3.6);
    lpClip(c, copper, redAngle, const Color(0xFFD62828));
    lpClip(c, tPlus, blackAngle, const Color(0xFF26292D));
    c.drawCircle(redJack, 3, Paint()..color = const Color(0xFFD62828));
    c.drawCircle(comJack, 3, Paint()..color = const Color(0xFF26292D));

    // 전류 흐름(분배기 + → 빨강 집게 → 미터 → 검정 집게 → 전송기 → − → 분배기)
    final flow = Path()
      ..addPath(plusWire, Offset.zero)
      ..moveTo(freeEnd.dx, freeEnd.dy)
      ..lineTo(copper.dx, copper.dy)
      ..lineTo(redTail.dx, redTail.dy)
      ..cubicTo(redTail.dx - 10, 104, redJack.dx, 104, redJack.dx, redJack.dy)
      ..moveTo(comJack.dx, comJack.dy)
      ..cubicTo(comJack.dx + 30, 90, blackTail.dx - 6, 95, blackTail.dx, blackTail.dy)
      ..lineTo(tPlus.dx, tPlus.dy)
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

    lpPill(c, '빨강 = 풀어낸 선 (전원 쪽)', const Offset(96, 252), const Color(0xFFD62828));
    lpPill(c, '검정 = 전송기 + 단자', const Offset(268, 252), const Color(0xFF26292D));
    c.drawLine(const Offset(226, 182), const Offset(220, 156), Paint()
      ..color = const Color(0xFFEA580C)
      ..strokeWidth = 1.4);
    lpPill(c, '여기 한 곳만 풀기', const Offset(228, 192), const Color(0xFFEA580C), size: 8.5);
    lpText(c, '전류 →', const Offset(110, 120), size: 8.5, color: const Color(0xFFB45309), w: FontWeight.w900);
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
    lpSupplyBox(c, const Rect.fromLTWH(8, 30, 98, 130), plus: sPlus, minus: sMinus);
    // 전송기는 단자함만 간단히
    final box = RRect.fromRectAndRadius(const Rect.fromLTWH(282, 54, 70, 92), const Radius.circular(10));
    lpShadow(c, box, blur: 5, off: const Offset(2, 3), a: .25);
    c.drawRRect(box, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF5B636B), Color(0xFF353A40)]).createShader(box.outerRect));
    lpText(c, '전송기', const Offset(317, 44), size: 9.5, color: const Color(0xFF2B3036), w: FontWeight.w900);
    const tPlus = Offset(300, 70);
    const tMinus = Offset(300, 130);
    lpScrew(c, tPlus, r: 6);
    lpScrew(c, tMinus, r: 6);
    final pw = Path()
      ..moveTo(sPlus.dx, sPlus.dy)
      ..lineTo(tPlus.dx, tPlus.dy);
    final mw = Path()
      ..moveTo(sMinus.dx, sMinus.dy)
      ..lineTo(tMinus.dx, tMinus.dy);
    lpWire(c, pw, const Color(0xFFD62828));
    lpWire(c, mw, const Color(0xFF26292D));
    // 미터(+와 − 사이에 댐)
    c.save();
    c.translate(166, 6);
    c.scale(.15);
    paintMeterFace(c, reading: '0.000', unit: 'mA', mode: 'DC', leads: false);
    c.restore();
    const redJack = Offset(166 + 146 * .15, 6 + 458 * .15);
    const comJack = Offset(166 + 210 * .15, 6 + 458 * .15);
    lpWire(c, Path()
      ..moveTo(redJack.dx, redJack.dy)
      ..cubicTo(redJack.dx - 10, 90, 180, 80, 196, 70), const Color(0xFFD62828), w: 3);
    lpWire(c, Path()
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
    lpPill(c, 'mA 단자로 + / − 사이에 대기 금지 (합선)', const Offset(180, 184), const Color(0xFFDC2626), size: 9);
    c.restore();
  }

  @override
  bool shouldRepaint(_WrongPainter o) => false;
}
