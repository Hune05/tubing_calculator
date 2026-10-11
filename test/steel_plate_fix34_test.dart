// 철판 가공 점검 34~47(10-11, 사용자: "전부 진행해") + 숫자 칸을 누르면 값 전체 고르기(사용자: "수치 변경할 때
// 왜 기준 수치가 안 날아가고 이어 쓰기 되냐").
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/common_widgets/recent_calc_history.dart';
import 'package:tubing_calculator/src/core/utils/ai_plate_sketch.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_form_parts.dart'
    show kElecTabLabels;
import 'package:tubing_calculator/src/presentation/steel_plate/plate_calc.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_dxf.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_page.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_painter.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_settings.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_sketch_model.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_sketch_page.dart';

const _lPts = [
  Offset(0, 0),
  Offset(200, 0),
  Offset(200, 50),
  Offset(80, 50),
  Offset(80, 120),
  Offset(0, 120),
];

void main() {
  group('계산', () {
    test('37: 판 폭을 줄여 절곡선이 판 밖으로 나가면 그 뒤 면 홀은 바깥 자리 그대로(판 밖으로 알림)', () {
      PlatePlan plan(double w) => platePlan(
        PlateInput(
          shape: PlateShape.custom,
          t: 3,
          points: [Offset.zero, Offset(w, 0), Offset(w, 100), Offset(0, 100)],
          bendLines: const [PlateBendSpec(at: 100), PlateBendSpec(at: 250)],
          holes: const [PlateHoleSpec(face: 2, u: 20, v: 50, dia: 11)],
        ),
      );
      final wide = plan(300);
      expect(wide.holes.single.out, isFalse);
      final narrow = plan(200);
      // 바깥 270 → 남은 절곡선(100) 뒤 2면 170, 판(200 − 공제값) 밖
      expect(narrow.holes.single.face, 1);
      expect(narrow.holes.single.u, closeTo(170, 1e-9));
      expect(narrow.holes.single.out, isTrue);
      expect(narrow.problems.any((s) => s.contains('판 밖으로 나오는 홀')), isTrue);
    });

    test('38: 면 치수를 줄여 홀이 옆 면 자리로 넘어가면 "자기 면을 벗어난 홀"', () {
      PlatePlan l(double l1, {int face = 0, double u = 60}) => platePlan(
        PlateInput(
          shape: PlateShape.l,
          t: 3,
          legs: [l1, 50],
          width: 100,
          holes: [PlateHoleSpec(face: face, u: u, v: 50, dia: 9)],
        ),
      );
      expect(l(100).holes.single.bad, isFalse);
      final short = l(40);
      expect(short.holes.single.bad, isTrue);
      expect(short.problems.any((s) => s.contains('자기 면을 벗어난 홀: 1')), isTrue);
      // 없는 면(ㄱ자에 3면)도
      final gone = l(100, face: 2, u: 20);
      expect(gone.problems.any((s) => s.contains('자기 면을 벗어난 홀')), isTrue);
    });

    test('39: 직접 절곡 기준점은 꼭짓점 왼쪽 아래(끝 꼭짓점에 C가 있어도 홀이 어긋나지 않음)', () {
      final p = platePlan(
        const PlateInput(
          shape: PlateShape.custom,
          t: 3,
          points: [
            Offset(0, 50),
            Offset(100, 0),
            Offset(200, 50),
            Offset(100, 100),
          ],
          pointCorners: [
            PlateCorner(PlateCornerKind.chamfer, 10),
            PlateCorner.square,
            PlateCorner.square,
            PlateCorner.square,
          ],
          holes: [PlateHoleSpec(u: 100, v: 50, dia: 11)],
        ),
      );
      expect(p.holes.single.c.dx, closeTo(100, 1e-9));
      expect(p.holes.single.c.dy, closeTo(50, 1e-9));
      expect(p.minX, greaterThan(1)); // C10으로 왼쪽 끝이 잘렸다
    });

    test('47: 꼭짓점 글은 소수 둘째 자리까지, DXF 방향 글은 판이 있는 자리에', () {
      expect(
        platePointsText(const [Offset(15.25, 0), Offset(1.5, 2)], const []),
        '15.25,0\n1.5,2',
      );
      final p = platePlan(
        const PlateInput(
          shape: PlateShape.custom,
          t: 3,
          points: _lPts,
          bendLines: [PlateBendSpec(at: 140)],
        ),
      );
      final lines = plateDxf(p, thickness: 3).split(RegExp(r'\r?\n'));
      final at = lines.indexWhere((s) => s.startsWith('BEND 1 UP'));
      expect(at, greaterThan(0));
      var y = double.nan;
      for (var k = at - 1; k > 0; k--) {
        if (lines[k].trim() == '20') {
          y = double.parse(lines[k + 1]);
          break;
        }
      }
      // 절곡선 자리(x 140)는 판이 0 ~ 50에만 있다
      expect(y, inInclusiveRange(0, 50));
    });

    test('42: 고치기 전 기록(제목 pl_sum)은 읽을 때 "철판 가공"으로', () async {
      final at = DateTime(2026, 10, 11, 15);
      SharedPreferences.setMockInitialValues({
        'k': jsonEncode([
          {
            't': 'pl_sum',
            's': '철판 링 · 3T',
            'at': at.toIso8601String(),
            'k': 'pl_sum',
          },
        ]),
      });
      RecentCalcLog.now = () => at;
      addTearDown(() => RecentCalcLog.now = DateTime.now);
      final log = RecentCalcLog();
      await log.attachStorage('k');
      expect(log.entries.single.title, '철판 가공');
    });

    testWidgets('42: 같은 요약이면 맨 위 기록의 입력을 지금 것으로, 기록 제목은 "철판 가공"', (
      tester,
    ) async {
      expect(kElecTabLabels['pl_sum'], '철판 가공');
      final log = RecentCalcLog();
      Future<void> wait() => tester.pump(const Duration(seconds: 1));
      log.log('철판 가공', '철판 ㄱ자', restoreKey: 'pl_sum', restoreData: 'a');
      await wait();
      log.log('철판 가공', '철판 ㄱ자', restoreKey: 'pl_sum', restoreData: 'b');
      await wait();
      expect(log.entries.length, 1);
      expect(log.entries.first.restoreData, 'b');
    });
  });

  group('화면', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> open(
      WidgetTester tester, {
      bool bend = true,
      Map<String, Object?>? initial,
      Map<String, Object> prefs = const {},
      Size size = const Size(800, 2400),
      Future<void> Function(String)? share,
    }) async {
      SharedPreferences.setMockInitialValues(prefs);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PlatePage(
            bend: bend,
            share: share ?? (_) async {},
            initial: initial,
          ),
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

    String text(WidgetTester tester, String k) =>
        tester.widget<TextField>(find.byKey(Key(k))).controller!.text;

    PlatePainter painter(WidgetTester tester) =>
        tester
                .widget<CustomPaint>(
                  find
                      .descendant(
                        of: find.byKey(const Key('pl_view')),
                        matching: find.byType(CustomPaint),
                      )
                      .first,
                )
                .painter!
            as PlatePainter;

    testWidgets('사용자: 숫자 칸을 누르면 들어 있던 값 전체를 골라 새로 친 숫자로 바뀐다', (tester) async {
      await open(tester, bend: false);
      await tester.tap(find.byKey(const Key('pl_len')));
      await tester.pump();
      await tester.pump();
      final c = tester
          .widget<TextField>(find.byKey(const Key('pl_len')))
          .controller!;
      expect(c.text, '200');
      expect(c.selection, const TextSelection(baseOffset: 0, extentOffset: 3));
    });

    testWidgets('34: 스케치에서 넘겨 받으면 넘어온 두께의 업체 공제값(앞 두께 값이 남지 않음)', (
      tester,
    ) async {
      await open(
        tester,
        prefs: {
          kPlateBendTableKey: jsonEncode({
            '3': {'r': 3, 'bd': 5.2},
            '4.5': {'r': 4.5, 'bd': 7.9},
          }),
          PlatePage.draftKeyOf(true): jsonEncode({
            'sh': 'l',
            't': '3',
            'r': '3',
            'bd': '5.2',
            'bm': 'saved',
          }),
        },
        initial: {
          'sh': 'custom',
          'pts': '0,0\n200,0\n200,100\n0,100',
          't': '4.5',
          'bl': [const PlateBendSpec(at: 60).toJson()],
        },
      );
      await tab(tester, 'result');
      expect(find.textContaining('공제값(90°) 7.9mm'), findsWidgets);
      expect(find.textContaining('(업체 값)'), findsWidgets);
      expect(find.textContaining('5.2mm'), findsNothing);
    });

    testWidgets('35: 세로선 → 가로선이면 장공 방향도 같이 돈다', (tester) async {
      await open(
        tester,
        initial: {
          'sh': 'custom',
          'pts': '0,0\n200,0\n200,100\n0,100',
          't': '3',
          'holes': [
            const PlateHoleSpec(u: 150, v: 50, dia: 11, slot: 30).toJson(),
          ],
        },
      );
      await tap(tester, 'pl_bax_h');
      await tab(tester, 'result');
      final row = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('pl_hole_row_1')),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .join(' | ');
      expect(row, contains('장공 11×30(세로)'));
    });

    testWidgets('36: 꼭짓점 칸에 "1,200"을 넣어도 1200으로 읽는다', (tester) async {
      await open(
        tester,
        bend: false,
        initial: {'sh': 'free', 't': '3', 'pts': '0,0\n200,0\n200,100\n0,100'},
      );
      await tester.ensureVisible(find.byKey(const Key('pl_vx_2')));
      await tester.enterText(find.byKey(const Key('pl_vx_2')), '1,200');
      await tester.pumpAndSettle();
      final p = painter(tester).plan;
      expect(p.flatLength, closeTo(1200, 1e-9));
      expect(p.flatWidth, closeTo(100, 1e-9));
      // 소수 둘째 자리도 그대로
      await tester.enterText(find.byKey(const Key('pl_vy_3')), '100.25');
      await tester.pumpAndSettle();
      await tap(tester, 'pl_pts_mode');
      expect(text(tester, 'pl_points'), contains('200,100.25'));
    });

    testWidgets('41: 직접 절곡 모양 탭은 꼭짓점 표와 같은 방향(가로선도), 꼭짓점을 누르면 코너 창', (
      tester,
    ) async {
      await open(
        tester,
        initial: {
          'sh': 'custom',
          'pts': '0,0\n200,0\n200,120\n0,120',
          't': '3',
          'blh': true,
          'bl': [
            const PlateBendSpec(at: 30).toJson(),
            const PlateBendSpec(at: 90).toJson(),
          ],
          'holes': [
            const PlateHoleSpec(face: 1, u: 30, v: 150, dia: 11).toJson(),
          ],
        },
      );
      // 절곡 탭(전개도)은 절곡선이 세로가 되게 돌린 판
      final flat = painter(tester).plan;
      expect(flat.flatWidth, closeTo(200, 1e-9));
      expect(flat.flatLength, lessThan(120));
      await tab(tester, 'shape');
      final drawn = painter(tester).plan;
      expect(drawn.flatLength, closeTo(200, 1e-9));
      expect(drawn.flatWidth, closeTo(120, 1e-9));
      // 홀: 돌린 판 바깥 (60, 150) → 그린 판 (200 − 150, 60)
      expect(drawn.holes.single.c.dx, closeTo(50, 1e-9));
      expect(drawn.holes.single.c.dy, closeTo(60, 1e-9));
      // 오른쪽 아래 꼭짓점(2번)을 누르면 코너 창
      final r = tester.getRect(find.byKey(const Key('pl_view')));
      final lay = PlatePainterLayout.of(drawn, r.size)!;
      await tester.tapAt(r.topLeft + lay.toScreen(const Offset(200, 0)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cd_preview')), findsOneWidget);
      expect(find.text('꼭짓점 2 코너'), findsOneWidget);
    });

    testWidgets('43: 판 밖 홀 알림 "지우기"는 그때 판 밖이던 홀만(그사이 옮긴 홀은 안 지움)', (
      tester,
    ) async {
      // 링 150(내경 60)에서 (25, 25)·(140, 20)은 판 밖
      final ring = platePlan(
        const PlateInput(
          shape: PlateShape.ring,
          t: 3,
          dia: 150,
          innerDia: 60,
          holes: [
            PlateHoleSpec(u: 25, v: 25, dia: 13.5),
            PlateHoleSpec(u: 140, v: 20, dia: 13.5),
          ],
        ),
      );
      expect([for (final h in ring.holes) h.out], [true, true]);
      expect([ring.minX, ring.minY, ring.maxX, ring.maxY], [0, 0, 150, 150]);
      await open(
        tester,
        bend: false,
        initial: {
          'sh': 'flat',
          't': '3',
          'len': '200',
          'wid': '100',
          'cd': '150',
          'ci': '60',
          'holes': [
            const PlateHoleSpec(u: 25, v: 25, dia: 13.5).toJson(),
            const PlateHoleSpec(u: 140, v: 20, dia: 13.5).toJson(),
          ],
        },
      );
      await tap(tester, 'pl_shape_ring');
      expect(find.text('모양을 바꿔 홀 2개가 판 밖에 있습니다.'), findsOneWidget);
      // 홀 탭에서 2번 홀을 판 안(75, 135)으로 끌어 옮긴다
      await tab(tester, 'holes');
      Offset scr(double x, double y) {
        final r = tester.getRect(find.byKey(const Key('ed_canvas')));
        final s = math.min((r.width - 80) / 150, (r.height - 110) / 150);
        final cy = 40 + (r.height - 110) / 2;
        return r.topLeft +
            Offset(r.width / 2 + (x - 75) * s, cy - (y - 75) * s);
      }

      final g = await tester.startGesture(scr(140, 20));
      await tester.pump(const Duration(milliseconds: 50));
      await g.moveTo(scr(110, 60));
      await tester.pump(const Duration(milliseconds: 50));
      await g.moveTo(scr(75, 135));
      await tester.pump(const Duration(milliseconds: 50));
      await g.up();
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(SnackBar), matching: find.text('지우기')),
      );
      await tester.pumpAndSettle();
      expect(find.text('판 밖 홀 1개를 지웠습니다.'), findsOneWidget);
      await tab(tester, 'result');
      expect(find.byKey(const Key('pl_hole_row_1')), findsOneWidget);
      expect(find.byKey(const Key('pl_hole_row_2')), findsNothing);
      expect(find.textContaining('판 밖으로 나오는 홀'), findsNothing);
    });

    testWidgets('44·45: 카톡 글에 직접 절곡 절곡선 자리·꼭짓점, 보내기·결과 탭 글', (tester) async {
      String? sent;
      await open(
        tester,
        initial: {
          'sh': 'custom',
          'pts': '0,0\n200,0\n200,100\n0,100',
          't': '3',
          'bl': [
            const PlateBendSpec(at: 40).toJson(),
            const PlateBendSpec(at: 140, up: false).toJson(),
          ],
        },
        share: (s) async => sent = s,
      );
      await tab(tester, 'result');
      expect(find.text('홀이 없습니다. 홀 탭에서 넣습니다.'), findsOneWidget);
      await tab(tester, 'send');
      expect(find.text('치수·중량·절곡을 글로 보냅니다'), findsOneWidget);
      await tap(tester, 'pl_send_kakao');
      expect(sent, contains('절곡선(왼쪽 끝에서) 40 UP 90° · 140 DOWN 90°'));
      expect(
        sent,
        contains('꼭짓점(가로,세로, 바깥 치수): 0,0 / 200,0 / 200,100 / 0,100'),
      );
    });

    testWidgets('45: 레이저 절단 보내기 탭은 절곡·BEND 말이 없다', (tester) async {
      await open(tester, bend: false);
      await tab(tester, 'send');
      expect(find.text('치수·중량·홀을 글로 보냅니다'), findsOneWidget);
      expect(find.textContaining('CUT·DIM 층'), findsOneWidget);
      expect(find.textContaining('BEND'), findsNothing);
    });

    testWidgets('47: 직접 넣기에서 내R만 넣으면 "(넣은 내R · K값 일반값)"', (tester) async {
      await open(
        tester,
        prefs: {
          PlatePage.draftKeyOf(true): jsonEncode({
            'sh': 'l',
            't': '3',
            'r': '5',
            'bd': '',
            'bm': 'manual',
          }),
        },
      );
      await tab(tester, 'result');
      expect(find.textContaining('(넣은 내R · K값 일반값)'), findsWidgets);
      expect(find.textContaining('(일반값)'), findsNothing);
    });
  });

  group('스케치', () {
    testWidgets('46: 옆 변 길이 글도 종이 안(가로로 긴 판, 휴대폰)', (tester) async {
      final sk = PlateSketch(
        pts: const [
          Offset(0, 0),
          Offset(400, 0),
          Offset(400, 100),
          Offset(0, 100),
        ],
        ids: const [0, 1, 2, 3],
        nextId: 4,
        dims: const {0: 400, 1: 100},
        frame: const Rect.fromLTWH(-20, -20, 440, 140),
        scaled: true,
        closed: true,
      );
      SharedPreferences.setMockInitialValues({
        PlateSketchPage.draftKey: jsonEncode(sk.toJson()),
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
      await tester.tap(find.byKey(const Key('sk_tab_dims')));
      await tester.pumpAndSettle();
      final dynamic pt = tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byKey(const Key('sk_canvas')),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter;
      final Offset Function(Offset) toScreen = pt.toScreen;
      final Rect paper = pt.paper;
      final pr = Rect.fromPoints(
        toScreen(Offset(paper.left, paper.bottom)),
        toScreen(Offset(paper.right, paper.top)),
      );
      final s = pt.sketch as PlateSketch;
      for (var i = 0; i < s.edgeCount; i++) {
        final at = sketchLabelAt(s, i, toScreen);
        if (at == null) continue;
        // 글 상자 반 너비 약 40점, 반 높이 약 12점
        expect(
          pr.contains(at - const Offset(40, 12)) &&
              pr.contains(at + const Offset(40, 12)),
          isTrue,
          reason: '변 ${i + 1}',
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
