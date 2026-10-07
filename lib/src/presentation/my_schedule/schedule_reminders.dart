import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:tubing_calculator/main.dart'
    show flutterLocalNotificationsPlugin;

import '../my_work_logs/models/report_tools.dart' show reminderScheduleMode;
import 'schedule_logic.dart';

// 🚀 개인 일정 알림 예약. 화면(내 일정 관리)과 알림 점검이 같이 쓴다.

const String kPersonalScheduleChannelId = 'personal_schedule_channel';
const String kPersonalSchedulesCollectionName = 'personal_schedules';

// 개인 일정 알림의 제목. 폰에 예약된 알림 중 개인 일정 알림을 골라낼 때 쓴다.
const String kPersonalReminderTitle = '일정 알림';

/// 개인 일정 알림에 붙이는 글. 누르면 내 일정의 그 날짜를 연다.
/// 반복 알림은 날짜가 매번 달라 비워 두고(=오늘을 연다) 일정 id만 넣는다.
const String kPersonalPayloadPrefix = 'sched:';

String personalReminderPayload(String docId, DateTime? date) {
  String two(int v) => v.toString().padLeft(2, '0');
  final d = date == null
      ? ''
      : '${date.year}-${two(date.month)}-${two(date.day)}';
  return '$kPersonalPayloadPrefix$docId|$d';
}

/// [personalReminderPayload]로 만든 글을 읽는다. 개인 일정 알림이 아니면 null.
({String id, DateTime? date})? parsePersonalReminderPayload(String? payload) {
  if (payload == null || !payload.startsWith(kPersonalPayloadPrefix)) {
    return null;
  }
  final rest = payload.substring(kPersonalPayloadPrefix.length);
  final i = rest.lastIndexOf('|');
  final id = i < 0 ? rest : rest.substring(0, i);
  final date = i < 0 ? null : DateTime.tryParse(rest.substring(i + 1));
  if (id.isEmpty) return null;
  return (id: id, date: date);
}

bool _tzReady = false;
bool _channelReady = false;

// 문서 id마다 정해진 알림 아이디(같은 일정이면 항상 같은 값).
int personalNotifId(String docId) => docId.hashCode & 0x7fffffff;

// 알림이 여러 개면 둘째부터는 다른 아이디(문서 id에 번호를 붙여 만든다).
const int kMaxRemindersPerSchedule = 5;
int personalNotifIdAt(String docId, int index) =>
    index == 0 ? personalNotifId(docId) : personalNotifId('$docId#$index');

Future<void> cancelPersonalReminders(String docId) async {
  for (var i = 0; i < kMaxRemindersPerSchedule; i++) {
    await flutterLocalNotificationsPlugin.cancel(
      id: personalNotifIdAt(docId, i),
    );
  }
}

/// 폰의 되풀이 예약으로 맞출 수 있는지. 반복 끝·뺀 회차가 있거나 격주·평일이면 한 번씩만 잡고
/// 앱을 열 때 다시 잡는다(rescheduleDriftingMonthlyReminders).
DateTimeComponents? repeatComponentsFor({
  required String recurrence,
  required DateTime start,
  required int minutesBefore,
  DateTime? until,
  Set<String> exceptions = const {},
}) {
  if (until != null || exceptions.isNotEmpty) return null;
  switch (recurrence) {
    case 'daily':
      return DateTimeComponents.time;
    case 'weekly':
      return DateTimeComponents.dayOfWeekAndTime;
    case 'monthly':
      return monthlyReminderKeepsDay(start, minutesBefore)
          ? DateTimeComponents.dayOfMonthAndTime
          : null;
    case 'yearly':
      return DateTimeComponents.dateAndTime;
  }
  return null;
}

void _ensureTz() {
  if (_tzReady) return;
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  _tzReady = true;
}

Future<void> _ensureChannel() async {
  if (_channelReady) return;
  const channel = AndroidNotificationChannel(
    kPersonalScheduleChannelId,
    '내 일정 알림',
    description: '개인 일정 알림',
    importance: Importance.high,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);
  _channelReady = true;
}

// 저장할 때마다 예전 예약은 취소하고 다시 잡는다(수정/반복 변경 시 중복 알림이 남지 않게).
// 알림 시각 계산은 schedule_logic.dart 의 reminderTime 이 한다.
Future<void> schedulePersonalReminder(
  String docId,
  Map<String, dynamic> data, {
  DateTime? nowForTest,
}) async {
  await cancelPersonalReminders(docId);
  await _rememberSig(docId, data);

  final String recurrence = (data['recurrence'] as String?) ?? 'none';
  // 날짜 칸이 없거나 글이 아니면(가져온 자료·옛 자료) 그 일정만 건너뛴다. 예전엔 여기서
  // 예외가 나서 나머지 일정 알림까지 전부 다시 잡히지 않았다.
  final DateTime? base = DateTime.tryParse(data['dateTime']?.toString() ?? '');
  if (base == null) return;
  final bool hasTime = data['hasTime'] != false;
  final DateTime start = hasTime
      ? base
      : DateTime(base.year, base.month, base.day);
  final DateTime? until = readUntil(data);
  final Set<String> exceptions = readExceptions(data);
  final List<int> minutesList = readReminders(
    data,
  ).take(kMaxRemindersPerSchedule).toList();
  final String body = (data['title'] as String?)?.trim().isNotEmpty == true
      ? data['title'] as String
      : '등록된 일정';

  for (var i = 0; i < minutesList.length; i++) {
    final int minutesBefore = minutesList[i];
    final DateTime? remindAt = reminderTime(
      base: base,
      minutesBefore: minutesBefore,
      recurrence: recurrence,
      hasTime: hasTime,
      now: nowForTest ?? DateTime.now(),
      allowAllDay: true,
      until: until,
      exceptions: exceptions,
    );
    if (remindAt == null) continue;
    _ensureTz();
    await _ensureChannel();
    final repeat = repeatComponentsFor(
      recurrence: recurrence,
      start: start,
      minutesBefore: minutesBefore,
      until: until,
      exceptions: exceptions,
    );
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: personalNotifIdAt(docId, i),
      title: kPersonalReminderTitle,
      body: body,
      // 🚀 [추가] 누르면 그 일정의 날짜를 연다(예전엔 홈만 떴다).
      payload: personalReminderPayload(
        docId,
        repeat == null ? remindAt.add(Duration(minutes: minutesBefore)) : null,
      ),
      scheduledDate: tz.TZDateTime.from(remindAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          kPersonalScheduleChannelId,
          '내 일정 알림',
          channelDescription: '개인 일정 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: await reminderScheduleMode(),
      matchDateTimeComponents: repeat,
    );
  }
}

// 알림 점검용: 알림이 필요한 개인 일정 수(expected)와 폰에 실제로 예약된 개수(scheduled).
// 로그인한 사람(이름)을 모르면 null.
Future<({int expected, int scheduled})?> personalReminderStatus({
  DateTime? nowForTest,
}) async {
  try {
    final p = await SharedPreferences.getInstance();
    final worker = p.getString('user_real_name');
    if (worker == null || worker.isEmpty) return null;
    final docs = await _personalDocs(worker);
    final now = nowForTest ?? DateTime.now();
    var expected = 0;
    for (final d in docs) {
      if (_needsReminder(d.data, now)) expected++;
    }
    final pending = await flutterLocalNotificationsPlugin
        .pendingNotificationRequests();
    final scheduled = pending
        .where((e) => e.title == kPersonalReminderTitle)
        .length;
    return (expected: expected, scheduled: scheduled);
  } catch (e) {
    debugPrint('개인 일정 알림 상태 확인 실패: $e');
    return null;
  }
}

bool _needsReminder(Map<String, dynamic> data, DateTime now) {
  final raw = data['dateTime'];
  if (raw is! String) return false;
  final base = DateTime.tryParse(raw);
  if (base == null) return false;
  return readReminders(data).any(
    (m) =>
        reminderTime(
          base: base,
          minutesBefore: m,
          recurrence: (data['recurrence'] as String?) ?? 'none',
          hasTime: data['hasTime'] != false,
          now: now,
          allowAllDay: true,
          until: readUntil(data),
          exceptions: readExceptions(data),
        ) !=
        null,
  );
}

/// 폰의 되풀이 예약으로 못 맞춰 한 번씩만 잡아 둔 일정인지(앱을 열 때 다음 회차를 다시 잡는다).
bool needsOneShotReschedule(Map<String, dynamic> data) {
  final recurrence = (data['recurrence'] as String?) ?? 'none';
  if (!isRecurring(recurrence)) return false;
  final raw = data['dateTime'];
  final base = raw is String ? DateTime.tryParse(raw) : null;
  if (base == null) return false;
  final hasTime = data['hasTime'] != false;
  final start = hasTime ? base : DateTime(base.year, base.month, base.day);
  final until = readUntil(data);
  final exceptions = readExceptions(data);
  for (final m in readReminders(data)) {
    if (repeatComponentsFor(
          recurrence: recurrence,
          start: start,
          minutesBefore: m,
          until: until,
          exceptions: exceptions,
        ) ==
        null) {
      return true;
    }
  }
  return false;
}

Future<List<({String id, Map<String, dynamic> data})>> _personalDocs(
  String worker,
) async => (await _personalDocsWithSource(worker)).docs;

Future<({List<({String id, Map<String, dynamic> data})> docs, bool fromCache})>
_personalDocsWithSource(String worker) async {
  final snap = await FirebaseFirestore.instance
      .collection(kPersonalSchedulesCollectionName)
      .where('owner', isEqualTo: worker)
      .get();
  return (
    docs: [for (final d in snap.docs) (id: d.id, data: d.data())],
    fromCache: snap.metadata.isFromCache,
  );
}

// ── 다른 기기에서 바뀐 일정 알림 맞추기(10-07) ──
// 알림 예약은 기기마다 따로다. 예전에는 태블릿에서 만든·고친·지운 일정의 알림이 폰에 잡히거나
// 취소되지 않았다(폰은 한 번씩만 잡는 반복 일정만 다시 잡았다). 이 기기가 예약할 때 알림에 쓰인
// 칸들의 모양(sig)을 적어 두고, 앱을 켤 때 서버(통신 없으면 폰 사본) 일정과 견주어
// 달라진 것은 다시 잡고, 없어진 것은 취소한다.
const String kPersonalReminderSigsKey = 'personal_reminder_sigs_v1';

/// 알림에 쓰이는 칸들의 모양. 이것이 바뀌면 알림을 다시 잡아야 한다.
String personalReminderSig(Map<String, dynamic> data) => [
  data['dateTime']?.toString() ?? '',
  data['hasTime'] != false,
  (data['recurrence'] as String?) ?? 'none',
  readReminders(data).join(','),
  readUntil(data)?.toIso8601String() ?? '',
  (readExceptions(data).toList()..sort()).join(','),
  (data['title']?.toString() ?? '').trim(),
].join('|');

/// 맞추기 계획: 다시 잡을 일정과 취소할 일정. [canCancel]이 false면(폰 사본이 비어 무엇이 지워졌는지
/// 모를 때) 취소하지 않는다.
({List<String> toSchedule, List<String> toCancel}) planPersonalReminderSync({
  required List<({String id, Map<String, dynamic> data})> docs,
  required Map<String, String> sigs,
  required bool canCancel,
}) {
  final ids = {for (final d in docs) d.id};
  return (
    toSchedule: [
      for (final d in docs)
        if (needsOneShotReschedule(d.data) ||
            sigs[d.id] != personalReminderSig(d.data))
          d.id,
    ],
    toCancel: canCancel
        ? [for (final id in sigs.keys) if (!ids.contains(id)) id]
        : const [],
  );
}

Future<Map<String, String>> _readSigs(SharedPreferences p) async {
  try {
    final raw = p.getString(kPersonalReminderSigsKey);
    if (raw == null) return {};
    return Map<String, String>.from(jsonDecode(raw) as Map);
  } catch (_) {
    return {};
  }
}

Future<void> _rememberSig(String docId, Map<String, dynamic> data) async {
  try {
    final p = await SharedPreferences.getInstance();
    final sigs = await _readSigs(p);
    sigs[docId] = personalReminderSig(data);
    await p.setString(kPersonalReminderSigsKey, jsonEncode(sigs));
  } catch (_) {}
}

/// 앱을 켤 때·내 일정 화면을 열 때 부른다. 다른 기기에서 만든·고친 일정은 알림을 잡고, 지운 일정은
/// 알림을 취소한다. 한 번씩만 잡아 둔 반복 일정도 다음 회차로 다시 잡는다. 다시 잡은 수를 돌려준다.
Future<int> syncPersonalReminders() async {
  try {
    final p = await SharedPreferences.getInstance();
    final worker = p.getString('user_real_name');
    if (worker == null || worker.isEmpty) return 0;
    final src = await _personalDocsWithSource(worker);
    final plan = planPersonalReminderSync(
      docs: src.docs,
      sigs: await _readSigs(p),
      canCancel: src.docs.isNotEmpty || !src.fromCache,
    );
    var n = 0;
    for (final d in src.docs) {
      if (!plan.toSchedule.contains(d.id)) continue;
      try {
        await schedulePersonalReminder(d.id, d.data);
        n++;
      } catch (e) {
        debugPrint('일정 ${d.id} 알림 맞추기 실패: $e');
      }
    }
    if (plan.toCancel.isNotEmpty) {
      for (final id in plan.toCancel) {
        await cancelPersonalReminders(id);
      }
      final sigs = await _readSigs(p);
      plan.toCancel.forEach(sigs.remove);
      await p.setString(kPersonalReminderSigsKey, jsonEncode(sigs));
    }
    return n;
  } catch (e) {
    debugPrint('일정 알림 맞추기 실패: $e');
    return 0;
  }
}

// 예전 이름. 앱을 켤 때(폰 홈)와 내 일정 화면을 열 때 부른다 — 지금은 다른 기기에서 바뀐 일정까지 맞춘다.
Future<int> rescheduleDriftingMonthlyReminders() => syncPersonalReminders();

// 내 개인 일정 알림을 전부 다시 예약한다. 다시 예약한 일정 수를 돌려준다.
Future<int> rescheduleAllPersonalReminders() async {
  final p = await SharedPreferences.getInstance();
  final worker = p.getString('user_real_name');
  if (worker == null || worker.isEmpty) return 0;
  var n = 0;
  final now = DateTime.now();
  for (final d in await _personalDocs(worker)) {
    try {
      await schedulePersonalReminder(d.id, d.data);
      if (_needsReminder(d.data, now)) n++;
    } catch (e) {
      debugPrint('일정 ${d.id} 알림 다시 잡기 실패: $e');
    }
  }
  return n;
}
