// 스키드 전선관 경로: 오프셋 두 줄 셈, 꺾이는 점(스키드 좌표), 탭 투영, 평면 부품 그림자, 저장.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

PlacedItem jb({double? elev = 800}) => PlacedItem(
  id: 'jb',
  name: '정션박스 200×200',
  position: const Offset(0, 100),
  width: 200,
  height: 200,
  elevation: elev,
);

void main() {
  test('오프셋: 두 번째 줄 = 비켜 갈 거리 ÷ sin(각도), 방향은 반대', () {
    final b = offsetBends(before: 500, offset: 100, angle: 30, dir: 0);
    expect(b[0], {'length': 500.0, 'angle': 30.0, 'rotation': 0.0});
    expect(b[1]['length'], 200.0);
    expect(b[1]['rotation'], 180.0);
  });

  test('경로 꺾이는 점: JB 가운데·높이에서 시작, 오른쪽 1000 → 위로 90° → 500', () {
    final r = ConduitRoute(
      id: 'r',
      name: 'A',
      startItemId: 'jb',
      startDir: 90,
      bends: [
        {'length': 1000, 'angle': 90, 'rotation': 0},
        {'length': 500, 'angle': 0, 'rotation': 0},
      ],
    );
    final p = r.points([jb()]);
    expect(p[0], vm.Vector3(100, 200, 800));
    expect(p[1].x, closeTo(1100, 1e-6));
    expect(p[1].z, closeTo(800, 1e-6));
    expect(p[2].x, closeTo(1100, 1e-6));
    expect(p[2].z, closeTo(1300, 1e-6));
    expect(r.warnings(), isEmpty);
  });

  test('오프셋으로 위로 100 비켜 가면 다시 같은 방향으로, 높이만 100 올라간다', () {
    final r = ConduitRoute(
      id: 'r',
      name: 'A',
      startItemId: 'jb',
      startDir: 90,
      bends: [
        ...offsetBends(before: 500, offset: 100, angle: 30, dir: 0),
        {'length': 300, 'angle': 0, 'rotation': 0},
      ],
    );
    final p = r.points([jb()]);
    final end = p.last;
    final prev = p[p.length - 2];
    expect(end.z, closeTo(900, 0.1));
    expect(end.y, closeTo(200, 1e-6));
    expect(end.z - prev.z, closeTo(0, 1e-6)); // 마지막 직선은 수평
    expect(end.x - prev.x, closeTo(300, 0.1));
  });

  test('앞 방향은 평면 아래쪽(y 증가)', () {
    final r = ConduitRoute(
      id: 'r',
      name: 'A',
      startItemId: 'jb',
      startDir: 360,
      bends: [
        {'length': 400, 'angle': 0, 'rotation': 0},
      ],
    );
    final p = r.points([jb()]);
    expect(p[1].y, closeTo(600, 1e-6));
  });

  test('탭 투영: 정면은 가로=x, 좌측면은 가로=y, 우측면은 폭에서 뺀 y, 세로는 바닥 기준', () {
    final p = vm.Vector3(300, 200, 500);
    Offset proj(String v) =>
        projectToView(p, v, planW: 2400, planH: 1200, viewH: 1500);
    expect(proj('main'), const Offset(300, 200));
    expect(proj(kSkidViewFront), const Offset(300, 1000));
    expect(proj('left'), const Offset(200, 1000));
    expect(proj('right'), const Offset(1000, 1000));
  });

  test('평면 부품 그림자: 높이를 넣은 것만, H형강은 단면 높이로', () {
    final beam = PlacedItem(
      id: 'b',
      name: 'H형강 150x150x7x10',
      position: const Offset(100, 0),
      width: 1000,
      height: 150,
      shape: SkidShape.beam,
      elevation: 75,
    );
    final g = skidGhosts(
      [beam, jb(elev: null)],
      kSkidViewFront,
      planH: 1200,
      viewH: 1500,
    );
    expect(g, hasLength(1));
    expect(g.single.rect, const Rect.fromLTWH(100, 1350, 1000, 150));
    expect(skidGhosts([beam], 'main', planH: 1200, viewH: 1500), isEmpty);
  });

  testWidgets('경로는 임시 저장에 남고, 경로 목록에 보인다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'layout_board_onboarding_shown_v1': true,
      'layout_board_draft_v1': jsonEncode({
        'kind': 'skid',
        'panelWidth': 2400,
        'panelHeight': 1200,
        'items': [jb().toJson()],
        'dimensions': [],
        'routes': [
          ConduitRoute(
            id: 'r1',
            name: 'JB→PT',
            startItemId: 'jb',
            bends: [
              {'length': 1000, 'angle': 0, 'rotation': 0},
            ],
          ).toJson(),
        ],
      }),
    });
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: LayoutBoardPage()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이어하기'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is SkidOverlayPainter,
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('skid_route')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('skid_route')));
    await tester.pumpAndSettle();
    expect(find.textContaining('JB→PT'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('layout_board_draft_v1')!) as Map;
    expect((saved['routes'] as List).single['name'], 'JB→PT');
  });
}
