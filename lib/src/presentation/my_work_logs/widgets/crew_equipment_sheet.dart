// 작업 일지의 업체·공종별 인력, 투입 장비를 적는 창(10-14). 줄마다 글 칸을 이 창이 스스로 만들고
// 없앤다(창이 닫히는 동안에도 안전하게). "적용"을 누르면 줄 목록을 돌려주고, 닫으면 null.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tubing_calculator/src/core/theme/app_tokens.dart';

/// 줄 하나의 칸 정의.
class _Col {
  final String key;
  final String label;
  final bool number;
  final int flex;
  const _Col(this.key, this.label, {this.number = false, this.flex = 2});
}

const _crewCols = [
  _Col('company', '업체', flex: 3),
  _Col('trade', '공종', flex: 3),
  _Col('count', '인원', number: true),
  _Col('hours', '시간', number: true),
];

const _equipCols = [
  _Col('name', '장비 (예: 크레인 25t)', flex: 6),
  _Col('count', '대수', number: true),
  _Col('hours', '시간', number: true),
];

/// 업체·공종별 인력 창. [suggest]는 업체 이름 칩(지난 일지·주소록 협력사).
Future<List<Map<String, dynamic>>?> showCrewsSheet(
  BuildContext context, {
  required List<Map<String, dynamic>> initial,
  List<String> suggest = const [],
}) => _show(
  context,
  title: '업체·공종별 인력',
  note: '적으면 투입 인원은 이 합계로 바뀝니다. 시간은 비워 둬도 됩니다.',
  cols: _crewCols,
  initial: initial,
  addLabel: '업체 줄 넣기',
  suggestKey: 'company',
  suggest: suggest,
  rowKey: 'crew',
);

/// 투입 장비 창.
Future<List<Map<String, dynamic>>?> showEquipmentSheet(
  BuildContext context, {
  required List<Map<String, dynamic>> initial,
  List<String> suggest = const [],
}) => _show(
  context,
  title: '투입 장비',
  note: '크레인·고소작업차·지게차처럼 그날 들어온 장비를 적습니다.',
  cols: _equipCols,
  initial: initial,
  addLabel: '장비 줄 넣기',
  suggestKey: 'name',
  suggest: suggest,
  rowKey: 'equip',
);

Future<List<Map<String, dynamic>>?> _show(
  BuildContext context, {
  required String title,
  required String note,
  required List<_Col> cols,
  required List<Map<String, dynamic>> initial,
  required String addLabel,
  required String suggestKey,
  required List<String> suggest,
  required String rowKey,
}) => showModalBottomSheet<List<Map<String, dynamic>>>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
  ),
  builder: (_) => _RowsSheet(
    title: title,
    note: note,
    cols: cols,
    initial: initial,
    addLabel: addLabel,
    suggestKey: suggestKey,
    suggest: suggest,
    rowKey: rowKey,
  ),
);

class _RowsSheet extends StatefulWidget {
  final String title;
  final String note;
  final List<_Col> cols;
  final List<Map<String, dynamic>> initial;
  final String addLabel;
  final String suggestKey;
  final List<String> suggest;
  final String rowKey;
  const _RowsSheet({
    required this.title,
    required this.note,
    required this.cols,
    required this.initial,
    required this.addLabel,
    required this.suggestKey,
    required this.suggest,
    required this.rowKey,
  });

  @override
  State<_RowsSheet> createState() => _RowsSheetState();
}

class _RowsSheetState extends State<_RowsSheet> {
  final List<Map<String, TextEditingController>> _rows = [];

  String _text(Object? v, bool number) {
    if (v == null) return '';
    if (number) {
      final n = v is num ? v : num.tryParse('$v');
      if (n == null || n == 0) return '';
      return n == n.roundToDouble() ? n.toInt().toString() : '$n';
    }
    return '$v';
  }

  void _addRow([Map<String, dynamic>? from]) {
    _rows.add({
      for (final c in widget.cols)
        c.key: TextEditingController(text: _text(from?[c.key], c.number)),
    });
  }

  @override
  void initState() {
    super.initState();
    for (final r in widget.initial) {
      _addRow(r);
    }
    if (_rows.isEmpty) _addRow();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      for (final c in r.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  List<Map<String, dynamic>> _result() => [
    for (final r in _rows)
      {
        for (final c in widget.cols)
          c.key: c.number
              ? (num.tryParse(r[c.key]!.text.replaceAll(',', '').trim()) ?? 0)
              : r[c.key]!.text.trim(),
      },
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.note,
              style: const TextStyle(fontSize: 13, color: AppColors.textSub),
            ),
            if (widget.suggest.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in widget.suggest.take(8))
                    ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 13)),
                      onPressed: () => setState(() {
                        // 빈 줄이 있으면 거기에, 없으면 새 줄.
                        final empty = _rows.where(
                          (r) => r[widget.suggestKey]!.text.trim().isEmpty,
                        );
                        if (empty.isEmpty) _addRow();
                        (empty.isEmpty
                                    ? _rows.last
                                    : empty.first)[widget.suggestKey]!
                                .text =
                            s;
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var i = 0; i < _rows.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            for (final c in widget.cols) ...[
                              Expanded(
                                flex: c.flex,
                                child: TextField(
                                  key: Key('${widget.rowKey}_${c.key}_$i'),
                                  controller: _rows[i][c.key],
                                  keyboardType: c.number
                                      ? const TextInputType.numberWithOptions(
                                          decimal: true,
                                        )
                                      : TextInputType.text,
                                  inputFormatters: c.number
                                      ? [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'[0-9.,]'),
                                          ),
                                        ]
                                      : null,
                                  style: const TextStyle(fontSize: 15),
                                  decoration: InputDecoration(
                                    labelText: c.label,
                                    isDense: true,
                                    filled: true,
                                    fillColor: AppColors.background,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            IconButton(
                              key: Key('${widget.rowKey}_remove_$i'),
                              tooltip: '줄 빼기',
                              onPressed: () => setState(() {
                                final r = _rows.removeAt(i);
                                // 지운 줄의 글 칸은 다음 그림이 끝난 뒤 없앤다.
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  for (final c in r.values) {
                                    c.dispose();
                                  }
                                });
                              }),
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: AppColors.textSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: Key('${widget.rowKey}_add'),
                onPressed: () => setState(_addRow),
                icon: const Icon(Icons.add),
                label: Text(widget.addLabel),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: Key('${widget.rowKey}_apply'),
                    onPressed: () => Navigator.pop(context, _result()),
                    child: const Text('적용'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
