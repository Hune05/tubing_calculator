// 철판 가공 점검 26~32(10-11, 사용자: "26번부터 32번까지 진행해"): 모양을 바꿔 판 밖으로 나간 홀 알림,
// 고른 홀 단추 줄(휴대폰), 꼭짓점 표, 스케치 홀 넣기 창, 스케치 맨 위 치수 글 여백, "홀 넣기" 단추가 홀을
// 가리지 않게, 넓이 cm².
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/utils/ai_plate_sketch.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_calc.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_page.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_sketch_model.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_sketch_page.dart';

void main() {
  group('계산', () {
    test('넓이 글: 1m² 아래는 cm², 100 아래는 소수 한 자리, 큰 판은 m²', () {
      expect(plateAreaText(200 * 100), '200 cm²');
      expect(plateAreaText(12300), '123 cm²');
      expect(plateAreaText(5050), '50.5 cm²');
      expect(plateAreaText(123456), '1,235 cm²');
      expect(plateAreaText(999999), '1.00 m²');
      expect(plateAreaText(1500 * 3000), '4.50 m²');
    });

    test('판 밖 홀 표시(out): 밖은 out·bad, 안은 둘 다 아님', () {
      final p = platePlan(
        const PlateInput(
          shape: PlateShape.flat,
          t: 3,
          length: 200,
          width: 100,
          holes: [
            PlateHoleSpec(u: 25, v: 25, dia: 11),
            PlateHoleSpec(u: 250, v: 25, dia: 11),
          ],
        ),
      );
      expect([for (final h in p.holes) h.out], [false, true]);
      expect(p.holes[1].bad, isTrue);
    });
  });

  group('화면', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> open(
      WidgetTester tester, {
      Map<String, Object?>? draft,
      Size size = const Size(800, 2400),
    }) async {
      SharedPreferences.setMockInitialValues({
        if (draft != null) PlatePage.draftKeyOf(false): jsonEncode(draft),
      });
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: PlatePage(bend: false, share: (_) async {})),
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

    String text(WidgetTester tester, String k) =>
        tester.widget<TextField>(find.byKey(Key(k))).controller!.text;

    /// 홀 편집 화면에서 mm 자리 → 화면 점(여백: 옆 40, 위 40, 아래 70).
    Offset scr(WidgetTester tester, double x, double y, double w, double h) {
      final r = tester.getRect(find.byKey(const Key('ed_canvas')));
      final s = math.min((r.width - 80) / w, (r.height - 110) / h);
      final cy = 40 + (r.height - 110) / 2;
      return r.topLeft +
          Offset(r.width / 2 + (x - w / 2) * s, cy - (y - h / 2) * s);
    }

    final twoHoles = {
      'sh': 'flat',
      't': '3',
      'len': '200',
      'wid': '100',
      'holes': [
        const PlateHoleSpec(u: 25, v: 25, dia: 13.5).toJson(),
        const PlateHoleSpec(u: 175, v: 25, dia: 13.5).toJson(),
      ],
    };

    testWidgets('26: 모양을 바꿔 판 밖으로 나간 홀은 알리고, 알림에서 지우고 되돌린다', (tester) async {
      await open(tester, draft: twoHoles);
      // 좌표 입력(처음 모양이 두 홀을 다 담음)으로는 알림이 없다
      await tap(tester, 'pl_shape_free');
      expect(find.textContaining('판 밖에 있습니다'), findsNothing);
      await tap(tester, 'pl_shape_flat');
      await tap(tester, 'pl_shape_ring');
      final msg = find.textContaining(RegExp(r'모양을 바꿔 홀 \d+개가 판 밖에 있습니다'));
      expect(msg, findsOneWidget);
      final n = int.parse(
        RegExp(
          r'홀 (\d+)개',
        ).firstMatch(tester.widget<Text>(msg).data!)!.group(1)!,
      );
      expect(n, greaterThan(0));
      await tester.tap(find.text('지우기'));
      await tester.pumpAndSettle();
      expect(find.text('판 밖 홀 $n개를 지웠습니다.'), findsOneWidget);
      await tab(tester, 'result');
      expect(find.textContaining('판 밖으로 나오는 홀'), findsNothing);
      expect(
        find.byKey(const Key('pl_hole_row_1')),
        n == 2 ? findsNothing : findsOneWidget,
      );
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pl_hole_row_2')), findsOneWidget);
    });

    testWidgets('27: 휴대폰 홀 탭에서 홀을 고르면 그림 위에 수정·복사·지우기 줄', (tester) async {
      await open(tester, draft: twoHoles, size: const Size(390, 844));
      await tab(tester, 'holes');
      expect(find.byKey(const Key('ed_fab_add')), findsOneWidget);
      await tester.tapAt(scr(tester, 25, 25, 200, 100));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ed_selbar')), findsOneWidget);
      expect(find.byKey(const Key('ed_fab_add')), findsNothing);
      // 스크롤 없이 보이는 자리(그림 칸 안)
      final canvas = tester.getRect(find.byKey(const Key('ed_canvas')));
      final bar = tester.getRect(find.byKey(const Key('ed_selbar')));
      expect(
        canvas.contains(bar.topLeft) && canvas.contains(bar.bottomRight),
        isTrue,
      );
      expect(find.byKey(const Key('ed_fl_edit')), findsOneWidget);
      await tester.tap(find.byKey(const Key('ed_fl_dup')));
      await tester.pumpAndSettle();
      // 복사한 홀(3번)을 고른다
      expect(
        find.descendant(
          of: find.byKey(const Key('ed_selbar')),
          matching: find.text('홀 3'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('ed_fl_del')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ed_selbar')), findsNothing);
      expect(find.byKey(const Key('ed_fab_add')), findsOneWidget);
      // 고르기 풀기(×)
      await tester.tapAt(scr(tester, 175, 25, 200, 100));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ed_fl_clear')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ed_selbar')), findsNothing);
    });

    testWidgets('31: "홀 넣기" 단추가 판(오른쪽 아래 홀)을 가리지 않는다', (tester) async {
      await open(
        tester,
        draft: {
          'sh': 'flat',
          't': '3',
          'len': '200',
          'wid': '300',
          'holes': [const PlateHoleSpec(u: 190, v: 10, dia: 9).toJson()],
        },
        size: const Size(390, 844),
      );
      await tab(tester, 'holes');
      final fab = tester.getRect(find.byKey(const Key('ed_fab_add')));
      final plate = Rect.fromPoints(
        scr(tester, 0, 300, 200, 300),
        scr(tester, 200, 0, 200, 300),
      );
      expect(fab.overlaps(plate), isFalse);
      // 오른쪽 아래 홀을 누르면 창이 아니라 그 홀을 고른다
      await tester.tapAt(scr(tester, 190, 10, 200, 300));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hi_preview')), findsNothing);
      expect(find.byKey(const Key('ed_selbar')), findsOneWidget);
    });

    testWidgets('28: 꼭짓점 표 - 칸 고치기·추가·지우기·코너, 글로 넣기와 오가기', (tester) async {
      await open(
        tester,
        draft: {'sh': 'free', 't': '3', 'pts': '0,0\n200,0\n200,100\n0,100'},
      );
      expect(find.byKey(const Key('pl_vtable')), findsOneWidget);
      expect(find.byKey(const Key('pl_points')), findsNothing);
      expect(
        [text(tester, 'pl_vx_2'), text(tester, 'pl_vy_3')],
        ['200', '100'],
      );
      expect(sum(tester), endsWith(' 200 × 100 mm'));
      await tester.ensureVisible(find.byKey(const Key('pl_vx_2')));
      await tester.enterText(find.byKey(const Key('pl_vx_2')), '250');
      await tester.pumpAndSettle();
      expect(sum(tester), endsWith(' 250 × 100 mm'));
      // 추가: 마지막 점과 첫 점 사이 가운데(모양은 그대로)
      await tap(tester, 'pl_vadd');
      expect([text(tester, 'pl_vx_5'), text(tester, 'pl_vy_5')], ['0', '50']);
      expect(sum(tester), endsWith(' 250 × 100 mm'));
      await tap(tester, 'pl_vdel_5');
      expect(find.byKey(const Key('pl_vrow_5')), findsNothing);
      // 넷에서 셋까지는 지우고, 셋이면 × 꺼짐
      expect(
        tester.widget<IconButton>(find.byKey(const Key('pl_vdel_4'))).onPressed,
        isNotNull,
      );
      // 코너 칸 → 코너 창
      await tap(tester, 'pl_vc_3');
      await tester.tap(find.byKey(const Key('cd_kind_round')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cd_a')), '10');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cd_ok')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('pl_vc_3')),
          matching: find.text('R10'),
        ),
        findsOneWidget,
      );
      // 글로 넣기: 표 내용이 글로, 글을 고치면 표로 돌아올 때 다시 읽는다
      await tap(tester, 'pl_pts_mode');
      expect(text(tester, 'pl_points'), '0,0\n250,0\n200,100,r10\n0,100');
      await tester.enterText(
        find.byKey(const Key('pl_points')),
        '0,0\n100,0\n100,50',
      );
      await tester.pumpAndSettle();
      await tap(tester, 'pl_pts_mode');
      expect(find.byKey(const Key('pl_vrow_3')), findsOneWidget);
      expect(find.byKey(const Key('pl_vrow_4')), findsNothing);
      expect(
        tester.widget<IconButton>(find.byKey(const Key('pl_vdel_3'))).onPressed,
        isNull,
      );
      expect(sum(tester), endsWith(' 100 × 50 mm'));
    });

    testWidgets('32: 결과 탭 넓이는 cm²', (tester) async {
      await open(tester, draft: twoHoles);
      await tab(tester, 'result');
      // 200 × 100 − φ13.5 둘 = 19,713.7mm² (예전 "0.0197 m²")
      expect(find.text('197 cm² (홀 뺀 것)'), findsOneWidget);
    });
  });

  group('스케치', () {
    final tall = PlateSketch(
      pts: const [
        Offset(0, 0),
        Offset(235, 0),
        Offset(235, 120),
        Offset(120, 120),
        Offset(120, 350),
        Offset(0, 350),
      ],
      ids: const [0, 1, 2, 3, 4, 5],
      nextId: 6,
      dims: const {0: 235, 1: 120, 4: 350},
      frame: const Rect.fromLTWH(-20, -20, 280, 400),
      scaled: true,
      closed: true,
      holes: const [PlateHoleSpec(u: 60, v: 60, dia: 13.5)],
    );

    Future<void> openSketch(WidgetTester tester, PlateSketch s) async {
      SharedPreferences.setMockInitialValues({
        PlateSketchPage.draftKey: jsonEncode(s.toJson()),
      });
      tester.view.physicalSize = const Size(390, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PlateSketchPage(
            parse: (_) async => const PlateSketchResult.fail('없음'),
            pickPhoto: (_) async => null,
            loadPhoto: () async => null,
            savePhoto: (_) async {},
            openCut: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }

    testWidgets('29 → 10-11: 스케치에는 홀 탭이 없고, 그림의 홀(AI가 읽은 홀)은 보내기에 그대로', (
      tester,
    ) async {
      await openSketch(tester, tall);
      expect(find.byKey(const Key('sk_tab_holes')), findsNothing);
      await tester.tap(find.byKey(const Key('sk_tab_send')));
      await tester.pumpAndSettle();
      expect(find.text('1개 · 같이 넘어갑니다'), findsOneWidget);
    });

    testWidgets('30: 변 길이 글이 오른쪽 위 단추 줄 아래, 종이 안에 든다(휴대폰, 치수·그리기 탭)', (
      tester,
    ) async {
      await openSketch(tester, tall);
      for (final t in ['dims', 'draw']) {
        await tester.tap(find.byKey(Key('sk_tab_$t')));
        await tester.pumpAndSettle();
        final canvas = tester.getRect(find.byKey(const Key('sk_canvas')));
        final fitBottom =
            tester.getBottomLeft(find.byKey(const Key('sk_fit'))).dy -
            canvas.top;
        final dynamic painter = tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byKey(const Key('sk_canvas')),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter;
        final Offset Function(Offset) toScreen = painter.toScreen;
        final Rect paper = painter.paper;
        final pr = Rect.fromPoints(
          toScreen(Offset(paper.left, paper.bottom)),
          toScreen(Offset(paper.right, paper.top)),
        );
        final s = painter.sketch as PlateSketch;
        for (var i = 0; i < s.edgeCount; i++) {
          final at = sketchLabelAt(s, i, toScreen);
          if (at == null) continue;
          // 글 상자 반 높이 약 12점
          expect(at.dy - 12, greaterThan(fitBottom), reason: '$t 변 ${i + 1}');
          expect(
            pr.contains(at - const Offset(0, 12)),
            isTrue,
            reason: '$t 변 ${i + 1} 위',
          );
          expect(
            pr.contains(at + const Offset(0, 12)),
            isTrue,
            reason: '$t 변 ${i + 1} 아래',
          );
        }
      }
    });
  });
}
