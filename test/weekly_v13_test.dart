import 'package:flutter/material.dart';
import 'helpers_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_phase.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/project_detail_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/weekly_report_page.dart';

String md(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

Map<String, dynamic> proj(
  String name, {
  bool reportToday = true,
  String status = 'ACTIVE',
  int? remind,
  List<Map<String, dynamic>> punches = const [],
  List<Map<String, dynamic>> phases = const [],
  DateTime? completedAt,
}) {
  final t = DateTime.now();
  return {
    'id': name,
    'name': name,
    'status': status,
    'phases': phases,
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

  group('planDailyReminders', () {
    // 2026-09-19 10:00
    final now = DateTime(2026, 9, 19, 10, 0);

    test('projects sharing a time become one notification', () {
      final plans = planDailyReminders(
        [proj('A', reportToday: false), proj('B', reportToday: false)],
        18 * 60,
        now,
      );
      expect(plans.length, 1);
      expect(plans.single.minutes, 18 * 60);
      expect(plans.single.count, 2);
      expect(plans.single.at, DateTime(2026, 9, 19, 18, 0)); // 오늘
      expect(plans.single.name, isNull); // 여러 곳이면 이름 없음
    });

    test('per-project time makes separate notifications, sorted by time', () {
      final plans = planDailyReminders(
        [
          proj('기본', reportToday: false),
          proj('이른곳', reportToday: false, remind: 7 * 60 + 30),
          proj('밤', reportToday: false, remind: 21 * 60),
        ],
        18 * 60,
        now,
      );
      expect(plans.map((p) => p.minutes).toList(), [450, 1080, 1260]);
      expect(plans[0].name, '이른곳');
      expect(plans[0].at, DateTime(2026, 9, 20, 7, 30)); // 이미 지나 내일
      expect(plans[0].count, 1); // 내일 알림은 진행중 프로젝트 수
      expect(plans[1].at, DateTime(2026, 9, 19, 18, 0));
      expect(plans[2].at, DateTime(2026, 9, 19, 21, 0));
    });

    test('a group whose projects all wrote today skips to tomorrow', () {
      final plans = planDailyReminders(
        [
          proj('썼음', reportToday: true),
          proj('안썼음', reportToday: false, remind: 20 * 60),
        ],
        18 * 60,
        now,
      );
      expect(plans.length, 2);
      final wrote = plans.firstWhere((p) => p.minutes == 18 * 60);
      expect(wrote.at, DateTime(2026, 9, 20, 18, 0));
      final not = plans.firstWhere((p) => p.minutes == 20 * 60);
      expect(not.at, DateTime(2026, 9, 19, 20, 0));
      expect(not.count, 1);
    });

    test('invalid minutes fall back to the default; overflow groups merge', () {
      final bad = planDailyReminders(
        [proj('A', remind: -5), proj('B', remind: 5000)],
        600,
        now,
      );
      expect(bad.length, 1);
      expect(bad.single.minutes, 600);
      // 시간이 9종류면 8개로 줄이고 넘친 프로젝트는 마지막 묶음에 합친다.
      final many = planDailyReminders(
        [
          for (var i = 0; i < 9; i++)
            proj('P$i', reportToday: false, remind: 60 * (i + 1)),
        ],
        600,
        now,
      );
      expect(many.length, 8);
      expect(many.last.count, 2); // 8번째 + 넘친 9번째
    });

    test('no active projects means no notifications', () {
      expect(planDailyReminders([], 1080, now), isEmpty);
    });

    test('notification body names a single-project notification', () {
      expect(
        dailyReminderBody(1, name: '루마'),
        '루마 오늘 작업 일보를 아직 작성하지 않았습니다. 눌러서 바로 남겨 두십시오.',
      );
      expect(dailyReminderBody(1), startsWith('오늘 작업 일보'));
      expect(dailyReminderBody(3, name: '루마'), contains('3곳'));
    });
  });

  test(
    'openIssueCount counts unresolved issues regardless of weekly exclusion',
    () {
      final log = proj(
        'A',
        punches: [
          {'is_completed': false},
          {'is_completed': false, 'weeklyExclude': true},
          {'is_completed': true},
        ],
      );
      expect(openIssueCount(log), 2);
      expect(openIssueCount(proj('B')), 0);
    },
  );

  group('completion confirm', () {
    Future<List<String>> pumpDetail(
      WidgetTester tester,
      Map<String, dynamic> log,
    ) async {
      final calls = <String>[];
      await pump(
        tester,
        ProjectDetailPage(
          log: log,
          actions: ProjectActions(
            addPunch: () async {},
            openPunch: (_) async {},
            addReport: () async {},
            openReport: (_) async {},
            openReportCalendar: () async {},
            openSchedule: ({String? phaseId, bool add = false}) async {},
            save: () {},
            toggleStatus: () {
              calls.add('toggle');
              log['status'] = log['status'] == 'DONE' ? 'ONGOING' : 'DONE';
            },
            toggleArchive: () {},
            delete: () {},
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('프로젝트 완료 처리'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      return calls;
    }

    testWidgets('open issues: cancel keeps the project active', (tester) async {
      final log = proj(
        'A',
        punches: [
          {'content': 'x', 'is_completed': false},
        ],
      );
      final calls = await pumpDetail(tester, log);
      await tester.tap(find.text('프로젝트 완료 처리'));
      await tester.pumpAndSettle();
      expect(findText('미해결 이슈가 남아 있습니다'), findsOneWidget);
      expect(findTextContaining('이슈 1건'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(log['status'], 'ACTIVE');
    });

    testWidgets('open issues: 그래도 완료 completes it', (tester) async {
      final log = proj(
        'A',
        punches: [
          {'content': 'x', 'is_completed': false},
        ],
      );
      final calls = await pumpDetail(tester, log);
      await tester.tap(find.text('프로젝트 완료 처리'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('그래도 완료'));
      await tester.pumpAndSettle();
      expect(calls, ['toggle']);
      expect(log['status'], 'DONE');
    });

    testWidgets('open issues: 이슈 보기 jumps to the issues tab, no completion', (
      tester,
    ) async {
      final log = proj(
        'A',
        punches: [
          {'content': '탭이동확인', 'location': '1층', 'is_completed': false},
        ],
      );
      final calls = await pumpDetail(tester, log);
      await tester.tap(find.text('프로젝트 완료 처리'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('이슈 보기'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(log['status'], 'ACTIVE');
      // 이슈 탭의 이슈 목록이 보인다.
      expect(find.text('이슈 목록'), findsOneWidget);
    });

    testWidgets('no open issues: completes without asking', (tester) async {
      final log = proj(
        'A',
        punches: [
          {'content': 'x', 'is_completed': true},
        ],
      );
      final calls = await pumpDetail(tester, log);
      await tester.tap(find.text('프로젝트 완료 처리'));
      await tester.pump();
      expect(findText('미해결 이슈가 남아 있습니다'), findsNothing);
      expect(calls, ['toggle']);
    });
  });

  group('weekly overview card', () {
    testWidgets('shows one progress bar per active project', (tester) async {
      await pump(
        tester,
        WeeklyReportPage(
          logs: [
            proj(
              'A',
              phases: [
                {'id': 'p1', 'name': 'P', 'isCompleted': true},
                {'id': 'p2', 'name': 'Q', 'isCompleted': false},
              ],
            ),
            proj('B'),
            proj('끝', status: 'DONE'),
          ],
        ),
      );
      expect(find.text('이번 주 한눈에'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('hidden when viewing a past base date', (tester) async {
      await pump(tester, WeeklyReportPage(logs: [proj('A')]));
      expect(find.text('이번 주 한눈에'), findsOneWidget);
      // 날짜 선택 창에서 오늘 이전 날짜를 고른다(창은 오늘이 미리 골라져 있다).
      await tester.tap(find.text('기준일: 오늘'));
      await tester.pumpAndSettle();
      // 달력 위쪽 "이전 달" 버튼(Semantics 이름 기준)으로 한 달 뒤로 간 뒤 1일을 고른다.
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('이번 주 한눈에'), findsNothing);
      // "오늘로"를 누르면 다시 보인다.
      await tester.tap(find.text('오늘로'));
      await tester.pumpAndSettle();
      expect(find.text('이번 주 한눈에'), findsOneWidget);
    });
  });

  testWidgets('tapping a "금주 완료" line opens that project', (tester) async {
    final done = proj('완료B', status: 'DONE', completedAt: DateTime.now());
    Map<String, dynamic>? opened;
    await pump(
      tester,
      WeeklyReportPage(
        logs: [proj('A'), done],
        onOpenProject: (l) => opened = l,
      ),
    );
    final line = find.textContaining('금주 완료 · 완료B');
    expect(line, findsOneWidget);
    await tester.tap(line);
    await tester.pumpAndSettle();
    expect(identical(opened, done), true);
  });

  testWidgets('a "금주 완료" line is plain text without an open handler', (
    tester,
  ) async {
    await pump(
      tester,
      WeeklyReportPage(
        logs: [proj('완료B', status: 'DONE', completedAt: DateTime.now())],
      ),
    );
    expect(find.textContaining('금주 완료 · 완료B'), findsOneWidget);
  });
}
