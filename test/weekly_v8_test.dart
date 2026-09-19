import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/weekly_plan.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/weekly_report_page.dart';

String md(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

Map<String, dynamic> proj(
  String name, {
  List<Map<String, dynamic>> punches = const [],
}) {
  final t = DateTime.now();
  return {
    'id': name,
    'name': name,
    'status': 'ACTIVE',
    'phases': [],
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

  test('uniquePdfName appends (2), (3) when the file already exists', () {
    final taken = <String>{'a.pdf', 'a(2).pdf'};
    expect(uniquePdfName('b.pdf', taken.contains), 'b.pdf');
    expect(uniquePdfName('a.pdf', taken.contains), 'a(3).pdf');
    expect(uniquePdfName('a.pdf', (n) => n == 'a.pdf'), 'a(2).pdf');
  });

  test('weekly doc notes how many open issues were excluded', () {
    final logs = [
      proj(
        'A',
        punches: [
          {'content': '넣음', 'is_completed': false},
          {'content': '뺌1', 'is_completed': false, 'weeklyExclude': true},
          {'content': '뺌2', 'is_completed': false, 'weeklyExclude': true},
          // 완료된 이슈는 제외 표시가 있어도 "미해결 제외" 건수에 안 센다.
          {'content': '완료', 'is_completed': true, 'weeklyExclude': true},
        ],
      ),
    ];
    final d = buildWeeklyPlanDoc(logs);
    final ref = d.sections.last;
    expect(ref.heading, '참고');
    expect(ref.lines.single.contains('2건'), true);
    final none = buildWeeklyPlanDoc([proj('A')]);
    expect(none.sections.any((s) => s.heading == '참고'), false);
    expect(d.toText().contains('제외한 미해결 이슈 2건'), true);
  });

  testWidgets('collapsed state is remembered across page reopen', (
    tester,
  ) async {
    final logs = [proj('A현장'), proj('B현장')];
    await pump(tester, WeeklyReportPage(logs: logs));
    await tester.tap(find.text('모두 접기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('A현장 작업'), findsNothing);
    // 저장된 값에는 날짜 범위가 들어 있지 않아야 한다.
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('weekly_report_collapsed')!;
    expect(saved.isNotEmpty, true);
    expect(saved.every((k) => !k.contains('/')), true);

    // 페이지를 새로 열어도 그대로 접혀 있다.
    await pump(tester, const SizedBox());
    await pump(tester, WeeklyReportPage(logs: logs));
    expect(find.textContaining('A현장 작업'), findsNothing);
    expect(find.textContaining('■ A현장'), findsWidgets);
  });

  testWidgets('swiping an issue line excludes it and can be undone', (
    tester,
  ) async {
    final punch = <String, dynamic>{
      'content': '밀어서제외',
      'location': '2층',
      'is_completed': false,
    };
    final log = proj('A현장', punches: [punch]);
    final changed = <Map<String, dynamic>>[];
    await pump(
      tester,
      WeeklyReportPage(
        logs: [log],
        onOpenIssue: (l, p) {},
        onIssueChanged: changed.add,
      ),
    );
    expect(find.textContaining('밀어서제외'), findsOneWidget);
    await tester.drag(find.textContaining('밀어서제외'), const Offset(-800, 0));
    await tester.pumpAndSettle();
    expect(punch['weeklyExclude'], true);
    expect(changed.length, 1);
    expect(find.textContaining('밀어서제외'), findsNothing);
    expect(find.text('이 이슈를 주간 보고에서 뺐습니다.'), findsOneWidget);

    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(punch.containsKey('weeklyExclude'), false);
    expect(changed.length, 2);
    expect(find.textContaining('밀어서제외'), findsOneWidget);
  });

  testWidgets('without onIssueChanged the issue line is not swipeable', (
    tester,
  ) async {
    final punch = <String, dynamic>{
      'content': '안밀림',
      'is_completed': false,
    };
    await pump(
      tester,
      WeeklyReportPage(
        logs: [
          proj('A현장', punches: [punch]),
        ],
        onOpenIssue: (l, p) {},
      ),
    );
    await tester.drag(find.textContaining('안밀림'), const Offset(-800, 0));
    await tester.pumpAndSettle();
    expect(punch.containsKey('weeklyExclude'), false);
    expect(find.textContaining('안밀림'), findsOneWidget);
  });
}
