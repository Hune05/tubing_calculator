// 안전 점검 "조치 필요" → 프로젝트 이슈(10-10): 저장한 뒤 프로젝트를 고르면 그 항목들이 이슈로 들어가고,
// 같은 점검의 같은 항목은 두 번 들어가지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/repositories/work_project_repository.dart';
import 'package:tubing_calculator/src/presentation/safety/safety_check_model.dart';
import 'package:tubing_calculator/src/presentation/safety/safety_check_page.dart';
import 'package:tubing_calculator/src/presentation/safety/safety_issue_link.dart';

final _at = DateTime(2026, 10, 10, 8, 5);

class _FakeRepo extends WorkProjectRepository {
  final List<Map<String, dynamic>> projects;
  Map<String, dynamic>? saved;
  _FakeRepo(this.projects);

  @override
  Future<List<Map<String, dynamic>>> fetchCachedProjects() async => [
    for (final p in projects) Map<String, dynamic>.from(p),
  ];

  @override
  Future<List<Map<String, dynamic>>> fetchAllProjects() async =>
      fetchCachedProjects();

  @override
  Future<void> upsertProject(
    Map<String, dynamic> project, {
    bool merge = true,
    void Function()? onWritten,
  }) async {
    saved = project;
    onWritten?.call();
  }
}

SafetyRecord _rec() => SafetyRecord(
  id: '77',
  at: _at,
  site: '1층 계장실',
  work: '센서 결선',
  lines: const [
    SafetyLine('작업허가서 확인', SafetyAnswer.yes),
    SafetyLine('보호구 착용', SafetyAnswer.fix),
    SafetyLine('통로 확보', SafetyAnswer.fix),
  ],
);

void main() {
  test('조치 필요 항목만 이슈로, 위치·작업·긴급·안전 유형, 이미 올린 항목은 뺀다', () {
    final r = _rec();
    final project = <String, dynamic>{'name': 'TEST', 'punch_lists': []};
    final adds = safetyIssuesFor(r, project, now: _at, who: '홍길동');
    expect(adds.map((e) => e['content']), [
      '[안전 점검] 보호구 착용 (작업: 센서 결선)',
      '[안전 점검] 통로 확보 (작업: 센서 결선)',
    ]);
    expect(adds.first['location'], '1층 계장실');
    expect(adds.first['priority'], '긴급');
    expect(adds.first['defect_type'], '안전');
    expect(adds.first['is_completed'], false);
    expect(adds.first['author'], '홍길동');
    expect(adds[0]['id'], isNot(adds[1]['id']));

    project['punch_lists'] = [adds.first];
    final again = safetyIssuesFor(r, project, now: _at);
    expect(again.map((e) => e['safetyItem']), ['통로 확보']);
  });

  test('글과 결과 한 마디에 조치 필요가 나온다', () {
    final r = _rec();
    expect(buildSafetyCheckText(r), contains('✖ 보호구 착용 (조치 필요)'));
    expect(safetyResultLabel(r), '조치 필요 2개');
    expect(
      safetyResultLabel(
        SafetyRecord(
          id: '1',
          at: _at,
          lines: const [SafetyLine('a', SafetyAnswer.yes)],
        ),
      ),
      '항목 모두 확인',
    );
  });

  group('화면', () {
    late _FakeRepo repo;
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repo = _FakeRepo([
        {'id': 'p1', 'name': '루마 현장', 'status': 'ACTIVE', 'punch_lists': []},
        {'id': 'p2', 'name': '끝난 현장', 'status': 'DONE'},
      ]);
      safetyIssueRepo = () => repo;
    });
    tearDown(() => safetyIssueRepo = WorkProjectRepository.new);

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: SafetyCheckPage(share: (t) async {}, now: () => _at),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('조치 필요로 저장하면 프로젝트를 묻고, 고르면 이슈로 들어간다', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('safety_fix_보호구 착용 (안전모·안전화·보안경·장갑)')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('safety_save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('safety_confirm_go')));
      await tester.pumpAndSettle();
      // 진행 중인 프로젝트만 보인다.
      expect(find.text('조치 필요 1건을 이슈로 올릴 프로젝트'), findsOneWidget);
      expect(find.text('루마 현장'), findsOneWidget);
      expect(find.text('끝난 현장'), findsNothing);
      await tester.tap(find.byKey(const Key('safety_issue_project_p1')));
      await tester.pumpAndSettle();
      final punches = repo.saved!['punch_lists'] as List;
      expect(punches.length, 1);
      expect(
        (punches.single as Map)['content'],
        '[안전 점검] 보호구 착용 (안전모·안전화·보안경·장갑)',
      );
      expect(find.text("'루마 현장' 이슈에 1건을 올렸습니다."), findsOneWidget);
    });

    testWidgets('"나중에"를 고르면 이슈를 넣지 않는다', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('safety_fix_보호구 착용 (안전모·안전화·보안경·장갑)')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('safety_save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('safety_confirm_go')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('safety_issue_later')));
      await tester.pumpAndSettle();
      expect(repo.saved, isNull);
      // 기록은 저장됐고, 조치 필요가 남아 있다.
      final saved = await loadSafetyRecords();
      expect(saved.single.fixCount, 1);
    });
  });
}
