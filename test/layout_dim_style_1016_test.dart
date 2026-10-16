// 10-16 배치도 치수 모양: 앱식 · 캐드식(부품 밖 치수선·보조선·화살표) · 좌표(위·왼쪽 벽에서 부품 센터까지).
import 'dart:convert';
import 'dart:ui' show instantiateImageCodec;

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
  group('캐드식: 판 밖 여백', () {
    PlacedItem d(String id, double x, double y, double w, double hh) =>
        PlacedItem(id: id, name: id, position: Offset(x, y), width: w, height: hh);
    // 사용자 배치(10-16): 가로 덕트 셋, 세로 덕트 둘
    final t = d('t', 63, 7, 470, 60), m = d('m', 63, 247, 470, 60), b = d('b', 63, 477, 470, 60);
    final l = d('l', 3, 7, 50, 785), r = d('r', 537, 7, 50, 785);

    test('가로 치수는 위 여백(음수 y), 세로 치수는 왼쪽 여백(음수 x), 보조선은 원래 센터에서', () {
      final res = layoutMarginDimensionLanes([dim('tm', t, m), dim('lr', l, r)], gap: 20);
      expect(res.lanes['lr']!.p1.dy, -20);
      expect(res.lanes['lr']!.origin1, const Offset(28, 399.5));
      expect(res.lanes['tm']!.p1.dx, -20);
      expect(res.lanes['tm']!.distance, 240);
      expect(res.topLanes, 1);
      expect(res.leftLanes, 1);
    });
    test('이어지는 치수(240·230)는 같은 줄, 겹치는 긴 치수는 한 줄 바깥', () {
      final res = layoutMarginDimensionLanes(
        [dim('tb', t, b), dim('tm', t, m), dim('mb', m, b)],
        gap: 20,
      );
      expect(res.lanes['tm']!.p1.dx, -20);
      expect(res.lanes['mb']!.p1.dx, -20);
      expect(res.lanes['tb']!.p1.dx, -40);
      expect(res.leftLanes, 2);
      // 판 크기 줄은 그 바깥, 여백은 숫자 자리까지
      expect(MarginDimLayout.lineAt(res.leftLanes, 20), -60);
      expect(res.leftMargin(20), closeTo(78, 0.01));
    });
    test('대각선은 판 안 그대로(줄 0)', () {
      final x = PlacedDimension(id: 'x', p1: t, p2: r, type: DimensionType.center, isDiagonal: true);
      final res = layoutMarginDimensionLanes([x], gap: 20);
      expect(res.lanes['x']!.lane, 0);
      expect(res.topLanes, 0);
    });
  });

  test('좌표 값: 부품 센터, 같은 값은 한 번, 메모는 뺀다', () {
    final items = [
      box('a', 100, 100), // (120,120)
      box('b', 100, 300), // (120,320)
      box('c', 300, 100), // (320,120)
      PlacedItem(id: 'n', name: '메모', position: const Offset(50, 50), shape: InstrumentShape.note),
    ];
    final v = ordinateValues(items);
    expect(v.xs.map((e) => e.$1), [120, 320]);
    expect(v.ys.map((e) => e.$1), [120, 320]);
    expect(v.xs.first.$2.length, 2);
  });

  testWidgets('도면 설정 "치수 모양"을 누르면 앱식 → 캐드식 → 좌표로 바뀌고 기억한다', (t) async {
    SharedPreferences.setMockInitialValues({
      'layout_board_onboarding_shown_v1': true,
      'layout_board_draft_v1': jsonEncode({
        'projectId': null,
        'projectName': 'T',
        'panelWidth': 600,
        'panelHeight': 800,
        'items': [
          {'type': 'item', 'id': 'a', 'name': 'A', 'x': 40, 'y': 40},
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
    await t.tap(find.byKey(const ValueKey('board_settings_button')));
    await t.pumpAndSettle();
    final row = find.byKey(const ValueKey('dim_style'));
    await t.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('치수 모양: 앱식'), findsOneWidget);
    await t.tap(row);
    await t.pumpAndSettle();
    expect(find.text('치수 모양: 캐드식'), findsOneWidget);
    await t.tap(row);
    await t.pumpAndSettle();
    expect(find.text('치수 모양: 좌표'), findsOneWidget);
    final p = await SharedPreferences.getInstance();
    expect(p.getString('layout_dim_style_v1'), 'ordinate');
  });

  testWidgets('캐드식: 판 크기 글자(W·H) 대신 여백 치수, 저장 그림은 여백만큼 크다', (t) async {
    Future<Size> capture(String style) async {
      SharedPreferences.setMockInitialValues({
        'layout_board_onboarding_shown_v1': true,
        'layout_dim_style_v1': style,
        'layout_board_draft_v1': jsonEncode({
          'projectId': null,
          'projectName': 'T',
          'panelWidth': 600,
          'panelHeight': 800,
          'items': [
            {'type': 'item', 'id': 'a', 'name': 'A', 'x': 40, 'y': 40},
            {'type': 'item', 'id': 'b', 'name': 'B', 'x': 240, 'y': 300},
          ],
          'dimensions': [
            dim('d1', box('a', 40, 40), box('b', 240, 300), axis: 'h').toJson(),
          ],
        }),
      });
      t.view.physicalSize = const Size(780, 1688);
      t.view.devicePixelRatio = 2;
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(const MaterialApp(home: LayoutBoardPage()));
      await t.pump(const Duration(milliseconds: 100));
      await t.pumpAndSettle();
      await t.tap(find.text('이어하기'));
      await t.pumpAndSettle();
      if (style == 'cad') {
        expect(find.byKey(const ValueKey('panel_w_label')), findsNothing);
      } else {
        expect(find.byKey(const ValueKey('panel_w_label')), findsOneWidget);
      }
      final state = t.state(find.byType(LayoutBoardPage)) as dynamic;
      final bytes = await t.runAsync(() => state.debugCapturePng() as Future);
      expect(bytes, isNotNull);
      final codec = await t.runAsync(() => instantiateImageCodec(bytes));
      final frame = await t.runAsync(() => codec!.getNextFrame());
      return Size(frame!.image.width.toDouble(), frame.image.height.toDouble());
    }

    addTearDown(t.view.reset);
    final app = await capture('app');
    final cad = await capture('cad');
    // 앱식은 판 비율 3:4 그대로, 캐드식은 위·왼쪽 여백이 붙어 비율이 달라진다(위 줄이 더 많아 세로가 더 늘어남).
    expect(app.width / app.height, closeTo(0.75, 0.002));
    expect((cad.width / cad.height - 0.75).abs(), greaterThan(0.004));
  });

  testWidgets('판 테두리가 부품을 밀지 않는다: (0,0) 부품은 판 왼쪽 위 그대로, 판 높이만 한 부품은 판 안에 꼭 맞음', (t) async {
    SharedPreferences.setMockInitialValues({
      'layout_board_onboarding_shown_v1': true,
      'layout_board_draft_v1': jsonEncode({
        'projectId': null,
        'projectName': 'T',
        'panelWidth': 600,
        'panelHeight': 800,
        'items': [
          {'type': 'item', 'id': 'duct', 'name': 'D', 'x': 0, 'y': 0, 'w': 60, 'h': 800},
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
    final state = t.state(find.byType(LayoutBoardPage)) as dynamic;
    final board = state.debugBoardRect() as Rect;
    final item = t.getRect(find.byKey(const ValueKey('duct')));
    expect(item.topLeft.dx, closeTo(board.left, 0.01));
    expect(item.topLeft.dy, closeTo(board.top, 0.01));
    expect(item.bottom, closeTo(board.bottom, 0.01));
  });
}
