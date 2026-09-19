import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_phase.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/weekly_plan.dart';

void main() {
  test('issueOverdueDays counts only open issues past due', () {
    final now = DateTime(2026, 9, 19);
    expect(
      issueOverdueDays({'dueDate': DateTime(2026, 9, 16)}, now),
      3,
    );
    expect(issueOverdueDays({'dueDate': DateTime(2026, 9, 19)}, now), 0);
    expect(issueOverdueDays({'dueDate': DateTime(2026, 9, 25)}, now), 0);
    expect(
      issueOverdueDays({'dueDate': DateTime(2026, 9, 1), 'is_completed': true}, now),
      0,
    );
    expect(issueOverdueDays({}, now), 0);
    expect(
      overdueIssueCount({
        'punch_lists': [
          {'dueDate': DateTime.now().subtract(const Duration(days: 2))},
          {'content': 'x'},
        ],
      }),
      1,
    );
  });

  Map<String, dynamic> proj(String id, String name, {bool tagged = false}) {
    final today = DateTime.now();
    String md(DateTime d) =>
        '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    return {
      'id': id,
      'name': name,
      'status': 'ACTIVE',
      'phases': [],
      'schedules': [],
      'punch_lists': [
        {'content': '미해결', 'is_completed': false},
      ],
      'daily_reports': [
        {
          'date': md(today),
          'dateISO': DateTime(today.year, today.month, today.day).toIso8601String(),
          'image_paths': tagged ? ['b1', 'a1', 'b2', 'a2', 'b3'] : [],
          'image_tags': tagged
              ? {'b1': '작업 전', 'a1': '작업 후', 'b2': '작업 전', 'a2': '작업 후', 'b3': '작업 전'}
              : {},
        },
      ],
    };
  }

  test('before/after photos are paired in order (extra unpaired dropped)', () {
    final d = buildWeeklyPlanDoc([proj('a', 'A현장', tagged: true)], includePhotos: true);
    expect(d.compares.length, 2);
    expect(d.compares[0].before, 'b1');
    expect(d.compares[0].after, 'a1');
    expect(d.compares[1].before, 'b2');
    expect(d.compares[1].after, 'a2');
    final off = buildWeeklyPlanDoc([proj('a', 'A현장', tagged: true)]);
    expect(off.compares, isEmpty);
  });

  test('multi-project summary has one line per project', () {
    final d = buildWeeklyPlanDoc([proj('a', 'A현장'), proj('b', 'B현장')]);
    final lines = d.sections.first.lines;
    expect(lines.where((l) => l.contains('■ A현장')).length, 1);
    expect(lines.where((l) => l.contains('■ B현장')).length, 1);
    expect(lines.any((l) => l.contains('미해결 이슈 1건')), true);
    final one = buildWeeklyPlanDoc([proj('a', 'A현장')]);
    expect(one.sections.first.lines.any((l) => l.contains('■')), false);
  });
}
