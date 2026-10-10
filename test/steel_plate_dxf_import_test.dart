// 철판 DXF 불러오기(10-10): 이 앱이 만든 DXF를 다시 읽으면 같은 모양(꼭짓점·코너 R·C·홀·장공·원형·링)이 나온다.
// LWPOLYLINE(볼록 원호)·다른 층(센터선) 걸러 내기·못 읽는 안쪽 모양 세기.
import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_calc.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_dxf.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_dxf_import.dart';

void main() {
  test('평판 200×100 · 네 코너 R10 · 홀 · 기운 장공 → 그대로 다시 읽는다', () {
    final p = platePlan(
      const PlateInput(
        shape: PlateShape.flat,
        t: 3,
        length: 200,
        width: 100,
        corners: [
          PlateCorner(PlateCornerKind.round, 10),
          PlateCorner(PlateCornerKind.round, 10),
          PlateCorner(PlateCornerKind.round, 10),
          PlateCorner(PlateCornerKind.round, 10),
        ],
        holes: [
          PlateHoleSpec(u: 50, v: 50, dia: 13.5),
          PlateHoleSpec(u: 140, v: 50, dia: 11, slot: 30, angle: 45),
        ],
      ),
    );
    final r = importPlateDxf(plateDxf(p, thickness: 3));
    expect(r.shape, PlateShape.free);
    expect(r.points, hasLength(4)); // 센터선(DIM 층)은 읽지 않는다
    expect(
      r.corners.every((c) => c.kind == PlateCornerKind.round && c.a == 10),
      isTrue,
    );
    final xs = r.points.map((q) => q.dx).toSet(),
        ys = r.points.map((q) => q.dy).toSet();
    expect(xs, {0, 200});
    expect(ys, {0, 100});
    expect(r.holes, hasLength(2));
    final round = r.holes.firstWhere((h) => h.slot == 0);
    expect(round.u, closeTo(50, 0.01));
    expect(round.v, closeTo(50, 0.01));
    expect(round.dia, closeTo(13.5, 0.01));
    final slot = r.holes.firstWhere((h) => h.slot > 0);
    expect(slot.u, closeTo(140, 0.01));
    expect(slot.dia, closeTo(11, 0.01));
    expect(slot.slot, closeTo(30, 0.01));
    expect(slot.angle, closeTo(45, 0.01));
    expect(r.skipped, 0);
    // 다시 계산해도 넓이가 같다
    final again = platePlan(
      PlateInput(
        shape: PlateShape.free,
        t: 3,
        points: r.points,
        pointCorners: r.corners,
        holes: r.holes,
      ),
    );
    expect(again.areaMm2, closeTo(p.areaMm2, 0.5));
  });

  test('코너 C 모따기·좌표 모양(凸)', () {
    final p = platePlan(
      const PlateInput(
        shape: PlateShape.free,
        t: 3,
        points: [
          Offset(0, 0),
          Offset(210, 0),
          Offset(210, 75),
          Offset(145, 75),
          Offset(145, 145),
          Offset(65, 145),
          Offset(65, 75),
          Offset(0, 75),
        ],
        pointCorners: [
          PlateCorner(PlateCornerKind.chamfer, 5),
          PlateCorner(PlateCornerKind.chamfer, 5),
          PlateCorner.square,
          PlateCorner.square,
          PlateCorner(PlateCornerKind.round, 8),
          PlateCorner(PlateCornerKind.round, 8),
          PlateCorner.square,
          PlateCorner.square,
        ],
      ),
    );
    final r = importPlateDxf(plateDxf(p, thickness: 3));
    expect(r.points, hasLength(8));
    final tags = {for (var k = 0; k < 8; k++) r.points[k]: r.corners[k].token};
    expect(tags[const Offset(0, 0)], 'c5');
    expect(tags[const Offset(210, 0)], 'c5');
    expect(tags[const Offset(145, 145)], 'r8');
    expect(tags[const Offset(65, 145)], 'r8');
    expect(tags[const Offset(145, 75)], '');
  });

  test('원형·링: 바깥 원은 외경, 같은 가운데 안쪽 원은 링 내경, 나머지 원은 홀', () {
    final ring = platePlan(
      const PlateInput(
        shape: PlateShape.ring,
        t: 3,
        dia: 200,
        innerDia: 100,
        holes: [PlateHoleSpec(u: 100, v: 175, dia: 13.5)],
      ),
    );
    expect(ring.cutouts, hasLength(1));
    final r = importPlateDxf(plateDxf(ring, thickness: 3));
    expect(r.shape, PlateShape.ring);
    expect(r.dia, closeTo(200, 0.01));
    expect(r.innerDia, closeTo(100, 0.01));
    expect(r.holes, hasLength(1));
    expect(r.holes.single.u, closeTo(100, 0.01));
    expect(r.holes.single.v, closeTo(175, 0.01));
    final circle = platePlan(
      const PlateInput(shape: PlateShape.circle, t: 3, dia: 150),
    );
    final c = importPlateDxf(plateDxf(circle, thickness: 3));
    expect(c.shape, PlateShape.circle);
    expect(c.dia, closeTo(150, 0.01));
  });

  test('LWPOLYLINE(볼록 원호), 층 없는 도면, 못 읽는 안쪽 모양은 센다', () {
    // 100×60 판, 오른쪽 위 코너 R10을 볼록으로, 안쪽 사각 따냄 하나, 원 하나
    String lw(List<(double, double, double)> v) => [
      '0',
      'LWPOLYLINE',
      '8',
      '0',
      '90',
      '${v.length}',
      '70',
      '1',
      for (final (x, y, b) in v) ...[
        '10',
        '$x',
        '20',
        '$y',
        if (b != 0) ...['42', '$b'],
      ],
    ].join('\n');
    const bulge90 = 0.41421356237; // tan(90°/4)
    final dxf = [
      '0',
      'SECTION',
      '2',
      'ENTITIES',
      lw([(0, 0, 0), (100, 0, 0), (100, 50, bulge90), (90, 60, 0), (0, 60, 0)]),
      lw([(20, 20, 0), (40, 20, 0), (40, 40, 0), (20, 40, 0)]),
      '0',
      'CIRCLE',
      '8',
      '0',
      '10',
      '70',
      '20',
      '30',
      '40',
      '5',
      '0',
      'ENDSEC',
      '0',
      'EOF',
    ].join('\n');
    final r = importPlateDxf(dxf);
    expect(r.points, hasLength(4));
    final k = r.points.indexOf(const Offset(100, 60));
    expect(k, greaterThanOrEqualTo(0));
    expect(r.corners[k].token, 'r10');
    expect(r.holes, hasLength(1));
    expect(r.holes.single.dia, closeTo(10, 0.01));
    expect(r.skipped, 1);
    expect(r.notes.join(), contains('읽지 못했습니다'));
  });

  test('외곽이 끊겨 있으면 알려 준다', () {
    expect(
      () => importPlateDxf(
        '0\nSECTION\n2\nENTITIES\n0\nLINE\n8\n0\n10\n0\n20\n0\n11\n10\n21\n0\n0\nENDSEC\n0\nEOF',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
