// 축 정렬 안내 그림: (1) 다이얼을 어디에 걸고 어떤 거리를 재는지 보여 주는 측정 그림, (2) 3시·6시·9시와 보는 방향을 보여 주는 시계 그림.
// 입력칸 이름의 번호(①②③④)가 그림의 번호와 같다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'alignment_machine_art.dart';
import 'alignment_math.dart';

const Color _dialA = Color(0xFFE08A00);
const Color _dialB = Color(0xFF2F6FE0);

/// 그림에 나오는 번호 글자.
const List<String> kAlignNumbers = ['①', '②', '③', '④'];

void _text(Canvas canvas, String s, Offset at, {double size = 12, Color color = AppColors.text, FontWeight w = FontWeight.w800, TextAlign align = TextAlign.center, double maxW = 140}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color, fontWeight: w, height: 1.2)),
    textAlign: align,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxW);
  tp.paint(canvas, Offset(at.dx - tp.width / 2, at.dy - tp.height / 2));
}

/// 번호 동그라미.
void _badge(Canvas canvas, String n, Offset c, Color color) {
  canvas.drawCircle(c.translate(0, 1), 10, Paint()..color = Colors.black.withValues(alpha: 0.15));
  canvas.drawCircle(c, 10, Paint()..color = color);
  _text(canvas, n, c, size: 12, color: Colors.white, w: FontWeight.w900);
}

/// 양쪽 화살표 치수선.
void _dim(Canvas canvas, double x1, double x2, double y, String n, Color color, {double extLen = 0, double extFrom = 0}) {
  final p = Paint()
    ..color = color
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round;
  if (extLen != 0) {
    // 치수를 재는 자리에서 치수선까지 이어 주는 가는 보조선
    final thin = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(x1, extFrom), Offset(x1, y + 3), thin);
    canvas.drawLine(Offset(x2, extFrom), Offset(x2, y + 3), thin);
  }
  canvas.drawLine(Offset(x1, y), Offset(x2, y), p);
  for (final (x, dir) in [(x1, 1.0), (x2, -1.0)]) {
    canvas.drawLine(Offset(x, y), Offset(x + dir * 6, y - 3.5), p);
    canvas.drawLine(Offset(x, y), Offset(x + dir * 6, y + 3.5), p);
  }
  _badge(canvas, n, Offset((x1 + x2) / 2, y), color);
}

/// 다이얼 게이지 하나(둥근 몸통 + 바늘 + 플런저).
void _dial(Canvas canvas, Offset c, Color color, String label, {required Offset tip}) {
  canvas.drawLine(c, tip, Paint()
    ..color = Colors.black87
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round);
  canvas.drawCircle(c.translate(0, 2), 14, Paint()..color = Colors.black.withValues(alpha: 0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  canvas.drawCircle(c, 14, Paint()..color = color);
  canvas.drawCircle(c, 10.5, Paint()..color = Colors.white);
  canvas.drawLine(c, c + const Offset(4, -6), Paint()..color = Colors.black87..strokeWidth = 1.6..strokeCap = StrokeCap.round);
  canvas.drawCircle(c, 1.6, Paint()..color = Colors.black87);
  canvas.drawArc(Rect.fromCircle(center: c, radius: 12.5), math.pi * 1.05, math.pi * 0.9, false, Paint()..color = Colors.white.withValues(alpha: 0.55)..style = PaintingStyle.stroke..strokeWidth = 1.5);
  _text(canvas, label, c.translate(0, -25), size: 12, color: color);
}

/// 측정 그림: 옆에서 본 펌프(고정)·모터(이동)·커플링·다이얼과 재는 거리.
class AlignSetupPainter extends CustomPainter {
  final AlignMethod method;
  AlignSetupPainter(this.method);

  static const double _topRoom = 46; // 다이얼 위 글씨 자리

  /// 그림에 필요한 높이: 위 여백 + 기계 + 거리선 네 줄.
  static double heightFor(double w) => _topRoom + alignMachineScale(w) * 0.60 + 160;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final lay = paintMachineSide(canvas, w, topRoom: _topRoom);
    final axisY = lay.axisY, ground = lay.ground;
    final xHubL = lay.xHubL, xC = lay.xC, xHubR = lay.xHubR, hubR = lay.hubR;
    final frontX = lay.frontX, rearX = lay.rearX;

    // 바닥 선(빗금)
    final gp = Paint()
      ..color = AppColors.textFaint
      ..strokeWidth = 1.6;
    canvas.drawLine(Offset(w * 0.02, ground + 4), Offset(w * 0.98, ground + 4), gp);
    for (var x = w * 0.03; x < w * 0.97; x += 9) {
      canvas.drawLine(Offset(x, ground + 4), Offset(x - 5, ground + 10), gp..strokeWidth = 1);
    }

    // 커플링 중심선
    final cp = Paint()
      ..color = AppColors.text.withValues(alpha: 0.6)
      ..strokeWidth = 1.4;
    for (var y = axisY - hubR - 14; y < ground; y += 8) {
      canvas.drawLine(Offset(xC, y), Offset(xC, y + 4), cp);
    }
    _text(canvas, '펌프 (고정)', Offset(w * 0.17, ground + 19), size: 11, color: AppColors.textSub);
    _text(canvas, '커플링 중심', Offset(xC, ground + 19), size: 11, color: AppColors.textSub);
    _text(canvas, '앞발', Offset(frontX, ground + 19), size: 11, color: AppColors.textSub);
    _text(canvas, '뒷발', Offset(rearX, ground + 19), size: 11, color: AppColors.textSub);

    if (method == AlignMethod.reverse) {
      final xAplane = (xC + 2 + xHubR) / 2 + 2; // A가 읽는 모터 림(모터 쪽 커플링)
      final xBplane = (xHubL + xC - 2) / 2 - 2; // B가 읽는 펌프 림
      final topA = axisY - hubR;
      // 브래킷: A는 펌프 허브에서 시작해 모터 림 위로, B는 모터 허브에서 시작해 펌프 림 위로
      final armA = Paint()
        ..color = _dialA
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      final armB = Paint()
        ..color = _dialB
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(xHubL + 6, topA), Offset(xHubL + 6, topA - 28), armA);
      canvas.drawLine(Offset(xHubL + 6, topA - 28), Offset(xAplane, topA - 28), armA);
      canvas.drawLine(Offset(xHubR - 6, topA), Offset(xHubR - 6, topA - 44), armB);
      canvas.drawLine(Offset(xHubR - 6, topA - 44), Offset(xBplane, topA - 44), armB);
      _dial(canvas, Offset(xAplane, topA - 28), _dialA, 'A', tip: Offset(xAplane, topA));
      _dial(canvas, Offset(xBplane, topA - 44), _dialB, 'B', tip: Offset(xBplane, topA));

      // 거리선은 번호마다 한 줄씩(위에서 아래로 ① ② ③ ④).
      final y1 = ground + 46, y2 = ground + 74, y3 = ground + 102, y4 = ground + 130;
      _dim(canvas, xBplane, xAplane, y1, kAlignNumbers[0], _dialB, extFrom: axisY + hubR);
      _dim(canvas, xBplane, xC, y2, kAlignNumbers[1], AppColors.text, extFrom: axisY + hubR);
      _dim(canvas, xAplane, frontX, y3, kAlignNumbers[2], _dialA, extFrom: ground);
      _dim(canvas, xAplane, rearX, y4, kAlignNumbers[3], _dialA, extFrom: ground);
      _text(canvas, 'A·B 두 접촉면 사이', Offset(xAplane + 96, y1), size: 11, color: _dialB, w: FontWeight.w700, maxW: 150);
      _text(canvas, 'B면 → 커플링 중심', Offset(xC + 92, y2), size: 11, color: AppColors.text, w: FontWeight.w700, maxW: 150);
      _text(canvas, 'A면 → 앞발', Offset(frontX + 62, y3), size: 11, color: _dialA, w: FontWeight.w700, maxW: 120);
      _text(canvas, 'A면 → 뒷발', Offset(rearX - 62, y4 - 14), size: 11, color: _dialA, w: FontWeight.w700, maxW: 120);
    } else {
      final topR = axisY - hubR;
      final xRim = (xC + 2 + xHubR) / 2; // 림을 읽는 자리(모터 쪽 커플링)
      final armP = Paint()
        ..color = _dialA
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(xHubL + 6, topR), Offset(xHubL + 6, topR - 30), armP);
      canvas.drawLine(Offset(xHubL + 6, topR - 30), Offset(xRim, topR - 30), armP);
      _dial(canvas, Offset(xRim, topR - 30), _dialA, '림', tip: Offset(xRim, topR));
      // 페이스: 모터 쪽 커플링 옆면(왼쪽 면)을 반지름 ρ 자리에서 눌러 읽는다
      final faceY = axisY - hubR * 0.62;
      canvas.drawLine(Offset(xHubL + 6, topR - 30), Offset(xHubL + 6, faceY), armP);
      canvas.drawLine(Offset(xHubL + 6, faceY), Offset(xC + 2, faceY), Paint()..color = Colors.black87..strokeWidth = 2.5..strokeCap = StrokeCap.round);
      canvas.drawCircle(Offset(xC + 2, faceY), 3.2, Paint()..color = _dialA);
      _text(canvas, '페이스', Offset(xHubL - 14, faceY - 10), size: 11, color: _dialA);
      // 반지름(④)
      final rx = xHubR + 14;
      final p = Paint()
        ..color = AppColors.text
        ..strokeWidth = 1.6;
      canvas.drawLine(Offset(rx, axisY), Offset(rx, faceY), p);
      canvas.drawLine(Offset(xHubR, faceY), Offset(rx + 4, faceY), p..strokeWidth = 1);
      _badge(canvas, kAlignNumbers[3], Offset(rx + 14, (axisY + faceY) / 2), AppColors.text);

      final y1 = ground + 46, y2 = ground + 76, y3 = ground + 106;
      _dim(canvas, xC, xRim, y1, kAlignNumbers[0], AppColors.text, extFrom: axisY + hubR);
      _dim(canvas, xRim, frontX, y2, kAlignNumbers[1], _dialA, extFrom: ground);
      _dim(canvas, xRim, rearX, y3, kAlignNumbers[2], _dialA, extFrom: ground);
      _text(canvas, '림면 → 커플링 중심', Offset(xRim + 100, y1), size: 11, color: AppColors.text, w: FontWeight.w700, maxW: 150);
      _text(canvas, '림면 → 앞발', Offset(frontX + 56, y2), size: 11, color: _dialA, w: FontWeight.w700, maxW: 120);
      _text(canvas, '림면 → 뒷발', Offset(rearX - 62, y3 - 14), size: 11, color: _dialA, w: FontWeight.w700, maxW: 120);
      _text(canvas, '④ 페이스가 닿는 반지름', Offset(96, y1), size: 11, color: AppColors.text, w: FontWeight.w700, maxW: 150);
    }
  }

  @override
  bool shouldRepaint(covariant AlignSetupPainter old) => old.method != method;
}

/// 시계 그림: 고정 쪽(펌프)에서 이동 쪽(모터)을 바라본 모양의 축 끝. 12·3·6·9시와 읽는 순서.
/// 시각 이름은 눈금 안쪽, 방향 이름(위·오른쪽·아래·왼쪽)은 바깥에 둔다.
class AlignClockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 30;

    // 판(그림자 + 그라데이션 + 하이라이트)
    canvas.drawCircle(c.translate(0, 3), r, Paint()..color = Colors.black.withValues(alpha: 0.16)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFFFFFF), Color(0xFFE4EEF0)],
        ).createShader(rect),
    );
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = AppColors.brand);
    // 가운데: 축 끝
    canvas.drawCircle(c, r * 0.22, Paint()..color = const Color(0xFFB9C4CE));
    canvas.drawCircle(c, r * 0.22, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.black26);
    canvas.drawCircle(c, 2.4, Paint()..color = Colors.black54);

    // 읽는 순서: 시계 방향 호(12 → 3 → 6 → 9). 눈금 안쪽 가까이에 둔다.
    final arc = Paint()
      ..color = _dialA
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final ar = r * 0.66;
    const startAng = -math.pi / 2 + 0.32;
    const sweep = math.pi * 1.5 - 0.64;
    canvas.drawArc(Rect.fromCircle(center: c, radius: ar), startAng, sweep, false, arc);
    final endAng = startAng + sweep; // 9시 근처
    final tip = c + Offset(math.cos(endAng), math.sin(endAng)) * ar;
    final back = endAng + math.pi; // 화살촉은 진행 방향 뒤쪽으로 벌린다
    final tang = endAng + math.pi / 2;
    for (final d in [0.55, -0.55]) {
      final dir = Offset(math.cos(tang + math.pi + d), math.sin(tang + math.pi + d));
      canvas.drawLine(tip, tip + dir * 9, arc);
    }
    if (back.isNaN) return;

    // 눈금·시각 이름(안쪽)·방향 이름(바깥)
    final marks = <(double, String, String, Color)>[
      (0, '12시', '위', AppColors.text),
      (90, '3시', '오른쪽', AppColors.brand),
      (180, '6시', '아래', AppColors.brand),
      (270, '9시', '왼쪽', AppColors.brand),
    ];
    for (final (deg, name, dirName, color) in marks) {
      final a = (deg - 90) * math.pi / 180;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        c + dir * (r - 8),
        c + dir * r,
        Paint()
          ..color = color
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      _text(canvas, name, c + dir * (r * 0.84 - 4), size: 11, color: color, w: FontWeight.w900, maxW: 40);
      _text(canvas, dirName, c + dir * (r + 15), size: 11, color: AppColors.textSub, w: FontWeight.w700, maxW: 50);
    }
    // 12시는 0으로 맞춘다는 표시
    _text(canvas, '0 맞춤', c + const Offset(0, -1) * (r * 0.4), size: 10, color: _dialA, w: FontWeight.w800, maxW: 50);
  }

  @override
  bool shouldRepaint(covariant AlignClockPainter old) => false;
}
