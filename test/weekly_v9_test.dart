import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';
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
  _swipeOnlyTest();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('cleanupOldPdfs removes only old top-level pdf files', () async {
    final dir = await Directory.systemTemp.createTemp('pdfclean');
    addTearDown(() => dir.delete(recursive: true));
    final now = DateTime(2026, 9, 19);
    File f(String n, int daysOld) {
      final file = File('${dir.path}/$n')..writeAsStringSync('x');
      file.setLastModifiedSync(now.subtract(Duration(days: daysOld)));
      return file;
    }

    final oldPdf = f('old.pdf', 10);
    final oldUpper = f('OLD2.PDF', 5);
    final freshPdf = f('fresh.pdf', 1);
    final oldTxt = f('old.txt', 10);
    final sub = Directory('${dir.path}/sub')..createSync();
    final nested = File('${sub.path}/nested.pdf')..writeAsStringSync('x');
    nested.setLastModifiedSync(now.subtract(const Duration(days: 30)));

    final n = await cleanupOldPdfs(dir, now: now);
    expect(n, 2);
    expect(oldPdf.existsSync(), false);
    expect(oldUpper.existsSync(), false);
    expect(freshPdf.existsSync(), true);
    expect(oldTxt.existsSync(), true); // pdf가 아니면 건드리지 않는다
    expect(nested.existsSync(), true); // 하위 폴더는 건드리지 않는다
    // 없는 폴더도 오류 없이 0
    expect(await cleanupOldPdfs(Directory('${dir.path}/nope'), now: now), 0);
  });

  testWidgets('collapse is keyed by project name; old keys are migrated', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'weekly_report_collapsed': ['금주 — 진행 및 예정|A현장', '미해결 이슈 현황|A현장'],
    });
    final logs = [proj('A현장'), proj('B현장')];
    await pump(tester, WeeklyReportPage(logs: logs));
    // 예전 형식 키에서 프로젝트 이름만 이어받아 A현장이 접혀 있다.
    expect(find.textContaining('A현장 작업'), findsNothing);
    expect(find.textContaining('B현장 작업'), findsWidgets);

    // 한 곳에서 B현장을 접으면 모든 섹션에서 같이 접히고, 저장은 이름만 든다.
    await tester.tap(find.text('■ B현장').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('B현장 작업'), findsNothing);
    final saved = (await SharedPreferences.getInstance()).getStringList(
      'weekly_report_collapsed',
    )!;
    expect(saved.toSet(), {'A현장', 'B현장'});
  });

  testWidgets('excluded issues can be listed and re-included', (tester) async {
    final punch = <String, dynamic>{
      'content': '뺀이슈',
      'location': '2층',
      'is_completed': false,
      'weeklyExclude': true,
    };
    final changed = <Map<String, dynamic>>[];
    await pump(
      tester,
      WeeklyReportPage(
        logs: [
          proj('A현장', punches: [punch]),
        ],
        onIssueChanged: changed.add,
      ),
    );
    expect(findText('제외한 이슈 1건 보기'), findsOneWidget);
    // 접혀 있어서 내용은 아직 안 보이고, 리포트 본문에도 없다.
    expect(find.textContaining('뺀이슈'), findsNothing);
    await tester.tap(findText('제외한 이슈 1건 보기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('뺀이슈'), findsOneWidget);

    await tester.tap(find.text('다시 포함'));
    await tester.pumpAndSettle();
    expect(punch.containsKey('weeklyExclude'), false);
    expect(changed.length, 1);
    // 카드는 사라지고 이슈가 본문 "미해결 이슈 현황"에 나타난다.
    expect(find.textContaining('제외한 이슈'), findsNothing);
    expect(find.textContaining('뺀이슈'), findsOneWidget);
  });

  testWidgets('no excluded card when nothing is excluded or no save hook', (
    tester,
  ) async {
    await pump(
      tester,
      WeeklyReportPage(logs: [proj('A현장')], onIssueChanged: (_) {}),
    );
    expect(find.textContaining('제외한 이슈'), findsNothing);
    final excluded = <String, dynamic>{
      'content': 'x',
      'is_completed': false,
      'weeklyExclude': true,
    };
    await pump(
      tester,
      WeeklyReportPage(
        logs: [
          proj('A현장', punches: [excluded]),
        ],
      ),
    );
    expect(findText('제외한 이슈 1건 보기'), findsNothing);
  });
}

// 알림으로 연 화면처럼 onOpenIssue 없이 onIssueChanged만 있어도 밀어서 제외할 수 있다.
void _swipeOnlyTest() {
  testWidgets('swipe works with only onIssueChanged (notification path)', (
    tester,
  ) async {
    final punch = <String, dynamic>{
      'content': '알림경로',
      'location': '3층',
      'is_completed': false,
    };
    final changed = <Map<String, dynamic>>[];
    await pump(
      tester,
      WeeklyReportPage(
        logs: [
          proj('A현장', punches: [punch]),
        ],
        onIssueChanged: changed.add,
      ),
    );
    // 열기 기능이 없으니 이슈 줄에는 화살표가 없다(남는 하나는 기준일 줄의 것).
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    await tester.drag(find.textContaining('알림경로'), const Offset(-800, 0));
    await tester.pumpAndSettle();
    expect(punch['weeklyExclude'], true);
    expect(changed.length, 1);
  });
}
