import 'package:flutter/foundation.dart';
import '../../../core/utils/error_log.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

import 'package:tubing_calculator/main.dart'
    show flutterLocalNotificationsPlugin;

// 🚀 작업 일지·주간 보고 알림(예약, 상태 확인, 확인된 알림 기록).
// ───────────────────────── 작업 일지 알림 ─────────────────────────
const int _kReminderId = 918273;
const String _kReminderChannel = 'daily_report_reminder';
const String _kPrefEnabled = 'report_reminder_enabled';
const String _kPrefMinutes = 'report_reminder_minutes';
const String _kPrefWeekly = 'weekly_report_reminder_enabled';
const String _kPrefWeeklyMinutes = 'weekly_report_reminder_minutes';
const int _kWeeklyId = 918274;
// 금요일 알림을 누르면 주간 업무 보고를 바로 여는 데 쓰는 표식.
const String kWeeklyReportPayload = 'work_weekly_report';
// 작업 일지 알림을 누르면 오늘 작업 일지 작성으로 바로 가는 데 쓰는 표식.
const String kDailyReportPayload = 'work_daily_report';

// 작업 일지 알림 문구. 여러 프로젝트가 걸렸으면 몇 곳인지, 프로젝트 하나짜리 알림이면 이름을 알려 준다.
String dailyReminderBody(int missingCount, {String? name}) {
  if (missingCount >= 2) {
    return '오늘 작업 일지를 아직 안 쓴 프로젝트가 $missingCount곳 있습니다. 눌러서 바로 남겨 두십시오.';
  }
  final who = (name == null || name.trim().isEmpty) ? '' : '${name.trim()} ';
  return '$who오늘 작업 일지를 아직 작성하지 않았습니다. 눌러서 바로 남겨 두십시오.';
}

// 작업 일지 알림 예약 계획 한 건: 이 시간(분)에 울릴 알림 하나.
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

const int _kDailyBaseId = 918300; // 918300 ~ 918307을 작업 일지 알림에 쓴다
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
    // 이 묶음에서 오늘 작업 일지를 아직 안 쓴 곳. 전부 썼거나 시간이 지났으면 내일부터.
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

// 알림은 정해진 시간 "정각"이 아니라 그 시간부터 최대 1시간 안에 온다(폰이 배터리를 아끼려고 묶어서 보냄).
// 이 도착 창(정해진 시간 ~ +70분) 안에 앱을 열어 알림을 다시 예약하면, 오늘 시간이 지났다고 내일로 미루면서
// 아직 안 온 오늘 알림이 사라진다. 그래서 도착 창 안에서 폰에 예약돼 있는 알림은 건드리지 않는다.
bool inDeliveryWindow(DateTime now, int minutes, {bool onlyFriday = false}) {
  if (onlyFriday && now.weekday != DateTime.friday) return false;
  final at = DateTime(
    now.year,
    now.month,
    now.day,
    minutes ~/ 60,
    minutes % 60,
  );
  return !now.isBefore(at) && now.isBefore(at.add(const Duration(minutes: 70)));
}

// ── 알림을 마지막으로 예약한 기록(알림 점검 화면에서 "왜 이렇게 됐는지" 보려는 용도) ──
const String _kPrefSyncLog = 'reminder_sync_log';

// 한 줄은 "시각(ISO)|새로 예약한 개수|그대로 둔 개수". 최근 5건만 남긴다.
List<String> addSyncLog(
  List<String> raw,
  DateTime at,
  int scheduled,
  int kept,
) {
  final out = [...raw, '${at.toIso8601String()}|$scheduled|$kept'];
  return out.length > 5 ? out.sublist(out.length - 5) : out;
}

// "9/19 19:20 · 새로 예약 1건" / "… · 새로 예약 0건 · 도착 시간 안이라 그대로 둔 알림 1건". 읽을 수 없는 줄은 null.
String? syncLogLabel(String entry) {
  final p = entry.split('|');
  if (p.length != 3) return null;
  final t = DateTime.tryParse(p[0]);
  final sc = int.tryParse(p[1]);
  final kp = int.tryParse(p[2]);
  if (t == null || sc == null || kp == null) return null;
  final hm =
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  final base = '${t.month}/${t.day} $hm · 새로 예약 $sc건';
  return kp == 0 ? base : '$base · 도착 시간 안이라 그대로 둔 알림 $kp건';
}

Future<void> _recordSync(DateTime at, int scheduled, int kept) async {
  try {
    final p = await SharedPreferences.getInstance();
    final list = addSyncLog(
      p.getStringList(_kPrefSyncLog) ?? const <String>[],
      at,
      scheduled,
      kept,
    );
    await p.setStringList(_kPrefSyncLog, list);
  } catch (_) {}
}

// 가장 최근 예약 기록(없으면 null).
Future<String?> loadLastSyncLabel() async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getStringList(_kPrefSyncLog) ?? const <String>[];
  for (final e in raw.reversed) {
    final l = syncLogLabel(e);
    if (l != null) return l;
  }
  return null;
}

Future<void> _cancelDailyReminders({Set<int> keep = const {}}) async {
  await flutterLocalNotificationsPlugin.cancel(id: _kReminderId); // 예전 버전 알림
  for (var i = 0; i < _kMaxDailyGroups; i++) {
    if (keep.contains(_kDailyBaseId + i)) continue;
    await flutterLocalNotificationsPlugin.cancel(id: _kDailyBaseId + i);
  }
}

// 오늘 작업 일지를 아직 안 쓴 진행중 프로젝트(오늘은 "MM/dd" 형식 문자열).
// 🚀 [고침] 예전엔 "MM/dd"만 견줘, 작년 같은 날 일지가 있으면 오늘 쓴 것으로 봐서
// 알림이 안 왔다. 연도 있는 날짜(dateISO)가 있으면 올해 그 날짜와 견준다.
List<Map<String, dynamic>> projectsMissingReport(
  List<Map<String, dynamic>> logs,
  String todayMmDd, {
  DateTime? now,
}) {
  final year = (now ?? DateTime.now()).year;
  final parts = todayMmDd.split('/');
  final today = parts.length == 2
      ? DateTime(year, int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0)
      : null;
  bool isToday(Map r) {
    final iso = DateTime.tryParse(r['dateISO']?.toString() ?? '');
    if (iso != null && today != null) {
      return iso.year == today.year &&
          iso.month == today.month &&
          iso.day == today.day;
    }
    return r['date'] == todayMmDd;
  }

  return logs.where((l) {
    if (l['status'] == 'DONE' || l['archived'] == true) return false;
    return !(l['daily_reports'] as List? ?? []).any(
      (r) => r is Map && isToday(r),
    );
  }).toList();
}

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
Future<void> _syncWeeklyReminder(
  bool on,
  int minutes,
  bool autoPdf, {
  bool keepIfInWindow = false,
}) async {
  if (on && keepIfInWindow) return; // 도착 창 안이고 이미 예약돼 있으면 그대로 둔다
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
        '작업 일지 알림',
        channelDescription: '작업 일지 작성 알림',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    androidScheduleMode: await reminderScheduleMode(),
    matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
  );
}

// 알림 점검용: 작업 일지/주간 보고 알림이 실제로 예약돼 있는지(폰이 알고 있는지) 읽는다.
// 폰에 예약된 작업 일지 알림 개수(프로젝트별 시간 묶음 수와 비교하려는 값).
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
  if (actual == 0) return '작업 일지 알림 $expected개가 필요한데 예약이 하나도 없습니다.';
  if (actual < expected) {
    return '작업 일지 알림 $expected개가 필요한데 $actual개만 예약돼 있습니다.';
  }
  return '작업 일지 알림이 필요한 $expected개보다 많은 $actual개 예약돼 있습니다.';
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

// ── 아침 요약 알림 ──
// 매일 정한 시간에 "오늘 일정과 작성할 작업 일지를 확인하십시오" 알림을 한 번 보낸다.
// 예약 알림은 내용이 미리 정해져 있어서, 그날의 개수는 넣지 않고 확인하라는 문구만 보낸다.
const int kMorningSummaryId = 918289; // 작업 일지 알림(918300~)·주간(918274)과 겹치지 않게
const String _kPrefMorningOn = 'morning_summary_on';
const String _kPrefMorningMinutes = 'morning_summary_minutes';
const String kMorningSummaryBody = '오늘 일정과 작성할 작업 일지를 확인하십시오.';

// 처음에는 꺼져 있다(모르는 새 알림이 매일 오지 않게). 켜면 기본은 07:30.
Future<({bool enabled, int minutes})> loadMorningSummary() async {
  final p = await SharedPreferences.getInstance();
  return (
    enabled: p.getBool(_kPrefMorningOn) ?? false,
    minutes: p.getInt(_kPrefMorningMinutes) ?? 7 * 60 + 30,
  );
}

Future<void> saveMorningSummary(bool enabled, int minutes) async {
  final p = await SharedPreferences.getInstance();
  await p.setBool(_kPrefMorningOn, enabled);
  await p.setInt(_kPrefMorningMinutes, minutes);
}

// 아침 요약 알림을 예약/취소한다. 도착 창 안에서 이미 예약돼 있으면(켜 둔 채 시간이 지나기 전에 앱을 열면)
// 오늘 알림이 사라지지 않게 그대로 둔다.
Future<void> _syncMorningSummary(
  DateTime now, {
  required bool keepIfInWindow,
}) async {
  final pref = await loadMorningSummary();
  if (!pref.enabled) {
    await flutterLocalNotificationsPlugin.cancel(id: kMorningSummaryId);
    return;
  }
  if (keepIfInWindow && inDeliveryWindow(now, pref.minutes)) return;
  await flutterLocalNotificationsPlugin.cancel(id: kMorningSummaryId);
  var at = DateTime(
    now.year,
    now.month,
    now.day,
    pref.minutes ~/ 60,
    pref.minutes % 60,
  );
  if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
  await flutterLocalNotificationsPlugin.zonedSchedule(
    id: kMorningSummaryId,
    title: '오늘 할 일',
    body: kMorningSummaryBody,
    scheduledDate: tz.TZDateTime.from(at, tz.local),
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _kReminderChannel,
        '작업 일지 알림',
        channelDescription: '작업 일지 작성 알림',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    androidScheduleMode: await reminderScheduleMode(),
    matchDateTimeComponents: DateTimeComponents.time,
  );
}

// 정확한 시간 알림(정확한 알람)을 폰이 허용했는지. 허용돼 있으면 정해진 시간에 맞춰 울리고,
// 아니면 폰이 배터리를 아끼려고 묶어서 보내서 최대 1시간까지 늦을 수 있다.
Future<bool> canScheduleExactAlarms() async {
  try {
    return await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.canScheduleExactNotifications() ??
        false;
  } catch (_) {
    return false;
  }
}

const String _kNotifPermAsked = 'notif_permission_asked_v1';

/// 알림 권한을 처음 한 번만 묻는다(이미 물었으면 그냥 돌아온다). 알림을 켜는 순간에 부른다.
/// 🚀 [고침] 예전에는 앱을 켜자마자 물어, 무엇에 쓰는지 알기 전이라 거절하기 쉬웠고
/// 거절하면 안드로이드는 다시 물어 주지 않았다. 거절했어도 알림 점검 화면에서 켤 수 있다.
Future<void> ensureNotificationPermission() async {
  try {
    final p = await SharedPreferences.getInstance();
    if (p.getBool(_kNotifPermAsked) == true) return;
    await p.setBool(_kNotifPermAsked, true);
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  } catch (_) {}
}

// 정확한 알람 허용 화면을 연다(폰 설정). 허용했으면 true.
Future<bool> requestExactAlarmPermission() async {
  try {
    return await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestExactAlarmsPermission() ??
        false;
  } catch (_) {
    return false;
  }
}

// 알림을 예약할 때 쓸 방식: 허용돼 있으면 정확한 시간, 아니면 묶어서 보내는 방식.
Future<AndroidScheduleMode> reminderScheduleMode() async =>
    await canScheduleExactAlarms()
    ? AndroidScheduleMode.exactAllowWhileIdle
    : AndroidScheduleMode.inexactAllowWhileIdle;

// 예약 알림이 실제로 오는지 확인하는 테스트: 1분 뒤에 알림 한 개를 예약한다.
// (바로 보이는 테스트 알림과 달리, 예약된 알림을 폰이 시간이 되어 띄우는 길 전체를 시험한다.)
Future<DateTime> scheduleTestReminder() async {
  _ensureTimezone();
  const channel = AndroidNotificationChannel(
    _kReminderChannel,
    '작업 일지 알림',
    description: '작업 일지 작성 알림',
    importance: Importance.high,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);
  final at = DateTime.now().add(const Duration(minutes: 1));
  await flutterLocalNotificationsPlugin.zonedSchedule(
    id: 918298,
    title: '예약 알림 점검',
    body: '이 알림이 보이면 예약 알림은 정상입니다.',
    scheduledDate: tz.TZDateTime.from(at, tz.local),
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _kReminderChannel,
        '작업 일지 알림',
        channelDescription: '작업 일지 작성 알림',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    androidScheduleMode: await reminderScheduleMode(),
  );
  return at;
}

Future<void> showTestNotification() async {
  const channel = AndroidNotificationChannel(
    _kReminderChannel,
    '작업 일지 알림',
    description: '작업 일지 작성 알림',
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
        '작업 일지 알림',
        channelDescription: '작업 일지 작성 알림',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}

// 진행중 프로젝트가 있는데 오늘 작업 일지가 아직 없으면 오늘 정해진 시간에, 이미
// 썼으면 내일부터 매일 알린다. 앱을 열 때/작업 일지 저장 후에 다시 맞춘다.
Future<void> syncReportReminder(
  List<Map<String, dynamic>> logs, {
  DateTime? nowForTest,
}) async {
  try {
    final pref = await loadReportReminder();
    final active = logs.where((l) => l['status'] != 'DONE').toList();
    if (!_tzReady) {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
      _tzReady = true;
    }
    final now = nowForTest ?? DateTime.now();
    Set<int> pending = {};
    try {
      pending = await pendingReminderIds();
    } catch (_) {}

    // 프로젝트마다 알림 시간이 다를 수 있어, 같은 시간끼리 묶어 알림을 한 개씩 예약한다.
    final plans = (!pref.enabled || active.isEmpty)
        ? <DailyReminderPlan>[]
        : planDailyReminders(active, pref.minutes, now);
    // 도착 창 안에서 이미 예약돼 있는 알림은 그대로 둔다(다시 예약하면 오늘 알림이 사라진다).
    // 그 사이 오늘 작업 일지를 다 써서 보낼 이유가 없어졌다면 지운다.
    final todayStr =
        '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
    bool stillMissing(DailyReminderPlan p) => projectsMissingReport(
      active
          .where((l) => p.names.contains(l['name']?.toString() ?? '프로젝트'))
          .toList(),
      todayStr,
    ).isNotEmpty;
    final keep = <int>{
      for (var i = 0; i < plans.length; i++)
        if (pending.contains(_kDailyBaseId + i) &&
            inDeliveryWindow(now, plans[i].minutes) &&
            stillMissing(plans[i]))
          _kDailyBaseId + i,
    };
    await _cancelDailyReminders(keep: keep);
    await _syncWeeklyReminder(
      pref.weekly && active.isNotEmpty,
      pref.weeklyMinutes,
      pref.autoPdf,
      keepIfInWindow:
          pending.contains(_kWeeklyId) &&
          inDeliveryWindow(now, pref.weeklyMinutes, onlyFriday: true),
    );
    await _syncMorningSummary(
      now,
      keepIfInWindow: pending.contains(kMorningSummaryId),
    );
    if (plans.isEmpty) return;

    const channel = AndroidNotificationChannel(
      _kReminderChannel,
      '작업 일지 알림',
      description: '작업 일지 작성 알림',
      importance: Importance.high,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    var scheduledCount = 0;
    for (var i = 0; i < plans.length; i++) {
      if (keep.contains(_kDailyBaseId + i)) continue;
      await _scheduleDailyPlan(plans[i], i);
      scheduledCount++;
    }
    await _recordSync(now, scheduledCount, keep.length);
  } catch (e) {
    debugPrint('작업 일지 알림 설정 실패: $e');
    recordError('알림 예약', e);
  }
}

Future<void> _scheduleDailyPlan(DailyReminderPlan plan, int index) async {
  await flutterLocalNotificationsPlugin.zonedSchedule(
    id: _kDailyBaseId + index,
    title: '작업 일지',
    body: dailyReminderBody(plan.count, name: plan.name),
    payload: kDailyReportPayload,
    scheduledDate: tz.TZDateTime.from(plan.at, tz.local),
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _kReminderChannel,
        '작업 일지 알림',
        channelDescription: '작업 일지 작성 알림',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    androidScheduleMode: await reminderScheduleMode(),
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

// "9/19 18:02  작업 일지". 읽을 수 없는 줄은 null.
String? seenReminderLabel(String entry) {
  final p = entry.split('|');
  if (p.length != 2) return null;
  final id = int.tryParse(p[0]);
  final t = DateTime.tryParse(p[1]);
  if (id == null || t == null) return null;
  final kind = id == _kWeeklyId ? '주간 보고' : '작업 일지';
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

// 오늘 이미 울렸어야 하는데(예약 시간 + 1시간 10분이 지남; 알림은 정해진 시간부터 최대 1시간 안에 옴) 확인 기록이 없는 작업 일지 알림.
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

// 작업 일지 알림 한 건(같은 시간에 묶인 프로젝트들)과, 폰에 실제로 예약돼 있는지.
class ReminderSlot {
  final int id; // 알림 아이디(폰에 예약될 때 쓰는 값)
  final DailyReminderPlan plan;
  final bool scheduled;
  ReminderSlot(this.id, this.plan, this.scheduled);
}

// 필요한 작업 일지 알림마다 예약 여부를 붙인다. [pendingIds]는 폰에 예약돼 있는 알림 아이디들.
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

// 어긋난 작업 일지 알림 한 건만 다시 예약한다(다른 알림은 건드리지 않는다).
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
