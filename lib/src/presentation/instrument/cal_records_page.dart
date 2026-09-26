// 저장한 교정 기록 목록(폰에만). 누르면 성적서 보기·계산기로 불러오기·지우기.
// 불러오기를 고르면 그 기록을 돌려주며 닫는다(Navigator.pop(record)).
import 'package:flutter/material.dart';

import '../../core/theme/field_view.dart';
import 'cal_record.dart';
import 'cal_record_pdf.dart';

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class CalRecordsPage extends StatefulWidget {
  const CalRecordsPage({super.key});

  @override
  State<CalRecordsPage> createState() => _CalRecordsPageState();
}

class _CalRecordsPageState extends State<CalRecordsPage> {
  List<CalRecord>? _list;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final l = await CalRecordStore.load();
    if (mounted) setState(() => _list = l);
  }

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
            '저장한 교정 기록',
            style: TextStyle(fontWeight: FontWeight.w800, color: fc.text),
          ),
        ),
        body: SafeArea(child: _body()),
      ),
    ),
  );

  Widget _body() {
    final l = _list;
    if (l == null) return const Center(child: CircularProgressIndicator());
    if (l.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '저장한 기록이 없습니다.\n교정 점검 탭에서 값을 넣고 "기록 저장"을 누르십시오.',
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

  Widget _tile(CalRecord r) {
    final pass = r.finalPass;
    final color = pass == false
        ? fc.danger
        : (pass == true ? fc.brand : fc.textSub);
    return Material(
      color: fc.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: Key('cr_item_${r.id}'),
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
                      r.tag.isEmpty ? '(태그 없음)' : r.tag,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: fc.text,
                      ),
                    ),
                    if (r.instrument.isNotEmpty)
                      Text(
                        r.instrument,
                        style: TextStyle(fontSize: 14, color: fc.text),
                      ),
                    Text(
                      '${_date(r.date)}${r.worker.isEmpty ? '' : ' · ${r.worker}'}',
                      style: TextStyle(fontSize: 13, color: fc.textSub),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    calVerdictText(pass),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  Text(
                    r.adjusted ? '조정함' : '조정 안 함',
                    style: TextStyle(fontSize: 12, color: fc.textSub),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _actions(CalRecord r) async {
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
                  r.tag.isEmpty ? '(태그 없음)' : r.tag,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: fc.text,
                  ),
                ),
              ),
            ),
            for (final (k, t) in const [
              ('pdf', '성적서 보기'),
              ('load', '계산기로 불러오기'),
              ('delete', '지우기'),
            ])
              ListTile(
                key: Key('cr_act_$k'),
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
        await openCalRecordPdf(context, r);
      case 'load':
        Navigator.pop(context, r);
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('기록 지우기'),
            content: Text(
              '${r.tag.isEmpty ? '(태그 없음)' : r.tag} ${_date(r.date)} 기록을 지우겠습니까?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              TextButton(
                key: const Key('cr_delete_ok'),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('지우기', style: TextStyle(color: fc.danger)),
              ),
            ],
          ),
        );
        if (ok == true) {
          await CalRecordStore.delete(r.id);
          await _reload();
        }
    }
  }
}
