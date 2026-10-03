// 시퀀스 회로도(래더)와 전동기 단자함(Y·Δ 연결편) 그림(10-03). 계산은 ladder_sim.dart.
// 전기가 통하는 선·닫힌 접점·여자된 코일은 [live] 색으로, 끊긴 곳은 [dead] 색으로 그려 흐름이 보이게 한다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ladder_sim.dart';

const double _cellW = 96;
const double _rowH = 62;
const double _railPad = 14;
const double _outW = 96;

int _cells(List<LNode> series) => series.fold(
  0,
  (n, e) => n + switch (e) {
    LContact() => 1,
    LPar(:final paths) => paths.map(_cells).reduce(math.max),
  },
);

int _rows(List<LNode> series) => series.fold(
  1,
  (n, e) => math.max(
    n,
    switch (e) {
      LContact() => 1,
      LPar(:final paths) => paths.fold(0, (a, p) => a + _rows(p)),
    },
  ),
);

/// 회로도를 그릴 크기.
Size ladderSize(LadderCircuit c) {
  final cells = c.rungs.map((r) => _cells(r.series)).reduce(math.max);
  final rows = c.rungs.fold(0, (a, r) => a + _rows(r.series));
  return Size(_railPad * 2 + cells * _cellW + _outW, rows * _rowH + 12);
}

class LadderPainter extends CustomPainter {
  LadderPainter({
    required this.circuit,
    required this.state,
    required this.live,
    required this.dead,
    required this.text,
    required this.surface,
  });

  final LadderCircuit circuit;
  final Map<String, bool> state;
  final Color live;
  final Color dead;
  final Color text;
  final Color surface;

  late Canvas _c;
  late double _rightX;

  Paint _wire(bool on) => Paint()
    ..color = on ? live : dead
    ..strokeWidth = on ? 3 : 1.6
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  void _label(String s, Offset center, {double size = 10.5, bool bold = false, Color? color}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          color: color ?? text,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          height: 1.1,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _cellW - 6);
    tp.paint(_c, center - Offset(tp.width / 2, 0));
  }

  /// 접점 하나를 그리고, 오른쪽으로 전기가 넘어가는지 돌려준다.
  bool _contact(LContact e, double x, double y, bool inLive) {
    final closed = contactClosed(e, state);
    final outLive = inLive && closed;
    final cx = x + _cellW / 2;
    _c.drawLine(Offset(x, y), Offset(cx - 8, y), _wire(inLive));
    _c.drawLine(Offset(cx + 8, y), Offset(x + _cellW, y), _wire(outLive));
    final sym = Paint()
      ..color = closed ? live : text
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    _c.drawLine(Offset(cx - 8, y - 11), Offset(cx - 8, y + 11), sym);
    _c.drawLine(Offset(cx + 8, y - 11), Offset(cx + 8, y + 11), sym);
    if (e.nc) {
      _c.drawLine(Offset(cx - 12, y + 12), Offset(cx + 12, y - 12), sym);
    }
    if (closed) {
      _c.drawLine(Offset(cx - 8, y), Offset(cx + 8, y), _wire(inLive));
    }
    _label(e.label, Offset(cx, y + 14));
    return outLive;
  }

  /// 직렬 경로를 [x]부터 그리고 끝 x와 출력 전기 여부를 돌려준다. [cells]는 이 경로가 채울 칸 수.
  (double, bool) _series(List<LNode> series, double x, double y, bool inLive, int cells) {
    var live0 = inLive;
    var cx = x;
    var used = 0;
    for (final e in series) {
      switch (e) {
        case LContact():
          live0 = _contact(e, cx, y, live0);
          cx += _cellW;
          used += 1;
        case LPar(:final paths):
          final w = paths.map(_cells).reduce(math.max);
          var py = y;
          var any = false;
          final ends = <double>[];
          for (final p in paths) {
            final (_, out) = _series(p, cx, py, live0, w);
            any = any || out;
            ends.add(py);
            py += _rows(p) * _rowH;
          }
          // 병렬 묶음 양 끝을 세로로 잇는다.
          _c.drawLine(Offset(cx, y), Offset(cx, ends.last), _wire(live0));
          _c.drawLine(Offset(cx + w * _cellW, y), Offset(cx + w * _cellW, ends.last), _wire(live0 && any));
          live0 = live0 && any;
          cx += w * _cellW;
          used += w;
      }
    }
    if (used < cells) {
      _c.drawLine(Offset(cx, y), Offset(x + cells * _cellW, y), _wire(live0));
      cx = x + cells * _cellW;
    }
    return (cx, live0);
  }

  void _output(LRung r, double x, double y, bool inLive) {
    final on = state[r.outTag] ?? false;
    final ox = _rightX - _outW / 2;
    _c.drawLine(Offset(x, y), Offset(ox - 15, y), _wire(inLive));
    _c.drawLine(Offset(ox + 15, y), Offset(_rightX, y), _wire(state[r.outTag] ?? false));
    final fillColor = switch (r.kind) {
      LOutKind.lamp => r.outTag == 'GL' ? const Color(0xFF2E9E5B) : const Color(0xFFD64545),
      _ => live,
    };
    final center = Offset(ox, y);
    if (on) {
      _c.drawCircle(
        center,
        17,
        Paint()
          ..color = fillColor.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      _c.drawCircle(
        center,
        14,
        Paint()
          ..shader = RadialGradient(
            colors: [Color.lerp(fillColor, Colors.white, 0.35)!, fillColor],
          ).createShader(Rect.fromCircle(center: center, radius: 14)),
      );
    } else {
      _c.drawCircle(center, 14, Paint()..color = surface);
    }
    _c.drawCircle(
      center,
      14,
      Paint()
        ..color = on ? fillColor : text
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (r.kind == LOutKind.lamp) {
      final p = Paint()
        ..color = on ? Colors.white : text
        ..strokeWidth = 1.6;
      _c.drawLine(center + const Offset(-8, -8), center + const Offset(8, 8), p);
      _c.drawLine(center + const Offset(8, -8), center + const Offset(-8, 8), p);
    } else {
      _label(r.kind == LOutKind.timer ? 'T' : 'M', center - const Offset(0, 7), size: 12, bold: true, color: on ? Colors.white : text);
    }
    _label(r.outLabel, Offset(ox, y + 18));
  }

  @override
  void paint(Canvas canvas, Size size) {
    _c = canvas;
    final leftX = _railPad;
    _rightX = size.width - _railPad;
    final rail = Paint()
      ..color = text
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(leftX, 6), Offset(leftX, size.height - 6), rail);
    canvas.drawLine(Offset(_rightX, 6), Offset(_rightX, size.height - 6), rail);
    var y = _rowH / 2 + 2;
    final cells = circuit.rungs.map((r) => _cells(r.series)).reduce(math.max);
    for (final r in circuit.rungs) {
      final (endX, out) = _series(r.series, leftX, y, true, cells);
      _output(r, endX, y, out);
      y += _rows(r.series) * _rowH;
    }
  }

  @override
  bool shouldRepaint(LadderPainter old) => true;
}

/// 전동기 단자함: 위 U1·V1·W1, 아래 W2·U2·V2. Y는 아래 줄을 하나로, Δ는 위아래를 세로로 잇는다.
class TerminalBoxPainter extends CustomPainter {
  TerminalBoxPainter({
    required this.delta,
    required this.text,
    required this.surface,
    required this.accent,
  });

  final bool delta;
  final Color text;
  final Color surface;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final box = RRect.fromLTRBR(w * 0.12, h * 0.18, w * 0.88, h * 0.92, const Radius.circular(14));
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
    final xs = [w * 0.3, w * 0.5, w * 0.7];
    final yTop = h * 0.42, yBot = h * 0.74;
    const top = ['U1', 'V1', 'W1'];
    const bot = ['W2', 'U2', 'V2'];
    const supply = ['L1', 'L2', 'L3'];
    final link = Paint()
      ..shader = const LinearGradient(colors: [Color(0xFFD9893A), Color(0xFFB8682A)])
          .createShader(Rect.fromLTWH(0, 0, w, h))
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final hl = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    if (delta) {
      for (final x in xs) {
        canvas.drawLine(Offset(x, yTop), Offset(x, yBot), link);
        canvas.drawLine(Offset(x - 2, yTop + 4), Offset(x - 2, yBot - 4), hl);
      }
    } else {
      canvas.drawLine(Offset(xs.first, yBot), Offset(xs.last, yBot), link);
      canvas.drawLine(Offset(xs.first + 4, yBot - 2), Offset(xs.last - 4, yBot - 2), hl);
    }
    final lead = Paint()
      ..color = accent
      ..strokeWidth = 3;
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(Offset(xs[i], h * 0.06), Offset(xs[i], yTop), lead);
      _t(canvas, supply[i], Offset(xs[i], h * 0.0), accent, bold: true);
      for (final (y, name) in [(yTop, top[i]), (yBot, bot[i])]) {
        canvas.drawCircle(Offset(xs[i], y), 11, Paint()..color = const Color(0xFF9AA3AD));
        canvas.drawCircle(Offset(xs[i], y), 6, Paint()..color = const Color(0xFF59616B));
        _t(canvas, name, y == yTop ? Offset(xs[i] + 26, y - 9) : Offset(xs[i], y + 16), text, bold: true);
      }
    }
  }

  void _t(Canvas c, String s, Offset at, Color color, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: 13, color: color, fontWeight: bold ? FontWeight.w800 : FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at - Offset(tp.width / 2, 0));
  }

  @override
  bool shouldRepaint(TerminalBoxPainter old) => old.delta != delta;
}
