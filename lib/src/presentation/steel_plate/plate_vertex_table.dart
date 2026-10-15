// 꼭짓점 표(10-11, 점검 28): 좌표 입력을 "0,0 ↵ 200,0" 글로 치던 것을 줄마다 가로·세로·코너 칸으로.
// 저장은 그대로 꼭짓점 글("x,y[,r10]" 줄들)이고, 표는 그 글을 고친다. 여러 줄을 한꺼번에 붙여 넣을 때는 "글로 넣기".
import 'package:flutter/material.dart';

import '../../core/theme/app_icon_set.dart';
import '../../core/theme/field_view.dart';
import '../common/number_text.dart';
import 'plate_calc.dart';
import 'plate_corner_dialog.dart';
import 'plate_ui.dart';

/// 소수 둘째 자리까지(넣은 15.25가 15.3으로 바뀌지 않게).
String _f(double v) {
  var s = v.toStringAsFixed(2);
  while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
    s = s.substring(0, s.length - 1);
  }
  return s == '-0' ? '0' : s;
}

/// 칸 글 → 꼭짓점 줄의 한 칸. 숫자로 읽히면 숫자로("1,200" → 1200 — 그대로 이으면 쉼표가 칸을 갈라
/// 꼭짓점이 틀어졌다, 점검 36), 못 읽으면 쉼표·띄어쓰기를 뺀 글(그 줄은 못 읽는 줄로 빠진다).
String _cell(String s) {
  final v = parseNumberText(s);
  return v != null ? _f(v) : s.replaceAll(RegExp(r'[,;/\s]'), '');
}

class _VRow {
  _VRow(String x, String y, this.corner)
    : x = TextEditingController(text: x),
      y = TextEditingController(text: y);
  final TextEditingController x, y;
  PlateCorner corner;

  Offset? get point {
    final a = parseNumberText(x.text), b = parseNumberText(y.text);
    return a == null || b == null ? null : Offset(a, b);
  }

  String get line {
    final t = corner.token;
    return '${_cell(x.text)},${_cell(y.text)}${t.isEmpty ? '' : ',$t'}';
  }

  void dispose() {
    x.dispose();
    y.dispose();
  }
}

/// 꼭짓점 표. [controller]의 글이 밖에서 바뀌면(스케치·DXF·크기 바꾸기·그림에서 코너) 표를 다시 채운다.
class PlateVertexTable extends StatefulWidget {
  const PlateVertexTable({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  State<PlateVertexTable> createState() => _PlateVertexTableState();
}

class _PlateVertexTableState extends State<PlateVertexTable> {
  final List<_VRow> _rows = [];
  String? _synced; // 표와 맞춰 둔 글
  bool _textMode = false;

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _load() {
    final old = List.of(_rows);
    _rows
      ..clear()
      ..addAll([
        for (final (p, c) in parsePlateVertices(widget.controller.text))
          _VRow(_f(p.dx), _f(p.dy), c),
      ]);
    _synced = widget.controller.text;
    // 앞 칸들은 이번 그림에서 새 칸으로 바뀐 뒤에 버린다(바로 버리면 지난 칸이 버린 것을 만진다).
    if (old.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final r in old) {
          r.dispose();
        }
      });
    }
  }

  void _emit() {
    final text = [for (final r in _rows) r.line].join('\n');
    _synced = text;
    widget.controller.text = text;
    widget.onChanged();
  }

  void _add() {
    final pts = [for (final r in _rows) r.point].whereType<Offset>().toList();
    // 마지막 점과 첫 점 사이 가운데(모양은 그대로, 옮겨서 고친다)
    final m = pts.length >= 2 ? (pts.last + pts.first) / 2 : null;
    setState(() {
      _rows.add(
        _VRow(
          m == null ? '' : _f(m.dx),
          m == null ? '' : _f(m.dy),
          PlateCorner.square,
        ),
      );
    });
    _emit();
  }

  void _remove(int i) {
    final r = _rows.removeAt(i);
    setState(() {});
    _emit();
    WidgetsBinding.instance.addPostFrameCallback((_) => r.dispose());
  }

  Future<void> _corner(int i) async {
    final c = await showPlateCornerDialog(
      context,
      title: '꼭짓점 ${i + 1} 코너',
      initial: _rows[i].corner,
    );
    if (c == null || !mounted || i >= _rows.length) return;
    setState(() => _rows[i].corner = c);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.text != _synced) _load();
    final n = _rows.where((r) => r.point != null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _textMode
                    ? '꼭짓점 (가로,세로 한 줄에 하나 · 코너는 줄 끝에 ,r10 ,c5 ,n20x15)'
                    : '꼭짓점 $n개 (판 왼쪽 아래에서 mm, 차례대로)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: fc.textSub,
                ),
              ),
            ),
            TextButton(
              key: const Key('pl_pts_mode'),
              style: TextButton.styleFrom(
                foregroundColor: fc.brand,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => setState(() {
                _textMode = !_textMode;
                _synced = null; // 표로 돌아올 때 글을 다시 읽는다
              }),
              // 글 모양은 단추(styleFrom textStyle)가 아니라 글에: 단추에 주면 앱 글꼴이 빠진다
              child: Text(
                _textMode ? '표로 보기' : '글로 넣기',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (_textMode) _text() else _table(),
      ],
    );
  }

  Widget _text() => TextField(
    key: const Key('pl_points'),
    controller: widget.controller,
    maxLines: 7,
    minLines: 4,
    keyboardType: TextInputType.multiline,
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: fc.text,
      height: 1.35,
    ),
    decoration: InputDecoration(
      // 10-15 통일: 테두리·바탕은 테마 기본
      contentPadding: const EdgeInsets.all(12),
    ),
    onChanged: (_) => widget.onChanged(),
  );

  Widget _table() {
    const numW = 26.0, cornerW = 78.0, delW = 36.0, gap = 6.0;
    final head = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: fc.textSub,
    );
    Widget row(int i) {
      final r = _rows[i];
      final bad = r.point == null;
      return Padding(
        key: Key('pl_vrow_${i + 1}'),
        padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
        child: Row(
          children: [
            SizedBox(
              width: numW,
              child: Text(
                '${i + 1}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: bad ? fc.danger : fc.textSub,
                ),
              ),
            ),
            const SizedBox(width: gap),
            Expanded(
              child: PlateNumField(
                fieldKey: 'pl_vx_${i + 1}',
                label: null,
                unit: null,
                controller: r.x,
                onChanged: (_) {
                  setState(() {});
                  _emit();
                },
              ),
            ),
            const SizedBox(width: gap),
            Expanded(
              child: PlateNumField(
                fieldKey: 'pl_vy_${i + 1}',
                label: null,
                unit: null,
                controller: r.y,
                onChanged: (_) {
                  setState(() {});
                  _emit();
                },
              ),
            ),
            const SizedBox(width: gap),
            SizedBox(
              width: cornerW,
              height: 46,
              child: Material(
                color: r.corner.isNone ? fc.fill : fc.brandSoft,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  key: Key('pl_vc_${i + 1}'),
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _corner(i),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          r.corner.isNone
                              ? '직각'
                              : r.corner.label.replaceFirst('따내기 ', '따냄 '),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: r.corner.isNone ? fc.textSub : fc.brand,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: delW,
              child: IconButton(
                key: Key('pl_vdel_${i + 1}'),
                tooltip: '꼭짓점 ${i + 1} 지우기',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                color: fc.textSub,
                disabledColor: fc.textFaint,
                onPressed: _rows.length <= 3 ? null : () => _remove(i),
                icon: const Icon(AppIcons.close, size: 18),
              ),
            ),
          ],
        ),
      );
    }

    return DecoratedBox(
      key: const Key('pl_vtable'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fc.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: fc.fill,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 4, 7),
              child: Row(
                children: [
                  SizedBox(
                    width: numW,
                    // 큰 글씨에서 두 줄로 꺾이지 않게(점검 60)
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('번호', maxLines: 1, style: head),
                    ),
                  ),
                  const SizedBox(width: gap),
                  Expanded(
                    // 칸 안 숫자 끝(안쪽 여백 12)에 맞춘다
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        '가로',
                        textAlign: TextAlign.right,
                        style: head,
                      ),
                    ),
                  ),
                  const SizedBox(width: gap),
                  Expanded(
                    // 칸 안 숫자 끝(안쪽 여백 12)에 맞춘다
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        '세로',
                        textAlign: TextAlign.right,
                        style: head,
                      ),
                    ),
                  ),
                  const SizedBox(width: gap),
                  SizedBox(
                    width: cornerW,
                    child: Text('코너', textAlign: TextAlign.center, style: head),
                  ),
                  const SizedBox(width: delW),
                ],
              ),
            ),
          ),
          for (var i = 0; i < _rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: fc.line),
            row(i),
          ],
          Divider(height: 1, color: fc.line),
          TextButton.icon(
            key: const Key('pl_vadd'),
            style: TextButton.styleFrom(
              foregroundColor: fc.brand,
              minimumSize: const Size(0, 44),
            ),
            onPressed: _add,
            icon: const Icon(AppIcons.add, size: 18),
            label: const Text(
              '꼭짓점 추가',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
