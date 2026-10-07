// 압력시험 기록 목록의 검색 칸·판정 칩(10-07): 기록이 쌓여도 끝까지 내려가지 않고 찾는다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/test_record.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/test_records_page.dart';

final _list = [
  PtRecord(id: 'a', date: DateTime(2026, 10, 1), line: 'GN-101', testNo: 'HT-1', site: '루마', tester: '홍길동'),
  PtRecord(id: 'b', date: DateTime(2026, 10, 2), line: 'AIR-5', system: '계장 공기', memo: '플랜지 재조임'),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('검색어: 라인(줄표 무시)·시험 번호·현장·계통·시험자·메모, 빈 검색어는 전부', () {
    List<String> ids(String q) => filterPtRecords(_list, q, null).map((r) => r.id).toList();
    expect(ids(''), ['a', 'b']);
    expect(ids('gn101'), ['a']);
    expect(ids('ht-1'), ['a']);
    expect(ids('루마'), ['a']);
    expect(ids('계장공기'), ['b']);
    expect(ids('홍길동'), ['a']);
    expect(ids('재조임'), ['b']);
    expect(ids('없는말'), isEmpty);
  });

  test('판정이 안 난 기록(값 부족)은 합격·불합격 어느 쪽에도 들지 않는다', () {
    expect(_list.every((r) => r.verdict.pass == null), isTrue);
    expect(filterPtRecords(_list, '', true), isEmpty);
    expect(filterPtRecords(_list, '', false), isEmpty);
  });

  testWidgets('목록 화면: 검색하면 맞는 것만·건수, 판정 칩, 지우기', (t) async {
    for (final r in _list) {
      await PtRecordStore.put(r);
    }
    await t.pumpWidget(const MaterialApp(home: PtRecordsPage()));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('pr_item_a')), findsOneWidget);
    expect(find.byKey(const Key('pr_item_b')), findsOneWidget);
    expect(find.byKey(const Key('pr_count')), findsNothing);

    await t.enterText(find.byKey(const Key('pr_search')), 'air');
    await t.pump();
    expect(find.byKey(const Key('pr_item_a')), findsNothing);
    expect(find.byKey(const Key('pr_item_b')), findsOneWidget);
    expect(find.text('1건 / 전체 2건'), findsOneWidget);

    await t.tap(find.byKey(const Key('pr_search_clear')));
    await t.pump();
    expect(find.byKey(const Key('pr_item_a')), findsOneWidget);

    await t.tap(find.byKey(const Key('pr_pass_ok')));
    await t.pump();
    expect(find.text('맞는 기록이 없습니다.'), findsOneWidget);
    await t.tap(find.byKey(const Key('pr_pass_all')));
    await t.pump();
    expect(find.byKey(const Key('pr_item_b')), findsOneWidget);
  });
}
