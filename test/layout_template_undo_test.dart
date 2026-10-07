// 배치도 템플릿 적용을 되돌리면 측판 부품도 돌아온다(10-07).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';

Map<String, dynamic> _withLeft(int n) => {
  'kind': 'cabinet',
  'sidePlatesOn': true,
  'panelWidth': 600,
  'panelHeight': 800,
  'items': [
    {'type': 'item', 'id': 'm1', 'name': '차단기', 'x': 40, 'y': 40},
  ],
  'dimensions': [],
  'sidePlates': {
    'left': {
      'panelWidth': 300,
      'panelHeight': 800,
      'items': [
        for (var i = 0; i < n; i++)
          {'type': 'item', 'id': 'l$i', 'name': '단자 $i', 'x': 10 + i * 40, 'y': 20},
      ],
      'dimensions': [],
    },
  },
};

void main() {
  testWidgets('측판 부품이 있는 도면에 템플릿을 적용했다가 되돌리면 측판 부품이 돌아온다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'layout_board_onboarding_shown_v1': true,
      'layout_board_draft_v1': jsonEncode({'projectId': null, 'items': [], 'dimensions': []}),
    });
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: LayoutBoardPage()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    if (find.text('새로 시작').evaluate().isNotEmpty) {
      await tester.tap(find.text('새로 시작'));
      await tester.pumpAndSettle();
    }
    final dynamic st = tester.state(find.byType(LayoutBoardPage));
    st.debugApplyTemplate(_withLeft(2)); // 빈 도면: 묻지 않고 적용
    await tester.pumpAndSettle();
    expect(st.debugPlateItemCount('left'), 2);
    st.debugApplyTemplate(_withLeft(0)); // 내용이 있으면 묻는다
    await tester.pumpAndSettle();
    final ok = find.text('적용');
    if (ok.evaluate().isNotEmpty) {
      await tester.tap(ok.last);
      await tester.pumpAndSettle();
    }
    expect(st.debugPlateItemCount('left'), 0);
    st.debugUndo();
    await tester.pumpAndSettle();
    expect(st.debugPlateItemCount('left'), 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
