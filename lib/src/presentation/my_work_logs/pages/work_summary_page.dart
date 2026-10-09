// 하루·한 주 정리 화면(10-09 고도화 4번): 근태, 작업 일지, 안전 점검, 압력시험, 교정을 한 장으로 보고
// 글(카톡)이나 PDF로 보낸다. "내 프로젝트" 오른쪽 위 더보기 → "하루·한 주 정리".
import 'package:tubing_calculator/src/core/common_widgets/snack_once.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_icon_set.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/error_text.dart';
import '../../instrument/cal_record.dart';
import '../../pressure_test/test_record.dart';
import '../../safety/safety_check_model.dart';
import '../models/attendance.dart';
import '../models/report_tools.dart';
import '../models/work_summary.dart';

/// 화면에서 읽는 기록 묶음(시험에서 바꿔 넣는다).
typedef WorkSummarySources = ({
  Map<String, AttendanceRecord>? attendance,
  List<SafetyRecord> safety,
  List<PtRecord> pts,
  List<CalRecord> cals,
});

/// 폰에 있는 기록과 서버 근태를 읽는다. 근태를 못 읽으면 attendance가 null.
Future<WorkSummarySources> loadWorkSummarySources(SummaryRange r) async {
  Map<String, AttendanceRecord>? att;
  try {
    att = await loadAttendanceRange(r.from, r.to);
  } catch (_) {
    att = null;
  }
  Future<List<T>> safe<T>(Future<List<T>> Function() f) async {
    try {
      return await f();
    } catch (_) {
      return <T>[];
    }
  }

  return (
    attendance: att,
    safety: await safe(loadSafetyRecords),
    pts: await safe(PtRecordStore.load),
    cals: await safe(CalRecordStore.load),
  );
}

class WorkSummaryPage extends StatefulWidget {
  /// 작업 일지가 든 프로젝트 목록("내 프로젝트" 화면이 가진 것).
  final List<Map<String, dynamic>> logs;
  final DateTime Function()? now;

  /// 시험에서 읽기·보내기를 바꿔 넣는다.
  final Future<WorkSummarySources> Function(SummaryRange r)? load;
  final Future<void> Function(ReportDoc doc)? shareText;
  final Future<void> Function(ReportDoc doc)? sharePdf;

  const WorkSummaryPage({
    super.key,
    required this.logs,
    this.now,
    this.load,
    this.shareText,
    this.sharePdf,
  });

  @override
  State<WorkSummaryPage> createState() => _WorkSummaryPageState();
}

class _WorkSummaryPageState extends State<WorkSummaryPage> {
  late SummaryRange _range;
  ReportDoc? _doc;
  bool _busy = false;
  int _loadSeq = 0;

  DateTime get _today => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _range = SummaryRange.day(_today);
    _reload();
  }

  Future<void> _reload() async {
    final seq = ++_loadSeq;
    final r = _range;
    final src = await (widget.load ?? loadWorkSummarySources)(r);
    if (!mounted || seq != _loadSeq) return; // 그사이 날짜를 또 바꿨다
    setState(() {
      _doc = buildWorkSummaryDoc(
        range: r,
        attendance: src.attendance,
        logs: widget.logs,
        safety: src.safety,
        pts: src.pts,
        cals: src.cals,
      );
    });
  }

  void _set(SummaryRange r) {
    setState(() {
      _range = r;
      _doc = null;
    });
    _reload();
  }

  Future<void> _send(bool pdf) async {
    final doc = _doc;
    if (doc == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (pdf) {
        await (widget.sharePdf ?? (d) => shareReportPdf(d))(doc);
      } else {
        await (widget.shareText ?? shareReportText)(doc);
      }
    } catch (e) {
      if (mounted) {
        showSnackOnce(ScaffoldMessenger.of(context),
          SnackBar(
            content: Text(failText(pdf ? "PDF를 만들지 못했습니다" : "보내지 못했습니다", e)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    final isToday = _range.contains(_today);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          '하루·한 주 정리',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            key: const Key('ws_share'),
            tooltip: '글로 보내기',
            icon: const Icon(AppIcons.share),
            onPressed: doc == null || _busy ? null : () => _send(false),
          ),
          IconButton(
            key: const Key('ws_pdf'),
            tooltip: 'PDF로 보내기',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: doc == null || _busy ? null : () => _send(true),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('하루', key: Key('ws_day'))),
              ButtonSegment(
                value: false,
                label: Text('한 주', key: Key('ws_week')),
              ),
            ],
            selected: {_range.isDay},
            showSelectedIcon: false,
            onSelectionChanged: (s) => _set(
              s.first
                  ? SummaryRange.day(_range.isDay ? _range.from : _today)
                  : SummaryRange.week(_range.from),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                key: const Key('ws_prev'),
                tooltip: _range.isDay ? '전날' : '전주',
                icon: const Icon(AppIcons.back),
                onPressed: () => _set(_range.shift(-1)),
              ),
              Expanded(
                child: Text(
                  _range.label,
                  key: const Key('ws_label'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
              IconButton(
                key: const Key('ws_next'),
                tooltip: _range.isDay ? '다음 날' : '다음 주',
                icon: const Icon(AppIcons.forward),
                onPressed: () => _set(_range.shift(1)),
              ),
            ],
          ),
          if (!isToday)
            Center(
              child: TextButton(
                key: const Key('ws_today'),
                onPressed: () => _set(
                  _range.isDay
                      ? SummaryRange.day(_today)
                      : SummaryRange.week(_today),
                ),
                child: Text(_range.isDay ? '오늘로' : '이번 주로'),
              ),
            ),
          const SizedBox(height: 6),
          if (doc == null)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            for (final s in doc.sections) _section(s),
          const SizedBox(height: 8),
          const Text(
            '근태는 서버에서, 안전 점검·압력시험·교정은 이 폰에 저장된 기록에서 읽습니다.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSub,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(ReportSection s) => Container(
    key: Key('ws_section_${s.heading}'),
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.medium),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.heading,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 6),
        for (final l in s.lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              l.trimLeft(),
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: l.contains('불합격')
                    ? AppColors.danger
                    : (l.trim() == '· 없음' ? AppColors.textSub : AppColors.text),
                fontWeight: l.contains('불합격')
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
      ],
    ),
  );
}
