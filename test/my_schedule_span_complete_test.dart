// 여러 날(기간) 일정은 하루씩 따로 완료한다 — 하루만 끝내도 전체 일정이 끝나 버리던 것을 고침.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/schedule_logic.dart';

void main() {
  moveTests();
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

// ── 날짜 옮기기(끌어서·카드 메뉴)와 기간 진행 표시 ──
void moveTests() {
  group('일정 날짜 옮기기', () {
    test('하루 일정: 시각은 그대로, 날짜만 옮긴다', () {
      final f = movedScheduleFields({
        'dateTime': DateTime(2026, 10, 5, 14, 30).toIso8601String(),
        'hasTime': true,
      }, DateTime(2026, 10, 9));
      expect(f['dateTime'], DateTime(2026, 10, 9, 14, 30).toIso8601String());
      expect(f['endDate'], isNull);
      expect(f['endTime'], isNull);
    });

    test('끝나는 시각이 있으면 같은 길이만큼 따라 옮긴다', () {
      final f = movedScheduleFields({
        'dateTime': DateTime(2026, 10, 5, 14, 0).toIso8601String(),
        'endTime': DateTime(2026, 10, 5, 16, 30).toIso8601String(),
      }, DateTime(2026, 10, 7));
      expect(f['endTime'], DateTime(2026, 10, 7, 16, 30).toIso8601String());
    });

    test('기간 일정: 길이를 그대로 두고 종료일도 같이 옮긴다', () {
      final f = movedScheduleFields({
        'dateTime': DateTime(2026, 10, 5).toIso8601String(),
        'endDate': DateTime(2026, 10, 9).toIso8601String(),
      }, DateTime(2026, 10, 12));
      expect(f['dateTime'], DateTime(2026, 10, 12).toIso8601String());
      expect(f['endDate'], DateTime(2026, 10, 16).toIso8601String());
    });

    test('하루씩 적어 둔 완료 표시도 같은 만큼 옮긴다', () {
      final f = movedScheduleFields({
        'dateTime': DateTime(2026, 10, 5).toIso8601String(),
        'endDate': DateTime(2026, 10, 7).toIso8601String(),
        'completedOccurrences': {occurrenceKey(DateTime(2026, 10, 5)): true},
      }, DateTime(2026, 10, 12));
      expect(f['completedOccurrences'], {
        occurrenceKey(DateTime(2026, 10, 12)): true,
      });
    });

    test('날짜를 읽을 수 없으면 아무것도 바꾸지 않는다', () {
      expect(movedScheduleFields({'dateTime': 'x'}, DateTime(2026, 10, 9)), isEmpty);
      expect(movedScheduleFields({}, DateTime(2026, 10, 9)), isEmpty);
    });

    test('되돌리기용 지금 값을 그대로 돌려준다(옮기고 되돌리면 원래대로)', () {
      final data = <String, dynamic>{
        'dateTime': DateTime(2026, 10, 5, 9).toIso8601String(),
        'endDate': DateTime(2026, 10, 7).toIso8601String(),
        'endTime': null,
      };
      final before = scheduleDateFields(data);
      expect(before['dateTime'], data['dateTime']);
      expect(before['endDate'], data['endDate']);
      expect(before['completedOccurrences'], <String, dynamic>{});
    });
  });

  group('기간 일정 진행 표시', () {
    test('끝낸 날 수를 센다', () {
      final done = {
        occurrenceKey(DateTime(2026, 10, 5)): true,
        occurrenceKey(DateTime(2026, 10, 7)): true,
      };
      expect(spanDoneCount(done, DateTime(2026, 10, 5), 5), 2);
      expect(spanDoneCount(null, DateTime(2026, 10, 5), 5), 0);
    });

    test('예전 방식으로 전체가 끝난 일정은 전부 센다', () {
      expect(spanDoneCount({}, DateTime(2026, 10, 5), 4, wholeDone: true), 4);
    });
  });
}
