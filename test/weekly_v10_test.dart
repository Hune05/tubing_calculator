import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_phase.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/punch_detail_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/storage_management_page.dart'
    show isAppTempFileName;
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/weekly_report_page.dart';

String md(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

Map<String, dynamic> proj(
  String name, {
  List<Map<String, dynamic>> punches = const [],
  int pct = 0,
}) {
  final t = DateTime.now();
  return {
    'id': name,
    'name': name,
    'status': 'ACTIVE',
    'phases': pct == 0
        ? []
        : [
            {'id': 'p1', 'name': 'P', 'isCompleted': true},
            {'id': 'p2', 'name': 'Q', 'isCompleted': false},
          ],
    'schedules': [],
    'punch_lists': punches,
    'daily_reports': [
      {
        'date': md(t),
        'dateISO': DateTime(t.year, t.month, t.day).toIso8601String(),
        'note': '$name 작업',
        'worker_count': 1,
      },
    ],
  };
}

Future<void> pump(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: w));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('weekly-exclude helpers are the single source of truth', () {
    final p = <String, dynamic>{'content': 'x'};
    expect(issueWeeklyExcluded(p), false);
    setIssueWeeklyExcluded(p, true);
    expect(p['weeklyExclude'], true);
    expect(issueWeeklyExcluded(p), true);
    setIssueWeeklyExcluded(p, false);
    expect(p.containsKey('weeklyExclude'), false);
  });

  testWidgets('issue detail switch reflects and changes the excluded state', (
    tester,
  ) async {
    // 주간 보고에서 밀어서 제외한 이슈 → 상세의 스위치는 꺼져 있어야 한다.
    final punch = <String, dynamic>{
      'content': '상세확인',
      'location': '2층',
      'is_completed': false,
      'created_at': DateTime.now(),
    };
    setIssueWeeklyExcluded(punch, true);
    Map<String, dynamic>? popped;
    await pump(
      tester,
      Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () async {
              popped = await Navigator.push<Map<String, dynamic>>(
                ctx,
                MaterialPageRoute(
                  builder: (_) => PunchDetailPage(punch: punch),
                ),
              );
            },
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    final sw = find.widgetWithText(SwitchListTile, '주간 보고에 포함');
    await tester.scrollUntilVisible(
      sw,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<SwitchListTile>(sw).value, false);

    // 켜면 제외가 풀린 채로 돌아온다(변경 사항이 반환값에 담긴다).
    await tester.tap(sw);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(sw).value, true);
    await tester.tap(find.byIcon(AppIcons.back));
    await tester.pumpAndSettle();
    expect(popped, isNotNull);
    expect(issueWeeklyExcluded(popped!), false);
    // 원본은 그대로(상세는 복사본을 고친다) — 호출한 쪽이 반환값으로 교체한다.
    expect(issueWeeklyExcluded(punch), true);
  });

  testWidgets('collapsed project shows a one-line summary next to its name', (
    tester,
  ) async {
    await pump(
      tester,
      WeeklyReportPage(logs: [proj('A현장', pct: 50), proj('B현장')]),
    );
    await tester.tap(find.text('모두 접기'));
    await tester.pumpAndSettle();
    // 진행률 줄이 있는 섹션에서는 진행률이 이름 옆에 보인다.
    expect(find.textContaining('■ A현장  ·  진행률 50%'), findsWidgets);
    // 진행률 줄이 없는 섹션(이슈 등)에서는 줄 수가 보인다.
    expect(find.textContaining('■ B현장  ·  진행률 0%'), findsWidgets);
  });

  testWidgets('reload refreshes the report after returning from a project', (
    tester,
  ) async {
    final a = proj('A현장');
    var loads = 0;
    await pump(
      tester,
      WeeklyReportPage(
        logs: [a],
        onOpenProject: (_) {},
        reload: () async {
          loads++;
          // 다녀온 사이에 새 이슈가 생겼다고 치자.
          return [
            proj(
              'A현장',
              punches: [
                {'content': '새로생김', 'is_completed': false},
              ],
            ),
          ];
        },
      ),
    );
    expect(find.textContaining('새로생김'), findsNothing);
    await tester.tap(find.byIcon(Icons.open_in_new_rounded).first);
    await tester.pumpAndSettle();
    expect(loads, 1);
    expect(find.textContaining('새로생김'), findsOneWidget);
  });

  test(
    'runPdfCleanup records last run, last removed and running total',
    () async {
      final dir = await Directory.systemTemp.createTemp('pdfrec');
      addTearDown(() => dir.delete(recursive: true));
      final now = DateTime(2026, 9, 19, 14, 50);
      File('${dir.path}/a.pdf')
        ..writeAsStringSync('x')
        ..setLastModifiedSync(now.subtract(const Duration(days: 9)));
      File('${dir.path}/b.pdf')
        ..writeAsStringSync('x')
        ..setLastModifiedSync(now.subtract(const Duration(days: 4)));
      expect((await loadPdfCleanupRecord()).lastRun, isNull);

      expect(await runPdfCleanup(dir, now: now), 2);
      var r = await loadPdfCleanupRecord();
      expect(r.lastRun, now);
      expect(r.lastRemoved, 2);
      expect(r.total, 2);

      // 두 번째 실행은 지울 게 없어도 기록은 갱신되고 누적은 유지된다.
      final later = now.add(const Duration(days: 1));
      expect(await runPdfCleanup(dir, now: later), 0);
      r = await loadPdfCleanupRecord();
      expect(r.lastRun, later);
      expect(r.lastRemoved, 0);
      expect(r.total, 2);
    },
  );

  test('storage page counts renamed PDFs as temp files', () {
    expect(isAppTempFileName('report_123.pdf'), true);
    expect(isAppTempFileName('루마_주간_업무_보고_20260919.pdf'), true);
    expect(isAppTempFileName('루마_주간_업무_보고_20260919(2).PDF'), true);
    expect(isAppTempFileName('up_1.jpg'), true);
    expect(isAppTempFileName('notes.txt'), false);
    expect(isAppTempFileName('photo.jpg'), false);
  });
}
