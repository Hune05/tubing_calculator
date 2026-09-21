import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/schedule_logic.dart';

void main() {
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
