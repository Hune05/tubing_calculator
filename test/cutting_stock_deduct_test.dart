import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_stock_deduct.dart';

void main() {
  group('컷팅에서 쓴 자재를 재고에서 뺄 줄로 바꾸기', () {
    test('튜브는 쓴 길이를 한 본(6000mm)으로 올려 센다', () {
      final takes = stockTakesFromMaterials([
        {'db_name': 'TUBE (기본)', 'type': 'TUBE', 'qty_mm': 6001},
      ]);
      expect(takes.length, 1);
      expect(takes.first.qty, 2);
      expect(takes.first.unit, '본');
    });

    test('딱 맞으면 올리지 않는다', () {
      final takes = stockTakesFromMaterials([
        {'db_name': 'TUBE (기본)', 'type': 'TUBE', 'qty_mm': 12000},
      ]);
      expect(takes.first.qty, 2);
    });

    test('피팅은 개수를 그대로 쓴다', () {
      final takes = stockTakesFromMaterials([
        {
          'db_name': '[HY-LOK] 3/8" Union',
          'type': 'FITTING',
          'qty_ea': 3,
          'spec': '3/8"',
        },
      ]);
      expect(takes.first.name, '[HY-LOK] 3/8" Union');
      expect(takes.first.qty, 3);
      expect(takes.first.unit, 'EA');
      expect(takes.first.spec, '3/8"');
    });

    test('수량이 0이거나 이름이 없으면 뺀다', () {
      final takes = stockTakesFromMaterials([
        {'db_name': 'TUBE (기본)', 'type': 'TUBE', 'qty_mm': 0},
        {'db_name': '', 'type': 'FITTING', 'qty_ea': 5},
        {'type': 'FITTING', 'qty_ea': 5},
        '이상한 줄',
      ]);
      expect(takes, isEmpty);
    });

    test('여러 줄을 그대로 옮긴다', () {
      final takes = stockTakesFromMaterials([
        {'db_name': 'TUBE (기본)', 'type': 'TUBE', 'qty_mm': 3000},
        {'db_name': '[DK-Lok] 1/2" Elbow', 'type': 'FITTING', 'qty_ea': 2},
      ]);
      expect(takes.length, 2);
      expect(takes[0].qty, 1);
      expect(takes[1].qty, 2);
    });
  });

  group('차감 결과 알림 글', () {
    const a = StockTake(name: '가', qty: 1, unit: 'EA');
    const b = StockTake(name: '나', qty: 2, unit: 'EA');

    test('다 뺐으면 몇 건인지 알려 준다', () {
      const r = StockDeductResult(done: [a, b], missing: []);
      expect(r.allDone, isTrue);
      expect(r.message, '자재 2건을 재고에서 차감했습니다.');
    });

    test('재고에 없는 것이 있으면 그것도 알려 준다', () {
      const r = StockDeductResult(done: [a], missing: [b]);
      expect(r.allDone, isFalse);
      expect(r.message.contains('1건을 차감했습니다'), isTrue);
      expect(r.message.contains('1건은 재고에 없어'), isTrue);
    });

    test('하나도 못 찾았으면 자재 목록에서 넣으라고 한다', () {
      const r = StockDeductResult(done: [], missing: [a, b]);
      expect(r.message.contains('재고에 없는 자재 2건'), isTrue);
      expect(r.message.contains('자재 목록'), isTrue);
    });

    test('아무것도 없으면 그렇게 알려 준다', () {
      const r = StockDeductResult(done: [], missing: []);
      expect(r.message, '차감할 자재가 없습니다.');
    });
  });
}
