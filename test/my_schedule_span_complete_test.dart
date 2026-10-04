// 여러 날(기간) 일정은 하루씩 따로 완료한다 — 하루만 끝내도 전체 일정이 끝나 버리던 것을 고침.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/schedule_logic.dart';

void main() {
  final d1 = DateTime(2026, 10, 5);
  final d2 = DateTime(2026, 10, 6);
  final d3 = DateTime(2026, 10, 7);

  group('기간 일정 하루 완료 읽기', () {
    test('완료 표시가 없으면 모든 날이 미완료', () {
      expect(isSpanDayCompleted({}, d1), false);
      expect(isSpanDayCompleted(null, d2), false);
    });

    test('한 날만 표시하면 그 날만 완료, 나머지는 미완료', () {
      final done = {occurrenceKey(d1): true};
      expect(isSpanDayCompleted(done, d1), true);
      expect(isSpanDayCompleted(done, d2), false);
      expect(isSpanDayCompleted(done, d3), false);
    });

    test('시각이 달라도 같은 날이면 같은 칸', () {
      final done = {occurrenceKey(d1): true};
      expect(isSpanDayCompleted(done, DateTime(2026, 10, 5, 14, 30)), true);
    });

    test('예전 방식(전체 완료 표시)으로 끝낸 일정은 모든 날이 완료', () {
      expect(isSpanDayCompleted({}, d1, wholeDone: true), true);
      expect(isSpanDayCompleted({}, d3, wholeDone: true), true);
    });
  });

  group('기간 일정 하루 완료 바꾸기', () {
    test('완료로 바꾸면 그 날 칸 하나만 적는다', () {
      final c = spanDayCompletionChanges(
        day: d2,
        nowDone: true,
        firstDay: d1,
        totalDays: 3,
      );
      expect(c.length, 1);
      expect(c.single.path, occurrenceFieldPath(d2));
      expect(c.single.value, true);
    });

    test('풀면 그 날 칸(예전 중첩 모양 포함)만 지운다', () {
      final c = spanDayCompletionChanges(
        day: d2,
        nowDone: false,
        firstDay: d1,
        totalDays: 3,
      );
      expect(c.map((e) => e.path), [
        occurrenceFieldPath(d2),
        legacyOccurrenceFieldPath(d2),
      ]);
      expect(c.every((e) => e.value == null), true);
    });

    test('예전 방식으로 전체가 끝난 일정의 하루를 풀면 나머지 날은 날마다 완료로 옮긴다', () {
      final c = spanDayCompletionChanges(
        day: d2,
        nowDone: false,
        firstDay: d1,
        totalDays: 3,
        wholeDone: true,
      );
      final marked = {
        for (final e in c.where((e) => e.value == true)) e.path.last,
      };
      expect(marked, {occurrenceKey(d1), occurrenceKey(d3)});
      expect(
        c.any((e) => e.path.last == occurrenceKey(d2) && e.value == true),
        false,
        reason: '푼 날은 완료로 적지 않는다',
      );
    });

    test('옮긴 뒤 읽으면 푼 날만 미완료다(전체 완료 표시를 풀었다고 보고)', () {
      final c = spanDayCompletionChanges(
        day: d2,
        nowDone: false,
        firstDay: d1,
        totalDays: 3,
        wholeDone: true,
      );
      final map = {
        for (final e in c.where((e) => e.value == true)) e.path.last: true,
      };
      expect(isSpanDayCompleted(map, d1), true);
      expect(isSpanDayCompleted(map, d2), false);
      expect(isSpanDayCompleted(map, d3), true);
    });
  });
}
