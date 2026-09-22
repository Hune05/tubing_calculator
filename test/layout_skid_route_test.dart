// 스키드 전선관 경로: 오프셋 두 줄 셈, 꺾이는 점(스키드 좌표), 탭 투영, 평면 부품 그림자, 저장.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/skid_route_editor_page.dart';
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

  testWidgets('경로 입력: 아래는 전선관 계산기 입력 탭, 넣은 줄이 위 작은 도면에 바로 그려지고 저장된다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    ConduitRoute? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await SkidRouteEditorPage.open(
                    context,
                    route: ConduitRoute(id: 'r', name: '경로 1'),
                    plates: {
                      'main': {
                        'panelWidth': 2400.0,
                        'panelHeight': 1200.0,
                        'items': [jb().toJson()],
                      },
                    },
                  );
                },
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    SkidMiniViewPainter mini() =>
        tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (w) => w is CustomPaint && w.painter is SkidMiniViewPainter,
                  ),
                )
                .painter!
            as SkidMiniViewPainter;
    expect(mini().route, hasLength(1)); // 시작점만

    // 계산기 입력 탭의 길이 칸에 700을 넣고 추가
    await tester.enterText(find.byType(TextField).last, '700');
    await tester.tap(find.text('90° 벤딩'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('0° 직관')); // 화면을 다시 그리게(길이 칸은 앱 숫자판이라)
    await tester.pumpAndSettle();
    await tester.tap(find.text('추가').last);
    await tester.pumpAndSettle();
    expect(mini().route, hasLength(2)); // 저장 전에도 바로 그려진다

    // 작은 도면을 누르면 크게 보기, 탭을 바꿔도 그려진다
    // 화면이 막 열린 직후 누름은 무시하므로 잠깐 기다린다.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 800)),
    );
    await tester.tap(find.byKey(const ValueKey('route_mini_board')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('route_big_board')), findsOneWidget);
    await tester.tap(find.text('정면').last);
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    Navigator.of(
      tester.element(find.byKey(const ValueKey('route_big_board'))),
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('route_save')));
    await tester.pumpAndSettle();
    expect(result!.bends.single['length'], 700.0);
  });

  testWidgets('도면에서 경로 선을 누르면 그 경로 입력 화면이 열린다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'layout_board_onboarding_shown_v1': true,
      'layout_board_draft_v1': jsonEncode({
        'kind': 'skid',
        'panelWidth': 2400,
        'panelHeight': 1200,
        'items': [],
        'dimensions': [],
        'routes': [
          ConduitRoute(
            id: 'r1',
            name: 'JB→PT',
            x: 200,
            y: 600,
            bends: [
              {'length': 1600, 'angle': 0, 'rotation': 0},
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

    // 도면(2400×1200)이 화면에 그려진 자리에서, 경로(가로 200→1800, 세로 600) 가운데를 누른다.
    final Rect board = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is SkidOverlayPainter,
      ),
    );
    final Offset at = Offset(
      board.left + board.width * 1000 / 2400,
      board.top + board.height * 600 / 1200,
    );
    await tester.tapAt(at);
    await tester.pumpAndSettle();
    expect(find.byType(SkidRouteEditorPage), findsOneWidget);
    expect(find.textContaining('JB→PT'), findsWidgets);
  });

  testWidgets('도면에서 경로 선을 끌면 경로가 옮겨지고, 되돌리기로 돌아온다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'layout_board_onboarding_shown_v1': true,
      'layout_board_draft_v1': jsonEncode({
        'kind': 'skid',
        'panelWidth': 2400,
        'panelHeight': 1200,
        'items': [],
        'dimensions': [],
        'routes': [
          ConduitRoute(
            id: 'r1',
            name: 'A',
            x: 200,
            y: 600,
            bends: [
              {'length': 1600, 'angle': 0, 'rotation': 0},
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

    final Rect board = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is SkidOverlayPainter,
      ),
    );
    final double k = board.height / 1200; // 화면 픽셀 / mm
    final Offset at = Offset(
      board.left + board.width * 1000 / 2400,
      board.top + board.height * 600 / 1200,
    );
    // 끄는 동안 가상선(SmartGuidePainter)이 나온다.
    final g = await tester.startGesture(at);
    for (int i = 0; i < 5; i++) {
      await g.moveBy(Offset(0, 60 * k));
      await tester.pump();
    }
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is SmartGuidePainter,
      ),
      findsWidgets,
    );
    await g.moveBy(Offset(0, 150 * k));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is SmartGuidePainter,
      ),
      findsNothing,
    );

    Future<Map> saved() async {
      await tester.pump(const Duration(seconds: 21)); // 20초 임시 저장
      final prefs = await SharedPreferences.getInstance();
      return jsonDecode(prefs.getString('layout_board_draft_v1')!) as Map;
    }

    final moved = (await saved())['routes'][0] as Map;
    expect((moved['y'] as num).toDouble(), closeTo(1050, 20)); // 600 + 300 + 150
    expect((moved['x'] as num).toDouble(), closeTo(200, 20));

    await tester.tap(find.byTooltip('되돌리기'));
    await tester.pumpAndSettle();
    final back = (await saved())['routes'][0] as Map;
    expect((back['y'] as num).toDouble(), 600);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
