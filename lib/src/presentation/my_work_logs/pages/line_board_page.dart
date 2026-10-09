// 라인 진행 보드(10-10): 프로젝트의 튜브 라인마다 단계(컷팅·벤딩 → 설치 → 서포트 → 압력시험 →
// 루프 체크)를 눌러 체크한다. 엑셀에서 라인 번호 열을 복사해 한꺼번에 넣고, 엑셀(CSV)로 내보낸다.
// 압력시험·교정 기록을 이 프로젝트에 붙여 합격으로 저장하면 그 단계가 저절로 체크된다(line_auto_check.dart).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/common_widgets/app_components.dart'
    show showAppSnack, AppSnackKind;
import '../../../core/common_widgets/swipe_to_delete.dart';
import '../../../core/theme/app_tokens.dart';
import '../models/line_progress.dart';
import '../models/project_merge.dart'
    show currentWorkerName, markItemDeleted, stampAuthor, kDeletedIdsKey;

/// 단계 이름을 줄여 쓴 머리글(예: "컷팅·벤딩" → "컷벤", "루프 체크" → "루프").
String lineStageShort(String s) {
  final parts = s.split('·').map((e) => e.trim()).where((e) => e.isNotEmpty);
  if (parts.length > 1) return parts.map((e) => e.characters.first).join();
  final t = s.replaceAll(' ', '');
  return t.characters.take(2).toString();
}

class LineBoardPage extends StatefulWidget {
  final Map<String, dynamic> log;
  final VoidCallback onChanged; // 프로젝트 저장

  const LineBoardPage({super.key, required this.log, required this.onChanged});

  @override
  State<LineBoardPage> createState() => _LineBoardPageState();
}

enum _Filter { all, going, done }

class _LineBoardPageState extends State<LineBoardPage> {
  _Filter _filter = _Filter.all;
  String _q = '';

  Map<String, dynamic> get _log => widget.log;
  List<String> get _stages => lineStagesOf(_log);

  /// 프로젝트에 든 라인 목록(같은 객체를 고친다).
  List<Map<String, dynamic>> get _items {
    final raw = _log[kLineItemsKey];
    if (raw is List<Map<String, dynamic>>) return raw;
    final list = lineItemsOf(_log);
    _log[kLineItemsKey] = list;
    return list;
  }

  void _save() {
    widget.onChanged();
    setState(() {});
  }

  void _toggle(Map<String, dynamic> line, String stage) {
    HapticFeedback.selectionClick();
    setLineStage(
      line,
      stage,
      !lineStageDone(line, stage),
      who: currentWorkerName.value,
    );
    _save();
  }

  Future<void> _addLines() async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('라인 넣기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '한 줄에 라인 번호 하나. 엑셀에서 라인 번호 열을 복사해 붙여 넣어도 됩니다.',
              style: TextStyle(fontSize: 13, color: AppColors.textSub),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('line_add_field'),
              controller: ctrl,
              autofocus: true,
              minLines: 4,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText: '1F-PT-101\n1F-PT-102',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            key: const Key('line_add_ok'),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('넣기'),
          ),
        ],
      ),
    );
    if (text == null || !mounted) return;
    final names = parseLineNames(text);
    final now = DateTime.now();
    var added = 0, same = 0;
    for (final n in names) {
      if (findLine(_log, n) != null) {
        same++;
        continue;
      }
      final m = <String, dynamic>{
        'id': 'line_${now.microsecondsSinceEpoch}_$added',
        'name': n,
        'note': '',
        'done': <String, dynamic>{},
      };
      stampAuthor(m, currentWorkerName.value, created: true);
      _items.add(m);
      added++;
    }
    if (added > 0) _save();
    if (!mounted) return;
    showAppSnack(
      context,
      added == 0
          ? '넣을 새 라인이 없습니다${same > 0 ? '(이미 있는 라인 $same개)' : ''}.'
          : '라인 $added개를 넣었습니다${same > 0 ? '(이미 있는 $same개는 뺌)' : ''}.',
    );
  }

  Future<void> _edit(Map<String, dynamic> line) async {
    final name = TextEditingController(text: '${line['name'] ?? ''}');
    final note = TextEditingController(text: '${line['note'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('라인 고치기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('line_edit_name'),
              controller: name,
              decoration: const InputDecoration(labelText: '라인 번호'),
            ),
            TextField(
              key: const Key('line_edit_note'),
              controller: note,
              decoration: const InputDecoration(labelText: '메모'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final n = name.text.trim();
    if (n.isEmpty) return;
    final other = findLine(_log, n);
    if (other != null && other['id'] != line['id']) {
      showAppSnack(context, '같은 라인 번호가 이미 있습니다.', kind: AppSnackKind.error);
      return;
    }
    line['name'] = n;
    line['note'] = note.text.trim();
    stampAuthor(line, currentWorkerName.value, created: false);
    _save();
  }

  void _delete(Map<String, dynamic> line) {
    final i = _items.indexOf(line);
    if (i < 0) return;
    _items.removeAt(i);
    markItemDeleted(_log, line['id']?.toString());
    _save();
    showAppSnack(
      context,
      "라인 '${line['name']}'을 지웠습니다.",
      onUndo: () {
        if (!mounted) return;
        final ids = List<String>.from(
          ((_log[kDeletedIdsKey] as List?) ?? const []).map((e) => '$e'),
        )..remove(line['id']?.toString());
        _log[kDeletedIdsKey] = ids;
        _items.insert(i.clamp(0, _items.length), line);
        _save();
      },
    );
  }

  Future<void> _editStages() async {
    final old = _stages;
    final ctrl = TextEditingController(text: old.join('\n'));
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('단계 이름'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '한 줄에 단계 하나, 작업 순서대로. 같은 자리의 이름을 바꾸면 체크도 따라갑니다.',
              style: TextStyle(fontSize: 13, color: AppColors.textSub),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('line_stage_field'),
              controller: ctrl,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, kDefaultLineStages.join('\n')),
            child: const Text('처음 것으로'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            key: const Key('line_stage_ok'),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (text == null || !mounted) return;
    final next = parseLineNames(text);
    if (next.isEmpty) return;
    // 같은 자리 이름이 바뀌면 체크를 새 이름으로 옮긴다.
    for (int k = 0; k < old.length && k < next.length; k++) {
      if (old[k] == next[k]) continue;
      for (final l in _items) {
        final d = Map<String, dynamic>.from((l['done'] as Map?) ?? {});
        if (!d.containsKey(old[k])) continue;
        d[next[k]] = d.remove(old[k]);
        l['done'] = d;
        l['updatedAt'] = DateTime.now().toIso8601String();
      }
    }
    _log[kLineStagesKey] = next;
    _save();
  }

  Future<void> _exportCsv() async {
    if (_items.isEmpty) return;
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/라인진행_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(buildLineCsv(_log));
      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(file.path)], text: '${_log['name']} 라인 진행');
    } catch (_) {
      if (mounted) {
        showAppSnack(context, '엑셀 파일을 만들지 못했습니다.', kind: AppSnackKind.error);
      }
    }
  }

  Widget _dot(Map<String, dynamic> line, String stage) {
    final on = lineStageDone(line, stage);
    return Tooltip(
      message: stage,
      child: InkResponse(
        key: Key('line_dot_${line['name']}_$stage'),
        onTap: () => _toggle(line, stage),
        radius: 22,
        child: Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? AppColors.brand : Colors.transparent,
            border: Border.all(
              color: on ? AppColors.brand : AppColors.idle,
              width: 1.6,
            ),
          ),
          child: on
              ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stages = _stages;
    final p = lineProgress(_log);
    final q = _q.trim().toUpperCase();
    final shown = [
      for (final l in _items)
        if ((q.isEmpty || '${l['name']}'.toUpperCase().contains(q)) &&
            switch (_filter) {
              _Filter.all => true,
              _Filter.done => lineComplete(l, stages),
              _Filter.going => !lineComplete(l, stages),
            })
          l,
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${_log['name'] ?? ''} · 라인 진행'),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        actions: [
          PopupMenuButton<String>(
            key: const Key('line_menu'),
            onSelected: (v) {
              if (v == 'stages') _editStages();
              if (v == 'csv') _exportCsv();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'stages', child: Text('단계 이름 고치기')),
              if (_items.isNotEmpty)
                const PopupMenuItem(value: 'csv', child: Text('엑셀로 보내기')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('line_add'),
        onPressed: _addLines,
        icon: const Icon(Icons.add),
        label: const Text('라인 넣기'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        children: [
          if (p.total > 0)
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '다 마친 라인 ${p.complete} / ${p.total}',
                      key: const Key('line_summary'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: p.total == 0 ? 0 : p.complete / p.total,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        for (final s in stages)
                          Text(
                            '$s ${p.perStage[s]}/${p.total}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSub,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (p.total == 0)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                '라인을 넣으면 라인마다 컷팅·벤딩부터 루프 체크까지 단계를 눌러 체크합니다. '
                '압력시험·교정 기록을 이 프로젝트에 붙여 합격으로 저장하면 그 단계가 저절로 체크됩니다.',
                style: TextStyle(height: 1.5, color: AppColors.textSub),
              ),
            ),
          if (p.total > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final (f, label) in const [
                  (_Filter.all, '전체'),
                  (_Filter.going, '진행 중'),
                  (_Filter.done, '다 마침'),
                ])
                  ChoiceChip(
                    key: Key('line_filter_${f.name}'),
                    label: Text(label),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
              ],
            ),
            if (p.total > 8)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  key: const Key('line_search'),
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                    hintText: '라인 번호 찾기',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
            const SizedBox(height: 10),
            // 머리글: 단계 줄임 이름
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '라인',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSub,
                      ),
                    ),
                  ),
                  for (final s in stages)
                    SizedBox(
                      width: 34,
                      child: Text(
                        lineStageShort(s),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSub,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            for (final l in shown)
              SwipeToDelete(
                itemKey: ValueKey('line_${l['id']}'),
                onDelete: () => _delete(l),
                child: Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    onLongPress: () => _edit(l),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${l['name'] ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                if ('${l['note'] ?? ''}'.isNotEmpty)
                                  Text(
                                    '${l['note']}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSub,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          for (final s in stages) _dot(l, s),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                '동그라미를 눌러 체크하거나 풉니다. 줄을 길게 누르면 이름·메모를 고치고, 왼쪽으로 밀면 지웁니다.',
                style: TextStyle(fontSize: 12, color: AppColors.textSub),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
