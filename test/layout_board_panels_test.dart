// 작업 배치도 넓은 화면: 오른쪽 "모듈 편집" 칸 접기/펴기와 왼쪽 라이브러리(덕트·계기 제조사) 묶음 접기/펴기.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';

const Size kTablet = Size(1024, 768); // 도면 폭 444: 오른쪽 칸이 펴진 채로 시작
const Size kTall = Size(924, 1480); // 14.6인치 세로: 도면 폭 344: 접힌 채로 시작

void setSize(WidgetTester tester, Size s) {
  tester.view.physicalSize = s * 2;
  tester.view.devicePixelRatio = 2;
}

Map<String, dynamic> draft() => {
  'projectId': null,
  'projectName': '1호기 분전반',
  'panelWidth': 600,
  'panelHeight': 800,
  'items': [
    {
      'type': 'item',
      'id': 'd',
      'name': '단자대',
      'x': 200,
      'y': 200,
      'w': 160,
      'h': 60,
    },
  ],
  'dimensions': [],
};

Future<void> pumpBoard(WidgetTester tester, {Size size = kTablet}) async {
  setSize(tester, size);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: LayoutBoardPage()));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
  if (find.text('이어하기').evaluate().isNotEmpty) {
    await tester.tap(find.text('이어하기'));
    await tester.pumpAndSettle();
  }
}

Future<void> disposeBoard(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

final _brand = kInstrumentPresets.keys.first;
final _brandKey = Key('layout_palette_group_inst:$_brand');
final _firstPreset = kInstrumentPresets[_brand]!.first.name;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'layout_board_onboarding_shown_v1': true,
      'layout_board_draft_v1': jsonEncode(draft()),
    });
  });

  group('오른쪽 모듈 편집 칸', () {
    testWidgets('도면이 충분히 넓으면 펴진 채로 시작하고, 접으면 띠만 남고 다시 펴진다', (tester) async {
      await pumpBoard(tester);
      expect(find.byKey(const Key('layout_inspector_collapse')), findsOneWidget);
      final wideCanvas = tester.getSize(find.byType(LayoutBoardPage)).width;
      expect(wideCanvas, 1024);

      await tester.tap(find.byKey(const Key('layout_inspector_collapse')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('layout_inspector_collapse')), findsNothing);
      expect(find.byKey(const Key('layout_inspector_expand')), findsOneWidget);

      await tester.tap(find.byKey(const Key('layout_inspector_expand')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('layout_inspector_collapse')), findsOneWidget);
      await disposeBoard(tester);
    });

    testWidgets('도면이 좁아지는 화면(14.6인치 세로)에서는 접힌 채로 시작한다', (tester) async {
      await pumpBoard(tester, size: kTall);
      expect(find.byKey(const Key('layout_inspector_expand')), findsOneWidget);
      expect(find.byKey(const Key('layout_inspector_collapse')), findsNothing);
      await disposeBoard(tester);
    });

    testWidgets('접고 펴 둔 것은 폰에 기억한다', (tester) async {
      await pumpBoard(tester);
      await tester.tap(find.byKey(const Key('layout_inspector_collapse')));
      await tester.pumpAndSettle();
      final p = await SharedPreferences.getInstance();
      expect(p.getBool('layout_inspector_open_v1'), false);
      await disposeBoard(tester);

      // 다시 열면 접힌 채다.
      await pumpBoard(tester);
      expect(find.byKey(const Key('layout_inspector_expand')), findsOneWidget);
      await disposeBoard(tester);
    });

    testWidgets('접혀 있어도 모듈을 누를 수 있고, 펴면 그 모듈이 편집 칸에 뜬다', (tester) async {
      await pumpBoard(tester, size: kTall);
      await tester.tap(find.text('단자대'));
      await tester.pumpAndSettle();
      expect(find.text('모듈 이름'), findsNothing);
      await tester.tap(find.byKey(const Key('layout_inspector_expand')));
      await tester.pumpAndSettle();
      expect(find.text('모듈 이름'), findsOneWidget);
      await disposeBoard(tester);
    });
  });

  group('왼쪽 라이브러리 묶음', () {
    testWidgets('기본은 접혀 있고, 누르면 펴지고 다시 누르면 접힌다', (tester) async {
      await pumpBoard(tester);
      final header = find.byKey(_brandKey, skipOffstage: false);
      await tester.scrollUntilVisible(
        header,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(_firstPreset, skipOffstage: false), findsNothing);

      await tester.tap(header);
      await tester.pumpAndSettle();
      expect(find.text(_firstPreset, skipOffstage: false), findsWidgets);

      await tester.tap(header);
      await tester.pumpAndSettle();
      expect(find.text(_firstPreset, skipOffstage: false), findsNothing);
      await disposeBoard(tester);
    });

    testWidgets('모두 펴기·모두 접기, 그리고 펴 둔 것을 기억한다', (tester) async {
      await pumpBoard(tester);
      final all = find.byKey(
        const Key('layout_palette_toggle_all'),
        skipOffstage: false,
      );
      await tester.scrollUntilVisible(
        all,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('모두 펴기'), findsOneWidget);
      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(find.text('모두 접기'), findsOneWidget);
      expect(find.text(_firstPreset, skipOffstage: false), findsWidgets);

      final p = await SharedPreferences.getInstance();
      final saved = p.getStringList('layout_palette_open_v1')!;
      expect(saved, contains('inst:$_brand'));

      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(find.text('모두 펴기'), findsOneWidget);
      expect(find.text(_firstPreset, skipOffstage: false), findsNothing);
      await disposeBoard(tester);
    });
  });
}
