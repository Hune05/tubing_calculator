import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/project_phase.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_style.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/report_tools.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/weekly_plan.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/punch_detail_page.dart';

String md(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

Map<String, dynamic> proj(
  String name, {
  String status = 'ACTIVE',
  DateTime? completedAt,
}) {
  final t = DateTime.now();
  return {
    'id': name,
    'name': name,
    'status': status,
    'phases': [],
    'schedules': [],
    'punch_lists': [],
    'completedAt': ?completedAt,
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

void main() {
  setUp(() => ReportStyle.current = ReportStyle());

  test('daily reminder body mentions the count only for 2+ projects', () {
    expect(dailyReminderBody(0).contains('곳'), false);
    expect(dailyReminderBody(1).contains('곳'), false);
    expect(dailyReminderBody(2), contains('2곳'));
    expect(dailyReminderBody(5), contains('5곳'));
    expect(dailyReminderBody(3), contains('눌러서 바로 남겨 두십시오'));
  });

  testWidgets(
    'issue detail: changing weekly inclusion shows a snackbar with undo',
    (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final punch = <String, dynamic>{
        'content': '안내확인',
        'location': '2층',
        'is_completed': false,
        'created_at': DateTime.now(),
      };
      Map<String, dynamic>? popped;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
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
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      final sw = find.widgetWithText(SwitchListTile, '주간 업무 보고에 포함');
      await tester.scrollUntilVisible(
        sw,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<SwitchListTile>(sw).value, true);

      // 끄면 "뺐어요" 안내가 뜨고 스위치가 꺼진다.
      await tester.tap(sw);
      await tester.pumpAndSettle();
      expect(find.text('주간 보고에서 뺐습니다.'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(sw).value, false);

      // 되돌리기 → 다시 켜진 상태로 돌아간다.
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(sw).value, true);

      // 다시 켜고 끄기 순서도 안내 문구가 맞다.
      await tester.tap(sw); // 끔
      await tester.pumpAndSettle();
      await tester.tap(sw); // 켬
      await tester.pumpAndSettle();
      expect(find.text('주간 보고에 포함했습니다.'), findsOneWidget);
      await tester.tap(find.text('되돌리기')); // 켠 것을 되돌리면 다시 꺼짐
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(sw).value, false);

      // 뒤로 가면 최종 상태(제외됨)가 반환값에 담긴다.
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(popped, isNotNull);
      expect(issueWeeklyExcluded(popped!), true);
    },
  );

  test('report style: weekly author line defaults on and round-trips', () {
    expect(ReportStyle().weeklyAuthorLine, true);
    expect(ReportStyle.fromJson({}).weeklyAuthorLine, true); // 옛 저장값
    final off = ReportStyle(weeklyAuthorLine: false);
    expect(off.toJson()['weeklyAuthorLine'], false);
    expect(ReportStyle.fromJson(off.toJson()).weeklyAuthorLine, false);
    expect(
      ReportStyle.fromJson({'weeklyAuthorLine': true}).weeklyAuthorLine,
      true,
    );
  });

  test('weekly doc shows the author line only when the style switch is on', () {
    expect(buildWeeklyPlanDoc([proj('A')]).showAuthorLine, true);
    ReportStyle.current = ReportStyle(weeklyAuthorLine: false);
    expect(buildWeeklyPlanDoc([proj('A')]).showAuthorLine, false);
  });

  test('projects completed this week are announced in the summary', () {
    final now = DateTime.now();
    final long = now.subtract(const Duration(days: 30));
    final logs = [
      proj('진행중A'),
      proj('완료B', status: 'DONE', completedAt: now),
      proj('예전완료C', status: 'DONE', completedAt: long),
      proj('완료날짜없음D', status: 'DONE'),
    ];
    final d = buildWeeklyPlanDoc(logs);
    final sum = d.sections.first;
    expect(sum.heading.startsWith('금주 요약'), true);
    final dones = sum.lines.where((l) => l.contains('금주 완료 ·')).toList();
    expect(dones.length, 1); // 이번 주에 완료한 것만, 프로젝트마다 한 줄
    expect(dones.single.contains('완료B (${now.month}/${now.day})'), true);
    final all = sum.lines.join(' | ');
    expect(all.contains('예전완료C'), false);
    expect(all.contains('완료날짜없음D'), false);
    expect(all.contains('진행중A'), false);
    // 눌러서 이동할 수 있게 그 줄이 프로젝트 원본을 가리킨다.
    final idx = sum.lines.indexOf(dones.single);
    expect(identical(sum.projectRefs![idx], logs[1]), true);
    // 진행중 프로젝트 하나만 골라 볼 때는 완료 안내가 붙지 않는다.
    final one = buildWeeklyPlanDoc(logs, onlyIds: {'진행중A'});
    expect(one.sections.first.lines.any((l) => l.contains('금주 완료')), false);
    // 이번 주 완료가 없으면 줄 자체가 없다.
    final none = buildWeeklyPlanDoc([proj('진행중A')]);
    expect(none.sections.first.lines.any((l) => l.contains('금주 완료')), false);
    // 카톡 텍스트에도 들어간다.
    expect(d.toText().contains('금주 완료 · 완료B'), true);
    // 지난 주 기준일로 보면 그 주에 완료한 것이 잡힌다.
    final past = buildWeeklyPlanDoc(logs, asOf: long);
    expect(past.sections.first.lines.any((l) => l.contains('예전완료C')), true);
  });

  test('all projects done: summary still announces this week completions', () {
    final now = DateTime.now();
    final d = buildWeeklyPlanDoc([
      proj('완료B', status: 'DONE', completedAt: now),
    ]);
    expect(d.sections.first.lines.any((l) => l.contains('금주 완료 · 완료B')), true);
  });
}
