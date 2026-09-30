// 축 정렬 현장 지침 화면: 경우별 대책을 찾아 보고, 자기 현장 요령을 항목마다 메모로 남긴다.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_icon_set.dart';
import '../../core/theme/app_tokens.dart';
import 'alignment_guide_data.dart';

/// 항목별 내 메모(폰에 남는다).
class AlignGuideNotes {
  static const String key = 'align_guide_notes_v1';

  static Future<Map<String, String>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw) as Map;
      return {for (final e in m.entries) e.key.toString(): e.value.toString()};
    } catch (_) {
      return {};
    }
  }

  static Future<void> save(Map<String, String> notes) async {
    final clean = {for (final e in notes.entries) if (e.value.trim().isNotEmpty) e.key: e.value.trim()};
    await (await SharedPreferences.getInstance()).setString(key, jsonEncode(clean));
  }
}

/// 한 항목을 글로(카톡 보내기용).
String alignTipText(AlignTip t, {String note = ''}) {
  final b = StringBuffer('[정렬 지침] ${t.title}\n이럴 때: ${t.symptom}');
  if (t.causes.isNotEmpty) b.write('\n원인: ${t.causes.join(' / ')}');
  b.write('\n대책:');
  for (var i = 0; i < t.fixes.length; i++) {
    b.write('\n${i + 1}. ${t.fixes[i]}');
  }
  b.write('\n확인: ${t.check}');
  if (note.trim().isNotEmpty) b.write('\n현장 메모: ${note.trim()}');
  return b.toString();
}

class AlignmentGuidePage extends StatefulWidget {
  /// 처음 펼쳐 둘 항목(예: 검산 경고에서 들어오면 'closure').
  final String? openId;
  final Future<void> Function(String text)? share;
  const AlignmentGuidePage({super.key, this.openId, this.share});

  @override
  State<AlignmentGuidePage> createState() => _AlignmentGuidePageState();
}

class _AlignmentGuidePageState extends State<AlignmentGuidePage> {
  final _q = TextEditingController();
  AlignGuideCat? _cat;
  late final Set<String> _open = {if (widget.openId != null) widget.openId!};
  Map<String, String> _notes = {};
  final Map<String, GlobalKey> _keys = {for (final t in kAlignTips) t.id: GlobalKey()};

  @override
  void initState() {
    super.initState();
    AlignGuideNotes.load().then((v) {
      if (mounted) setState(() => _notes = v);
    });
    if (widget.openId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[widget.openId]?.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250));
      });
    }
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _editNote(AlignTip t) async {
    final out = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NoteSheet(title: t.title, initial: _notes[t.id] ?? ''),
    );
    if (out == null) return;
    final next = {..._notes, t.id: out.trim()};
    next.removeWhere((_, v) => v.isEmpty);
    setState(() => _notes = next);
    await AlignGuideNotes.save(next);
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.text.trim();
    final list = [
      for (final t in kAlignTips)
        if ((_cat == null || t.cat == _cat) && (t.matches(q) || (_notes[t.id] ?? '').contains(q))) t,
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('축 정렬 현장 지침')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.brandSoft, borderRadius: BorderRadius.circular(AppRadius.medium)),
            child: const Text(
              '현장이 늘 좋은 조건은 아닙니다. 여러 현장에서 흔히 쓰는 요령을 경우별로 모았습니다(이럴 때 → 원인 → 대책 → 확인). '
              '숫자는 흔히 쓰는 값이고, 제조사 매뉴얼·사내 절차가 있으면 그것이 먼저입니다. 항목마다 내 현장 메모를 남길 수 있습니다.',
              style: TextStyle(fontSize: 12.5, height: 1.55, color: AppColors.text),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('guide_search'),
            controller: _q,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(AppIcons.search, size: 18),
              hintText: '증상으로 찾기 (예: 진동, 소프트 풋, 못 밈)',
              isDense: true,
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(icon: const Icon(AppIcons.close, size: 18), onPressed: () => setState(_q.clear)),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(label: const Text('전체'), selected: _cat == null, onSelected: (_) => setState(() => _cat = null)),
              for (final c in AlignGuideCat.values)
                ChoiceChip(key: Key('guide_cat_${c.name}'), label: Text(c.label), selected: _cat == c, onSelected: (_) => setState(() => _cat = _cat == c ? null : c)),
            ],
          ),
          const SizedBox(height: 8),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('맞는 항목이 없습니다. 다른 말로 찾아 보십시오.', textAlign: TextAlign.center, style: AppText.sub),
            ),
          for (final t in list) _tipCard(t),
        ],
      ),
    );
  }

  Widget _tipCard(AlignTip t) {
    final open = _open.contains(t.id);
    final note = _notes[t.id] ?? '';
    Widget section(String head, Color c, List<Widget> body) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(head, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: c)),
          ),
          const SizedBox(height: 4),
          ...body,
        ],
      ),
    );
    Widget line(String s, {String? mark}) => Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 20, child: Text(mark ?? '·', style: const TextStyle(fontSize: 13.5, height: 1.5, fontWeight: FontWeight.w800, color: AppColors.textSub))),
          Expanded(child: Text(s, style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.text))),
        ],
      ),
    );
    return Card(
      key: _keys[t.id],
      margin: const EdgeInsets.only(top: 8),
      elevation: 0,
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('guide_tip_${t.id}'),
            onTap: () => setState(() => open ? _open.remove(t.id) : _open.add(t.id)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${t.cat.label}${note.isNotEmpty ? ' · 내 메모 있음' : ''}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.brand)),
                        const SizedBox(height: 2),
                        Text(t.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.text)),
                        const SizedBox(height: 2),
                        Text(t.symptom, style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textSub)),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.25 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: const Icon(AppIcons.forward, size: 18, color: AppColors.textFaint),
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  if (t.causes.isNotEmpty) section('흔한 원인', AppColors.caution, [for (final c in t.causes) line(c)]),
                  section('대책', AppColors.brand, [for (var i = 0; i < t.fixes.length; i++) line(t.fixes[i], mark: '${i + 1}.')]),
                  section('됐는지 보기', AppColors.ok, [line(t.check)]),
                  if (note.isNotEmpty)
                    section('내 현장 메모', AppColors.text, [Text(note, key: Key('guide_note_${t.id}'), style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.text))]),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      TextButton.icon(
                        key: Key('guide_note_btn_${t.id}'),
                        onPressed: () => _editNote(t),
                        icon: const Icon(AppIcons.editNote, size: 16),
                        label: Text(note.isEmpty ? '내 메모 남기기' : '메모 고치기'),
                      ),
                      if (widget.share != null)
                        TextButton.icon(
                          key: Key('guide_share_${t.id}'),
                          onPressed: () => widget.share!(alignTipText(t, note: note)),
                          icon: const Icon(AppIcons.share, size: 16),
                          label: const Text('보내기'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 내 현장 메모 적는 창(글 칸을 스스로 가지고 있다가 닫힐 때 치운다).
class _NoteSheet extends StatefulWidget {
  final String title;
  final String initial;
  const _NoteSheet({required this.title, required this.initial});

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('내 현장 메모 · ${widget.title}', style: AppText.title),
            const SizedBox(height: 4),
            const Text('이 경우에 써 본 요령, 선배에게 들은 방법, 기계별 주의점을 적어 둡니다.', style: TextStyle(fontSize: 12.5, color: AppColors.textSub)),
            const SizedBox(height: 8),
            TextField(
              key: const Key('guide_note_field'),
              controller: _c,
              maxLines: 5,
              minLines: 3,
              decoration: const InputDecoration(hintText: '예: 2호기 급수펌프는 뒷발 오른쪽 볼트 구멍이 좁아 펌프를 먼저 0.2 밈'),
            ),
            const SizedBox(height: 10),
            FilledButton(key: const Key('guide_note_ok'), onPressed: () => Navigator.pop(context, _c.text), child: const Text('저장')),
          ],
        ),
      ),
    );
  }
}
