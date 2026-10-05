// 근태 관리(필드 헬퍼 4번) - 작업 일지와 별개로, 사람 기준으로 날짜별 근태
// (정상근무/연차/월차/반차/반반차/조퇴/특근/결근)와 출퇴근 시간을 기록한다. 어느 프로젝트의
// 일지를 썼는지와 무관하며, 공수(인·일) 통계 쪽에서는 날짜만 맞춰 이 기록을
// 가져다 쓴다(AttendanceCache 참고).
//
// 2026-09-26 점검(docs/근태관리_근거.md): 휴게 뺀 근로시간, 달 합계(연장·야간·휴일·가산 시간),
// 주 52시간 경고, 연차 잔여(입사일 기준), 달력 보기, 현장 메모, PDF·CSV 내보내기를 넣었다.
// 저장·지우기는 서버 응답을 기다리지 않는다(통신 없는 현장에서 창이 멈추던 문제).
import 'package:tubing_calculator/src/core/common_widgets/app_components.dart'
    show AppSnackKind, showAppSnack;
import 'package:tubing_calculator/src/core/common_widgets/swipe_to_delete.dart'
    show showDeleteUndo;
import 'package:tubing_calculator/src/core/utils/home_widget_sync.dart';
import 'package:tubing_calculator/src/core/utils/settings_cloud.dart';
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/attendance.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_phase.dart'
    show dayOnly;

import '../attendance_bulk.dart';
import '../attendance_calc.dart';
import '../attendance_clock.dart';
import '../attendance_export.dart';
import '../attendance_reminder.dart';
import '../attendance_settings.dart';
import '../widgets/attendance_leave_sheet.dart';
import '../widgets/attendance_range_sheet.dart';
import '../widgets/attendance_sheets.dart';
import '../widgets/attendance_year_page.dart';
import '../widgets/attendance_views.dart';

const Color _bg = AppColors.background;
const Color _text = AppColors.text;
const Color _white = Color(0xFFFFFFFF);

/// 위젯·알림에서 열렸을 때 화면이 열리자마자 할 일.
enum AttendanceAutoPunch { none, clockIn, clockOut }

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

  /// PDF 성명에 적을 이름(시험용). 없으면 프로필에 저장된 이름.
  final String? workerName;

  /// 출근·퇴근 단추가 찍을 "지금 시각"(시험용). 없으면 지금 시각(today만 주면 그 날짜의 지금 시·분).
  final DateTime Function()? nowProvider;

  /// 홈 위젯의 [출근]·[퇴근] 단추로 열렸을 때: 읽은 뒤 바로 한 번 찍는다(이미 찍었으면 알리기만).
  final AttendanceAutoPunch autoPunch;

  const AttendancePage({
    super.key,
    this.today,
    this.loadRange,
    this.saveRecord,
    this.deleteRecord,
    this.workerName,
    this.nowProvider,
    this.autoPunch = AttendanceAutoPunch.none,
  });

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  /// 출근·퇴근에 찍을 지금 시각. today를 시험으로 정해 줬으면 그 날짜에 지금의 시·분을 붙인다.
  DateTime _now() {
    final f = widget.nowProvider;
    if (f != null) return f();
    final real = DateTime.now();
    final t = widget.today;
    return t == null
        ? real
        : DateTime(t.year, t.month, t.day, real.hour, real.minute);
  }

  late final DateTime _today = dayOnly(_now());
  late DateTime _viewedMonth = DateTime(_today.year, _today.month);
  Map<String, AttendanceRecord> _records = {};
  AttendanceSettings _settings = const AttendanceSettings();
  bool _loading = true;
  bool _loadFailed = false;
  int _loadSeq = 0;

  // 출근·퇴근 카드가 보는 어제·오늘 기록(보고 있는 달과 따로 읽는다).
  Map<String, AttendanceRecord> _clockRecs = {};
  bool _clockLoaded = false;
  bool _clockFailed = false;

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
    await _loadClock();
    await _runAutoPunch();
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

  Future<void> _loadClock() async {
    // 어제·오늘 기록과, 위젯의 "지난 퇴근" 줄에 쓸 일주일 치.
    final y = DateTime(_today.year, _today.month, _today.day - 7);
    Map<String, AttendanceRecord>? m;
    try {
      m = await _loader(y, _today);
    } catch (_) {
      m = null;
    }
    if (!mounted) return;
    setState(() {
      _clockLoaded = true;
      _clockFailed = m == null;
      if (m != null) _clockRecs = Map.of(m);
    });
    _syncOutside();
  }

  bool _isClockDay(DateTime d) {
    final x = dayOnly(d);
    return x == _today ||
        x == DateTime(_today.year, _today.month, _today.day - 1);
  }

  /// 홈 화면 출퇴근 위젯과 퇴근 알림을 지금 상태에 맞춘다(둘 다 실패해도 화면에는 영향이 없다).
  void _syncOutside() {
    final st = _clockStatus();
    if (st == null) return;
    HomeWidgetSync.push(
      clockJson: encodeClockWidgetPayload(st, _now(), records: _clockRecs),
    );
    syncClockOutReminder(
      enabled: _settings.clockOutReminder,
      workEnd: _settings.workEnd,
      today: _clockRecs[dateKey(_today)],
      now: _now(),
    );
  }

  /// 위젯 단추로 열렸으면 읽은 직후 한 번만 찍는다.
  bool _autoDone = false;
  Future<void> _runAutoPunch() async {
    if (_autoDone || widget.autoPunch == AttendanceAutoPunch.none || !mounted) {
      return;
    }
    _autoDone = true;
    final st = _clockStatus();
    if (st == null) {
      _toast("기록을 읽지 못해 출퇴근을 찍지 못했습니다.");
      return;
    }
    final r = st.record;
    switch (widget.autoPunch) {
      case AttendanceAutoPunch.clockIn:
        if (st.phase == ClockPhase.ready) {
          await _punchIn();
        } else if (st.phase == ClockPhase.off) {
          _toast("오늘은 ${r?.type ?? ''}이라 출근을 찍지 않았습니다.");
        } else {
          _toast("이미 ${r?.checkIn ?? '--:--'}에 출근을 찍었습니다.");
        }
      case AttendanceAutoPunch.clockOut:
        if (st.phase == ClockPhase.working) {
          await _punchOut();
        } else if (st.phase == ClockPhase.done) {
          _toast("이미 ${r?.checkOut ?? '--:--'}에 퇴근을 찍었습니다.");
        } else {
          _toast("출근 기록이 없어 퇴근을 찍지 못했습니다. 오늘 줄에서 출근 시각을 먼저 적어 주십시오.");
        }
      case AttendanceAutoPunch.none:
        break;
    }
  }

  ClockStatus? _clockStatus() {
    if (!_clockLoaded || _clockFailed) return null;
    final y = DateTime(_today.year, _today.month, _today.day - 1);
    return clockStatus(
      now: _now(),
      today: _clockRecs[dateKey(_today)],
      yesterday: _clockRecs[dateKey(y)],
    );
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
        previous: latestRecordBefore({..._clockRecs, ..._records}, day),
      ),
    );
    if (result == null || !mounted) return;
    if (result.delete) {
      final old = _records[key];
      final ok = await (widget.deleteRecord ?? deleteAttendance)(day);
      if (!mounted) return;
      if (!ok) {
        _toast("로그인하지 않아 지우지 못했습니다. 로그인한 뒤 다시 하십시오.");
        return;
      }
      AttendanceCache.byDate.remove(key);
      setState(() {
        _records.remove(key);
        _clockRecs.remove(key);
      });
      if (_isClockDay(day)) _syncOutside();
      // 잘못 눌렀을 때 되살릴 수 있게 "되돌리기"를 띄운다(10-02, 예전엔 바로 사라졌다).
      if (old != null) {
        showDeleteUndo(
          context,
          "${day.month}월 ${day.day}일 근태 기록",
          onUndo: () => _restore(old),
        );
      }
      return;
    }
    await _saveRecord(result.save!);
  }

  /// 기록 하나를 저장하고 화면·캐시를 바로 고친다. 로그인하지 않았으면 알리고 false.
  Future<bool> _saveRecord(AttendanceRecord rec) async {
    final key = dateKey(rec.date);
    final ok = await (widget.saveRecord ?? saveAttendance)(rec);
    if (!mounted) return false;
    if (!ok) {
      _toast("로그인하지 않아 저장하지 못했습니다. 로그인한 뒤 다시 저장하십시오.");
      return false;
    }
    // 통계 화면(project_stats_page 등)이 새로고침 없이 바로 반영하도록 캐시도 고친다.
    AttendanceCache.byDate[key] = rec.type;
    setState(() {
      _records[key] = rec;
      _clockRecs[key] = rec;
    });
    if (_isClockDay(rec.date)) _syncOutside();
    return true;
  }

  /// 기록 하나를 지우고 화면·캐시를 바로 고친다(되돌리기용). 못 지우면 false.
  Future<bool> _removeRecord(DateTime day) async {
    final key = dateKey(day);
    final ok = await (widget.deleteRecord ?? deleteAttendance)(day);
    if (!mounted || !ok) return false;
    AttendanceCache.byDate.remove(key);
    setState(() {
      _records.remove(key);
      _clockRecs.remove(key);
    });
    if (_isClockDay(day)) _syncOutside();
    return true;
  }

  /// 출근·퇴근 한 번 더 누른 것을 되돌린다: 전 기록이 없었으면 지우고, 있었으면 그대로 다시 저장.
  Future<void> _undoTo(DateTime day, AttendanceRecord? old) async {
    if (old == null) {
      await _removeRecord(day);
    } else {
      await _saveRecord(old);
    }
  }

  /// [출근]: 지금 시각으로 오늘 기록의 출근을 채운다.
  Future<void> _punchIn() async {
    final now = _now();
    final day = dayOnly(now);
    final old = _clockRecs[dateKey(day)];
    final rec = punchIn(day, old, now);
    HapticFeedback.mediumImpact();
    if (!await _saveRecord(rec) || !mounted) return;
    showAppSnack(
      context,
      "출근 ${rec.checkIn} 저장했습니다.",
      kind: AppSnackKind.undo,
      onUndo: () => _undoTo(day, old),
    );
  }

  /// [퇴근]: 지금 시각으로 퇴근을 채운다(밤샘이면 어제 기록에).
  Future<void> _punchOut() async {
    final st = _clockStatus();
    final cur = st?.record;
    if (st == null || st.phase != ClockPhase.working || cur == null) return;
    final rec = punchOut(cur, _now());
    if (rec == null) {
      _toast("방금 출근하셨습니다. 1분 뒤에 퇴근을 눌러 주십시오.");
      return;
    }
    HapticFeedback.mediumImpact();
    if (!await _saveRecord(rec) || !mounted) return;
    final w = computeDay(rec, _settings.calcOptions);
    final bits = <String>[
      if (w != null) "근로 ${formatMinutes(w.work)}",
      if (w != null && w.dailyOver > 0) "연장 ${formatMinutes(w.dailyOver)}",
    ];
    showAppSnack(
      context,
      "퇴근 ${rec.checkOut} 저장했습니다${bits.isEmpty ? '' : ' · ${bits.join(' · ')}'}",
      kind: AppSnackKind.undo,
      onUndo: () => _undoTo(st.day, cur),
    );
  }

  /// 여러 날 한 번에 기록. 이미 적은 날은 범위를 서버(폰 사본)에서 읽어 가리고, 끝난 뒤 되돌리기를 준다.
  Future<void> _openRange() async {
    HapticFeedback.selectionClick();
    final r = await showModalBottomSheet<AttendanceRangeResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          AttendanceRangeSheet(today: _today, options: _settings.calcOptions),
    );
    if (r == null || !mounted) return;
    Map<String, AttendanceRecord>? existing;
    try {
      existing = await _loader(r.from, r.to);
    } catch (_) {
      existing = null;
    }
    if (!mounted) return;
    if (existing == null) {
      _toast("이미 적은 기록을 읽지 못해 저장하지 않았습니다. 잠시 뒤 다시 하십시오.");
      return;
    }
    final plan = planBulk(
      from: r.from,
      to: r.to,
      skipOff: r.skipOff,
      overwrite: r.overwrite,
      existingKeys: existing.keys.toSet(),
    );
    if (plan.days.isEmpty) {
      _toast("기록할 날이 없습니다. 이미 적은 날은 그대로 둡니다.");
      return;
    }
    final olds = <DateTime, AttendanceRecord?>{};
    for (final day in plan.days) {
      final ok = await _saveRecord(bulkRecord(day, r.template));
      if (!ok) break; // 안내는 _saveRecord가 했다
      olds[day] = existing[dateKey(day)];
    }
    if (!mounted || olds.isEmpty) return;
    final kept = plan.skippedExisting.length;
    showAppSnack(
      context,
      "${olds.length}일 기록했습니다${kept > 0 ? ' (이미 적은 $kept일은 그대로)' : ''}",
      kind: AppSnackKind.undo,
      onUndo: () async {
        for (final e in olds.entries) {
          await _undoTo(e.key, e.value);
        }
      },
    );
  }

  /// 지운 근태 기록을 같은 날짜·같은 내용으로 다시 저장한다.
  Future<void> _restore(AttendanceRecord old) async {
    final ok = await (widget.saveRecord ?? saveAttendance)(old);
    if (!mounted) return;
    if (!ok) {
      _toast("로그인하지 않아 되돌리지 못했습니다. 로그인한 뒤 다시 하십시오.");
      return;
    }
    final key = dateKey(old.date);
    AttendanceCache.byDate[key] = old.type;
    setState(() => _records[key] = old);
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

  Future<void> _openRules() async {
    var openSettings = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => AttendanceRulesSheet(
        settings: _settings,
        onOpenSettings: () {
          openSettings = true;
          Navigator.pop(ctx);
        },
      ),
    );
    if (openSettings && mounted) await _openSettings();
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
    // 계산기 설정과 같은 서버 문서에 올린다(구글 로그인이 없거나 통신이 없으면 조용히 건너뛴다).
    SettingsCloudSync.instance.backup();
    _syncOutside();
  }

  void _openYear() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttendanceYearPage(
          year: _viewedMonth.year,
          options: _settings.calcOptions,
          hourlyWage: _settings.hourlyWage,
          loader: _loader,
        ),
      ),
    );
  }

  Future<void> _openLeaveHistory() async {
    final b = _leave();
    if (b == null) return;
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AttendanceLeaveSheet(
        balance: b,
        types: AttendanceCache.byDate,
        today: _today,
      ),
    );
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
        // PDF 머리의 성명 자리에 내 이름을 적는다(프로필에 저장된 이름).
        final String? name =
            widget.workerName ??
            (await SharedPreferences.getInstance()).getString('user_real_name');
        if (!mounted) return;
        await openAttendanceMonthPdf(
          context,
          month: _viewedMonth,
          records: _records,
          options: _settings.calcOptions,
          leave: _leave(),
          workerName: name,
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
          key: const Key('att_range'),
          tooltip: "여러 날 한 번에 기록",
          onPressed: _openRange,
          icon: const Icon(Icons.edit_calendar_outlined),
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
    final clock = _clockStatus();
    // 지금 근무 중인 날(밤샘이면 어제)은 "퇴근 입력 필요"에서 뺀다.
    final DateTime? workingDay = clock?.phase == ClockPhase.working
        ? clock!.day
        : null;
    final missing = missingCheckOutCount(
      {
        for (final e in _records.entries)
          if (e.value.date.year == _viewedMonth.year &&
              e.value.date.month == _viewedMonth.month)
            e.key: e.value,
      },
      _today,
      skip: workingDay,
    );

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
            key: const Key('att_rules'),
            tooltip: "사규 보기",
            onPressed: _openRules,
            icon: const Icon(Icons.menu_book_outlined),
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
          AttendanceClockCard(
            status: clock,
            loadFailed: _clockFailed,
            today: _today,
            onPunchIn: _punchIn,
            onPunchOut: _punchOut,
            onEdit: () => _openDay(_today),
            onRetry: () {
              setState(() => _clockFailed = false);
              _loadClock();
            },
          ),
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
                                  onPressed: () {
                                    _load();
                                    if (_clockFailed) {
                                      setState(() => _clockFailed = false);
                                      _loadClock();
                                    }
                                  },
                                  child: const Text("다시 읽기"),
                                ),
                              ],
                            ),
                          ),
                        AttendanceSummaryCard(
                          month: _viewedMonth,
                          summary: summary,
                          settings: _settings,
                          missingCheckOut: missing,
                          onOpenYear: _openYear,
                        ),
                        AttendanceLeaveCard(
                          balance: _leave(),
                          hasHireDate: _settings.hireDate != null,
                          onOpenSettings: _openSettings,
                          onOpenHistory: _leave() == null
                              ? null
                              : _openLeaveHistory,
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
                                  missingCheckOut:
                                      isMissingCheckOut(
                                        _records[key],
                                        _today,
                                      ) &&
                                      (workingDay == null ||
                                          dayOnly(workingDay) != dayOnly(day)),
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
