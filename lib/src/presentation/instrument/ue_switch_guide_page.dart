// UE(United Electric) 120 시리즈 J120 압력 스위치 셋팅 가이드(10-02).
// 근거: UE 설치·운전 안내서 IMP120 23 (ueonline.com 공개본, 사용자 요청으로 받음), 카탈로그 120-B.
// ① 덮개 연 J120 안쪽 그림(단자대 N.O.·COM·N.C., 마이크로스위치, 플런저, 돌리면 안 되는 너트, 5/8" 조정 육각, 십자 잠금 나사,
//    내부 접지 단자, 3/4" NPT 전선관 구멍, 압력 접속구·벤트 구멍) — 단계마다 누를 곳에 빛, 돌리는 방향 화살표
// ② 시험대 흉내: 핸드 펌프 압력을 올리고 내리며 동작·복귀를 보고, 잠금 나사를 풀어야 육각을 돌릴 수 있게.
// 설명서에 없는 것(육각 한 바퀴에 얼마나 바뀌는지 등)은 그림용 값이라고 밝힌다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_icon_set.dart';
import '../../core/theme/app_tokens.dart';
import '../equipment/equipment_manual.dart';
import '../reference/page/reference_widgets.dart';
import 'loop_paint_kit.dart';

part 'ue_h122_section.dart';

/// 그림 상태.
class UeView {
  final bool cover; // 덮개 닫힘
  final bool lockLoose; // 잠금 나사 풀림
  final int hexTurn; // 0 없음, 1 시계(올림), -1 반시계(내림)
  final bool meter; // 멀티미터 도통 연결
  final bool wiresOff; // 현장 선 풀어 둠
  final bool closedNO; // COM–N.O. 닫힘(동작함)
  final String? hot; // 빛낼 곳: cover, lock, hex, donot, term, hub, conn, ground
  const UeView({this.cover = false, this.lockLoose = false, this.hexTurn = 0, this.meter = false, this.wiresOff = false, this.closedNO = false, this.hot});
}

const _ueBlue = Color(0xFF7FA6BE); // 카탈로그 사진의 연한 회청색 에폭시
const _ueBlueDark = Color(0xFF4E7590);

void _glow(Canvas c, Offset p, double r) {
  c.drawCircle(p, r, Paint()
    ..color = AppColors.brand.withValues(alpha: .45)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
}

void _hexagon(Canvas c, Offset ctr, double r, Paint p, {double rot = 0}) {
  final path = Path();
  for (var i = 0; i < 6; i++) {
    final a = rot + i * math.pi / 3;
    final q = ctr + Offset(math.cos(a), math.sin(a)) * r;
    i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
  }
  path.close();
  c.drawPath(path, p);
}

void _phillips(Canvas c, Offset p, double r) {
  c.drawCircle(p + const Offset(0, 1), r + 1, Paint()..color = Colors.black.withValues(alpha: .3));
  c.drawCircle(p, r, Paint()..shader = RadialGradient(center: const Alignment(-.4, -.4), colors: [Colors.white, const Color(0xFFB9C0C7), const Color(0xFF6F7780)]).createShader(Rect.fromCircle(center: p, radius: r)));
  final k = Paint()
    ..color = const Color(0xFF3A4046)
    ..strokeWidth = r * .28
    ..strokeCap = StrokeCap.round;
  c.drawLine(p + Offset(-r * .55, 0), p + Offset(r * .55, 0), k);
  c.drawLine(p + Offset(0, -r * .55), p + Offset(0, r * .55), k);
}

void _turnArrow(Canvas c, Offset ctr, double r, bool cw, Color col) {
  final rect = Rect.fromCircle(center: ctr, radius: r);
  final p = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..color = col;
  const start = -math.pi * .85;
  const sweep = math.pi * 1.3;
  c.drawArc(rect, cw ? start : start + sweep, cw ? sweep : -sweep, false, p);
  final endA = cw ? start + sweep : start;
  final tip = ctr + Offset(math.cos(endA), math.sin(endA)) * r;
  final dir = cw ? endA + math.pi / 2 : endA - math.pi / 2;
  final head = Path()
    ..moveTo(tip.dx + math.cos(dir) * 7, tip.dy + math.sin(dir) * 7)
    ..lineTo(tip.dx + math.cos(dir + 2.4) * 7, tip.dy + math.sin(dir + 2.4) * 7)
    ..lineTo(tip.dx + math.cos(dir - 2.4) * 7, tip.dy + math.sin(dir - 2.4) * 7)
    ..close();
  c.drawPath(head, Paint()..color = col);
}

/// 360 × 320 설계 좌표에 J120(덮개 연 모습, 정면)을 그린다.
class UeJ120Painter extends CustomPainter {
  final UeView v;
  const UeJ120Painter(this.v);

  @override
  void paint(Canvas canvas, Size size) {
    final c = canvas;
    c.save();
    c.scale(size.width / 360, size.height / 320);
    const ctr = Offset(180, 138);

    // 압력 접속구(아래 줄기)와 벤트 구멍
    final stem = Rect.fromLTWH(160, 236, 40, 50);
    c.drawRect(stem, Paint()..shader = const LinearGradient(colors: [Color(0xFF8E979F), Color(0xFFE2E6EA), Color(0xFF7D868E)]).createShader(stem));
    final hexP = Paint()..shader = const LinearGradient(colors: [Color(0xFF9AA3AB), Color(0xFFEDEFF1), Color(0xFF8E979F)]).createShader(const Rect.fromLTWH(150, 286, 60, 22));
    c.drawRect(const Rect.fromLTWH(150, 286, 60, 22), hexP);
    for (final x in const [170.0, 190.0]) {
      c.drawLine(Offset(x, 286), Offset(x, 308), Paint()
        ..color = Colors.black.withValues(alpha: .2)
        ..strokeWidth = 1);
    }
    c.drawCircle(const Offset(168, 252), 3.2, Paint()..color = const Color(0xFF1F2328));
    if (v.hot == 'conn') _glow(c, const Offset(180, 297), 30);

    // 전선관 구멍(좌우, 3/4" NPT)
    for (final x in const [6.0, 318.0]) {
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(x, 112, 36, 52), const Radius.circular(6));
      c.drawRRect(r, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFA9C6D8), _ueBlue, _ueBlueDark]).createShader(r.outerRect));
      c.drawCircle(Offset(x + 18, 138), 11, Paint()..color = const Color(0xFF15181C));
    }
    if (v.hot == 'hub') {
      _glow(c, const Offset(24, 138), 28);
      _glow(c, const Offset(336, 138), 28);
    }

    // 몸체(다이캐스트 알루미늄, 파란 에폭시) + 설치 귀 4개
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(38, 24, 284, 222), const Radius.circular(26));
    lpShadow(c, body, blur: 10, off: const Offset(3, 7), a: .3);
    c.drawRRect(body, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFA9C6D8), _ueBlue, _ueBlueDark]).createShader(body.outerRect));
    c.drawRRect(body.deflate(2), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: .18));
    for (final p in const [Offset(58, 44), Offset(302, 44), Offset(58, 226), Offset(302, 226)]) {
      c.drawCircle(p, 8, Paint()..color = _ueBlueDark);
      c.drawCircle(p, 4, Paint()..color = const Color(0xFF0B1A33));
    }

    if (v.cover) {
      // 덮개(나사식 둥근 뚜껑)
      c.drawCircle(ctr + const Offset(2, 4), 104, Paint()
        ..color = Colors.black.withValues(alpha: .3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      c.drawCircle(ctr, 104, Paint()..shader = const RadialGradient(center: Alignment(-.35, -.4), colors: [Color(0xFFB7D0DF), _ueBlue, _ueBlueDark]).createShader(Rect.fromCircle(center: ctr, radius: 104)));
      for (var k = 0; k < 36; k++) {
        final a = k * math.pi / 18;
        c.drawLine(ctr + Offset(math.cos(a), math.sin(a)) * 96, ctr + Offset(math.cos(a), math.sin(a)) * 104, Paint()
          ..color = Colors.black.withValues(alpha: .18)
          ..strokeWidth = 2);
      }
      final plate = RRect.fromRectAndRadius(Rect.fromCenter(center: ctr, width: 120, height: 60), const Radius.circular(6));
      c.drawRRect(plate, Paint()..color = const Color(0xFF1A1D21));
      lpText(c, 'UE', ctr + const Offset(0, -12), size: 18, color: Colors.white, w: FontWeight.w900);
      lpText(c, 'J120  EXPLOSION-PROOF', ctr + const Offset(0, 12), size: 7, color: const Color(0xFFCBD2D8));
      // 덮개 잠금 나사
      c.drawCircle(const Offset(268, 214), 6, Paint()..color = const Color(0xFF9AA3AB));
      c.drawCircle(const Offset(268, 214), 2.4, Paint()..color = const Color(0xFF3A4046));
      if (v.hot == 'cover') {
        _glow(c, const Offset(268, 214), 16);
        _turnArrow(c, ctr, 116, false, const Color(0xFFEA580C));
      }
      c.restore();
      return;
    }

    // 안쪽(덮개를 뗀 모습)
    c.drawCircle(ctr, 104, Paint()..color = _ueBlueDark);
    c.drawCircle(ctr, 96, Paint()..shader = const RadialGradient(center: Alignment(-.2, -.3), colors: [Color(0xFFDDE2E7), Color(0xFFAEB6BE)]).createShader(Rect.fromCircle(center: ctr, radius: 96)));
    for (var k = 0; k < 48; k++) {
      final a = k * math.pi / 24;
      c.drawLine(ctr + Offset(math.cos(a), math.sin(a)) * 97, ctr + Offset(math.cos(a), math.sin(a)) * 103, Paint()
        ..color = Colors.white.withValues(alpha: .15)
        ..strokeWidth = 1.5);
    }

    // 단자대(N.O. COM N.C.)
    final tb = RRect.fromRectAndRadius(const Rect.fromLTWH(118, 52, 124, 36), const Radius.circular(5));
    lpShadow(c, tb, blur: 3, off: const Offset(0, 2), a: .25);
    c.drawRRect(tb, Paint()..color = const Color(0xFFF1EBDD));
    const termX = [146.0, 180.0, 214.0];
    const termName = ['N.O.', 'COM.', 'N.C.'];
    for (var i = 0; i < 3; i++) {
      lpText(c, termName[i], Offset(termX[i], 60), size: 7.5, color: const Color(0xFF1F2328), w: FontWeight.w900);
      lpScrew(c, Offset(termX[i], 77), r: 7);
    }
    if (v.hot == 'term') _glow(c, const Offset(180, 74), 40);
    // 현장 선
    if (!v.wiresOff) {
      const cols = [Color(0xFFDC2626), Color(0xFF111316), Color(0xFFF8FAFC)];
      for (var i = 0; i < 3; i++) {
        if (i == 2) continue; // N.C. 안 씀(예: N.O.·COM 두 선)
        final w = Path()
          ..moveTo(termX[i], 77)
          ..cubicTo(termX[i] - 10, 100, 60, 100, 24, 138);
        lpWire(c, w, cols[i], w: 3.2);
      }
    }
    // 마이크로스위치(검은 몸통) + 단자대와 잇는 내부 선
    final sw = RRect.fromRectAndRadius(const Rect.fromLTWH(128, 98, 104, 40), const Radius.circular(5));
    c.drawRRect(sw, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3A3F45), Color(0xFF15181C)]).createShader(sw.outerRect));
    lpText(c, 'SPDT', const Offset(180, 112), size: 8, color: const Color(0xFFB4BBC2), w: FontWeight.w900);
    // 접점 모양(작게): COM 칼날이 N.O. 또는 N.C.에 붙음
    final bladeEnd = v.closedNO ? const Offset(162, 124) : const Offset(198, 124);
    c.drawLine(const Offset(180, 132), bladeEnd, Paint()
      ..color = const Color(0xFFFBBF24)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round);
    c.drawCircle(const Offset(160, 124), 2.4, Paint()..color = const Color(0xFFFBBF24));
    c.drawCircle(const Offset(200, 124), 2.4, Paint()..color = const Color(0xFFFBBF24));
    // 플런저
    c.drawRect(const Rect.fromLTWH(176, 138, 8, 18), Paint()..color = const Color(0xFFE5E7EB));
    // 돌리면 안 되는 너트(플런저 가이드)
    _hexagon(c, const Offset(180, 162), 10, Paint()..shader = const LinearGradient(colors: [Color(0xFFEDEFF1), Color(0xFF8E979F)]).createShader(Rect.fromCircle(center: const Offset(180, 162), radius: 10)));
    if (v.hot == 'donot') {
      _glow(c, const Offset(180, 162), 20);
      c.drawLine(const Offset(166, 148), const Offset(194, 176), Paint()
        ..color = const Color(0xFFDC2626)
        ..strokeWidth = 3);
      c.drawLine(const Offset(194, 148), const Offset(166, 176), Paint()
        ..color = const Color(0xFFDC2626)
        ..strokeWidth = 3);
    }
    // 조정 받침판
    final bracket = RRect.fromRectAndRadius(const Rect.fromLTWH(140, 180, 104, 40), const Radius.circular(6));
    c.drawRRect(bracket, Paint()..shader = const LinearGradient(colors: [Color(0xFFC9CFD5), Color(0xFF9AA3AB)]).createShader(bracket.outerRect));
    lpText(c, 'TURN IN TO RAISE', const Offset(176, 226), size: 6.5, color: const Color(0xFF1F2328), w: FontWeight.w800);
    // 5/8" 조정 육각
    if (v.hot == 'hex') _glow(c, const Offset(180, 200), 30);
    final hexRot = v.hexTurn * .35;
    _hexagon(c, const Offset(180, 200), 17, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF4F5F6), Color(0xFFB4BBC2), Color(0xFF6D757D)]).createShader(Rect.fromCircle(center: const Offset(180, 200), radius: 17)), rot: hexRot);
    _hexagon(c, const Offset(180, 200), 17, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF4A5057), rot: hexRot);
    c.drawCircle(const Offset(180, 200), 4, Paint()..color = const Color(0xFF6D757D));
    if (v.hexTurn != 0) _turnArrow(c, const Offset(180, 200), 27, v.hexTurn > 0, v.hexTurn > 0 ? const Color(0xFF16A34A) : const Color(0xFFEA580C));
    // 십자 잠금 나사
    if (v.hot == 'lock') _glow(c, const Offset(222, 200), 18);
    _phillips(c, const Offset(222, 200), 7);
    if (v.hot == 'lock') _turnArrow(c, const Offset(222, 200), 13, !v.lockLoose, const Color(0xFFEA580C));
    if (v.lockLoose) lpPill(c, '풀림', const Offset(222, 186), const Color(0xFFEA580C), size: 7);
    // 내부 접지 단자(오른쪽 전선관 쪽)
    c.drawCircle(const Offset(266, 138), 7, Paint()..color = const Color(0xFF16A34A));
    lpScrew(c, const Offset(266, 138), r: 5);
    if (v.hot == 'ground') _glow(c, const Offset(266, 138), 18);

    // 멀티미터 도통
    if (v.meter) {
      final probe = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;
      c.drawPath(Path()
        ..moveTo(termX[0], 77)
        ..quadraticBezierTo(130, 96, 80, 96), probe..color = const Color(0xFFDC2626));
      c.drawPath(Path()
        ..moveTo(termX[1], 77)
        ..quadraticBezierTo(170, 106, 80, 104), probe..color = const Color(0xFF111316));
      final m = RRect.fromRectAndRadius(const Rect.fromLTWH(2, 88, 78, 24), const Radius.circular(5));
      lpShadow(c, m, blur: 3, off: const Offset(0, 2), a: .3);
      c.drawRRect(m, Paint()..color = const Color(0xFF2B3036));
      lpText(c, v.closedNO ? '도통 ♪ 0.2 Ω' : '열림 OL', const Offset(41, 100), size: 8, color: v.closedNO ? const Color(0xFF4ADE80) : const Color(0xFFFCA5A5), w: FontWeight.w900);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(UeJ120Painter o) => true;
}

Widget _frame(Widget child, double aspect) => Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 520),
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

class _UeStep {
  final String say;
  final UeView view;
  final String? warn;
  const _UeStep(this.say, this.view, {this.warn});
}

const _setSteps = [
  _UeStep('제어실에 알리고 이 스위치가 물린 경보·인터록을 바이패스. 스위치 전원(회로)을 끊음. 방폭 지역은 회로가 살아 있으면 덮개를 열지 말 것', UeView(cover: true), warn: '방폭: 덮개 열기 전 회로 차단, 회로가 살아 있는 동안 덮개는 꽉 닫아 둠 (설명서)'),
  _UeStep('공정 원밸브를 잠그고 남은 압력을 빼서(벤트) 0으로', UeView(cover: true, hot: 'conn')),
  _UeStep('덮개 잠금 나사(5/64" 육각 렌치)를 풀고 덮개를 반시계 방향으로 돌려 엶. 나사산 윤활제는 닦지 말 것 (덮개가 들러붙음)', UeView(cover: true, hot: 'cover')),
  _UeStep('현장 선에 표를 붙이고 단자에서 풂 (예: N.O.·COM 두 선)', UeView(hot: 'term')),
  _UeStep('멀티미터를 도통(Ω)으로 COM–N.O.에 댐. 압력 0에서는 열림(OL)', UeView(wiresOff: true, meter: true, hot: 'term')),
  _UeStep('압력 접속구에 시험 압력원(핸드 펌프 + 표준 압력계)을 연결. 스패너는 압력 접속구 육각에 대고, 본체를 돌려 조이지 말 것 (센서 손상)', UeView(wiresOff: true, meter: true, hot: 'conn')),
  _UeStep('십자 잠금 나사를 풂 (반시계)', UeView(wiresOff: true, meter: true, lockLoose: true, hot: 'lock')),
  _UeStep('5/8" 육각 조정 나사를 돌림: 시계 방향 = 설정점 올림, 반시계 = 내림 ("TURN IN TO RAISE"). 조금씩', UeView(wiresOff: true, meter: true, lockLoose: true, hexTurn: 1, hot: 'hex')),
  _UeStep('바로 위 너트(플런저 가이드)는 돌리지 말 것', UeView(wiresOff: true, meter: true, lockLoose: true, hot: 'donot'), warn: '설명서 그림에 "DO NOT TURN"으로 표시된 곳'),
  _UeStep('압력을 천천히 올려 도통이 되는 순간(동작점)을 읽고, 천천히 내려 끊기는 순간(복귀점)을 읽음. 아래 "시험대"에서 해 볼 수 있음', UeView(wiresOff: true, meter: true, lockLoose: true, closedNO: true)),
  _UeStep('목표와 다르면 육각을 다시 조금 돌리고 시험. 맞으면 2~3번 더 올렸다 내려 같은 값이 나오는지 확인', UeView(wiresOff: true, meter: true, lockLoose: true, hexTurn: -1, hot: 'hex')),
  _UeStep('십자 잠금 나사를 조임 (시계). 조인 뒤 한 번 더 시험해서 값이 안 바뀌었는지 확인', UeView(wiresOff: true, meter: true, hot: 'lock')),
  _UeStep('압력원을 떼고 원밸브 복구. 선을 표대로 다시 물림 (14 AWG까지, 7~17 in·lb ≈ 0.8~1.9 N·m)', UeView(hot: 'term')),
  _UeStep('덮개를 손으로 끝까지 돌려 O-링이 다 물리게 닫고 덮개 잠금 나사 조임. 회로 복구, 바이패스 해제, 결과 기록', UeView(cover: true, hot: 'cover')),
];

class _UeWalk extends StatefulWidget {
  const _UeWalk();

  @override
  State<_UeWalk> createState() => _UeWalkState();
}

class _UeWalkState extends State<_UeWalk> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final s = _setSteps[_i];
    final last = _i == _setSteps.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _frame(CustomPaint(key: const Key('ue_walk_fig'), painter: UeJ120Painter(s.view)), 360 / 320),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.brandSoft, borderRadius: BorderRadius.circular(20)),
                child: Text('${_i + 1} / ${_setSteps.length}', key: const Key('ue_walk_count'), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.brand)),
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
              child: OutlinedButton.icon(key: const Key('ue_walk_prev'), onPressed: _i == 0 ? null : () => setState(() => _i--), icon: const Icon(AppIcons.back), label: const Text('이전')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(key: const Key('ue_walk_next'), onPressed: () => setState(() => _i = last ? 0 : _i + 1), icon: Icon(last ? Icons.replay : AppIcons.forward), label: Text(last ? '처음부터' : '다음')),
            ),
          ],
        ),
      ],
    );
  }
}

// ───────── 시험대 ─────────

class _Bench extends StatefulWidget {
  const _Bench();

  @override
  State<_Bench> createState() => _BenchState();
}

class _BenchState extends State<_Bench> {
  // 그림용 스위치: 범위 0~10 bar, 상승 동작(고 경보), 데드밴드 0.4 bar 고정.
  static const double _db = 0.4, _step = 0.25;
  static const double _target = 6.0;
  double _sp = 5.2; // 지금 설정점(상승 동작점)
  double _p = 0;
  bool _tripped = false;
  bool _lockLoose = false;
  int _lastTurn = 0;
  double? _tripAt, _resetAt;

  void _setP(double v) {
    setState(() {
      final up = v > _p;
      _p = v;
      if (!_tripped && up && _p >= _sp) {
        _tripped = true;
        _tripAt = _p;
      } else if (_tripped && !up && _p <= _sp - _db) {
        _tripped = false;
        _resetAt = _p;
      }
    });
  }

  void _turn(int dir) {
    if (!_lockLoose) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('먼저 십자 잠금 나사를 푸십시오')));
      return;
    }
    setState(() {
      _sp = (_sp + dir * _step).clamp(1.0, 9.0);
      _lastTurn = dir;
      _tripAt = null;
      _resetAt = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final err = _tripAt == null ? null : _tripAt! - _target;
    final ok = err != null && err.abs() <= 0.1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('목표: 압력이 ${_target.toStringAsFixed(1)} bar로 오르면 동작 (고압 경보)', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.text)),
        const SizedBox(height: 8),
        _frame(CustomPaint(key: const Key('ue_bench_fig'), painter: _BenchPainter(_p, _tripped)), 360 / 150),
        const SizedBox(height: 6),
        Text('시험 압력 ${_p.toStringAsFixed(2)} bar', key: const Key('ue_bench_p'), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSub)),
        Slider(key: const Key('ue_bench_slider'), min: 0, max: 10, divisions: 200, value: _p, onChanged: _setP),
        _frame(CustomPaint(painter: UeJ120Painter(UeView(wiresOff: true, meter: true, lockLoose: _lockLoose, closedNO: _tripped, hexTurn: _lastTurn, hot: _lockLoose ? 'hex' : 'lock'))), 360 / 320),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(key: const Key('ue_bench_lock'), onPressed: () => setState(() => _lockLoose = !_lockLoose), child: Text(_lockLoose ? '잠금 나사 조이기' : '잠금 나사 풀기')),
            OutlinedButton(key: const Key('ue_bench_cw'), onPressed: () => _turn(1), child: const Text('육각 시계 ¼바퀴 (올림)')),
            OutlinedButton(key: const Key('ue_bench_ccw'), onPressed: () => _turn(-1), child: const Text('육각 반시계 ¼바퀴 (내림)')),
          ],
        ),
        const SizedBox(height: 10),
        refDataRow('동작점', _tripAt == null ? '압력을 올려 보십시오' : '${_tripAt!.toStringAsFixed(2)} bar (목표와 ${err! >= 0 ? '+' : ''}${err.toStringAsFixed(2)})'),
        refGap(),
        refDataRow('복귀점', _resetAt == null ? '동작 뒤 압력을 내려 보십시오' : '${_resetAt!.toStringAsFixed(2)} bar'),
        refGap(),
        refDataRow('데드밴드', _tripAt != null && _resetAt != null ? '${(_tripAt! - _resetAt!).toStringAsFixed(2)} bar' : '동작점 − 복귀점'),
        const SizedBox(height: 8),
        if (err != null) ok ? refTipBox('목표 안 (±0.1 bar). 잠금 나사를 조이고 한 번 더 확인') : refWarnBox(err < 0 ? '일찍 동작함 → 잠금 나사 풀고 육각을 시계 방향(올림)으로' : '늦게 동작함 → 육각을 반시계 방향(내림)으로'),
        const SizedBox(height: 8),
        const Text('※ 그림용 스위치: 범위 0~10 bar, 데드밴드 0.4 bar 고정, ¼바퀴 = 0.25 bar로 정한 흉내입니다. 실제 육각 한 바퀴에 바뀌는 양은 설명서에 없고 모델(범위)마다 다릅니다.', style: TextStyle(fontSize: 12, color: AppColors.textSub)),
      ],
    );
  }
}

class _BenchPainter extends CustomPainter {
  final double p;
  final bool tripped;
  const _BenchPainter(this.p, this.tripped);

  @override
  void paint(Canvas canvas, Size size) {
    final c = canvas;
    c.save();
    c.scale(size.width / 360, size.height / 150);
    // 핸드 펌프
    final pump = RRect.fromRectAndRadius(const Rect.fromLTWH(14, 70, 70, 40), const Radius.circular(8));
    lpShadow(c, pump, blur: 4, off: const Offset(1, 3), a: .25);
    c.drawRRect(pump, Paint()..shader = const LinearGradient(colors: [Color(0xFF5B636B), Color(0xFF2B3036)]).createShader(pump.outerRect));
    c.drawRect(const Rect.fromLTWH(30, 40, 8, 30), Paint()..color = const Color(0xFF9AA3AB));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(14, 32, 52, 10), const Radius.circular(5)), Paint()..color = const Color(0xFFDC2626));
    lpText(c, '핸드 펌프', const Offset(49, 124), size: 8, color: AppColors.textSub, w: FontWeight.w800);
    // 관
    final line = Paint()
      ..color = const Color(0xFF9AA3AB)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    c.drawLine(const Offset(84, 90), const Offset(300, 90), line);
    c.drawLine(const Offset(170, 90), const Offset(170, 70), line);
    // 표준 압력계
    const g = Offset(170, 44);
    c.drawCircle(g + const Offset(1, 3), 30, Paint()..color = Colors.black.withValues(alpha: .25));
    c.drawCircle(g, 30, Paint()..shader = const RadialGradient(colors: [Colors.white, Color(0xFFDDE2E7)]).createShader(Rect.fromCircle(center: g, radius: 30)));
    c.drawCircle(g, 30, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF6D757D));
    for (var i = 0; i <= 10; i++) {
      final a = math.pi * .75 + i / 10 * math.pi * 1.5;
      c.drawLine(g + Offset(math.cos(a), math.sin(a)) * 22, g + Offset(math.cos(a), math.sin(a)) * 27, Paint()
        ..color = const Color(0xFF2B3036)
        ..strokeWidth = i % 5 == 0 ? 1.6 : 1);
    }
    final na = math.pi * .75 + (p / 10).clamp(0.0, 1.0) * math.pi * 1.5;
    c.drawLine(g, g + Offset(math.cos(na), math.sin(na)) * 24, Paint()
      ..color = const Color(0xFFDC2626)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round);
    c.drawCircle(g, 3, Paint()..color = const Color(0xFF2B3036));
    lpText(c, '${p.toStringAsFixed(2)} bar', g + const Offset(0, 14), size: 7, color: const Color(0xFF2B3036), w: FontWeight.w900);
    lpText(c, '표준 압력계', const Offset(110, 22), size: 8, color: AppColors.textSub, w: FontWeight.w800);
    // 스위치(작게)
    final sw = RRect.fromRectAndRadius(const Rect.fromLTWH(270, 44, 60, 56), const Radius.circular(12));
    lpShadow(c, sw, blur: 4, off: const Offset(1, 3), a: .25);
    c.drawRRect(sw, Paint()..shader = const LinearGradient(colors: [Color(0xFFA9C6D8), _ueBlueDark]).createShader(sw.outerRect));
    lpText(c, 'J120', const Offset(300, 72), size: 10, color: Colors.white, w: FontWeight.w900);
    // 램프(동작 표시)
    final lamp = tripped ? const Color(0xFF22C55E) : const Color(0xFF9CA3AF);
    if (tripped) {
      c.drawCircle(const Offset(300, 124), 14, Paint()
        ..color = lamp.withValues(alpha: .5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }
    c.drawCircle(const Offset(300, 124), 8, Paint()..color = lamp);
    lpText(c, tripped ? '동작 (COM–N.O. 도통)' : '대기 (COM–N.O. 열림)', const Offset(232, 124), size: 8, color: tripped ? const Color(0xFF15803D) : AppColors.textSub, w: FontWeight.w900);
    c.restore();
  }

  @override
  bool shouldRepaint(_BenchPainter o) => o.p != p || o.tripped != tripped;
}

// ───────── 화면 ─────────

class UeSwitchGuidePage extends StatefulWidget {
  const UeSwitchGuidePage({super.key});

  @override
  State<UeSwitchGuidePage> createState() => _UeSwitchGuidePageState();
}

class _UeSwitchGuidePageState extends State<UeSwitchGuidePage> {
  // 처음엔 H122(사용자가 쓰는 형: 바깥 다이얼, 스위치 2개, single conduit)
  bool _h122 = true;

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
  );

  @override
  Widget build(BuildContext context) {
    List<Widget> rows(List<(String, String)> r) => [
      for (var i = 0; i < r.length; i++) ...[if (i > 0) refGap(), refDataRow(r[i].$1, r[i].$2)],
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('UE 120 시리즈 스위치 셋팅')),
      body: ListView(
        key: const Key('ue_list'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          refChips(
            items: const ['H121·H122 (바깥 다이얼)', 'J120 (안쪽 육각)'],
            selected: _h122 ? 'H121·H122 (바깥 다이얼)' : 'J120 (안쪽 육각)',
            onSelected: (v) => setState(() => _h122 = v.startsWith('H')),
          ),
          const SizedBox(height: 12),
          if (_h122) ...h122Section(_title, rows) else ...[
          refIntroBadge('UE 120 시리즈 방폭 압력 스위치 J120(차압 J120K) 설정점 맞추는 법입니다. 근거는 UE 설치·운전 안내서 IMP120. 그림은 실물을 단순화했습니다.'),
          _title('부품 (덮개 연 모습)'),
          _frame(CustomPaint(key: const Key('ue_parts_fig'), painter: const UeJ120Painter(UeView())), 360 / 320),
          const SizedBox(height: 10),
          ...rows(const [
            ('단자대', 'N.O.(평상시 열림)·COM(공통)·N.C.(평상시 닫힘). SPDT 기준'),
            ('마이크로스위치', '설정점에서 딸깍 바뀌는 스냅 스위치'),
            ('플런저', '센서(벨로즈·다이어프램·피스톤)가 밀어 스위치를 누름'),
            ('5/8" 육각 조정 나사', '설정점 조정. 시계 = 올림, 반시계 = 내림 ("TURN IN TO RAISE")'),
            ('십자 잠금 나사', '조정 나사를 잠금. 풀어야 돌릴 수 있음'),
            ('위 너트', '"DO NOT TURN" (돌리지 말 것)'),
            ('내부 접지 단자', '오른쪽 전선관 구멍 옆. 주 접지는 이것, 바깥 접지 단자는 보조'),
            ('전선관 구멍', '3/4" NPT 하나 또는 둘. 안 쓰는 구멍은 같이 오는 방폭 마개로'),
            ('압력 접속구·벤트 구멍', '아래쪽. 조일 때 스패너는 접속구 육각에'),
          ]),
          _title('준비물'),
          ...rows(const [
            ('공구', '일자·십자 드라이버, 5/8" (16 mm) 스패너, 5/64" 육각 렌치 (설명서)'),
            ('압력원', '교정된 압력원: 핸드 펌프 + 표준 압력계 (또는 압력 교정기)'),
            ('멀티미터', '도통(Ω)으로 COM–N.O. 또는 COM–N.C.'),
          ]),
          _title('따라하기: 설정점 맞추기'),
          const _UeWalk(),
          _title('시험대: 직접 해 보기'),
          const _Bench(),
          _title('데드밴드 조정형 (옵션 1519, 모델 15622·15834~15839)'),
          ...[
            refStep(1, '설정점과 데드밴드를 정함. 예: 상승 설정점 20 psi, 데드밴드 6 psi'),
            refStep(2, '하강 설정점 = 20 − 6 = 14 psi를 위의 조정 나사로 먼저 맞춤 (이 값이 고정)'),
            refStep(3, '스위치에 붙은 조정 휠을 돌려 상승 설정점을 20 psi에 맞춤. 휠은 상승 쪽만 바꾸고 하강 쪽은 그대로'),
          ],
          const SizedBox(height: 8),
          refTipBox('보통 모델은 데드밴드가 모델마다 정해져 있어 따로 못 바꿈 (카탈로그 120-B 모델표). 동작점을 옮기면 복귀점도 같이 옮겨감'),
          _title('배선'),
          refTable(
            headers: const ['스위치', '단자'],
            flex: const [2, 6],
            rows: const [
              ['SPDT', 'N.O. · COM. · N.C. 하나씩'],
              ['DPDT', 'N.O.1·COM.1·N.C.1 / N.O.2·COM.2·N.C.2 (두 접점 같이 동작)'],
              ['2SPDT', 'HIGH 단자대·LOW 단자대 따로 (LOW 스위치는 배선이 반대로 되어 있으니 주의)'],
            ],
          ),
          const SizedBox(height: 10),
          ...rows(const [
            ('전선', '구리 90 ℃ 이상, 최대 14 AWG (약 2.0 mm²)'),
            ('조임', '7~17 in·lb (약 0.8~1.9 N·m)'),
            ('접점 정격', '15 A 125/250/480 VAC (저항 부하), 2 A 30 VDC, 1 A 48 VDC, 0.5 A 125 VDC. 명판 정격 넘기면 첫 동작에도 상할 수 있음'),
            ('방폭', '전선관은 함에서 18" (약 450 mm) 안에 실링. 방폭 실링 피팅 필수'),
            ('습기', '전선관 들어가는 곳을 잘 막음. 세로 설치 권장 (함에 물 안 들게)'),
          ]),
          _title('설치'),
          ...rows(const [
            ('위치', '충격·진동·온도 변화가 적은 곳. 명판 주위 온도 넘지 말 것 (-50~71 ℃)'),
            ('방향', '아무 방향 가능하나 세로 권장. J120·J120K 모델 520~525·530~535는 압력 접속구가 아래로, 가로면 벤트 구멍을 아래로 (설정점이 바뀔 수 있어 다시 맞춤)'),
            ('차압형', '맞대는 센서형(36~39, 147~157, 367)은 압력 접속구를 가로로'),
            ('조이기', '압력 접속구 육각에 스패너. 함을 돌려 조이면 센서·용접부 상함'),
            ('고정', '함의 1/4" 나사 구멍 4개로 벽에, 또는 압력 접속구로 단단한 배관에'),
          ]),
          ],
          _title('압력 한도 (명판)'),
          ...rows(const [
            ('프루프 압력', '가끔(기동·시험) 걸려도 영구 손상이 없는 최대 압력. 걸린 뒤 다시 맞춰야 할 수 있음'),
            ('오버 레인지', '계속 걸려도 손상 없고 설정점 반복성이 유지되는 최대 압력'),
            ('차압 작동 범위', '차압형에서 두 센서를 안전하게 쓰는 범위'),
            ('주의', '명판 한도는 순간 서지로도 넘지 말 것. 최대 압력에서 자주 동작하면 센서 수명 줄어듦'),
          ]),
          _title('사양 요약'),
          ...rows(const [
            ('반복성', '대부분 모델 ±1% FS (일부 ±0.5%) (카탈로그)'),
            ('방폭', 'Class I Div.1 B·C·D, Ex db IIC T6, 함 4X·IP66'),
            ('날짜 코드', '명판 "YYWW" (연·주)'),
            ('H121·H122', '바깥 손잡이와 눈금으로 설정. H122는 앞(LOW) 스위치를 뒤(HIGH)보다 높게 두지 말 것'),
          ]),
          _title('권장 사항 (설명서)'),
          ...[
            refStep(1, '고장 나면 사람·설비가 위험한 곳은 예비 스위치를 같이'),
            refStep(2, '설정점이 흘러가는(드리프트) 기미가 보이면 바로 점검'),
            refStep(3, '중요 설비는 예방 정비와 주기 시험'),
            refStep(4, '현장에서 개조 금지, 바꿀 수 있는 부품 없음 (부품을 바꾸면 방폭 인증 무효)'),
            refStep(5, '닦을 때는 젖은 천 (정전기 방지)'),
          ],
          const SizedBox(height: 14),
          refTipBox('시험 결과는 계기 교정 → 교정 점검 → 스위치에 기록 (동작점·복귀점·데드밴드 판정)'),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('ue_manual'),
            onPressed: () => openEquipManual(context, key: 'UE|J120', title: 'UE J120'),
            icon: const Icon(Icons.menu_book, size: 18),
            label: const Text('UE 설명서 (원본 PDF)'),
          ),
        ],
      ),
    );
  }
}
