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
  final List<String> deleted = [];

  @override
  Future<List<Map<String, dynamic>>> fetchAllProjects() async => items;

  @override
  Future<void> upsertProject(Map<String, dynamic> project) async {
    saved.add(project['id'].toString());
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
}
