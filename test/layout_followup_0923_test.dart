// 배치도 후속(2026-09-23 점검결과 18~26번) 확인.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';

void main() {
  test('26번: 같은 순간에 만든 아이디가 겹치지 않는다', () {
    final ids = {for (var i = 0; i < 2000; i++) newLayoutId()};
    expect(ids.length, 2000);
    expect(newLayoutId('dup_'), startsWith('dup_'));
  });

  test('19번: 뒤집기 칸은 저장했다 읽어도 남는다(복제할 때 같이 옮기는 값)', () {
    final a = PlacedItem(
      id: 'a',
      name: '곤질레다 LB 22',
      position: Offset.zero,
      flipped: true,
      isLocked: true,
    );
    final back = PlacedItem.fromJson(a.toJson());
    expect(back.flipped, isTrue);
    expect(back.isLocked, isTrue);
  });

  Map<String, dynamic> wall(double x, double y) => {
    'type': 'wall',
    'id': 'wall_${x}_$y',
    'x': x,
    'y': y,
  };
  Map<String, dynamic> viewPt(String planId) => {
    'type': 'item',
    'id': 'view_$planId',
    'name': 'x',
    'x': 0,
    'y': 0,
    'w': 10,
    'h': 10,
  };
  Map<String, dynamic> dim(String id, Map p1, Map p2) => {
    'id': id,
    'p1': p1,
    'p2': p2,
    'type': 'center',
    'isDiagonal': false,
    'isSafetyCritical': false,
  };

  testWidgets('20·22번: 정면 탭으로 가면 판 폭이 평면 길이를 따르고, 없는 부품의 치수는 빠진다', (
    tester,
  ) async {
    final draft = {
      'kind': kLayoutKindSkid,
      'projectName': 'TEST',
      'panelWidth': 3000.0,
      'panelHeight': 2000.0,
      'items': [
        {
          'type': 'item',
          'id': 'a',
          'name': '정션박스 300×300',
          'x': 100,
          'y': 100,
          'w': 300,
          'h': 300,
          'elev': 500,
        },
      ],
      'dimensions': <Map<String, dynamic>>[],
      'sidePlatesOn': true,
      'sidePlates': {
        'front': {
          // 예전 스키드 길이(2400)로 만들어진 정면 판 — 평면을 3000으로 바꿔도 안 따라오던 것.
          'panelWidth': 2400.0,
          'panelHeight': 1500.0,
          'items': <Map<String, dynamic>>[],
          'dimensions': [
            dim('keep', viewPt('a'), wall(0, 0)),
            dim('gone', viewPt('deleted'), wall(0, 0)),
          ],
        },
      },
    };
    SharedPreferences.setMockInitialValues({
      'layout_board_onboarding_shown_v1': true,
      'layout_board_draft_v1': jsonEncode(draft),
    });
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: LayoutBoardPage(initialKind: kLayoutKindSkid, resumeDraft: true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('plate_tab_front')));
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(LayoutBoardPage)) as dynamic;
    final plates = state.debugPlates() as Map<String, Map<String, dynamic>>;
    final front = plates['front']!;
    expect(front['panelWidth'], 3000.0);
    final dims = (front['dimensions'] as List).cast<Map>();
    expect(dims.map((d) => d['id']), ['keep']);
  });
}
