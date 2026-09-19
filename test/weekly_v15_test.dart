import 'package:flutter/material.dart';
import 'helpers_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_phase.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/notification_check_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/project_detail_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/weekly_report_page.dart';

String md(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

Map<String, dynamic> proj(
  String name, {
  String status = 'ACTIVE',
  int? remind,
  List<Map<String, dynamic>> punches = const [],
  List<Map<String, dynamic>> phases = const [],
  DateTime? due,
  bool reportToday = true,
}) {
  final t = DateTime.now();
  return {
    'id': name,
    'name': name,
    'status': status,
    'phases': phases,
    'schedules': [],
    'punch_lists': punches,
    if (due != null) 'dueDate': due,
    if (remind != null) 'reportReminderMinutes': remind,
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

List<Map<String, dynamic>> twoPhases(bool firstDone, bool secondDone) => [
  {'id': 'p1', 'name': 'P', 'isCompleted': firstDone},
  {'id': 'p2', 'name': 'Q', 'isCompleted': secondDone},
];

Future<void> pump(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: w));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('resolveOpenIssues', () {
    test('resolves only unresolved issues and keeps existing notes', () {
      final now = DateTime(2026, 9, 19, 15);
      final log = proj(
        'A',
        punches: [
          {'content': '열림1', 'is_completed': false},
          {'content': '열림2', 'is_completed': false, 'resolution_note': '메모'},
          {
            'content': '이미완료',
            'is_completed': true,
            'resolved_at': DateTime(2026, 9, 1),
            'resolution_note': '원래처리',
          },
        ],
      );
      final n = resolveOpenIssues(log, now: now);
      expect(n, 2);
      final ps = log['punch_lists'] as List;
      expect(ps[0]['is_completed'], true);
      expect(ps[0]['resolved_at'], now);
      expect(ps[0]['resolution_note'], '프로젝트 완료 시 일괄 처리');
      expect(ps[1]['resolution_note'], '메모'); // 기존 메모는 유지
      expect(ps[2]['resolved_at'], DateTime(2026, 9, 1)); // 이미 완료된 것은 그대로
      expect(ps[2]['resolution_note'], '원래처리');
      expect(openIssueCount(log), 0);
      // 다시 실행해도 바꿀 것이 없다.
      expect(resolveOpenIssues(log, now: now), 0);
      expect(resolveOpenIssues(proj('B')), 0);
    });
  });

  group('resolve-all button on a completed project', () {
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
            save: () => calls.add('save'),
            toggleStatus: () {},
            toggleArchive: () {},
            delete: () {},
          ),
        ),
      );
      return calls;
    }

    testWidgets('appears only for completed projects with open issues', (
      tester,
    ) async {
      final log = proj(
        'A',
        status: 'DONE',
        punches: [
          {'content': 'x', 'is_completed': false},
          {'content': 'y', 'is_completed': false},
        ],
      );
      await pumpDetail(tester, log);
      await tester.scrollUntilVisible(
        findText('남은 이슈 2건 모두 처리 완료'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(findText('남은 이슈 2건 모두 처리 완료'), findsOneWidget);
    });

    testWidgets('not shown for an active project', (tester) async {
      final log = proj(
        'A',
        punches: [
          {'content': 'x', 'is_completed': false},
        ],
      );
      await pumpDetail(tester, log);
      await tester.scrollUntilVisible(
        find.text('프로젝트 완료 처리'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('모두 처리 완료'), findsNothing);
    });

    testWidgets('cancel keeps issues; confirm resolves and saves', (
      tester,
    ) async {
      final log = proj(
        'A',
        status: 'DONE',
        punches: [
          {'content': 'x', 'is_completed': false},
        ],
      );
      final calls = await pumpDetail(tester, log);
      final btn = findText('남은 이슈 1건 모두 처리 완료');
      await tester.scrollUntilVisible(
        btn,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(btn);
      await tester.pumpAndSettle();
      expect(findText('남은 이슈를 모두 완료하시겠습니까?'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(openIssueCount(log), 1);
      expect(calls, isEmpty);

      await tester.tap(btn);
      await tester.pumpAndSettle();
      await tester.tap(find.text('모두 처리 완료'));
      await tester.pumpAndSettle();
      expect(openIssueCount(log), 0);
      expect(calls, ['save']);
      expect(findText('이슈 1건을 처리 완료로 바꿨습니다.'), findsOneWidget);
      // 남은 이슈가 없으니 버튼이 사라진다.
      expect(findText('남은 이슈 1건 모두 처리 완료'), findsNothing);
    });
  });

  group('overview card sort', () {
    test('sortedForOverview orders by progress or due date', () {
      final a = proj('A', phases: twoPhases(true, true)); // 100%
      final b = proj('B', phases: twoPhases(false, false)); // 0%
      final c = proj('C', phases: twoPhases(true, false)); // 50%
      final list = [a, b, c];
      expect(sortedForOverview(list, 0).map((e) => e['name']), ['A', 'B', 'C']);
      expect(sortedForOverview(list, 1).map((e) => e['name']), ['B', 'C', 'A']);
      // 원본 목록은 바뀌지 않는다.
      expect(list.map((e) => e['name']), ['A', 'B', 'C']);
    });

    test('mode 2 sorts by the project due date, no-due projects last', () {
      final now = DateTime.now();
      Map<String, dynamic> withDue(String n, int days) =>
          proj(n)
            ..['phases'] = [
              {
                'id': 'p',
                'name': 'P',
                'isCompleted': false,
                'endDate': now.add(Duration(days: days)),
              },
            ];
      final far = withDue('먼곳', 30);
      final near = withDue('가까운곳', 3);
      final none = proj('납기없음');
      final viaSchedule = proj('일정납기')
        ..['schedules'] = [
          {'type': '납기일', 'dateTime': now.add(const Duration(days: 10))},
        ];
      final sorted = sortedForOverview([none, far, viaSchedule, near], 2);
      expect(sorted.map((e) => e['name']).toList(), [
        '가까운곳',
        '일정납기',
        '먼곳',
        '납기없음',
      ]);
    });

    testWidgets('button cycles 기본 → 진행률 낮은 순 → 납기 임박순', (tester) async {
      await pump(
        tester,
        WeeklyReportPage(
          logs: [
            proj('높음', phases: twoPhases(true, true)),
            proj('낮음', phases: twoPhases(false, false)),
          ],
        ),
      );
      double y(String name) {
        // 진행률 카드 안의 이름 텍스트(카드 첫 번째 일치)의 세로 위치.
        final f = find.descendant(
          of: find
              .ancestor(
                of: find.text('이번 주 한눈에'),
                matching: find.byType(Container),
              )
              .first,
          matching: find.text(name),
        );
        return tester.getTopLeft(f.first).dy;
      }

      expect(find.text('기본 순'), findsOneWidget);
      expect(y('높음') < y('낮음'), true);
      await tester.tap(find.text('기본 순'));
      await tester.pumpAndSettle();
      expect(find.text('진행률 낮은 순'), findsOneWidget);
      expect(y('낮음') < y('높음'), true);
      await tester.tap(find.text('진행률 낮은 순'));
      await tester.pumpAndSettle();
      expect(find.text('납기 임박순'), findsOneWidget);
      await tester.tap(find.text('납기 임박순'));
      await tester.pumpAndSettle();
      expect(find.text('기본 순'), findsOneWidget); // 한 바퀴 돌아옴
    });

    testWidgets('no sort button with a single project', (tester) async {
      await pump(tester, WeeklyReportPage(logs: [proj('A')]));
      expect(find.text('기본 순'), findsNothing);
    });
  });

  group('reminder count check', () {
    test('mismatch messages', () {
      expect(reminderCountMismatch(2, 2), isNull);
      expect(reminderCountMismatch(0, 0), isNull);
      expect(reminderCountMismatch(2, 0), contains('하나도 없습니다'));
      expect(reminderCountMismatch(3, 1), contains('3개가 필요한데 1개만'));
      expect(reminderCountMismatch(1, 3), contains('3개 예약'));
    });

    testWidgets('project time list can be edited when a save hook is given', (
      tester,
    ) async {
      final saved = <String>[];
      final a = proj('A현장', reportToday: false, remind: 21 * 60);
      await pump(
        tester,
        NotificationCheckPage(
          logs: [a, proj('B현장', reportToday: false)],
          onSaveProject: (l) async => saved.add(l['name'] as String),
        ),
      );
      expect(find.text('프로젝트별 시각 바꾸기'), findsOneWidget);
      await tester.tap(find.text('프로젝트별 시각 바꾸기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('A현장  21:00'), findsOneWidget);
      expect(find.textContaining('B현장  18:00 (기본)'), findsOneWidget);
      // A현장에만 "기본" 버튼이 있다(따로 정한 시각이 있으니까).
      expect(find.text('기본'), findsOneWidget);
      await tester.tap(find.text('기본'));
      await tester.pumpAndSettle();
      expect(saved, ['A현장']);
      expect(a.containsKey('reportReminderMinutes'), false);
      expect(find.textContaining('A현장  18:00 (기본)'), findsOneWidget);
    });

    testWidgets('without a save hook the edit list is replaced by a hint', (
      tester,
    ) async {
      await pump(
        tester,
        NotificationCheckPage(logs: [proj('A현장', reportToday: false)]),
      );
      expect(find.text('프로젝트별 시각 바꾸기'), findsNothing);
      expect(findTextContaining('프로젝트 화면 ⋮ 메뉴'), findsOneWidget);
    });
  });
}
