import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

import 'package:tubing_calculator/main.dart'
    show flutterLocalNotificationsPlugin;

// 🚀 일보·주간 보고 알림(예약, 상태 확인, 확인된 알림 기록).
// ───────────────────────── 일보 알림 ─────────────────────────
const int _kReminderId = 918273;
const String _kReminderChannel = 'daily_report_reminder';
const String _kPrefEnabled = 'report_reminder_enabled';
const String _kPrefMinutes = 'report_reminder_minutes';
const String _kPrefWeekly = 'weekly_report_reminder_enabled';
const String _kPrefWeeklyMinutes = 'weekly_report_reminder_minutes';
const int _kWeeklyId = 918274;
// 금요일 알림을 누르면 주간 업무 보고를 바로 여는 데 쓰는 표식.
const String kWeeklyReportPayload = 'work_weekly_report';
// 일보 알림을 누르면 오늘 일보 작성으로 바로 가는 데 쓰는 표식.
const String kDailyReportPayload = 'work_daily_report';

// 일보 알림 문구. 여러 프로젝트가 걸렸으면 몇 곳인지, 프로젝트 하나짜리 알림이면 이름을 알려 준다.
String dailyReminderBody(int missingCount, {String? name}) {
  if (missingCount >= 2) {
    return '오늘 일보를 아직 안 쓴 프로젝트가 $missingCount곳 있습니다. 눌러서 바로 남겨 두십시오.';
  }
  final who = (name == null || name.trim().isEmpty) ? '' : '${name.trim()} ';
  return '$who오늘 작업 일보 아직 작성하지 않았습니다. 눌러서 바로 남겨 두십시오.';
}

// 일보 알림 예약 계획 한 건: 이 시간(분)에 울릴 알림 하나.
class DailyReminderPlan {
  final int minutes; // 하루 중 몇 분(0~1439)
  final int count; // 알림 문구에 쓸 미작성 프로젝트 수
  final DateTime at; // 다음에 울릴 시간
  final String? name; // 이 시간에 묶인 프로젝트가 하나뿐일 때 그 이름
  final List<String> names; // 이 시간에 묶인 프로젝트 이름들
  DailyReminderPlan(
    this.minutes,
    this.count,
    this.at,
    this.name, {
    this.names = const [],
  });
}

const int _kDailyBaseId = 918300; // 918300 ~ 918307을 일보 알림에 쓴다
const int _kMaxDailyGroups = 8;

// 프로젝트별 알림 시간(reportReminderMinutes, 없으면 기본 시간)으로 묶어 예약 계획을 만든다.
// 시간이 8종류를 넘으면 넘치는 프로젝트는 마지막 묶음에 합친다(알림이 빠지지 않게).
List<DailyReminderPlan> planDailyReminders(
  List<Map<String, dynamic>> active,
  int defaultMinutes,
  DateTime now,
) {
  int minutesOf(Map<String, dynamic> l) {
    final v = (l['reportReminderMinutes'] as num?)?.toInt();
    return (v != null && v >= 0 && v < 1440) ? v : defaultMinutes;
  }

  final groups = <int, List<Map<String, dynamic>>>{};
  for (final l in active) {
    groups.putIfAbsent(minutesOf(l), () => []).add(l);
  }
  final keys = groups.keys.toList()..sort();
  if (keys.length > _kMaxDailyGroups) {
    final last = keys[_kMaxDailyGroups - 1];
    for (final k in keys.skip(_kMaxDailyGroups)) {
      groups[last]!.addAll(groups.remove(k)!);
    }
    keys.removeRange(_kMaxDailyGroups, keys.length);
  }
  final todayStr =
      '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
  final plans = <DailyReminderPlan>[];
  for (final m in keys) {
    final g = groups[m]!;
    // 이 묶음에서 오늘 일보를 아직 안 쓴 곳. 전부 썼거나 시간이 지났으면 내일부터.
    final missing = projectsMissingReport(g, todayStr);
    var at = DateTime(now.year, now.month, now.day, m ~/ 60, m % 60);
    final skipToday = missing.isEmpty || !at.isAfter(now);
    if (skipToday) at = at.add(const Duration(days: 1));
    plans.add(
      DailyReminderPlan(
        m,
        skipToday ? g.length : missing.length,
        at,
        g.length == 1 ? g.first['name']?.toString() : null,
        names: [for (final l in g) l['name']?.toString() ?? '프로젝트'],
      ),
    );
  }
  return plans;
}

Future<void> _cancelDailyReminders() async {
  await flutterLocalNotificationsPlugin.cancel(id: _kReminderId); // 예전 버전 알림
  for (var i = 0; i < _kMaxDailyGroups; i++) {
    await flutterLocalNotificationsPlugin.cancel(id: _kDailyBaseId + i);
  }
}

// 오늘 일보를 아직 안 쓴 진행중 프로젝트(오늘은 "MM/dd" 형식 문자열).
List<Map<String, dynamic>> projectsMissingReport(
  List<Map<String, dynamic>> logs,
  String todayMmDd,
) => logs.where((l) {
  if (l['status'] == 'DONE' || l['archived'] == true) return false;
  return !(l['daily_reports'] as List? ?? []).any(
    (r) => r is Map && r['date'] == todayMmDd,
  );
}).toList();
// 알림을 누르면 PDF까지 바로 만들어 공유창을 여는 설정일 때 쓰는 표식.
const String kWeeklyReportPdfPayload = 'work_weekly_report_pdf';
const String _kPrefWeeklyAutoPdf = 'weekly_report_autopdf';
bool _tzReady = false;

Future<
  ({bool enabled, int minutes, bool weekly, int weeklyMinutes, bool autoPdf})
>
loadReportReminder() async {
  final p = await SharedPreferences.getInstance();
  return (
    enabled: p.getBool(_kPrefEnabled) ?? true,
    minutes: p.getInt(_kPrefMinutes) ?? 18 * 60,
    weekly: p.getBool(_kPrefWeekly) ?? true,
    weeklyMinutes: p.getInt(_kPrefWeeklyMinutes) ?? 17 * 60,
    autoPdf: p.getBool(_kPrefWeeklyAutoPdf) ?? false,
  );
}

Future<void> saveReportReminder(
  bool enabled,
  int minutes, {
  bool weekly = true,
  int weeklyMinutes = 17 * 60,
  bool autoPdf = false,
}) async {
  final p = await SharedPreferences.getInstance();
  await p.setBool(_kPrefEnabled, enabled);
  await p.setInt(_kPrefMinutes, minutes);
  await p.setBool(_kPrefWeekly, weekly);
  await p.setInt(_kPrefWeeklyMinutes, weeklyMinutes);
  await p.setBool(_kPrefWeeklyAutoPdf, autoPdf);
}

// 매주 금요일(기본 17:00)에 주간 업무 보고 알림(진행중 프로젝트가 있을 때).
Future<void> _syncWeeklyReminder(bool on, int minutes, bool autoPdf) async {
  await flutterLocalNotificationsPlugin.cancel(id: _kWeeklyId);
  if (!on) return;
  final now = DateTime.now();
  var at = DateTime(now.year, now.month, now.day, minutes ~/ 60, minutes % 60);
  while (at.weekday != DateTime.friday || !at.isAfter(now)) {
    at = at.add(const Duration(days: 1));
  }
  await flutterLocalNotificationsPlugin.zonedSchedule(
    id: _kWeeklyId,
    title: '주간 보고서',
    body: '이번 주 업무를 정리해 공유해 보십시오. 눌러서 바로 열 수 있습니다.',
    payload: autoPdf ? kWeeklyReportPdfPayload : kWeeklyReportPayload,
    scheduledDate: tz.TZDateTime.from(at, tz.local),
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _kReminderChannel,
        '작업일보 알림',
        channelDescription: '작업일보 작성 알림',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
  );
}

// 알림 점검용: 일보/주간 보고 알림이 실제로 예약돼 있는지(폰이 알고 있는지) 읽는다.
// 폰에 예약된 일보 알림 개수(프로젝트별 시간 묶음 수와 비교하려는 값).
Future<int> scheduledDailyReminderCount() async {
  final pending = await flutterLocalNotificationsPlugin
      .pendingNotificationRequests();
  return pending
      .where(
        (e) =>
            e.id == _kReminderId ||
            (e.id >= _kDailyBaseId && e.id < _kDailyBaseId + _kMaxDailyGroups),
      )
      .length;
}

// 필요한 예약 수와 실제 예약 수가 다르면 안내 문구, 맞으면 null.
String? reminderCountMismatch(int expected, int actual) {
  if (expected == actual) return null;
  if (actual == 0) return '일보 알림 $expected개가 필요한데 예약이 하나도 없습니다.';
  if (actual < expected) {
    return '일보 알림 $expected개가 필요한데 $actual개만 예약돼 있습니다.';
  }
  return '일보 알림이 필요한 $expected개보다 많은 $actual개 예약돼 있습니다.';
}

// 알림을 다시 예약하고, 그래도 어긋나 있는지 확인한 결과(문구, 정상이면 null)를 돌려준다.
Future<String?> resyncRemindersAndCheck(List<Map<String, dynamic>> logs) async {
  await syncReportReminder(logs);
  return dailyReminderProblem(logs);
}

// 알림을 다시 맞춘 직후에도 필요한 수만큼 예약되지 않았으면 그 이유 문구를, 정상이면 null을 돌려준다.
// (권한이 꺼져 있거나 폰이 예약을 막는 경우를 앱을 열 때 바로 알아차리려는 용도)
Future<String?> dailyReminderProblem(List<Map<String, dynamic>> logs) async {
  try {
    final pref = await loadReportReminder();
    if (!pref.enabled) return null;
    final active = logs.where((l) => l['status'] != 'DONE').toList();
    if (active.isEmpty) return null;
    final expected = planDailyReminders(
      active,
      pref.minutes,
      DateTime.now(),
    ).length;
    final actual = await scheduledDailyReminderCount();
    return reminderCountMismatch(expected, actual);
  } catch (_) {
    return null;
  }
}

Future<({bool daily, bool weekly})> scheduledReminderStatus() async {
  final pending = await flutterLocalNotificationsPlugin
      .pendingNotificationRequests();
  final ids = pending.map((e) => e.id).toSet();
  final daily = ids.any(
    (id) =>
        id == _kReminderId ||
        (id >= _kDailyBaseId && id < _kDailyBaseId + _kMaxDailyGroups),
  );
  return (daily: daily, weekly: ids.contains(_kWeeklyId));
}

// 알림 점검용: 지금 바로 테스트 알림을 보내고, 알림 권한이 켜져 있는지 돌려준다.
Future<bool> areNotificationsAllowed() async {
  final android = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  return (await android?.areNotificationsEnabled()) ?? true;
}

Future<void> showTestNotification() async {
  const channel = AndroidNotificationChannel(
    _kReminderChannel,
    '작업일보 알림',
    description: '작업일보 작성 알림',
    importance: Importance.high,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);
  await flutterLocalNotificationsPlugin.show(
    id: 918299,
    title: '알림 점검',
    body: '이 알림이 보이면 알림 권한과 채널은 정상입니다.',
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _kReminderChannel,
        '작업일보 알림',
        channelDescription: '작업일보 작성 알림',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}

// 진행중 프로젝트가 있는데 오늘 일보가 아직 없으면 오늘 정해진 시간에, 이미
// 썼으면 내일부터 매일 알린다. 앱을 열 때/일보 저장 후에 다시 맞춘다.
Future<void> syncReportReminder(List<Map<String, dynamic>> logs) async {
  try {
    final pref = await loadReportReminder();
    await _cancelDailyReminders();
    final active = logs.where((l) => l['status'] != 'DONE').toList();
    if (!_tzReady) {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
      _tzReady = true;
    }
    await _syncWeeklyReminder(
      pref.weekly && active.isNotEmpty,
      pref.weeklyMinutes,
      pref.autoPdf,
    );
    if (!pref.enabled || active.isEmpty) return;

    // 프로젝트마다 알림 시간이 다를 수 있어, 같은 시간끼리 묶어 알림을 한 개씩 예약한다.
    final plans = planDailyReminders(active, pref.minutes, DateTime.now());

    const channel = AndroidNotificationChannel(
      _kReminderChannel,
      '작업일보 알림',
      description: '작업일보 작성 알림',
      importance: Importance.high,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    for (var i = 0; i < plans.length; i++) {
      await _scheduleDailyPlan(plans[i], i);
    }
  } catch (e) {
    debugPrint('일보 알림 설정 실패: $e');
  }
}

Future<void> _scheduleDailyPlan(DailyReminderPlan plan, int index) async {
  await flutterLocalNotificationsPlugin.zonedSchedule(
    id: _kDailyBaseId + index,
    title: '작업일보',
    body: dailyReminderBody(plan.count, name: plan.name),
    payload: kDailyReportPayload,
    scheduledDate: tz.TZDateTime.from(plan.at, tz.local),
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _kReminderChannel,
        '작업일보 알림',
        channelDescription: '작업일보 작성 알림',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time,
  );
}

void _ensureTimezone() {
  if (_tzReady) return;
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  _tzReady = true;
}

// ── 알림이 실제로 확인된 기록 ──
// 폰이 알림을 띄웠는지는 앱이 직접 알 수 없다. 그래서 (1) 알림창에 떠 있는 것을 앱이 볼 때,
// (2) 알림을 눌러 앱이 열릴 때만 기록한다. 알림을 밀어서 지웠다면 기록되지 않는다.
const String _kPrefSeenReminders = 'seen_reminders';

bool isReminderNotificationId(int id) =>
    id == _kReminderId ||
    id == _kWeeklyId ||
    (id >= _kDailyBaseId && id < _kDailyBaseId + 8);

// 기록 한 줄은 "알림아이디|시간(ISO)". 같은 알림이 20시간 안에 또 보이면 새로 적지 않고,
// 최근 10건만 남긴다.
List<String> addSeenReminder(List<String> raw, int id, DateTime at) {
  for (final e in raw) {
    final p = e.split('|');
    if (p.length != 2 || p[0] != id.toString()) continue;
    final t = DateTime.tryParse(p[1]);
    if (t != null && at.difference(t).inHours.abs() < 20) return raw;
  }
  final out = [...raw, '$id|${at.toIso8601String()}'];
  return out.length > 10 ? out.sublist(out.length - 10) : out;
}

// "9/19 18:02  작업일보". 읽을 수 없는 줄은 null.
String? seenReminderLabel(String entry) {
  final p = entry.split('|');
  if (p.length != 2) return null;
  final id = int.tryParse(p[0]);
  final t = DateTime.tryParse(p[1]);
  if (id == null || t == null) return null;
  final kind = id == _kWeeklyId ? '주간 보고' : '작업일보';
  final hm =
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  return '${t.month}/${t.day} $hm  $kind';
}

Future<void> recordSeenReminders(Iterable<int> ids, [DateTime? now]) async {
  final mine = ids.where(isReminderNotificationId).toList();
  if (mine.isEmpty) return;
  final p = await SharedPreferences.getInstance();
  var list = p.getStringList(_kPrefSeenReminders) ?? <String>[];
  for (final id in mine) {
    list = addSeenReminder(list, id, now ?? DateTime.now());
  }
  await p.setStringList(_kPrefSeenReminders, list);
}

// 지금 알림창에 떠 있는 우리 알림을 기록한다. 앱을 열 때 부른다.
Future<void> recordActiveReminders() async {
  try {
    final active = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.getActiveNotifications();
    await recordSeenReminders([
      for (final a in active ?? const <ActiveNotification>[])
        if (a.id != null) a.id!,
    ]);
  } catch (_) {}
}

// 기록 원본(알림아이디|시각 줄들).
Future<List<String>> loadSeenReminderRaw() async {
  final p = await SharedPreferences.getInstance();
  return p.getStringList(_kPrefSeenReminders) ?? const <String>[];
}

// 오늘 이미 울렸어야 하는데(예약 시간 + 1시간 10분이 지남; 알림은 정해진 시간부터 최대 1시간 안에 옴) 확인 기록이 없는 일보 알림.
// 예약이 폰에 잡혀 있는 것만 본다. 밀어서 지운 알림도 여기 걸릴 수 있어 "확인 안 됨"으로만 알린다.
List<ReminderSlot> unconfirmedToday(
  List<ReminderSlot> slots,
  List<String> rawSeen,
  DateTime now,
) {
  bool seenSince(int id, DateTime since) {
    for (final e in rawSeen) {
      final p = e.split('|');
      if (p.length != 2 || p[0] != id.toString()) continue;
      final t = DateTime.tryParse(p[1]);
      if (t != null && !t.isBefore(since)) return true;
    }
    return false;
  }

  return [
    for (final s in slots)
      if (s.scheduled)
        if (!now.isBefore(
          DateTime(
            now.year,
            now.month,
            now.day,
            s.plan.minutes ~/ 60,
            s.plan.minutes % 60,
          ).add(const Duration(minutes: 70)),
        ))
          if (!seenSince(
            s.id,
            DateTime(
              now.year,
              now.month,
              now.day,
              s.plan.minutes ~/ 60,
              s.plan.minutes % 60,
            ).subtract(const Duration(minutes: 5)),
          ))
            s,
  ];
}

// 최근에 확인된 알림들(최신이 앞).
Future<List<String>> loadSeenReminderLabels() async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getStringList(_kPrefSeenReminders) ?? const <String>[];
  return [
    for (final e in raw.reversed)
      if (seenReminderLabel(e) != null) seenReminderLabel(e)!,
  ];
}

// ── 예약 항목별 점검: 어긋난 것만 골라 다시 예약 ──

// 일보 알림 한 건(같은 시간에 묶인 프로젝트들)과, 폰에 실제로 예약돼 있는지.
class ReminderSlot {
  final int id; // 알림 아이디(폰에 예약될 때 쓰는 값)
  final DailyReminderPlan plan;
  final bool scheduled;
  ReminderSlot(this.id, this.plan, this.scheduled);
}

// 필요한 일보 알림마다 예약 여부를 붙인다. [pendingIds]는 폰에 예약돼 있는 알림 아이디들.
List<ReminderSlot> dailyReminderSlots(
  List<Map<String, dynamic>> logs,
  int defaultMinutes,
  DateTime now,
  Set<int> pendingIds,
) {
  final active = logs.where((l) => l['status'] != 'DONE').toList();
  final plans = planDailyReminders(active, defaultMinutes, now);
  return [
    for (var i = 0; i < plans.length; i++)
      ReminderSlot(
        _kDailyBaseId + i,
        plans[i],
        pendingIds.contains(_kDailyBaseId + i),
      ),
  ];
}

// 폰에 예약돼 있는 알림 아이디들.
Future<Set<int>> pendingReminderIds() async {
  final pending = await flutterLocalNotificationsPlugin
      .pendingNotificationRequests();
  return pending.map((e) => e.id).toSet();
}

// 어긋난 일보 알림 한 건만 다시 예약한다(다른 알림은 건드리지 않는다).
Future<void> rescheduleDailySlot(ReminderSlot slot) async {
  _ensureTimezone();
  await _scheduleDailyPlan(slot.plan, slot.id - _kDailyBaseId);
}

// 주간 보고 알림만 다시 예약한다.
Future<void> rescheduleWeeklyOnly(List<Map<String, dynamic>> logs) async {
  _ensureTimezone();
  final pref = await loadReportReminder();
  final active = logs.where((l) => l['status'] != 'DONE').toList();
  await _syncWeeklyReminder(
    pref.weekly && active.isNotEmpty,
    pref.weeklyMinutes,
    pref.autoPdf,
  );
}
