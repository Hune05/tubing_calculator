import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_project_list_page.dart';

// 작업 배치도가 작은 폰(320), 보통 폰(390), 세로 태블릿·폴드(800), 가로 태블릿(1024)에서
// 넘치지 않는지 본다. 도면, 모듈 고치기, 치수 모드, 더보기, 지우기 확인 창, 저장 창, 목록.

const List<Size> kSizes = [
  Size(320, 568),
  Size(390, 844),
  Size(800, 1280),
  Size(1024, 768),
];

void setSize(WidgetTester tester, Size s) {
  tester.view.physicalSize = s * 2;
  tester.view.devicePixelRatio = 2;
}

Map<String, dynamic> draft() => {
  'projectId': null,
  'projectName': '1호기 분전반 제어반 아주 긴 이름 테스트',
  'panelWidth': 600,
  'panelHeight': 800,
  'items': [
    {'type': 'item', 'id': 'a', 'name': '차단기 A', 'x': 40, 'y': 40},
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
  'dimensions': [
    {
      'id': 'd1',
      'p1': {'type': 'item', 'id': 'a', 'name': '차단기 A', 'x': 40, 'y': 40},
      'p2': {'type': 'wall', 'id': 'wall_600_80', 'x': 600, 'y': 80},
      'type': 'center',
    },
  ],
};

const String presetsJson =
    '[{"name":"차단기 3P","width":90,"height":130},{"name":"SMPS 전원 공급기 아주 긴 이름","width":60,"height":120}]';

Future<GlobalKey<NavigatorState>> openBoard(
  WidgetTester tester,
  Size size,
) async {
  SharedPreferences.setMockInitialValues({
    'layout_board_onboarding_shown_v1': true,
    'layout_board_draft_v1': jsonEncode(draft()),
    'layout_board_custom_presets': presetsJson,
  });
  setSize(tester, size);
  addTearDown(tester.view.reset);
  final nav = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(navigatorKey: nav, home: const LayoutBoardPage()),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
  await tester.tap(find.text('이어하기'));
  await tester.pumpAndSettle();
  return nav;
}

Future<void> disposeBoard(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

Finder onBoard(String name) => find.descendant(
  of: find.byType(InteractiveViewer),
  matching: find.text(name),
);

void main() {
  for (final size in kSizes) {
    final String tag = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('$tag: 도면·모듈 고치기·치수 모드가 넘치지 않는다', (tester) async {
      final nav = await openBoard(tester, size);
      expect(tester.takeException(), isNull);

      // 모듈을 누르면 좁은 화면은 바텀시트, 넓은 화면은 오른쪽 칸.
      await tester.tap(onBoard('차단기 A'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (!layoutBoardUsesWideLayout(size)) {
        expect(nav.currentState!.canPop(), isTrue, reason: '편집 바텀시트가 열려야 함');
        nav.currentState!.pop();
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('고정 치수 측정'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await disposeBoard(tester);
    });

    testWidgets('$tag: 더보기, 전체 지우기 확인 창, 저장 창이 넘치지 않는다', (tester) async {
      final nav = await openBoard(tester, size);

      await tester.tap(find.byTooltip('더보기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('도면 전체 지우기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('도면 전체 지우기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(onBoard('단자대'), findsOneWidget);

      await tester.tap(find.byTooltip('저장·공유'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      await disposeBoard(tester);
    });

    testWidgets('$tag: 배치도 목록이 넘치지 않는다', (tester) async {
      setSize(tester, size);
      addTearDown(tester.view.reset);
      final ctrl = StreamController<List<LayoutListEntry>>();
      addTearDown(ctrl.close);
      await tester.pumpWidget(
        MaterialApp(
          home: LayoutBoardProjectListPage(
            entries: ctrl.stream,
            owner: const LayoutOwner(uid: 'u-me', name: '김반장'),
          ),
        ),
      );
      ctrl.add([
        for (int i = 0; i < 6; i++)
          LayoutListEntry('id$i', {
            'projectName': i == 0 ? '3호기 보일러 급수 펌프실 계장 분전반 아주 긴 이름' : '분전반 $i',
            'ownerUid': 'u-me',
            'updatedAt': Timestamp.fromDate(DateTime(2026, 9, 20 - i)),
            'panelWidth': 600,
            'panelHeight': 800,
            'items': [
              for (int k = 0; k < i * 7; k++)
                {'type': 'item', 'id': 'm$k', 'name': 'M$k', 'x': 0, 'y': 0},
            ],
          }),
      ]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('분전반 1'), findsOneWidget);
    });
  }
}
