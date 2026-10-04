// 퇴근 깜빡 알림: 소정 퇴근 시각이 지났는데 퇴근을 안 찍었으면 폰이 알려 준다.
// 언제 울릴지는 순수 함수(planClockOutReminder)가 정하고, 여기서는 폰에 예약·취소만 한다.
// 예약이 안 돼도(권한·기기 문제) 앱은 그대로 동작한다.
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:tubing_calculator/main.dart'
    show flutterLocalNotificationsPlugin;

import '../my_work_logs/models/attendance.dart';
import '../my_work_logs/models/report_tools.dart' show reminderScheduleMode;
import 'attendance_clock.dart';

const String kClockOutChannelId = 'attendance_clock_out_channel';

/// 알림 글에 붙이는 표시. 누르면 근태 화면이 열린다.
const String kClockOutPayload = 'attendance:out';

/// 항상 같은 아이디(하루에 하나만 예약한다).
const int kClockOutNotifId = 918500;

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
    kClockOutChannelId,
    '퇴근 시각 알림',
    description: '소정 퇴근 시각이 지났는데 퇴근을 안 찍었을 때 알림',
    importance: Importance.high,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);
  _channelReady = true;
}

Future<void> cancelClockOutReminder() async {
  try {
    await flutterLocalNotificationsPlugin.cancel(id: kClockOutNotifId);
  } catch (_) {}
}

/// 오늘 기록 [today]를 보고 퇴근 알림을 다시 잡는다(지울 때는 예약만 취소). 예약한 시각을 돌려준다.
Future<DateTime?> syncClockOutReminder({
  required bool enabled,
  required String? workEnd,
  required AttendanceRecord? today,
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();
  final when = planClockOutReminder(
    enabled: enabled,
    workEnd: workEnd,
    today: today,
    now: at,
  );
  await cancelClockOutReminder();
  if (when == null) return null;
  try {
    _ensureTz();
    await _ensureChannel();
    final mode = await reminderScheduleMode();
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: kClockOutNotifId,
      title: '퇴근 시각이 지났습니다',
      body: '퇴근을 아직 안 찍었습니다. 눌러서 퇴근을 찍으십시오.',
      payload: kClockOutPayload,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          kClockOutChannelId,
          '퇴근 시각 알림',
          channelDescription: '소정 퇴근 시각이 지났는데 퇴근을 안 찍었을 때 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: mode,
    );
    return when;
  } catch (e) {
    debugPrint('퇴근 알림 예약 실패: $e');
    return null;
  }
}
