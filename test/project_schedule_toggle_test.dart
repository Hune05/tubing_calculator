import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/data/repositories/work_project_repository.dart';

void main() {
  test('일정 하나의 완료 표시만 바꾸고 다른 일정은 그대로 둔다', () {
    final fresh = [
      {'id': 'a', 'title': '도면 검토', 'isCompleted': false},
      {'id': 'b', 'title': '다른 폰에서 넣은 일정', 'isCompleted': false},
    ];
    final r = scheduleListWithCompleted(fresh, 'a', true)!;
    expect(r.length, 2);
    expect(r[0]['isCompleted'], true);
    expect(r[1]['title'], '다른 폰에서 넣은 일정');
    expect(r[1]['isCompleted'], false);
    // 원래 목록은 건드리지 않는다.
    expect(fresh[0]['isCompleted'], false);
  });

  test('일정을 찾지 못하거나 목록이 없으면 아무것도 쓰지 않는다', () {
    expect(
      scheduleListWithCompleted(
        [
          {'id': 'a'},
        ],
        'z',
        true,
      ),
      isNull,
    );
    expect(scheduleListWithCompleted(null, 'a', true), isNull);
    expect(scheduleListWithCompleted('x', 'a', true), isNull);
  });
}
