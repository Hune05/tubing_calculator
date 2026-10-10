// 직접 절곡 절곡선 넣기·고치기 창(10-11, 사용자: "절곡할 때 절곡 위치 지정할 수 있도록, 방향 지정도").
// 홀 넣기 창과 같은 틀: 위 미리보기(바깥 치수로 펴 그린 판 · 다른 절곡선 회색 점선 · 이 절곡선 주황과 판 끝에서 치수) ·
// 위치(판 끝에서 그 절곡 바깥 꼭짓점까지 바깥 치수) · 접는 쪽(UP/DOWN) · 각도(90° · 45° · 직접) · 맨 아래 취소/넣기.
// 고칠 때는 아래 줄 왼쪽에 "지우기". 자리는 계산(plate_calc의 직접 절곡)과 같은 바깥 치수 자리로 주고받는다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/field_view.dart';
import 'plate_calc.dart';
import 'plate_painter.dart' show PlateTone, kPlateBend;
import 'plate_ui.dart';

/// 창 결과: 넣거나 고친 절곡선, 또는 지우기.
class PlateBendLineResult {
  final PlateBendSpec? spec;
  final bool delete;
  const PlateBendLineResult(this.spec) : delete = false;
  const PlateBendLineResult.delete() : spec = null, delete = true;
}

String _f(double v) {
  var s = v.toStringAsFixed(2);
  while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
    s = s.substring(0, s.length - 1);
  }
  return s == '-0' ? '0' : s;
}

/// [outline]은 바깥 치수로 펴 그린 판(절곡선이 세로가 되게 돌린 자리, 왼쪽 아래 (0, 0)), [width]는 판 끝~끝.
Future<PlateBendLineResult?> showPlateBendLineInput(
  BuildContext context, {
  required String title,
  required List<Offset> outline,
  required double width,
  required List<double> others,
  PlateBendSpec? edit,
  double? at,
  bool axisH = false,
  String okText = '넣기',
}) => showPlateSheet<PlateBendLineResult>(
  context,
  (_) => PlateBendLineSheet(
    title: title,
    outline: outline,
    width: width,
    others: others,
    edit: edit,
    at: at,
    axisH: axisH,
    okText: okText,
  ),
);

class PlateBendLineSheet extends StatefulWidget {
  const PlateBendLineSheet({
    super.key,
    required this.title,
    required this.outline,
    required this.width,
    required this.others,
    this.edit,
    this.at,
    this.axisH = false,
    this.okText = '넣기',
  });

  final String title;
  final List<Offset> outline;
  final double width;
  final List<double> others;
  final PlateBendSpec? edit;

  /// 새 절곡선의 처음 위치(없으면 가장 긴 면 가운데).
  final double? at;
  final bool axisH;
  final String okText;

  @override
  State<PlateBendLineSheet> createState() => _PlateBendLineSheetState();
}

class _PlateBendLineSheetState extends State<PlateBendLineSheet> {
  late bool _up = widget.edit?.up ?? true;

  /// 각도: 90, 45, null = 칸.
  late double? _preset = () {
    final a = widget.edit?.angle ?? 90;
    return a == 90 || a == 45 ? a : null;
  }();

  late final _at = TextEditingController(
    text: _f(widget.edit?.at ?? widget.at ?? _middle()),
  );
  late final _ang = TextEditingController(text: _f(widget.edit?.angle ?? 90));

  /// 가장 긴 면의 가운데(반 mm 단위).
  double _middle() {
    final xs = [
      0.0,
      ...([...widget.others]..sort()),
      widget.width,
    ];
    var best = 0, len = -1.0;
    for (var k = 0; k + 1 < xs.length; k++) {
      if (xs[k + 1] - xs[k] > len) {
        len = xs[k + 1] - xs[k];
        best = k;
      }
    }
    return ((xs[best] + xs[best + 1]) / 2 * 2).roundToDouble() / 2;
  }

  @override
  void dispose() {
    _at.dispose();
    _ang.dispose();
    super.dispose();
  }

  double? _v(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  /// 지금 칸 값으로 만든 절곡선과, 안 되면 이유.
  (PlateBendSpec?, String?) _build() {
    final at = _v(_at);
    if (at == null) return (null, '위치를 넣으십시오.');
    if (at <= 0 || at >= widget.width) {
      return (null, '위치는 판 끝에서 0 ~ ${_f(widget.width)}mm 사이입니다.');
    }
    for (final o in widget.others) {
      if ((o - at).abs() < 1) {
        return (null, '${_f(o)}mm에 절곡선이 이미 있습니다.');
      }
    }
    final a = _preset ?? _v(_ang);
    if (a == null || a <= 0 || a >= 180) {
      return (null, '각도는 0°와 180° 사이입니다.');
    }
    return (PlateBendSpec(at: at, angle: a, up: _up), null);
  }

  @override
  Widget build(BuildContext context) {
    final (spec, err) = _build();
    final from = widget.axisH ? '아래 끝에서' : '왼쪽 끝에서';
    return PlateSheetFrame(
      title: widget.title,
      preview: CustomPaint(
        key: const Key('bl_preview'),
        painter: _BendPreviewPainter(
          outline: widget.outline,
          width: widget.width,
          others: widget.others,
          at: spec?.at ?? _v(_at),
          up: _up,
          colors: fc,
        ),
        child: const SizedBox.expand(),
      ),
      info: Text(
        widget.axisH
            ? '가로 절곡선 · 판을 돌려 아래 끝이 왼쪽에 오게 그렸습니다.'
            : '세로 절곡선 · 판 끝에서 그 절곡 바깥 꼭짓점까지 바깥 치수',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: fc.textSub,
        ),
      ),
      okText: widget.okText,
      okKey: const Key('bl_ok'),
      error: err,
      onOk: err != null
          ? null
          : () {
              final (now, e) = _build();
              if (e != null || now == null) return;
              Navigator.pop(context, PlateBendLineResult(now));
            },
      extra: widget.edit == null
          ? null
          : TextButton(
              key: const Key('bl_del'),
              style: TextButton.styleFrom(foregroundColor: fc.danger),
              onPressed: () =>
                  Navigator.pop(context, const PlateBendLineResult.delete()),
              child: const Text(
                '지우기',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
      children: [
        PlateSection('위치 (바깥 치수)', [
          plateRow([
            PlateNumField(
              fieldKey: 'bl_at',
              label: from,
              controller: _at,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox.shrink(),
          ]),
        ], first: true),
        PlateSection('접는 쪽', [
          PlateSegments([
            PlateOption(
              'bl_up',
              'UP (위로)',
              _up,
              () => setState(() => _up = true),
            ),
            PlateOption(
              'bl_down',
              'DOWN (아래로)',
              !_up,
              () => setState(() => _up = false),
            ),
          ]),
          Text(
            'UP은 전개도(DXF)를 위에서 본 쪽으로 접습니다.',
            style: TextStyle(fontSize: 13, color: fc.textSub, height: 1.35),
          ),
        ]),
        PlateSection('각도', [
          PlateSegments([
            PlateOption(
              'bl_a90',
              '90°',
              _preset == 90,
              () => setState(() => _preset = 90),
            ),
            PlateOption(
              'bl_a45',
              '45°',
              _preset == 45,
              () => setState(() => _preset = 45),
            ),
            PlateOption(
              'bl_aany',
              '직접',
              _preset == null,
              () => setState(() => _preset = null),
            ),
          ]),
          if (_preset == null)
            plateRow([
              PlateNumField(
                fieldKey: 'bl_ang',
                label: '절곡 각도 (90 = 직각)',
                controller: _ang,
                unit: '°',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox.shrink(),
            ]),
        ]),
      ],
    );
  }
}

/// 미리보기: 펴 그린 판, 다른 절곡선(회색 점선), 이 절곡선(주황)과 판 끝에서 치수·접는 쪽.
class _BendPreviewPainter extends CustomPainter {
  _BendPreviewPainter({
    required this.outline,
    required this.width,
    required this.others,
    required this.at,
    required this.up,
    required this.colors,
  });

  final List<Offset> outline;
  final double width;
  final List<double> others;
  final double? at;
  final bool up;
  final FieldPalette colors;

  @override
  void paint(Canvas c, Size size) {
    if (outline.length < 3 || width <= 0) return;
    final tone = PlateTone.now;
    final h = outline.map((p) => p.dy).reduce(math.max);
    const m = 18.0;
    final s = math.min(
      (size.width - 2 * m) / width,
      (size.height - 2 * m - 18) / math.max(h, 1e-6),
    );
    final ox = (size.width - width * s) / 2;
    final oy = m + (size.height - 2 * m - 18 - h * s) / 2;
    Offset sc(Offset p) => Offset(ox + p.dx * s, oy + (h - p.dy) * s);
    final path = Path()..addPolygon([for (final p in outline) sc(p)], true);
    c.drawPath(path, Paint()..color = tone.fill);
    c.drawPath(
      path,
      Paint()
        ..color = tone.edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    void vline(double x, Paint p, {bool dash = false}) {
      for (final (y0, y1) in plateBendSpans(outline, x)) {
        final a = sc(Offset(x, y1)), b = sc(Offset(x, y0));
        if (!dash) {
          c.drawLine(a, b, p);
          continue;
        }
        for (var y = a.dy; y < b.dy; y += 9) {
          c.drawLine(Offset(a.dx, y), Offset(a.dx, math.min(y + 5, b.dy)), p);
        }
      }
    }

    final gray = Paint()
      ..color = colors.textSub
      ..strokeWidth = 1.2;
    for (final o in others) {
      vline(o, gray, dash: true);
    }
    final x = at;
    if (x == null || x <= 0 || x >= width) return;
    vline(
      x,
      Paint()
        ..color = kPlateBend
        ..strokeWidth = 2.4,
    );
    // 판 끝에서 치수(판 아래)
    final y = oy + h * s + 12;
    final a = Offset(ox, y), b = Offset(sc(Offset(x, 0)).dx, y);
    final dim = Paint()
      ..color = colors.brand
      ..strokeWidth = 1.2;
    c.drawLine(a, b, dim);
    for (final q in [a, b]) {
      c.drawLine(q + const Offset(-3, 3), q + const Offset(3, -3), dim);
    }
    final tp = TextPainter(
      text: TextSpan(
        text: '${_f(x)}  ${up ? 'UP' : 'DOWN'}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: colors.brand,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset((a.dx + b.dx) / 2 - tp.width / 2, y + 2));
  }

  @override
  bool shouldRepaint(covariant _BendPreviewPainter old) => true;
}
