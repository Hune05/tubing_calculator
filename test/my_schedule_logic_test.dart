import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/schedule_logic.dart';

LiteAgenda item(
  String key,
  DateTime date, {
  bool hasTime = true,
  bool done = false,
  String title = '일정',
}) => LiteAgenda(
  key: key,
  date: date,
  hasTime: hasTime,
  title: title,
  isCompleted: done,
);

void main() {
  group('매달 날짜 맞추기', () {
    test('31일 일정은 짧은 달에는 그 달 마지막 날로 간다', () {
      final b = DateTime(2026, 1, 31, 9, 30);
      expect(addMonthsClamped(b, 0), DateTime(2026, 1, 31, 9, 30));
      expect(addMonthsClamped(b, 1), DateTime(2026, 2, 28, 9, 30));
      expect(addMonthsClamped(b, 2), DateTime(2026, 3, 31, 9, 30));
      expect(addMonthsClamped(b, 3), DateTime(2026, 4, 30, 9, 30));
    });

    test('윤년 2월은 29일', () {
      expect(
        addMonthsClamped(DateTime(2027, 12, 31), 2),
        DateTime(2028, 2, 29),
      );
    });

    test('해를 넘겨도 맞다', () {
      expect(
        addMonthsClamped(DateTime(2026, 11, 15), 3),
        DateTime(2027, 2, 15),
      );
      expect(
        addMonthsClamped(DateTime(2026, 12, 5), 12),
        DateTime(2027, 12, 5),
      );
    });
  });

  group('반복 일정 회차', () {
    final start = DateTime(2026, 1, 1);
    final end = DateTime(2026, 12, 31, 23, 59);

    test('반복이 없으면 시작 날짜 하나', () {
      final b = DateTime(2026, 5, 5, 10);
      expect(recurrenceDates(b, 'none', rangeStart: start, rangeEnd: end), [b]);
    });

    test('매주는 7일씩', () {
      final r = recurrenceDates(
        DateTime(2026, 9, 1, 10),
        'weekly',
        rangeStart: DateTime(2026, 9, 1),
        rangeEnd: DateTime(2026, 9, 30),
      );
      expect(r.map((e) => e.day).toList(), [1, 8, 15, 22, 29]);
    });

    test('범위 앞의 회차는 빼고 뒤는 넘지 않는다', () {
      final r = recurrenceDates(
        DateTime(2026, 1, 5),
        'weekly',
        rangeStart: DateTime(2026, 2, 1),
        rangeEnd: DateTime(2026, 2, 28),
      );
      expect(r.first, DateTime(2026, 2, 2));
      expect(r.last, DateTime(2026, 2, 23));
    });

    test('매달 31일은 달마다 마지막 날로 맞추고 3일로 밀리지 않는다', () {
      final r = recurrenceDates(
        DateTime(2026, 1, 31, 9),
        'monthly',
        rangeStart: start,
        rangeEnd: end,
      );
      expect(r.length, 12);
      expect(r[1], DateTime(2026, 2, 28, 9));
      expect(r[2], DateTime(2026, 3, 31, 9)); // 예전에는 2월 뒤로 날짜가 밀려 3일이 됐다
      expect(r[3], DateTime(2026, 4, 30, 9));
      expect(r.every((d) => d.hour == 9), true);
    });

    test('회차가 너무 많아지지 않는다(최대 400개)', () {
      final r = recurrenceDates(
        DateTime(1990, 1, 1),
        'weekly',
        rangeStart: DateTime(1990, 1, 1),
        rangeEnd: DateTime(2100, 1, 1),
      );
      expect(r.length, 400);
    });
  });

  group('그날 반복 일정이 걸리는지', () {
    test('매주: 같은 요일, 시작일 전은 아님', () {
      final b = DateTime(2026, 9, 1, 10); // 화요일
      expect(recurrenceOccursOn(b, 'weekly', DateTime(2026, 9, 8)), true);
      expect(recurrenceOccursOn(b, 'weekly', DateTime(2026, 9, 9)), false);
      expect(recurrenceOccursOn(b, 'weekly', DateTime(2026, 8, 25)), false);
    });

    test('매달 31일은 30일까지인 달에는 30일에 걸린다', () {
      final b = DateTime(2026, 1, 31);
      expect(recurrenceOccursOn(b, 'monthly', DateTime(2026, 4, 30)), true);
      expect(recurrenceOccursOn(b, 'monthly', DateTime(2026, 4, 29)), false);
      expect(recurrenceOccursOn(b, 'monthly', DateTime(2026, 2, 28)), true);
      expect(recurrenceOccursOn(b, 'monthly', DateTime(2026, 5, 31)), true);
    });

    test('반복이 없으면 그 날만', () {
      final b = DateTime(2026, 9, 1, 10);
      expect(recurrenceOccursOn(b, 'none', DateTime(2026, 9, 1, 23)), true);
      expect(recurrenceOccursOn(b, 'none', DateTime(2026, 9, 2)), false);
    });
  });

  group('알림 시각', () {
    final now = DateTime(2026, 9, 19, 12);

    test('알림 없음(0분)·종일 일정은 알림을 만들지 않는다', () {
      final b = DateTime(2026, 9, 20, 10);
      expect(
        reminderTime(
          base: b,
          minutesBefore: 0,
          recurrence: 'none',
          hasTime: true,
          now: now,
        ),
        isNull,
      );
      expect(
        reminderTime(
          base: b,
          minutesBefore: 30,
          recurrence: 'none',
          hasTime: false,
          now: now,
        ),
        isNull,
      );
    });

    test('일정 30분 전 / 1시간 전 / 하루 전', () {
      final b = DateTime(2026, 9, 20, 10);
      DateTime? r(int m) => reminderTime(
        base: b,
        minutesBefore: m,
        recurrence: 'none',
        hasTime: true,
        now: now,
      );
      expect(r(30), DateTime(2026, 9, 20, 9, 30));
      expect(r(60), DateTime(2026, 9, 20, 9));
      expect(r(1440), isNull); // 하루 전(오늘 10시)은 이미 지났다
    });

    test('반복이 없고 이미 지난 알림은 만들지 않는다', () {
      expect(
        reminderTime(
          base: DateTime(2026, 9, 19, 12, 20),
          minutesBefore: 30,
          recurrence: 'none',
          hasTime: true,
          now: now,
        ),
        isNull,
      );
    });

    test('매주 반복은 지금 이후 가장 가까운 회차로 맞춘다', () {
      final r = reminderTime(
        base: DateTime(2026, 9, 1, 10), // 화요일 10:00
        minutesBefore: 30,
        recurrence: 'weekly',
        hasTime: true,
        now: now, // 토요일 12:00
      );
      expect(r, DateTime(2026, 9, 22, 9, 30)); // 다음 화요일 09:30
    });

    test('매달 반복은 지금 이후 가장 가까운 달로 맞춘다', () {
      final r = reminderTime(
        base: DateTime(2026, 1, 15, 10),
        minutesBefore: 60,
        recurrence: 'monthly',
        hasTime: true,
        now: now,
      );
      expect(r, DateTime(2026, 10, 15, 9));
    });
  });

  group('시간 겹침', () {
    final d = DateTime(2026, 9, 19);

    test('1시간 안쪽으로 가까운 두 일정이 겹친다', () {
      final k = overlappingKeys([
        item('a', d.add(const Duration(hours: 10))),
        item('b', d.add(const Duration(hours: 10, minutes: 30))),
        item('c', d.add(const Duration(hours: 15))),
      ]);
      expect(k, {'a', 'b'});
    });

    test('딱 1시간 간격은 겹치지 않는다', () {
      final k = overlappingKeys([
        item('a', d.add(const Duration(hours: 10))),
        item('b', d.add(const Duration(hours: 11))),
      ]);
      expect(k, isEmpty);
    });

    test('종일 일정·완료한 일정은 겹침으로 보지 않는다', () {
      final k = overlappingKeys([
        item('a', d.add(const Duration(hours: 10))),
        item('b', d.add(const Duration(hours: 10)), hasTime: false),
        item('c', d.add(const Duration(hours: 10)), done: true),
      ]);
      expect(k, isEmpty);
    });

    test('날짜가 다르면 자정 근처여도 겹치지 않는다', () {
      final k = overlappingKeys([
        item('a', DateTime(2026, 9, 19, 23, 40)),
        item('b', DateTime(2026, 9, 20, 0, 10)),
      ]);
      expect(k, isEmpty);
    });

    test('세 개가 이어서 겹치면 모두 표시', () {
      final k = overlappingKeys([
        item('a', DateTime(2026, 9, 19, 10)),
        item('b', DateTime(2026, 9, 19, 10, 40)),
        item('c', DateTime(2026, 9, 19, 11, 20)),
      ]);
      expect(k, {'a', 'b', 'c'});
    });

    test('일정이 없어도 죽지 않는다', () {
      expect(overlappingKeys([]), isEmpty);
    });
  });

  group('오늘 일정 요약', () {
    final now = DateTime(2026, 9, 19, 12);

    test('일정이 없으면 없다고 알린다', () {
      expect(todaySummary([], now), '오늘 일정이 없습니다.');
    });

    test('남은 일정과 다음 일정을 알려 준다', () {
      final s = todaySummary([
        item('a', DateTime(2026, 9, 19, 9), title: '도면 검토', done: true),
        item('b', DateTime(2026, 9, 19, 14), title: '검사'),
        item('c', DateTime(2026, 9, 19, 16), title: '입고'),
      ], now);
      expect(s, '오늘 일정 3건 · 남은 일정 2건 · 다음 14:00 검사');
    });

    test('다음 일정이 없으면(종일뿐이거나 이미 지남) 건수만', () {
      final s = todaySummary([
        item('a', DateTime(2026, 9, 19, 9), title: '지난 일정'),
        item('b', DateTime(2026, 9, 19), title: '종일', hasTime: false),
      ], now);
      expect(s, '오늘 일정 2건 · 남은 일정 2건');
    });

    test('전부 끝냈으면 모두 마쳤다고 알린다', () {
      final s = todaySummary([
        item('a', DateTime(2026, 9, 19, 9), done: true),
        item('b', DateTime(2026, 9, 19, 10), done: true),
      ], now);
      expect(s, '오늘 일정 2건을 모두 마쳤습니다.');
    });
  });
}
