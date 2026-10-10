// 철판 가공(10-10): 공제값·전개 길이·꺾기선, 업체 공제값으로 k 맞추기, 면 구멍 → 전개도 자리, 구멍 검사,
// 평판·리브·자유 모양 넓이·무게, DXF 내용, 화면(가공 방식·구멍 넣기·DXF·두께별 공제값 저장), 그림·PDF.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_bend_painter.dart';
import 'package:tubing_calculator/src/presentation/steel_bracket/bracket_pdf.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_calc.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_dxf.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_page.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_painter.dart';
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
    test('ㄱ자 3t: 전개 = 바깥 치수 합 − 공제값, 꺾기선 자리', () {
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

    test('ㄷ·Z·모자: 꺾는 곳마다 공제, 방향', () {
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

    test('면 구멍 → 전개도 자리, 꺾기에 걸리면 못 만듦, 가까우면 알림', () {
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
      expect(inBend.problems.join(), contains('꺾이는 부분에 걸리는 구멍: 1.'));
      final near = _bent(
        PlateShape.l,
        [50, 80],
        holes: const [PlateHoleSpec(face: 1, dia: 13.5, u: 17, v: 50)],
      );
      expect(near.notes.join(), contains('보다 가까운 구멍: 1.'));
      expect(near.ok, isTrue);
    });

    test('짧은 면은 절곡기에 안 걸릴 수 있다고 알림', () {
      final p = _bent(PlateShape.l, [10, 50]);
      expect(p.notes.join(), contains('1면 바깥 치수가 두께의 5배(15mm)보다 짧습니다'));
    });

    test('평판: 모서리 R·네 귀 구멍·넓이·무게', () {
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

    test('구멍 검사: 판 밖·서로 겹침·장공', () {
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
      expect(p.problems.join(), contains('판 밖으로 나오는 구멍: 1.'));
      expect(p.problems.join(), contains('서로 겹치는 구멍: 2·3.'));
      final slot = p.holes.last;
      expect(slot.slot, 30);
      expect(slot.halfX, 15);
      expect(slot.area, closeTo(11 * 19 + math.pi * 121 / 4, 1e-9));
    });

    test('삼각 리브·자유 모양 넓이', () {
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

    test("구멍 틀 풀기(줄·네 귀)와 원형 배치(PCD)", () {
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
      expect(touch.problems.join(), contains("서로 겹치는 구멍: 1·2."));
    });

    test("판 90° 돌리기: 외곽·구멍이 같이 돌고 저장 자리는 그대로", () {
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

    test('DXF: 층·외곽·구멍·장공·꺾기선·글', () {
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

  group('화면', () {
    setUpAll(expandFormulaCards);
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> open(
      WidgetTester tester, {
      Future<void> Function(String)? share,
      Future<void> Function(String)? dxf,
    }) async {
      tester.view.physicalSize = const Size(800, 16000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PlatePage(share: share ?? (_) async {}, shareDxf: dxf),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tap(WidgetTester tester, String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    testWidgets('기본 ㄱ자 3t → 레이저 절단만(평판)으로', (tester) async {
      await open(tester);
      expect(find.text('94.3 × 100 mm'), findsOneWidget);
      expect(find.byKey(const Key('pl_view')), findsOneWidget);
      expect(find.byKey(const Key('pl_side')), findsOneWidget);
      expect(find.textContaining('꺾기 1: 왼쪽 끝에서 47.1mm'), findsOneWidget);
      await tap(tester, 'pl_cut');
      expect(find.text('200 × 100 mm'), findsOneWidget);
      expect(find.byKey(const Key('pl_side')), findsNothing);
      await tap(tester, 'pl_shape_rib');
      expect(find.text('100 × 100 mm'), findsOneWidget);
      await tap(tester, 'pl_bend');
      await tap(tester, 'pl_shape_hat');
      // 발 50 · 높이 50 · 윗면 50 → 250 − 4 × 공제
      expect(
        find.text('${(250 - 4 * bd3).toStringAsFixed(1)} × 100 mm'),
        findsOneWidget,
      );
    });

    testWidgets('구멍 넣기 → 결과·DXF, 다시 열어도 구멍이 남는다', (tester) async {
      String? dxf;
      await open(tester, dxf: (s) async => dxf = s);
      await tap(tester, 'pl_hole_add');
      await tester.tap(find.byKey(const Key('hs_face_1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('hs_x')), '30');
      await tester.enterText(find.byKey(const Key('hs_y')), '50');
      await tester.tap(find.byKey(const Key('hs_ok')));
      await tester.pumpAndSettle();
      expect(find.textContaining('구멍 1개 · φ13.5 1'), findsOneWidget);
      expect(find.textContaining('구멍 1 φ13.5: 2면 30·50 → 전개도'), findsOneWidget);
      await tap(tester, 'pl_dxf');
      expect(dxf, contains('CIRCLE'));
      expect(dxf, contains('BEND 1 UP 90 R3'));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await open(tester);
      expect(find.textContaining('구멍 1개 · φ13.5 1'), findsOneWidget);
    });

    testWidgets('업체 공제값을 두께별로 저장하고 두께를 고르면 채운다', (tester) async {
      await open(tester);
      await tap(tester, 'pl_t_4');
      await tester.enterText(find.byKey(const Key('pl_bd')), '7');
      await tester.pumpAndSettle();
      expect(find.text('93 × 100 mm'), findsOneWidget);
      await tap(tester, 'pl_bd_save');
      await tap(tester, 'pl_t_3');
      String text(String k) =>
          tester.widget<TextField>(find.byKey(Key(k))).controller!.text;
      expect(text('pl_bd'), '');
      await tap(tester, 'pl_t_4');
      expect(text('pl_bd'), '7');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PlatePage.bendTableKey), contains('"4"'));
    });

    testWidgets('카톡 글', (tester) async {
      String? sent;
      await open(tester, share: (s) async => sent = s);
      await tap(tester, 'pl_share');
      expect(sent, startsWith('[철판 가공] ㄱ자 · 철판 3t · 1장'));
      expect(sent, contains('전개 크기: 94.3 × 100mm'));
      expect(sent, contains('꺾기 1: 왼쪽 끝에서 47.1mm'));
    });

    testWidgets('전개도·꺾은 모양 PNG와 PDF', (tester) async {
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
            docTitle: '철판 가공 지시서',
            summary: const [('모양', '모자')],
            drawingPng: flat,
            moreDrawings: [('꺾은 모양', side)],
            sections: const [],
            notes: const [],
          ),
        );
      });
      expect(String.fromCharCodes(pdf.sublist(0, 4)), '%PDF');
    });
  });
}
