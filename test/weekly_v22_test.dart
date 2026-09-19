import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/daily_report_page.dart';

import 'helpers_text.dart';

// 새 일보를 쓸 때 이전 일보로 채우기(배너 → 확인창).
Map<String, dynamic> prev() => {
  'date': '09/18',
  'dateISO': DateTime(2026, 9, 18).toIso8601String(),
  'worker_count': 3,
  'work_type': ['라인 수정'],
  'is_overtime': false,
  'note': '어제 메모',
  'materials_used': '엘보',
};

Future<void> open(WidgetTester tester, {Map<String, dynamic>? previous}) async {
  tester.view.physicalSize = const Size(1080, 2400); // 360dp 폭
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: DailyReportPage(previousReport: previous ?? prev())),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Finder noteField() => find
    .ancestor(
      of: find.textContaining('오늘 작업 내용'),
      matching: find.byType(TextField),
    )
    .first;

CheckboxListTile box(WidgetTester t, String title) =>
    t.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, title));

Future<void> openDialog(WidgetTester tester) async {
  await tester.tap(findText('9월 18일 일보로 채우기'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('배너: 날짜가 들어간 한 줄이고, 옛 버튼 이름은 없다', (tester) async {
    await open(tester);
    final banner = findText('9월 18일 일보로 채우기');
    expect(banner, findsOneWidget);
    expect(tester.getSize(banner).height, lessThan(24), reason: '한 줄');
    expect(find.text('기본 정보만'), findsNothing);
    expect(find.text('내용까지'), findsNothing);
  });

  testWidgets('날짜는 어제가 아니어도 그 일보의 날짜로 나온다', (tester) async {
    final p = prev()
      ..['date'] = '09/12'
      ..['dateISO'] = DateTime(2026, 9, 12).toIso8601String();
    await open(tester, previous: p);
    expect(findText('9월 12일 일보로 채우기'), findsOneWidget);
  });

  testWidgets('dateISO가 없어도 날짜(MM/dd)로 만든다', (tester) async {
    final p = prev()..remove('dateISO');
    await open(tester, previous: p);
    expect(findText('9월 18일 일보로 채우기'), findsOneWidget);
  });

  testWidgets('확인창: 기본 정보는 체크, 작업 내용·자재는 체크 안 된 상태로 시작', (tester) async {
    await open(tester);
    await openDialog(tester);
    expect(findText('9월 18일 일보로 채웁니다'), findsOneWidget);
    expect(box(tester, '단계·유형·인원').value, true);
    expect(box(tester, '작업 내용·자재').value, false);
    expect(findTextContaining('사진, 벤딩·결선 숫자, 이슈는 옮기지 않습니다'), findsOneWidget);
  });

  testWidgets('기본 정보만 채우면 인원이 바뀌고 메모는 비어 있다', (tester) async {
    await open(tester);
    expect(find.text('1명'), findsOneWidget);
    await openDialog(tester);
    await tester.tap(find.text('채우기'));
    await tester.pumpAndSettle();
    expect(find.text('3명'), findsOneWidget);
    expect(find.text('어제 메모'), findsNothing);
    expect(findTextContaining('9월 18일 일보로 채웠습니다'), findsOneWidget);
  });

  testWidgets('작업 내용·자재까지 고르면 비어 있는 칸에 채운다', (tester) async {
    await open(tester);
    await openDialog(tester);
    await tester.tap(find.text('작업 내용·자재'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('채우기'));
    await tester.pumpAndSettle();
    expect(find.text('3명'), findsOneWidget);
    expect(find.text('어제 메모'), findsOneWidget);
  });

  testWidgets('이미 적은 메모는 덮어쓰지 않는다', (tester) async {
    await open(tester);
    await tester.enterText(noteField(), '오늘 메모');
    await tester.pumpAndSettle();
    await openDialog(tester);
    await tester.tap(find.text('작업 내용·자재'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('채우기'));
    await tester.pumpAndSettle();
    expect(find.text('오늘 메모'), findsOneWidget);
    expect(find.text('어제 메모'), findsNothing);
  });

  testWidgets('취소하면 아무것도 바뀌지 않는다', (tester) async {
    await open(tester);
    await openDialog(tester);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('1명'), findsOneWidget);
    expect(find.text('3명'), findsNothing);
  });

  testWidgets('둘 다 체크를 끄면 채우기 버튼이 눌리지 않는다', (tester) async {
    await open(tester);
    await openDialog(tester);
    await tester.tap(find.text('단계·유형·인원'));
    await tester.pumpAndSettle();
    final btn = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '채우기'),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('이전 일보가 없으면 배너가 없다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: DailyReportPage()));
    await tester.pumpAndSettle();
    expect(findTextContaining('일보로 채우기'), findsNothing);
  });
}
