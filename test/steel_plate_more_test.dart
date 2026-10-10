// 철판 가공 상용 앱 비교로 더한 것(10-10): 원형·링, 절단 길이·피어싱, 홀 사이 간격(브릿지)·작은 홀 표시,
// 원판 배치, 재질별 두께 단추, 모양 그림 카드, DXF 불러오기.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_calc.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_dxf.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_page.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_ui.dart';

void main() {
  group('계산', () {
    test('원형: 넓이 πR², 절단 길이 πD, 피어싱 1, DXF는 CIRCLE 하나', () {
      final p = platePlan(
        const PlateInput(shape: PlateShape.circle, t: 3, dia: 200),
      );
      expect(p.ok, isTrue);
      expect(p.flatLength, closeTo(200, 1e-6));
      expect(p.flatWidth, closeTo(200, 1e-6));
      expect(p.areaMm2, closeTo(math.pi * 100 * 100, 1e-6));
      expect(p.cutLength, closeTo(math.pi * 200, 1e-6));
      expect(p.pierces, 1);
      final dxf = plateDxf(p, thickness: 3);
      expect(RegExp(r'CIRCLE\n8\nCUT\n').allMatches(dxf).length, 1);
      expect(dxf, isNot(contains('ARC\n8\nCUT')));
    });

    test('링: 내경은 따로(사용자 홀 번호와 안 섞임), 넓이·절단 길이·피어싱, 내경 안 홀은 못 만듦', () {
      final p = platePlan(
        const PlateInput(
          shape: PlateShape.ring,
          t: 3,
          dia: 200,
          innerDia: 100,
          holes: [
            PlateHoleSpec(u: 100, v: 175, dia: 13.5),
            PlateHoleSpec(u: 100, v: 100, dia: 10), // 내경 안
          ],
        ),
      );
      expect(p.cutouts.single.dia, 100);
      expect(p.cutouts.single.c, const Offset(100, 100));
      expect(p.holes.map((h) => h.label), ['1', '2']);
      expect(p.holes[1].bad, isTrue);
      expect(p.problems.join(), contains('판 밖으로 나오는 홀: 2.'));
      final holeA = math.pi * 13.5 * 13.5 / 4 + math.pi * 25;
      expect(p.areaMm2, closeTo(math.pi * (100 * 100 - 50 * 50) - holeA, 1e-6));
      expect(p.cutLength, closeTo(math.pi * (200 + 100 + 13.5 + 10), 1e-6));
      expect(p.pierces, 4);
      // 링 폭이 두께보다 좁으면 알림
      final thin = platePlan(
        const PlateInput(shape: PlateShape.ring, t: 6, dia: 100, innerDia: 92),
      );
      expect(thin.notes.join(), contains('링 폭(4mm)이 두께보다 좁습니다'));
      final bad = platePlan(
        const PlateInput(shape: PlateShape.ring, t: 3, dia: 100, innerDia: 120),
      );
      expect(bad.problems.join(), contains('내경이 외경보다 크거나 같습니다'));
    });

    test('절단 길이: 사각 외곽 + 홀 + 장공 둘레, 피어싱 = 1 + 홀 수', () {
      final p = platePlan(
        const PlateInput(
          shape: PlateShape.flat,
          t: 3,
          length: 200,
          width: 100,
          holes: [
            PlateHoleSpec(u: 50, v: 50, dia: 10),
            PlateHoleSpec(u: 140, v: 50, dia: 10, slot: 30),
          ],
        ),
      );
      expect(
        p.cutLength,
        closeTo(600 + math.pi * 10 + (2 * 20 + math.pi * 10), 1e-6),
      );
      expect(p.pierces, 3);
    });

    test('홀 사이가 두께보다 좁으면(브릿지) 노랑, 두께보다 작은 홀도 노랑', () {
      final p = platePlan(
        const PlateInput(
          shape: PlateShape.flat,
          t: 3,
          length: 200,
          width: 100,
          holes: [
            PlateHoleSpec(u: 50, v: 50, dia: 10),
            PlateHoleSpec(u: 62, v: 50, dia: 10), // 사이 2mm < 3
            PlateHoleSpec(u: 150, v: 50, dia: 2), // 두께보다 작음
          ],
        ),
      );
      expect(p.holes[0].caution && p.holes[1].caution, isTrue);
      expect(p.notes.join(), contains('홀 사이가 두께(3mm)보다 좁은 곳: 1·2.'));
      expect(p.holes[2].caution, isTrue);
      expect(p.notes.join(), contains('두께보다 작은 홀: 3.'));
      expect(p.ok, isTrue); // 만들 수는 있다(알림만)
    });

    test('원판 배치: 원판 안·서로 간격 지킴, 돌려 놓기·남는 띠 채우기로 더 많이', () {
      final n = plateNest(
        sheetW: 1219,
        sheetH: 2438,
        w: 200,
        h: 100,
        gap: 5,
        partArea: 20000,
      );
      // 바로만 놓으면 5 × 23 = 115, 돌리면 11 × 11 = 121, 남는 띠까지 채우면 더
      expect(n.count, greaterThan(121));
      for (final r in n.parts) {
        expect(r.left, greaterThanOrEqualTo(10 - 1e-9));
        expect(r.bottom, lessThanOrEqualTo(2438 - 10 + 1e-9));
        expect(r.right, lessThanOrEqualTo(1219 - 10 + 1e-9));
        expect({r.width, r.height}, {200.0, 100.0});
      }
      for (var a = 0; a < n.parts.length; a++) {
        for (var b = a + 1; b < n.parts.length; b++) {
          final p = n.parts[a].inflate(2.5 - 1e-6),
              q = n.parts[b].inflate(2.5 - 1e-6);
          expect(p.overlaps(q), isFalse, reason: '$a $b');
        }
      }
      expect(n.usage, closeTo(n.count * 20000 / (1219 * 2438), 1e-9));
      // 원판보다 큰 부품
      expect(plateNest(sheetW: 1219, sheetH: 2438, w: 3000, h: 100).count, 0);
    });
  });

  group('화면', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> open(
      WidgetTester tester, {
      Future<String?> Function()? pickDxf,
    }) async {
      tester.view.physicalSize = const Size(800, 16000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PlatePage(share: (_) async {}, pickDxf: pickDxf),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tap(WidgetTester tester, String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    /// 위 "더 보기" 메뉴의 철판 가공 설정.
    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('pl_more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pl_settings')));
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

    String sum(WidgetTester tester) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(const Key('pl_sum')),
            matching: find.byType(Text),
          ),
        )
        .data!;

    testWidgets('모양 그림 카드: 원형·링 칸, 결과 탭 가공 정보', (tester) async {
      await open(tester);
      await tap(tester, 'pl_shape_circle');
      expect(sum(tester), '철판 원형 · 3T · 150 × 150 mm');
      expect(find.byKey(const Key('pl_cd')), findsOneWidget);
      expect(find.byKey(const Key('pl_ci')), findsNothing);
      await tap(tester, 'pl_shape_ring');
      expect(find.byKey(const Key('pl_ci')), findsOneWidget);
      // 원형·링에는 절곡선이 없다(그림 안내 글)
      expect(find.textContaining('절곡선'), findsNothing);
      await tester.enterText(find.byKey(const Key('pl_cd')), '200');
      await tester.enterText(find.byKey(const Key('pl_ci')), '100');
      await tester.pumpAndSettle();
      expect(sum(tester), endsWith(' 200 × 200 mm'));
      await tester.tap(find.byKey(const Key('pl_tab_result')));
      await tester.pumpAndSettle();
      final cut = find.descendant(
        of: find.byKey(const Key('pl_cut')),
        matching: find.byType(Text),
      );
      expect(
        tester.widgetList<Text>(cut).map((t) => t.data).join(' '),
        contains('${(math.pi * 300 / 1000).toStringAsFixed(2)} m'),
      );
      expect(find.textContaining('1개 2곳 (외곽 1 + 홀·내경)'), findsOneWidget);
    });

    testWidgets('재질별 두께 단추: SUS는 1.5T, 철판은 3.2T', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('pl_t_3.2')), findsOneWidget);
      expect(find.byKey(const Key('pl_t_1.5')), findsNothing);
      await tap(tester, 'pl_mat_stainless');
      expect(find.byKey(const Key('pl_t_1.5')), findsOneWidget);
      expect(find.byKey(const Key('pl_t_3.2')), findsNothing);
      await tap(tester, 'pl_t_1.5');
      expect(sum(tester), 'SUS 평판 · 1.5T · 200 × 100 mm');
      expect(
        tester
            .widget<PlateSegButton>(find.byKey(const Key('pl_t_1.5')))
            .selected,
        isTrue,
      );
    });

    testWidgets('원판 배치: 4×8 기본, 5×10·직접은 설정 화면에서, 수량에 원판 몇 장', (tester) async {
      await open(tester);
      await tester.enterText(find.byKey(const Key('pl_qty')), '300');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pl_tab_result')));
      await tester.pumpAndSettle();
      String nest() => tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('pl_nest')),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .join(' ');
      final n48 = plateNest(
        sheetW: 1219,
        sheetH: 2438,
        w: 200,
        h: 100,
        partArea: 20000,
      );
      expect(nest(), contains('${n48.count}개'));
      expect(nest(), contains('수량 300장에 원판 ${(300 / n48.count).ceil()}장'));
      expect(find.byKey(const Key('pl_nest_view')), findsOneWidget);
      // 원판 바꾸기는 설정 화면에서(작업 화면에는 결과만)
      expect(find.byKey(const Key('pl_sheet_510')), findsNothing);
      await tap(tester, 'pl_nest_settings');
      expect(find.text('철판 가공 설정'), findsOneWidget);
      await tap(tester, 'ps_sheet_510');
      await tester.pageBack();
      await tester.pumpAndSettle();
      final n510 = plateNest(
        sheetW: 1524,
        sheetH: 3048,
        w: 200,
        h: 100,
        partArea: 20000,
      );
      expect(nest(), contains('${n510.count}개'));
      await tap(tester, 'pl_nest_settings');
      await tap(tester, 'ps_sheet_custom');
      await tester.enterText(find.byKey(const Key('ps_sw')), '90');
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(nest(), contains('부품이 원판보다 큽니다'));
    });

    testWidgets('DXF 불러오기: 링 DXF → 링 모양·홀, 알림으로 되돌리기', (tester) async {
      final ring = platePlan(
        const PlateInput(
          shape: PlateShape.ring,
          t: 3,
          dia: 240,
          innerDia: 120,
          holes: [PlateHoleSpec(u: 120, v: 210, dia: 13.5)],
        ),
      );
      await open(tester, pickDxf: () async => plateDxf(ring, thickness: 3));
      await tap(tester, 'pl_dxf_import');
      expect(sum(tester), '철판 링 · 3T · 240 × 240 mm');
      expect(find.textContaining('DXF를 불러왔습니다: 링 Ø240 · 홀 1개'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('pl_ci')))
            .controller!
            .text,
        '120',
      );
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(sum(tester), '철판 평판 · 3T · 200 × 100 mm');
      // 읽을 수 없는 파일
      await tester.pumpWidget(const SizedBox());
      await open(tester, pickDxf: () async => '0\nEOF');
      await tap(tester, 'pl_dxf_import');
      expect(find.textContaining('도형을 찾지 못했습니다'), findsOneWidget);
    });

    testWidgets('홀 입력 창: 격자 6개, 센터 기준으로 바꾸면 같은 자리, 지름 비우면 넣기 꺼짐·이유', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('pl_tab_holes')));
      await tester.pumpAndSettle();
      await tap(tester, 'ed_add_row');
      await tap(tester, 'hp_grid');
      await tester.enterText(find.byKey(const Key('hs_nx')), '3');
      await tester.pumpAndSettle();
      expect(find.text('넣기 (6개)'), findsOneWidget);
      String text(String k) =>
          tester.widget<TextField>(find.byKey(Key(k))).controller!.text;
      // 왼쪽 아래 25·25 → 센터 기준: 200×100 판 센터(100, 50)에서 −75·−25
      await tap(tester, 'hi_ref_center');
      expect(text('hs_x'), '-75');
      expect(text('hs_y'), '-25');
      // 판 밖으로 나가는 홀은 빨강으로 센다(가로 피치 100 → 25·125·225)
      await tester.enterText(find.byKey(const Key('hs_px')), '100');
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('hi_info'))).data,
        contains('판 밖·절곡부 2개'),
      );
      await tester.enterText(find.byKey(const Key('hs_px')), '50');
      // 지름을 비우면 넣기 꺼짐 + 이유
      await tester.enterText(find.byKey(const Key('hs_dia')), '');
      await tester.pumpAndSettle();
      expect(find.text('홀 지름을 넣으십시오.'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('hs_ok'))).onPressed,
        isNull,
      );
      await tap(tester, 'hs_die_1100');
      await tester.tap(find.byKey(const Key('hs_ok')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pl_tab_result')));
      await tester.pumpAndSettle();
      expect(find.textContaining('홀 6개 · φ11 6'), findsOneWidget);
      expect(await row(tester, 'pl_hole_row_1'), '1 | φ11 | 25 | 25');
      expect(await row(tester, 'pl_hole_row_6'), '6 | φ11 | 125 | 75');
    });

    testWidgets('홀 고치기: 같은 창(하나), 장공·세로로 바꾸기', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('pl_tab_holes')));
      await tester.pumpAndSettle();
      await tap(tester, 'ed_add_row');
      await tester.tap(find.byKey(const Key('hs_ok')));
      await tester.pumpAndSettle();
      // 넣은 홀이 골라져 있다 → 위치·크기 수정
      await tap(tester, 'ed_edit');
      expect(find.text('홀 1 수정'), findsOneWidget);
      expect(find.byKey(const Key('hp_single')), findsNothing); // 놓는 방법 고르기 없음
      await tap(tester, 'hs_slot');
      await tap(tester, 'hs_sloty');
      await tester.enterText(find.byKey(const Key('hs_x')), '60');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('hs_ok')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pl_tab_result')));
      await tester.pumpAndSettle();
      expect(
        await row(tester, 'pl_hole_row_1'),
        '1 | 장공 13.5×30(세로) | 60 | 25',
      );
    });

    testWidgets('설정: 두께 단추·자주 쓰는 지름을 바꾸면 작업 화면에 바로, 공제값 넣고 지우기', (
      tester,
    ) async {
      await open(tester);
      await openSettings(tester);
      await tester.enterText(
        find.byKey(const Key('ps_thick_steel')),
        '3, 4.5, 3',
      );
      await tester.enterText(find.byKey(const Key('ps_dias')), '10, 22');
      await tester.enterText(find.byKey(const Key('ps_bt')), '3');
      await tester.enterText(find.byKey(const Key('ps_br')), '3');
      await tester.enterText(find.byKey(const Key('ps_bdv')), '6');
      await tester.pumpAndSettle();
      await tap(tester, 'ps_bd_add');
      expect(find.byKey(const Key('ps_bd_3')), findsOneWidget);
      await tap(tester, 'ps_bd_del_3');
      expect(find.byKey(const Key('ps_bd_3')), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      // 두께 단추: 3T·4.5T만(같은 값 하나)
      expect(find.byKey(const Key('pl_t_3')), findsOneWidget);
      expect(find.byKey(const Key('pl_t_4.5')), findsOneWidget);
      expect(find.byKey(const Key('pl_t_1.6')), findsNothing);
      expect(
        tester.widget<PlateSegButton>(find.byKey(const Key('pl_t_3'))).selected,
        isTrue,
      );
      // 홀 창 지름 단추도 설정 값
      await tester.tap(find.byKey(const Key('pl_tab_holes')));
      await tester.pumpAndSettle();
      await tap(tester, 'ed_add_row');
      expect(find.byKey(const Key('hs_die_1000')), findsOneWidget);
      expect(find.byKey(const Key('hs_die_2200')), findsOneWidget);
      expect(find.byKey(const Key('hs_die_1350')), findsNothing);
      // 작업 화면 홀 탭에 그리드 단추는 없다(설정에서)
      await tap(tester, 'ps_cancel');
      expect(find.byKey(const Key('ed_grid_5')), findsNothing);
    });
  });
}
