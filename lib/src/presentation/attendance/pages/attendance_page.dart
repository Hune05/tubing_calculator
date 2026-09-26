// 근태 관리(필드 헬퍼 4번) - 작업 일지와 별개로, 사람 기준으로 날짜별 근태
// (정상근무/연차/월차/반차/반반차/조퇴/특근/결근)와 출퇴근 시간을 기록한다. 어느 프로젝트의
// 일지를 썼는지와 무관하며, 공수(인·일) 통계 쪽에서는 날짜만 맞춰 이 기록을
// 가져다 쓴다(AttendanceCache 참고).
//
// 2026-09-26 점검(docs/근태관리_근거.md): 휴게 뺀 근로시간, 달 합계(연장·야간·휴일·가산 시간),
// 주 52시간 경고, 연차 잔여(입사일 기준), 달력 보기, 현장 메모, PDF·CSV 내보내기를 넣었다.
// 저장·지우기는 서버 응답을 기다리지 않는다(통신 없는 현장에서 창이 멈추던 문제).
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/attendance.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_phase.dart'
    show dayOnly;

import '../attendance_calc.dart';
import '../attendance_export.dart';
import '../attendance_settings.dart';
import '../widgets/attendance_sheets.dart';
import '../widgets/attendance_views.dart';

const Color _bg = AppColors.background;
const Color _text = AppColors.text;
const Color _white = Color(0xFFFFFFFF);

typedef AttendanceRangeLoader =
    Future<Map<String, AttendanceRecord>?> Function(DateTime from, DateTime to);
typedef AttendanceSaver = Future<bool> Function(AttendanceRecord r);
typedef AttendanceDeleter = Future<bool> Function(DateTime day);

class AttendancePage extends StatefulWidget {
  /// 오늘 날짜(시험용). 없으면 지금 날짜.
  final DateTime? today;

  /// 기록 읽기·저장·지우기(시험용). 없으면 서버(attendance.dart).
  final AttendanceRangeLoader? loadRange;
  final AttendanceSaver? saveRecord;
  final AttendanceDeleter? deleteRecord;

  const AttendancePage({
    super.key,
    this.today,
    this.loadRange,
    this.saveRecord,
    this.deleteRecord,
  });

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late final DateTime _today = dayOnly(widget.today ?? DateTime.now());
  late DateTime _viewedMonth = DateTime(_today.year, _today.month);
  Map<String, AttendanceRecord> _records = {};
  AttendanceSettings _settings = const AttendanceSettings();
  bool _loading = true;
  bool _loadFailed = false;
  int _loadSeq = 0;

  // 이번 달을 열면 오늘 줄로 옮긴다(1일부터 보이면 월말엔 한참 내려야 한다).
  // 근태를 고친 뒤 다시 그릴 때는 옮기지 않는다.
  final _todayKey = GlobalKey();
  bool _scrollToToday = true;

  AttendanceRangeLoader get _loader => widget.loadRange ?? loadAttendanceRange;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final s = await AttendanceSettings.load();
    if (!mounted) return;
    setState(() => _settings = s);
    await _load();
    // 연차 잔여는 모든 날의 근태 종류(AttendanceCache)로 계산한다.
    if (widget.loadRange == null) {
      await AttendanceCache.refresh();
      if (mounted) setState(() {});
    }
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    setState(() => _loading = true);
    final first = DateTime(_viewedMonth.year, _viewedMonth.month, 1);
    final last = DateTime(_viewedMonth.year, _viewedMonth.month + 1, 0);
    // 첫 주 월요일~마지막 주 일요일(주 40시간·52시간을 정확히 세려고).
    final from = mondayOf(first);
    final to = DateTime(last.year, last.month, last.day + (7 - last.weekday));
    Map<String, AttendanceRecord>? m;
    try {
      m = await _loader(from, to);
    } catch (_) {
      m = null;
    }
    if (!mounted || seq != _loadSeq) return;
    setState(() {
      _records = m ?? {};
      _loadFailed = m == null;
      _loading = false;
    });
    if (_scrollToToday && !_settings.calendarView) {
      _scrollToToday = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _todayKey.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.3);
      });
    }
  }

  void _changeMonth(int delta) {
    setState(
      () => _viewedMonth = DateTime(
        _viewedMonth.year,
        _viewedMonth.month + delta,
      ),
    );
    _scrollToToday = true;
    _load();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openDay(DateTime day) async {
    HapticFeedback.selectionClick();
    final key = dateKey(day);
    final result = await showModalBottomSheet<AttendanceSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AttendanceEditSheet(
        day: day,
        existing: _records[key],
        options: _settings.calcOptions,
      ),
    );
    if (result == null || !mounted) return;
    if (result.delete) {
      final ok = await (widget.deleteRecord ?? deleteAttendance)(day);
      if (!mounted) return;
      if (!ok) {
        _toast("로그인하지 않아 지우지 못했습니다. 로그인한 뒤 다시 하십시오.");
        return;
      }
      AttendanceCache.byDate.remove(key);
      setState(() => _records.remove(key));
      return;
    }
    final rec = result.save!;
    final ok = await (widget.saveRecord ?? saveAttendance)(rec);
    if (!mounted) return;
    if (!ok) {
      _toast("로그인하지 않아 저장하지 못했습니다. 로그인한 뒤 다시 저장하십시오.");
      return;
    }
    // 통계 화면(project_stats_page 등)이 새로고침 없이 바로 반영하도록 캐시도 고친다.
    AttendanceCache.byDate[key] = rec.type;
    setState(() => _records[key] = rec);
  }

  LeaveBalance? _leave() {
    final h = _settings.hireDate;
    if (h == null) return null;
    return computeLeaveBalance(
      hire: h,
      today: _today,
      types: AttendanceCache.byDate,
      overrides: _settings.leaveOverrides,
    );
  }

  Future<void> _openSettings() async {
    final s = await showModalBottomSheet<AttendanceSettings>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AttendanceSettingsSheet(
        settings: _settings,
        today: _today,
        balance: _leave(),
      ),
    );
    if (s == null || !mounted) return;
    setState(() => _settings = s);
    await s.save();
  }

  Future<void> _toggleView() async {
    final s = _settings.copyWith(calendarView: !_settings.calendarView);
    setState(() => _settings = s);
    await s.save();
  }

  Future<void> _openExport() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "${_viewedMonth.year}년 ${_viewedMonth.month}월 근태 내보내기",
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            ListTile(
              key: const Key('att_export_pdf'),
              leading: const Icon(AppIcons.pdf),
              title: const Text("PDF 미리보기"),
              subtitle: const Text("한 달 기록표와 합계. 미리 본 뒤 공유합니다."),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
            ListTile(
              key: const Key('att_export_csv'),
              leading: const Icon(AppIcons.download),
              title: const Text("CSV 파일"),
              subtitle: const Text("엑셀에서 여는 표. 시간은 소수(8.5)로 적습니다."),
              onTap: () => Navigator.pop(ctx, 'csv'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'pdf') {
      try {
        await openAttendanceMonthPdf(
          context,
          month: _viewedMonth,
          records: _records,
          options: _settings.calcOptions,
          leave: _leave(),
        );
      } catch (_) {
        _toast("PDF를 만들지 못했습니다.");
      }
    } else {
      final ok = await shareAttendanceMonthCsv(
        month: _viewedMonth,
        records: _records,
        options: _settings.calcOptions,
      );
      if (!ok) _toast("CSV 파일을 만들지 못했습니다.");
    }
  }

  Widget _monthBar() => Container(
    color: _white,
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Row(
      children: [
        IconButton(
          key: const Key('att_prev_month'),
          tooltip: "이전 달",
          onPressed: () => _changeMonth(-1),
          icon: const Icon(AppIcons.back),
        ),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "${_viewedMonth.year}년 ${_viewedMonth.month}월",
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: _text,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          key: const Key('att_next_month'),
          tooltip: "다음 달",
          onPressed: () => _changeMonth(1),
          icon: const Icon(AppIcons.forward),
        ),
        IconButton(
          key: const Key('att_view_toggle'),
          tooltip: _settings.calendarView ? "목록으로 보기" : "달력으로 보기",
          onPressed: _toggleView,
          icon: Icon(
            _settings.calendarView ? AppIcons.list : AppIcons.calendar,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final opts = _settings.calcOptions;
    final summary = summarizeMonth(_records, _viewedMonth, opts);
    final daysInMonth = DateTime(
      _viewedMonth.year,
      _viewedMonth.month + 1,
      0,
    ).day;
    final works = <String, DayWork?>{
      for (final e in _records.entries) e.key: computeDay(e.value, opts),
    };

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _white,
        foregroundColor: _text,
        elevation: 0,
        title: const Text(
          "근태 관리",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            key: const Key('att_export'),
            tooltip: "내보내기",
            onPressed: _loading ? null : _openExport,
            icon: const Icon(AppIcons.share),
          ),
          IconButton(
            key: const Key('att_settings'),
            tooltip: "근태 설정",
            onPressed: _openSettings,
            icon: const Icon(AppIcons.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          _monthBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                // 한 달이 많아야 31줄이라 한꺼번에 그린다. 그래야 오늘 줄로
                // 옮길 수 있다(ListView.builder는 안 보이는 줄을 만들지 않는다).
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    child: Column(
                      children: [
                        if (_loadFailed)
                          Container(
                            key: const Key('att_load_failed'),
                            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    "기록을 읽지 못했습니다. 이 달이 비어 보여도 기록이 지워진 것은 아닙니다.",
                                    style: TextStyle(
                                      color: AppColors.danger,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _load,
                                  child: const Text("다시 읽기"),
                                ),
                              ],
                            ),
                          ),
                        AttendanceSummaryCard(
                          month: _viewedMonth,
                          summary: summary,
                          settings: _settings,
                        ),
                        AttendanceLeaveCard(
                          balance: _leave(),
                          hasHireDate: _settings.hireDate != null,
                          onOpenSettings: _openSettings,
                        ),
                        if (_settings.calendarView)
                          AttendanceMonthCalendar(
                            month: _viewedMonth,
                            today: _today,
                            records: _records,
                            works: works,
                            options: opts,
                            onTapDay: _openDay,
                          )
                        else
                          for (var i = 0; i < daysInMonth; i++)
                            Builder(
                              builder: (_) {
                                final day = DateTime(
                                  _viewedMonth.year,
                                  _viewedMonth.month,
                                  i + 1,
                                );
                                final key = dateKey(day);
                                final isToday = dayOnly(day) == _today;
                                return AttendanceDayRow(
                                  key: isToday ? _todayKey : null,
                                  day: day,
                                  record: _records[key],
                                  work: works[key],
                                  isToday: isToday,
                                  isRest: isRestDay(day, opts),
                                  onTap: () => _openDay(day),
                                );
                              },
                            ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
