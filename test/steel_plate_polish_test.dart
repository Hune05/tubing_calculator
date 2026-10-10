// 철판 가공 화면 다듬기(10-11, 사용자: "전부 다, 최고의 상용 앱 수준으로"): 철판 전용 측면도(바깥 치수), 홀 위치 치수,
// 야간 판 색, 두께 칸, 모양 카드 한 줄, 홀 넣기 단추·창 순서, 위 막대 이름, 중량 자리수, 스케치 탭 고정.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/theme/field_view.dart';
import 'package:tubing_calculator/src/core/utils/ai_plate_sketch.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_form_parts.dart'
    show fmt;
import 'package:tubing_calculator/src/presentation/steel_plate/plate_calc.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_page.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_painter.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_side_painter.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_sketch_model.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_sketch_page.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_ui.dart';

double _min(Iterable<double> v) => v.reduce(math.min);
double _max(Iterable<double> v) => v.reduce(math.max);

void main() {
  group('측면도 모양', () {
    test('Z자: 면마다 치수 길이 = 넣은 바깥 치수, 높이는 1면 아랫면 ~ 3면 윗면, 3면은 세운 면 바깥면에서', () {
      final g = PlateSideGeometry.of([60, 85, 50], [90, -90], 3, 3)!;
      const legs = [60.0, 85.0, 50.0];
      for (var k = 0; k < 3; k++) {
        final (a, b, _) = g.dims[k];
        expect((b - a).distance, closeTo(legs[k], 1e-9));
      }
      final ys = g.outline.map((p) => p.dy), xs = g.outline.map((p) => p.dx);
      expect(_max(ys) - _min(ys), closeTo(85, 1e-9));
      expect(g.dims[1].$1.dy, closeTo(_min(ys), 1e-9));
      expect(g.dims[1].$2.dy, closeTo(_max(ys), 1e-9));
      // 1면: 판 끝(0)에서 세운 면 오른쪽 바깥면(60), 3면: 세운 면 왼쪽 바깥면(57)에서 50
      expect(_min(xs), closeTo(0, 1e-9));
      expect(_max(xs), closeTo(57 + 50, 1e-9));
      expect(g.bends.length, 2);
      // 치수선은 면 바깥쪽: 1면 아래, 높이 왼쪽, 3면 위
      expect(g.dims[0].$3.dy, lessThan(0));
      expect(g.dims[1].$3.dx, lessThan(0));
      expect(g.dims[2].$3.dy, greaterThan(0));
    });

    test('ㄷ자·ㄱ자: 바깥 크기가 넣은 치수와 같다', () {
      final u = PlateSideGeometry.of([40, 100, 40], [90, 90], 3, 3)!;
      final ux = u.outline.map((p) => p.dx), uy = u.outline.map((p) => p.dy);
      expect(_max(ux) - _min(ux), closeTo(40, 1e-9));
      expect(_max(uy) - _min(uy), closeTo(100, 1e-9));
      final l = PlateSideGeometry.of([50, 70], [90], 4, 6)!;
      final lx = l.outline.map((p) => p.dx), ly = l.outline.map((p) => p.dy);
      expect(_max(lx) - _min(lx), closeTo(50, 1e-9));
      expect(_max(ly) - _min(ly), closeTo(70, 1e-9));
    });

    test('치수 글 각도: 가로는 그대로, 세로는 아래→위로 읽게(화면 위·아래 어느 쪽으로 그어도)', () {
      expect(plateReadableAngle(const Offset(1, 0)), closeTo(0, 1e-9));
      expect(plateReadableAngle(const Offset(-1, 0)), closeTo(0, 1e-9));
      expect(
        plateReadableAngle(const Offset(0, -1)),
        closeTo(-math.pi / 2, 1e-9),
      );
      expect(
        plateReadableAngle(const Offset(0, 1)),
        closeTo(-math.pi / 2, 1e-9),
      );
      expect(
        plateReadableAngle(const Offset(-1, -1)),
        closeTo(math.pi / 4, 1e-9),
      );
    });

    test('모자: 다섯 면, 치수는 발·높이·윗면만 그린다', () {
      final p = platePlan(
        const PlateInput(
          shape: PlateShape.hat,
          t: 3,
          width: 100,
          legs: [30, 50, 60],
        ),
      );
      final sp = PlateSidePainter.of(
        p,
        t: 3,
        text: Colors.black,
        sub: Colors.grey,
        bg: Colors.white,
        hat: true,
      );
      expect(sp.legs, [30, 50, 60, 50, 30]);
      expect(sp.dimFaces, [0, 1, 2]);
      final g = PlateSideGeometry.of(sp.legs, sp.turns, 3, p.rUsed)!;
      final ys = g.outline.map((q) => q.dy);
      expect(_max(ys) - _min(ys), closeTo(50, 1e-9));
    });
  });

  group('그림', () {
    tearDown(() => FieldColors.mode.value = FieldViewMode.normal);

    testWidgets('홀 위치 치수: 홀이 있으면 오른쪽·아래 칸을 더 두고, PNG로 그려도 된다', (tester) async {
      final p = platePlan(
        const PlateInput(
          shape: PlateShape.flat,
          t: 3,
          length: 200,
          width: 100,
          holes: [
            PlateHoleSpec(u: 25, v: 25, dia: 13.5),
            PlateHoleSpec(u: 175, v: 75, dia: 13.5),
            PlateHoleSpec(u: 26, v: 75, dia: 9), // 25와 붙은 자리(글은 둘째 단)
          ],
        ),
      );
      const size = Size(800, 500);
      final plain = PlatePainterLayout.of(p, size)!;
      final dims = PlatePainterLayout.of(p, size, holeDims: true)!;
      expect(dims.s, lessThan(plain.s));
      late Uint8List png, side;
      await tester.runAsync(() async {
        png = await renderPainterPng(
          PlatePainter(
            plan: p,
            text: Colors.black,
            sub: Colors.grey,
            bg: Colors.white,
            holeDims: true,
          ),
          width: 800,
          height: 500,
        );
        final z = platePlan(
          const PlateInput(
            shape: PlateShape.z,
            t: 3,
            width: 70,
            legs: [60, 85, 50],
          ),
        );
        side = await renderPainterPng(
          PlateSidePainter.of(
            z,
            t: 3,
            text: Colors.black,
            sub: Colors.grey,
            bg: Colors.white,
            fontScale: 1.8,
          ),
          width: 1200,
          height: 700,
        );
      });
      expect(png.length, greaterThan(1000));
      expect(side.length, greaterThan(1000));
    });

    test('야간 보기는 어두운 판 색, 나머지는 밝은 판 색', () {
      FieldColors.mode.value = FieldViewMode.night;
      expect(PlateTone.now, same(PlateTone.night));
      FieldColors.mode.value = FieldViewMode.sunlight;
      expect(PlateTone.now, same(PlateTone.light));
      FieldColors.mode.value = FieldViewMode.normal;
      expect(PlateTone.now, same(PlateTone.light));
    });
  });

  group('화면', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> open(
      WidgetTester tester, {
      bool bend = true,
      Size size = const Size(800, 2400),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PlatePage(bend: bend, share: (_) async {}),
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

    testWidgets('휴대폰 폭: 모양 카드가 한 줄(절곡 넷, 레이저 절단 다섯)', (tester) async {
      await open(tester, size: const Size(390, 844));
      final y = tester.getTopLeft(find.byKey(const Key('pl_shape_l'))).dy;
      expect(tester.getTopLeft(find.byKey(const Key('pl_shape_hat'))).dy, y);
      await tester.pumpWidget(const SizedBox());
      await open(tester, bend: false, size: const Size(390, 844));
      final y2 = tester.getTopLeft(find.byKey(const Key('pl_shape_flat'))).dy;
      expect(tester.getTopLeft(find.byKey(const Key('pl_shape_free'))).dy, y2);
      // 휴대폰 첫 화면에 치수 칸이 보인다(재질·두께는 그 아래로)
      expect(find.byKey(const Key('pl_len')), findsOneWidget);
      expect(
        tester.getBottomLeft(find.byKey(const Key('pl_len'))).dy,
        lessThan(844),
      );
    });

    testWidgets('두께: 단추에 없는 3T는 칸 테두리로, 단추를 누르면 그 단추', (tester) async {
      await open(tester);
      PlateNumField field() => tester.widget<PlateNumField>(
        find.ancestor(
          of: find.byKey(const Key('pl_t')),
          matching: find.byType(PlateNumField),
        ),
      );
      bool on(String k) =>
          tester.widget<PlateSegButton>(find.byKey(Key(k))).selected;
      expect(on('pl_t_3.2'), isFalse);
      expect(field().highlight, isTrue);
      await tap(tester, 'pl_t_4.5');
      expect(on('pl_t_4.5'), isTrue);
      expect(field().highlight, isFalse);
    });

    testWidgets('위 요약 줄은 고른 재질 이름(알루미늄을 골라도 철판으로 나오던 것)', (tester) async {
      await open(tester);
      await tap(tester, 'pl_mat_aluminum');
      final sum = tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const Key('pl_sum')),
              matching: find.byType(Text),
            ),
          )
          .data!;
      expect(sum, startsWith('알루미늄 ㄱ자 · 3T'));
    });

    testWidgets('Z자 치수 4칸: 넓으면 한 줄, 휴대폰은 2 × 2(폭이 혼자 남지 않음)', (tester) async {
      await open(tester);
      await tap(tester, 'pl_shape_z');
      double y(String k) => tester.getTopLeft(find.byKey(Key(k))).dy;
      expect(y('pl_wid'), y('pl_l1'));
      await tester.pumpWidget(const SizedBox());
      await open(tester, size: const Size(390, 844));
      await tap(tester, 'pl_shape_z');
      expect(y('pl_l2'), y('pl_l1'));
      expect(y('pl_wid'), y('pl_l3'));
      expect(y('pl_l3'), greaterThan(y('pl_l1')));
    });

    testWidgets('절곡 탭: 측면도는 철판 전용 그림, 일반값은 보기 칸·K값', (tester) async {
      await open(tester);
      await tab(tester, 'bend');
      final side = tester.widget<CustomPaint>(find.byKey(const Key('pl_side')));
      expect(side.painter, isA<PlateSidePainter>());
      expect(find.byKey(const Key('pl_r_view')), findsOneWidget);
      expect(find.byKey(const Key('pl_k')), findsOneWidget);
      expect(find.text('0.33'), findsOneWidget);
      // 직접 넣기면 칸(내R은 지금 값으로 채움)
      await tap(tester, 'pl_bm_manual');
      // K값 보기 칸과 숫자 칸의 높이·자리가 같다(실기기에서 K값만 아래로 내려갔다)
      final rBox = tester.getRect(find.byKey(const Key('pl_r')));
      final kBox = tester.getRect(
        find.descendant(
          of: find.byKey(const Key('pl_k')),
          matching: find.byType(TextField),
        ),
      );
      expect(kBox.top, closeTo(rBox.top, 0.5));
      expect(kBox.height, closeTo(rBox.height, 0.5));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('pl_r')))
            .controller!
            .text,
        '3',
      );
      // 일반값으로 돌아가면 칸을 비운다
      await tap(tester, 'pl_bm_auto');
      expect(find.byKey(const Key('pl_r')), findsNothing);
    });

    testWidgets('결과: 1kg 밑 중량은 소수 셋째 자리, 절곡선·홀은 표', (tester) async {
      SharedPreferences.setMockInitialValues({
        PlatePage.draftKeyOf(true): jsonEncode({
          'sh': 'z',
          'mat': 'steel',
          't': '3',
          'l1': '60',
          'l2': '85',
          'l3': '50',
          'wid': '70',
          'holes': [
            const PlateHoleSpec(face: 2, u: 25, v: 35, dia: 13.5).toJson(),
          ],
        }),
      });
      await open(tester);
      await tab(tester, 'result');
      final p = platePlan(
        const PlateInput(
          shape: PlateShape.z,
          t: 3,
          width: 70,
          legs: [60, 85, 50],
          holes: [PlateHoleSpec(face: 2, u: 25, v: 35, dia: 13.5)],
        ),
      );
      expect(p.kgEach, lessThan(1));
      expect(find.text('개당 약 ${fmt(p.kgEach, 3)}kg'), findsOneWidget);
      expect(find.byKey(const Key('pl_bend_row_2')), findsOneWidget);
      expect(find.byKey(const Key('pl_hole_row_1')), findsOneWidget);
      // 결과 그림에는 홀 위치 치수(그림 칸이 넉넉할 때)
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byKey(const Key('pl_view')),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as PlatePainter;
      expect(painter.holeDims, isTrue);
      await tab(tester, 'shape');
      final shapePainter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byKey(const Key('pl_view')),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as PlatePainter;
      expect(shapePainter.holeDims, isFalse);
    });

    testWidgets('홀 탭: 그림 위 "홀 넣기"로 창, 놓는 방법이 맨 위, 지름 단추 둘째 줄은 볼트', (
      tester,
    ) async {
      await open(tester, bend: false);
      await tab(tester, 'holes');
      await tester.tap(find.byKey(const Key('ed_fab_add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hi_preview')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('hp_single'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('hs_round'))).dy),
      );
      expect(find.text('M12'), findsOneWidget);
      expect(find.text('φ13.5'), findsOneWidget);
    });

    testWidgets('위 막대: "저장"은 이름 단추, 더 보기에 최근 계산 기록·설정', (tester) async {
      await open(tester);
      expect(
        find.descendant(
          of: find.byKey(const Key('pl_saved')),
          matching: find.text('저장'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('pl_more')));
      await tester.pumpAndSettle();
      expect(find.text('철판 가공 설정'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pl_history')));
      await tester.pumpAndSettle();
      expect(find.text('최근 계산 기록'), findsOneWidget);
    });
  });

  group('스케치', () {
    testWidgets('사진을 읽는 사이 고른 탭은 읽고 나서도 그대로(그리기로 되돌아가지 않음)', (tester) async {
      final s = PlateSketch(
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
      );
      SharedPreferences.setMockInitialValues({
        PlateSketchPage.draftKey: jsonEncode(s.toJson()),
      });
      final photo = Completer<Uint8List?>();
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PlateSketchPage(
            parse: (_) async => const PlateSketchResult.fail('없음'),
            pickPhoto: (_) async => null,
            loadPhoto: () => photo.future,
            savePhoto: (_) async {},
            openCut: (_, _) {},
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('sk_tab_dims')));
      await tester.pump();
      photo.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('변 길이 (누르면 고침)'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
