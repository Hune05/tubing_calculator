// 압력시험·교정 기록을 프로젝트에 붙이기(10-09 고도화 1번).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/instrument/cal_record.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/linked_records_section.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/widgets/project_link_field.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/weekly_plan.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_units.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_calc.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/test_record.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/test_record_sheet.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => debugProjectLinks = null);

  test('기록이 프로젝트를 저장·읽는다(예전 기록은 빈 값)', () {
    final pt = PtRecord(
      id: '1',
      date: DateTime(2026, 10, 8),
      line: 'L-101',
      projectId: 'p1',
      projectName: '루마',
    );
    final back = PtRecord.fromJson(pt.toJson());
    expect(back.projectId, 'p1');
    expect(back.projectName, '루마');
    expect(
      PtRecord.fromJson({
        'id': '2',
        'date': '2026-10-08',
        'line': 'x',
      }).projectId,
      '',
    );
    final cal = CalRecord(
      id: 'c',
      date: DateTime(2026, 10, 7),
      tag: 'PT-101',
      lrv: 0,
      urv: 10,
      found: const [],
      projectId: 'p1',
      projectName: '루마',
    );
    expect(CalRecord.fromJson(cal.toJson()).projectId, 'p1');
  });

  test('프로젝트 칸 줄: 이 프로젝트 것만, 최근 것부터', () {
    final rows = linkedRecordRows(
      'p1',
      [
        PtRecord(
          id: '1',
          date: DateTime(2026, 10, 8),
          line: 'L-101',
          projectId: 'p1',
        ),
        PtRecord(
          id: '2',
          date: DateTime(2026, 10, 9),
          line: 'L-102',
          projectId: 'p2',
        ),
      ],
      [
        CalRecord(
          id: 'c',
          date: DateTime(2026, 10, 9),
          tag: 'PT-101',
          lrv: 0,
          urv: 10,
          found: const [],
          projectId: 'p1',
        ),
      ],
    );
    expect(rows.map((r) => '${r.kind} ${r.name}'), ['교정 PT-101', '압력시험 L-101']);
    expect(linkedRecordRows('', const [], const []), isEmpty);
  });

  testWidgets('프로젝트 개요 칸: 붙인 기록이 있을 때만 보인다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              LinkedRecordsSection(
                projectId: 'p1',
                projectName: '루마',
                load: () async => (
                  [
                    PtRecord(
                      id: '1',
                      date: DateTime(2026, 10, 8),
                      line: 'L-101',
                      projectId: 'p1',
                    ),
                  ],
                  <CalRecord>[],
                ),
              ),
              LinkedRecordsSection(
                key: const Key('empty'),
                projectId: 'p9',
                projectName: '빈',
                load: () async => (<PtRecord>[], <CalRecord>[]),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('압력시험·교정 기록 (1)'), findsOneWidget);
    expect(find.text('10/8 압력시험 L-101'), findsOneWidget);
    expect(find.byKey(const Key('linked_pt_all')), findsOneWidget);
    expect(find.byKey(const Key('linked_cal_all')), findsNothing);
  });

  testWidgets('압력시험 저장 창에서 프로젝트를 고르면 결과에 붙고 빈 현장 칸에 이름이 들어간다', (tester) async {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    debugProjectLinks = () async => const [(id: 'p1', name: '루마 2층')];
    PtSaveResult? got;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                got = await showModalBottomSheet<PtSaveResult>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => PtSaveSheet(
                    editing: null,
                    unit: PUnit.bar,
                    medium: TestMedium.hydro,
                    line: 'L-101',
                    date: DateTime(2026, 10, 9),
                    tester: '홍',
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
    await tester.tap(find.byKey(const Key('plink_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plink_p1')));
    await tester.pumpAndSettle();
    expect(find.text('루마 2층'), findsWidgets);
    await tester.ensureVisible(find.byKey(const Key('ps_save')));
    await tester.tap(find.byKey(const Key('ps_save')));
    await tester.pumpAndSettle();
    expect(got!.project.id, 'p1');
    expect(got!.site, '루마 2층');
    // 다음 새 기록의 기본값으로 쓰려고 기억하는 것은 저장 쪽이 한다(여기서는 결과만 본다).
  });

  test('주간 보고 실적에 그 주에 한 시험·교정이 들어간다', () {
    final today = DateTime.now();
    final d = DateTime(today.year, today.month, today.day);
    final tests = weeklyTestsByProject([
      PtRecord(id: '1', date: d, line: 'L-101', projectId: 'p1'),
    ], const []);
    expect(tests['p1']!.single.text, '압력시험 L-101 판정 없음');
    final doc = buildWeeklyPlanDoc([
      {'id': 'p1', 'name': '루마', 'status': 'ONGOING'},
    ], tests: tests);
    final all = doc.sections.expand((s) => s.lines).join('\n');
    expect(all, contains('시험·교정: ${d.month}/${d.day} 압력시험 L-101 판정 없음'));
  });
}
