import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/weekly_plan.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/weekly_report_page.dart';

String md(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

Map<String, dynamic> proj(
  String name, {
  List<String> imgs = const [],
  Map<String, dynamic> tags = const {},
}) {
  final t = DateTime.now();
  return {
    'id': name,
    'name': name,
    'status': 'ACTIVE',
    'phases': [],
    'schedules': [],
    'punch_lists': [],
    'daily_reports': [
      {
        'date': md(t),
        'dateISO': DateTime(t.year, t.month, t.day).toIso8601String(),
        'note': '$name 작업',
        'worker_count': 1,
        'image_paths': imgs,
        'image_tags': tags,
      },
    ],
  };
}

void main() {
  test('PDF file name: project_kind_date, unsafe chars removed', () {
    final doc = ReportDoc(
      '루마 / 2공구: A*',
      'p',
      [],
      heading: '주간 업무 보고',
      fileStamp: '20260919',
    );
    expect(reportPdfFileName(doc), '루마_2공구_A_주간_업무_보고_20260919.pdf');
    final plain = ReportDoc('현장', 'p', []);
    expect(
      reportPdfFileName(plain, DateTime(2026, 1, 5)),
      '현장_작업_보고_20260105.pdf',
    );
    final weekly = buildWeeklyPlanDoc([proj('A'), proj('B')]);
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    expect(reportPdfFileName(weekly), '진행중_프로젝트_2건_주간_업무_보고_$stamp.pdf');
  });

  test('text footer mentions photos only when photos are switched on', () {
    final logs = [
      proj('A', imgs: ['b', 'a'], tags: {'b': '작업 전', 'a': '작업 후'}),
    ];
    final off = buildWeeklyPlanDoc(logs);
    expect(off.toText().contains('PDF로 보내면'), false);
    final on = buildWeeklyPlanDoc(logs, includePhotos: true);
    final t = on.toText();
    expect(t.contains('※ 사진 2장, 작업 전/후 비교 1쌍은 PDF로 보내면'), true);
    // 사진이 없으면 안내도 없다.
    final none = buildWeeklyPlanDoc([proj('A')], includePhotos: true);
    expect(none.toText().contains('PDF로 보내면'), false);
  });

  testWidgets('모두 접기 hides project lines, 모두 펼치기 shows them again', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: WeeklyReportPage(logs: [proj('A현장'), proj('B현장')])),
    );
    expect(find.textContaining('A현장 작업'), findsWidgets);
    await tester.tap(find.text('모두 접기'));
    await tester.pump();
    expect(find.textContaining('A현장 작업'), findsNothing);
    expect(find.textContaining('B현장 작업'), findsNothing);
    // 프로젝트 제목 줄은 남아 있다.
    expect(find.textContaining('■ A현장'), findsWidgets);
    await tester.tap(find.text('모두 펼치기'));
    await tester.pump();
    expect(find.textContaining('A현장 작업'), findsWidgets);
  });
}
