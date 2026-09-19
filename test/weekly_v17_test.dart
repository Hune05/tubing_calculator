import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_phase.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/notification_check_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/project_detail_page.dart';

import 'helpers_text.dart';

String md(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

Map<String, dynamic> proj(
  String name, {
  String status = 'ACTIVE',
  List<Map<String, dynamic>> punches = const [],
  Map<String, dynamic>? retro,
}) {
  final t = DateTime.now();
  return {
    'id': name,
    'name': name,
    'status': status,
    'phases': [],
    'schedules': [],
    'punch_lists': punches,
    if (retro != null) 'retro': retro,
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

  group('알림 점검: 안내 카드 미리 보기', () {
    testWidgets('the button closes the page with the preview result', (
      tester,
    ) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () async => result = await Navigator.push<String>(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => const NotificationCheckPage(),
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      tester.view.physicalSize = const Size(900, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.text('5. 안내 카드 미리 보기'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('안내 카드 미리 보기'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('안내 카드 미리 보기'));
      await tester.pumpAndSettle();
      expect(result, kPreviewProblem);
    });

    test(
      'preview message is the same text the real problem card would show',
      () {
        expect(reminderCountMismatch(2, 0), '일보 알림 2개가 필요한데 예약이 하나도 없습니다.');
      },
    );
  });

  group('완료 처리 뒤 결과 정리를 이어서 묻는다', () {
    Future<Map<String, dynamic>> open(
      WidgetTester tester,
      Map<String, dynamic> log,
    ) async {
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
      return log;
    }

    testWidgets('no retro yet: asks first, 나중에 → then the report question', (
      tester,
    ) async {
      final log = await open(tester, proj('A'));
      await tester.tap(find.text('프로젝트 완료 처리'));
      await tester.pumpAndSettle();
      expect(findText('결과 정리를 작성하시겠습니까?'), findsOneWidget);
      // 이 시점에는 아직 마무리 보고서 질문이 뜨지 않는다(결과 정리가 먼저).
      expect(findText('마무리 보고서를 만드시겠습니까?'), findsNothing);
      await tester.tap(find.text('나중에'));
      await tester.pumpAndSettle();
      expect(findText('마무리 보고서를 만드시겠습니까?'), findsOneWidget);
      expect(log['status'], 'DONE');
      expect(log.containsKey('retro'), false);
    });

    testWidgets('작성 opens the input dialog and saves into the project', (
      tester,
    ) async {
      final log = await open(tester, proj('A'));
      await tester.tap(find.text('프로젝트 완료 처리'));
      await tester.pumpAndSettle();
      // 화면 뒤쪽 "결과 정리 > 작성" 버튼과 구분하려고, 팝업 안(AlertDialog)의 버튼만 누른다.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('작성'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('프로젝트 결과 정리'), findsWidgets);
      await tester.enterText(find.byType(TextField).first, '자재 입고 지연');
      await tester.enterText(find.byType(TextField).last, '시작하기 전에 발주');
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      final r = log['retro'] as Map;
      expect(r['cause'], '자재 입고 지연');
      expect(r['lesson'], '시작하기 전에 발주');
      // 저장 뒤에 마무리 보고서 질문이 이어진다.
      expect(findText('마무리 보고서를 만드시겠습니까?'), findsOneWidget);
    });

    testWidgets('already written: skips straight to the report question', (
      tester,
    ) async {
      final log = await open(
        tester,
        proj('A', retro: {'cause': '이미 적음', 'lesson': ''}),
      );
      await tester.tap(find.text('프로젝트 완료 처리'));
      await tester.pumpAndSettle();
      expect(findText('결과 정리를 작성하시겠습니까?'), findsNothing);
      expect(findText('마무리 보고서를 만드시겠습니까?'), findsOneWidget);
      expect(log['status'], 'DONE');
    });

    testWidgets('the final report includes what was just written', (
      tester,
    ) async {
      final log = proj(
        'A',
        status: 'DONE',
        retro: {'cause': '자재 지연', 'lesson': '발주 먼저'},
      );
      final doc = buildFinalReportDoc(log);
      final s = doc.sections.last;
      expect(s.heading, '결과 정리');
      expect(s.lines.join().contains('자재 지연'), true);
      expect(openIssueCount(log), 0);
    });
  });
}
