// 10-13: "이어서 작업하시겠습니까?" 창을 시스템 뒤로 가기로 닫으면 이어하기로 본다.
// 예전엔 "새로 시작"과 같아 저장 안 한 임시 작업이 말없이 지워졌다(기기 확인 중 두 기기에서 잃음).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';

Map<String, dynamic> draft() => {
  'kind': kLayoutKindCabinet,
  'projectName': '임시 작업',
  'panelWidth': 600,
  'panelHeight': 800,
  'items': [
    {
      'type': 'item',
      'id': 'a',
      'name': '차단기 A',
      'x': 40,
      'y': 40,
      'w': 80,
      'h': 80,
    },
  ],
  'dimensions': [],
};

Future<void> openAsking(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'layout_board_onboarding_shown_v1': true,
    'layout_board_draft_v1': jsonEncode(draft()),
  });
  tester.view.physicalSize = const Size(390, 844) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: LayoutBoardPage()));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
  expect(find.text('이어서 작업하시겠습니까?'), findsOneWidget);
}

Finder onBoard(String name) => find.descendant(
  of: find.byType(InteractiveViewer),
  matching: find.text(name),
);

void main() {
  testWidgets('뒤로 가기로 창을 닫으면 임시 작업이 펴지고 지워지지 않는다', (tester) async {
    await openAsking(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('이어서 작업하시겠습니까?'), findsNothing);
    expect(onBoard('차단기 A'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('layout_board_draft_v1'), isNotNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('"새로 시작"을 눌렀을 때만 임시 작업을 지운다', (tester) async {
    await openAsking(tester);
    await tester.tap(find.text('새로 시작'));
    await tester.pumpAndSettle();
    expect(onBoard('차단기 A'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('layout_board_draft_v1'), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
