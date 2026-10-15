// 10-16 배치도 부품 끌기: 길게 누른 채 끌기, 겹친 채 시작한 부품 빠져나오기, "치수" 상태에서도 끌기.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';

Map<String, dynamic> draft({bool overlap = false}) => {
  'projectId': null,
  'projectName': 'T',
  'panelWidth': 600,
  'panelHeight': 800,
  'items': [
    {'type': 'item', 'id': 'a', 'name': 'A', 'x': 40, 'y': 40},
    {
      'type': 'item',
      'id': 'b',
      'name': 'B',
      'x': overlap ? 60 : 300,
      'y': overlap ? 60 : 500,
      'w': 160,
      'h': 60,
    },
  ],
  'dimensions': <Map>[],
};

Future<void> open(WidgetTester t, {bool overlap = false}) async {
  SharedPreferences.setMockInitialValues({
    'layout_board_onboarding_shown_v1': true,
    'layout_board_draft_v1': jsonEncode(draft(overlap: overlap)),
  });
  t.view.physicalSize = const Size(780, 1688);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(const MaterialApp(home: LayoutBoardPage()));
  await t.pump(const Duration(milliseconds: 100));
  await t.pumpAndSettle();
  await t.tap(find.text('이어하기'));
  await t.pumpAndSettle();
}

Offset posA(WidgetTester t) {
  final state = t.state(find.byType(LayoutBoardPage)) as dynamic;
  final plates = state.debugPlates() as Map<String, Map<String, dynamic>>;
  final m = (plates['main']!['items'] as List).cast<Map>().firstWhere(
    (e) => e['id'] == 'a',
  );
  return Offset((m['x'] as num).toDouble(), (m['y'] as num).toDouble());
}

Future<void> dragA(WidgetTester t, {int holdMs = 0, bool corner = false}) async {
  // corner: 겹친 B가 A 가운데를 덮으므로 A만 있는 왼쪽 위 귀퉁이를 잡는다.
  final Rect r = t.getRect(find.byKey(const ValueKey('a')));
  final g = await t.startGesture(
    corner ? r.topLeft + Offset(r.width * 0.1, r.height * 0.1) : r.center,
  );
  await t.pump(Duration(milliseconds: holdMs));
  for (int i = 0; i < 10; i++) {
    await g.moveBy(const Offset(8, 6));
    await t.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await t.pumpAndSettle();
}

Future<void> close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

void main() {
  for (final hold in [0, 300, 700, 1200]) {
    testWidgets('$hold ms 누르고 있다가 끌어도 움직인다', (t) async {
      await open(t);
      await dragA(t, holdMs: hold);
      expect(posA(t), isNot(const Offset(40, 40)));
      expect(posA(t).dx, greaterThan(60));
      await close(t);
    });
  }

  testWidgets('길게 누르고 움직이지 않고 떼면 예전처럼 여러 개 고르기', (t) async {
    await open(t);
    final g = await t.startGesture(t.getCenter(find.byKey(const ValueKey('a'))));
    await t.pump(const Duration(milliseconds: 800));
    await g.up();
    await t.pumpAndSettle();
    expect(posA(t), const Offset(40, 40));
    final state = t.state(find.byType(LayoutBoardPage)) as dynamic;
    expect(state.debugMultiSelectedIds as Set<String>, contains('a'));
    await close(t);
  });

  testWidgets('이미 겹친 채로 시작한 부품도 끌어서 빼낼 수 있다', (t) async {
    await open(t, overlap: true);
    await dragA(t, corner: true);
    expect(posA(t), isNot(const Offset(40, 40)));
    await close(t);
  });

  testWidgets('"치수" 상태에서도 부품을 끈다', (t) async {
    await open(t);
    await t.tap(find.text('치수'));
    await t.pumpAndSettle();
    await dragA(t);
    expect(posA(t), isNot(const Offset(40, 40)));
    await close(t);
  });
}
