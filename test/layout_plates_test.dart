// 배치도 좌·우 측판: 간섭 셈, 깊이 저장, 판 바꾸기·저장 모양.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';

PlacedItem item(
  String id,
  double x,
  double y,
  double w,
  double h, {
  double? depth,
}) => PlacedItem(
  id: id,
  name: id,
  position: Offset(x, y),
  width: w,
  height: h,
  depth: depth,
);

void main() {
  group('간섭 셈', () {
    // 중판 600×800. 왼쪽 끝 붙은 계기(가로 100, 깊이 110, 위에서 100~280).
    final main = PlateData(
      width: 600,
      height: 800,
      items: [item('pt', 0, 100, 100, 180, depth: 110)],
    );

    test('좌측판 중판 쪽 끝의 부품이 중판 계기 깊이 안으로 들어오면 부딪힌다', () {
      // 좌측판 300 폭. 오른쪽 끝(중판 쪽)에서 60 안쪽까지 차지, 벽에서 80 튀어나옴, 같은 높이.
      final left = PlateData(
        width: 300,
        height: 800,
        items: [item('tb', 240, 150, 60, 50, depth: 80)],
      );
      final r = checkCabinetClashes(main: main, left: left);
      expect(r.clashes, hasLength(1));
      expect(r.problemIds(kPlateMain), {'pt'});
      expect(r.problemIds(kPlateLeft), {'tb'});
    });

    test('계기 깊이보다 문 쪽이면, 또는 높이가 다르면 안 부딪힌다', () {
      final farFront = PlateData(
        width: 300,
        height: 800,
        // 중판 쪽 끝에서 150~210 → 계기 깊이 110보다 앞
        items: [item('tb', 90, 150, 60, 50, depth: 80)],
      );
      expect(checkCabinetClashes(main: main, left: farFront).clashes, isEmpty);
      final lower = PlateData(
        width: 300,
        height: 800,
        items: [item('tb', 240, 500, 60, 50, depth: 80)],
      );
      expect(checkCabinetClashes(main: main, left: lower).clashes, isEmpty);
    });

    test('중판~벽 틈이 부품 깊이보다 크면 안 부딪힌다', () {
      final left = PlateData(
        width: 300,
        height: 800,
        gap: 90,
        items: [item('tb', 240, 150, 60, 50, depth: 80)],
      );
      expect(checkCabinetClashes(main: main, left: left).clashes, isEmpty);
    });

    test('우측판은 왼쪽 끝이 중판 쪽이다', () {
      final m = PlateData(
        width: 600,
        height: 800,
        items: [item('pt', 500, 100, 100, 180, depth: 110)],
      );
      final right = PlateData(
        width: 300,
        height: 800,
        items: [item('tb', 0, 150, 60, 50, depth: 80)],
      );
      expect(checkCabinetClashes(main: m, right: right).clashes, hasLength(1));
    });

    test('측판 바닥 높이 차를 넣으면 세로 자리가 옮겨진다', () {
      final left = PlateData(
        width: 300,
        height: 800,
        bottomOffset: 400, // 측판이 400 높이 붙음 → 부품이 계기보다 위
        items: [item('tb', 240, 150, 60, 50, depth: 80)],
      );
      expect(checkCabinetClashes(main: main, left: left).clashes, isEmpty);
    });

    test('캐비닛 깊이보다 깊은 부품, 깊이 없는 부품 수', () {
      final m = PlateData(
        width: 600,
        height: 800,
        items: [
          item('deep', 0, 0, 100, 100, depth: 150),
          item('ok', 200, 0, 100, 100, depth: 100),
          item('none', 400, 0, 100, 100),
        ],
      );
      final r = checkCabinetClashes(main: m, cabinetDepth: 120);
      expect(r.tooDeep.map((e) => e.id), ['deep']);
      expect(r.noDepth[kPlateMain], 1);
    });
  });

  test('깊이는 저장했다 읽어도 남고, 예전 목록 부품은 이름으로 깊이를 채운다', () {
    final a = item('a', 0, 0, 104, 181, depth: 109);
    expect(PlacedItem.fromJson(a.toJson()).depth, 109);
    final old = PlacedItem.fromJson({
      'id': 'x',
      'name': 'APT3100 DPT',
      'x': 0,
      'y': 0,
    });
    expect(old.depth, 112);
    final box = PlacedItem.fromJson({'id': 'y', 'name': '차단기', 'x': 0, 'y': 0});
    expect(box.depth, isNull);
  });

  testWidgets('측판을 켜면 탭이 생기고, 판마다 모듈이 따로 있고, 임시 저장에 측판이 남는다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'layout_board_onboarding_shown_v1': true,
      'layout_board_draft_v1': jsonEncode({
        'projectName': '시험',
        'panelWidth': 600,
        'panelHeight': 800,
        'items': [
          {'type': 'item', 'id': 'm1', 'name': '중판 차단기', 'x': 40, 'y': 40},
        ],
        'dimensions': [],
        'sidePlatesOn': true,
        'sidePlates': {
          'left': {
            'panelWidth': 250,
            'panelHeight': 700,
            'items': [
              {'type': 'item', 'id': 'l1', 'name': '좌측 단자대', 'x': 10, 'y': 10},
            ],
            'dimensions': [],
          },
        },
      }),
    });
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: LayoutBoardPage()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이어하기'));
    await tester.pumpAndSettle();

    Finder onBoard(String t) => find.descendant(
      of: find.byType(InteractiveViewer),
      matching: find.text(t),
    );
    expect(find.byKey(const ValueKey('plate_tab_left')), findsOneWidget);
    expect(onBoard('중판 차단기'), findsOneWidget);
    expect(onBoard('좌측 단자대'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('plate_tab_left')));
    await tester.pumpAndSettle();
    expect(onBoard('좌측 단자대'), findsOneWidget);
    expect(onBoard('중판 차단기'), findsNothing);

    // 좌측판을 보는 채로 저장해도 중판은 맨 위 칸, 좌측판은 sidePlates 칸에 들어간다.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('layout_board_draft_v1')!) as Map;
    expect((saved['items'] as List).single['name'], '중판 차단기');
    expect(saved['panelWidth'], 600);
    final left = (saved['sidePlates'] as Map)['left'] as Map;
    expect((left['items'] as List).single['name'], '좌측 단자대');
    expect(left['panelWidth'], 250);
  });
}
