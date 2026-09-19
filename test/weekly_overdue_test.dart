import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/weekly_plan.dart';

void main() {
  test('overdue issues are flagged and sorted first', () {
    final now = DateTime.now();
    final logs = [
      {
        'id': 'a', 'name': 'A현장', 'status': 'ACTIVE',
        'phases': [], 'schedules': [], 'daily_reports': [],
        'punch_lists': [
          {'content': '여유건', 'priority': '여유', 'location': '1층', 'is_completed': false},
          {'content': '지연건', 'priority': '긴급', 'location': '2층', 'is_completed': false,
           'dueDate': now.subtract(const Duration(days: 3))},
        ],
      },
    ];
    final d = buildWeeklyPlanDoc(logs);
    final s = d.sections.last;
    expect(s.heading, '미해결 이슈 현황');
    expect(s.lines[0].contains('기한 초과 1건'), true);
    expect(s.lines[1].contains('지연건'), true);
    expect(s.lines[1].contains('초과 3일'), true);
    expect(s.lines[2].contains('기한'), false);
  });
}
