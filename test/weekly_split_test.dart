import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/weekly_plan.dart';

void main() {
  test('perProject splits into 3 sections per project, new page after first', () {
    final logs = [
      {'id': 'a', 'name': 'A현장', 'status': 'ACTIVE', 'phases': [], 'schedules': [], 'daily_reports': []},
      {'id': 'b', 'name': 'B현장', 'status': 'ACTIVE', 'phases': [], 'schedules': [], 'daily_reports': []},
    ];
    final d = buildWeeklyPlanDoc(logs, perProject: true);
    expect(d.sections.length, 7); // 요약 1 + 3x2
    expect(d.sections[1].newPage, false);
    expect(d.sections[4].newPage, true);
    expect(d.sections[4].heading.startsWith('B현장 · 지난주'), true);
    final c = buildWeeklyPlanDoc(logs);
    expect(c.sections.length, 4);
  });
}

