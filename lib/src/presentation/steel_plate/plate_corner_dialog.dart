// 귀 처리 하나를 고르는 창(직각·R·C·따내기와 크기). 레이저 절단 그림에서 귀를 눌렀을 때와
// 손그림 화면에서 꼭짓점의 "귀 처리"를 눌렀을 때 같이 쓴다(10-10).
import 'package:flutter/material.dart';

import '../../core/theme/field_view.dart';
import '../calculator/widgets/app_dialog.dart';
import 'plate_calc.dart';

String _f(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s;
}

/// 귀 처리 창을 띄운다. 취소하면 null. [flat]이면 따내기를 가로 × 세로로, 아니면 앞 변 × 다음 변으로 받는다.
Future<PlateCorner?> showPlateCornerDialog(
  BuildContext context, {
  required String title,
  required PlateCorner initial,
  bool flat = false,
}) => showDialog<PlateCorner>(
  context: context,
  builder: (_) => PlateCornerDialog(title: title, initial: initial, flat: flat),
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

  @override
  Widget build(BuildContext context) => AppDialog(
    title: widget.title,
    okText: '적용',
    okKey: const Key('cd_ok'),
    onCancel: () => Navigator.pop(context),
    onOk: () {
      final a = _num(_a), b = _num(_b);
      Navigator.pop(
        context,
        _kind == PlateCornerKind.none || a <= 0
            ? PlateCorner.square
            : PlateCorner(
                _kind,
                a,
                _kind == PlateCornerKind.notch ? (b > 0 ? b : a) : 0,
              ),
      );
    },
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (k, label) in const [
                (PlateCornerKind.none, '직각'),
                (PlateCornerKind.round, '코너 R'),
                (PlateCornerKind.chamfer, 'C 모따기'),
                (PlateCornerKind.notch, '따내기'),
              ])
                ChoiceChip(
                  key: Key('cd_kind_${k.name}'),
                  label: Text(label),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                ),
            ],
          ),
          if (_kind != PlateCornerKind.none) ...[
            const SizedBox(height: 12),
            TextField(
              key: const Key('cd_a'),
              controller: _a,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: appFieldTextStyle,
              decoration: appFieldDecoration(switch (_kind) {
                PlateCornerKind.round => 'R (mm)',
                PlateCornerKind.chamfer => 'C (mm)',
                _ => widget.flat ? '따내기 가로 (mm)' : '따내기: 앞 변 쪽 (mm)',
              }),
            ),
          ],
          if (_kind == PlateCornerKind.notch) ...[
            const SizedBox(height: 10),
            TextField(
              key: const Key('cd_b'),
              controller: _b,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: appFieldTextStyle,
              decoration: appFieldDecoration(
                widget.flat ? '따내기 세로 (mm)' : '따내기: 다음 변 쪽 (mm)',
              ),
            ),
            if (!widget.flat) ...[
              const SizedBox(height: 6),
              Text(
                '앞 변은 앞 번호 꼭짓점에서 오는 변, 다음 변은 다음 번호 꼭짓점으로 가는 변입니다.',
                style: TextStyle(color: fc.textSub, fontSize: 13, height: 1.35),
              ),
            ],
          ],
        ],
      ),
    ),
  );
}
