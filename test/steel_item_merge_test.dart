// 형강 컷팅 항목 저장 때 서버 것과 합치기(8차, 10-09): 다른 기기에서 넣은 줄이 지워지지 않는다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/data/models/steel_cutting_project_model.dart';
import 'package:tubing_calculator/src/presentation/steel_cutting/steel_item_merge.dart';

SteelCutItem _i(String id, {double len = 1000, int qty = 1}) => SteelCutItem(
  id: id,
  category: 'ANGLE',
  shapeLabel: 'L-50x50x6',
  length: len,
  qty: qty,
);

List<String> _ids(SteelItemsMerge m) => m.items.map((e) => e.id).toList();

void main() {
  test('다른 기기가 넣은 줄은 남고, 내가 넣은 줄도 남는다', () {
    final base = [_i('a'), _i('b')];
    final local = [_i('a'), _i('b'), _i('mine')];
    final server = [_i('a'), _i('b'), _i('theirs')];
    final m = mergeSteelItems(base: base, local: local, server: server);
    expect(_ids(m), ['a', 'b', 'mine', 'theirs']);
    expect(m.deletedIds, isEmpty);
  });

  test('내가 손대지 않은 줄은 다른 기기가 고친 값, 내가 고친 줄은 내 값', () {
    final base = [_i('a'), _i('b')];
    final local = [_i('a', qty: 5), _i('b')];
    final server = [_i('a', qty: 2), _i('b', len: 750)];
    final m = mergeSteelItems(base: base, local: local, server: server);
    expect(m.items[0].qty, 5);
    expect(m.items[1].length, 750);
  });

  test('내가 지운 줄은 서버에 남아 있어도 빠지고, 지운 아이디로 남는다', () {
    final base = [_i('a'), _i('b')];
    final local = [_i('a')];
    final server = [_i('a'), _i('b')];
    final m = mergeSteelItems(base: base, local: local, server: server);
    expect(_ids(m), ['a']);
    expect(m.deletedIds, ['b']);
  });

  test('다른 기기가 지운 줄(지운 아이디)은 내가 손대지 않았으면 빠진다', () {
    final base = [_i('a'), _i('b')];
    final local = [_i('a'), _i('b')];
    final server = [_i('a')];
    final m = mergeSteelItems(
      base: base,
      local: local,
      server: server,
      serverDeletedIds: ['b'],
    );
    expect(_ids(m), ['a']);
    expect(m.deletedIds, ['b']);
  });

  test('통신 없이 다른 기기가 목록을 통째로 덮어 내 줄이 빠졌어도(지운 표시 없음) 되살린다', () {
    final base = [_i('a'), _i('mine')];
    final local = [_i('a'), _i('mine')];
    final server = [_i('a'), _i('theirs')];
    final m = mergeSteelItems(base: base, local: local, server: server);
    expect(_ids(m), ['a', 'mine', 'theirs']);
  });

  test('지웠다가 실행 취소로 살린 줄은 지운 아이디에서 빠진다', () {
    final base = [_i('a')]; // 지운 뒤 저장한 상태
    final local = [_i('a'), _i('b')]; // 되돌려 살림
    final server = [_i('a')];
    final m = mergeSteelItems(
      base: base,
      local: local,
      server: server,
      serverDeletedIds: ['b'],
    );
    expect(_ids(m), ['a', 'b']);
    expect(m.deletedIds, isEmpty);
  });
}
