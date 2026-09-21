import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';

// 작업 배치도 화면은 하나다. 화면 폭에 따라 모양만 바뀌고, 폴드를 펴고 접어도
// 저장 안 한 작업(배치·되돌리기 기록)이 그대로 남아야 한다.

const Size kPhone = Size(390, 844);
const Size kTablet = Size(1024, 768);

void setSize(WidgetTester tester, Size s) {
  tester.view.physicalSize = s * 2;
  tester.view.devicePixelRatio = 2;
}

Map<String, dynamic> oldDraft() => {
  'projectId': null,
  'projectName': '1호기 분전반',
  'panelWidth': 600,
  'panelHeight': 800,
  'items': [
    {'type': 'item', 'id': 'a', 'name': '차단기 A', 'x': 40, 'y': 40},
    {
      'type': 'item',
      'id': 'd',
      'name': '단자대',
      'x': 200,
      'y': 200,
      'w': 160,
      'h': 60,
    },
  ],
  'dimensions': [],
};

Future<void> pumpBoard(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: LayoutBoardPage()));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

// 화면에 있는 20초 임시 저장 타이머를 정리한다.
Future<void> disposeBoard(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'layout_board_onboarding_shown_v1': true,
    });
  });

  test('넓은 모양 기준: 가로 900 이상만 양옆 칸을 둔다', () {
    expect(layoutBoardUsesWideLayout(kPhone), false);
    expect(layoutBoardUsesWideLayout(const Size(673, 841)), false); // 폴드 편 화면
    expect(layoutBoardUsesWideLayout(const Size(844, 390)), false); // 폰 가로
    expect(layoutBoardUsesWideLayout(kTablet), true);
    expect(layoutBoardUsesWideLayout(const Size(1280, 800)), true);
  });

  testWidgets('폰 폭에서는 아래 팔레트, 태블릿 폭에서는 양옆 칸이 보인다', (tester) async {
    setSize(tester, kPhone);
    addTearDown(tester.view.reset);
    await pumpBoard(tester);
    expect(find.text('신규 모듈'), findsOneWidget);
    expect(find.text('자재 라이브러리'), findsNothing);

    setSize(tester, kTablet);
    await tester.pumpAndSettle();
    expect(find.text('자재 라이브러리'), findsOneWidget);
    expect(find.text('모듈 편집'), findsOneWidget);
    expect(find.text('신규 박스 모듈'), findsOneWidget);
    await disposeBoard(tester);
  });

  testWidgets('화면 폭이 바뀌어도 저장 안 한 배치와 되돌리기 기록이 남는다', (tester) async {
    setSize(tester, kPhone);
    addTearDown(tester.view.reset);
    await pumpBoard(tester);

    await tester.tap(find.text('샘플 배치 불러오기'));
    await tester.pumpAndSettle();
    expect(find.text('차단기 A'), findsOneWidget);

    // 폴드를 편다(넓은 모양)
    setSize(tester, kTablet);
    await tester.pumpAndSettle();
    expect(find.text('자재 라이브러리'), findsOneWidget);
    expect(find.text('차단기 A'), findsOneWidget);
    expect(find.text('차단기 B'), findsOneWidget);

    // 다시 접는다
    setSize(tester, kPhone);
    await tester.pumpAndSettle();
    expect(find.text('자재 라이브러리'), findsNothing);
    expect(find.text('차단기 A'), findsOneWidget);

    // 되돌리기 기록도 그대로라, 되돌리면 샘플을 불러오기 전(빈 도면)으로 간다.
    await tester.tap(find.byTooltip('되돌리기'));
    await tester.pumpAndSettle();
    expect(find.text('차단기 A'), findsNothing);
    await disposeBoard(tester);
  });

  testWidgets('예전 태블릿 화면이 남긴 임시 저장도 이어서 열 수 있다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'layout_board_onboarding_shown_v1': true,
      'tablet_layout_board_draft_v1': jsonEncode(oldDraft()),
    });
    setSize(tester, kTablet);
    addTearDown(tester.view.reset);
    await pumpBoard(tester);
    expect(find.text('이어하기'), findsOneWidget);
    await tester.tap(find.text('이어하기'));
    await tester.pumpAndSettle();
    expect(find.text('단자대'), findsOneWidget);
    expect(find.text('1호기 분전반'), findsOneWidget);
    await disposeBoard(tester);
  });

  testWidgets('새로 시작을 고르면 두 임시 저장 자리를 모두 지운다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'layout_board_onboarding_shown_v1': true,
      'layout_board_draft_v1': jsonEncode(oldDraft()),
      'tablet_layout_board_draft_v1': jsonEncode(oldDraft()),
    });
    setSize(tester, kPhone);
    addTearDown(tester.view.reset);
    await pumpBoard(tester);
    await tester.tap(find.text('새로 시작'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('layout_board_draft_v1'), isNull);
    expect(prefs.getString('tablet_layout_board_draft_v1'), isNull);
    expect(find.text('단자대'), findsNothing);
    await disposeBoard(tester);
  });

  testWidgets('넓은 화면에서 모듈을 누르면 오른쪽 칸에서 고칠 수 있다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'layout_board_onboarding_shown_v1': true,
      'layout_board_draft_v1': jsonEncode(oldDraft()),
    });
    setSize(tester, kTablet);
    addTearDown(tester.view.reset);
    await pumpBoard(tester);
    await tester.tap(find.text('이어하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('단자대'));
    await tester.pumpAndSettle();
    expect(find.text('모듈 이름'), findsOneWidget);

    // 폭을 줄이면 오른쪽 칸이 없어지니 선택만 풀리고 배치는 남는다.
    setSize(tester, kPhone);
    await tester.pumpAndSettle();
    expect(find.text('모듈 이름'), findsNothing);
    expect(find.text('단자대'), findsOneWidget);
    await disposeBoard(tester);
  });

  // 입력 칸 안의 글(컨트롤러 값)로 찾는다.
  Finder fieldWith(String v) => find.byWidgetPredicate(
    (w) => w is EditableText && w.controller.text == v,
    skipOffstage: false,
  );

  testWidgets('넓은 화면 오른쪽 칸: 크기를 치고 완료 없이 다른 칸을 눌러도 값이 들어간다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'layout_board_onboarding_shown_v1': true,
      'layout_board_draft_v1': jsonEncode(oldDraft()),
    });
    setSize(tester, kTablet);
    addTearDown(tester.view.reset);
    await pumpBoard(tester);
    await tester.tap(find.text('이어하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('단자대'));
    await tester.pumpAndSettle();

    final Finder widthField = fieldWith('160');
    expect(widthField, findsOneWidget);
    await tester.ensureVisible(widthField);
    await tester.pumpAndSettle();
    await tester.enterText(widthField, '240');
    await tester.pump();
    // 완료를 누르지 않고 세로 칸으로 옮긴다.
    await tester.tap(fieldWith('60'));
    await tester.pumpAndSettle();
    // 다른 모듈을 골랐다가 돌아와도 친 값이 남아 있다(모듈에 들어갔다).
    await tester.tap(
      find.descendant(
        of: find.byType(InteractiveViewer),
        matching: find.text('차단기 A'),
      ),
    );
    await tester.pumpAndSettle();
    expect(fieldWith('240'), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(InteractiveViewer),
        matching: find.text('단자대'),
      ),
    );
    await tester.pumpAndSettle();
    expect(fieldWith('240'), findsOneWidget);
    // 모듈을 누르기만 한 기록은 건너뛰고, 되돌리기 한 번이면 예전 크기로 돌아온다.    await tester.tap(find.byTooltip('되돌리기'));    await tester.pumpAndSettle();    await tester.tap(find.descendant(of: find.byType(InteractiveViewer), matching: find.text('단자대')));    await tester.pumpAndSettle();    expect(fieldWith('160'), findsOneWidget);
    await disposeBoard(tester);
  });
}
