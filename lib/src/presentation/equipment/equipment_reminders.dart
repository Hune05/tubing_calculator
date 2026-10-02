// 공구 정기 점검 기한 알림: 기한 7일 전·당일 오전 9시에 폰이 알려 준다.
// 무엇을 언제 알릴지는 순수 함수(planEquipmentReminders)가 정하고, 폰에 예약하는 일만 따로 한다.
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:tubing_calculator/main.dart' show flutterLocalNotificationsPlugin;

import '../my_work_logs/models/report_tools.dart' show reminderScheduleMode;
import 'equipment_model.dart';

const String kEquipReminderChannelId = 'equipment_due_channel';

/// 알림 글에 붙이는 표시. 누르면 장비 대장이 열린다.
const String kEquipPayloadPrefix = 'equip:';

/// 기한 며칠 전에 알릴지(0은 당일).
const List<int> kEquipReminderOffsets = [7, 0];

/// 예전(30일 전 알림이 있던 때) 예약까지 지우려고 취소할 때는 이것을 쓴다.
const List<int> _kCancelOffsets = [30, 7, 0];

/// 알림 시각(시).
const int kEquipReminderHour = 9;

class EquipReminder {
  final int id;
  final String equipmentId;
  final DateTime when;
  final String title;
  final String body;
  const EquipReminder(this.id, this.equipmentId, this.when, this.title, this.body);
}

/// 같은 장비·같은 시점이면 늘 같은 알림 아이디.
int equipNotifId(String equipmentId, int offsetDays) =>
    '$equipmentId#$offsetDays'.hashCode & 0x7fffffff;

/// 앞으로 예약할 알림 목록(지난 시각은 뺀다). 폐기했거나 기한 없는 장비는 없다.
List<EquipReminder> planEquipmentReminders(List<Equipment> all, DateTime now) {
  final out = <EquipReminder>[];
  for (final e in all) {
    if (e.isRetired) continue;
    final due = e.nextDue;
    if (due == null) continue;
    for (final off in kEquipReminderOffsets) {
      final day = due.subtract(Duration(days: off));
      final when = DateTime(day.year, day.month, day.day, kEquipReminderHour);
      if (!when.isAfter(now)) continue;
      final label = e.assetNo.isEmpty ? e.name : '${e.assetNo} ${e.name}';
      final body = off == 0
          ? '$label 점검일이 오늘입니다'
          : '$label 점검일이 $off일 남았습니다 (${dateLabel(due)})';
      out.add(EquipReminder(equipNotifId(e.id, off), e.id, when, '공구 점검 기한', body));
    }
  }
  out.sort((a, b) => a.when.compareTo(b.when));
  return out;
}

bool _tzReady = false;
bool _channelReady = false;

void _ensureTz() {
  if (_tzReady) return;
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  _tzReady = true;
}

Future<void> _ensureChannel() async {
  if (_channelReady) return;
  const channel = AndroidNotificationChannel(
    kEquipReminderChannelId,
    '공구 점검 기한',
    description: '공구 정기 점검 기한 알림',
    importance: Importance.high,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  _channelReady = true;
}

/// 이 장비의 알림 예약을 모두 취소한다(지우거나 다시 잡기 전에).
Future<void> cancelEquipmentReminders(String equipmentId) async {
  for (final off in _kCancelOffsets) {
    try {
      await flutterLocalNotificationsPlugin.cancel(id: equipNotifId(equipmentId, off));
    } catch (_) {}
  }
}

/// 대장 전체의 알림을 다시 잡는다. 예약이 안 돼도(권한·기기 문제) 앱은 그대로 동작한다.
Future<int> rescheduleEquipmentReminders(List<Equipment> all, {DateTime? now}) async {
  var n = 0;
  try {
    for (final e in all) {
      await cancelEquipmentReminders(e.id);
    }
    final plan = planEquipmentReminders(all, now ?? DateTime.now());
    if (plan.isEmpty) return 0;
    _ensureTz();
    await _ensureChannel();
    final mode = await reminderScheduleMode();
    for (final r in plan) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: r.id,
        title: r.title,
        body: r.body,
        payload: '$kEquipPayloadPrefix${r.equipmentId}',
        scheduledDate: tz.TZDateTime.from(r.when, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            kEquipReminderChannelId,
            '공구 점검 기한',
            channelDescription: '공구 정기 점검 기한 알림',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: mode,
      );
      n++;
    }
  } catch (e) {
    debugPrint('장비 알림 예약 실패: $e');
  }
  return n;
}
