// 스키드 입체 보기(보기 전용): 평면 부품과 경로가 입체 조각으로 바뀌는지, 시점 계산, 화면 눌러 고르기.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/instrument_shape_painter.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/layout_board_models.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/skid_iso.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/skid_presets.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/skid_route.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/skid_iso_page.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

PlacedItem _beam({
  String id = 'b1',
  String name = 'H형강 150x150x7x10',
  double x = 0,
  double y = 525,
  double len = 2400,
  double w = 150,
  double elev = 75,
  String shape = SkidShape.beam,
}) => PlacedItem(
  id: id,
  name: name,
  position: Offset(x, y),
  width: len,
  height: w,
  shape: shape,
  elevation: elev,
);

void main() {
  test('H형강은 단면대로 상자 셋: 아래 플랜지 10, 위 플랜지 10, 웹 7', () {
    final s = buildSkidIsoScene([_beam()], const [], length: 2400, width: 1200);
    expect(s.boxes.length, 3);
    expect(s.partCount, 1);
    final bottom = s.boxes[0], top = s.boxes[1], web = s.boxes[2];
    expect((bottom.z0, bottom.z1), (0, 10));
    expect((top.z0, top.z1), (140, 150));
    expect((web.z0, web.z1), (10, 140));
    expect(web.y1 - web.y0, 7);
    expect((web.y0 + web.y1) / 2, 600, reason: '웹은 단면 가운데');
    expect(bottom.x1 - bottom.x0, 2400);
  });

  test('길이가 세로로 놓인(돌린) 형강은 단면 방향이 바뀐다', () {
    final it = PlacedItem(
      id: 'b2',
      name: 'H형강 150x150x7x10',
      position: const Offset(100, 0),
      width: 150,
      height: 2400,
      shape: SkidShape.beam,
      elevation: 75,
    );
    final s = buildSkidIsoScene([it], const [], length: 2400, width: 1200);
    final web = s.boxes[2];
    expect(web.x1 - web.x0, 7);
    expect(web.y1 - web.y0, 2400);
  });

  test('찬넬은 웹 + 플랜지 둘, 앵글은 다리 둘, 각파이프는 한 상자', () {
    final ch = buildSkidIsoScene(
      [_beam(name: '찬넬 75x40x5x7', w: 40, elev: 37.5, shape: SkidShape.channel)],
      const [],
      length: 2400,
      width: 1200,
    );
    expect(ch.boxes.length, 3);
    final an = buildSkidIsoScene(
      [_beam(name: '앵글 50x50x5', w: 50, elev: 25, shape: SkidShape.angle)],
      const [],
      length: 2400,
      width: 1200,
    );
    expect(an.boxes.length, 2);
    final sq = buildSkidIsoScene(
      [_beam(name: '각파이프 50x50x3', w: 50, elev: 25, shape: SkidShape.square)],
      const [],
      length: 2400,
      width: 1200,
    );
    expect(sq.boxes.length, 1);
  });

  test('전선관 부품은 관, 정션박스는 상자, 메모는 건너뛴다', () {
    final conduit = PlacedItem(
      id: 'c1',
      name: '후강 22',
      position: const Offset(0, 100),
      width: 1500,
      height: 26.5,
      shape: SkidShape.conduit,
      elevation: 300,
    );
    final jb = PlacedItem(
      id: 'j1',
      name: 'JB',
      position: const Offset(500, 500),
      width: 200,
      height: 150,
      shape: SkidShape.jb,
      elevation: 400,
    );
    final note = PlacedItem(
      id: 'n1',
      name: '메모',
      position: const Offset(0, 0),
      width: 160,
      height: 40,
      shape: InstrumentShape.note,
    );
    final s = buildSkidIsoScene(
      [conduit, jb, note],
      const [],
      length: 2400,
      width: 1200,
    );
    expect(s.pipes.length, 1);
    expect(s.pipes.first.od, 26.5);
    expect(s.pipes.first.a.z, 300);
    expect(s.boxes.length, 1);
    expect(s.partCount, 2);
  });

  test('전선관 경로는 꺾이는 점 사이마다 관 한 토막', () {
    final r = ConduitRoute(
      id: 'r1',
      name: '경로',
      size: 22,
      x: 100,
      y: 100,
      z: 200,
      startDir: 90,
      bends: [
        {'length': 1000.0, 'angle': 90.0, 'rotation': 0.0},
        {'length': 500.0, 'angle': 0.0, 'rotation': 0.0},
      ],
    );
    final s = buildSkidIsoScene(const [], [r], length: 2400, width: 1200);
    expect(s.routeCount, 1);
    expect(s.pipes.length, greaterThanOrEqualTo(2));
    expect((s.pipes.first.b - s.pipes.first.a).length, closeTo(1000, 1e-6));
    expect(s.pipes.first.od, closeTo(26.5, 1e-9));
  });

  test('아주 큰 구조물(30 m × 12 m, 높이 8 m)도 같은 식으로 둘러싸는 상자가 나온다', () {
    final col = _beam(
      id: 'col',
      name: 'H형강 400x200x8x13',
      x: 5000,
      y: 2000,
      len: 200,
      w: 8000,
      elev: 400,
    );
    final long = _beam(
      id: 'g',
      name: 'H형강 600x200x11x17',
      len: 30000,
      w: 200,
      y: 6000,
      elev: 8000,
    );
    final s = buildSkidIsoScene(
      [col, long],
      const [],
      length: 30000,
      width: 12000,
    );
    final b = s.bounds;
    expect(b.max.x, greaterThanOrEqualTo(30000));
    expect(b.max.z, greaterThan(8000));
    expect(s.boxes.length, 6);
  });

  test('시점: 정면(yaw 0)에서 y가 큰 쪽이 가깝고 화면 아래로 온다, 위에 있는 것은 위로 간다', () {
    const v = IsoView(0, 0.5);
    final c = vm.Vector3.zero();
    final near = v.project(vm.Vector3(0, 100, 0), c);
    final far = v.project(vm.Vector3(0, -100, 0), c);
    expect(near.near, greaterThan(far.near));
    expect(near.sy, greaterThan(far.sy));
    final up = v.project(vm.Vector3(0, 0, 100), c);
    expect(up.sy, lessThan(0));
    // yaw 90도(오른쪽에서 봄): x가 큰 쪽이 가깝다.
    const r = IsoView(math.pi / 2, 0);
    expect(
      r.project(vm.Vector3(100, 0, 0), c).near,
      greaterThan(r.project(vm.Vector3(-100, 0, 0), c).near),
    );
  });

  test('바닥 격자 간격은 1·2·5 × 10의 거듭제곱', () {
    expect(niceGridStep(2400), 200);
    expect(niceGridStep(30000), 2000);
    expect(niceGridStep(600), 50);
    expect(niceGridStep(0), 100);
  });

  testWidgets('입체 보기 화면: 요약, 시점 바꾸기, 눌러서 부품 고르기', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: SkidIsoPage(
          plan: [_beam()],
          routes: const [],
          length: 2400,
          width: 1200,
        ),
      ),
    );
    await tester.pumpAndSettle();
    String info() => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('iso_info')),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data ?? '')
        .join('\n');
    expect(info(), contains('부품 1개'));
    expect(info(), contains('전체 2400 × 1200'));
    // 눌러서 고르기: 화면 가운데는 형강 위다.
    await tester.tap(find.byKey(const Key('iso_canvas')));
    await tester.pumpAndSettle();
    expect(info(), contains('H형강 150x150x7x10'));
    // 빈 곳을 누르면 선택이 풀린다(캔버스 왼쪽 위 구석).
    final tl = tester.getTopLeft(find.byKey(const Key('iso_canvas')));
    await tester.tapAt(tl + const Offset(6, 6));
    await tester.pumpAndSettle();
    expect(info(), contains('부품 1개'));
    // 시점 칩
    await tester.tap(find.byKey(const Key('iso_front')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ChoiceChip>(find.byKey(const Key('iso_front'))).selected,
      true,
    );
  });

  testWidgets('부품이 없으면 안내 글만 나온다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SkidIsoPage(plan: [], routes: [], length: 2400, width: 1200),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('놓은 부품이 없습니다'), findsOneWidget);
  });
}
