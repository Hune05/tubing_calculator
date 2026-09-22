// 일정 묶음(2026-09-23): 반복 종류 확대·반복 끝·뺀 회차, 알림 여러 개·종일 알림, 끝나는 시각 겹침.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/schedule_logic.dart';

void main() {
  final base = DateTime(2026, 9, 23, 9, 0); // 수요일

  group('반복 종류', () {
    test('매일·격주·매년 회차', () {
      expect(nthOccurrence(base, 'daily', 3), DateTime(2026, 9, 26, 9, 0));
      expect(nthOccurrence(base, 'biweekly', 1), DateTime(2026, 10, 7, 9, 0));
      expect(nthOccurrence(base, 'yearly', 1), DateTime(2027, 9, 23, 9, 0));
      expect(
        nthOccurrence(DateTime(2028, 2, 29, 9), 'yearly', 1),
        DateTime(2029, 2, 28, 9),
      );
    });

    test('평일마다는 토·일을 건너뛴다', () {
      final fri = DateTime(2026, 9, 25, 9); // 금
      expect(nthOccurrence(fri, 'weekdays', 1), DateTime(2026, 9, 28, 9)); // 월
      expect(
        nthOccurrence(fri, 'weekdays', 5),
        DateTime(2026, 10, 2, 9),
      ); // 다음 금
      final sat = DateTime(2026, 9, 26, 9);
      expect(nthOccurrence(sat, 'weekdays', 0), DateTime(2026, 9, 28, 9));
      expect(recurrenceOccursOn(fri, 'weekdays', DateTime(2026, 9, 27)), false);
      expect(recurrenceOccursOn(fri, 'weekdays', DateTime(2026, 9, 29)), true);
    });

    test('격주는 같은 요일이라도 한 주 건너뛴 날만', () {
      expect(
        recurrenceOccursOn(base, 'biweekly', DateTime(2026, 9, 30)),
        false,
      );
      expect(recurrenceOccursOn(base, 'biweekly', DateTime(2026, 10, 7)), true);
    });

    test('모르는 종류는 반복 없음으로', () {
      expect(isRecurring('none'), false);
      expect(isRecurring('foo'), false);
      expect(recurrenceDates(base, 'foo', rangeStart: base, rangeEnd: base), [
        base,
      ]);
    });
  });

  group('반복 끝·뺀 회차', () {
    test('반복 끝 뒤 회차는 안 나온다', () {
      final dates = recurrenceDates(
        base,
        'weekly',
        rangeStart: DateTime(2026, 9, 1),
        rangeEnd: DateTime(2026, 12, 31),
        until: DateTime(2026, 10, 7),
      );
      expect(dates.map((d) => d.day), [23, 30, 7]);
      expect(
        recurrenceOccursOn(
          base,
          'weekly',
          DateTime(2026, 10, 14),
          until: DateTime(2026, 10, 7),
        ),
        false,
      );
    });

    test('뺀 회차는 빠지고 나머지는 그대로', () {
      final ex = {occurrenceKey(DateTime(2026, 9, 30))};
      final dates = recurrenceDates(
        base,
        'weekly',
        rangeStart: DateTime(2026, 9, 1),
        rangeEnd: DateTime(2026, 10, 8),
        exceptions: ex,
      );
      expect(dates.map((d) => d.day), [23, 7]);
      expect(
        recurrenceOccursOn(
          base,
          'weekly',
          DateTime(2026, 9, 30),
          exceptions: ex,
        ),
        false,
      );
    });

    test('이후 모두 끊을 때 옛 일정의 끝은 회차 하루 전', () {
      expect(
        untilBeforeOccurrence(DateTime(2026, 10, 1, 9)),
        DateTime(2026, 9, 30),
      );
    });

    test('문서에서 반복 끝·뺀 회차 읽기', () {
      expect(
        readUntil({'recurrenceUntil': '2026-10-07T00:00:00.000'}),
        DateTime(2026, 10, 7),
      );
      expect(readUntil({}), isNull);
      expect(
        readExceptions({
          'recurrenceExceptions': ['a', 'b'],
        }),
        {'a', 'b'},
      );
      expect(readExceptions({}), isEmpty);
    });
  });

  group('알림', () {
    test('알림 목록: 새 칸이 있으면 그것, 없으면 예전 칸 하나', () {
      expect(
        readReminders({
          'reminders': [10, 1440, 10],
        }),
        [1440, 10],
      );
      expect(readReminders({'reminderMinutesBefore': 30}), [30]);
      expect(readReminders({'reminderMinutesBefore': 0}), isEmpty);
      // 종일 일정의 예전 칸은 안 쓴다(예전엔 종일엔 알림이 없었다).
      expect(
        readReminders({'hasTime': false, 'reminderMinutesBefore': 30}),
        isEmpty,
      );
    });

    test('종일 알림: 전날 18:00·당일 08:00', () {
      final now = DateTime(2026, 9, 20);
      final allDay = DateTime(2026, 9, 23);
      expect(
        reminderTime(
          base: allDay,
          minutesBefore: 360,
          recurrence: 'none',
          hasTime: false,
          now: now,
          allowAllDay: true,
        ),
        DateTime(2026, 9, 22, 18, 0),
      );
      expect(
        reminderTime(
          base: allDay,
          minutesBefore: -480,
          recurrence: 'none',
          hasTime: false,
          now: now,
          allowAllDay: true,
        ),
        DateTime(2026, 9, 23, 8, 0),
      );
      // 예전 호출(allowAllDay 없음)은 종일이면 그대로 없음.
      expect(
        reminderTime(
          base: allDay,
          minutesBefore: 360,
          recurrence: 'none',
          hasTime: false,
          now: now,
        ),
        isNull,
      );
      // 시간 일정에 음수(당일 아침)는 쓰지 않는다.
      expect(
        reminderTime(
          base: base,
          minutesBefore: -480,
          recurrence: 'none',
          hasTime: true,
          now: now,
          allowAllDay: true,
        ),
        isNull,
      );
    });

    test('반복 끝을 지나면 알림 없음, 뺀 회차는 건너뛴다', () {
      final now = DateTime(2026, 9, 29);
      expect(
        reminderTime(
          base: base,
          minutesBefore: 10,
          recurrence: 'weekly',
          hasTime: true,
          now: now,
          until: DateTime(2026, 9, 25),
        ),
        isNull,
      );
      expect(
        reminderTime(
          base: base,
          minutesBefore: 10,
          recurrence: 'weekly',
          hasTime: true,
          now: now,
          exceptions: {occurrenceKey(DateTime(2026, 9, 30))},
        ),
        DateTime(2026, 10, 7, 8, 50),
      );
    });
  });

  group('끝나는 시각', () {
    test('읽기·회차 끝·글', () {
      final end = readEndTime({'endTime': '2026-09-23T10:30:00.000'}, base);
      expect(end, DateTime(2026, 9, 23, 10, 30));
      expect(readEndTime({'endTime': '2026-09-23T08:00:00.000'}, base), isNull);
      expect(
        occurrenceEnd(DateTime(2026, 9, 30, 9), base, end),
        DateTime(2026, 9, 30, 10, 30),
      );
      expect(formatTimeRange(base, end), '09:00~10:30');
      expect(formatTimeRange(base, null), '09:00');
    });

    test('겹침: 끝 시각이 있으면 구간으로 본다', () {
      LiteAgenda a(String k, int h, int m, {int? endH}) => LiteAgenda(
        key: k,
        date: DateTime(2026, 9, 23, h, m),
        hasTime: true,
        title: k,
        isCompleted: false,
        end: endH == null ? null : DateTime(2026, 9, 23, endH, 0),
      );
      // 09:00~10:00 과 09:30~11:00 겹침, 11:00 시작은 안 겹침(끝 = 시작은 겹치지 않음)
      expect(
        overlappingKeys([
          a('x', 9, 0, endH: 10),
          a('y', 9, 30, endH: 11),
          a('z', 11, 0, endH: 12),
        ]),
        {'x', 'y'},
      );
      // 두 시간짜리 회의와 1시간 40분 뒤 시작: 예전 규칙(1시간 창)이면 안 겹쳤지만 구간으로는 겹친다
      expect(
        overlappingKeys([a('x', 9, 0, endH: 11), a('y', 10, 40, endH: 12)]),
        {'x', 'y'},
      );
      // 끝이 없으면 예전대로 1시간 창
      expect(overlappingKeys([a('x', 9, 0), a('y', 9, 30)]), {'x', 'y'});
      expect(overlappingKeys([a('x', 9, 0), a('y', 10, 0)]), isEmpty);
      expect(
        conflictsWith(a('n', 9, 30, endH: 10), [
          a('x', 9, 0, endH: 9),
          a('y', 9, 45, endH: 11),
        ]).map((e) => e.key),
        ['y'],
      );
    });
  });
}
