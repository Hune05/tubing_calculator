// 배치도 P2·P3(2026-09-23 저녁): 태그·각도 칸, 경로 끝 부품, PDF 표준 축척, 기준점 치수, 레일 붙이기.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

PlacedItem _jb(String id, Offset pos, {double? elev = 800}) => PlacedItem(
  id: id,
  name: '정션박스 $id',
  position: pos,
  width: 200,
  height: 200,
  elevation: elev,
);

void main() {
  group('태그·각도 칸', () {
    test('저장했다 읽어도 남고, 없던 부품은 null', () {
      final a = PlacedItem(
        id: 'a',
        name: '3051CD DPT',
        position: Offset.zero,
        tag: ' PT-101 ',
        rotation: 270,
      );
      final j = a.toJson();
      expect(j['tag'], 'PT-101');
      expect(j['rot'], 270);
      final back = PlacedItem.fromJson(j);
      expect(back.tag, 'PT-101');
      expect(back.rotation, 270);
      expect(back.quarterTurns, 3);
      expect(back.label, 'PT-101 3051CD DPT');

      final old = PlacedItem.fromJson({
        'id': 'b',
        'name': 'x',
        'x': 0,
        'y': 0,
        'w': 10,
        'h': 10,
      });
      expect(old.tag, isNull);
      expect(old.rotation, isNull);
      expect(old.quarterTurns, isNull);
      expect(old.label, 'x');
      // 빈 태그는 저장하지 않는다.
      expect(
        PlacedItem(
          id: 'c',
          name: 'y',
          position: Offset.zero,
          tag: '  ',
        ).toJson().containsKey('tag'),
        isFalse,
      );
    });
  });

  group('경로 끝 부품', () {
    ConduitRoute route() => ConduitRoute(
      id: 'r',
      name: 'A',
      startItemId: 's',
      startDir: 90,
      bends: [
        {'length': 1000, 'angle': 90, 'rotation': 0},
      ],
      endItemId: 'e',
    );

    test('마지막 줄이 끝 부품 가운데까지 자동으로 이어지고 길이 합에 들어간다', () {
      // 시작 JB 가운데 (100, 200, 800) → 오른쪽 1000 → 위로 꺾임. 끝 JB 가운데 (1100, 200), 높이 1800.
      final plan = [
        _jb('s', const Offset(0, 100)),
        _jb('e', const Offset(1000, 100), elev: 1800),
      ];
      final r = route();
      final end = r.endRun(plan)!;
      expect(end.length, closeTo(1000, 1e-6));
      expect(end.miss, closeTo(0, 1e-6));
      final p = r.points(plan);
      expect(p.length, 3);
      expect(p.last, vm.Vector3(1100, 200, 1800));
      expect(r.totalLengthWith(plan), closeTo(2000, 1e-6));
      expect(r.endWarnings(plan), isEmpty);
    });

    test('끝 부품이 방향에서 비켜 나 있으면 경고, 없으면 없다는 경고', () {
      final plan = [
        _jb('s', const Offset(0, 100)),
        _jb('e', const Offset(1050, 100), elev: 1800),
      ];
      final r = route();
      expect(r.endRun(plan)!.miss, closeTo(50, 1e-6));
      expect(r.endWarnings(plan).single, contains('50mm 비켜'));
      expect(
        r.endWarnings([_jb('s', const Offset(0, 100))]).single,
        contains('없습니다'),
      );
      // 끝 부품이 없는 경로는 예전과 같다.
      final plain = route()..endItemId = null;
      expect(plain.points(plan).length, 2);
      expect(plain.endWarnings(plan), isEmpty);
    });

    test('저장했다 읽어도 끝 부품이 남는다', () {
      final back = ConduitRoute.fromJson(
        jsonDecode(jsonEncode(route().toJson())) as Map<String, dynamic>,
      );
      expect(back.endItemId, 'e');
      expect(ConduitRoute.fromJson({'id': 'x', 'bends': []}).endItemId, isNull);
    });
  });

  test('PDF 표준 축척: 들어가는 가장 큰 축척을 고른다', () {
    // A4 세로 여백 뺀 자리 ≈ 527 × 640pt. 600×800mm 판은 1:5(340×453pt).
    expect(pdfStandardScale(600, 800, 527, 640), 5);
    // 작은 판은 1:1, 2400×1200 스키드는 A4 가로(773×470)에서 1:10.
    expect(pdfStandardScale(100, 100, 527, 640), 1);
    expect(pdfStandardScale(2400, 1200, 773, 470), 10);
    // 말도 안 되게 큰 판은 1:1000.
    expect(pdfStandardScale(1e6, 1e6, 527, 640), 1000);
  });

  Future<void> pumpBoard(
    WidgetTester tester,
    Map<String, dynamic> draft, {
    String kind = kLayoutKindCabinet,
  }) async {
    SharedPreferences.setMockInitialValues({
      'layout_board_onboarding_shown_v1': true,
      'layout_board_draft_v1': jsonEncode(draft),
    });
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: LayoutBoardPage(initialKind: kind, resumeDraft: true)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  testWidgets('DIN 레일 부품을 레일 위로 끌어 놓으면 세로 자리가 레일 가운데에 맞는다', (tester) async {
    await pumpBoard(tester, {
      'kind': kLayoutKindCabinet,
      'projectName': 'TEST',
      'panelWidth': 600.0,
      'panelHeight': 400.0,
      'items': [
        {
          'type': 'item',
          'id': 'rail',
          'name': 'DIN 레일 35×7.5',
          'x': 50,
          'y': 200,
          'w': 400,
          'h': 35,
          'shape': 'el_rail',
        },
        {
          'type': 'item',
          'id': 'mcb',
          'name': 'BKN 소형 차단기 2P',
          'x': 100,
          'y': 20,
          'w': 35,
          'h': 81,
          'shape': 'el_mcb:2',
        },
      ],
      'dimensions': <Map<String, dynamic>>[],
    });
    final state = tester.state(find.byType(LayoutBoardPage)) as dynamic;
    // 차단기를 아래로 165 끌어 가운데(y 60.5 → 225.5)가 레일 가운데(217.5)에서 40 안에 오게 한다.
    final Finder mcb = find.byKey(const ValueKey('mcb'));
    expect(mcb, findsOneWidget);
    // 화면 배율(판 600mm가 폰 폭에 맞춰짐)을 셈해 도면 165mm만큼 끈다.
    final Offset c = tester.getCenter(mcb);
    final Offset railC = tester.getCenter(find.byKey(const ValueKey('rail')));
    final double pxPerMm = (railC.dy - c.dy) / (217.5 - 60.5);
    final g = await tester.startGesture(c);
    // 처음 몇 px는 터치 여유로 먹혀서 조금 더 끈다(레일 가운데 ±40 안이면 붙는다).
    for (int i = 0; i < 12; i++) {
      await g.moveBy(Offset(0, 16.5 * pxPerMm));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    final plates = state.debugPlates() as Map<String, Map<String, dynamic>>;
    final items = (plates['main']!['items'] as List).cast<Map>();
    final m = items.firstWhere((e) => e['id'] == 'mcb');
    // 레일 가운데 217.5 − 81/2 = 177.
    expect((m['y'] as num).toDouble(), closeTo(177, 0.5));
    expect((m['x'] as num).toDouble(), closeTo(100, 0.5));
  });

  testWidgets('편집창에 태그 칸이 있고 적으면 부품에 남는다', (tester) async {
    await pumpBoard(tester, {
      'kind': kLayoutKindCabinet,
      'projectName': 'TEST',
      'panelWidth': 600.0,
      'panelHeight': 400.0,
      'items': [
        {
          'type': 'item',
          'id': 'a',
          'name': '3051CD DPT',
          'x': 100,
          'y': 50,
          'w': 104,
          'h': 181,
          'shape': 'rm_coplanar',
        },
      ],
      'dimensions': <Map<String, dynamic>>[],
    });
    await tester.tap(find.byKey(const ValueKey('a')));
    await tester.pumpAndSettle();
    final Finder tagField = find.byKey(const ValueKey('item_tag_field'));
    expect(tagField, findsOneWidget);
    await tester.enterText(tagField, 'PT-101');
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(LayoutBoardPage)) as dynamic;
    final plates = state.debugPlates() as Map<String, Map<String, dynamic>>;
    final items = (plates['main']!['items'] as List).cast<Map>();
    expect(items.single['tag'], 'PT-101');
    // 돌리기 단추를 누르면 각도 칸이 90이 되고 가로·세로가 바뀐다.
    await tester.tap(find.text('90° 회전'));
    await tester.pumpAndSettle();
    final again = (state.debugPlates()['main']!['items'] as List).cast<Map>();
    expect(again.single['rot'], 90);
    expect(again.single['w'], 181);
    expect(again.single['h'], 104);
  });
  testWidgets('PDF 만들기 창: 폰 폭에서 안 넘치고 취소하면 그대로', (tester) async {
    await pumpBoard(tester, {
      'kind': kLayoutKindCabinet,
      'projectName': 'TEST',
      'panelWidth': 600.0,
      'panelHeight': 400.0,
      'items': [
        {
          'type': 'item',
          'id': 'a',
          'name': 'x',
          'x': 10,
          'y': 10,
          'w': 50,
          'h': 50,
        },
      ],
      'dimensions': <Map<String, dynamic>>[],
    });
    await tester.tap(find.byIcon(Icons.save_alt_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('QR 도면 PDF로 공유'));
    await tester.pumpAndSettle();
    expect(find.text('PDF 만들기'), findsOneWidget);
    expect(find.byKey(const ValueKey('pdf_paper_A3')), findsOneWidget);
    expect(find.byKey(const ValueKey('pdf_land_true')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pdf_paper_A3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('PDF 만들기'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
