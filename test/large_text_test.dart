import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_leftovers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/error_log.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/schedule_logic.dart';
import 'package:tubing_calculator/src/presentation/my_schedule/schedule_search_dialog.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/app_status_page.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/widgets/cutting_optimization_sheet.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/daily_report_calendar_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/daily_report_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/project_stats_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/punch_detail_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/report_search_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/report_style_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/notification_check_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/project_detail_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/project_schedule_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/retro_overview_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/weekly_report_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/create_log_sheet.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/work_theme.dart';

import 'helpers_text.dart';

// 폰의 글자 크기를 크게 키워 둔 경우(1.5배)에도 주요 화면이 넘치거나 깨지지 않는지 본다.
// 글자가 넘치면 Flutter가 "RenderFlex overflowed" 오류를 내므로, 오류가 없는지로 확인한다.
const _scale = 1.5;

Map<String, dynamic> project({bool done = false}) => {
  'id': '1',
  'name': '루마 현장 배관 신설 공사',
  'status': done ? 'DONE' : 'ACTIVE',
  'workType': '배관 신설',
  'revision': '기준 도면 없음',
  'date': '2026-09-01 ~ 진행중',
  if (done) 'completedAt': DateTime(2026, 9, 10),
  'retro': {
    'cause': '자재 입고가 2주 늦어짐, 우천으로 작업 중지',
    'lesson': '자재는 시작하기 전에 미리 발주',
  },
  'phases': [
    {
      'id': 'p1',
      'name': '자재 입고',
      'isCompleted': true,
      'startDate': DateTime(2026, 9, 1),
      'endDate': DateTime(2026, 9, 5),
    },
    {
      'id': 'p2',
      'name': '시운전·검사',
      'isCompleted': false,
      'startDate': DateTime(2026, 9, 6),
      'endDate': DateTime(2026, 9, 20),
    },
  ],
  'schedules': [
    {
      'id': 's1',
      'title': '도면 검토와 현장 확인',
      'type': '검사일정',
      'dateTime': DateTime(2026, 9, 20, 10),
      'isCompleted': false,
      'phaseId': 'p2',
    },
  ],
  'punch_lists': [
    {
      'id': 'k1',
      'content': '트레이 지지대 간격이 규정보다 넓음',
      'location': '2층 A구역',
      'is_completed': false,
      'priority': '긴급',
      'dueDate': DateTime(2026, 9, 25),
    },
  ],
  'daily_reports': [
    {
      'date': '09/18',
      'dateISO': DateTime(2026, 9, 18).toIso8601String(),
      'worker_count': 3,
      'work_type': ['라인 수정', '결선/트레이싱'],
      'note': '센서 3개소 결선 완료, 튜브 라인 연결하고 누설 점검까지 진행했습니다.',
      'materials_used': '엘보 1/2, 유니온',
      'workedPhaseIds': ['p1'],
    },
    {
      'date': '09/19',
      'dateISO': DateTime(2026, 9, 19).toIso8601String(),
      'worker_count': 2,
      'work_type': ['신규 설치'],
      'note': '',
    },
  ],
};

ProjectActions actions() => ProjectActions(
  addPunch: () async {},
  openPunch: (_) async {},
  addReport: () async {},
  openReport: (_) async {},
  openReportCalendar: () async {},
  openSchedule: ({String? phaseId, bool add = false}) async {},
  save: () {},
  toggleStatus: () {},
  toggleArchive: () {},
  delete: () {},
);

Future<void> show(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1080, 2400); // 360dp 폭
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(_scale)),
        child: child!,
      ),
      home: WorkTheme(child: page),
    ),
  );
  await tester.pumpAndSettle();
}

void expectNoOverflow(WidgetTester tester, String where) {
  final e = tester.takeException();
  expect(
    e,
    isNull,
    reason: '$where: ${e is FlutterError ? e.toStringDeep() : e}',
  );
}

void main() {
  // 잔재는 앱에서는 서버에 두지만, 테스트에서는 폰(prefs) 저장소로 바꿔 쓴다.
  leftoverStore = PrefsLeftoverStore();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('알림 점검', (tester) async {
    await show(
      tester,
      NotificationCheckPage(
        logs: [project()],
        pendingIdsLoader: () async => {918300},
        recordActive: () async {},
        exactChecker: () async => false,
        personalStatusLoader: () async => (expected: 3, scheduled: 1),
      ),
    );
    expectNoOverflow(tester, '알림 점검');
  });

  testWidgets('앱 상태', (tester) async {
    await show(
      tester,
      AppStatusPage(
        notificationsAllowed: () async => false,
        exactAllowed: () async => false,
        pendingCount: () async => 3,
        serverReachable: () async => throw StateError('offline'),
        lastBackup: () async => DateTime(2026, 8, 1),
        pendingWrites: () => 2,
        errorsLoader: () async => [
          ErrorEntry(DateTime(2026, 9, 19, 20), '알림 예약', '긴 오류 내용 ' * 20),
        ],
      ),
    );
    expectNoOverflow(tester, '앱 상태');
  });

  testWidgets('작업 일지 작성(채우기 창 포함)', (tester) async {
    await show(
      tester,
      DailyReportPage(
        previousReports: List.from(project()['daily_reports'] as List),
        phases: List.from(project()['phases'] as List),
      ),
    );
    expectNoOverflow(tester, '작업 일지 작성');
    await tester.tap(findText('이전 작업 일지에서 채우기'));
    await tester.pumpAndSettle();
    expectNoOverflow(tester, '채우기 창');
  });

  testWidgets('결과 정리 모아보기', (tester) async {
    await show(tester, RetroOverviewPage(logs: [project(done: true)]));
    expectNoOverflow(tester, '결과 정리 모아보기');
  });

  testWidgets('프로젝트 일정', (tester) async {
    await show(
      tester,
      ProjectSchedulePage(
        projectName: '루마 현장 배관 신설 공사',
        initialSchedules: List.from(project()['schedules'] as List),
        phases: List.from(project()['phases'] as List),
      ),
    );
    expectNoOverflow(tester, '프로젝트 일정');
  });

  testWidgets('프로젝트 상세', (tester) async {
    await show(tester, ProjectDetailPage(log: project(), actions: actions()));
    expectNoOverflow(tester, '프로젝트 상세(개요)');
    for (final tab in ['단계·일정', '이슈', '일지']) {
      await tester.tap(find.text(tab).first);
      await tester.pumpAndSettle();
      expectNoOverflow(tester, '프로젝트 상세($tab)');
    }
  });

  testWidgets('주간 보고', (tester) async {
    await show(tester, WeeklyReportPage(logs: [project()]));
    expectNoOverflow(tester, '주간 보고');
  });

  testWidgets('새 프로젝트 만들기', (tester) async {
    await show(
      tester,
      Scaffold(body: CreateLogSheet(existingLogs: [project(done: true)])),
    );
    await tester.tap(find.text('배관 신설'));
    await tester.pumpAndSettle();
    expectNoOverflow(tester, '새 프로젝트 만들기');
  });

  testWidgets('일정 검색 창', (tester) async {
    await show(
      tester,
      ScheduleSearchDialog(
        entries: [
          SearchEntry(
            groupKey: 'a',
            key: 'a1',
            date: DateTime(2026, 9, 25, 10),
            title: '거래처 미팅과 현장 답사를 겸한 긴 제목의 일정',
            category: '영업',
            projectName: '루마 현장 배관 신설 공사',
          ),
        ],
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('schedule_search_field')),
      '거래처',
    );
    await tester.pumpAndSettle();
    expectNoOverflow(tester, '일정 검색 창');
  });

  testWidgets('작업 일지 달력', (tester) async {
    await show(
      tester,
      DailyReportCalendarPage(
        projectName: '루마 현장 배관 신설 공사',
        initialReports: List.from(
          project()['daily_reports'] as List,
        ).cast<Map<String, dynamic>>(),
      ),
    );
    expectNoOverflow(tester, '작업 일지 달력');
  });

  testWidgets('통계', (tester) async {
    await show(
      tester,
      ProjectStatsPage(logs: [project(), project(done: true)], title: '통계'),
    );
    expectNoOverflow(tester, '통계');
  });

  testWidgets('이슈 상세', (tester) async {
    await show(
      tester,
      PunchDetailPage(
        punch: Map<String, dynamic>.from(
          (project()['punch_lists'] as List).first as Map,
        ),
      ),
    );
    expectNoOverflow(tester, '이슈 상세');
  });

  testWidgets('검색', (tester) async {
    await show(tester, ReportSearchPage(logs: [project()], onOpen: (_) {}));
    await tester.enterText(find.byType(TextField).first, '센서');
    await tester.pumpAndSettle();
    expectNoOverflow(tester, '검색');
  });

  testWidgets('보고서 양식', (tester) async {
    await show(tester, const ReportStylePage());
    expectNoOverflow(tester, '보고서 양식');
  });

  testWidgets('재단 최적화 시트(잔재 포함)', (tester) async {
    SharedPreferences.setMockInitialValues({
      'cutting_leftovers_v1': ['1000튜브 1/2"', '850튜브 1/2"'],
    });
    await show(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showCuttingOptimizationSheet(
              context,
              groupedPieces: {
                '튜브 1/2"': [900, 800, 2600, 2600, 2000, 1400],
                '튜브 3/4"': [3000, 3000],
              },
              initialStockLength: 6000,
              kerf: 3,
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expectNoOverflow(tester, '재단 최적화 시트');
    await tester.tap(find.text('잔재 관리'));
    await tester.pumpAndSettle();
    expectNoOverflow(tester, '잔재 관리 창');
  });
}
