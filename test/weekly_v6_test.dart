import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_style.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/weekly_plan.dart';

String md(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

Map<String, dynamic> proj({
  String name = 'A현장',
  List<Map<String, dynamic>> reports = const [],
  List<Map<String, dynamic>> punches = const [],
}) => {
  'id': name,
  'name': name,
  'status': 'ACTIVE',
  'phases': [],
  'schedules': [],
  'daily_reports': reports,
  'punch_lists': punches,
};

void main() {
  _excludeStatsTest();
  setUp(() => ReportStyle.current = ReportStyle());

  test('weekly text uses 【】 section headings and keeps ■ for projects', () {
    final d = buildWeeklyPlanDoc([
      proj(
        reports: [
          {
            'date': md(DateTime.now()),
            'dateISO': DateTime.now().toIso8601String(),
            'note': '설치',
            'worker_count': 2,
          },
        ],
      ),
    ]);
    final t = d.toText();
    expect(t.contains('【금주 요약'), true);
    expect(t.contains('■ 금주 요약'), false);
    expect(t.contains('■ A현장'), true);
    expect(t.startsWith('[A현장] 주간 업무 보고'), true);
  });

  test('issues marked weeklyExclude are left out of the weekly report', () {
    final logs = [
      proj(
        punches: [
          {'content': '넣는것', 'is_completed': false},
          {'content': '뺀것', 'is_completed': false, 'weeklyExclude': true},
        ],
      ),
    ];
    final d = buildWeeklyPlanDoc(logs);
    final all = d.sections.expand((s) => s.lines).join('\n');
    expect(all.contains('넣는것'), true);
    expect(all.contains('뺀것'), false);
    expect(all.contains('미해결 1건'), true);
    // 제외한 이슈만 있으면 이슈 섹션 자체가 없다.
    final only = buildWeeklyPlanDoc([
      proj(
        punches: [
          {'content': 'x', 'is_completed': false, 'weeklyExclude': true},
        ],
      ),
    ]);
    expect(only.sections.any((s) => s.heading == '미해결 이슈 현황'), false);
  });

  test('photos and before/after follow the chosen base date', () {
    final today = DateTime.now();
    final old = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 21));
    Map<String, dynamic> rep(DateTime d, List<String> imgs, Map tags) => {
      'date': md(d),
      'dateISO': d.toIso8601String(),
      'image_paths': imgs,
      'image_tags': tags,
    };
    final logs = [
      proj(
        reports: [
          rep(old, ['oldB', 'oldA'], {'oldB': '작업 전', 'oldA': '작업 후'}),
          rep(today, ['newB', 'newA'], {'newB': '작업 전', 'newA': '작업 후'}),
        ],
      ),
    ];
    final now = buildWeeklyPlanDoc(logs, includePhotos: true);
    expect(now.photos.map((p) => p.path).toSet(), {'newB', 'newA'});
    expect(now.compares.single.before, 'newB');
    final past = buildWeeklyPlanDoc(logs, includePhotos: true, asOf: old);
    expect(past.photos.map((p) => p.path).toSet(), {'oldB', 'oldA'});
    expect(past.compares.single.before, 'oldB');
  });
}

void _excludeStatsTest() {
  test('excluded issues are also left out of per-project 이슈 신규 line', () {
    final now = DateTime.now();
    final logs = [
      proj(
        punches: [
          {
            'content': '뺀것',
            'is_completed': false,
            'weeklyExclude': true,
            'created_at': now,
          },
        ],
      ),
    ];
    final d = buildWeeklyPlanDoc(logs);
    final all = d.sections.expand((s) => s.lines).join('\n');
    expect(all.contains('이슈 신규'), true); // 요약 줄은 항상 있음(0건)
    expect(all.contains('이슈 신규 1건'), false);
    expect(all.contains('! 이슈'), false);
  });
}
