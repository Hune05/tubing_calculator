// 구멍 여러 개를 줄·네 귀·장공 틀로 한꺼번에 넣는 창(10-10). 구멍 배치 편집 화면의 "줄로 넣기·네 귀 구멍·장공 넣기"가 연다.
// 고른 틀은 [PlateHoleGroup]으로 돌려주고, 부른 쪽이 하나하나 구멍으로 풀어 넣는다.
import 'package:flutter/material.dart';

import '../electrical/busbar_punch_dies.dart' show punchDieLabel;
import 'plate_calc.dart';

/// 구멍 묶음 창을 아래에서 띄운다. 취소하면 null.
Future<PlateHoleGroup?> showPlateHoleSheet(
  BuildContext context, {
  PlateHoleGroup? preset,
  required PlateShape shape,
  required List<double> dies,
  required Color background,
  required Color text,
  required Color sub,
  required Widget Function(
    String key,
    String label,
    bool sel,
    VoidCallback onTap,
  )
  chip,
}) => showModalBottomSheet<PlateHoleGroup>(
  context: context,
  isScrollControlled: true,
  backgroundColor: background,
  builder: (_) => PlateHoleSheet(
    initial: preset,
    bent: plateShapeBends(shape),
    flat: shape == PlateShape.flat,
    faces: plateFaceNames(shape),
    dies: dies,
    text: text,
    sub: sub,
    chip: chip,
  ),
);

/// 구멍 묶음 넣기·고치기 창.
class PlateHoleSheet extends StatefulWidget {
  const PlateHoleSheet({
    super.key,
    required this.initial,
    required this.bent,
    required this.flat,
    required this.faces,
    required this.dies,
    required this.text,
    required this.sub,
    required this.chip,
  });
  final PlateHoleGroup? initial;
  final bool bent, flat;
  final List<String> faces;
  final List<double> dies;
  final Color text, sub;
  final Widget Function(String key, String label, bool sel, VoidCallback onTap)
  chip;

  @override
  State<PlateHoleSheet> createState() => _PlateHoleSheetState();
}

class _PlateHoleSheetState extends State<PlateHoleSheet> {
  late final PlateHoleGroup? g = widget.initial;
  late bool _slot = (g?.slot ?? 0) > 0;
  late bool _slotX = g?.slotAlongX ?? true;
  late bool _corners = (g?.corners ?? false) && widget.flat;
  late bool _rowX = g?.rowAlongX ?? true;
  late int _face = (g?.face ?? 0).clamp(0, widget.faces.length - 1);
  late final _dia = TextEditingController(text: fmtSheet(g?.dia ?? 13.5));
  late final _slotLen = TextEditingController(
    text: fmtSheet((g?.slot ?? 0) > 0 ? g!.slot : 30),
  );
  late final _x = TextEditingController(text: fmtSheet(g?.x ?? 25));
  late final _y = TextEditingController(text: fmtSheet(g?.y ?? 25));
  late final _n = TextEditingController(text: '${g?.count ?? 1}');
  late final _pitch = TextEditingController(text: fmtSheet(g?.pitch ?? 50));

  static String fmtSheet(double v) {
    var s = v.toStringAsFixed(2);
    while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  @override
  void dispose() {
    for (final c in [_dia, _slotLen, _x, _y, _n, _pitch]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _v(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Widget _chip(String key, String label, bool sel, VoidCallback onTap) =>
      widget.chip(key, label, sel, () => setState(onTap));

  Widget _field(String key, String label, TextEditingController c) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      key: Key(key),
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, isDense: true),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final xLabel = _corners
        ? '가장자리에서 가로 거리 (mm)'
        : widget.bent
        ? '면 시작에서 (mm)'
        : '왼쪽 끝에서 첫 홀 (mm)';
    final yLabel = _corners
        ? '가장자리에서 세로 거리 (mm)'
        : widget.bent
        ? '아래 가장자리에서 (mm)'
        : '아래 끝에서 첫 홀 (mm)';
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initial == null ? '홀 넣기' : '홀 고치기',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: widget.text,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  _chip('hs_round', '원형 홀', !_slot, () => _slot = false),
                  _chip('hs_slot', '장공', _slot, () => _slot = true),
                ],
              ),
              const SizedBox(height: 8),
              _field('hs_dia', _slot ? '장공 폭 (mm)' : '홀 지름 (mm)', _dia),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final d in widget.dies)
                    _chip(
                      'hs_die_${(d * 100).round()}',
                      punchDieLabel(d),
                      double.tryParse(_dia.text.trim()) == d,
                      () => _dia.text = fmtSheet(d),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_slot) ...[
                _field('hs_slotlen', '장공 전체 길이 (mm)', _slotLen),
                Wrap(
                  spacing: 8,
                  children: [
                    _chip('hs_slotx', '가로로 긴 장공', _slotX, () => _slotX = true),
                    _chip(
                      'hs_sloty',
                      '세로로 긴 장공',
                      !_slotX,
                      () => _slotX = false,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (widget.bent) ...[
                Text('홀이 있는 면', style: TextStyle(color: widget.sub)),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var k = 0; k < widget.faces.length; k++)
                      _chip(
                        'hs_face_$k',
                        widget.faces[k],
                        _face == k,
                        () => _face = k,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (widget.flat)
                Wrap(
                  spacing: 8,
                  children: [
                    _chip('hs_row', '줄로 놓기', !_corners, () => _corners = false),
                    _chip(
                      'hs_corners',
                      '네 코너',
                      _corners,
                      () => _corners = true,
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              _field('hs_x', xLabel, _x),
              _field('hs_y', yLabel, _y),
              if (!_corners) ...[
                _field('hs_n', '개수', _n),
                _field('hs_pitch', '피치 (다음 홀까지, mm)', _pitch),
                Wrap(
                  spacing: 8,
                  children: [
                    _chip('hs_rowx', '가로로 늘어놓기', _rowX, () => _rowX = true),
                    _chip('hs_rowy', '세로로 늘어놓기', !_rowX, () => _rowX = false),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('hs_ok'),
                  onPressed: () {
                    final dia = _v(_dia);
                    if (dia == null || dia <= 0) return;
                    Navigator.pop(
                      context,
                      PlateHoleGroup(
                        face: widget.bent ? _face : 0,
                        dia: dia,
                        slot: _slot ? (_v(_slotLen) ?? 0) : 0,
                        slotAlongX: _slotX,
                        corners: _corners,
                        count: (_v(_n) ?? 1).round().clamp(1, 99),
                        x: _v(_x) ?? 0,
                        y: _v(_y) ?? 0,
                        pitch: _v(_pitch) ?? 0,
                        rowAlongX: _rowX,
                      ),
                    );
                  },
                  child: Text(widget.initial == null ? '넣기' : '고치기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
