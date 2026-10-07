// 일지 달력에서 돌아온 목록 중 실제로 고친 일지만 고르는 비교(10-07).
// 달력은 복사본으로 고치므로, 같은 객체인지(==)로 보면 모든 일지가 "바뀜"으로 잡혀
// 되돌려 둔 이슈·일정이 다시 완료로 바뀌고 모든 일지에 지금 고친 사람·시각이 찍혔다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_phase.dart';

void main() {
  final a = {
    'id': 'r1',
    'date': '10/07',
    'completedScheduleIds': ['s1'],
    'tasks': [
      {'t': '배관', 'h': 8},
    ],
    'scheduleNoApply': true,
  };

  test('복사본은 같은 일지로 본다(안쪽 목록·맵까지)', () {
    final copy = Map<String, dynamic>.from(a);
    expect(identical(copy, a), isFalse);
    expect([a].contains(copy), isFalse); // 예전 비교는 이렇게 "바뀜"으로 잡았다
    expect(sameReportValue(copy, a), isTrue);
  });

  test('글자·안쪽 값이 하나라도 다르면 다른 일지로 본다', () {
    expect(sameReportValue({...a, 'date': '10/08'}, a), isFalse);
    expect(
      sameReportValue({
        ...a,
        'tasks': [
          {'t': '배관', 'h': 9},
        ],
      }, a),
      isFalse,
    );
    expect(sameReportValue({...a, 'memo': ''}, a), isFalse);
  });
}
