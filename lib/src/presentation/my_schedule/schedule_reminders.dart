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

bool _tzReady = false;
bool _channelReady = false;

// 문서 id마다 정해진 알림 아이디(같은 일정이면 항상 같은 값).
int personalNotifId(String docId) => docId.hashCode & 0x7fffffff;

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
  final int notifId = personalNotifId(docId);
  await flutterLocalNotificationsPlugin.cancel(id: notifId);

  final String recurrence = (data['recurrence'] as String?) ?? 'none';
  DateTimeComponents? matchComponents;
  if (recurrence == 'weekly') {
    matchComponents = DateTimeComponents.dayOfWeekAndTime;
  } else if (recurrence == 'monthly') {
    matchComponents = DateTimeComponents.dayOfMonthAndTime;
  }
  final DateTime? remindAt = reminderTime(
    base: DateTime.parse(data['dateTime'] as String),
    minutesBefore: (data['reminderMinutesBefore'] as int?) ?? 0,
    recurrence: recurrence,
    hasTime: data['hasTime'] != false,
    now: nowForTest ?? DateTime.now(),
  );
  if (remindAt == null) return;

  _ensureTz();
  await _ensureChannel();
  await flutterLocalNotificationsPlugin.zonedSchedule(
    id: notifId,
    title: kPersonalReminderTitle,
    body: (data['title'] as String?)?.trim().isNotEmpty == true
        ? data['title'] as String
        : '등록된 일정',
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
    matchDateTimeComponents: matchComponents,
  );
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
  return reminderTime(
        base: base,
        minutesBefore: (data['reminderMinutesBefore'] as int?) ?? 0,
        recurrence: (data['recurrence'] as String?) ?? 'none',
        hasTime: data['hasTime'] != false,
        now: now,
      ) !=
      null;
}

Future<List<({String id, Map<String, dynamic> data})>> _personalDocs(
  String worker,
) async {
  final snap = await FirebaseFirestore.instance
      .collection(kPersonalSchedulesCollectionName)
      .where('owner', isEqualTo: worker)
      .get();
  return [for (final d in snap.docs) (id: d.id, data: d.data())];
}

// 내 개인 일정 알림을 전부 다시 예약한다. 다시 예약한 일정 수를 돌려준다.
Future<int> rescheduleAllPersonalReminders() async {
  final p = await SharedPreferences.getInstance();
  final worker = p.getString('user_real_name');
  if (worker == null || worker.isEmpty) return 0;
  var n = 0;
  final now = DateTime.now();
  for (final d in await _personalDocs(worker)) {
    await schedulePersonalReminder(d.id, d.data);
    if (_needsReminder(d.data, now)) n++;
  }
  return n;
}
