// 10-13 배치도 UI 개편: 아래 칸은 모드 한 줄(배치 | 치수 + 가상선)과 도구 단추 다섯 개 한 줄,
// 부품은 "부품 담기" 페이지에서 고르고, 도면 크기·모눈·안내선·측판·배경 사진은 "도면" 설정 페이지에.
// 도면(캔버스)은 그대로다.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';

Map<String, dynamic> draft({String kind = kLayoutKindCabinet}) => {
  'kind': kind,
  'projectName': '1호기 분전반',
  'panelWidth': 600,
  'panelHeight': 800,
  'items': [
    {
      'type': 'item',
      'id': 'a',
      'name': '차단기 A',
      'x': 40,
      'y': 40,
      'w': 80,
      'h': 80,
    },
  ],
  'dimensions': [],
};

Future<void> open(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  String kind = kLayoutKindCabinet,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'layout_board_onboarding_shown_v1': true,
    'layout_board_draft_v1': jsonEncode(draft(kind: kind)),
    ...prefs,
  });
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(home: LayoutBoardPage(resumeDraft: true)),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

Future<void> close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

Finder onBoard(String name) => find.descendant(
  of: find.byType(InteractiveViewer),
  matching: find.text(name),
);

Finder key(String k) => find.byKey(ValueKey(k));

Future<void> tapKey(WidgetTester tester, String k) async {
  await tester.tap(key(k));
  await tester.pumpAndSettle();
}

void main() {
  group('아래 칸', () {
    testWidgets('캐비닛: 모드 두 개와 도구 단추 다섯 개, 모두 40 이상이고 글씨 14 이상', (tester) async {
      await open(tester);
      for (final t in ['배치', '치수']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      for (final k in [
        'parts_button',
        'search_button',
        'note_button',
        'multi_select_button',
        'board_settings_button',
      ]) {
        expect(key(k), findsOneWidget, reason: k);
        final Size s = tester.getSize(key(k));
        expect(s.width, greaterThanOrEqualTo(40), reason: '$k 폭 $s');
        expect(s.height, greaterThanOrEqualTo(40), reason: '$k 높이 $s');
      }
      for (final t in ['부품', '찾기', '메모', '여러 개', '도면']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      // 스키드 전용 단추와 옛 묶음 단추는 없다.
      for (final k in [
        'route_button',
        'iso_button',
        'elec_button',
        'duct_button',
      ]) {
        expect(key(k), findsNothing, reason: k);
      }
      final texts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('palette')),
              matching: find.byType(Text),
            ),
          )
          .toList();
      expect(texts, isNotEmpty);
      for (final t in texts) {
        expect(
          t.style?.fontSize ?? 14,
          greaterThanOrEqualTo(14),
          reason: t.data,
        );
      }
      await close(tester);
    });

    testWidgets('스키드: 부품·경로·입체·여러 개·도면', (tester) async {
      await open(tester, kind: kLayoutKindSkid);
      for (final k in [
        'parts_button',
        'route_button',
        'iso_button',
        'multi_select_button',
        'board_settings_button',
      ]) {
        expect(key(k), findsOneWidget, reason: k);
      }
      for (final k in ['search_button', 'note_button']) {
        expect(key(k), findsNothing, reason: k);
      }
      await close(tester);
    });

    testWidgets('위 막대: 도면 이름 밑에 종류·크기가 붙는다', (tester) async {
      await open(tester);
      expect(find.text('1호기 분전반'), findsOneWidget);
      expect(find.text('600×800mm'), findsOneWidget);
      await close(tester);
    });

    testWidgets('메모 단추를 누르면 도면에 메모가 놓인다', (tester) async {
      await open(tester);
      expect(onBoard('메모'), findsNothing);
      await tapKey(tester, 'note_button');
      expect(onBoard('메모'), findsOneWidget);
      await close(tester);
    });
  });

  group('부품 담기 페이지', () {
    testWidgets('부품 단추 → 묶음 단추 → 고르면 도면에 놓이고 페이지가 닫힌다', (tester) async {
      await open(tester);
      await tapKey(tester, 'parts_button');
      expect(find.text('부품 담기'), findsOneWidget);
      // 캐비닛 묶음 다섯 개 + 내 부품
      for (final k in [
        'mine',
        'duct',
        'elec',
        'instrument',
        'valve',
        'fitting',
      ]) {
        expect(key('parts_cat_$k'), findsOneWidget, reason: k);
      }
      await tapKey(tester, 'parts_cat_elec');
      await tester.tap(key('preset_row_UK 5N 단자대 10P'));
      await tester.pumpAndSettle();
      expect(find.text('부품 담기'), findsNothing);
      expect(onBoard('UK 5N 단자대 10P'), findsOneWidget);
      await close(tester);
    });

    testWidgets('찾기 단추로 열면 찾기 칸부터, 글을 넣으면 모든 묶음에서 거른다', (tester) async {
      await open(tester);
      await tapKey(tester, 'search_button');
      expect(find.text('부품 담기'), findsOneWidget);
      await tester.enterText(key('preset_search'), 'uk 5n');
      await tester.pumpAndSettle();
      expect(key('preset_row_UK 5N 단자대 10P'), findsOneWidget);
      // 거를 때는 묶음 단추 줄이 숨는다.
      expect(key('parts_cat_elec'), findsNothing);
      await tester.enterText(key('preset_search'), '없는부품zzz');
      await tester.pumpAndSettle();
      expect(key('preset_search_empty'), findsOneWidget);
      await close(tester);
    });

    testWidgets('피팅 묶음에서만 튜브 크기 단추가 나오고, 고른 크기만 보인다', (tester) async {
      await open(tester);
      await tapKey(tester, 'parts_button');
      expect(key('fitting_size_1/2"'), findsNothing);
      await tapKey(tester, 'parts_cat_fitting');
      expect(key('fitting_size_1/2"'), findsOneWidget);
      expect(find.textContaining('1/2"'), findsWidgets);
      await tapKey(tester, 'fitting_size_1/4"');
      expect(find.textContaining('1/4"'), findsWidgets);
      await close(tester);
    });

    testWidgets('내 부품에는 신규 부품·메모와 내 프리셋이 있고, 신규 부품을 고르면 놓인다', (tester) async {
      await open(tester);
      await tapKey(tester, 'parts_button');
      await tapKey(tester, 'parts_cat_mine');
      expect(key('preset_row_신규 부품'), findsOneWidget);
      expect(key('preset_row_메모'), findsOneWidget);
      await tapKey(tester, 'preset_row_신규 부품');
      expect(onBoard('신규 부품'), findsOneWidget);
      await close(tester);
    });

    testWidgets('스키드는 형강·JB·부속 묶음만', (tester) async {
      await open(tester, kind: kLayoutKindSkid);
      await tapKey(tester, 'parts_button');
      for (final k in ['skid_steel', 'skid_jb', 'skid_fitting']) {
        expect(key('parts_cat_$k'), findsOneWidget, reason: k);
      }
      for (final k in ['duct', 'elec', 'instrument', 'valve', 'fitting']) {
        expect(key('parts_cat_$k'), findsNothing, reason: k);
      }
      await close(tester);
    });
  });

  group('도면 설정 페이지', () {
    testWidgets('캐비닛: 크기·모눈·안내선·측판·배경 줄이 있고, 모눈은 누르면 바로 바뀐다', (tester) async {
      await open(tester);
      await tapKey(tester, 'board_settings_button');
      expect(find.text('도면 설정'), findsOneWidget);
      for (final k in [
        'settings_size',
        'grid_snap',
        'snap_guides',
        'toggle_side_plates',
        'settings_background',
      ]) {
        expect(key(k), findsOneWidget, reason: k);
      }
      expect(key('toggle_hidden_parts'), findsNothing);
      // 기본 5mm → 10mm → 끔
      expect(find.text('모눈 맞춤: 5mm'), findsOneWidget);
      await tapKey(tester, 'grid_snap');
      expect(find.text('모눈 맞춤: 10mm'), findsOneWidget);
      await tapKey(tester, 'grid_snap');
      expect(find.text('모눈 맞춤: 끔'), findsOneWidget);
      // 돌아오면 도면이 그대로다.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(onBoard('차단기 A'), findsOneWidget);
      await close(tester);
    });

    testWidgets('크기 줄을 누르면 페이지가 닫히고 도면 위에서 크기 창이 열린다', (tester) async {
      await open(tester);
      await tapKey(tester, 'board_settings_button');
      await tapKey(tester, 'settings_size');
      expect(find.text('도면 설정'), findsNothing);
      // 외함 크기 창(폭·높이 칸)
      expect(
        find.byWidgetPredicate(
          (w) => w is TextField && w.controller?.text == '600',
        ),
        findsOneWidget,
      );
      await close(tester);
    });

    testWidgets('스키드: 가려진 부품 보이기 줄이 있고 측판 줄은 없다', (tester) async {
      await open(tester, kind: kLayoutKindSkid);
      await tapKey(tester, 'board_settings_button');
      expect(key('toggle_hidden_parts'), findsOneWidget);
      expect(key('toggle_side_plates'), findsNothing);
      await close(tester);
    });

    testWidgets('더보기의 "도면 설정" 줄로도 열린다', (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('더보기'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'board_settings_row');
      expect(find.text('도면 설정'), findsOneWidget);
      await close(tester);
    });
  });
}
