// 알림을 누르면 그 항목을 열고, 알림 권한은 켜는 순간에 한 번만 묻는지(점검 34번).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/main.dart' show routeForNotification;
import 'package:tubing_calculator/src/presentation/my_schedule/schedule_reminders.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/reminder_tools.dart';

void main() {
  test('개인 일정 알림 글: 일정 id와 날짜가 되읽힌다', () {
    final p = personalReminderPayload('doc-1', DateTime(2026, 10, 3, 9, 30));
    final r = parsePersonalReminderPayload(p)!;
    expect(r.id, 'doc-1');
    expect(r.date, DateTime(2026, 10, 3));
    // 반복 알림은 날짜 없이(=오늘을 연다)
    expect(
      parsePersonalReminderPayload(personalReminderPayload('d', null))!.date,
      isNull,
    );
    // 다른 알림(일일·주간 보고)은 개인 일정이 아니다
    expect(parsePersonalReminderPayload('daily_report'), isNull);
    expect(parsePersonalReminderPayload(null), isNull);
  });

  test('누르면 열 화면: 개인 일정 → 내 일정, 서버 알림 → 작업 일지, 나머지는 없음', () {
    // 예전: 개인 일정 알림엔 글이 없고, 서버 알림은 글만 찍어 홈만 떴다.
    expect(
      routeForNotification(
        personalReminderPayload('d', DateTime(2026, 10, 3)),
        {},
      ),
      isA<MaterialPageRoute<void>>(),
    );
    expect(routeForNotification(null, {'open': 'work_logs'}), isNotNull);
    expect(routeForNotification('weekly_report', {}), isNull);
    expect(routeForNotification(null, {}), isNull);
  });

  test('알림 권한은 처음 한 번만 묻는다', () async {
    SharedPreferences.setMockInitialValues({});
    await ensureNotificationPermission();
    final p = await SharedPreferences.getInstance();
    expect(p.getBool('notif_permission_asked_v1'), isTrue);
    await ensureNotificationPermission(); // 두 번째는 묻지 않고 바로
  });
}
