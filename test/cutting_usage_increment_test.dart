// 라인 컷팅 자재 사용량을 "늘어난 만큼 더하기"로 쌓는다(10-10). 예전에는 목록(materials)을 읽어 더한 뒤
// 통째로 다시 써서, 폰·태블릿이 같은 작업을 저장하면(한쪽이 통신 없이 저장했다가 나중에 올라가면 더 잘)
// 다른 기기가 더한 부속이 사라졌다. 서버의 더하기를 흉내 내어 두 기기 저장 순서와 상관없이 합이 맞는지 본다.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_firestore_helper.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_stock_deduct.dart';

const _qty = ['qty_ea', 'qty_mm', 'qty_bars', 'qty_bars_mm'];

/// 서버가 하는 일을 흉내 낸다: 수량은 더하고, 설명 칸은 덮어쓴다.
Map<String, dynamic> apply(
  Map<String, dynamic> doc,
  Map<String, Map<String, Object>> deltas,
) {
  final usage = Map<String, dynamic>.from(doc[kUsageField] as Map? ?? {});
  deltas.forEach((k, d) {
    final row = Map<String, dynamic>.from(usage[k] as Map? ?? {});
    d.forEach((f, v) {
      row[f] = _qty.contains(f) ? ((row[f] as num?) ?? 0) + (v as num) : v;
    });
    usage[k] = row;
  });
  return {...doc, kUsageField: usage};
}

Map<String, dynamic> fit(String name, int n) => {
  'db_name': name,
  'maker': 'HY-LOK',
  'spec': '1/2"',
  'name': name,
  'qty': n,
};

num? qtyOf(List<Map<String, dynamic>> rows, String name, [String k = 'qty_ea']) =>
    rows.where((m) => m['db_name'] == name).firstOrNull?[k] as num?;

void main() {
  test('키: 다른 이름은 다른 키, 영문·숫자·한글 말고는 _코드_로', () {
    expect(usageKeyOf('튜브 1/2"'), '튜브_20_1_2f_2_22_');
    expect(usageKeyOf('[HY-LOK] 1/2" Union'), isNot(usageKeyOf('[HY-LOK] 1/2" Union.')));
    expect(usageKeyOf('a_b'), isNot(usageKeyOf('a b')));
    for (final n in ['튜브 1/2"', '[HY-LOK] 3/8" Elbow', 'a.b/c~d*e']) {
      expect(RegExp(r'^[0-9A-Za-z가-힣_]+$').hasMatch(usageKeyOf(n)), isTrue);
    }
  });

  test('두 기기가 같은 작업을 저장해도(순서와 상관없이) 부속 합이 맞다', () {
    final a = usageDeltas(sessionUsageRows([fit('엘보', 2)]));
    final b = usageDeltas(sessionUsageRows([fit('엘보', 3), fit('티', 1)]));
    for (final order in [
      [a, b],
      [b, a],
    ]) {
      var doc = <String, dynamic>{};
      for (final d in order) {
        doc = apply(doc, d);
      }
      final rows = materialsOf(doc);
      expect(qtyOf(rows, '엘보'), 5);
      expect(qtyOf(rows, '티'), 1);
      expect(rows.firstWhere((m) => m['db_name'] == '엘보')['maker'], 'HY-LOK');
    }
  });

  test('예전 목록과 사용량 칸은 이름별로 합쳐 읽고, 다 빠진 줄은 안 보인다', () {
    var doc = <String, dynamic>{
      'materials': [
        {'db_name': '엘보', 'type': 'FITTING', 'qty_ea': 4},
        {'db_name': 'TUBE (기본)', 'type': 'TUBE', 'qty_mm': 3000},
      ],
    };
    doc = apply(doc, usageDeltas(sessionUsageRows([fit('엘보', 2), fit('티', 1)])));
    doc = apply(doc, usageDeltas(sessionUsageRows([fit('티', 1)]), sign: -1));
    final rows = materialsOf(doc);
    expect(qtyOf(rows, '엘보'), 6);
    expect(qtyOf(rows, 'TUBE (기본)', 'qty_mm'), 3000);
    expect(rows.where((m) => m['db_name'] == '티'), isEmpty);
    expect(rows.length, 2);
  });

  test('나중에 뺄 튜브 줄(본수)도 사용량 칸에 쌓이고 재고 빼기 본수가 맞다', () {
    final extra = pendingTubeEntries(
      {'튜브 1/2"': 12000},
      barsBySpec: {'튜브 1/2"': 3},
    );
    final doc = apply({}, usageDeltas(sessionUsageRows(extra)));
    final takes = stockTakesFromMaterials(
      materialsOf(doc),
      barLengthByName: {'튜브 1/2"': 6000},
    );
    expect(takes.single.name, '튜브 1/2"');
    expect(takes.single.qty, 3);
  });

  test('실행 취소: 더한 만큼 빼되, 그사이 재고에서 빼서 줄었으면 남은 만큼만', () {
    final saved = [fit('엘보', 3)];
    var doc = apply({}, usageDeltas(sessionUsageRows(saved)));
    // 다른 기기가 엘보 2개를 더함
    doc = apply(doc, usageDeltas(sessionUsageRows([fit('엘보', 2)])));
    final undone = apply(doc, usageDeltas(undoUsageRows(doc, saved), sign: -1));
    expect(qtyOf(materialsOf(undone), '엘보'), 2);

    // 저장 뒤 재고 빼기로 1개만 남았으면 1개만 빼서 0(음수가 되지 않는다)
    var drained = apply({}, usageDeltas(sessionUsageRows(saved)));
    drained = apply(drained, usageDeltas([
      {'db_name': '엘보', 'qty_ea': 2},
    ], sign: -1));
    final rows = undoUsageRows(drained, saved);
    expect(rows.single['qty_ea'], 1);
    final after = apply(drained, usageDeltas(rows, sign: -1));
    expect((after[kUsageField] as Map).values.single['qty_ea'], 0);
    expect(materialsOf(after), isEmpty);
  });

  test('재고 빼기: 못 뺀 이름은 남기고, 확인 창 사이 다른 기기가 더한 몫도 남긴다', () {
    var doc = <String, dynamic>{
      'materials': [
        {'db_name': '엘보', 'type': 'FITTING', 'qty_ea': 1},
      ],
    };
    doc = apply(doc, usageDeltas(sessionUsageRows([fit('엘보', 2), fit('티', 1)])));
    final atRead = Map<String, dynamic>.from(doc);
    // 확인 창이 떠 있는 사이 다른 기기가 엘보 4개를 더함
    doc = apply(doc, usageDeltas(sessionUsageRows([fit('엘보', 4)])));

    final parts = deductedParts(atRead, {'티'}); // 티는 재고에 없어 못 뺌
    expect(parts.legacy.single['qty_ea'], 1);
    expect(parts.usage.map((m) => m['db_name']), ['엘보']);
    doc = apply(doc, usageDeltas(parts.usage, sign: -1));
    doc['materials'] = materialsAfterDeduct(
      doc['materials'] as List,
      parts.legacy,
    );
    final rows = materialsOf(doc);
    expect(qtyOf(rows, '엘보'), 4); // 다른 기기 몫
    expect(qtyOf(rows, '티'), 1); // 못 뺀 것
    expect(doc['materials'], isEmpty);
  });

  test('문서 update 내용: 수량은 더하기, 설명 칸은 값, 모두 usage.키.칸', () {
    final u = usageUpdate(usageDeltas(sessionUsageRows([fit('엘보', 2)])));
    final paths = u.keys.cast<FieldPath>().map((p) => p.components).toList();
    expect(paths.every((c) => c.length == 3 && c[0] == kUsageField), isTrue);
    final byField = {
      for (final e in u.entries) (e.key as FieldPath).components[2]: e.value,
    };
    expect(byField['qty_ea'], isA<FieldValue>());
    expect(byField['db_name'], '엘보');
    expect(byField['type'], 'FITTING');
  });
}
