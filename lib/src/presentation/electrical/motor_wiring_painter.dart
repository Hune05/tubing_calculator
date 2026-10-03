// 9단자·12단자 전동기 단자함 그림. 단자는 3열 격자(위에서부터 T1 T2 T3 / T4 T5 T6 / T7 T8 T9 / T10 T11 T12)에 놓고,
// 점퍼(연결편)는 같은 열·같은 줄 단자를 잇는 막대로, 전원선은 단자 옆 L1·L2·L3 표로 그린다.
// 접속표는 motor_wiring.dart. 색은 구분용이다(상 색 표시가 아니다).
import 'package:flutter/material.dart';

import 'motor_wiring.dart';

class MotorTerminalPainter extends CustomPainter {
  MotorTerminalPainter({
    required this.wiring,
    required this.text,
    required this.surface,
    required this.accent,
  });

  final MotorWiring wiring;
  final Color text;
  final Color surface;
  final Color accent;

  static const _phaseColors = [Color(0xFFC62828), Color(0xFF2E7D32), Color(0xFF1565C0)];

  /// 단자 [t](1부터)의 칸 위치: (줄, 열).
  static (int, int) cell(int t) => ((t - 1) ~/ 3, (t - 1) % 3);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rows = (wiring.terminals + 2) ~/ 3;
    final box = RRect.fromLTRBR(w * 0.06, h * 0.04, w * 0.94, h * 0.96, const Radius.circular(14));
    canvas.drawRRect(
      box.shift(const Offset(0, 4)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(
      box,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(surface, Colors.white, 0.5)!, Color.lerp(surface, Colors.black, 0.06)!],
        ).createShader(box.outerRect),
    );
    canvas.drawRRect(
      box,
      Paint()
        ..color = text.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final xs = [w * 0.3, w * 0.52, w * 0.74];
    final top = h * 0.16, bottom = h * 0.84;
    final step = rows == 1 ? 0.0 : (bottom - top) / (rows - 1);
    Offset pos(int t) {
      final (r, c) = cell(t);
      return Offset(xs[c], top + step * r);
    }

    // 점퍼 막대
    final link = Paint()
      ..shader = const LinearGradient(colors: [Color(0xFFD9893A), Color(0xFFB8682A)])
          .createShader(Rect.fromLTWH(0, 0, w, h))
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final hl = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final j in wiring.joins) {
      final pts = [for (final t in j) pos(t)];
      final a = pts.reduce((p, q) => (p.dy < q.dy || (p.dy == q.dy && p.dx < q.dx)) ? p : q);
      final b = pts.reduce((p, q) => (p.dy > q.dy || (p.dy == q.dy && p.dx > q.dx)) ? p : q);
      canvas.drawLine(a, b, link);
      canvas.drawLine(a.translate(-2, 3), b.translate(-2, -3), hl);
    }

    // 전원선 표
    void feed(List<int> list, int phase, String name) {
      for (final t in list) {
        final p = pos(t);
        final tag = Offset(p.dx + 40, p.dy);
        canvas.drawLine(p.translate(12, 0), tag.translate(-12, 0), Paint()
          ..color = _phaseColors[phase]
          ..strokeWidth = 3);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: tag, width: 30, height: 20), const Radius.circular(6)),
          Paint()..color = _phaseColors[phase],
        );
        _t(canvas, name, Offset(tag.dx, tag.dy - 7), Colors.white, bold: true, size: 12);
      }
    }

    feed(wiring.l1, 0, 'L1');
    feed(wiring.l2, 1, 'L2');
    feed(wiring.l3, 2, 'L3');

    // 단자
    for (var t = 1; t <= wiring.terminals; t++) {
      final p = pos(t);
      canvas.drawCircle(p, 12, Paint()..color = const Color(0xFF9AA3AD));
      canvas.drawCircle(p, 7, Paint()..color = const Color(0xFF59616B));
      // 점퍼 막대가 글자를 가리지 않게 배경 칩을 깐다.
      final chip = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(p.dx - 34, p.dy), width: 34, height: 20),
        const Radius.circular(6),
      );
      canvas.drawRRect(chip, Paint()..color = Color.lerp(surface, Colors.white, 0.6)!);
      canvas.drawRRect(
        chip,
        Paint()
          ..color = text.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      _t(canvas, 'T$t', Offset(p.dx - 34, p.dy - 8), text, bold: true, size: 13);
    }
  }

  void _t(Canvas c, String s, Offset at, Color color, {bool bold = false, double size = 13}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, color: color, fontWeight: bold ? FontWeight.w800 : FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at - Offset(tp.width / 2, 0));
  }

  @override
  bool shouldRepaint(MotorTerminalPainter old) => old.wiring != wiring;
}
