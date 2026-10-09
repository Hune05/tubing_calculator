// 저장한 압력시험 기록 목록(폰 저장 + 서버, 열 때 서버 것과 합침). 누르면 기록서 보기·계산기로 불러오기·지우기. CSV 내보내기(엑셀용).
// 지우기는 줄을 왼쪽으로 밀거나 누른 창의 "지우기" — 지운 뒤 "되돌리기"를 띄운다(10-02).
// 불러오기를 고르면 그 기록을 돌려주며 닫는다(Navigator.pop(record)).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/common_widgets/swipe_to_delete.dart';
import '../../core/theme/field_view.dart';
import '../../data/record_sync.dart';
import 'test_record.dart';
import 'test_record_pdf.dart';
import '../trash/trash_kinds.dart';

String _date(DateTime d) => '${ptDay(d)} ${ptHm(d)}';

/// 띄어쓰기·대소문자·줄표 같은 기호는 무시한다(GN101로 쳐도 GN-101이 나오게).
String _norm(String s) => s.replaceAll(RegExp(r'[\s\-_./·,()]+'), '').toLowerCase();

/// 기록 목록 거르기: 검색어(라인·시험 번호·현장·계통·P&ID·구간·시험자·메모)와 판정(null이면 전체).
/// 판정이 안 난 기록(값 부족)은 합격·불합격 어느 쪽에도 들지 않는다.
List<PtRecord> filterPtRecords(List<PtRecord> list, String query, bool? pass) {
  final q = _norm(query);
  return [
    for (final r in list)
      if ((pass == null || r.verdict.pass == pass) &&
          (q.isEmpty ||
              _norm(
                [r.line, r.testNo, r.site, r.system, r.pid, r.section, r.tester, r.memo].join(' '),
              ).contains(q)))
        r,
  ];
}

class PtRecordsPage extends StatefulWidget {
  const PtRecordsPage({super.key, this.projectId, this.projectName = ''});

  /// 주면 그 프로젝트에 붙인 기록만 보인다(프로젝트 개요에서 열 때, 10-09).
  final String? projectId;
  final String projectName;

  @override
  State<PtRecordsPage> createState() => _PtRecordsPageState();
}

class _PtRecordsPageState extends State<PtRecordsPage> {
  List<PtRecord>? _list;
  RecordSyncStatus? _sync;
  final _search = TextEditingController();
  bool? _pass; // 판정 거르기: null 전체, true 합격, false 불합격

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _reload();
    _syncWithServer();
  }

  Future<void> _reload() async {
    final l = await PtRecordStore.load();
    if (mounted) setState(() => _list = _scope(l));
  }

  /// 서버의 내 기록을 받아 합치고, 폰에만 있는 것을 올린다. 통신이 없으면 폰 것만 보인다.
  Future<void> _syncWithServer() async {
    final s0 = await PtRecordStore.sync.status();
    if (mounted) setState(() => _sync = s0);
    final s = await PtRecordStore.sync.syncNow();
    final l = await PtRecordStore.load();
    if (mounted) {
      setState(() {
        _sync = s;
        _list = _scope(l);
      });
    }
  }

  /// 지운 것이 서버에 올라간 뒤 상태 줄을 고친다.
  Future<void> _refreshSyncAfterPush() async {
    await RecordSync.idle();
    final s = await PtRecordStore.sync.status();
    if (mounted) setState(() => _sync = s);
  }

  /// 목록 위 한 줄: 서버에 저장됨 / 폰에만 저장된 것 N건.
  Widget _syncLine() {
    final s = _sync;
    if (s == null) return const SizedBox.shrink();
    final waiting = !s.enabled || s.pending > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: Row(
        children: [
          Icon(
            waiting ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined,
            size: 16,
            color: waiting ? fc.caution : fc.textSub,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              recordSyncText(s),
              key: const Key('pr_sync'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: waiting ? FontWeight.w700 : FontWeight.w500,
                color: waiting ? fc.caution : fc.textSub,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _name(PtRecord r) => r.line.isEmpty ? '(라인 번호 없음)' : r.line;

  List<PtRecord> _scope(List<PtRecord> l) => widget.projectId == null
      ? l
      : [for (final r in l) if (r.projectId == widget.projectId) r];

  @override
  Widget build(BuildContext context) => FieldViewTheme(
    child: Builder(
      builder: (context) => Scaffold(
        backgroundColor: fc.background,
        appBar: AppBar(
          backgroundColor: fc.surface,
          foregroundColor: fc.text,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            widget.projectId == null ? '압력시험 기록' : '압력시험 기록 · ${widget.projectName}',
            style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
          ),
          actions: [
            // 걸러 놓았으면 보이는 기록만 내보낸다(건수를 단추에 적어 무엇이 나가는지 보인다).
            if (_shown.isNotEmpty)
              TextButton(
                key: const Key('pr_csv'),
                onPressed: _exportCsv,
                child: Text(
                  _filtering ? 'CSV 내보내기 ${_shown.length}건' : 'CSV 내보내기',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
        body: SafeArea(child: _body()),
      ),
    ),
  );

  bool get _filtering => _search.text.trim().isNotEmpty || _pass != null;

  /// 지금 목록에 보이는 기록(검색어·판정 칩으로 거른 것).
  List<PtRecord> get _shown => filterPtRecords(_list ?? const [], _search.text, _pass);

  /// 엑셀에서 여는 CSV 파일을 만들어 공유 창을 연다(보내기는 사용자가 고른다).
  Future<void> _exportCsv() async {
    final l = _shown;
    if (l.isEmpty) return;
    final d = DateTime.now();
    final name =
        'pt_records_${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}.csv';
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(utf8.encode(ptRecordsCsv(l)));
      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(file.path)], text: '압력시험 기록 ${l.length}건');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('CSV 파일을 만들지 못했습니다.')));
    }
  }

  Widget _body() {
    final l = _list;
    if (l == null) return const Center(child: CircularProgressIndicator());
    if (l.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '저장한 기록이 없습니다.\n시험 기록 탭에서 시험을 마치고 "기록 저장"을 누르십시오.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: fc.textSub, height: 1.5),
          ),
        ),
      );
    }
    final shown = _shown;
    final filtering = _filtering;
    final head = <Widget>[
      _syncLine(),
      _filterBar(),
      if (filtering)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
          child: Text(
            shown.isEmpty ? '맞는 기록이 없습니다.' : '${shown.length}건 / 전체 ${l.length}건',
            key: const Key('pr_count'),
            style: TextStyle(fontSize: 13, color: fc.textSub),
          ),
        ),
    ];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: head.length + shown.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => i < head.length ? head[i] : _tile(shown[i - head.length]),
    );
  }

  /// 검색 칸과 판정 칩(전체·합격·불합격). 기록이 쌓이면 목록을 끝까지 내려가지 않고 찾는다.
  Widget _filterBar() {
    Widget chip(String label, bool? v) {
      final on = _pass == v;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          key: Key('pr_pass_${v == null ? 'all' : (v ? 'ok' : 'ng')}'),
          label: Text(label),
          selected: on,
          showCheckmark: false,
          selectedColor: fc.brand,
          backgroundColor: fc.surface,
          side: BorderSide(color: on ? fc.brand : fc.line),
          labelStyle: TextStyle(
            fontWeight: FontWeight.w700,
            color: on ? Colors.white : fc.text,
          ),
          onSelected: (_) => setState(() => _pass = v),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('pr_search'),
          controller: _search,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          style: TextStyle(color: fc.text),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search, color: fc.textSub),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    key: const Key('pr_search_clear'),
                    icon: Icon(Icons.close, color: fc.textSub),
                    tooltip: '지우기',
                    onPressed: () => setState(_search.clear),
                  ),
            hintText: '라인·시험 번호·현장·시험자',
            hintStyle: TextStyle(color: fc.textSub),
            filled: true,
            fillColor: fc.surface,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: fc.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: fc.line),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            chip('전체', null),
            chip('합격', true),
            chip('불합격', false),
          ],
        ),
      ],
    );
  }

  Widget _tile(PtRecord r) {
    final pass = r.verdict.pass;
    final color = pass == false
        ? fc.danger
        : (pass == true ? fc.brand : fc.textSub);
    final sub = [
      if (r.testNo.isNotEmpty) r.testNo,
      if (r.system.isNotEmpty) r.system,
    ].join(' · ');
    return SwipeToDelete(
      itemKey: ValueKey('pr_swipe_${r.id}'),
      radius: 14,
      bottomMargin: 0,
      onDelete: () => _delete(r),
      child: Material(
        color: fc.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: Key('pr_item_${r.id}'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => _actions(r),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name(r),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: fc.text,
                        ),
                      ),
                      if (sub.isNotEmpty)
                        Text(
                          sub,
                          style: TextStyle(fontSize: 14, color: fc.text),
                        ),
                      Text(
                        '${_date(r.date)}${r.tester.isEmpty ? '' : ' · ${r.tester}'}',
                        style: TextStyle(fontSize: 13, color: fc.textSub),
                      ),
                      Text(
                        '${ptCodeShort(r.code)} ${ptMediumLabel(r.medium)} · ${ptFluidLabel(r.fluid)}',
                        key: Key('pr_kind_${r.id}'),
                        style: TextStyle(fontSize: 13, color: fc.textSub),
                      ),
                      if (r.witnessLine.isNotEmpty || r.photos.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (r.witnessLine.isNotEmpty)
                                Flexible(
                                  child: Text(
                                    r.witnessLine,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: fc.textSub,
                                    ),
                                  ),
                                ),
                              if (r.photos.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.photo_camera_outlined,
                                  size: 13,
                                  color: fc.textSub,
                                ),
                                Text(
                                  '${r.photos.length}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: fc.textSub,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  ptVerdictText(pass),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 목록에서 곧바로 빼고 휴지통으로 옮긴다. "되돌리기"를 누르면 휴지통에서 복원한다.
  void _delete(PtRecord r) {
    final l = _list;
    if (l == null) return;
    setState(() => _list = [...l]..removeWhere((e) => e.id == r.id));
    final title = '${_name(r)} ${_date(r.date)}';
    final done = trashPtRecord(r, title: title);
    unawaited(done.then((_) => _refreshSyncAfterPush()));
    showTrashUndo(
      context,
      title,
      done,
      onRestored: () async {
        await _reload();
        unawaited(_refreshSyncAfterPush());
      },
    );
  }

  Future<void> _actions(PtRecord r) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: fc.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _name(r),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: fc.text,
                  ),
                ),
              ),
            ),
            for (final (k, t) in const [
              ('pdf', '기록서 보기'),
              ('load', '계산기로 불러오기'),
              ('delete', '지우기'),
            ])
              ListTile(
                key: Key('pr_act_$k'),
                title: Text(
                  t,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: k == 'delete' ? fc.danger : fc.text,
                  ),
                ),
                onTap: () => Navigator.pop(ctx, k),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'pdf':
        await openPtRecordPdf(context, r);
      case 'load':
        Navigator.pop(context, r);
      case 'delete':
        _delete(r);
    }
  }
}
