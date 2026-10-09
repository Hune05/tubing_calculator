// 프로젝트 개요의 "압력시험·교정 기록" 칸(10-09 고도화 1번): 저장 창에서 이 프로젝트에 붙인 기록을 모아 보인다.
// 기록은 폰(서버와 맞춘 사본)에서 읽는다. 붙인 기록이 없으면 칸을 그리지 않는다.
import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../instrument/cal_record.dart';
import '../../instrument/cal_records_page.dart';
import '../../pressure_test/test_record.dart';
import '../../pressure_test/test_records_page.dart';
import '../models/weekly_plan.dart' show WeeklyTestLine;

/// 칸에 보일 한 줄.
class LinkedRecordRow {
  final DateTime date;
  final bool isPressure;
  final String name;
  final bool? pass;
  const LinkedRecordRow(this.date, this.isPressure, this.name, this.pass);

  String get kind => isPressure ? '압력시험' : '교정';
  String get verdict => pass == null ? '판정 없음' : (pass! ? '합격' : '불합격');
}

/// [projectId]에 붙인 압력시험·교정 기록, 최근 것부터.
List<LinkedRecordRow> linkedRecordRows(
  String projectId,
  List<PtRecord> pts,
  List<CalRecord> cals,
) {
  if (projectId.isEmpty) return const [];
  final rows = <LinkedRecordRow>[
    for (final r in pts)
      if (r.projectId == projectId)
        LinkedRecordRow(
          r.date,
          true,
          r.line.isEmpty ? '(라인 번호 없음)' : r.line,
          r.verdict.pass,
        ),
    for (final r in cals)
      if (r.projectId == projectId)
        LinkedRecordRow(
          r.date,
          false,
          r.tag.isEmpty ? '(태그 없음)' : r.tag,
          r.finalPass,
        ),
  ]..sort((a, b) => b.date.compareTo(a.date));
  return rows;
}

class LinkedRecordsSection extends StatefulWidget {
  final String projectId;
  final String projectName;

  /// 시험에서 기록 읽기를 바꿔 넣는다.
  final Future<(List<PtRecord>, List<CalRecord>)> Function()? load;

  const LinkedRecordsSection({
    super.key,
    required this.projectId,
    required this.projectName,
    this.load,
  });

  @override
  State<LinkedRecordsSection> createState() => _LinkedRecordsSectionState();
}

class _LinkedRecordsSectionState extends State<LinkedRecordsSection> {
  List<LinkedRecordRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final (pts, cals) =
          await (widget.load ??
              () async =>
                  (await PtRecordStore.load(), await CalRecordStore.load()))();
      if (mounted) {
        setState(() => _rows = linkedRecordRows(widget.projectId, pts, cals));
      }
    } catch (_) {}
  }

  Future<void> _open(bool pressure) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => pressure
            ? PtRecordsPage(
                projectId: widget.projectId,
                projectName: widget.projectName,
              )
            : CalRecordsPage(
                projectId: widget.projectId,
                projectName: widget.projectName,
              ),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_rows.isEmpty) return const SizedBox.shrink();
    final hasPt = _rows.any((r) => r.isPressure);
    final hasCal = _rows.any((r) => !r.isPressure);
    String md(DateTime d) => '${d.month}/${d.day}';
    return Padding(
      key: const Key('linked_records'),
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '압력시험·교정 기록 (${_rows.length})',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          for (final r in _rows.take(4))
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                r.isPressure ? Icons.speed_rounded : Icons.tune_rounded,
                color: AppColors.brand,
              ),
              title: Text(
                '${md(r.date)} ${r.kind} ${r.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              trailing: Text(
                r.verdict,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: r.pass == false
                      ? AppColors.danger
                      : (r.pass == true ? AppColors.ok : AppColors.textSub),
                ),
              ),
              onTap: () => _open(r.isPressure),
            ),
          Wrap(
            spacing: 8,
            children: [
              if (hasPt)
                TextButton(
                  key: const Key('linked_pt_all'),
                  onPressed: () => _open(true),
                  child: const Text('압력시험 기록 모두'),
                ),
              if (hasCal)
                TextButton(
                  key: const Key('linked_cal_all'),
                  onPressed: () => _open(false),
                  child: const Text('교정 기록 모두'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 주간 보고 실적에 넣을 시험·교정 줄(프로젝트 아이디별). 붙이지 않은 기록은 빠진다.
Map<String, List<WeeklyTestLine>> weeklyTestsByProject(
  List<PtRecord> pts,
  List<CalRecord> cals,
) {
  final ids = {
    for (final r in pts) r.projectId,
    for (final r in cals) r.projectId,
  }..remove('');
  return {
    for (final id in ids)
      id: [
        for (final r in linkedRecordRows(id, pts, cals))
          (date: r.date, text: '${r.kind} ${r.name} ${r.verdict}'),
      ],
  };
}

/// 폰에 있는(서버와 맞춘) 기록으로 [weeklyTestsByProject]. 못 읽으면 빈 것.
Future<Map<String, List<WeeklyTestLine>>> loadWeeklyTests() async {
  try {
    return weeklyTestsByProject(
      await PtRecordStore.load(),
      await CalRecordStore.load(),
    );
  } catch (_) {
    return const {};
  }
}
