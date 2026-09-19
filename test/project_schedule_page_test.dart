import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/project_schedule_page.dart';

import 'helpers_text.dart';

// 프로젝트 일정 화면(목록·필터·달력·새 일정 입력)의 기본 동작.
List<Map<String, dynamic>> sample() {
  final t = DateTime.now();
  return [
    {
      'id': 's1',
      'title': '도면 검토',
      'type': '검사일정',
      'dateTime': DateTime(t.year, t.month, 20, 10),
      'isCompleted': false,
    },
    {
      'id': 's2',
      'title': '덕트 입고',
      'type': '입고일',
      'dateTime': DateTime(t.year, t.month, 22, 9),
      'isCompleted': false,
    },
    {
      'id': 's3',
      'title': '끝난 일정',
      'type': '납기일',
      'dateTime': DateTime(t.year, t.month, 5, 9),
      'isCompleted': true,
    },
  ];
}

Future<void> open(WidgetTester tester, {bool openEditor = false}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: ProjectSchedulePage(
        projectName: '시험 현장',
        initialSchedules: sample(),
        openEditorOnStart: openEditor,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('목록: 끝난 일정은 기본으로 숨기고, 완료 표시를 누르면 보인다', (tester) async {
    await open(tester);
    expect(tester.takeException(), isNull);
    expect(findTextContaining('도면 검토'), findsOneWidget);
    expect(findTextContaining('덕트 입고'), findsOneWidget);
    expect(findTextContaining('끝난 일정'), findsNothing);
    await tester.tap(find.text('완료 숨김'));
    await tester.pumpAndSettle();
    expect(find.text('완료 표시'), findsOneWidget);
    expect(findTextContaining('끝난 일정'), findsOneWidget);
  });

  testWidgets('필터: 자재 요청/입고일만 모아 본다', (tester) async {
    await open(tester);
    await tester.tap(find.text('자재 요청/입고일'));
    await tester.pumpAndSettle();
    expect(findTextContaining('덕트 입고'), findsOneWidget);
    expect(findTextContaining('도면 검토'), findsNothing);
    await tester.tap(find.text('전체'));
    await tester.pumpAndSettle();
    expect(findTextContaining('도면 검토'), findsOneWidget);
  });

  testWidgets('달력으로 바꿨다가 목록으로 돌아온다', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('달력으로 보기'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('리스트로 보기'), findsOneWidget);
    await tester.tap(find.byTooltip('리스트로 보기'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('달력으로 보기'), findsOneWidget);
    expect(findTextContaining('도면 검토'), findsOneWidget);
  });

  testWidgets('열자마자 새 일정 입력창을 띄울 수 있다', (tester) async {
    await open(tester, openEditor: true);
    expect(tester.takeException(), isNull);
    // 입력창(바텀시트)에는 글자를 적는 칸이 있다.
    expect(find.byType(TextField), findsWidgets);
  });
}
