// 코너 처리 하나를 고르는 창(직각·코너 R·C 모따기·따내기와 크기). 레이저 절단 그림에서 코너를 눌렀을 때와
// 스케치 화면에서 꼭짓점의 "코너 처리"를 눌렀을 때 같이 쓴다(10-10).
// 10-10 입력 창 정리: 가공 입력 창 공통 틀(아래에서 올라옴) + 위에 코너 모양 그림(넣은 크기대로).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/field_view.dart';
import 'plate_calc.dart';
import 'plate_painter.dart' show PlateTone;
import 'plate_ui.dart';

String _f(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s;
}

/// 코너 처리 창을 띄운다. 취소하면 null. [flat]이면 따내기를 가로 × 세로로, 아니면 앞 변 × 다음 변으로 받는다.
Future<PlateCorner?> showPlateCornerDialog(
  BuildContext context, {
  required String title,
  required PlateCorner initial,
  bool flat = false,
}) => showPlateSheet<PlateCorner>(
  context,
  (_) => PlateCornerDialog(title: title, initial: initial, flat: flat),
);

class PlateCornerDialog extends StatefulWidget {
  const PlateCornerDialog({
    super.key,
    required this.title,
    required this.initial,
    this.flat = false,
  });
  final String title;
  final PlateCorner initial;
  final bool flat;

  @override
  State<PlateCornerDialog> createState() => _PlateCornerDialogState();
}

class _PlateCornerDialogState extends State<PlateCornerDialog> {
  late PlateCornerKind _kind = widget.initial.kind;
  late final _a = TextEditingController(
    text: widget.initial.a > 0 ? _f(widget.initial.a) : '10',
  );
  late final _b = TextEditingController(
    text: widget.initial.b > 0 ? _f(widget.initial.b) : _a.text,
  );

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  PlateCorner get _value {
    final a = _num(_a), b = _num(_b);
    return _kind == PlateCornerKind.none || a <= 0
        ? PlateCorner.square
        : PlateCorner(
            _kind,
            a,
            _kind == PlateCornerKind.notch ? (b > 0 ? b : a) : 0,
          );
  }

  @override
  Widget build(BuildContext context) {
    final err = _kind != PlateCornerKind.none && _num(_a) <= 0
        ? '크기를 넣으십시오.'
        : null;
    return PlateSheetFrame(
      title: widget.title,
      previewHeight: 150,
      preview: CustomPaint(
        key: const Key('cd_preview'),
        painter: _CornerPreviewPainter(_value, colors: fc),
        child: const SizedBox.expand(),
      ),
      info: Text(
        _kind == PlateCornerKind.none ? '직각 (처리 없음)' : _value.label,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: fc.textSub,
        ),
      ),
      okText: '적용',
      okKey: const Key('cd_ok'),
      error: err,
      onOk: err != null ? null : () => Navigator.pop(context, _value),
      children: [
        PlateSection('코너 처리', [
          PlateSegments([
            for (final (k, label) in const [
              (PlateCornerKind.none, '직각'),
              (PlateCornerKind.round, '코너 R'),
              (PlateCornerKind.chamfer, 'C 모따기'),
              (PlateCornerKind.notch, '따내기'),
            ])
              PlateOption(
                'cd_kind_${k.name}',
                label,
                _kind == k,
                () => setState(() => _kind = k),
              ),
          ]),
        ], first: true),
        if (_kind != PlateCornerKind.none)
          PlateSection('크기', [
            plateRow([
              PlateNumField(
                fieldKey: 'cd_a',
                label: switch (_kind) {
                  PlateCornerKind.round => 'R',
                  PlateCornerKind.chamfer => 'C',
                  _ => widget.flat ? '따내기 가로' : '따내기: 앞 변 쪽',
                },
                controller: _a,
                onChanged: (_) => setState(() {}),
              ),
              if (_kind == PlateCornerKind.notch)
                PlateNumField(
                  fieldKey: 'cd_b',
                  label: widget.flat ? '따내기 세로' : '따내기: 다음 변 쪽',
                  controller: _b,
                  onChanged: (_) => setState(() {}),
                )
              else
                const SizedBox.shrink(),
            ]),
            if (_kind == PlateCornerKind.notch && !widget.flat)
              Text(
                '앞 변은 앞 번호 꼭짓점에서 오는 변, 다음 변은 다음 번호 꼭짓점으로 가는 변입니다.',
                style: TextStyle(color: fc.textSub, fontSize: 13, height: 1.35),
              ),
          ]),
      ],
    );
  }
}

/// 코너 그림: 왼쪽 아래 코너 하나를 크게(가로 변 오른쪽으로, 세로 변 위로).
class _CornerPreviewPainter extends CustomPainter {
  _CornerPreviewPainter(this.corner, {required this.colors});
  final PlateCorner corner;
  final FieldPalette colors;

  @override
  void paint(Canvas canvas, Size size) {
    // 판 100 × 100 중 왼쪽 아래 코너를 그린다(크기는 넣은 값 비율, 너무 크면 줄여 보임).
    const side = 100.0;
    final a = corner.isNone ? 0.0 : math.min(corner.a, side * 0.6);
    final b = corner.kind == PlateCornerKind.notch
        ? math.min(corner.b > 0 ? corner.b : corner.a, side * 0.6)
        : a;
    final s = math.min(size.width, size.height) * 0.8 / side;
    final o = Offset(
      (size.width - side * s) / 2,
      (size.height + side * s) / 2,
    ); // 왼쪽 아래 화면 자리
    Offset p(double x, double y) => o + Offset(x * s, -y * s);
    final path = Path();
    switch (corner.kind) {
      case PlateCornerKind.round when !corner.isNone:
        path.moveTo(p(a, 0).dx, p(a, 0).dy);
        path.lineTo(p(side, 0).dx, p(side, 0).dy);
        path.lineTo(p(side, side).dx, p(side, side).dy);
        path.lineTo(p(0, side).dx, p(0, side).dy);
        path.lineTo(p(0, a).dx, p(0, a).dy);
        path.arcToPoint(
          p(a, 0),
          radius: Radius.circular(a * s),
          clockwise: false,
        );
      case PlateCornerKind.chamfer when !corner.isNone:
        path.addPolygon([
          p(a, 0),
          p(side, 0),
          p(side, side),
          p(0, side),
          p(0, a),
        ], true);
      case PlateCornerKind.notch when !corner.isNone:
        path.addPolygon([
          p(a, 0),
          p(side, 0),
          p(side, side),
          p(0, side),
          p(0, b),
          p(a, b),
        ], true);
      default:
        path.addPolygon([p(0, 0), p(side, 0), p(side, side), p(0, side)], true);
    }
    path.close();
    final tone = PlateTone.now;
    canvas.drawPath(path, Paint()..color = tone.fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = tone.edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    // 원래 직각 자리(점선 대신 옅은 선)
    if (!corner.isNone) {
      final ghost = Paint()
        ..color = colors.textFaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawLine(p(0, 0), p(a, 0), ghost);
      canvas.drawLine(
        p(0, 0),
        p(0, corner.kind == PlateCornerKind.notch ? b : a),
        ghost,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CornerPreviewPainter old) =>
      old.corner.kind != corner.kind ||
      old.corner.a != corner.a ||
      old.corner.b != corner.b;
}
