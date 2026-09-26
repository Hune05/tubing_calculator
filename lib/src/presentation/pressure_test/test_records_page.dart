// 저장한 압력시험 기록 목록(폰에만). 누르면 기록서 보기·계산기로 불러오기·지우기. CSV 내보내기(엑셀용).
// 불러오기를 고르면 그 기록을 돌려주며 닫는다(Navigator.pop(record)).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/field_view.dart';
import 'test_record.dart';
import 'test_record_pdf.dart';

String _date(DateTime d) => '${ptDay(d)} ${ptHm(d)}';

class PtRecordsPage extends StatefulWidget {
  const PtRecordsPage({super.key});

  @override
  State<PtRecordsPage> createState() => _PtRecordsPageState();
}

class _PtRecordsPageState extends State<PtRecordsPage> {
  List<PtRecord>? _list;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final l = await PtRecordStore.load();
    if (mounted) setState(() => _list = l);
  }

  String _name(PtRecord r) => r.line.isEmpty ? '(라인 번호 없음)' : r.line;

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
            '저장한 압력시험 기록',
            style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
          ),
          actions: [
            if (_list?.isNotEmpty ?? false)
              TextButton(
                key: const Key('pr_csv'),
                onPressed: _exportCsv,
                child: const Text(
                  'CSV 내보내기',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
        body: SafeArea(child: _body()),
      ),
    ),
  );

  /// 엑셀에서 여는 CSV 파일을 만들어 공유 창을 연다(보내기는 사용자가 고른다).
  Future<void> _exportCsv() async {
    final l = _list;
    if (l == null || l.isEmpty) return;
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
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: l.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _tile(l[i]),
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
    return Material(
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
                      Text(sub, style: TextStyle(fontSize: 14, color: fc.text)),
                    Text(
                      '${_date(r.date)}${r.tester.isEmpty ? '' : ' · ${r.tester}'}',
                      style: TextStyle(fontSize: 13, color: fc.textSub),
                    ),
                    Text(
                      '${ptCodeShort(r.code)} ${ptMediumLabel(r.medium)} · ${ptFluidLabel(r.fluid)}',
                      key: Key('pr_kind_${r.id}'),
                      style: TextStyle(fontSize: 13, color: fc.textSub),
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
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('기록 지우기'),
            content: Text('${_name(r)} ${_date(r.date)} 기록을 지우겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              TextButton(
                key: const Key('pr_delete_ok'),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('지우기', style: TextStyle(color: fc.danger)),
              ),
            ],
          ),
        );
        if (ok == true) {
          await PtRecordStore.delete(r.id);
          await _reload();
        }
    }
  }
}
