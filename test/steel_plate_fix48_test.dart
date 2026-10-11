// 철판 가공 절곡 판 모서리 따기(10-11, 사용자: "절곡 절단에서는 모서리 따는 기능이 없나?") + 점검 48~60
// (사용자: "전부 진행해").
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_calc.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_dxf_import.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_hole_input.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_page.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_painter.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_settings.dart';
import 'package:tubing_calculator/src/presentation/steel_plate/plate_ui.dart';

/// DXF 글 만들기: [header]가 있으면 HEADER 구역, 나머지는 ENTITIES.
String _dxf(List<List<Object>> ents, {List<Object> header = const []}) {
  final b = StringBuffer();
  void w(Object code, Object v) => b
    ..writeln(code)
    ..writeln(v);
  if (header.isNotEmpty) {
    w(0, 'SECTION');
    w(2, 'HEADER');
    for (var k = 0; k < header.length; k += 2) {
      w(header[k], header[k + 1]);
    }
    w(0, 'ENDSEC');
  }
  w(0, 'SECTION');
  w(2, 'ENTITIES');
  for (final e in ents) {
    for (var k = 0; k < e.length; k += 2) {
      w(e[k], e[k + 1]);
    }
  }
  w(0, 'ENDSEC');
  w(0, 'EOF');
  return b.toString();
}

/// 닫힌 LWPOLYLINE(꼭짓점마다 볼록 값).
List<Object> _poly(List<(double, double, double)> pts) => [
  0, 'LWPOLYLINE', 8, '0', 90, pts.length, 70, 1, //
  for (final (x, y, bulge) in pts) ...[10, x, 20, y, 42, bulge],
];

void main() {
  group('계산', () {
    test('절곡 판 전개도 네 귀 R·따내기, 절곡부에 닿으면 알림', () {
      PlatePlan l(List<PlateCorner> cs) => platePlan(
        PlateInput(
          shape: PlateShape.l,
          t: 3,
          legs: const [50, 50],
          width: 100,
          corners: cs,
        ),
      );
      final plain = l(List.filled(4, PlateCorner.square));
      final r10 = l(
        List.filled(4, const PlateCorner(PlateCornerKind.round, 10)),
      );
      expect(r10.outline.whereType<PlateArc>().length, 4);
      expect(r10.flatLength, closeTo(plain.flatLength, 1e-9));
      // 네 귀 R10만큼(4 × (10² − π·10²/4)) 넓이가 준다
      expect(
        plain.areaMm2 - r10.areaMm2,
        closeTo(4 * (100 - math.pi * 100 / 4), 1e-6),
      );
      expect(r10.problems, isEmpty);
      final big = l([
        const PlateCorner(PlateCornerKind.notch, 60, 20),
        PlateCorner.square,
        PlateCorner.square,
        PlateCorner.square,
      ]);
      expect(
        big.problems.join(),
        contains('왼쪽 아래 코너(따내기 60×20)가 1번 절곡부에 닿습니다'),
      );
    });

    test('49: 직접 절곡 절곡선 창의 판 폭·기준점은 꼭짓점(끝 꼭짓점에 C가 있어도)', () {
      final (pts, w) = plateCustomOuter(
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
            PlateCorner(PlateCornerKind.chamfer, 10),
            PlateCorner.square,
          ],
        ),
      );
      expect(w, closeTo(200, 1e-9));
      expect(pts.map((p) => p.dx).reduce(math.min), greaterThan(5));
    });

    test('50: 홀 넣기 창 미리보기는 홀 크기·장공 길이·있던 홀과 겹침까지 본다', () {
      const cv = PlateHoleCanvas(
        outline: [
          Offset(0, 0),
          Offset(200, 0),
          Offset(200, 100),
          Offset(0, 100),
        ],
        minX: 0,
        minY: 0,
        maxX: 200,
        maxY: 100,
        bendSpans: [(100, 110)],
        existing: [PlateHoleDraft(Offset(50, 50), 10)],
      );
      expect(cv.badAt(const PlateHoleDraft(Offset(5, 50), 20)), isTrue);
      expect(cv.badAt(const PlateHoleDraft(Offset(10, 70), 9)), isFalse);
      expect(
        cv.badAt(const PlateHoleDraft(Offset(82, 80), 11, slot: 40)),
        isTrue,
      );
      expect(cv.badAt(const PlateHoleDraft(Offset(58, 50), 10)), isTrue);
    });

    test('51: 꼭짓점 차례가 엇갈려 꼬인 외곽은 알린다', () {
      const bad = [
        Offset(0, 0),
        Offset(200, 0),
        Offset(50, 150),
        Offset(200, 100),
      ];
      expect(plateSelfCrossing(bad), isNotNull);
      expect(
        plateSelfCrossing(const [
          Offset(0, 0),
          Offset(200, 0),
          Offset(200, 100),
          Offset(0, 100),
        ]),
        isNull,
      );
      final p = platePlan(
        const PlateInput(shape: PlateShape.free, t: 3, points: bad),
      );
      expect(p.problems.join(), contains('외곽선이 꼬입니다'));
    });

    test('52: 업체 공제값 두께 키는 소수 둘째 자리까지', () {
      expect(plateThicknessKey(1.25), '1.25');
      expect(plateThicknessKey(4.5), '4.5');
      expect(plateThicknessKey(3), '3');
    });

    test('58: 판 밖 홀은 절단 길이·피어싱·넓이에 넣지 않는다', () {
      PlatePlan f(List<PlateHoleSpec> hs) => platePlan(
        PlateInput(
          shape: PlateShape.flat,
          t: 3,
          length: 200,
          width: 100,
          holes: hs,
        ),
      );
      final none = f(const []);
      final outside = f(const [PlateHoleSpec(u: 250, v: 50, dia: 10)]);
      expect(outside.pierces, 1);
      expect(outside.cutLength, closeTo(none.cutLength, 1e-9));
      expect(outside.areaMm2, closeTo(none.areaMm2, 1e-9));
    });
  });

  group('DXF 불러오기', () {
    test('55: 거울로 저장된(Z −1) 원은 제자리로 읽는다', () {
      final r = importPlateDxf(
        _dxf([
          _poly(const [(0, 0, 0), (100, 0, 0), (100, 50, 0), (0, 50, 0)]),
          [
            0,
            'CIRCLE',
            8,
            '0',
            10,
            -30,
            20,
            25,
            30,
            0,
            40,
            5,
            210,
            0,
            220,
            0,
            230,
            -1,
          ],
        ]),
      );
      expect(r.holes, hasLength(1));
      expect(r.holes.single.u, 30);
      expect(r.holes.single.v, 25);
    });

    test('56: 반원 러그는 R 코너 둘로(원호 그대로), 다시 계산해도 알림 없음', () {
      final r = importPlateDxf(
        _dxf([
          _poly(const [(0, 0, 0), (100, 0, 0), (100, 60, 1), (0, 60, 0)]),
        ]),
      );
      final rounds = r.corners.where((c) => c.kind == PlateCornerKind.round);
      expect(rounds.length, 2);
      expect(rounds.every((c) => c.a == 50), isTrue);
      final p = platePlan(
        PlateInput(
          shape: PlateShape.free,
          t: 3,
          points: r.points,
          pointCorners: r.corners,
        ),
      );
      expect(p.problems, isEmpty);
      expect(p.outline.whereType<PlateArc>().length, 2);
      expect(p.areaMm2, closeTo(100 * 60 + math.pi * 50 * 50 / 2, 0.5));
    });

    test('57: 인치 도면은 mm로 바꿔 읽고 알린다', () {
      final r = importPlateDxf(
        _dxf(
          [
            _poly(const [(0, 0, 0), (10, 0, 0), (10, 5, 0), (0, 5, 0)]),
          ],
          header: [9, r'$INSUNITS', 70, 1],
        ),
      );
      expect(r.points.map((p) => p.dx).reduce(math.max), closeTo(254, 1e-9));
      expect(r.points.map((p) => p.dy).reduce(math.max), closeTo(127, 1e-9));
      expect(r.notes.join(), contains('인치'));
    });
  });

  group('화면', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> open(
      WidgetTester tester, {
      bool bend = true,
      Map<String, Object?>? initial,
      Map<String, Object> prefs = const {},
      Future<void> Function(String)? share,
    }) async {
      SharedPreferences.setMockInitialValues(prefs);
      tester.view.physicalSize = const Size(800, 2400);
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

    PlatePlan plan(WidgetTester tester) =>
        (tester
                    .widget<CustomPaint>(
                      find
                          .descendant(
                            of: find.byKey(const Key('pl_view')),
                            matching: find.byType(CustomPaint),
                          )
                          .first,
                    )
                    .painter!
                as PlatePainter)
            .plan;

    Future<void> tapCorner(WidgetTester tester, Offset mm) async {
      final r = tester.getRect(find.byKey(const Key('pl_view')));
      final lay = PlatePainterLayout.of(plan(tester), r.size)!;
      await tester.tapAt(r.topLeft + lay.toScreen(mm));
      await tester.pumpAndSettle();
    }

    String text(WidgetTester tester, String k) =>
        tester.widget<TextField>(find.byKey(Key(k))).controller!.text;

    testWidgets('사용자: ㄱ자 모양 탭에 "네 코너 (전개도)", 귀를 누르면 그 귀만, 카톡 글에도', (
      tester,
    ) async {
      String? sent;
      await open(tester, share: (s) async => sent = s);
      expect(find.text('네 코너 (전개도)'), findsOneWidget);
      await tap(tester, 'pl_ck_round');
      expect(plan(tester).outline.whereType<PlateArc>().length, 4);
      // 오른쪽 위 귀를 눌러 C5로
      final p = plan(tester);
      await tester.ensureVisible(find.byKey(const Key('pl_view')));
      await tapCorner(tester, Offset(p.maxX, p.maxY));
      expect(find.text('전개도 오른쪽 위 코너'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cd_kind_chamfer')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cd_a')), '5');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cd_ok')));
      await tester.pumpAndSettle();
      await tab(tester, 'send');
      await tap(tester, 'pl_send_kakao');
      expect(sent, contains('전개도 왼쪽 아래 R10'));
      expect(sent, contains('전개도 오른쪽 위 C5'));
    });

    testWidgets('48: 90° 돌린 평판은 코너 이름·따내기 가로×세로를 그림 방향으로', (tester) async {
      String? sent;
      await open(
        tester,
        bend: false,
        share: (s) async => sent = s,
        prefs: {
          PlatePage.draftKeyOf(false): jsonEncode({
            'sh': 'flat',
            't': '3',
            'len': '200',
            'wid': '100',
            'rot': 1,
            'corners': [
              const PlateCorner(PlateCornerKind.notch, 30, 10).toJson(),
              PlateCorner.square.toJson(),
              PlateCorner.square.toJson(),
              PlateCorner.square.toJson(),
            ],
          }),
        },
      );
      expect(find.byKey(const Key('pl_turned_note')), findsOneWidget);
      // 돌린 판(가로 100 × 세로 200)의 오른쪽 아래 귀
      final p = plan(tester);
      expect(p.flatLength, closeTo(100, 1e-9));
      await tester.ensureVisible(find.byKey(const Key('pl_view')));
      await tapCorner(tester, Offset(p.maxX, p.minY));
      expect(find.text('오른쪽 아래 코너'), findsOneWidget);
      expect([text(tester, 'cd_a'), text(tester, 'cd_b')], ['10', '30']);
      await tester.enterText(find.byKey(const Key('cd_a')), '12');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cd_ok')));
      await tester.pumpAndSettle();
      await tab(tester, 'send');
      await tap(tester, 'pl_send_kakao');
      expect(sent, contains('치수: 100 × 200 · 오른쪽 아래 따내기 12×30'));
      // 그림(돌린 판)에서 따낸 자리: 오른쪽 아래 귀에서 가로 12 × 세로 30
      await tab(tester, 'shape');
      final pts = plateOutlinePoints(plan(tester).outline);
      expect(pts, contains(const Offset(88, 30)));
    });

    testWidgets('52: 1.25T 업체 공제값이 붙는다', (tester) async {
      await open(
        tester,
        prefs: {
          kPlateBendTableKey: jsonEncode({
            '1.25': {'r': 2, 'bd': 3},
          }),
        },
        initial: {'sh': 'l', 't': '1.25'},
      );
      await tab(tester, 'result');
      expect(find.textContaining('(업체 값)'), findsWidgets);
    });

    testWidgets('54: 절곡 판 홀 그리드는 면 시작에서(2면 자리도 5mm 칸)', (tester) async {
      await open(
        tester,
        initial: {'sh': 'l', 't': '3', 'l1': '100', 'l2': '100', 'wid': '100'},
      );
      await tab(tester, 'holes');
      await tap(tester, 'ed_mode_place');
      final p = platePlan(
        const PlateInput(
          shape: PlateShape.l,
          t: 3,
          legs: [100, 100],
          width: 100,
        ),
      );
      final r = tester.getRect(find.byKey(const Key('ed_canvas')));
      final w = p.maxX - p.minX, h = p.maxY - p.minY;
      final s = math.min((r.width - 80) / w, (r.height - 110) / h);
      final cy = 40 + (r.height - 110) / 2;
      await tester.tapAt(
        r.topLeft +
            Offset(r.width / 2 + (152 - w / 2) * s, cy - (51 - h / 2) * s),
      );
      await tester.pumpAndSettle();
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
      final m = RegExp(r'2면 ([0-9.]+) · ([0-9.]+)').firstMatch(row);
      expect(m, isNotNull, reason: row);
      expect(double.parse(m!.group(1)!) % 5, closeTo(0, 1e-6), reason: row);
      expect(double.parse(m.group(2)!) % 5, closeTo(0, 1e-6), reason: row);
    });

    testWidgets('53: 설정에서 나올 수 없는 업체 공제값은 막고 범위를 알린다', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: PlateSettingsPage()));
      await tester.pumpAndSettle();
      for (final (k, v) in const [
        ('ps_bt', '3'),
        ('ps_br', '3'),
        ('ps_bdv', '2'),
      ]) {
        await tester.ensureVisible(find.byKey(Key(k)));
        await tester.enterText(find.byKey(Key(k)), v);
      }
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('ps_bd_add')));
      await tester.tap(find.byKey(const Key('ps_bd_add')));
      await tester.pumpAndSettle();
      expect(find.textContaining('2.58 ~ 7.29 사이'), findsOneWidget);
      expect(find.byKey(const Key('ps_bd_3')), findsNothing);
    });

    testWidgets('59: 큰 글씨에서 값이 칸보다 길면 글자를 줄여 다 보인다(줄 높이는 그대로)', (tester) async {
      Future<double> size(double width) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width,
                    child: PlateNumField(
                      fieldKey: 'f',
                      label: null,
                      readOnly: true,
                      controller: TextEditingController(text: '12345.67'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return tester
            .widget<TextField>(find.byKey(const Key('f')))
            .style!
            .fontSize!;
      }

      expect(await size(400), 18);
      final small = await size(110);
      expect(small, lessThan(18));
      expect(small, greaterThanOrEqualTo(11));
    });
  });
}
