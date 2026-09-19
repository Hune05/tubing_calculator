import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_phase.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_style.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/weekly_plan.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/weekly_report_page.dart';

String md(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

Map<String, dynamic> proj(
  String name, {
  List<Map<String, dynamic>> punches = const [],
  bool reportToday = true,
  String status = 'ACTIVE',
}) {
  final t = DateTime.now();
  return {
    'id': name,
    'name': name,
    'status': status,
    'phases': [],
    'schedules': [],
    'punch_lists': punches,
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ReportStyle.current = ReportStyle();
  });

  testWidgets(
    'open weekly report reflects a change made in the issue detail on return',
    (tester) async {
      final punch = <String, dynamic>{
        'content': '갱신확인',
        'location': '2층',
        'is_completed': false,
      };
      final log = proj('A현장', punches: [punch]);
      // 메인 화면처럼: 상세에서 돌아오면 이슈 항목을 복사본으로 "교체"한다.
      await pump(
        tester,
        WeeklyReportPage(
          logs: [log],
          onOpenIssue: (l, p) async {
            final updated = Map<String, dynamic>.from(p);
            setIssueWeeklyExcluded(updated, true);
            final list = l['punch_lists'] as List;
            list[list.indexOf(p)] = updated;
          },
          onIssueChanged: (_) {},
        ),
      );
      expect(find.textContaining('갱신확인'), findsOneWidget);
      expect(find.textContaining('제외한 이슈'), findsNothing);
      await tester.tap(find.textContaining('갱신확인'));
      await tester.pumpAndSettle();
      // 본문에서는 빠지고, 아래 "제외한 이슈" 카드로 옮겨 가 있어야 한다.
      expect(find.textContaining('참고'), findsOneWidget);
      expect(findText('제외한 이슈 1건 보기'), findsOneWidget);
      expect(find.textContaining('미해결 이슈 현황'), findsNothing);
    },
  );

  test('PDF author line: date always, author only when a manager is set', () {
    final now = DateTime(2026, 9, 19);
    final noMgr = buildWeeklyPlanDoc([proj('A')]);
    expect(noMgr.showAuthorLine, true);
    expect(noMgr.authorLine(now), '작성일 2026.9.19');
    ReportStyle.current = ReportStyle(manager: '홍길동');
    expect(
      buildWeeklyPlanDoc([proj('A')]).authorLine(now),
      '작성일 2026.9.19 · 작성 홍길동',
    );
    // 프로젝트 하나면 그 프로젝트의 담당자가 우선한다.
    final own = proj('B')
      ..['reportHeader'] = {'company': 'c', 'manager': '김프로'};
    expect(buildWeeklyPlanDoc([own]).authorLine(now), '작성일 2026.9.19 · 작성 김프로');
    // 다른 보고서(작업 보고 등)에는 한 줄이 붙지 않는다.
    expect(ReportDoc('t', 'p', []).showAuthorLine, false);
  });

  test('weekly PDF with the author line builds', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    ReportStyle.current = ReportStyle(company: '설비', manager: '홍길동');
    final bytes = await buildReportPdfBytes(buildWeeklyPlanDoc([proj('A')]));
    expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    await File('build/weekly_author_test.pdf').create(recursive: true);
    await File('build/weekly_author_test.pdf').writeAsBytes(bytes);
  });

  test('runPdfCleanup(maxAge: zero) removes fresh pdfs too', () async {
    final dir = await Directory.systemTemp.createTemp('pdfnow');
    addTearDown(() => dir.delete(recursive: true));
    final fresh = File('${dir.path}/fresh.pdf')..writeAsStringSync('x');
    final txt = File('${dir.path}/keep.txt')..writeAsStringSync('x');
    // 3일 기본값이면 새 파일은 남는다.
    expect(await runPdfCleanup(dir), 0);
    expect(fresh.existsSync(), true);
    // 지금 정리: 기준 시각을 1초 뒤로 잡아 방금 만든 파일도 지운다.
    final n = await runPdfCleanup(
      dir,
      maxAge: Duration.zero,
      now: DateTime.now().add(const Duration(seconds: 1)),
    );
    expect(n, 1);
    expect(fresh.existsSync(), false);
    expect(txt.existsSync(), true);
    final r = await loadPdfCleanupRecord();
    expect(r.lastRemoved, 1);
    expect(r.total, 1);
  });

  test('projectsMissingReport picks active projects without today report', () {
    final today = md(DateTime.now());
    final logs = [
      proj('쓴곳'),
      proj('안쓴곳', reportToday: false),
      proj('끝난곳', reportToday: false, status: 'DONE'),
      proj('보관곳', reportToday: false)..['archived'] = true,
    ];
    final m = projectsMissingReport(logs, today);
    expect(m.map((e) => e['name']).toList(), ['안쓴곳']);
    // 여럿이면 자동으로 열지 않는다는 판단의 근거: 개수 확인
    expect(
      projectsMissingReport([
        proj('a', reportToday: false),
        proj('b', reportToday: false),
      ], today).length,
      2,
    );
  });
}
