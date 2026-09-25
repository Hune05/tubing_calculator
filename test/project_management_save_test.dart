import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/repositories/work_project_repository.dart';
import 'package:tubing_calculator/src/presentation/project/project_management_page.dart';

// 서버 대신 저장 기록만 남기는 저장소.
class _FakeRepo extends WorkProjectRepository {
  _FakeRepo(this.items);
  final List<Map<String, dynamic>> items;
  final List<String> saved = [];
  final List<Map<String, dynamic>> savedDocs = [];
  final List<String> deleted = [];

  @override
  Future<List<Map<String, dynamic>>> fetchAllProjects() async => items;

  @override
  Future<void> upsertProject(
    Map<String, dynamic> project, {
    bool merge = true,
  }) async {
    saved.add(project['id'].toString());
    savedDocs.add(Map<String, dynamic>.from(project));
  }

  @override
  Future<void> deleteProject(String id) async => deleted.add(id);
}

Map<String, dynamic> _project(String id, String name) => {
  'id': id,
  'name': name,
  'revision': 'Rev.0',
  'status': 'ONGOING',
  'progress': 0.5,
  'isDeducted': false,
  'materials': [],
  'daily_reports': [],
  'punch_lists': [],
};

void main() {
  testWidgets('진행률을 바꾸면 그 프로젝트 하나만 저장한다(다른 프로젝트는 다시 쓰지 않는다)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo([
      _project('3', 'TEST 셋'),
      _project('2', 'TEST 둘'),
      _project('1', 'TEST 하나'),
    ]);
    await tester.pumpWidget(
      MaterialApp(home: ProjectManagementPage(repository: repo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(LinearProgressIndicator).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(repo.saved, ['2']);
    expect(repo.deleted, isEmpty);
  });

  testWidgets('PC에서 폰 일지를 고쳐도 원래 칸이 남고, 확정된 일지는 사유를 받는다(점검 5번)', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final p = _project('1', 'TEST 하나');
    // 서버에서 읽은 것처럼 List<dynamic>·Map<String, dynamic>.
    p['daily_reports'] = <dynamic>[
      <String, dynamic>{
        'id': 'r-1',
        'date': '09/24',
        'dateISO': '2026-09-24T08:00:00.000',
        'points': 12,
        'note': '결선',
        'author': '폰사람',
        'worker_count': 4,
        'linked_issue_ids': ['i-1'],
        'locked': true,
        'lockedAt': '2026-09-24T18:00:00.000',
      },
    ];
    final repo = _FakeRepo([p]);
    await tester.pumpWidget(
      MaterialApp(home: ProjectManagementPage(repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('TEST 하나'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();

    // 예전: 확정된 일지도 바로 고치는 창이 열렸다.
    expect(find.text('확정된 작업 일지입니다'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('pc_unlock_reason')), '포인트 오기');
    await tester.tap(find.byKey(const Key('pc_unlock_ok')));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '12'), '14');
    final done = find.widgetWithText(ElevatedButton, '수정완료');
    await tester.ensureVisible(done);
    await tester.pumpAndSettle();
    await tester.tap(done);
    await tester.pumpAndSettle();

    final doc = repo.savedDocs.last;
    final reports = doc['daily_reports'] as List;
    // 예전: 아홉 칸짜리 새 일지로 바뀌어 아이디·작성자·인원·연결 이슈가 빠지고 두 벌이 됐다.
    expect(reports.length, 1);
    final r = reports.single as Map;
    expect(r['id'], 'r-1');
    expect(r['points'], 14);
    expect(r['author'], '폰사람');
    expect(r['worker_count'], 4);
    expect(r['linked_issue_ids'], ['i-1']);
    expect(r['locked'], false);
    expect((r['unlockHistory'] as List).single['reason'], '포인트 오기');
    expect(r['updatedAt'], isNotNull);
  });
}
