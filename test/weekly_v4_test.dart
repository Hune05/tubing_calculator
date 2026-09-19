import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/weekly_plan.dart';

void main() {
  _noDue();
  test('issue before/after photos become a compare when resolved this week', () {
    final now = DateTime.now();
    final logs = [
      {
        'id': 'a', 'name': 'A현장', 'status': 'ACTIVE',
        'phases': [], 'schedules': [], 'daily_reports': [],
        'punch_lists': [
          {
            'content': '누수', 'location': '2층', 'is_completed': true,
            'resolved_at': now,
            'image_paths': ['before.jpg'],
            'resolution_images': ['after.jpg'],
          },
          {
            'content': '사진없음', 'is_completed': true, 'resolved_at': now,
            'image_paths': [], 'resolution_images': [],
          },
        ],
      },
    ];
    final d = buildWeeklyPlanDoc(logs, includePhotos: true);
    expect(d.compares.length, 1);
    expect(d.compares.first.before, 'before.jpg');
    expect(d.compares.first.after, 'after.jpg');
    expect(d.compares.first.label.contains('2층'), true);
    expect(buildWeeklyPlanDoc(logs).compares, isEmpty);
  });

  test('final report adds totals and retro', () {
    final today = DateTime.now();
    final log = <String, dynamic>{
      'name': 'A현장', 'status': 'DONE', 'date': '2026-09-01', 'revision': 'r1',
      'phases': [], 'schedules': [],
      'completedAt': today,
      'retro': {'cause': '자재 지연', 'lesson': '발주 먼저'},
      'punch_lists': [
        {'is_completed': true},
        {'is_completed': false},
      ],
      'daily_reports': [
        for (final i in [1, 2])
          {
            'date': '09/0$i',
            'dateISO': DateTime(today.year, today.month, today.day - 3 + i).toIso8601String(),
            'worker_count': 2, 'points': 10, 'wiring_points': 5,
          },
      ],
    };
    final d = buildFinalReportDoc(log);
    final stats = d.sections[1];
    expect(stats.heading, '총 통계');
    expect(stats.lines.join('\n').contains('총 투입 4인·일'), true);
    expect(stats.lines.join('\n').contains('벤딩 총 20 pt'), true);
    expect(stats.lines.join('\n').contains('2건 중 1건 처리'), true);
    expect(d.sections.last.heading, '회고');
    expect(d.sections.last.lines.join().contains('발주 먼저'), true);
  });
}

void _noDue() {
  test('open issues without a due date are flagged 기한 미정', () {
    final logs = [
      {
        'id': 'a', 'name': 'A현장', 'status': 'ACTIVE',
        'phases': [], 'schedules': [], 'daily_reports': [],
        'punch_lists': [
          {'content': '기한없음', 'location': '1층', 'is_completed': false},
        ],
      },
    ];
    final d = buildWeeklyPlanDoc(logs);
    final s = d.sections.last;
    expect(s.lines[0].contains('기한 미정 1건'), true);
    expect(s.lines[1].contains('기한 미정'), true);
  });
}
