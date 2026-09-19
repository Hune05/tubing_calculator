import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_phase.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/weekly_plan.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/notification_check_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/weekly_report_page.dart';

String md(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

Map<String, dynamic> proj(
  String name, {
  String status = 'ACTIVE',
  int? remind,
  DateTime? completedAt,
  List<Map<String, dynamic>> punches = const [],
  bool reportToday = true,
}) {
  final t = DateTime.now();
  return {
    'id': name,
    'name': name,
    'status': status,
    'phases': [],
    'schedules': [],
    'punch_lists': punches,
    'reportReminderMinutes': ?remind,
    'completedAt': ?completedAt,
    'daily_reports': reportToday
        ? [
            {
              'date': md(t),
              'dateISO': DateTime(t.year, t.month, t.day).toIso8601String(),
              'note': '$name 작업',
              'worker_count': 1,
            },
          ]
        : [],
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

  test('plans carry the names of the projects grouped in each time', () {
    final now = DateTime(2026, 9, 19, 10);
    final plans = planDailyReminders(
      [
        proj('A', reportToday: false),
        proj('B', reportToday: false),
        proj('C', reportToday: false, remind: 21 * 60),
      ],
      18 * 60,
      now,
    );
    expect(plans[0].names, ['A', 'B']);
    expect(plans[1].names, ['C']);
    expect(plans[1].name, 'C');
    expect(plans[0].name, isNull);
  });

  testWidgets('notification check lists which projects get which time', (
    tester,
  ) async {
    await pump(
      tester,
      NotificationCheckPage(
        logs: [
          proj('기본A', reportToday: false),
          proj('기본B', reportToday: false),
          proj('밤에', reportToday: false, remind: 21 * 60),
          proj('끝난곳', status: 'DONE'),
        ],
      ),
    );
    expect(find.textContaining('· 18:00  기본A, 기본B'), findsOneWidget);
    expect(find.textContaining('· 21:00  밤에'), findsOneWidget);
    expect(find.textContaining('끝난곳'), findsNothing); // 완료 프로젝트는 알림 대상이 아니다
    expect(findTextContaining('프로젝트 화면 ⋮ 메뉴'), findsOneWidget);
  });

  testWidgets('notification check without logs shows no per-project list', (
    tester,
  ) async {
    await pump(tester, const NotificationCheckPage());
    expect(find.textContaining('· 18:00'), findsNothing);
  });

  test(
    'withOpenIssues keeps only projects that still have unresolved issues',
    () {
      final logs = [
        proj(
          '이슈있음',
          punches: [
            {'is_completed': false},
          ],
        ),
        proj(
          '다처리',
          punches: [
            {'is_completed': true},
          ],
        ),
        proj('이슈없음'),
      ];
      expect(withOpenIssues(logs).map((e) => e['name']).toList(), ['이슈있음']);
      expect(withOpenIssues([]), isEmpty);
    },
  );

  test(
    'reopening a completed project removes it from the weekly completions',
    () {
      final p = proj('B', status: 'DONE', completedAt: DateTime.now());
      bool listed() => buildWeeklyPlanDoc([
        proj('A'),
        p,
      ]).sections.first.lines.any((l) => l.contains('금주 완료 · B'));
      expect(listed(), true);
      // 메인 화면의 _toggleProjectStatus와 같은 변화: 진행중으로 되돌리며 completedAt 제거
      p['status'] = 'ONGOING';
      p.remove('completedAt');
      expect(listed(), false);
      // 완료일만 남아 있어도 진행중이면 완료로 세지 않는다.
      p['completedAt'] = DateTime.now();
      expect(listed(), false);
    },
  );

  testWidgets(
    'weekly page drops the completion line after the project is reopened',
    (tester) async {
      final done = proj('완료B', status: 'DONE', completedAt: DateTime.now());
      final a = proj('A');
      await pump(
        tester,
        WeeklyReportPage(
          logs: [a, done],
          // 프로젝트 화면에서 "다시 진행중으로"를 누른 것과 같은 변화.
          onOpenProject: (l) {
            l['status'] = 'ONGOING';
            l.remove('completedAt');
          },
        ),
      );
      final line = find.textContaining('금주 완료 · 완료B');
      expect(line, findsOneWidget);
      await tester.tap(line);
      await tester.pumpAndSettle();
      expect(find.textContaining('금주 완료 · 완료B'), findsNothing);
      // 이제 진행중이라 진행률 카드에도 나타난다.
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    },
  );

  group('overview card rows', () {
    testWidgets('tapping a row opens that project and refreshes on return', (
      tester,
    ) async {
      final a = proj('A현장');
      Map<String, dynamic>? opened;
      var loads = 0;
      await pump(
        tester,
        WeeklyReportPage(
          logs: [a, proj('B현장')],
          onOpenProject: (l) => opened = l,
          reload: () async {
            loads++;
            return [a, proj('B현장'), proj('새로생김')];
          },
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
      // 진행률 카드의 첫 행(막대를 감싼 InkWell)을 누른다. 상단 필터 칩과 구별하려는 것.
      await tester.tap(
        find
            .ancestor(
              of: find.byType(LinearProgressIndicator).first,
              matching: find.byType(InkWell),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(identical(opened, a), true);
      expect(loads, 1);
      // 돌아온 뒤 다시 읽어 새 프로젝트가 카드에 나타난다.
      expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
    });

    testWidgets('rows are not tappable without an open handler', (
      tester,
    ) async {
      await pump(tester, WeeklyReportPage(logs: [proj('A현장')]));
      // 화살표는 열기 기능이 있을 때만 있다(기준일 줄의 것 하나만 남는다).
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      await tester.tap(find.byType(LinearProgressIndicator).first);
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });
}
