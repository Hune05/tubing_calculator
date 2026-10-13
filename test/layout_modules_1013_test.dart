// 10-13 배치도 모듈 개선: 부품 찾기(검색·최근·즐겨찾기), 편집 창 정리(더보기), 조작(안내선에 붙기·
// 겹침 막기 어디서나·가운데 기준 회전·길게 눌러 여러 개 선택).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';

Map<String, dynamic> item(
  String id,
  String name,
  double x,
  double y, {
  double w = 80,
  double h = 80,
}) => {'type': 'item', 'id': id, 'name': name, 'x': x, 'y': y, 'w': w, 'h': h};

Map<String, dynamic> draft(List<Map<String, dynamic>> items) => {
  'kind': kLayoutKindCabinet,
  'projectName': 'TEST',
  'panelWidth': 600,
  'panelHeight': 800,
  'items': items,
  'dimensions': [],
};

Future<GlobalKey<NavigatorState>> open(
  WidgetTester tester,
  List<Map<String, dynamic>> items, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'layout_board_onboarding_shown_v1': true,
    'layout_board_draft_v1': jsonEncode(draft(items)),
    ...prefs,
  });
  tester.view.physicalSize = const Size(390, 844) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final nav = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: nav,
      home: const LayoutBoardPage(resumeDraft: true),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
  return nav;
}

Future<void> close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

Finder onBoard(String name) => find.descendant(
  of: find.byType(InteractiveViewer),
  matching: find.text(name),
);

List<Map> items(WidgetTester tester) {
  final state = tester.state(find.byType(LayoutBoardPage)) as dynamic;
  return (state.debugPlates()['main']!['items'] as List).cast<Map>();
}

Rect rectOf(Map m) => Rect.fromLTWH(
  (m['x'] as num).toDouble(),
  (m['y'] as num).toDouble(),
  (m['w'] as num).toDouble(),
  (m['h'] as num).toDouble(),
);

void main() {
  group('부품 찾기', () {
    testWidgets('찾기 단추 → 이름으로 거르고, 누르면 놓이고 최근 쓴 부품에 남는다', (tester) async {
      final nav = await open(tester, [item('a', '차단기 A', 40, 40)]);
      await tester.tap(find.byKey(const ValueKey('search_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('preset_search')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('preset_search')),
        'uk 5n',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('preset_row_UK 5N 단자대 10P')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('preset_row_UK 2.5N 단자대 10P')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('preset_row_UK 5N 단자대 10P')));
      await tester.pumpAndSettle();
      // 놓이면서 편집 창이 열린다.
      expect(find.text('부품 편집'), findsOneWidget);
      expect(items(tester).map((m) => m['name']), contains('UK 5N 단자대 10P'));
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('layout_recent_parts_v1'), ['UK 5N 단자대 10P']);
      // 다시 열면 최근 쓴 부품 묶음에 있다.
      await tester.tap(find.byKey(const ValueKey('elec_button')));
      await tester.pumpAndSettle();
      expect(find.text('최근 쓴 부품'), findsOneWidget);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      await close(tester);
    });

    testWidgets('별을 누르면 즐겨찾기 묶음에 올라오고 폰에 남는다, 맞는 게 없으면 안내', (tester) async {
      final nav = await open(tester, [item('a', '차단기 A', 40, 40)]);
      await tester.tap(find.byKey(const ValueKey('elec_button')));
      await tester.pumpAndSettle();
      expect(find.text('즐겨찾기'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('preset_fav_UK 2.5N 단자대 10P')).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('즐겨찾기'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('layout_fav_parts_v1'), ['UK 2.5N 단자대 10P']);
      await tester.enterText(
        find.byKey(const ValueKey('preset_search')),
        '없는부품',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('preset_search_empty')), findsOneWidget);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      await close(tester);
    });
  });

  group('편집 창', () {
    testWidgets('자주 쓰는 단추만 보이고, 더보기를 누르면 위치·앞뒤·잠금·프리셋이 나온다', (tester) async {
      final nav = await open(tester, [item('a', '차단기 A', 40, 40)]);
      await tester.tap(onBoard('차단기 A'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rotate_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('duplicate_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('delete_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('item_tag_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('front_button')), findsNothing);
      expect(find.text('X 좌표 (mm)'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('item_more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('front_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('lock_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('preset_save_button')), findsOneWidget);
      expect(find.text('X 좌표 (mm)'), findsOneWidget);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      await close(tester);
    });

    testWidgets('위치 숫자로 옮길 때 다른 부품과 겹치면 옮기지 않는다', (tester) async {
      final nav = await open(tester, [
        item('a', '차단기 A', 40, 40),
        item('b', '단자대', 300, 60), // 차단기 A와 같은 높이
      ]);
      await tester.tap(onBoard('단자대'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('item_more')));
      await tester.pumpAndSettle();
      final x = find.widgetWithText(TextField, '300').first;
      await tester.enterText(x, '60');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      final b = items(tester).firstWhere((m) => m['id'] == 'b');
      expect(b['x'], 300); // 차단기 A(40~120)와 겹치는 60으로는 안 간다
      // keepWords가 글자 사이에 안 보이는 이음표를 넣으므로 그것을 빼고 견준다.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data ?? '').replaceAll(RegExp(r'[⁠​﻿]'), '').contains('겹칩니다'),
        ),
        findsOneWidget,
      );
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      await close(tester);
    });
  });

  group('조작', () {
    testWidgets('90° 회전은 가운데를 그대로 둔다', (tester) async {
      final nav = await open(tester, [
        item('a', '차단기 A', 100, 100, w: 60, h: 100),
      ]);
      await tester.tap(onBoard('차단기 A'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rotate_button')));
      await tester.pumpAndSettle();
      final a = items(tester).single;
      expect(a['w'], 100);
      expect(a['h'], 60);
      // 가운데(130,150) 그대로: 왼쪽 위는 (80,120).
      expect(a['x'], 80);
      expect(a['y'], 120);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      await close(tester);
    });

    testWidgets('복제는 포개지 않고 옆 빈자리에 놓는다', (tester) async {
      await open(tester, [
        item('a', '차단기 A', 100, 100),
        item('b', '단자대', 185, 100), // 바로 오른쪽이 막혀 있다
      ]);
      await tester.tap(onBoard('차단기 A'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('duplicate_button')));
      await tester.pumpAndSettle();
      final all = items(tester);
      expect(all, hasLength(3));
      for (var i = 0; i < all.length; i++) {
        for (var j = i + 1; j < all.length; j++) {
          expect(
            rectOf(all[i]).overlaps(rectOf(all[j])),
            isFalse,
            reason: '$i-$j',
          );
        }
      }
      await close(tester);
    });

    testWidgets('목록에서 골라 놓을 자리가 막혀 있으면 옆 빈자리로 간다', (tester) async {
      // 600×800 판 가운데를 큰 부품이 막고 있다.
      final nav = await open(tester, [
        item('big', '큰 부품', 150, 250, w: 300, h: 300),
      ]);
      await tester.tap(find.byKey(const ValueKey('elec_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('preset_row_UK 5N 단자대 10P')));
      await tester.pumpAndSettle();
      final all = items(tester);
      expect(all, hasLength(2));
      expect(rectOf(all[0]).overlaps(rectOf(all[1])), isFalse);
      // 빈자리 찾기 자체: 큰 부품 한가운데를 원하면 바로 옆으로 비킨다.
      final state = tester.state(find.byType(LayoutBoardPage)) as dynamic;
      final Offset spot = state.debugFreeSpotNear(
        all[1]['id'],
        const Offset(300, 400),
      );
      expect(spot, isNot(const Offset(300, 400)));
      final Rect moved = Rect.fromLTWH(
        spot.dx,
        spot.dy,
        rectOf(all[1]).width,
        rectOf(all[1]).height,
      );
      expect(moved.overlaps(rectOf(all[0])), isFalse);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      await close(tester);
    });

    testWidgets('부품을 길게 누르면 여러 개 선택이 켜진다', (tester) async {
      await open(tester, [
        item('a', '차단기 A', 40, 40),
        item('b', '단자대', 300, 300),
      ]);
      final state = tester.state(find.byType(LayoutBoardPage)) as dynamic;
      expect(state.debugMultiSelected(), isEmpty);
      await tester.longPress(onBoard('차단기 A'));
      await tester.pumpAndSettle();
      expect(state.debugMultiSelected(), {'a'});
      // 다음 부품은 그냥 눌러도 같이 골라진다(편집 창이 뜨지 않는다).
      await tester.tap(onBoard('단자대'));
      await tester.pumpAndSettle();
      expect(state.debugMultiSelected(), {'a', 'b'});
      expect(find.text('부품 편집'), findsNothing);
      await close(tester);
    });

    testWidgets('안내선에 붙기: 옆 부품 왼쪽 선과 6mm 안이면 그 자리로, 더보기에서 끄면 그대로', (
      tester,
    ) async {
      await open(tester, [
        item('a', '차단기 A', 40, 40),
        item('b', '단자대', 300, 300),
      ]);
      final state = tester.state(find.byType(LayoutBoardPage)) as dynamic;
      expect(
        state.debugSnapAlignment('b', const Offset(44, 300)),
        const Offset(40, 300),
      );
      expect(
        state.debugSnapAlignment('b', const Offset(60, 300)),
        const Offset(60, 300),
      );
      // 더보기 → 안내선에 붙이기 끄기 → 폰에 남고 붙지 않는다.
      await tester.tap(find.byTooltip('더보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('snap_guides')));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('layout_snap_guides_v1'), false);
      expect(
        state.debugSnapAlignment('b', const Offset(44, 300)),
        const Offset(44, 300),
      );
      await close(tester);
    });
  });
}
