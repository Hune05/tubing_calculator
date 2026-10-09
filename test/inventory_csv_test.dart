// 재고 엑셀(CSV) 내보내기·가져오기(10-09 자재 관리): 글 만들기, 읽기, 무엇을 고칠지 계획.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/inventory_csv.dart';

final _server = <String, Map<String, dynamic>>{
  'a': {
    'name': '[HY-LOK] 3/8" Union',
    'category': 'FITTING',
    'maker': '하이록',
    'location': 'A창고',
    'unit': 'EA',
    'qty': 14,
    'minQty': 5,
  },
  'b': {'name': '찬넬 75x40x5', 'category': 'STEEL', 'unit': '본', 'qty': 3},
  'mine': {
    'name': '앵글 50x50x6',
    'category': 'STEEL',
    'qty': 2,
    'ownerUid': 'me',
  },
  'other': {'name': '남의 자재', 'qty': 9, 'ownerUid': 'someone'},
};

Iterable<(String, Map<String, dynamic>)> get _docs => [
  for (final e in _server.entries) (e.key, e.value),
];

void main() {
  test('내보내기: BOM·머리줄, 나에게 보이는 것만, 분류는 한글로, 쉼표·따옴표는 감싼다', () {
    final csv = buildInventoryCsv(_docs, 'me');
    expect(
      csv.startsWith('﻿아이디,이름,분류,규격,제조사,재질,위치,단위,수량,최소 수량,히트 번호,내보낼 때 수량\r\n'),
      isTrue,
    );
    expect(csv, isNot(contains('남의 자재')));
    expect(csv, contains('"[HY-LOK] 3/8"" Union",피팅'));
    expect(csv, contains('mine,앵글 50x50x6,형강'));
    expect(inventoryCsvFileName(DateTime(2026, 10, 9)), '재고_20261009.csv');
  });

  test('내보낸 것을 그대로 가져오면 바뀌는 것이 없다', () {
    final parsed = parseInventoryCsv(buildInventoryCsv(_docs, 'me'));
    expect(parsed.errors, isEmpty);
    expect(parsed.rows, hasLength(3));
    final plan = planInventoryImport(parsed, _server, 'me');
    expect(plan.isEmpty, isTrue);
    expect(plan.unchanged, 3);
  });

  test('수량은 "고친 값 − 내보낼 때 값"만 더하고 뺀다(내보낸 뒤 컷팅으로 빠진 것은 남는다)', () {
    const csv =
        '아이디,이름,분류,위치,수량,최소 수량,내보낼 때 수량\n'
        'a,"[HY-LOK] 3/8"" Union",피팅,B창고,20,5,14\n';
    // 내보낸 뒤 컷팅에서 4개가 빠져 서버는 10
    final server = {
      ..._server,
      'a': {..._server['a']!, 'qty': 10},
    };
    final plan = planInventoryImport(parseInventoryCsv(csv), server, 'me');
    final u = plan.updates.single;
    expect(u.qtyDelta, 6); // 20 − 14
    expect(u.qtyBefore, 10);
    expect(u.qtyAfter, 16);
    expect(u.fields, {'location': 'B창고'});
    final text = inventoryImportSummary(plan);
    expect(text, contains('고칠 자재 1건(수량 바뀜 1건)'));
    expect(text, contains('[HY-LOK] 3/8" Union: 10 → 16EA'));
  });

  test('"내보낼 때 수량"이 없으면 적힌 수량으로 맞춘다, 칸이 없는 글은 안 고친다', () {
    const csv = '아이디,이름,수량\nb,찬넬 75x40x5,7\n';
    final plan = planInventoryImport(parseInventoryCsv(csv), _server, 'me');
    final u = plan.updates.single;
    expect(u.qtyDelta, 4);
    expect(u.fields, isEmpty); // 제조사·위치 칸이 없으니 그대로
  });

  test('새 줄: 아이디가 비면 새로 넣고, 이미 있는 이름·제조사면 넘긴다', () {
    const csv =
        '아이디,이름,분류,제조사,수량,단위\n'
        ',후강 전선관 22mm,전선관,삼화,10,본\n'
        ',[HY-LOK] 3/8” Union,피팅,하이록,1,EA\n'
        ',[HY-LOK] 3/8" Union,피팅,스웨즈락,2,EA\n';
    final plan = planInventoryImport(parseInventoryCsv(csv), _server, 'me');
    expect(plan.creates.map((r) => r.name), [
      '후강 전선관 22mm',
      '[HY-LOK] 3/8" Union',
    ]);
    expect(plan.creates.first.category, 'CONDUIT');
    expect(plan.problems.single, contains('3째 줄'));
    expect(plan.problems.single, contains('이미 재고에 있습니다'));
  });

  test('읽기 오류·없는 아이디·남의 재고·같은 아이디 두 번은 넘긴다', () {
    const csv =
        '아이디,이름,수량\n'
        'a,유니온,열두 개\n'
        'zzz,없는 자재,3\n'
        'other,남의 자재,1\n'
        'b,찬넬 75x40x5,"1,200"\n'
        'b,찬넬 75x40x5,5\n'
        ',,\n'
        'mine,,3\n';
    final parsed = parseInventoryCsv(csv);
    expect(parsed.errors, ['2째 줄: 수량이 숫자가 아닙니다', '8째 줄: 이름이 비어 있습니다']);
    final plan = planInventoryImport(parsed, _server, 'me');
    expect(plan.updates.single.id, 'b');
    expect(plan.updates.single.qtyAfter, 1200); // 쉼표 든 숫자도 읽는다
    expect(plan.problems.where((p) => p.contains('재고에 없는 아이디')), hasLength(1));
    expect(
      plan.problems.where((p) => p.contains('다른 사람의 개인 재고')),
      hasLength(1),
    );
    expect(plan.problems.where((p) => p.contains('같은 아이디')), hasLength(1));
  });

  test('머리줄에 "이름"이 없으면 가져오지 않는다, 칸 차례가 바뀌어도 읽는다', () {
    expect(
      parseInventoryCsv('a,b\n1,2\n').errors.single,
      contains('"이름" 칸이 없습니다'),
    );
    final p = parseInventoryCsv('﻿수량,이름,아이디\r\n9,찬넬 75x40x5,b\r\n');
    expect(p.rows.single.id, 'b');
    expect(p.rows.single.qty, 9);
  });

  test('최소 수량·분류를 고칠 수 있고, 모르는 분류 이름은 그대로 둔다', () {
    const csv = '아이디,이름,분류,최소 수량\nb,찬넬 75x40x5,형강,4\nmine,앵글 50x50x6,모르는분류,0\n';
    final plan = planInventoryImport(parseInventoryCsv(csv), _server, 'me');
    expect(plan.updates.single.id, 'b');
    expect(plan.updates.single.fields, {'minQty': 4});
    expect(plan.unchanged, 1);
  });

  test('분류가 빈 자재는 "기타"로 내보내고, 그대로 가져오면 안 바뀐다', () {
    final server = {
      'n': <String, dynamic>{'name': '분류 없는 자재', 'qty': 1},
    };
    final csv = buildInventoryCsv([('n', server['n']!)], null);
    expect(csv, contains('n,분류 없는 자재,기타'));
    final plan = planInventoryImport(parseInventoryCsv(csv), server, null);
    expect(plan.isEmpty, isTrue);
    expect(plan.unchanged, 1);
  });
}
