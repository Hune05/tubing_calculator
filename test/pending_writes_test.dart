import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/pending_write_log.dart';
import 'package:tubing_calculator/src/data/repositories/work_project_repository.dart';
import 'package:tubing_calculator/src/presentation/notification/pages/my_notifications_tab.dart';
import 'package:tubing_calculator/src/presentation/notification/pages/pending_writes_page.dart';

void main() {
  final t0 = DateTime(2026, 9, 30, 10, 0);

  group('PendingWriteLog', () {
    test('시작하면 목록에 생기고 끝나면 사라진다', () {
      final log = PendingWriteLog();
      final a = log.begin(
        projectId: '1',
        projectName: '루마',
        kind: kPendingKindSave,
        now: t0,
      );
      expect(log.entries.value.length, 1);
      log.end(a);
      expect(log.entries.value, isEmpty);
      log.end(a); // 두 번 끝내도 안전
      expect(log.entries.value, isEmpty);
    });

    test('이름이 비면 이름 없는 프로젝트', () {
      final log = PendingWriteLog();
      log.begin(projectId: '1', projectName: '  ', kind: kPendingKindSave);
      expect(log.entries.value.single.projectName, '이름 없는 프로젝트');
    });

    test('프로젝트별로 묶고 오래 기다린 것이 위, 종류는 중복 없이', () {
      final log = PendingWriteLog();
      log.begin(
        projectId: 'b',
        projectName: 'H2',
        kind: kPendingKindSave,
        now: t0.add(const Duration(minutes: 5)),
      );
      log.begin(
        projectId: 'a',
        projectName: '루마',
        kind: kPendingKindSave,
        now: t0,
      );
      log.begin(
        projectId: 'a',
        projectName: '루마',
        kind: kPendingKindSchedule,
        now: t0.add(const Duration(minutes: 1)),
      );
      log.begin(
        projectId: 'a',
        projectName: '루마',
        kind: kPendingKindSave,
        now: t0.add(const Duration(minutes: 2)),
      );
      final g = PendingWriteLog.groupByProject(log.entries.value);
      expect(g.map((e) => e.projectName), ['루마', 'H2']);
      expect(g.first.count, 3);
      expect(g.first.oldest, t0);
      expect(g.first.kinds, [kPendingKindSave, kPendingKindSchedule]);
      expect(PendingWriteLog.namesLabel(log.entries.value), '루마 외 1곳');
    });

    test('이름 글: 없으면 빈 글, 하나면 이름만', () {
      final log = PendingWriteLog();
      expect(PendingWriteLog.namesLabel(log.entries.value), '');
      log.begin(projectId: 'a', projectName: '루마', kind: kPendingKindSave);
      expect(PendingWriteLog.namesLabel(log.entries.value), '루마');
    });

    test('기다린 시간 글', () {
      expect(waitingLabel(t0, t0.add(const Duration(seconds: 20))), '방금부터');
      expect(waitingLabel(t0, t0.add(const Duration(minutes: 12))), '12분째');
      expect(waitingLabel(t0, t0.add(const Duration(hours: 3))), '3시간째');
      expect(waitingLabel(t0, t0.add(const Duration(days: 2))), '2일째');
    });
  });

  group('저장 대기 화면', () {
    testWidgets('비어 있으면 안내가 뜬다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PendingWritesPage(
            log: PendingWriteLog(),
            loadProjects: () async => [],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('기다리는 저장이 없습니다'), findsOneWidget);
    });

    testWidgets('프로젝트 이름과 건수·기다린 시간이 뜨고, 끝나면 사라진다', (tester) async {
      final log = PendingWriteLog();
      final token = log.begin(
        projectId: 'a',
        projectName: '루마',
        kind: kPendingKindSave,
        now: t0,
      );
      log.begin(
        projectId: 'a',
        projectName: '루마',
        kind: kPendingKindSchedule,
        now: t0,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PendingWritesPage(
            log: log,
            loadProjects: () async => [],
            now: () => t0.add(const Duration(minutes: 12)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('루마'), findsOneWidget);
      expect(find.textContaining('변경 내용 저장 · 일정 완료 표시 2건'), findsOneWidget);
      expect(find.textContaining('12분째 대기'), findsOneWidget);

      log.end(token);
      await tester.pump();
      expect(find.textContaining('1건'), findsOneWidget);
    });

    testWidgets('목록을 못 읽어도 화면은 뜬다', (tester) async {
      final log = PendingWriteLog();
      log.begin(projectId: 'a', projectName: '루마', kind: kPendingKindSave);
      await tester.pumpWidget(
        MaterialApp(
          home: PendingWritesPage(
            log: log,
            loadProjects: () async => throw Exception('없음'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('루마'), findsOneWidget);
    });
  });

  testWidgets('내 알림의 저장 대기를 누르면 저장 대기 화면이 열린다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final log = WorkProjectRepository.pendingLog;
    final token = log.begin(
      projectId: 'a',
      projectName: '루마',
      kind: kPendingKindSave,
    );
    WorkProjectRepository.pendingWrites.value = 1;
    addTearDown(() {
      log.end(token);
      WorkProjectRepository.pendingWrites.value = 0;
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MyNotificationsTab(currentWorker: '시험')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('오프라인 저장 대기 1건'), findsOneWidget);
    expect(find.textContaining('루마 — 통신이 없어'), findsOneWidget);

    await tester.tap(find.text('오프라인 저장 대기 1건'));
    await tester.pumpAndSettle();
    expect(find.text('저장 대기'), findsOneWidget); // 앱바 제목
    expect(find.textContaining('12분째'), findsNothing);
    expect(find.text('루마'), findsOneWidget);
  });
}
