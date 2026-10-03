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
    expect(s.boxes.length, 2, reason: '정션박스 몸통 + 뚜껑');
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
  test('화면 맞춤: 어느 시점이든 둘러싸는 상자가 화면 안에 들어오고 가운데에 놓인다', () {
    final s = buildSkidIsoScene(
      [_beam(), _beam(id: 'b2', y: 0, len: 30000, elev: 8000)],
      const [],
      length: 30000,
      width: 12000,
    );
    const size = Size(400, 600);
    for (final v in [IsoView.standard, IsoView.front, IsoView.top, IsoView.right]) {
      final fit = fitIso(s, v, size);
      expect(fit.scale, greaterThan(0));
      final b = s.bounds;
      final c = (b.min + b.max) * 0.5;
      double minX = 1e18, maxX = -1e18, minY = 1e18, maxY = -1e18;
      for (final x in [b.min.x, b.max.x]) {
        for (final y in [b.min.y, b.max.y]) {
          for (final z in [b.min.z, b.max.z]) {
            final q = v.project(vm.Vector3(x, y, z), c);
            final sx = size.width / 2 + fit.shift.dx + q.sx * fit.scale;
            final sy = size.height / 2 + fit.shift.dy + q.sy * fit.scale;
            minX = math.min(minX, sx);
            maxX = math.max(maxX, sx);
            minY = math.min(minY, sy);
            maxY = math.max(maxY, sy);
          }
        }
      }
      expect(minX, greaterThanOrEqualTo(0));
      expect(maxX, lessThanOrEqualTo(size.width));
      expect(minY, greaterThanOrEqualTo(0));
      expect(maxY, lessThanOrEqualTo(size.height));
      expect((minX + maxX) / 2, closeTo(size.width / 2, size.width * 0.08));
      expect((minY + maxY) / 2, closeTo(size.height / 2, size.height * 0.08));
    }
  });

  testWidgets('"이름" 칩으로 부품 이름 표시를 켜고 끈다', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: SkidIsoPage(plan: [_beam()], routes: const [], length: 2400, width: 1200),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('iso_labels')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(find.byKey(const Key('iso_labels'))).selected, true);
    await tester.tap(find.byKey(const Key('iso_labels')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(find.byKey(const Key('iso_labels'))).selected, false);
  });
  PlacedItem cd(String shape, {double w = 243, double h = 110, int? rot, bool flip = false, double elev = 60, double depth = 100}) =>
      PlacedItem(
        id: 'cd',
        name: '곤질레다',
        position: const Offset(100, 200),
        width: w,
        height: h,
        shape: shape,
        depth: depth,
        elevation: elev,
        rotation: rot,
        flipped: flip,
      );

  test('곤질레다 LL: 몸통 + 뚜껑, 왼쪽 끝 허브와 평면 아래쪽(옆 B) 허브', () {
    final s = buildSkidIsoScene([cd(SkidShape.cdLL, rot: 0)], const [], length: 1000, width: 800);
    expect(s.boxes.length, 2, reason: '몸통 + 뚜껑');
    expect(s.pipes.length, 2, reason: '끝 허브 + 옆 허브');
    final end = s.pipes.firstWhere((p) => (p.a.x - p.b.x).abs() > 1);
    expect(end.a.x, closeTo(100, 1e-6), reason: '왼쪽 끝 허브는 평면 왼쪽 끝에서 시작');
    final side = s.pipes.firstWhere((p) => (p.a.y - p.b.y).abs() > 1);
    expect(side.b.y, closeTo(310, 1e-6), reason: '옆 허브 바깥 끝 = 평면 아래쪽 끝(y 200 + 110)');
    expect(s.pipes.every((p) => !p.round), true, reason: '허브는 잘린 끝');
    // 부품 전체가 놓은 칸 안에 들어간다.
    final b = s.bounds;
    expect(b.max.y, lessThanOrEqualTo(800));
  });

  test('곤질레다 LL을 180° 돌리면 허브가 오른쪽 끝, 옆 허브는 위쪽(평면 y 작은 쪽)으로 간다', () {
    final s = buildSkidIsoScene([cd(SkidShape.cdLL, rot: 180)], const [], length: 1000, width: 800);
    final end = s.pipes.firstWhere((p) => (p.a.x - p.b.x).abs() > 1);
    expect(end.a.x, closeTo(343, 1e-6), reason: '끝 허브가 오른쪽 끝(100 + 243)에서 시작');
    final side = s.pipes.firstWhere((p) => (p.a.y - p.b.y).abs() > 1);
    expect(side.b.y, closeTo(200, 1e-6));
  });

  test('곤질레다 LB: 뒤 허브는 아래로 바닥까지, LX는 허브 넷', () {
    final lb = buildSkidIsoScene([cd(SkidShape.cdLB, rot: 0)], const [], length: 1000, width: 800);
    final back = lb.pipes.firstWhere((p) => (p.a.z - p.b.z).abs() > 1);
    expect(back.a.z, closeTo(10, 1e-6), reason: '바닥에서 높이 60 − 높이 100 ÷ 2');
    final lx = buildSkidIsoScene([cd(SkidShape.cdLX, w: 243, h: 160, rot: 0)], const [], length: 1000, width: 800);
    expect(lx.pipes.length, 4, reason: '양 끝 + 양 옆');
  });

  test('뒤집으면(flipped) 끝 허브가 오른쪽으로, 세워 돌리면(90°) 허브가 위쪽 끝(평면 y 작은 쪽)이 아니라 아래 끝으로 간다', () {
    final fl = buildSkidIsoScene([cd(SkidShape.cdLC, rot: 0, flip: true)], const [], length: 1000, width: 800);
    final end = fl.pipes.firstWhere((p) => (p.a.x - p.b.x).abs() > 1);
    expect(end.a.x, closeTo(343, 1e-6), reason: '뒤집으면 왼쪽 끝 허브가 오른쪽 끝에서 시작');
    // 90도 돌린 부품: 칸이 세로로 길다(가로 110, 세로 243). 90도(시계)면 왼쪽 끝 허브는 위쪽 끝.
    final r1 = buildSkidIsoScene([cd(SkidShape.cdLB, w: 110, h: 243, rot: 90)], const [], length: 1000, width: 800);
    final hub = r1.pipes.firstWhere((p) => (p.a.y - p.b.y).abs() > 1 && (p.a.x - p.b.x).abs() < 1e-6 && (p.a.z - p.b.z).abs() < 1e-6);
    expect(hub.a.y, closeTo(200, 1e-6), reason: '세로로 놓으면 길이 방향이 평면 세로, 왼쪽 끝 허브는 위쪽 끝');
  });

  test('커플링·유니온은 길이 방향 관 모양, 지름은 칸 짧은 쪽이 아니라 단면 방향 크기', () {
    final c = PlacedItem(
      id: 'c',
      name: '커플링 54',
      position: const Offset(0, 0),
      width: 64,
      height: 68,
      shape: SkidShape.coupling,
      depth: 68,
      elevation: 100,
      rotation: 0,
    );
    final s = buildSkidIsoScene([c], const [], length: 500, width: 500);
    expect(s.pipes.length, 3, reason: '몸통 + 양 끝 띠');
    expect(s.pipes.first.od, closeTo(68 * 0.94, 1e-6));
    final u = PlacedItem(
      id: 'u',
      name: '유니온 커플링 54',
      position: const Offset(0, 0),
      width: 63,
      height: 82,
      shape: SkidShape.union,
      depth: 82,
      elevation: 100,
      rotation: 0,
    );
    final su = buildSkidIsoScene([u], const [], length: 500, width: 500);
    expect(su.pipes.length, 2);
    expect(su.pipes.last.od, closeTo(82, 1e-6));
  });

  test('높이를 안 넣은 부품 수를 센다, 정션박스는 뚜껑이 붙고 경로 꺾임은 둥근 이음', () {
    final a = _beam(id: 'a');
    final b = PlacedItem(
      id: 'b',
      name: 'JB',
      position: const Offset(0, 0),
      width: 200,
      height: 150,
      shape: SkidShape.jb,
    );
    final r = ConduitRoute(
      id: 'r',
      name: 'r',
      x: 0,
      y: 0,
      z: 100,
      startDir: 90,
      bends: [
        {'length': 500.0, 'angle': 90.0, 'rotation': 0.0},
        {'length': 400.0, 'angle': 0.0, 'rotation': 0.0},
      ],
    );
    final s = buildSkidIsoScene([a, b], [r], length: 1000, width: 500);
    expect(s.noHeightCount, 1);
    expect(s.boxes.where((x) => x.partId == 'b').length, 2, reason: '몸통 + 뚜껑');
    final dots = s.pipes.where((p) => (p.b - p.a).length < 1e-9).length;
    expect(dots, 1, reason: '꺾이는 곳 하나 = 둥근 이음 하나');
  });
}
