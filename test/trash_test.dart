// 휴지통(10-02): 넣기·복원·30일 지나면 저절로 비움·완전 삭제·비우기, 화면 동작.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/trash/trash_store.dart';
import 'package:tubing_calculator/src/data/record_sync.dart';
import 'package:tubing_calculator/src/presentation/equipment/equipment_model.dart';
import 'package:tubing_calculator/src/presentation/equipment/equipment_store.dart';
import 'package:tubing_calculator/src/presentation/trash/trash_kinds.dart';
import 'package:tubing_calculator/src/presentation/trash/trash_page.dart';

final _t0 = DateTime(2026, 10, 2, 9);

Equipment _eq(String id, String name) => Equipment(id: id, name: name, assetNo: 'CT-$id', createdAt: _t0);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    recordRemote = () => null;
    TrashStore.now = () => _t0;
  });
  tearDown(() => TrashStore.now = DateTime.now);

  test('장비를 휴지통에 넣으면 대장에서 빠지고, 복원하면 같은 아이디·내용으로 돌아온다', () async {
    await EquipmentStore.put(_eq('a', '고속절단기'));
    final e = await trashEquipment((await EquipmentStore.load()).single);
    expect(await EquipmentStore.load(), isEmpty);
    final list = await loadTrash();
    expect(list.single.title, '고속절단기');
    expect(list.single.subtitle, 'CT-a');
    await restoreTrash(e);
    final back = (await EquipmentStore.load()).single;
    expect(back.id, 'a');
    expect(back.assetNo, 'CT-a');
    expect(await loadTrash(), isEmpty);
  });

  test('30일이 지나면 저절로 빠지고, 남은 날을 센다', () async {
    final e = await TrashStore.add(kind: TrashKind.equipment, title: 'x', data: _eq('x', 'x').toJson());
    expect(e.daysLeft(_t0), 30);
    expect(e.daysLeft(_t0.add(const Duration(days: 29, hours: 1))), 1);
    TrashStore.now = () => _t0.add(const Duration(days: 29, hours: 23));
    expect((await loadTrash()).length, 1);
    TrashStore.now = () => _t0.add(const Duration(days: 30));
    expect(await loadTrash(), isEmpty);
  });

  test('완전 삭제·비우기', () async {
    final a = await TrashStore.add(kind: TrashKind.equipment, title: 'a', data: _eq('a', 'a').toJson());
    TrashStore.now = () => _t0.add(const Duration(minutes: 1));
    await TrashStore.add(kind: TrashKind.equipment, title: 'b', data: _eq('b', 'b').toJson());
    expect((await loadTrash()).map((e) => e.title), ['b', 'a']); // 최신이 앞
    await purgeTrash(a);
    expect((await loadTrash()).map((e) => e.title), ['b']);
    await emptyTrash();
    expect(await loadTrash(), isEmpty);
  });

  test('서버 값(Timestamp) 바꾸기 왕복', () {
    final d = DateTime(2026, 10, 2, 8, 30);
    final enc = trashEncode({'at': d, 'list': [1, {'b': d}]});
    final dec = trashDecode(enc) as Map;
    expect((dec['at'] as dynamic).toDate(), d);
    expect(((dec['list'] as List)[1] as Map)['b'].toDate(), d);
  });

  testWidgets('휴지통 화면: 복원 단추, 밀면 확인 뒤 완전 삭제, 비우기', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await EquipmentStore.put(_eq('a', '고속절단기'));
      await trashEquipment((await EquipmentStore.load()).single);
      await TrashStore.add(kind: TrashKind.equipment, title: '밴드쏘', data: _eq('b', '밴드쏘').toJson());
    });
    await tester.pumpWidget(const MaterialApp(home: TrashPage()));
    await tester.pumpAndSettle();
    expect(find.text('고속절단기'), findsOneWidget);
    expect(find.text('밴드쏘'), findsOneWidget);
    expect(find.textContaining('30일 뒤 완전히 지워집니다'), findsNWidgets(2));

    // 밀면 묻고, 취소하면 그대로
    await tester.drag(find.text('밴드쏘'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('완전히 삭제하시겠습니까?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('밴드쏘'), findsOneWidget);
    // 다시 밀고 삭제
    await tester.drag(find.text('밴드쏘'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trash_purge_ok')));
    await tester.pumpAndSettle();
    expect(find.text('밴드쏘'), findsNothing);

    // 비우기
    await tester.tap(find.byKey(const Key('trash_empty')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trash_empty_ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trash_none')), findsOneWidget);
  });
}
