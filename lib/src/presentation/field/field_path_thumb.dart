/// 현장 탭의 관 모양 작은 그림(10-14). 관 전체 윤곽을 아이소로 그리고 지금 할 벤드를 빨갛게 찍어,
/// UP·BACK이 앞 벤드 기준으로 어느 쪽인지 줄자 옆에서 바로 보이게 한다. 보기만 하는 그림이다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'package:tubing_calculator/src/core/engine/bend_path.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking.dart';

class FieldPathThumb extends StatelessWidget {
  final FieldMarkingData data;

  /// 빨갛게 찍을 벤드 번호(1부터). null이면 없음.
  final int? highlightBend;

  /// 자르는 자리를 찍을지(자르기 단계).
  final bool highlightCut;
  final Color pipe;
  final Color highlight;
  final Color muted;
  final Color line;

  const FieldPathThumb({
    super.key,
    required this.data,
    this.highlightBend,
    this.highlightCut = false,
    required this.pipe,
    required this.highlight,
    required this.muted,
    required this.line,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const Key('field_path_thumb'),
    painter: _ThumbPainter(
      data: data,
      highlightBend: highlightBend,
      highlightCut: highlightCut,
      pipe: pipe,
      highlight: highlight,
      muted: muted,
      line: line,
    ),
  );
}

class _ThumbPainter extends CustomPainter {
  final FieldMarkingData data;
  final int? highlightBend;
  final bool highlightCut;
  final Color pipe;
  final Color highlight;
  final Color muted;
  final Color line;

  _ThumbPainter({
    required this.data,
    required this.highlightBend,
    required this.highlightCut,
    required this.pipe,
    required this.highlight,
    required this.muted,
    required this.line,
  });

  static final double _c30 = math.cos(math.pi / 6);
  static const double _s30 = 0.5;

  /// 아이소 투영: 위(y)는 위로, 오른쪽(x)은 오른쪽 아래로, 앞(z)은 왼쪽 아래로.
  Offset _project(vm.Vector3 v) =>
      Offset((v.x - v.z) * _c30, -v.y + (v.x + v.z) * _s30);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.segments.isEmpty || size.width < 40 || size.height < 40) return;
    final BendPath path;
    try {
      path = buildBendPath(
        [
          for (final s in data.segments)
            PathSegment(length: s.length, angle: s.angle, rotation: s.rotation),
        ],
        radius: data.radius,
        startDirection: directionForName(data.startDir),
        tail: data.tail,
      );
    } catch (_) {
      return;
    }

    // 투영한 점들의 범위를 재서 상자 안에 맞춘다.
    final pts = <Offset>[
      _project(vm.Vector3.zero()),
      _project(path.endPoint),
      for (final l in path.straights) ...[_project(l.a), _project(l.b)],
      for (final b in path.bends) ...[
        _project(b.tangentIn),
        _project(b.corner),
        _project(b.tangentOut),
      ],
    ];
    double minX = pts.first.dx, maxX = pts.first.dx;
    double minY = pts.first.dy, maxY = pts.first.dy;
    for (final p in pts) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    const double pad = 18;
    final double w = math.max(maxX - minX, 1);
    final double h = math.max(maxY - minY, 1);
    final double k = math.min(
      (size.width - pad * 2) / w,
      (size.height - pad * 2) / h,
    );
    final Offset shift = Offset(
      (size.width - w * k) / 2 - minX * k,
      (size.height - h * k) / 2 - minY * k,
    );
    Offset at(vm.Vector3 v) => _project(v) * k + shift;

    final pipePaint = Paint()
      ..color = pipe
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final l in path.straights) {
      canvas.drawLine(at(l.a), at(l.b), pipePaint);
    }
    Path arc(PathBend b) {
      final p = Path()..moveTo(at(b.tangentIn).dx, at(b.tangentIn).dy);
      final c = at(b.corner), o = at(b.tangentOut);
      p.quadraticBezierTo(c.dx, c.dy, o.dx, o.dy);
      return p;
    }

    for (final b in path.bends) {
      canvas.drawPath(arc(b), pipePaint);
    }

    // 지금 할 벤드: 빨간 호 + 모서리 점.
    final hi = highlightBend;
    if (hi != null && hi >= 1 && hi <= path.bends.length) {
      final b = path.bends[hi - 1];
      canvas.drawPath(
        arc(b),
        Paint()
          ..color = highlight
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
      canvas.drawCircle(at(b.corner), 5, Paint()..color = highlight);
    }
    // 자르는 자리: 끝점에 빨간 점.
    if (highlightCut) {
      canvas.drawCircle(at(path.endPoint), 5, Paint()..color = highlight);
    }

    // 관 끝 0: 빈 동그라미와 "0".
    final start = at(vm.Vector3.zero());
    canvas.drawCircle(
      start,
      4.5,
      Paint()
        ..color = muted
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    _text(canvas, '0', start + const Offset(6, -16), 12, muted);

    // 방향 범례(왼쪽 아래): UP·RIGHT·FRONT 화살.
    final base = Offset(pad + 4, size.height - pad - 2);
    final legend = Paint()
      ..color = muted
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    // 글자는 화살 끝 바깥쪽에(UP은 위, RIGHT는 오른쪽, FRONT는 왼쪽 아래) 서로 안 겹치게.
    for (final (v, label, off) in [
      (vm.Vector3(0, 1, 0), 'UP', const Offset(-9, -16)),
      (vm.Vector3(1, 0, 0), 'RIGHT', const Offset(3, -7)),
      (vm.Vector3(0, 0, 1), 'FRONT', const Offset(-40, -2)),
    ]) {
      final d = _project(v) * 14;
      canvas.drawLine(base, base + d, legend);
      _text(canvas, label, base + d + off, 11, muted);
    }
  }

  void _text(Canvas canvas, String s, Offset o, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, o);
  }

  @override
  bool shouldRepaint(covariant _ThumbPainter old) =>
      old.data != data ||
      old.highlightBend != highlightBend ||
      old.highlightCut != highlightCut ||
      old.pipe != pipe ||
      old.highlight != highlight ||
      old.muted != muted;
}
