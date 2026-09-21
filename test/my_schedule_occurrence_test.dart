import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/schedule_logic.dart';

void main() {
  pickerGroup();
  coverGroup();
  spanGroup();
  recurrenceGroup();
  shiftGroup();
  reminderGroup();
  group('반복 일정 회차 완료 표시', () {
    final day = DateTime(2026, 9, 25, 14, 30);

    test('회차 키는 날짜만 보고, 저장 경로는 키 전체가 한 칸이다', () {
      expect(occurrenceKey(day), '2026-09-25T00:00:00.000');
      final path = FieldPath(occurrenceFieldPath(day));
      expect(path.components, [
        'completedOccurrences',
        '2026-09-25T00:00:00.000',
      ]);
      // 점이 든 문자열 경로는 세 칸으로 쪼개진다(예전에 저장이 안 되던 까닭).
      expect(
        FieldPath.fromString(
          'completedOccurrences.${occurrenceKey(day)}',
        ).components.length,
        3,
      );
    });

    test('바르게 들어간 완료 표시를 읽는다', () {
      expect(
        isOccurrenceCompleted({'2026-09-25T00:00:00.000': true}, day),
        true,
      );
      expect(
        isOccurrenceCompleted({'2026-09-25T00:00:00.000': false}, day),
        false,
      );
      expect(isOccurrenceCompleted(null, day), false);
      expect(isOccurrenceCompleted({}, day), false);
    });

    test('예전에 중첩 모양으로 들어간 완료 표시도 읽는다', () {
      expect(
        isOccurrenceCompleted({
          '2026-09-25T00:00:00': {'000': true},
        }, day),
        true,
      );
      expect(
        isOccurrenceCompleted({
          '2026-09-25T00:00:00': {'000': false},
        }, day),
        false,
      );
      // 다른 날의 표시는 보지 않는다.
      expect(
        isOccurrenceCompleted({
          '2026-09-26T00:00:00': {'000': true},
        }, day),
        false,
      );
    });

    test('예전 중첩 모양의 경로(지울 때 쓴다)', () {
      expect(legacyOccurrenceFieldPath(day), [
        'completedOccurrences',
        '2026-09-25T00:00:00',
      ]);
    });
  });
}

DateTime? _monthly(DateTime base, int minutes, DateTime now) => reminderTime(
  base: base,
  minutesBefore: minutes,
  recurrence: 'monthly',
  hasTime: true,
  now: now,
);

void reminderGroup() {
  group('매달 반복 알림 날짜(회차를 먼저 구하고 거기서 뺀다)', () {
    test('1일 일정의 하루 전 알림은 전달 말일이다', () {
      expect(
        _monthly(DateTime(2026, 3, 1, 9), 1440, DateTime(2026, 3, 15)),
        DateTime(2026, 3, 31, 9),
      );
    });

    test('31일 일정은 2월 말일 회차에서 하루 전이다', () {
      expect(
        _monthly(DateTime(2026, 1, 31, 9), 1440, DateTime(2026, 2, 1)),
        DateTime(2026, 2, 27, 9),
      );
    });

    test('이틀 전 알림', () {
      expect(
        _monthly(DateTime(2026, 10, 1, 8), 2880, DateTime(2026, 10, 2)),
        DateTime(2026, 10, 30, 8),
      );
    });

    test('매주 반복은 그대로 회차에서 뺀다', () {
      expect(
        reminderTime(
          base: DateTime(2026, 9, 1, 10),
          minutesBefore: 30,
          recurrence: 'weekly',
          hasTime: true,
          now: DateTime(2026, 9, 19, 12),
        ),
        DateTime(2026, 9, 22, 9, 30),
      );
    });

    test('알림 날짜가 달마다 같은지(같을 때만 매달 같은 날로 되풀이 예약한다)', () {
      expect(monthlyReminderKeepsDay(DateTime(2026, 1, 15, 10), 60), true);
      expect(monthlyReminderKeepsDay(DateTime(2026, 1, 15, 10), 1440), true);
      expect(monthlyReminderKeepsDay(DateTime(2026, 1, 1, 9), 1440), false);
      expect(monthlyReminderKeepsDay(DateTime(2026, 1, 1, 9), 30), true);
      expect(monthlyReminderKeepsDay(DateTime(2026, 1, 1, 0, 10), 30), false);
      expect(monthlyReminderKeepsDay(DateTime(2026, 1, 29, 9), 30), false);
      expect(monthlyReminderKeepsDay(DateTime(2026, 1, 28, 9), 30), true);
    });
  });
}

void shiftGroup() {
  group('시작일을 옮기면 기간을 그대로 두고 종료일도 옮긴다', () {
    test('3일 기간', () {
      expect(
        shiftedEndDate(
          oldStart: DateTime(2026, 9, 22, 14),
          oldEnd: DateTime(2026, 9, 24),
          newStart: DateTime(2026, 9, 30, 14),
        ),
        DateTime(2026, 10, 2),
      );
    });

    test('종료일이 없으면 그대로 없다', () {
      expect(
        shiftedEndDate(
          oldStart: DateTime(2026, 9, 22),
          oldEnd: null,
          newStart: DateTime(2026, 9, 30),
        ),
        isNull,
      );
    });

    test('시작일을 모르거나 기간이 이상하면 새 시작일 앞의 종료일은 버린다', () {
      expect(
        shiftedEndDate(
          oldStart: null,
          oldEnd: DateTime(2026, 9, 24),
          newStart: DateTime(2026, 9, 30),
        ),
        isNull,
      );
      expect(
        shiftedEndDate(
          oldStart: null,
          oldEnd: DateTime(2026, 10, 5),
          newStart: DateTime(2026, 9, 30),
        ),
        DateTime(2026, 10, 5),
      );
      expect(
        shiftedEndDate(
          oldStart: DateTime(2026, 9, 25),
          oldEnd: DateTime(2026, 9, 24),
          newStart: DateTime(2026, 9, 30),
        ),
        isNull,
      );
    });
  });
}

void recurrenceGroup() {
  group('오래된 반복 일정도 화면 범위 끝까지 나온다', () {
    test('2020년 매주 일정, 2025~2028 범위', () {
      final r = recurrenceDates(
        DateTime(2020, 1, 6, 9),
        'weekly',
        rangeStart: DateTime(2025, 1, 1),
        rangeEnd: DateTime(2028, 12, 31, 23, 59),
      );
      // 2025-01-06(월)부터 2028-12-25(월)까지 매주.
      expect(r.first, DateTime(2025, 1, 6, 9));
      expect(r.last, DateTime(2028, 12, 25, 9));
      expect(r.length, 208);
    });

    test('2000년 매달 31일 일정은 범위 안에서 말일로 맞춘다', () {
      final r = recurrenceDates(
        DateTime(2000, 1, 31, 9),
        'monthly',
        rangeStart: DateTime(2025, 1, 1),
        rangeEnd: DateTime(2025, 3, 31, 23, 59),
      );
      expect(r, [
        DateTime(2025, 1, 31, 9),
        DateTime(2025, 2, 28, 9),
        DateTime(2025, 3, 31, 9),
      ]);
    });

    test('시작일이 범위 안이면 시작일부터', () {
      final r = recurrenceDates(
        DateTime(2025, 1, 6, 9),
        'weekly',
        rangeStart: DateTime(2025, 1, 1),
        rangeEnd: DateTime(2025, 1, 31),
      );
      expect(r.first, DateTime(2025, 1, 6, 9));
      expect(r.length, 4);
    });
  });
}

void spanGroup() {
  group('기간 일정 일수', () {
    test('반년짜리 시공 기간도 달력에 펼친다', () {
      expect(spanDayCount(DateTime(2026, 9, 1, 8), DateTime(2027, 3, 1)), 182);
    });
    test('편집에서 고를 수 있는 가장 긴 기간(시작 + 730일)까지 펼친다', () {
      final s = DateTime(2026, 9, 1);
      expect(spanDayCount(s, s.add(const Duration(days: 730))), 731);
      expect(spanDayCount(s, s.add(const Duration(days: 731))), 1);
    });
    test('종료일이 없거나 시작보다 앞서면 하루', () {
      expect(spanDayCount(DateTime(2026, 9, 3), null), 1);
      expect(spanDayCount(DateTime(2026, 9, 3), DateTime(2026, 9, 1)), 1);
      expect(spanDayCount(DateTime(2026, 9, 3, 14), DateTime(2026, 9, 5)), 3);
    });
  });
}

void coverGroup() {
  test('여러 날 일정은 둘째 날·마지막 날에도 오늘 일정으로 센다', () {
    final s = DateTime(2026, 9, 21, 9);
    final e = DateTime(2026, 9, 23);
    expect(spanCoversDay(s, e, DateTime(2026, 9, 20)), false);
    expect(spanCoversDay(s, e, DateTime(2026, 9, 21, 15)), true);
    expect(spanCoversDay(s, e, DateTime(2026, 9, 22)), true);
    expect(spanCoversDay(s, e, DateTime(2026, 9, 23, 23)), true);
    expect(spanCoversDay(s, e, DateTime(2026, 9, 24)), false);
    expect(spanCoversDay(s, null, DateTime(2026, 9, 21)), true);
    expect(spanCoversDay(s, null, DateTime(2026, 9, 22)), false);
  });
}

void pickerGroup() {
  test('날짜 고르기 범위는 고치려는 날짜를 품도록 넓힌다', () {
    final first = DateTime(2025, 9, 22);
    final last = DateTime(2028, 9, 21);
    final old = pickerRangeFor(DateTime(2025, 6, 1, 9), first, last);
    expect(old.first, DateTime(2025, 6, 1));
    expect(old.last, last);
    final far = pickerRangeFor(DateTime(2029, 1, 1), first, last);
    expect(far.first, first);
    expect(far.last, DateTime(2029, 1, 1));
    final inside = pickerRangeFor(DateTime(2026, 1, 1), first, last);
    expect(inside.first, first);
    expect(inside.last, last);
  });

  test('이미 지난 기한은 오늘부터 보인다', () {
    final today = DateTime(2026, 9, 22, 10);
    final last = DateTime(2027, 9, 22);
    expect(clampPickerInitial(DateTime(2026, 9, 1), today, last), today);
    expect(
      clampPickerInitial(DateTime(2026, 10, 1), today, last),
      DateTime(2026, 10, 1),
    );
  });
}
