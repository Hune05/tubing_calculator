// 매년 반복 일정 알림의 폰 되풀이 예약(10-08): 윤년에 날짜가 어긋나는 경우는 한 번씩만 잡는다.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/schedule_reminders.dart';

DateTimeComponents? _yearly(DateTime start, int before) => repeatComponentsFor(
  recurrence: 'yearly',
  start: start,
  minutesBefore: before,
);

void main() {
  test('같은 달 안의 알림은 매년 같은 날로 되풀이한다', () {
    expect(_yearly(DateTime(2026, 5, 10, 9), 60), DateTimeComponents.dateAndTime);
    expect(_yearly(DateTime(2026, 5, 10, 9), 24 * 60), DateTimeComponents.dateAndTime);
  });

  test('3월 1일 일정의 하루 전 알림(2월로 넘어감)은 되풀이하지 않는다', () {
    expect(_yearly(DateTime(2026, 3, 1, 9), 24 * 60), isNull);
  });

  test('2월 29일 일정은 되풀이하지 않는다', () {
    expect(_yearly(DateTime(2028, 2, 29, 9), 60), isNull);
  });
}
