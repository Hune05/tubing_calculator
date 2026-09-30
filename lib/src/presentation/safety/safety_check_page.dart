// 작업 전 안전 점검: 작업을 시작하기 전에 항목을 하나씩 확인하고, 기록으로 남겨 카톡으로 보낸다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_icon_set.dart';
import '../../core/theme/app_tokens.dart';
import '../tube_cutting/cutting_action_bar.dart' show kakaoSender, textSharer;
import 'safety_check_model.dart';

// 카카오톡으로 바로 보내고, 카카오톡이 없으면 일반 공유창으로 보낸다.
Future<void> _defaultShare(String text) async {
  if (await kakaoSender(text)) return;
  await textSharer(text);
}

class SafetyCheckPage extends StatefulWidget {
  final Future<void> Function(String text) share;
  final DateTime Function()? now;
  const SafetyCheckPage({super.key, this.share = _defaultShare, this.now});

  @override
  State<SafetyCheckPage> createState() => _SafetyCheckPageState();
}

class _SafetyCheckPageState extends State<SafetyCheckPage> {
  final _site = TextEditingController();
  final _work = TextEditingController();
  final _people = TextEditingController();
  final _risks = TextEditingController();
  List<String> _items = [];
  final Map<String, SafetyAnswer> _answers = {};
  bool _loaded = false;

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _site.dispose();
    _work.dispose();
    _people.dispose();
    _risks.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await loadSafetyItems();
    String site = '';
    try {
      site = (await SharedPreferences.getInstance()).getString(kSafetySiteKey) ?? '';
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _items = items;
      _site.text = site;
      _loaded = true;
    });
  }

  SafetyAnswer _answerOf(String label) => _answers[label] ?? SafetyAnswer.none;

  void _set(String label, SafetyAnswer a) {
    HapticFeedback.selectionClick();
    setState(() {
      // 같은 것을 다시 누르면 체크가 풀린다.
      if (_answerOf(label) == a) {
        _answers.remove(label);
      } else {
        _answers[label] = a;
      }
    });
  }

  SafetyRecord _record() {
    final at = _now;
    return SafetyRecord(
      id: at.millisecondsSinceEpoch.toString(),
      at: at,
      site: _site.text.trim(),
      work: _work.text.trim(),
      people: _people.text.trim(),
      risks: _risks.text.trim(),
      lines: [for (final l in _items) SafetyLine(l, _answerOf(l))],
    );
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<bool> _confirmUnanswered(SafetyRecord r) async {
    if (r.unanswered == 0) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('확인하지 않은 항목이 있습니다'),
        content: Text('${r.unanswered}개 항목이 아직 "확인"이나 "해당 없음"이 아닙니다. 그대로 진행하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('다시 확인'),
          ),
          TextButton(
            key: const Key('safety_confirm_go'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('그대로'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _remember() async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        kSafetySiteKey,
        _site.text.trim(),
      );
    } catch (_) {}
  }

  Future<void> _save({bool send = false}) async {
    final r = _record();
    if (!await _confirmUnanswered(r) || !mounted) return;
    await addSafetyRecord(r);
    await _remember();
    if (send) await widget.share(buildSafetyCheckText(r));
    if (!mounted) return;
    setState(() {
      _answers.clear();
      _work.clear();
      _people.clear();
      _risks.clear();
    });
    _toast(send ? '저장하고 보냈습니다' : '저장했습니다');
  }

  Future<void> _editItems() async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ItemsSheet(items: _items),
    );
    if (result == null || !mounted) return;
    await saveSafetyItems(result);
    setState(() {
      _items = result;
      _answers.removeWhere((k, _) => !result.contains(k));
    });
  }

  Future<void> _openHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => SafetyHistoryPage(share: widget.share)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final at = _now;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('작업 전 안전 점검'),
        actions: [
          IconButton(
            key: const Key('safety_history'),
            tooltip: '지난 기록',
            icon: const Icon(AppIcons.history),
            onPressed: _openHistory,
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      children: [
                        Text(
                          '${safetyTimeLabel(at)} 점검',
                          style: AppText.caption,
                        ),
                        const SizedBox(height: 8),
                        _field(_site, '현장 (선택)', key: 'safety_site'),
                        const SizedBox(height: 8),
                        _field(_work, '오늘 작업', key: 'safety_work', hint: '예: 센서 3개소 결선'),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(
                              child: Text('점검 항목', style: AppText.title),
                            ),
                            TextButton(
                              key: const Key('safety_edit_items'),
                              onPressed: _editItems,
                              child: const Text('항목 고치기'),
                            ),
                          ],
                        ),
                        for (final label in _items) _row(label),
                        const SizedBox(height: 12),
                        _field(_risks, '위험 요인·메모 (선택)', key: 'safety_risks', lines: 2),
                        const SizedBox(height: 8),
                        _field(_people, '참석자 (선택)', key: 'safety_people', hint: '이름을 쉼표로'),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.line)),
                    ),
                    child: Row(
                      children: [
                        OutlinedButton(
                          key: const Key('safety_save'),
                          onPressed: () => _save(),
                          child: const Text('저장'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('safety_send'),
                            onPressed: () => _save(send: true),
                            icon: const Icon(AppIcons.send, size: 18),
                            label: const Text('저장하고 카톡으로 보내기'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    required String key,
    String? hint,
    int lines = 1,
  }) => TextField(
    key: Key(key),
    controller: c,
    maxLines: lines,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.surface,
    ),
  );

  Widget _row(String label) {
    final a = _answerOf(label);
    Widget chip(String text, SafetyAnswer v, Color color) => ChoiceChip(
      key: Key('safety_${v.name}_$label'),
      label: Text(text),
      selected: a == v,
      showCheckmark: false,
      selectedColor: color.withValues(alpha: 0.18),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w800,
        color: a == v ? color : AppColors.textSub,
      ),
      onSelected: (_) => _set(label, v),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                chip('확인', SafetyAnswer.yes, AppColors.ok),
                const SizedBox(width: 8),
                chip('해당 없음', SafetyAnswer.na, AppColors.textSub),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 점검 항목을 더하고 빼고 처음 것으로 되돌린다.
class _ItemsSheet extends StatefulWidget {
  final List<String> items;
  const _ItemsSheet({required this.items});

  @override
  State<_ItemsSheet> createState() => _ItemsSheetState();
}

class _ItemsSheetState extends State<_ItemsSheet> {
  late final List<String> _list = List.of(widget.items);
  final _add = TextEditingController();

  @override
  void dispose() {
    _add.dispose();
    super.dispose();
  }

  void _addItem() {
    final t = _add.text.trim();
    if (t.isEmpty || _list.contains(t)) return;
    setState(() {
      _list.add(t);
      _add.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('점검 항목 고치기', style: AppText.title),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final l in _list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l, style: const TextStyle(fontSize: 14)),
                    trailing: IconButton(
                      key: Key('safety_remove_$l'),
                      icon: const Icon(AppIcons.delete, size: 20),
                      onPressed: () => setState(() => _list.remove(l)),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('safety_add_field'),
                  controller: _add,
                  decoration: const InputDecoration(hintText: '항목 더하기'),
                  onSubmitted: (_) => _addItem(),
                ),
              ),
              IconButton(
                key: const Key('safety_add_button'),
                icon: const Icon(AppIcons.add),
                onPressed: _addItem,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                key: const Key('safety_reset_items'),
                onPressed: () => setState(() {
                  _list
                    ..clear()
                    ..addAll(kDefaultSafetyItems);
                }),
                child: const Text('처음 항목으로'),
              ),
              const Spacer(),
              FilledButton(
                key: const Key('safety_items_done'),
                onPressed: () => Navigator.pop(context, _list),
                child: const Text('완료'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 지난 점검 기록: 보기, 다시 보내기, 지우기.
class SafetyHistoryPage extends StatefulWidget {
  final Future<void> Function(String text) share;
  const SafetyHistoryPage({super.key, required this.share});

  @override
  State<SafetyHistoryPage> createState() => _SafetyHistoryPageState();
}

class _SafetyHistoryPageState extends State<SafetyHistoryPage> {
  List<SafetyRecord>? _records;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final r = await loadSafetyRecords();
    if (mounted) setState(() => _records = r);
  }

  Future<void> _open(SafetyRecord r) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(
                    buildSafetyCheckText(r),
                    style: const TextStyle(fontSize: 14, height: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton(
                    key: const Key('safety_history_delete'),
                    onPressed: () => Navigator.pop(ctx, 'delete'),
                    child: const Text('지우기'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const Key('safety_history_send'),
                      onPressed: () => Navigator.pop(ctx, 'send'),
                      child: const Text('카톡으로 보내기'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (action == 'send') {
      await widget.share(buildSafetyCheckText(r));
    } else if (action == 'delete') {
      await deleteSafetyRecord(r.id);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _records;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('지난 점검 기록')),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
          ? const Center(
              child: Text('저장한 점검 기록이 없습니다', style: AppText.sub),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final r in list)
                  Card(
                    elevation: 0,
                    color: AppColors.surface,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      key: Key('safety_record_${r.id}'),
                      onTap: () => _open(r),
                      title: Text(
                        [safetyTimeLabel(r.at), if (r.site.isNotEmpty) r.site].join(' · '),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        [
                          if (r.work.isNotEmpty) r.work,
                          r.unanswered == 0
                              ? '항목 모두 확인'
                              : '미확인 ${r.unanswered}개',
                        ].join(' · '),
                      ),
                      trailing: const Icon(AppIcons.forward),
                    ),
                  ),
              ],
            ),
    );
  }
}
