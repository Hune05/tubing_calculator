// 10-16 배치도 치수 모양: 앱식 · 캐드식(부품 밖 치수선·보조선·화살표) · 좌표(위·왼쪽 벽에서 부품 센터까지).
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
  group('캐드식 치수선 자리', () {
    test('가로 치수는 두 부품 위(부품 밖)에, 보조선은 원래 센터에서', () {
      final a = box('a', 100, 200), b = box('b', 300, 200); // 센터 (120,220) (320,220)
      final l = layoutCadDimensionLanes([dim('ab', a, b)], gap: 20, panelWidth: 600, panelHeight: 600, obstacles: dimObstacles([a, b]));
      expect(l['ab']!.p1.dy, 180); // 위 200 - 20
      expect(l['ab']!.p1.dy, lessThan(a.boundingBox.top));
      expect(l['ab']!.origin1, const Offset(120, 220));
      expect(l['ab']!.distance, 200);
    });
    test('세로 치수는 부품 왼쪽 밖에', () {
      final a = box('a', 200, 100), b = box('b', 200, 300);
      final l = layoutCadDimensionLanes([dim('ab', a, b)], gap: 20, panelWidth: 600, panelHeight: 600, obstacles: dimObstacles([a, b]));
      expect(l['ab']!.p1.dx, 180);
    });
    test('구간이 겹치면 짧은 것이 안쪽, 긴 것이 한 칸 더 바깥', () {
      final a = box('a', 100, 200), b = box('b', 300, 200), c = box('c', 500, 200);
      final l = layoutCadDimensionLanes(
        [dim('ac', a, c), dim('ab', a, b)],
        gap: 20,
        panelWidth: 800,
        panelHeight: 600,
        obstacles: dimObstacles([a, b, c]),
      );
      // 짧은 것은 위, 긴 것은 겹치지 않게 아래 바깥(부품은 가로지르지 않음)
      expect(l['ab']!.p1.dy, 180);
      expect(l['ac']!.p1.dy, 260);
    });
    test('사이에 다른 부품이 있으면 그 부품을 가로지르지 않는 자리로', () {
      final a = box('a', 100, 200), b = box('b', 400, 200);
      final m = PlacedItem(id: 'm', name: 'm', position: const Offset(250, 120), width: 40, height: 120);
      final l = layoutCadDimensionLanes(
        [dim('ab', a, b)],
        gap: 20,
        panelWidth: 600,
        panelHeight: 600,
        obstacles: dimObstacles([a, b, m]),
      );
      final y = l['ab']!.p1.dy;
      expect(y < 120 - 5 || y > 240 + 15, isTrue, reason: '$y');
    });
    test('사용자 배치(덕트 셋 가로·둘 세로): 다 막히면 덕트 이름 자리(가운데)를 피한다', () {
      PlacedItem d(String id, double x, double y, double w, double hh) =>
          PlacedItem(id: id, name: id, position: Offset(x, y), width: w, height: hh);
      final t = d('t', 63, 7, 470, 60), m = d('m', 63, 247, 470, 60), b = d('b', 63, 477, 470, 60);
      final l = d('l', 3, 7, 50, 785), r = d('r', 537, 7, 50, 785);
      final lanes = layoutCadDimensionLanes(
        [dim('tm', t, m), dim('mb', m, b), dim('lr', l, r)],
        gap: 30,
        panelWidth: 600,
        panelHeight: 800,
        obstacles: dimObstacles([t, m, b, l, r]),
      );
      for (final k in ['tm', 'mb']) {
        final x = lanes[k]!.p1.dx;
        expect((x - 298).abs() >= 60, isTrue, reason: '$k x=$x');
        expect(x > 63 && x < 533, isTrue, reason: '$k x=$x'); // 세로 덕트 위는 아님
      }
    });
    test('위에 자리가 없으면(도면 위 끝) 아래로', () {
      final a = box('a', 100, 5), b = box('b', 300, 5);
      final l = layoutCadDimensionLanes([dim('ab', a, b)], gap: 20, panelWidth: 600, panelHeight: 600, obstacles: dimObstacles([a, b]));
      expect(l['ab']!.p1.dy, 65); // 아래 45 + 20
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
}
