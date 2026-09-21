import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/layout_board_models.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_project_list_page.dart';

// 목록에는 내 배치도만 보인다. 만든 사람 칸이 없는 예전 배치도는 예전처럼 보인다.
void main() {
  const me = LayoutOwner(uid: 'u-me', name: '김반장');

  group('layoutVisibleTo', () {
    test('만든 사람 칸이 없는 예전 배치도는 누구에게나 보인다', () {
      expect(layoutVisibleTo({'projectName': '예전'}, me), true);
      expect(layoutVisibleTo({'projectName': '예전'}, const LayoutOwner()), true);
      expect(layoutVisibleTo({'ownerUid': '', 'ownerName': '  '}, me), true);
    });

    test('uid가 있으면 uid로 가른다', () {
      expect(
        layoutVisibleTo({'ownerUid': 'u-me', 'ownerName': '다른이름'}, me),
        true,
      );
      expect(
        layoutVisibleTo({'ownerUid': 'u-other', 'ownerName': '김반장'}, me),
        false,
      );
    });

    test('uid로 가를 수 없으면 이름으로 가른다', () {
      expect(layoutVisibleTo({'ownerName': '김반장'}, me), true);
      expect(layoutVisibleTo({'ownerName': '이기사'}, me), false);
      // 저장한 쪽은 로그인했고 나는 로그인 안 함 → 이름으로
      expect(
        layoutVisibleTo({
          'ownerUid': 'u-x',
          'ownerName': '김반장',
        }, const LayoutOwner(name: '김반장')),
        true,
      );
    });

    test('나를 알 수 없으면(로그인·이름 없음) 예전처럼 다 보인다', () {
      expect(layoutVisibleTo({'ownerUid': 'u-x'}, const LayoutOwner()), true);
    });
  });

  test('만든 사람 칸은 아는 것만 붙이고 칸 이름은 ownerUid/ownerName', () {
    expect(layoutOwnerFields(me), {'ownerUid': 'u-me', 'ownerName': '김반장'});
    expect(layoutOwnerFields(const LayoutOwner(name: '김반장')), {
      'ownerName': '김반장',
    });
    expect(layoutOwnerFields(const LayoutOwner()), isEmpty);
  });

  test('만든 사람 칸이 저장 칸 이름과 겹치지 않는다', () {
    final keys = layoutSaveFields(
      projectId: 'p',
      projectName: 'n',
      panelWidth: 600,
      panelHeight: 800,
      items: const [],
      dimensions: const [],
      backgroundImagePath: null,
      backgroundOpacity: 0.5,
    ).keys;
    expect(keys.contains(kLayoutOwnerUidField), false);
    expect(keys.contains(kLayoutOwnerNameField), false);
  });

  test('visibleLayoutEntries: 남의 것은 빼고 최근 고친 순으로', () {
    final list = visibleLayoutEntries([
      LayoutListEntry('old', {
        'projectName': '예전',
        'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      }),
      LayoutListEntry('mine', {
        'projectName': '내 것',
        'ownerUid': 'u-me',
        'updatedAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
      }),
      LayoutListEntry('other', {
        'projectName': '남의 것',
        'ownerUid': 'u-other',
        'updatedAt': Timestamp.fromDate(DateTime(2026, 9, 10)),
      }),
      const LayoutListEntry('noDate', {'projectName': '날짜 없음'}),
    ], me);
    expect(list.map((e) => e.id).toList(), ['mine', 'old', 'noDate']);
  });

  testWidgets('목록 화면: 내 것과 예전 것만 보이고, 줄마다 복제·삭제 단추가 보인다', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final ctrl = StreamController<List<LayoutListEntry>>();
    addTearDown(ctrl.close);
    await tester.pumpWidget(
      MaterialApp(
        home: LayoutBoardProjectListPage(entries: ctrl.stream, owner: me),
      ),
    );
    ctrl.add([
      const LayoutListEntry('a', {
        'projectName': '1호기 분전반',
        'ownerUid': 'u-me',
      }),
      const LayoutListEntry('b', {'projectName': '예전 배치도'}),
      const LayoutListEntry('c', {'projectName': '남의 배치도', 'ownerUid': 'u-x'}),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('1호기 분전반'), findsOneWidget);
    expect(find.text('예전 배치도'), findsOneWidget);
    expect(find.text('남의 배치도'), findsNothing);
    expect(find.byTooltip('복제·삭제'), findsNWidgets(2));
    final Size btn = tester.getSize(find.byTooltip('복제·삭제').first);
    expect(btn.width, greaterThanOrEqualTo(40)); // 보통 폰 누르는 크기
    expect(btn.height, greaterThanOrEqualTo(40));

    // 길게 누르지 않고 단추로 복제·삭제 창을 연다.
    await tester.tap(find.byTooltip('복제·삭제').first);
    await tester.pumpAndSettle();
    expect(find.text('복제하기'), findsOneWidget);
    expect(find.text('삭제하기'), findsOneWidget);
  });

  group('다른 도면에서 가져오기 후보', () {
    List<MapEntry<String, Map<String, dynamic>>> pick(
      List<MapEntry<String, Map<String, dynamic>>> docs, {
      String? current,
    }) => layoutImportCandidates(
      docs,
      me: me,
      currentId: current,
      dataOf: (d) => d.value,
      idOf: (d) => d.key,
    );

    test('남의 배치도와 지금 열어 둔 도면은 빼고, 예전 배치도는 넣는다', () {
      final docs = [
        MapEntry('mine', {'ownerUid': 'u-me'}),
        MapEntry('other', {'ownerUid': 'u-other'}),
        MapEntry('old', <String, dynamic>{'projectName': '예전'}),
        MapEntry('open', {'ownerUid': 'u-me'}),
      ];
      expect(pick(docs, current: 'open').map((e) => e.key).toSet(), {
        'mine',
        'old',
      });
    });

    test('updatedAt이 없는 예전 문서도 빠지지 않고 createdAt으로 줄 선다', () {
      final docs = [
        MapEntry('a', {'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1))}),
        MapEntry('b', {'createdAt': Timestamp.fromDate(DateTime(2026, 5, 1))}),
        MapEntry('c', <String, dynamic>{}),
        MapEntry('d', {'updatedAt': Timestamp.fromDate(DateTime(2026, 9, 1))}),
      ];
      expect(pick(docs).map((e) => e.key).toList(), ['d', 'b', 'a', 'c']);
    });
  });
}
