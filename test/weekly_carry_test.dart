import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/weekly_plan.dart';

void main() {
  test('unfinished last-week schedule is carried over; older is late; summary first', () {
    final now = DateTime.now();
    final mon = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final logs = [
      {
        'id': 'a', 'name': 'A현장', 'status': 'ACTIVE', 'phases': [], 'daily_reports': [],
        'schedules': [
          {'id': 's1', 'title': '전주끝', 'isCompleted': false,
           'dateTime': mon.subtract(const Duration(days: 4)), 'endDate': mon.subtract(const Duration(days: 3))},
          {'id': 's2', 'title': '오래전', 'isCompleted': false,
           'dateTime': mon.subtract(const Duration(days: 20)), 'endDate': mon.subtract(const Duration(days: 19))},
        ],
      },
    ];
    final d = buildWeeklyPlanDoc(logs);
    expect(d.sections.first.heading.startsWith('금주 요약'), true);
    final all = d.sections.expand((s) => s.lines).join('\n');
    // 금주가 월요일이면 today가 그 주에 속하므로 항상 성립
    expect(all.contains('전주끝 (전주 이월)'), true);
    expect(all.contains('오래전 (지연)'), true);
  });
}
