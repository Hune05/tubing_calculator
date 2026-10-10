// 철판 가공(10-10): 공제값·전개 길이·꺾기선, 업체 공제값으로 k 맞추기, 면 구멍 → 전개도 자리, 구멍 검사,
// 평판·리브·자유 모양 넓이·무게, DXF 내용, 화면(가공 방식·구멍 넣기·DXF·두께별 공제값 저장), 그림·PDF.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_bend_painter.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_form_parts.dart'
    show ElecSummaryBar;
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_pdf.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_3d.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_calc.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_dxf.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_hole_editor.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_page.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_painter.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_ui.dart';
import 'formula_flat.dart';

// 3t, 안쪽 반경 3, k 0.33의 90° 공제값 = 12 − π/2 × 3.99
final double bd3 = 12 - math.pi / 2 * 3.99;

PlatePlan _bent(
  PlateShape s,
  List<double> legs, {
  double? bd,
  double angle = 90,
  List<PlateHoleSpec> holes = const [],
}) => platePlan(
  PlateInput(
    shape: s,
    t: 3,
    width: 100,
    legs: legs,
    angle: angle,
    bd90: bd,
    holes: holes,
  ),
);

void main() {
  group('계산', () {
    test('ㄱ자 3T: 전개 = 바깥 치수 합 − 공제값, 절곡선 자리', () {
      final p = _bent(PlateShape.l, [50, 50]);
      expect(p.bd90Used, closeTo(bd3, 1e-9));
      expect(p.flatLength, closeTo(100 - bd3, 1e-9));
      expect(p.flatWidth, 100);
      final b = p.bends.single;
      expect(b.start, closeTo(50 - 6, 1e-9)); // 바깥 치수 − (r + t)
      expect(b.end - b.start, closeTo(3.99 * math.pi / 2, 1e-9));
      expect(b.turn, 90);
      expect(p.ok, isTrue);
    });

    test('업체 공제값을 넣으면 그 값이 나오게 k를 맞춘다, 못 나오는 값은 알림', () {
      final p = _bent(PlateShape.l, [50, 50], bd: 6);
      expect(p.flatLength, closeTo(94, 1e-9));
      expect(p.bd90Used, closeTo(6, 1e-9));
      expect(p.kUsed, closeTo(((12 - 6) / (math.pi / 2) - 3) / 3, 1e-9));
      final bad = _bent(PlateShape.l, [50, 50], bd: 20);
      expect(bad.problems.join(), contains('나올 수 없는 값'));
    });

    test('ㄷ·Z·모자: 절곡마다 공제, 방향', () {
      final u = _bent(PlateShape.u, [50, 100, 50]);
      expect(u.flatLength, closeTo(200 - 2 * bd3, 1e-9));
      expect(u.bends.map((b) => b.turn), [90, 90]);
      final z = _bent(PlateShape.z, [50, 50, 50]);
      expect(z.flatLength, closeTo(150 - 2 * bd3, 1e-9));
      expect(z.bends.map((b) => b.turn), [90, -90]);
      final hat = _bent(PlateShape.hat, [30, 40, 60]);
      expect(hat.flatLength, closeTo(200 - 4 * bd3, 1e-9));
      expect(hat.bends.map((b) => b.turn), [90, -90, -90, 90]);
      expect(hat.faceNames, ['왼쪽 발', '왼쪽 다리', '윗면', '오른쪽 다리', '오른쪽 발']);
      expect(hat.bendPlan, isNotNull);
    });

    test('면 홀 → 전개도 자리, 꺾기에 걸리면 못 만듦, 가까우면 알림', () {
      // 2면에 바깥면(1면)에서 30: 전개도 = 꺾기 끝선 + 30 − (r + t)
      final p = _bent(
        PlateShape.l,
        [50, 80],
        holes: const [PlateHoleSpec(face: 1, dia: 13.5, u: 30, v: 50)],
      );
      final h = p.holes.single;
      expect(h.c.dx, closeTo(p.bends.single.end + 24, 1e-9));
      expect(h.c.dy, 50);
      expect(p.ok, isTrue);
      final inBend = _bent(
        PlateShape.l,
        [50, 80],
        holes: const [PlateHoleSpec(face: 1, dia: 13.5, u: 10, v: 50)],
      );
      expect(inBend.problems.join(), contains('절곡부에 걸리는 홀: 1.'));
      final near = _bent(
        PlateShape.l,
        [50, 80],
        holes: const [PlateHoleSpec(face: 1, dia: 13.5, u: 17, v: 50)],
      );
      expect(near.notes.join(), contains('보다 가까운 홀: 1.'));
      expect(near.ok, isTrue);
    });

    test('짧은 면은 절곡기에 안 걸릴 수 있다고 알림', () {
      final p = _bent(PlateShape.l, [10, 50]);
      expect(p.notes.join(), contains('1면 바깥 치수가 두께의 5배(15mm)보다 짧습니다'));
    });

    test('평판: 모서리 R·네 코너 홀·넓이·중량', () {
      final corners = const PlateHoleGroup(
        dia: 13.5,
        corners: true,
        x: 20,
        y: 20,
      ).expand(maxX: 200, maxY: 100);
      final p = platePlan(
        PlateInput(
          shape: PlateShape.flat,
          t: 3,
          length: 200,
          width: 100,
          cornerR: 10,
          holes: corners,
        ),
      );
      expect(p.holes.map((h) => h.c), const [
        Offset(20, 20),
        Offset(180, 20),
        Offset(180, 80),
        Offset(20, 80),
      ]);
      final area =
          200 * 100 - (4 - math.pi) * 100 - 4 * math.pi * 13.5 * 13.5 / 4;
      expect(p.areaMm2, closeTo(area, 1e-6));
      expect(p.kgEach, closeTo(area * 3 * 7.85e-6, 1e-9));
      expect(p.bends, isEmpty);
      expect(p.ok, isTrue);
    });

    test('홀 검사: 판 밖·서로 겹침·장공', () {
      final p = platePlan(
        const PlateInput(
          shape: PlateShape.flat,
          t: 3,
          length: 200,
          width: 100,
          holes: [
            PlateHoleSpec(dia: 13.5, u: 195, v: 50), // 판 밖으로
            PlateHoleSpec(dia: 13.5, u: 50, v: 50), // 겹침
            PlateHoleSpec(dia: 13.5, u: 60, v: 50),
            PlateHoleSpec(dia: 11, slot: 30, u: 120, v: 50), // 장공
          ],
        ),
      );
      expect(p.problems.join(), contains('판 밖으로 나오는 홀: 1.'));
      expect(p.problems.join(), contains('서로 겹치는 홀: 2·3.'));
      final slot = p.holes.last;
      expect(slot.slot, 30);
      expect(slot.halfX, 15);
      expect(slot.area, closeTo(11 * 19 + math.pi * 121 / 4, 1e-9));
    });

    test('삼각 리브·좌표 입력 넓이', () {
      final rib = platePlan(
        const PlateInput(
          shape: PlateShape.rib,
          t: 4,
          ribA: 100,
          ribB: 100,
          ribC: 15,
        ),
      );
      expect(rib.areaMm2, closeTo(5000 - 15 * 15 / 2, 1e-9));
      final pts = parsePlatePoints('0,0\n200 0\n200,100\n0,100\n잘못된 줄');
      expect(pts.length, 4);
      final free = platePlan(
        PlateInput(shape: PlateShape.free, t: 3, points: pts),
      );
      expect(free.areaMm2, closeTo(20000, 1e-9));
      final few = platePlan(
        const PlateInput(
          shape: PlateShape.free,
          t: 3,
          points: [Offset(0, 0), Offset(1, 1)],
        ),
      );
      expect(few.problems.join(), contains('3개 이상'));
    });

    test("홀 틀 풀기(줄·네 코너)와 원형 배치(PCD)", () {
      final row = const PlateHoleGroup(
        dia: 11,
        count: 3,
        x: 20,
        y: 30,
        pitch: 50,
      ).expand();
      expect(row.map((h) => (h.u, h.v)), [
        (20.0, 30.0),
        (70.0, 30.0),
        (120.0, 30.0),
      ]);
      final col = const PlateHoleGroup(
        dia: 11,
        count: 2,
        x: 20,
        y: 30,
        pitch: 40,
        rowAlongX: false,
        slot: 30,
        slotAlongX: false,
      ).expand();
      expect(col.map((h) => (h.u, h.v, h.angle, h.slot)), [
        (20.0, 30.0, 90.0, 30.0),
        (20.0, 70.0, 90.0, 30.0),
      ]);
      final pcd = platePcd(
        cu: 100,
        cv: 100,
        pcd: 100,
        count: 4,
        startDeg: 45,
        dia: 13.5,
      );
      expect(pcd.length, 4);
      expect(pcd.first.u, closeTo(100 + 50 * math.cos(math.pi / 4), 1e-9));
      expect(pcd[2].v, closeTo(100 - 50 * math.sin(math.pi / 4), 1e-9));
    });

    test("기운 장공: 감싸는 폭·겹침·판 밖을 실제 모양으로 본다", () {
      final p = platePlan(
        const PlateInput(
          shape: PlateShape.flat,
          t: 3,
          length: 200,
          width: 100,
          holes: [
            PlateHoleSpec(dia: 10, slot: 40, angle: 45, u: 100, v: 50),
            // 장공 끝에서 대각선으로 떨어진 구멍: 상자로는 겹치지만 실제로는 안 겹친다
            PlateHoleSpec(dia: 10, u: 112, v: 38),
          ],
        ),
      );
      final s = p.holes.first;
      expect(s.halfX, closeTo(15 * math.sqrt1_2 + 5, 1e-9));
      expect(p.problems, isEmpty);
      final touch = platePlan(
        const PlateInput(
          shape: PlateShape.flat,
          t: 3,
          length: 200,
          width: 100,
          holes: [
            PlateHoleSpec(dia: 10, slot: 40, angle: 45, u: 100, v: 50),
            PlateHoleSpec(dia: 10, u: 112, v: 112 - 50.0),
          ],
        ),
      );
      expect(touch.problems.join(), contains("서로 겹치는 홀: 1·2."));
    });

    test("90° 회전: 외곽·홀이 같이 돌고 저장 자리는 그대로", () {
      const base = PlateInput(
        shape: PlateShape.flat,
        t: 3,
        length: 200,
        width: 100,
        holes: [PlateHoleSpec(dia: 10, slot: 30, u: 40, v: 20)],
      );
      final p = platePlan(base.withHoles(base.holes, rotQ: 1));
      expect(p.flatLength, closeTo(100, 1e-9));
      expect(p.flatWidth, closeTo(200, 1e-9));
      final h = p.holes.single;
      // (40, 20)을 반시계 90° → (−20, 40), 옮김 (100, 0) → (80, 40)
      expect(h.c.dx, closeTo(80, 1e-9));
      expect(h.c.dy, closeTo(40, 1e-9));
      expect(h.angle, 90);
      expect((h.u, h.v), (40.0, 20.0));
      expect(p.toBase(h.c).dx, closeTo(40, 1e-9));
      expect(p.toBase(h.c).dy, closeTo(20, 1e-9));
      expect(p.ok, isTrue);
    });

    test("꺾음: 전개도 자리 → 면 자리(면에 붙어 따라감)", () {
      final p = _bent(PlateShape.l, [50, 80]);
      final (f, u, v) = p.specAt(Offset(p.bends.single.end + 24, 40));
      expect(f, 1);
      expect(u, closeTo(30, 1e-9));
      expect(v, 40);
      expect(p.specAt(const Offset(10, 40)).$1, 0);
      // 2면 치수를 바꿔도 같은 면 자리 그대로
      final longer = _bent(
        PlateShape.l,
        [70, 80],
        holes: const [PlateHoleSpec(face: 1, dia: 11, u: 30, v: 40)],
      );
      expect(
        longer.holes.single.c.dx,
        closeTo(longer.bends.single.end + 24, 1e-9),
      );
    });

    test('DXF: 층·외곽·홀·장공·절곡선·글', () {
      final p = _bent(
        PlateShape.l,
        [50, 80],
        holes: const [
          PlateHoleSpec(face: 1, dia: 13.5, u: 40, v: 50),
          PlateHoleSpec(face: 0, dia: 11, slot: 30, u: 20, v: 50, angle: 90),
        ],
      );
      final dxf = plateDxf(p, thickness: 3);
      expect(dxf, startsWith('0\nSECTION\n2\nHEADER'));
      expect(dxf, contains('AC1009'));
      expect(dxf, endsWith('0\nEOF\n'));
      expect(RegExp('\nLINE\n8\nCUT\n').allMatches(dxf).length, 4 + 2);
      expect(RegExp('\nCIRCLE\n8\nCUT\n').allMatches(dxf).length, 1);
      expect(RegExp('\nARC\n8\nCUT\n').allMatches(dxf).length, 2);
      expect(RegExp('\nLINE\n8\nBEND\n').allMatches(dxf).length, 1);
      expect(dxf, contains('BEND 1 UP 90 R3'));
      // 평판 모서리 R은 ARC 넷
      final flat = platePlan(
        const PlateInput(
          shape: PlateShape.flat,
          t: 3,
          length: 200,
          width: 100,
          cornerR: 10,
        ),
      );
      expect(
        RegExp('\nARC\n').allMatches(plateDxf(flat, thickness: 3)).length,
        4,
      );
    });
  });

  group('코너 처리', () {
    PlatePlan flat(List<PlateCorner> cs, {double w = 200, double h = 100}) =>
        platePlan(
          PlateInput(
            shape: PlateShape.flat,
            t: 3,
            length: w,
            width: h,
            corners: cs,
          ),
        );
    const sq = PlateCorner.square;
    double area(PlatePlan p) => plateOutlineArea(p.outline).abs();

    test('네 코너 R10: 넓이 = 사각 − 4 × (1 − π/4) × R²', () {
      final p = flat(
        List.filled(4, const PlateCorner(PlateCornerKind.round, 10)),
      );
      expect(area(p), closeTo(20000 - 4 * (1 - math.pi / 4) * 100, 1e-6));
      expect(p.ok, isTrue);
      // 예전 "모서리 R"과 같은 모양
      final old = platePlan(
        const PlateInput(
          shape: PlateShape.flat,
          t: 3,
          length: 200,
          width: 100,
          cornerR: 10,
        ),
      );
      expect(area(old), closeTo(area(p), 1e-6));
    });

    test('C10 한 코너, 따내기는 어느 코너든 가로 × 세로', () {
      expect(
        area(
          flat([const PlateCorner(PlateCornerKind.chamfer, 10), sq, sq, sq]),
        ),
        closeTo(20000 - 50, 1e-6),
      );
      for (var k = 0; k < 4; k++) {
        final cs = List.of(List.filled(4, sq));
        cs[k] = const PlateCorner(PlateCornerKind.notch, 30, 15);
        final p = flat(cs);
        expect(area(p), closeTo(20000 - 450, 1e-6), reason: '코너 $k');
        // 따낸 안쪽 귀: 가로로 30, 세로로 15 들어간 자리
        final inner = [
          const Offset(30, 15),
          const Offset(170, 15),
          const Offset(170, 85),
          const Offset(30, 85),
        ][k];
        final pts = plateOutlinePoints(p.outline);
        expect(
          pts.any((q) => (q - inner).distance < 1e-6),
          isTrue,
          reason: '코너 $k 안쪽 코너 $inner',
        );
      }
    });

    test('코너 처리가 옆 변보다 크면 알린다', () {
      final p = flat(
        List.filled(4, const PlateCorner(PlateCornerKind.round, 60)),
      );
      expect(p.ok, isFalse);
      expect(p.problems.join(), contains('사이 변(100mm)보다 모서리 처리가 큽니다'));
    });

    test('좌표 입력 꼭짓점 꼬리표 r·c·n 읽기·쓰기', () {
      final vs = parsePlateVertices(
        '0,0,r10\n100,0\n100,50,C5\n0,50,n20x15\n bad',
      );
      expect(vs.length, 4);
      expect(vs[0].$2.label, 'R10');
      expect(vs[1].$2.isNone, isTrue);
      expect(vs[2].$2.label, 'C5');
      expect(vs[3].$2.label, '따내기 20×15');
      final text = platePointsText(
        [for (final v in vs) v.$1],
        [for (final v in vs) v.$2],
      );
      expect(text, '0,0,r10\n100,0\n100,50,c5\n0,50,n20x15');
      final p = platePlan(
        PlateInput(
          shape: PlateShape.free,
          t: 3,
          points: [for (final v in vs) v.$1],
          pointCorners: [for (final v in vs) v.$2],
        ),
      );
      expect(
        area(p),
        closeTo(5000 - (1 - math.pi / 4) * 100 - 12.5 - 300, 1e-6),
      );
    });

    test('안으로 꺾인 코너는 따낼 수 없다고 알린다', () {
      // ㄱ자 모양: 꼭짓점 3(80,40)이 안으로 꺾인 귀
      final p = platePlan(
        PlateInput(
          shape: PlateShape.free,
          t: 3,
          points: const [
            Offset(0, 0),
            Offset(120, 0),
            Offset(120, 40),
            Offset(40, 40),
            Offset(40, 100),
            Offset(0, 100),
          ],
          pointCorners: const [
            sq,
            sq,
            sq,
            PlateCorner(PlateCornerKind.notch, 10, 10),
            sq,
            sq,
          ],
        ),
      );
      expect(p.problems.join(), contains('안쪽 코너라 따낼 수 없습니다'));
    });
  });

  group('판 가운데 십자선', () {
    test('DXF: DIM 층에 판 가운데 중심선 둘과 CL 글, 홀 치수는 없음, CUT 층은 그대로', () {
      final p = platePlan(
        const PlateInput(
          shape: PlateShape.flat,
          t: 3,
          length: 200,
          width: 100,
          holes: [
            PlateHoleSpec(u: 20, v: 20, dia: 13.5),
            PlateHoleSpec(u: 180, v: 20, dia: 13.5),
            PlateHoleSpec(u: 20, v: 80, dia: 13.5),
          ],
        ),
      );
      final dxf = plateDxf(p, thickness: 3);
      expect(RegExp(r'LINE\n8\nDIM\n').allMatches(dxf).length, 2);
      // 가로 중심선: (−5, 50) → (205, 50)
      expect(dxf, contains('LINE\n8\nDIM\n10\n-5\n20\n50\n'));
      final texts = RegExp(
        r'TEXT\n8\nDIM\n[^]*?\n1\n([^\n]+)\n',
      ).allMatches(dxf).map((m) => m.group(1)).toList();
      expect(texts, ['CL']);
      expect(RegExp(r'CIRCLE\n8\nCUT\n').allMatches(dxf).length, 3);
    });

    testWidgets('그림·PDF용 PNG에 판 가운데 십자선을 그려도 그대로 그려진다', (tester) async {
      final p = platePlan(
        const PlateInput(
          shape: PlateShape.flat,
          t: 3,
          length: 200,
          width: 100,
          holes: [
            PlateHoleSpec(u: 20, v: 20, dia: 13.5),
            PlateHoleSpec(u: 100, v: 50, dia: 11, slot: 30, angle: 45),
          ],
        ),
      );
      late Uint8List png;
      await tester.runAsync(() async {
        png = await renderPainterPng(
          PlatePainter(
            plan: p,
            text: Colors.black,
            sub: Colors.grey,
            bg: Colors.white,
          ),
          width: 600,
          height: 360,
        );
      });
      expect(png.length, greaterThan(1000));
    });
  });

  group('입체(3D) 모양', () {
    test('평판: 위아래 면에 홀 위치, 둘레 옆면, 홀마다 벽, 크기 = 판 × 두께', () {
      final p = platePlan(
        const PlateInput(
          shape: PlateShape.flat,
          t: 3,
          length: 200,
          width: 100,
          holes: [
            PlateHoleSpec(u: 50, v: 50, dia: 13.5),
            PlateHoleSpec(u: 140, v: 50, dia: 11, slot: 30),
          ],
        ),
      );
      final f = plate3dMesh(p, t: 3);
      final big = f.where((x) => x.kind == 0).toList();
      expect(big, hasLength(2));
      expect(big.every((x) => x.holes.length == 2), isTrue);
      expect(f.where((x) => x.kind == 1), hasLength(4));
      expect(
        f.where((x) => x.kind == 2).length,
        plateHoleLoop(p.holes[0]).length + plateHoleLoop(p.holes[1]).length,
      );
      final (lo, hi) = plate3dBounds(f);
      expect(hi.x - lo.x, closeTo(200, 1e-9));
      expect(hi.y - lo.y, closeTo(100, 1e-9));
      expect(hi.z - lo.z, closeTo(3, 1e-9));
      // 장공 둘레는 장공 길이만큼
      final slot = plateHoleLoop(p.holes[1]);
      final xs = slot.map((q) => q.dx);
      expect(xs.reduce(math.max) - xs.reduce(math.min), closeTo(30, 1e-9));
    });

    test('꺾은 판: 바깥 치수대로 접히고, 면 홀은 바깥면에서 잰 자리에', () {
      // ㄱ자 50·80: 가로 50, 높이 80, 폭 100
      final l = _bent(
        PlateShape.l,
        [50, 80],
        holes: const [PlateHoleSpec(face: 1, dia: 13.5, u: 30, v: 50)],
      );
      final fl = plate3dMesh(l, t: 3);
      final (lo, hi) = plate3dBounds(fl);
      expect(hi.x - lo.x, closeTo(50, 1e-6));
      expect(hi.z - lo.z, closeTo(80, 1e-6));
      expect(hi.y - lo.y, closeTo(100, 1e-6));
      // 구멍: 세운 면(2면) 앞뒤에 뚫리고 벽이 있다. 높이 = 바깥면(바닥)에서 30
      final withHole = fl.where((x) => x.kind == 0 && x.holes.isNotEmpty);
      expect(withHole, hasLength(2));
      final pts = [for (final x in withHole) ...x.holes.single];
      final cz = pts.map((q) => q.z).reduce((a, b) => a + b) / pts.length;
      final cy = pts.map((q) => q.y).reduce((a, b) => a + b) / pts.length;
      expect(cz - lo.z, closeTo(30, 0.01));
      expect(cy, closeTo(50, 0.01));
      expect(fl.where((x) => x.kind == 2), hasLength(24));
      // 세운 면의 큰 면은 옆(±x)을 향한다
      for (final x in withHole) {
        expect(x.normal.x.abs(), closeTo(1, 1e-9));
      }

      // ㄷ자 50·100·50: 가로 50, 높이 100
      final (ulo, uhi) = plate3dBounds(
        plate3dMesh(_bent(PlateShape.u, [50, 100, 50]), t: 3),
      );
      expect(uhi.x - ulo.x, closeTo(50, 1e-6));
      expect(uhi.z - ulo.z, closeTo(100, 1e-6));

      // 모자 발 30·높이 40·윗면 60: 높이 40, 가로 = 발 둘 + 윗면 − 다리 두께 둘
      final (hlo, hhi) = plate3dBounds(
        plate3dMesh(_bent(PlateShape.hat, [30, 40, 60]), t: 3),
      );
      expect(hhi.z - hlo.z, closeTo(40, 1e-6));
      expect(hhi.x - hlo.x, closeTo(30 + 60 + 30 - 2 * 3, 1e-6));
    });

    test('판 밖에 놓인 홀은 입체에서 뺀다(허공에 홀 벽이 뜨거나 크기가 커지지 않게)', () {
      final p = platePlan(
        const PlateInput(
          shape: PlateShape.flat,
          t: 3,
          length: 200,
          width: 100,
          holes: [
            PlateHoleSpec(u: 100, v: 50, dia: 17),
            PlateHoleSpec(u: 100, v: -37.5, dia: 17.5),
          ],
        ),
      );
      final f = plate3dMesh(p, t: 3);
      expect(
        f.where((x) => x.kind == 0).every((x) => x.holes.length == 1),
        isTrue,
      );
      expect(
        f.where((x) => x.kind == 2).length,
        plateHoleLoop(p.holes[0]).length,
      );
      final (lo, hi) = plate3dBounds(f);
      expect(hi.y - lo.y, closeTo(100, 1e-9));
      // 꺾은 판도 폭 밖 구멍은 뺀다
      final l = _bent(
        PlateShape.l,
        [50, 80],
        holes: const [
          PlateHoleSpec(face: 1, dia: 13.5, u: 30, v: 50),
          PlateHoleSpec(face: 1, dia: 13.5, u: 30, v: 140),
        ],
      );
      final fl = plate3dMesh(l, t: 3);
      expect(fl.where((x) => x.kind == 2), hasLength(24));
      final (llo, lhi) = plate3dBounds(fl);
      expect(lhi.y - llo.y, closeTo(100, 1e-6));
    });

    test('모든 면의 바깥 방향은 단위 길이, 꺾는 자리는 15° 안팎 토막', () {
      final p = _bent(PlateShape.z, [50, 50, 50]);
      final f = plate3dMesh(p, t: 3);
      for (final x in f) {
        expect(x.normal.length, closeTo(1, 1e-9));
        expect(x.loop.length, greaterThanOrEqualTo(3));
      }
      // 곧은 면 3개 × 앞뒤 + 꺾는 자리 2곳 × 6토막 × 앞뒤
      expect(f.where((x) => x.kind == 0), hasLength(3 * 2 + 2 * 6 * 2));
    });
  });

  group('화면', () {
    setUpAll(expandFormulaCards);
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> open(
      WidgetTester tester, {
      bool bend = true,
      Future<void> Function(String)? share,
      Future<void> Function(String)? dxf,
      Map<String, Object?>? initial,
    }) async {
      tester.view.physicalSize = const Size(800, 16000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PlatePage(
            bend: bend,
            share: share ?? (_) async {},
            shareDxf: dxf,
            initial: initial,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// 화면을 닫아 입력을 저장하게 한다(다시 열기 시험용).
    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> tap(WidgetTester tester, String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    /// 위 요약 줄 글(크기는 여기에만 나온다).
    String sum(WidgetTester tester) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(const Key('pl_sum')),
            matching: find.byType(Text),
          ),
        )
        .data!;

    /// 위 붙박이 그림에서 판 자리(mm) → 화면 점.
    Offset onView(WidgetTester tester, PlatePlan p, Offset mm) {
      final r = tester.getRect(find.byKey(const Key('pl_view')));
      return r.topLeft + PlatePainterLayout.of(p, r.size)!.toScreen(mm);
    }

    /// 맨 아래 "업체에 보내기" → dxf·pdf·kakao.
    /// 아래 탭 고르기(shape·bend·holes·result·send).
    Future<void> tab(WidgetTester tester, String id) async {
      await tester.tap(find.byKey(Key('pl_tab_$id')));
      await tester.pumpAndSettle();
    }

    /// 결과 표 한 줄을 "칸 | 칸" 글로(보이게 굴린 뒤 읽는다).
    Future<String> row(WidgetTester tester, String key) async {
      await tester.scrollUntilVisible(
        find.byKey(Key(key)),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      return tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(Key(key)),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .join(' | ');
    }

    /// 보내기 탭 → dxf·pdf·kakao.
    Future<void> send(WidgetTester tester, String what) async {
      await tab(tester, 'send');
      await tap(tester, 'pl_send_$what');
    }

    testWidgets('절곡 화면은 ㄱ자부터, 레이저 절단 화면은 평판부터, 입력은 따로 남는다', (tester) async {
      await open(tester);
      expect(find.text('절단 + 절곡'), findsOneWidget);
      expect(sum(tester), '철판 ㄱ자 · 3T · 전개 94.3 × 100 mm');
      // 탭: 모양 · 꺾기 · 구멍 · 결과 · 보내기(절곡), 처음은 모양 탭. 3D는 탭이 아니라 그림 칸 보기
      for (final id in ['shape', 'bend', 'holes', 'result', 'send']) {
        expect(find.byKey(Key('pl_tab_$id')), findsOneWidget);
      }
      expect(find.byKey(const Key('pl_tab_view3d')), findsNothing);
      expect(find.byKey(const Key('pl_view')), findsOneWidget);
      expect(find.byKey(const Key('pl_shape_flat')), findsNothing);
      expect(find.byKey(const Key('pl_side')), findsNothing); // 옆모습은 고를 때
      // 맨 아래 이전/다음 줄은 없다(아래 탭 줄과 겹쳤다, 10-11)
      expect(find.byKey(const Key('pl_next_bend')), findsNothing);
      await tab(tester, 'bend');
      expect(find.byKey(const Key('pl_bends')), findsOneWidget);
      expect(await row(tester, 'pl_bend_row_1'), startsWith('1 | 47.1 | '));
      // 절곡 탭은 처음에 측면도
      expect(find.byKey(const Key('pl_side')), findsOneWidget);
      await tab(tester, 'shape');
      expect(find.byKey(const Key('pl_shape_hat')), findsOneWidget);
      expect(find.byKey(const Key('pl_side')), findsNothing);
      await tab(tester, 'result');
      // 위 그림 칸은 탭마다 같은 자리: 전개도 · 옆모습 · 3D
      expect(find.byKey(const Key('pl_view')), findsOneWidget);
      await tap(tester, 'pl_vm_side');
      expect(find.byKey(const Key('pl_side')), findsOneWidget);
      await tap(tester, 'pl_vm_flat');
      // 결과 칸은 무게 위주(크기는 요약 줄에만)
      expect(find.textContaining('개당 약'), findsOneWidget);
      expect(find.text('94.3 × 100 mm'), findsNothing);
      await tab(tester, 'shape');
      await tap(tester, 'pl_shape_hat');
      // 발 50 · 높이 50 · 윗면 50 → 250 − 4 × 공제
      final hat = '${(250 - 4 * bd3).toStringAsFixed(1)} × 100 mm';
      expect(sum(tester), endsWith('전개 $hat'));
      await close(tester);

      await open(tester, bend: false);
      expect(find.text('레이저 절단'), findsOneWidget);
      expect(sum(tester), '철판 평판 · 3T · 200 × 100 mm');
      // 레이저 절단은 꺾기 탭이 없다
      expect(find.byKey(const Key('pl_tab_bend')), findsNothing);
      expect(find.byKey(const Key('pl_next_holes')), findsNothing);
      expect(find.byKey(const Key('pl_shape_hat')), findsNothing);
      await tap(tester, 'pl_shape_rib');
      expect(sum(tester), endsWith(' 100 × 100 mm'));
      await close(tester);

      await open(tester);
      expect(sum(tester), endsWith('전개 $hat'));
      await close(tester);
      await open(tester, bend: false);
      expect(sum(tester), endsWith(' 100 × 100 mm'));
    });

    testWidgets('그림 칸 3D: 크기 글, 끌면 돌아가고 칩·두 번 누르기로 보기 방향, 탭을 옮겨도 그대로', (
      tester,
    ) async {
      await open(tester);
      // 그림 칸 오른쪽 위에서 3D
      await tap(tester, 'pl_vm_3d');
      expect(find.byKey(const Key('p3_canvas')), findsOneWidget);
      expect(
        find.byKey(const Key('pl_center')),
        findsNothing,
      ); // 3D에서는 센터선 단추 없음
      // ㄱ자 50·50, 폭 100, 3t
      expect(
        tester.widget<Text>(find.byKey(const Key('p3_info'))).data,
        startsWith('50 × 100 × 50 mm (두께 3)'),
      );
      bool on(String k) =>
          tester.widget<PlateSegButton>(find.byKey(Key(k))).selected;
      expect(on('p3_iso'), isTrue);
      expect(on('pl_vm_3d'), isTrue);
      await tester.drag(
        find.byKey(const Key('p3_canvas')),
        const Offset(80, 0),
      );
      await tester.pumpAndSettle();
      expect(on('p3_iso'), isFalse);
      await tap(tester, 'p3_top');
      expect(on('p3_top'), isTrue);
      expect(on('p3_iso'), isFalse);
      // 두 번 누르면 처음 모습
      final c = tester.getCenter(find.byKey(const Key('p3_canvas')));
      await tester.tapAt(c);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(c);
      await tester.pumpAndSettle();
      expect(on('p3_iso'), isTrue);
      // 모양을 바꾸면 3D도 따라 바뀐다
      await tap(tester, 'pl_shape_hat');
      expect(
        tester.widget<Text>(find.byKey(const Key('p3_info'))).data,
        startsWith('144 × 100 × 50 mm'), // 발 50 둘 + 윗면 50 − 다리 두께 둘
      );
      // 다른 탭에서도 같은 그림 칸(구멍 탭은 구멍 편집 그림)
      await tab(tester, 'result');
      expect(find.byKey(const Key('p3_canvas')), findsOneWidget);
      await tab(tester, 'holes');
      expect(find.byKey(const Key('ed_canvas')), findsOneWidget);
      await tab(tester, 'send');
      expect(find.byKey(const Key('p3_canvas')), findsOneWidget);
      expect(find.byKey(const Key('pl_send_dxf')), findsOneWidget);
      // 이전/다음 줄은 없다(탭 줄로 옮긴다)
      expect(find.byKey(const Key('pl_prev_result')), findsNothing);
      await tap(tester, 'pl_vm_flat');
      expect(find.byKey(const Key('pl_view')), findsOneWidget);
    });

    testWidgets('네 코너는 한 줄로 같이, 코너 하나는 그림에서 눌러 따로', (tester) async {
      String? sent;
      await open(tester, bend: false, share: (s) async => sent = s);
      await tap(tester, 'pl_ck_round');
      await tester.enterText(find.byKey(const Key('pl_ca')), '20');
      await tester.pumpAndSettle();
      // 그림에서 왼쪽 아래 귀를 눌러 따내기 30×15
      final p = platePlan(
        const PlateInput(
          shape: PlateShape.flat,
          t: 3,
          length: 200,
          width: 100,
          corners: [
            PlateCorner(PlateCornerKind.round, 20),
            PlateCorner(PlateCornerKind.round, 20),
            PlateCorner(PlateCornerKind.round, 20),
            PlateCorner(PlateCornerKind.round, 20),
          ],
        ),
      );
      await tester.tapAt(onView(tester, p, Offset.zero));
      await tester.pumpAndSettle();
      expect(find.text('왼쪽 아래 코너'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cd_kind_notch')));
      await tester.pumpAndSettle();
      expect(find.text('따내기 가로'), findsOneWidget);
      expect(find.byKey(const Key('cd_preview')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('cd_a')), '30');
      await tester.enterText(find.byKey(const Key('cd_b')), '15');
      await tester.tap(find.byKey(const Key('cd_ok')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          '코너마다 다릅니다: 왼쪽 아래 따내기 30×15 · 오른쪽 아래 R20 · 오른쪽 위 R20 · 왼쪽 위 R20. 단추를 누르면 네 코너가 같아집니다.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('pl_ca')), findsNothing); // 섞여 있으면 크기 칸 없음
      await send(tester, 'kakao');
      expect(
        sent,
        contains(
          '200 × 100 · 왼쪽 아래 따내기 30×15 · 오른쪽 아래 R20 · 오른쪽 위 R20 · 왼쪽 위 R20',
        ),
      );
      // 다시 열어도 남는다
      await close(tester);
      await open(tester, bend: false, share: (s) async => sent = s);
      expect(find.byKey(const Key('pl_corner_mixed')), findsOneWidget);
      // 단추를 누르면 네 귀가 같아진다
      await tap(tester, 'pl_ck_none');
      expect(find.byKey(const Key('pl_corner_mixed')), findsNothing);
      await send(tester, 'kakao');
      expect(sent, contains('치수: 200 × 100 (mm)'));
    });

    testWidgets('그림에서 치수를 누르면 그 칸, 판을 누르면 홀 넣기·고치기', (tester) async {
      await open(tester, bend: false);
      final p = platePlan(
        const PlateInput(shape: PlateShape.flat, t: 3, length: 200, width: 100),
      );
      final r = tester.getRect(find.byKey(const Key('pl_view')));
      final lay = PlatePainterLayout.of(p, r.size)!;
      bool focused(String k) =>
          tester.widget<TextField>(find.byKey(Key(k))).focusNode!.hasFocus;
      await tester.tapAt(
        r.topLeft +
            Offset(lay.toScreen(const Offset(100, 0)).dx, lay.widthDimY),
      );
      await tester.pumpAndSettle();
      expect(focused('pl_len'), isTrue);
      await tester.tapAt(
        r.topLeft +
            Offset(lay.heightDimX, lay.toScreen(const Offset(0, 50)).dy),
      );
      await tester.pumpAndSettle();
      expect(focused('pl_wid'), isTrue);
      // 판 가운데 → 구멍 탭(편집 화면이 탭 안에)
      await tester.tapAt(onView(tester, p, const Offset(100, 50)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ed_canvas')), findsOneWidget);
    });

    testWidgets('예전 한 칸 저장: 같은 방식 화면만 이어 쓰고 "모서리 R"은 네 코너 R로', (tester) async {
      SharedPreferences.setMockInitialValues({
        PlatePage.legacyDraftKey: jsonEncode({
          'bend': false,
          'sh': 'flat',
          'mat': 'steel',
          't': '4',
          'len': '300',
          'wid': '150',
          'cr': '10',
          'holes': const [],
        }),
        PlatePage.legacySavedKey: jsonEncode([
          {
            'name': '꺾음 하나',
            'data': {'bend': true, 'sh': 'u', 't': '3'},
          },
          {
            'name': '평판 하나',
            'data': {'bend': false, 'sh': 'flat', 't': '4'},
          },
        ]),
      });
      await open(tester, bend: false);
      expect(sum(tester), '철판 평판 · 4T · 300 × 150 mm');
      expect(
        tester
            .widget<PlateSegButton>(find.byKey(const Key('pl_ck_round')))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('pl_ca')))
            .controller!
            .text,
        '10',
      );
      final prefs = await SharedPreferences.getInstance();
      final cutSaved = prefs.getString(PlatePage.savedKeyOf(false))!;
      expect(cutSaved, contains('평판 하나'));
      expect(cutSaved, isNot(contains('꺾음 하나')));
      await close(tester);
      // 닫을 때 남긴 입력에 첫 화면 "이어서" 글이 들어 있다
      expect(
        prefs.getString(PlatePage.draftKeyOf(false)),
        contains('"lbl":"평판 4T · 300 × 150"'),
      );
      await open(tester);
      expect(sum(tester), endsWith('전개 94.3 × 100 mm')); // 절곡 화면은 새로
      expect(prefs.getString(PlatePage.savedKeyOf(true)), contains('꺾음 하나'));
      // 옛 칸은 지우지 않는다
      expect(prefs.getString(PlatePage.legacyDraftKey), isNotNull);
    });

    testWidgets('좌표 입력: 가로·세로 칸으로 모양 전체와 홀 위치를 늘이고 줄인다', (tester) async {
      await open(
        tester,
        bend: false,
        initial: {
          'sh': 'free',
          'pts':
              '0,0\n70,0\n70,40\n140,40\n140,0\n210,0\n210,75\n145,75\n145,145\n65,145\n65,75\n0,75',
          'holes': [const PlateHoleSpec(u: 30, v: 35, dia: 17).toJson()],
          'rot': 0,
          't': '3',
        },
      );
      String text(String k) =>
          tester.widget<TextField>(find.byKey(Key(k))).controller!.text;
      expect(text('pl_fw'), '210');
      expect(text('pl_fh'), '145');
      await tester.enterText(find.byKey(const Key('pl_fw')), '420');
      await tester.pumpAndSettle();
      expect(sum(tester), endsWith(' 420 × 145 mm'));
      expect(text('pl_points'), startsWith('0,0\n140,0\n140,40'));
      // 한 자씩 쳐도 잡아 둔 처음 모양에서 늘인다(중간 값이 쌓이지 않음)
      await tester.enterText(find.byKey(const Key('pl_fh')), '2');
      await tester.enterText(find.byKey(const Key('pl_fh')), '29');
      await tester.enterText(find.byKey(const Key('pl_fh')), '290');
      await tester.pumpAndSettle();
      expect(sum(tester), endsWith(' 420 × 290 mm'));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tab(tester, 'result');
      // 홀(30, 35) → (60, 70), 지름은 그대로
      expect(await row(tester, 'pl_hole_row_1'), '1 | φ17 | 60 | 70');
    });

    testWidgets('스케치에서 넘겨 받은 모양을 덮고, 알림으로 되돌린다', (tester) async {
      await open(
        tester,
        bend: false,
        initial: {
          'sh': 'free',
          'pts': '0,0\n150,0,r10\n150,80\n0,80',
          'holes': [const PlateHoleSpec(u: 20, v: 20, dia: 11).toJson()],
          'rot': 0,
          't': '4',
        },
      );
      expect(find.textContaining('스케치에서 옮겨 왔습니다'), findsOneWidget);
      expect(sum(tester), '철판 좌표 입력 · 4T · 150 × 80 mm');
      expect(
        find.textContaining('홀 1개 · φ11 1', skipOffstage: false),
        findsOneWidget,
      );
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(sum(tester), endsWith(' 200 × 100 mm'));
    });

    testWidgets('홀 넣기·고치기 → 편집 화면의 "줄로 넣기" → 결과·DXF, 다시 열어도 남는다', (
      tester,
    ) async {
      String? dxf;
      await open(tester, dxf: (s) async => dxf = s);
      // 구멍 탭(편집 화면) 안의 "줄로 넣기"
      await tab(tester, 'holes');
      // 숫자로 넣기 → 홀 입력 창(하나), 면 2면
      await tap(tester, 'ed_add_row');
      expect(find.byKey(const Key('hi_preview')), findsOneWidget);
      await tester.tap(find.byKey(const Key('hs_face_1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('hs_x')), '30');
      await tester.enterText(find.byKey(const Key('hs_y')), '50');
      await tester.tap(find.byKey(const Key('hs_ok')));
      await tester.pumpAndSettle();
      await tab(tester, 'result');
      expect(find.textContaining('홀 1개 · φ13.5 1'), findsOneWidget);
      expect(
        await row(tester, 'pl_hole_row_1'),
        startsWith('1 | φ13.5 | 2면 30 · 50 | '),
      );
      await send(tester, 'dxf');
      expect(dxf, contains('CIRCLE'));
      expect(dxf, contains('BEND 1 UP 90 R3'));
      await close(tester);
      await open(tester);
      await tab(tester, 'result');
      expect(find.textContaining('홀 1개 · φ13.5 1'), findsOneWidget);
    });

    testWidgets('업체 공제값: 직접 넣기 → 업체 값 저장(설정) → 두께를 고르면 업체 값', (tester) async {
      await open(tester);
      await tap(tester, 'pl_t_4.5');
      await tab(tester, 'bend');
      bool on(String k) =>
          tester.widget<PlateSegButton>(find.byKey(Key(k))).selected;
      // 처음은 일반값(값은 보기만, 칸이 아님)
      expect(on('pl_bm_auto'), isTrue);
      expect(find.byKey(const Key('pl_bd')), findsNothing);
      expect(find.byKey(const Key('pl_bm_saved')), findsNothing);
      await tap(tester, 'pl_bm_manual');
      await tester.enterText(find.byKey(const Key('pl_bd')), '7');
      await tester.pumpAndSettle();
      expect(sum(tester), endsWith('전개 93 × 100 mm'));
      // 업체 값 저장 → 설정 화면, 넣기 칸에 지금 값이 채워져 있다
      await tap(tester, 'pl_bd_manage');
      expect(find.text('철판 가공 설정'), findsOneWidget);
      expect(find.byKey(const Key('ps_bd_prefilled')), findsOneWidget);
      String text(String k) =>
          tester.widget<TextField>(find.byKey(Key(k))).controller!.text;
      expect(text('ps_bt'), '4.5');
      expect(text('ps_bdv'), '7');
      await tap(tester, 'ps_bd_add');
      await tester.pageBack();
      await tester.pumpAndSettle();
      // 같은 값이 저장됐으니 업체 값으로
      expect(on('pl_bm_saved'), isTrue);
      await tab(tester, 'shape');
      await tap(tester, 'pl_t_3.2');
      await tab(tester, 'bend');
      expect(on('pl_bm_auto'), isTrue);
      expect(find.byKey(const Key('pl_bm_saved')), findsNothing);
      await tab(tester, 'shape');
      await tap(tester, 'pl_t_4.5');
      await tab(tester, 'bend');
      expect(on('pl_bm_saved'), isTrue);
      expect(sum(tester), endsWith('전개 93 × 100 mm'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PlatePage.bendTableKey), contains('"4.5"'));
    });

    testWidgets('센터선 켜고 끄기(기억, 홀 탭도 따름), 요약은 제목 아래', (tester) async {
      await open(tester, bend: false);
      // 요약 줄을 따로 두지 않고 제목 아래 작은 글로
      expect(find.byType(ElecSummaryBar), findsNothing);
      expect(sum(tester), '철판 평판 · 3T · 200 × 100 mm');
      PlatePainter painter() =>
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byKey(const Key('pl_view')),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as PlatePainter;
      expect(painter().showCenter, isTrue);
      await tap(tester, 'pl_center');
      expect(painter().showCenter, isFalse);
      await tab(tester, 'holes');
      expect(
        tester
            .widget<PlateHoleEditorPage>(find.byType(PlateHoleEditorPage))
            .showCenter,
        isFalse,
      );
      await close(tester);
      await open(tester, bend: false);
      expect(painter().showCenter, isFalse);
    });

    testWidgets('보내기 탭 → 카톡 글, 키보드가 뜨면 아래 탭 줄을 숨긴다', (tester) async {
      String? sent;
      await open(tester, share: (s) async => sent = s);
      await send(tester, 'kakao');
      expect(sent, startsWith('[철판 가공] ㄱ자 · 철판 3T · 1장'));
      expect(sent, contains('전개 크기: 94.3 × 100mm'));
      expect(sent, contains('절곡 1: 왼쪽 끝에서 47.1mm'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 600);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pl_tab_send')), findsNothing);
    });

    testWidgets('전개도·측면도 PNG와 PDF', (tester) async {
      final p = _bent(
        PlateShape.hat,
        [30, 40, 60],
        holes: const [PlateHoleSpec(face: 0, dia: 11, u: 15, v: 50)],
      );
      late Uint8List pdf;
      await tester.runAsync(() async {
        final flat = await renderPainterPng(
          PlatePainter(
            plan: p,
            text: Colors.black,
            sub: Colors.grey,
            bg: Colors.white,
          ),
          width: 700,
          height: 400,
        );
        final side = await renderPainterPng(
          BusbarShapePainter(
            plan: p.bendPlan!,
            rho: p.rUsed + p.kUsed * 3,
            thickness: 3,
            text: Colors.black,
            sub: Colors.grey,
            line: Colors.grey,
          ),
          width: 600,
          height: 300,
        );
        pdf = await buildBracketPdf(
          BracketPdfInput(
            title: 'TEST',
            docTitle: '철판 가공 도면',
            summary: const [('모양', '모자')],
            drawingPng: flat,
            moreDrawings: [('측면도', side)],
            sections: const [],
            notes: const [],
          ),
        );
      });
      expect(String.fromCharCodes(pdf.sublist(0, 4)), '%PDF');
    });
  });
}
