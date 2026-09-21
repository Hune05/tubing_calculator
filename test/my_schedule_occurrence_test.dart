import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/schedule_logic.dart';

void main() {
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
