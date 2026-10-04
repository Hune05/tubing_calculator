// 퇴근 깜빡 알림: 소정 퇴근 시각이 지났는데 퇴근을 안 찍었으면 폰이 알려 준다.
// 언제 울릴지는 순수 함수(planClockOutReminder)가 정하고, 예약은 안드로이드 알람(ClockReminder.kt)이 한다.
// 위젯 단추로 앱 없이 출근했을 때도 안드로이드가 같은 설정을 읽어 스스로 예약하므로, 예약을 한 곳(안드로이드)에 둔다.
// 알림에는 [퇴근 찍기] 단추가 있다. 예약이 안 돼도(권한·기기 문제) 앱은 그대로 동작한다.
import 'package:tubing_calculator/main.dart'
    show flutterLocalNotificationsPlugin;
import 'package:tubing_calculator/src/core/utils/home_widget_sync.dart';

import '../my_work_logs/models/attendance.dart';
import 'attendance_clock.dart';

/// 알림 글에 붙이는 표시(예전 버전이 flutter_local_notifications로 예약한 알림을 눌렀을 때만 쓴다).
const String kClockOutPayload = 'attendance:out';

/// 알림 아이디(안드로이드 쪽과 같다).
const int kClockOutNotifId = 918500;

/// 예전 버전이 flutter_local_notifications로 잡아 둔 예약이 남아 있으면 지운다.
Future<void> _cancelLegacy() async {
  try {
    await flutterLocalNotificationsPlugin.cancel(id: kClockOutNotifId);
  } catch (_) {}
}

Future<void> cancelClockOutReminder() async {
  await _cancelLegacy();
  await HomeWidgetSync.setClockOutReminder(null);
}

/// 오늘 기록 [today]를 보고 퇴근 알림을 다시 잡는다(없으면 취소). 예약한 시각을 돌려준다.
Future<DateTime?> syncClockOutReminder({
  required bool enabled,
  required String? workEnd,
  required AttendanceRecord? today,
  DateTime? now,
}) async {
  final when = planClockOutReminder(
    enabled: enabled,
    workEnd: workEnd,
    today: today,
    now: now ?? DateTime.now(),
  );
  await _cancelLegacy();
  await HomeWidgetSync.setClockOutReminder(when);
  return when;
}
