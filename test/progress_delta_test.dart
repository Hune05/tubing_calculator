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
}
