// 직접 절곡(10-11, 사용자: "스케치도 절곡으로 넘기고, 절곡 위치·방향 지정"): 바깥 치수로 펴 그린 판 + 나란한 절곡선.
// 사각 판은 ㄱ·Z자와 같은 결과, 가로선, L자 판(절곡선이 판 일부만 지남), 홀 자리, ㄱ·ㄷ·Z·모자 방향 뒤집기.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/ai_plate_sketch.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_page.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_painter.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_side_painter.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_sketch_model.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_sketch_page.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_ui.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_calc.dart';

List<Offset> rect(double w, double h) => [
  Offset.zero,
  Offset(w, 0),
  Offset(w, h),
  Offset(0, h),
];

PlatePlan custom(
  List<Offset> pts,
  List<PlateBendSpec> bl, {
  bool h = false,
  List<PlateHoleSpec> holes = const [],
}) => platePlan(
  PlateInput(
    shape: PlateShape.custom,
    t: 3,
    points: pts,
    bendLines: bl,
    bendAxisH: h,
    holes: holes,
  ),
);

void main() {
  test('사각 200 × 100, 절곡선 50 UP 90° = ㄱ자 50·150 폭 100', () {
    final c = custom(rect(200, 100), const [PlateBendSpec(at: 50)]);
    final l = platePlan(
      const PlateInput(shape: PlateShape.l, t: 3, width: 100, legs: [50, 150]),
    );
    expect(c.ok, isTrue, reason: c.problems.join());
    expect(c.flatLength, closeTo(l.flatLength, 1e-9));
    expect(c.flatWidth, closeTo(100, 1e-9));
    expect(c.bends.single.center, closeTo(l.bends.single.center, 1e-9));
    expect(c.bends.single.turn, 90);
    expect(c.faceNames, ['1면', '2면']);
    expect(c.areaMm2, closeTo(l.areaMm2, 1e-6));
  });

  test('사각 195 × 70, 60 UP · 145 DOWN = Z자 60·85·50 폭 70', () {
    final c = custom(rect(195, 70), const [
      PlateBendSpec(at: 145, up: false),
      PlateBendSpec(at: 60),
    ]);
    final z = platePlan(
      const PlateInput(
        shape: PlateShape.z,
        t: 3,
        width: 70,
        legs: [60, 85, 50],
      ),
    );
    expect(c.flatLength, closeTo(z.flatLength, 1e-9));
    for (var n = 0; n < 2; n++) {
      expect(c.bends[n].center, closeTo(z.bends[n].center, 1e-9));
      expect(c.bends[n].turn, z.bends[n].turn);
    }
    expect(c.faceLengths, [60, 85, 50]);
  });

  test('가로선: 판을 돌려 계산(100 × 200, 아래에서 50) = ㄱ자 50·150 폭 100', () {
    final c = custom(rect(100, 200), const [PlateBendSpec(at: 50)], h: true);
    final l = platePlan(
      const PlateInput(shape: PlateShape.l, t: 3, width: 100, legs: [50, 150]),
    );
    expect(c.flatLength, closeTo(l.flatLength, 1e-9));
    expect(c.flatWidth, closeTo(100, 1e-9));
  });

  test('L자 판: 절곡선이 판이 있는 곳에만, 줄어든 넓이 = 공제값 × 그 자리 판 높이', () {
    const pts = [
      Offset(0, 0),
      Offset(200, 0),
      Offset(200, 50),
      Offset(80, 50),
      Offset(80, 120),
      Offset(0, 120),
    ];
    final flat = platePlan(
      const PlateInput(shape: PlateShape.free, t: 3, points: pts),
    );
    final c = custom(pts, const [PlateBendSpec(at: 150)]);
    expect(c.ok, isTrue, reason: c.problems.join());
    final bd = c.bd90Used;
    expect(c.flatLength, closeTo(200 - bd, 1e-9));
    expect(c.areaMm2, closeTo(flat.areaMm2 - bd * 50, 1e-6));
    final poly = plateOutlinePoints(c.outline);
    final sp = plateBendSpans(poly, c.bends.single.center);
    expect(sp.length, 1);
    expect(sp.single.$1, closeTo(0, 1e-9));
    expect(sp.single.$2, closeTo(50, 1e-9));
    // 높은 쪽(왼쪽 0~80)은 그대로
    expect(plateBendSpans(poly, 40).single.$2, closeTo(120, 1e-9));
  });

  test('홀은 면 기준: 2면 30 · 40 = ㄱ자와 같은 자리, 절곡선 넣기 전에는 한 면', () {
    const hole = PlateHoleSpec(face: 1, u: 30, v: 40, dia: 11);
    final c = custom(
      rect(200, 100),
      const [PlateBendSpec(at: 50)],
      holes: [hole],
    );
    final l = platePlan(
      const PlateInput(
        shape: PlateShape.l,
        t: 3,
        width: 100,
        legs: [50, 150],
        holes: [hole],
      ),
    );
    expect(c.holes.single.c.dx, closeTo(l.holes.single.c.dx, 1e-9));
    final none = custom(rect(200, 100), const []);
    expect(none.isBent, isTrue);
    expect(none.bends, isEmpty);
    expect(none.faceNames, ['1면']);
    expect(none.flatLength, 200);
  });

  test('판 밖 절곡선·같은 자리 둘은 알림', () {
    expect(
      custom(rect(200, 100), const [PlateBendSpec(at: 250)]).problems.join(),
      contains('판 밖에 있는 절곡선'),
    );
    expect(
      custom(rect(200, 100), const [
        PlateBendSpec(at: 80),
        PlateBendSpec(at: 80),
      ]).problems.join(),
      contains('같은 자리'),
    );
  });

  test('ㄱ·ㄷ·Z·모자 방향 뒤집기: Z자 [뒤집음, 뒤집음] → DOWN·UP, 전개 길이는 같다', () {
    const base = PlateInput(
      shape: PlateShape.z,
      t: 3,
      width: 70,
      legs: [60, 85, 50],
    );
    final z = platePlan(base);
    final f = platePlan(
      const PlateInput(
        shape: PlateShape.z,
        t: 3,
        width: 70,
        legs: [60, 85, 50],
        flips: [true, true],
      ),
    );
    expect([for (final b in f.bends) b.turn], [-90, 90]);
    expect(f.flatLength, closeTo(z.flatLength, 1e-9));
  });

  group('화면', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> open(
      WidgetTester tester, {
      Map<String, Object?>? initial,
    }) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PlatePage(bend: true, share: (_) async {}, initial: initial),
        ),
      );
      await tester.pumpAndSettle();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }

    Future<void> tap(WidgetTester tester, String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    Future<void> tab(WidgetTester tester, String id) async {
      await tester.tap(find.byKey(Key('pl_tab_$id')));
      await tester.pumpAndSettle();
    }

    String sum(WidgetTester tester) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(const Key('pl_sum')),
            matching: find.byType(Text),
          ),
        )
        .data!;

    Future<void> addLine(
      WidgetTester tester,
      String at, {
      bool down = false,
    }) async {
      await tap(tester, 'pl_bl_add');
      expect(find.byKey(const Key('bl_preview')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('bl_at')), at);
      await tester.pumpAndSettle();
      if (down) await tap(tester, 'bl_down');
      await tester.tap(find.byKey(const Key('bl_ok')));
      await tester.pumpAndSettle();
    }

    final bd = platePlan(const PlateInput(shape: PlateShape.l, t: 3)).bd90Used;

    testWidgets('스케치 → 절단 + 절곡으로: 직접 절곡 지도를 넘긴다', (tester) async {
      final sk = PlateSketch(
        pts: const [
          Offset(0, 0),
          Offset(200, 0),
          Offset(200, 100),
          Offset(0, 100),
        ],
        ids: const [0, 1, 2, 3],
        nextId: 4,
        dims: const {0: 200, 1: 100},
        frame: const Rect.fromLTWH(-20, -20, 240, 140),
        scaled: true,
        closed: true,
        holes: const [PlateHoleSpec(u: 150, v: 50, dia: 11)],
      );
      SharedPreferences.setMockInitialValues({
        PlateSketchPage.draftKey: jsonEncode(sk.toJson()),
      });
      Map<String, Object?>? cut, bend;
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PlateSketchPage(
            parse: (_) async => const PlateSketchResult.fail('없음'),
            pickPhoto: (_) async => null,
            loadPhoto: () async => null,
            savePhoto: (_) async {},
            openCut: (_, m) => cut = m,
            openBend: (_, m) => bend = m,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sk_tab_send')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sk_send_bend')));
      await tester.pumpAndSettle();
      expect(cut, isNull);
      expect(bend!['sh'], 'custom');
      expect(bend!['bl'], isEmpty);
      expect((bend!['holes'] as List).length, 1);
      await tester.tap(find.byKey(const Key('sk_send')));
      await tester.pumpAndSettle();
      expect(cut!['sh'], 'free');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('넘겨 받으면 직접·절곡 탭, 절곡선 넣기 → 전개 줄고 홀은 바깥 자리 그대로, 방향·지우기', (
      tester,
    ) async {
      await open(
        tester,
        initial: {
          'sh': 'custom',
          'pts': '0,0\n200,0\n200,100\n0,100',
          'holes': [const PlateHoleSpec(u: 150, v: 50, dia: 11).toJson()],
          'bl': const <Object>[],
          't': '3',
        },
      );
      expect(find.textContaining('절곡선을 넣으십시오'), findsOneWidget);
      expect(find.byKey(const Key('pl_bl_empty')), findsOneWidget);
      expect(sum(tester), endsWith('전개 200 × 100 mm'));
      await addLine(tester, '50');
      expect(find.byKey(const Key('pl_bend_item_1')), findsOneWidget);
      expect(sum(tester), endsWith('전개 ${fmtTest(200 - bd)} × 100 mm'));
      // 홀(바깥 150)은 2면 100으로 옮겨 붙는다 → 전개도 150 − 공제값
      await tab(tester, 'result');
      final hole = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('pl_hole_row_1')),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .join(' | ');
      expect(
        hole,
        startsWith('1 | φ11 | 2면 100 · 50 | ${fmtTest(150 - bd)} | '),
      );
      // 방향 DOWN → 측면도 각
      await tab(tester, 'bend');
      await tap(tester, 'pl_bdir_1_down');
      await tap(tester, 'pl_vm_side');
      final side =
          tester.widget<CustomPaint>(find.byKey(const Key('pl_side'))).painter!
              as PlateSidePainter;
      expect(side.turns, [-90]);
      // 고치기 창에서 지우기
      await tap(tester, 'pl_vm_flat');
      await tap(tester, 'pl_bl_edit_1');
      await tap(tester, 'bl_del');
      expect(find.byKey(const Key('pl_bend_item_1')), findsNothing);
      expect(sum(tester), endsWith('전개 200 × 100 mm'));
    });

    testWidgets('절곡선 창: 판 밖·같은 자리는 넣기 꺼짐과 이유', (tester) async {
      await open(tester, initial: {'sh': 'custom', 't': '3'});
      await addLine(tester, '80');
      await tap(tester, 'pl_bl_add');
      await tester.enterText(find.byKey(const Key('bl_at')), '250');
      await tester.pumpAndSettle();
      expect(find.textContaining('0 ~ 200mm 사이'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('bl_at')), '80');
      await tester.pumpAndSettle();
      expect(find.textContaining('80mm에 절곡선이 이미 있습니다'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('bl_ok'))).onPressed,
        isNull,
      );
      await tap(tester, 'ps_cancel');
    });

    testWidgets('세로선 ↔ 가로선: 넣은 절곡선은 지우고 알림에서 되돌린다', (tester) async {
      await open(tester, initial: {'sh': 'custom', 't': '3'});
      await addLine(tester, '50');
      await tap(tester, 'pl_bax_h');
      expect(find.byKey(const Key('pl_bend_item_1')), findsNothing);
      expect(find.textContaining('절곡선을 지웠습니다'), findsOneWidget);
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pl_bend_item_1')), findsOneWidget);
      bool on(String k) =>
          tester.widget<PlateSegButton>(find.byKey(Key(k))).selected;
      expect(on('pl_bax_v'), isTrue);
    });

    testWidgets('전개도에서 절곡선을 옆으로 끌면 옮긴다(절곡 탭)', (tester) async {
      await open(tester, initial: {'sh': 'custom', 't': '3'});
      await addLine(tester, '50');
      final view = find.byKey(const Key('pl_view'));
      final r = tester.getRect(view);
      final p = platePlan(
        const PlateInput(
          shape: PlateShape.custom,
          t: 3,
          points: [
            Offset(0, 0),
            Offset(200, 0),
            Offset(200, 100),
            Offset(0, 100),
          ],
          bendLines: [PlateBendSpec(at: 50)],
        ),
      );
      final lay = PlatePainterLayout.of(p, r.size)!;
      final from = r.topLeft + lay.toScreen(Offset(p.bends.single.center, 50));
      await tester.dragFrom(from, Offset(20 * lay.s, 0));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('pl_bend_item_1')),
          matching: find.textContaining('70mm'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('ㄱ·ㄷ·Z·모자 방향: Z자 1번을 DOWN으로 → DOWN·DOWN', (tester) async {
      await open(tester);
      await tap(tester, 'pl_shape_z');
      await tab(tester, 'bend');
      await tap(tester, 'pl_bdir_1_down');
      final side =
          tester.widget<CustomPaint>(find.byKey(const Key('pl_side'))).painter!
              as PlateSidePainter;
      expect(side.turns, [-90, -90]);
      // 다른 모양을 고르면 처음 방향
      await tab(tester, 'shape');
      await tap(tester, 'pl_shape_u');
      await tab(tester, 'bend');
      final u =
          tester.widget<CustomPaint>(find.byKey(const Key('pl_side'))).painter!
              as PlateSidePainter;
      expect(u.turns, [90, 90]);
    });
  });
}

String fmtTest(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s;
}
