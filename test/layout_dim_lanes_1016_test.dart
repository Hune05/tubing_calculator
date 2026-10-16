// 10-16 배치도 치수: 잴 방향(자동·가로·세로), 같은 줄에서 겹치는 치수는 한 칸씩 띄우기.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/layout_board_models.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';

PlacedItem box(String id, double x, double y) =>
    PlacedItem(id: id, name: id, position: Offset(x, y), width: 40, height: 40);

PlacedDimension dim(String id, PlacedItem a, PlacedItem b, {String? axis}) =>
    PlacedDimension(id: id, p1: a, p2: b, type: DimensionType.center, axis: axis);

void main() {
  group('잴 방향', () {
    final a = box('a', 0, 0); // 가운데 (20,20)
    final b = box('b', 200, 60); // 가운데 (220,80)
    test('자동은 긴 쪽(가로 200)', () {
      expect(computeDimensionEndpoints(dim('d', a, b)).distance, 200);
    });
    test('세로를 고르면 세로 센터 차이 60', () {
      final e = computeDimensionEndpoints(dim('d', a, b, axis: 'v'));
      expect(e.distance, 60);
      expect(e.p1.dx, e.p2.dx);
    });
    test('저장·불러오기: axis 칸은 있을 때만, 옛 저장본은 자동', () {
      expect(dim('d', a, b).toJson().containsKey('axis'), isFalse);
      final j = dim('d', a, b, axis: 'h').toJson();
      expect(j['axis'], 'h');
      final back = PlacedDimension.fromJson(jsonDecode(jsonEncode(j)));
      expect(back.axis, 'h');
    });
  });

  group('겹 치수', () {
    final a = box('a', 100, 0); // (120,20)
    final b = box('b', 100, 100); // (120,120)
    final c = box('c', 100, 210); // (120,230)
    final d = box('d', 100, 320); // (120,340)
    test('한 부품에서 아래 셋으로 — 짧은 것 그대로, 나머지 왼쪽으로 한 칸씩', () {
      final dims = [dim('ad', a, d), dim('ab', a, b), dim('ac', a, c)];
      final l = layoutDimensionLanes(dims, gap: 20);
      expect(l['ab']!.lane, 0);
      expect(l['ac']!.lane, 1);
      expect(l['ad']!.lane, 2);
      expect(l['ac']!.p1.dx, 100); // 120 - 20
      expect(l['ad']!.p1.dx, 80);
      // 값은 그대로
      expect(l['ad']!.distance, 320);
      expect(l['ad']!.origin1, const Offset(120, 20));
    });
    test('도면 왼쪽 끝에 붙어 있으면 오른쪽으로 띄운다(테두리에 잘리지 않게)', () {
      final e = box('e', 0, 0), f = box('f', 0, 100), g = box('g', 0, 210);
      final l = layoutDimensionLanes([dim('ef', e, f), dim('eg', e, g)], gap: 30);
      expect(l['eg']!.lane, 1);
      expect(l['eg']!.p1.dx, 50); // 20 + 30
    });
    test('끝만 닿는 체인(a→b, b→c)은 같은 줄', () {
      final l = layoutDimensionLanes([dim('ab', a, b), dim('bc', b, c)], gap: 20);
      expect(l['ab']!.lane, 0);
      expect(l['bc']!.lane, 0);
    });
  });

  testWidgets('치수 도구에 방향 고르기, 세로로 찍으면 세로 치수가 생긴다', (t) async {
    SharedPreferences.setMockInitialValues({
      'layout_board_onboarding_shown_v1': true,
      'layout_board_draft_v1': jsonEncode({
        'projectId': null,
        'projectName': 'T',
        'panelWidth': 600,
        'panelHeight': 800,
        'items': [
          {'type': 'item', 'id': 'a', 'name': 'A', 'x': 40, 'y': 40},
          {'type': 'item', 'id': 'b', 'name': 'B', 'x': 240, 'y': 300},
        ],
        'dimensions': <Map>[],
      }),
    });
    t.view.physicalSize = const Size(780, 1688);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: LayoutBoardPage()));
    await t.pump(const Duration(milliseconds: 100));
    await t.pumpAndSettle();
    await t.tap(find.text('이어하기'));
    await t.pumpAndSettle();
    await t.tap(find.text('치수'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('dim_axis_auto')), findsOneWidget);
    await t.tap(find.byKey(const Key('dim_axis_v')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('a')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('b')));
    await t.pumpAndSettle();
    // 같은 두 부품에 가로도 하나 더
    await t.tap(find.byKey(const Key('dim_axis_h')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('a')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('b')));
    await t.pumpAndSettle();
    final state = t.state(find.byType(LayoutBoardPage)) as dynamic;
    final plates = state.debugPlates() as Map<String, Map<String, dynamic>>;
    final dims = (plates['main']!['dimensions'] as List).cast<Map>();
    expect(dims.length, 2);
    expect(dims.map((d) => d['axis']).toSet(), {'v', 'h'});
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
}
