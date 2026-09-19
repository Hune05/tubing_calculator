import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/daily_report_page.dart';

import 'helpers_text.dart';

// 새 작업 일지를 쓸 때 이전 작업 일지에서 날짜를 골라 채우기(배너 → 넓은 선택 창).
Map<String, dynamic> log(
  int day, {
  required int workers,
  required List<String> types,
  String note = '',
  String materials = '',
  int month = 9,
}) => {
  'date':
      '${month.toString().padLeft(2, '0')}/${day.toString().padLeft(2, '0')}',
  'dateISO': DateTime(2026, month, day).toIso8601String(),
  'worker_count': workers,
  'work_type': types,
  'is_overtime': false,
  'note': note,
  'materials_used': materials,
};

// 일부러 오래된 것부터 넣는다(화면에서는 최근 것이 위).
List<Map<String, dynamic>> sample() => [
  log(15, workers: 2, types: ['신규 설치'], note: '특이사항 없음'),
  log(18, workers: 5, types: ['결선/트레이싱'], note: '전날 메모'),
  log(19, workers: 3, types: ['라인 수정'], note: '최근 메모', materials: '엘보'),
];

Future<void> open(
  WidgetTester tester, {
  List<Map<String, dynamic>>? reports,
  Map<String, dynamic>? single,
}) async {
  tester.view.physicalSize = const Size(1080, 2400); // 360dp 폭
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: DailyReportPage(
        previousReports: reports ?? sample(),
        previousReport: single,
      ),
    ),
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
  await tester.tap(findText('이전 작업 일지에서 채우기'));
  await tester.pumpAndSettle();
}

Future<void> pick(WidgetTester tester, int i) async {
  await tester.tap(find.byKey(ValueKey('fill_pick_$i')));
  await tester.pumpAndSettle();
}

Finder inRow(int i, String text) => find.descendant(
  of: find.byKey(ValueKey('fill_pick_$i')),
  matching: find.byWidgetPredicate(
    (w) => w is Text && (w.data ?? '').replaceAll('⁠', '').contains(text),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('배너: 한 줄이고 옛 이름은 없다', (tester) async {
    await open(tester);
    final banner = findText('이전 작업 일지에서 채우기');
    expect(banner, findsOneWidget);
    expect(tester.getSize(banner).height, lessThan(24), reason: '한 줄');
    expect(find.text('기본 정보만'), findsNothing);
    expect(find.text('내용까지'), findsNothing);
    expect(findTextContaining('일보'), findsNothing);
  });

  testWidgets('선택 창: 최근 것이 위, 날짜·요일·유형·인원이 보인다', (tester) async {
    await open(tester);
    await openDialog(tester);
    expect(findText('채울 작업 일지를 선택하십시오'), findsOneWidget);
    expect(find.byKey(const ValueKey('fill_pick_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('fill_pick_2')), findsOneWidget);
    expect(find.byKey(const ValueKey('fill_pick_3')), findsNothing);
    expect(inRow(0, '9월 19일 (토)'), findsOneWidget);
    expect(inRow(1, '9월 18일 (금)'), findsOneWidget);
    expect(inRow(2, '9월 15일 (화)'), findsOneWidget);
    expect(inRow(0, '라인 수정'), findsOneWidget);
    expect(inRow(0, '3명'), findsOneWidget);
    expect(inRow(0, '최근 메모'), findsOneWidget);
  });

  testWidgets('선택 창은 폭이 넓다(폰 폭에서 좌우 여백만 남김)', (tester) async {
    await open(tester);
    await openDialog(tester);
    final w = tester.getSize(find.byType(Dialog)).width;
    expect(w, greaterThan(330), reason: '360dp 폭에서 330dp 넘게');
  });

  testWidgets('처음에는 가장 최근이 골라져 있고, 기본 정보만 체크', (tester) async {
    await open(tester);
    await openDialog(tester);
    expect(box(tester, '단계·유형·인원').value, true);
    expect(box(tester, '작업 내용·자재').value, false);
    expect(findTextContaining('9월 19일 (토) 작업 일지에서 채워질 내용'), findsOneWidget);
    expect(findTextContaining('인원: 3명'), findsOneWidget);
    expect(findTextContaining('유형: 라인 수정'), findsOneWidget);
    expect(findTextContaining('작업 내용:'), findsNothing);
  });

  testWidgets('다른 날짜를 고르면 미리 보기가 바뀌고, 그 날짜로 채운다', (tester) async {
    await open(tester);
    await openDialog(tester);
    await pick(tester, 1);
    expect(findTextContaining('9월 18일 (금) 작업 일지에서 채워질 내용'), findsOneWidget);
    expect(findTextContaining('인원: 5명'), findsOneWidget);
    await tester.tap(find.text('채우기'));
    await tester.pumpAndSettle();
    expect(find.text('5명'), findsOneWidget);
    expect(findTextContaining('9월 18일 (금) 작업 일지로 채웠습니다'), findsOneWidget);
  });

  testWidgets('작업 내용·자재까지 고르면 그 날짜의 내용이 비어 있는 칸에 들어간다', (tester) async {
    await open(tester);
    await openDialog(tester);
    await pick(tester, 1);
    await tester.tap(find.text('작업 내용·자재'));
    await tester.pumpAndSettle();
    expect(findTextContaining('작업 내용: 전날 메모'), findsOneWidget);
    await tester.tap(find.text('채우기'));
    await tester.pumpAndSettle();
    expect(find.text('전날 메모'), findsOneWidget);
  });

  testWidgets('특이사항 없음은 작업 내용으로 옮기지 않는다', (tester) async {
    await open(tester);
    await openDialog(tester);
    await pick(tester, 2);
    await tester.tap(find.text('작업 내용·자재'));
    await tester.pumpAndSettle();
    expect(findTextContaining('작업 내용: 없음'), findsOneWidget);
    await tester.tap(find.text('채우기'));
    await tester.pumpAndSettle();
    expect(find.text('특이사항 없음'), findsNothing);
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
    expect(find.text('최근 메모'), findsNothing);
  });

  testWidgets('취소하면 아무것도 바뀌지 않는다', (tester) async {
    await open(tester);
    await openDialog(tester);
    await pick(tester, 1);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('1명'), findsOneWidget);
    expect(find.text('5명'), findsNothing);
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

  testWidgets('예전 방식(previousReport 하나만)도 그대로 된다', (tester) async {
    await open(
      tester,
      reports: const [],
      single: log(18, workers: 4, types: ['라인 수정']),
    );
    await openDialog(tester);
    expect(find.byKey(const ValueKey('fill_pick_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('fill_pick_1')), findsNothing);
    await tester.tap(find.text('채우기'));
    await tester.pumpAndSettle();
    expect(find.text('4명'), findsOneWidget);
  });

  testWidgets('이전 작업 일지가 없으면 배너가 없다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: DailyReportPage()));
    await tester.pumpAndSettle();
    expect(findTextContaining('작업 일지에서 채우기'), findsNothing);
  });
}
