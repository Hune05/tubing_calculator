import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_firestore_helper.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_stock_deduct.dart';

void main() {
  group('원자재 한 본 길이', () {
    test('자재에 길이가 적혀 있으면 그 길이로 읽는다', () {
      expect(barLengthOf({'barLengthMm': 3000}), 3000);
      expect(barLengthOf({'barLengthMm': 8000}), 8000);
    });

    test('길이가 없거나 0이면 6000으로 본다', () {
      expect(barLengthOf(null), 6000);
      expect(barLengthOf({}), 6000);
      expect(barLengthOf({'barLengthMm': 0}), 6000);
    });

    test('3m짜리 원자재는 3m로 나눈다 (예전에는 6m로 나눠 절반만 뺐다)', () {
      final takes = stockTakesFromMaterials(
        [
          {'db_name': '튜브 3/8"', 'type': 'TUBE', 'qty_mm': 7000},
        ],
        barLengthByName: {'튜브 3/8"': 3000},
      );
      expect(takes.first.qty, 3); // 7000 / 3000 → 3본
    });

    test('길이를 안 넘기면 6000으로 나눈다', () {
      final takes = stockTakesFromMaterials([
        {'db_name': '튜브 3/8"', 'type': 'TUBE', 'qty_mm': 7000},
      ]);
      expect(takes.first.qty, 2);
    });

    test('피팅은 한 본 길이와 상관없다', () {
      final takes = stockTakesFromMaterials(
        [
          {'db_name': '유니온', 'type': 'FITTING', 'qty_ea': 4},
        ],
        barLengthByName: {'유니온': 3000},
      );
      expect(takes.first.qty, 4);
      expect(takes.first.unit, 'EA');
    });
  });

  group('차감 결과 알림 글', () {
    const t = StockTake(name: '튜브 3/8"', qty: 1, unit: '본');

    test('재고보다 많이 빼면 마이너스가 됐다고 알려 준다', () {
      const r = StockDeductResult(
        done: [t],
        missing: [],
        negative: {'튜브 3/8"': -2},
      );
      expect(r.message, contains('마이너스'));
      expect(r.allDone, isTrue);
    });

    test('통신이 안 되면 "재고에 없다"고 잘라 말하지 않는다', () {
      const r = StockDeductResult(done: [], missing: [t], offline: true);
      expect(r.message, contains('통신'));
      expect(r.message, isNot(contains('자재 목록에서 먼저')));
    });

    test('통신이 될 때만 재고에 없다고 알려 준다', () {
      const r = StockDeductResult(done: [], missing: [t]);
      expect(r.message, contains('재고에 없는 자재'));
    });

    test('뺄 것이 없으면 그렇게 알려 준다', () {
      const r = StockDeductResult(done: [], missing: []);
      expect(r.message, '차감할 자재가 없습니다.');
    });
  });

  group('튜브 자재 이름을 규격별로', () {
    test('규격이 이름에 들어간다', () {
      expect(tubeMaterialName('3/8"'), '튜브 3/8"');
      expect(tubeMaterialName('1/2"'), '튜브 1/2"');
    });

    test('규격이 없으면 규격 미지정으로 둔다', () {
      expect(tubeMaterialName(''), '튜브 (규격 미지정)');
      expect(tubeMaterialName('   '), '튜브 (규격 미지정)');
    });

    test('규격이 다르면 자재 줄이 따로 쌓인다', () {
      final merged = mergeMaterialsUsage(
        [],
        0,
        [],
        tubeLengthBySize: {'3/8"': 3000, '1/2"': 1500},
      );
      final tubes = merged.where((m) => m['type'] == 'TUBE').toList();
      expect(tubes.length, 2);
      expect(
        tubes.map((m) => m['db_name']).toSet(),
        {'튜브 3/8"', '튜브 1/2"'},
      );
    });

    test('같은 규격을 또 쓰면 한 줄에 더해진다', () {
      var merged = mergeMaterialsUsage([], 0, [], tubeLengthBySize: {
        '3/8"': 3000,
      });
      merged = mergeMaterialsUsage(merged, 0, [], tubeLengthBySize: {
        '3/8"': 2000,
      });
      final tubes = merged.where((m) => m['type'] == 'TUBE').toList();
      expect(tubes.length, 1);
      expect(tubes.first['qty_mm'], 5000);
    });

    test('규격별로 더했다 빼면 원래대로 돌아온다', () {
      final merged = mergeMaterialsUsage(
        [],
        0,
        [],
        tubeLengthBySize: {'3/8"': 3000, '1/2"': 1500},
      );
      final back = subtractMaterialsUsage(
        merged,
        0,
        [],
        tubeLengthBySize: {'3/8"': 3000, '1/2"': 1500},
      );
      expect(back.where((m) => m['type'] == 'TUBE'), isEmpty);
    });

    test('옛 자료(TUBE (기본))도 규격 없이 빼면 그대로 빠진다', () {
      final old = [
        {'db_name': kLegacyTubeMaterialName, 'type': 'TUBE', 'qty_mm': 4500.0},
      ];
      final back = subtractMaterialsUsage(old, 1500, []);
      expect(back.first['qty_mm'], 3000.0);
    });

    test('규격을 모르면 옛 자료 줄에 그대로 쌓인다', () {
      final old = [
        {'db_name': kLegacyTubeMaterialName, 'type': 'TUBE', 'qty_mm': 3000.0},
      ];
      final merged = mergeMaterialsUsage(old, 1500, []);
      final tubes = merged.where((m) => m['type'] == 'TUBE').toList();
      expect(tubes.length, 1);
      expect(tubes.first['qty_mm'], 4500.0);
    });
  });
}
