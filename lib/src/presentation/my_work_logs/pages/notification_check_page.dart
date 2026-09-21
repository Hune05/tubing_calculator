import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/report_tools.dart';
import '../../my_schedule/korean_holidays.dart' show holidayTableNotice;
import '../../my_schedule/schedule_reminders.dart';
import '../widgets/korean_text.dart';

const Color _teal = Color(0xFF007580);
const Color _text = Color(0xFF191F28);
const Color _sub = Color(0xFF8B95A1);
const Color _bg = Color(0xFFF2F4F6);
const String _pkg = 'com.example.tubing_calculator';

// 🚀 [알림 점검] 예약 알림(작업 일지/주간 보고)이 안 올 때 원인을 찾는 화면.
// 알림 권한 확인, 즉시 테스트 알림, 배터리 제한 해제 안내를 한 곳에 모았다.
// 이 화면에서 "안내 카드 미리 보기"를 누르면 이 값을 돌려주며 닫힌다.
const String kPreviewProblem = 'preview_problem';

class NotificationCheckPage extends StatefulWidget {
  // 프로젝트별 알림 시간을 보여 주려면 프로젝트 목록을 넘긴다(없으면 목록 없이 상태만).
  final List<Map<String, dynamic>> logs;
  // 프로젝트별 알림 시간을 바꿔 저장하고 알림을 다시 맞추는 함수(없으면 바꾸기 기능은 숨김).
  final Future<void> Function(Map<String, dynamic> log)? onSaveProject;
  // 폰에 예약된 알림 아이디를 읽는 함수(테스트에서 바꿔 끼운다). 기본은 실제 폰 조회.
  final Future<Set<int>> Function()? pendingIdsLoader;
  // 어긋난 작업 일지 알림 한 건 / 주간 알림만 다시 예약하는 함수(테스트에서 바꿔 끼운다).
  final Future<void> Function(ReminderSlot slot)? rescheduleSlot;
  final Future<void> Function()? rescheduleWeekly;
  // 알림창에 떠 있는 알림을 기록하는 함수(테스트에서 바꿔 끼운다).
  final Future<void> Function()? recordActive;
  // 정확한 알람 허용 여부 조회·요청, 1분 뒤 예약 테스트(테스트에서 바꿔 끼운다).
  final Future<bool> Function()? exactChecker;
  final Future<bool> Function()? exactRequester;
  final Future<DateTime> Function()? scheduleTest;
  // 개인 일정 알림 상태 조회·다시 예약(테스트에서 바꿔 끼운다).
  final Future<({int expected, int scheduled})?> Function()?
  personalStatusLoader;
  final Future<int> Function()? personalRescheduler;
  // 공휴일 표 안내를 볼 "지금"(테스트에서 바꿔 끼운다).
  final DateTime? nowForTest;
  const NotificationCheckPage({
    super.key,
    this.logs = const [],
    this.onSaveProject,
    this.pendingIdsLoader,
    this.rescheduleSlot,
    this.rescheduleWeekly,
    this.recordActive,
    this.exactChecker,
    this.exactRequester,
    this.scheduleTest,
    this.personalStatusLoader,
    this.personalRescheduler,
    this.nowForTest,
  });

  @override
  State<NotificationCheckPage> createState() => _NotificationCheckPageState();
}

class _NotificationCheckPageState extends State<NotificationCheckPage>
    with WidgetsBindingObserver {
  bool? _allowed;
  bool _exact = false; // 정확한 시간 알림(정확한 알람) 허용 여부
  ({bool enabled, int minutes})? _morning; // 아침 요약 알림 설정
  ({int expected, int scheduled})? _personal; // 개인 일정 알림 예약 상태(모르면 null)
  ({bool daily, bool weekly})? _sched;
  int? _dailyCount; // 폰에 실제 예약된 작업 일지 알림 수(모르면 null)
  List<String> _seen = const []; // 최근 확인된 알림 기록
  List<String> _seenRaw = const []; // 기록 원본(오늘 알림 확인 여부 판단용)
  String? _lastSync; // 알림을 마지막으로 예약한 기록
  Set<int>? _pendingIds; // 폰에 예약된 알림 아이디들(모르면 null)
  ({bool enabled, int minutes, bool weekly, int weeklyMinutes, bool autoPdf})?
  _pref;
  String? _msg;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    // 이 화면을 한 번 열어 봤으면 메인 화면의 안내 카드는 더 안 띄운다.
    SharedPreferences.getInstance().then(
      (p) => p.setBool('notif_check_seen', true),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 설정 화면에 다녀오면 상태를 다시 읽는다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    bool ok = true;
    try {
      ok = await areNotificationsAllowed();
    } catch (_) {}
    ({bool daily, bool weekly})? sched;
    int? count;
    Set<int>? pendingIds;
    try {
      sched = await scheduledReminderStatus();
      count = await scheduledDailyReminderCount();
    } catch (_) {}
    try {
      pendingIds = await (widget.pendingIdsLoader ?? pendingReminderIds)();
    } catch (_) {}
    final pref = await loadReportReminder();
    final exact = await (widget.exactChecker ?? canScheduleExactAlarms)();
    final morning = await loadMorningSummary();
    ({int expected, int scheduled})? personal;
    try {
      personal =
          await (widget.personalStatusLoader ?? personalReminderStatus)();
    } catch (_) {}
    List<String> seen = const [];
    List<String> seenRaw = const [];
    String? lastSync;
    try {
      lastSync = await loadLastSyncLabel();
    } catch (_) {}
    try {
      await (widget.recordActive ?? recordActiveReminders)();
      seen = await loadSeenReminderLabels();
      seenRaw = await loadSeenReminderRaw();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _exact = exact;
        _morning = morning;
        _personal = personal;
        _seen = seen;
        _seenRaw = seenRaw;
        _lastSync = lastSync;
        _allowed = ok;
        _sched = sched;
        _dailyCount = count;
        _pendingIds = pendingIds;
        _pref = pref;
      });
    }
  }

  String _hm(int m) =>
      "${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}";

  List<Map<String, dynamic>> get _activeLogs =>
      widget.logs.where((l) => l['status'] != 'DONE').toList();

  // 프로젝트 하나의 알림 시간을 고른다(취소하면 그대로, 기본 시간 쓰기도 가능).
  Future<void> _changeProjectTime(Map<String, dynamic> l) async {
    final pref = _pref;
    if (pref == null || widget.onSaveProject == null) return;
    final cur = (l['reportReminderMinutes'] as num?)?.toInt();
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (cur ?? pref.minutes) ~/ 60,
        minute: (cur ?? pref.minutes) % 60,
      ),
    );
    if (t == null) return;
    l['reportReminderMinutes'] = t.hour * 60 + t.minute;
    await widget.onSaveProject!(l);
    await _refresh();
  }

  Future<void> _useDefaultTime(Map<String, dynamic> l) async {
    l.remove('reportReminderMinutes');
    await widget.onSaveProject!(l);
    await _refresh();
  }

  // 필요한 예약 수와 실제 예약 수를 맞춰 보고, 다르면 다시 예약하는 버튼을 보여 준다.
  List<Widget> _countCheck() {
    final pref = _pref;
    final actual = _dailyCount;
    if (pref == null || !pref.enabled || actual == null) return const [];
    final active = _activeLogs;
    if (active.isEmpty) return const [];
    final expected = planDailyReminders(
      active,
      pref.minutes,
      DateTime.now(),
    ).length;
    final msg = reminderCountMismatch(expected, actual);
    if (msg == null) {
      return [
        Padding(
          padding: const EdgeInsets.only(left: 26, bottom: 6),
          child: Text(
            keepWords("프로젝트 ${active.length}곳 → 알림 $expected개, 예약과 같습니다."),
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF1B9E5A),
            ),
          ),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.only(left: 26, bottom: 4),
        child: Text(
          msg,
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: Color(0xFFE5484D),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(left: 26, bottom: 6),
        child: OutlinedButton(
          onPressed: () async {
            await syncReportReminder(widget.logs);
            await _refresh();
          },
          child: const Text("다시 예약"),
        ),
      ),
    ];
  }

  // 오늘 울렸어야 하는데 확인 기록이 없는 알림이 있으면 알려 준다(붉은 오류가 아니라 참고용).
  List<Widget> _unconfirmedNotice(List<ReminderSlot> slots) {
    final miss = unconfirmedToday(slots, _seenRaw, DateTime.now());
    if (miss.isEmpty) return const [];
    final times = miss.map((s) => _hm(s.plan.minutes)).join(', ');
    return [
      Padding(
        padding: const EdgeInsets.only(left: 26, top: 2, bottom: 6),
        child: Text(
          keepWords(
            "오늘 $times 알림이 아직 확인되지 않았습니다. 알림을 밀어서 지웠다면 정상입니다. "
            "그렇지 않은데 알림이 안 왔다면 아래 5번(배터리 제한)을 확인하십시오.",
          ),
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: Color(0xFFB54708),
          ),
        ),
      ),
    ];
  }

  // 알림 한 건의 상태 줄. 폰에 예약돼 있지 않으면 빨갛게 표시하고 그 건만 다시 예약할 수 있다.
  Widget _slotRow(ReminderSlot s) {
    final ok = s.scheduled;
    return Padding(
      padding: const EdgeInsets.only(left: 26, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              keepWords("· ${_hm(s.plan.minutes)}  ${s.plan.names.join(', ')}"),
              style: const TextStyle(fontSize: 12, height: 1.4, color: _text),
            ),
          ),
          Text(
            ok ? "예약됨" : "예약 안 됨",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ok ? const Color(0xFF1B9E5A) : const Color(0xFFE5484D),
            ),
          ),
          if (!ok)
            TextButton(
              onPressed: () => _rescheduleOne(s),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text("다시 예약"),
            ),
        ],
      ),
    );
  }

  Future<void> _rescheduleOne(ReminderSlot s) async {
    try {
      await (widget.rescheduleSlot ?? rescheduleDailySlot)(s);
      if (mounted) {
        setState(() => _msg = "${_hm(s.plan.minutes)} 알림을 다시 예약했습니다.");
      }
    } catch (e) {
      if (mounted) setState(() => _msg = "다시 예약하지 못했습니다: $e");
    }
    await _refresh();
  }

  Future<void> _rescheduleWeeklyOne() async {
    try {
      await (widget.rescheduleWeekly ??
          () => rescheduleWeeklyOnly(widget.logs))();
      if (mounted) setState(() => _msg = "주간 보고 알림을 다시 예약했습니다.");
    } catch (e) {
      if (mounted) setState(() => _msg = "다시 예약하지 못했습니다: $e");
    }
    await _refresh();
  }

  // 작업 일지 알림이 켜져 있으면, 어느 시간에 어느 프로젝트 알림이 가는지 보여 준다.
  List<Widget> _projectTimeRows() {
    final pref = _pref;
    if (pref == null || !pref.enabled || widget.logs.isEmpty) return const [];
    final active = widget.logs.where((l) => l['status'] != 'DONE').toList();
    final plans = planDailyReminders(active, pref.minutes, DateTime.now());
    if (plans.isEmpty) return const [];
    final pending = _pendingIds;
    final slots = pending == null
        ? null
        : dailyReminderSlots(active, pref.minutes, DateTime.now(), pending);
    return [
      ..._countCheck(),
      if (slots != null) ...[
        for (final s in slots) _slotRow(s),
        ..._unconfirmedNotice(slots),
      ] else
        for (final p in plans)
          Padding(
            padding: const EdgeInsets.only(left: 26, bottom: 4),
            child: Text(
              "· ${_hm(p.minutes)}  ${p.names.join(', ')}",
              style: const TextStyle(fontSize: 12, height: 1.4, color: _text),
            ),
          ),
      if (widget.onSaveProject != null)
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.only(left: 26),
            childrenPadding: const EdgeInsets.only(left: 26),
            dense: true,
            title: const Text(
              "프로젝트별 시간 바꾸기",
              style: TextStyle(fontSize: 12, color: _teal),
            ),
            children: [
              for (final l in _activeLogs)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "${l['name'] ?? '프로젝트'}  ${_hm((l['reportReminderMinutes'] as num?)?.toInt() ?? pref.minutes)}"
                        "${l['reportReminderMinutes'] == null ? ' (기본)' : ''}",
                        style: const TextStyle(fontSize: 12, color: _text),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _changeProjectTime(l),
                      child: const Text("시간"),
                    ),
                    if (l['reportReminderMinutes'] != null)
                      TextButton(
                        onPressed: () => _useDefaultTime(l),
                        child: const Text("기본"),
                      ),
                  ],
                ),
            ],
          ),
        )
      else
        Padding(
          padding: EdgeInsets.only(left: 26, bottom: 6),
          child: Text(
            keepWords("프로젝트 화면 ⋮ 메뉴에서 프로젝트별 시간을 바꿀 수 있습니다."),
            style: TextStyle(fontSize: 11, height: 1.4, color: _sub),
          ),
        ),
    ];
  }

  // 설정이 켜져 있는데 예약이 안 돼 있으면 빨간 경고, 꺼 뒀으면 회색 "꺼짐".
  Widget _schedRow(String name, bool on, bool? scheduled, String when) {
    final Color c;
    final String t;
    if (!on) {
      c = _sub;
      t = "꺼 둠";
    } else if (scheduled == null) {
      c = _sub;
      t = "확인 못 함";
    } else if (scheduled) {
      c = const Color(0xFF1B9E5A);
      t = "예약됨 ($when)";
    } else {
      c = const Color(0xFFE5484D);
      t = "예약 안 됨 (진행중 프로젝트가 없거나 아직 앱에서 설정이 반영되지 않았습니다)";
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            on && scheduled == true
                ? Icons.check_circle_rounded
                : (on && scheduled == false
                      ? Icons.error_rounded
                      : Icons.remove_circle_outline_rounded),
            color: c,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "$name: $t",
              style: TextStyle(fontSize: 13, height: 1.4, color: c),
            ),
          ),
        ],
      ),
    );
  }

  // 정확한 시간 알림 허용 상태와 허용하기 버튼.
  Widget _exactRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            _exact ? Icons.check_circle : Icons.info_outline,
            size: 18,
            color: _exact ? const Color(0xFF1B9E5A) : const Color(0xFFB54708),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _exact ? "정확한 시간 알림: 허용됨" : "정확한 시간 알림: 허용 안 됨",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _exact
                    ? const Color(0xFF1B9E5A)
                    : const Color(0xFFB54708),
              ),
            ),
          ),
          if (!_exact)
            TextButton(onPressed: _allowExact, child: const Text("허용하기")),
        ],
      ),
    );
  }

  Future<void> _test() async {
    try {
      await showTestNotification();
      if (mounted) {
        setState(
          () => _msg =
              "테스트 알림을 보냈습니다. 상단바에 보이는지 확인하십시오. 보이지 않으면 위 알림 설정을 확인하십시오.",
        );
      }
    } catch (e) {
      if (mounted) setState(() => _msg = "테스트 알림 실패: $e");
    }
  }

  Future<void> _reschedulePersonal() async {
    try {
      final n =
          await (widget.personalRescheduler ??
              rescheduleAllPersonalReminders)();
      if (mounted) setState(() => _msg = "개인 일정 알림 $n개를 다시 예약했습니다.");
    } catch (e) {
      if (mounted) setState(() => _msg = "개인 일정 알림을 다시 예약하지 못했습니다: $e");
    }
    await _refresh();
  }

  // 아침 요약 알림 상태 줄(꺼져 있으면 보이지 않는다).
  List<Widget> _morningRows() {
    final m = _morning;
    if (m == null || !m.enabled) return const [];
    final pending = _pendingIds;
    final scheduled = pending == null
        ? null
        : pending.contains(kMorningSummaryId);
    final ok = scheduled != false;
    final color = ok ? const Color(0xFF1B9E5A) : const Color(0xFFE5484D);
    return [
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Row(
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.error_rounded,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                keepWords(
                  ok
                      ? "아침 요약 알림: 예약됨 (매일 ${_hm(m.minutes)})"
                      : "아침 요약 알림: 예약 안 됨 (매일 ${_hm(m.minutes)})",
                ),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // 공휴일 표가 곧 끝나거나 이미 끝났으면 알려 주는 줄.
  List<Widget> _holidayRows() {
    final note = holidayTableNotice(widget.nowForTest ?? DateTime.now());
    if (note.isEmpty) return const [];
    const color = Color(0xFFE5484D);
    return [
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.event_busy_rounded, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                keepWords(note),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // 개인 일정(내 일정 관리) 알림 예약 상태 줄.
  List<Widget> _personalRows() {
    final p = _personal;
    if (p == null) return const [];
    final ok = p.expected == p.scheduled;
    final color = ok ? const Color(0xFF1B9E5A) : const Color(0xFFE5484D);
    return [
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Row(
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.error_rounded,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                keepWords(
                  ok
                      ? (p.expected == 0
                            ? "개인 일정 알림: 알림을 켜 둔 일정이 없습니다."
                            : "개인 일정 알림: 예약됨 (${p.scheduled}개)")
                      : "개인 일정 알림: 필요한 ${p.expected}개 중 ${p.scheduled}개만 예약돼 있습니다.",
                ),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
      if (!ok)
        Padding(
          padding: const EdgeInsets.only(left: 26, bottom: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: _reschedulePersonal,
              child: const Text("개인 일정 알림 다시 예약"),
            ),
          ),
        ),
    ];
  }

  Future<void> _allowExact() async {
    try {
      await (widget.exactRequester ?? requestExactAlarmPermission)();
    } catch (_) {}
    await _refresh();
  }

  Future<void> _scheduleTest() async {
    try {
      final at = await (widget.scheduleTest ?? scheduleTestReminder)();
      if (mounted) {
        setState(
          () => _msg =
              "${_hm(at.hour * 60 + at.minute)}에 예약 알림이 옵니다. 1~2분 안에 상단바에 보이는지 확인하십시오. "
              "안 보이면 아래 5번(배터리 제한)을 확인하십시오.",
        );
      }
    } catch (e) {
      if (mounted) setState(() => _msg = "예약 알림 테스트 실패: $e");
    }
  }

  Future<void> _open(
    String action, {
    Map<String, dynamic>? args,
    String? data,
  }) async {
    try {
      await AndroidIntent(action: action, arguments: args, data: data).launch();
    } catch (_) {
      if (mounted) {
        setState(() => _msg = "설정 화면을 열지 못했습니다. 폰 설정에서 직접 찾아 주십시오.");
      }
    }
  }

  Widget _card(List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 15,
        color: _teal,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ok = _allowed;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          "알림 점검",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _card([
            _title("1. 알림 권한"),
            Row(
              children: [
                Icon(
                  ok == null
                      ? Icons.hourglass_empty_rounded
                      : (ok ? Icons.check_circle_rounded : Icons.error_rounded),
                  color: ok == null
                      ? _sub
                      : (ok
                            ? const Color(0xFF1B9E5A)
                            : const Color(0xFFE5484D)),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ok == null
                        ? "확인 중…"
                        : (ok
                              ? "알림이 허용돼 있습니다."
                              : "알림이 꺼져 있습니다. 아래 버튼으로 켜 주십시오."),
                    style: const TextStyle(fontSize: 13, color: _text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _open(
                'android.settings.APP_NOTIFICATION_SETTINGS',
                args: {'android.provider.extra.APP_PACKAGE': _pkg},
              ),
              child: const Text("앱 알림 설정 열기"),
            ),
          ]),
          _card([
            _title("2. 정확한 시간 알림"),
            _exactRow(),
            Text(
              keepWords(
                _exact
                    ? "정해진 시간에 맞춰 알림이 옵니다. 예약이 돼 있어도 절전 기능 때문에 안 울릴 수 있으니 아래 5번을 확인하십시오."
                    : "지금은 정해진 시간부터 최대 1시간 안에 알림이 옵니다(폰이 배터리를 아끼려고 묶어서 보냅니다). 예약이 돼 있어도 절전 기능 때문에 안 울릴 수 있으니 아래 5번을 확인하십시오.",
              ),
              style: TextStyle(fontSize: 12, height: 1.4, color: _sub),
            ),
          ]),
          _card([
            _title("3. 알림이 오는지 테스트"),
            Text(
              keepWords("지금 바로 알림 한 개를 보낼 수 있습니다. 보이면 알림 자체는 정상입니다."),
              style: TextStyle(fontSize: 13, height: 1.4, color: _sub),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _test,
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
              ),
              child: const Text("테스트 알림 보내기"),
            ),
            const SizedBox(height: 8),
            Text(
              keepWords("예약된 알림이 시간이 되면 실제로 오는지도 확인할 수 있습니다(1분 뒤에 알림이 옵니다)."),
              style: TextStyle(fontSize: 13, height: 1.4, color: _sub),
            ),
            const SizedBox(height: 6),
            OutlinedButton(
              onPressed: _scheduleTest,
              child: const Text("1분 뒤 예약 알림 테스트"),
            ),
            if (_msg != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _msg!,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: _text,
                  ),
                ),
              ),
          ]),
          _card([
            _title("4. 알림 예약 상태"),
            _schedRow(
              "작업 일지 알림",
              _pref?.enabled ?? true,
              _sched?.daily,
              "매일 ${_hm(_pref?.minutes ?? 1080)}",
            ),
            ..._projectTimeRows(),
            _schedRow(
              "주간 보고 알림",
              _pref?.weekly ?? true,
              _sched?.weekly,
              "금요일 ${_hm(_pref?.weeklyMinutes ?? 1020)}",
            ),
            if ((_pref?.weekly ?? false) &&
                _sched?.weekly == false &&
                _activeLogs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 18, bottom: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: _rescheduleWeeklyOne,
                    child: const Text("주간 보고 알림만 다시 예약"),
                  ),
                ),
              ),
            ..._morningRows(),
            ..._personalRows(),
            ..._holidayRows(),
            if (_lastSync != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  keepWords("마지막 알림 예약: $_lastSync"),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: _text,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                keepWords(
                  _seen.isEmpty
                      ? "최근 확인된 알림: 아직 없습니다. 알림이 온 뒤 알림창에서 확인하거나 눌러야 기록됩니다."
                      : "최근 확인된 알림: ${_seen.take(3).join(' / ')} (알림을 밀어서 지운 경우는 기록되지 않습니다.)",
                ),
                style: const TextStyle(fontSize: 12, height: 1.4, color: _text),
              ),
            ),
            Text(
              keepWords("예약이 돼 있어도 절전 기능 때문에 안 울릴 수 있으니 아래 5번을 확인하십시오."),
              style: TextStyle(fontSize: 12, height: 1.4, color: _sub),
            ),
          ]),
          _card([
            _title("5. 예약 알림이 안 올 때 (배터리 제한)"),
            Text(
              keepWords(
                "작업 일지·주간 보고 알림은 정해진 시간에 폰이 앱을 깨워서 보냅니다. 삼성 등 일부 폰은 "
                "절전 기능이 앱을 재워서 예약 알림이 오지 않을 수 있습니다.\n\n"
                "• 설정 → 배터리 → 백그라운드 사용 제한에서 이 앱을 빼 주십시오.\n"
                "• 앱 정보 → 배터리 → '제한 없음'(또는 최적화 안 함)으로 바꿔 주십시오.",
              ),
              style: TextStyle(fontSize: 13, height: 1.5, color: _sub),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _open(
                'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
              ),
              child: const Text("배터리 최적화 설정 열기"),
            ),
            const SizedBox(height: 6),
            OutlinedButton(
              onPressed: () => _open(
                'android.settings.APPLICATION_DETAILS_SETTINGS',
                data: 'package:$_pkg',
              ),
              child: const Text("앱 정보 열기"),
            ),
          ]),
          _card([
            _title("6. 안내 카드 미리 보기"),
            Text(
              keepWords(
                "알림 예약이 안 맞을 때 내 프로젝트 화면 위에 뜨는 안내 카드가 어떻게 보이는지 확인합니다. 실제 문제가 있는 것은 아닙니다.",
              ),
              style: const TextStyle(fontSize: 13, height: 1.4, color: _sub),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, kPreviewProblem),
              child: const Text("안내 카드 미리 보기"),
            ),
          ]),
        ],
      ),
    );
  }
}
