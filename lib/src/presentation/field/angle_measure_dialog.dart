// 각도 실측 창(10-17): 아이소 꺾이는 점·현장 탭 단계에서 같이 쓴다.
// 굽힌 뒤(손을 놓고) 각도기로 잰 값. 마킹은 안 바뀐다. 결과는 (지우기, 값).
import 'package:flutter/material.dart';

import 'field_progress_bus.dart';

/// 각도 실측 창: 설계 각도와 잰 값, 저장·지우기(10-17).
class AngleMeasureDialog extends StatefulWidget {
  final int number;
  final double design;
  final double? current;
  const AngleMeasureDialog({
    super.key,
    required this.number,
    required this.design,
    this.current,
  });

  @override
  State<AngleMeasureDialog> createState() => _AngleMeasureDialogState();
}

class _AngleMeasureDialogState extends State<AngleMeasureDialog> {
  late final TextEditingController _c = TextEditingController(
    text: widget.current == null ? '' : _fmt(widget.current!),
  );
  String? _err;

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    final v = double.tryParse(_c.text.trim().replaceAll(',', '.'));
    if (v == null || v <= 0 || v > 180) {
      setState(() => _err = '0보다 크고 180 이하로 넣으십시오');
      return;
    }
    Navigator.pop(context, (clear: false, value: v));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('각도 실측'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.number}번 벤드 각도',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            '굽힌 뒤(손을 놓고) 각도기로 잰 값을 넣으십시오. 설계 ${_fmt(widget.design)}° 기준 ±${_fmt(kAngleTolDefault)}° 안이면 합격입니다.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('angle_measure_field'),
            controller: _c,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '잰 각도',
              suffixText: '°',
              helperText: '설계 ${_fmt(widget.design)}°',
              errorText: _err,
            ),
            onChanged: (_) {
              if (_err != null) setState(() => _err = null);
            },
            onSubmitted: (_) => _save(),
          ),
          // 10-17 폰 확인: 단추 셋이 한 줄에 안 들어가 세로로 쌓였다 → 지우기는 칸 아래로.
          if (widget.current != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('angle_measure_clear'),
                onPressed: () =>
                    Navigator.pop(context, (clear: true, value: null)),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('이 각도 실측 지우기'),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('angle_measure_save'),
          onPressed: _save,
          child: const Text('저장'),
        ),
      ],
    );
  }
}
