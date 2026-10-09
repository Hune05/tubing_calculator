import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_phase.dart';

void main() {
  test('progress delta vs last week', () {
    final now = DateTime(2026, 9, 19);
    final log = <String, dynamic>{
      'phases': [
        {'id': 'a', 'name': 'A', 'isCompleted': true},
        {'id': 'b', 'name': 'B', 'isCompleted': false},
      ],
      'progressHistory': {'2026-09-10': 10, '2026-09-12': 20, '2026-09-18': 40},
    };
    expect(progressDeltaSince(log, 7, now), 30); // 50 - 20
    expect(recordProgressSnapshot(log, now), true);
    expect(recordProgressSnapshot(log, now), false);
    expect(progressDeltaSince({'phases': []}, 7, now), isNull);
  });

  test('일지를 열 때 진행률만 바뀌면 그 칸만 쓴다(문서 통째로 다시 쓰지 않음, 8차)', () {
    final now = DateTime(2026, 10, 9);
    final log = <String, dynamic>{
      'id': 'p1',
      'phasesMigrated': true,
      'phases': [
        {'id': 'a', 'name': 'A', 'isCompleted': true},
      ],
    };
    expect(prepareProjectOnOpen(log, now), ProjectOpenWrite.progressOnly);
    expect((log['progressHistory'] as Map)['2026-10-09'], 100);
    expect(prepareProjectOnOpen(log, now), ProjectOpenWrite.none);
    // 단계가 없던 옛 프로젝트는 이전 때문에 통째로 쓴다.
    final old = <String, dynamic>{'id': 'p2', 'schedules': []};
    expect(prepareProjectOnOpen(old, now), ProjectOpenWrite.whole);
  });
}
