// 자재 이름이 조금 달라도 재고에서 찾아야 한다.
// 예전에는 빈칸 하나, 따옴표 모양 하나만 달라도 "재고에 없는 자재"로 빠졌다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_stock_deduct.dart';

void main() {
  group('자재 이름 다듬기', () {
    test('앞뒤 빈칸을 없앤다', () {
      expect(normalizeMaterialName('  유니온 '), '유니온');
    });

    test('가운데 빈칸이 여럿이면 하나로 줄인다', () {
      expect(
        normalizeMaterialName('[HY-LOK]  3/8"   Union'),
        normalizeMaterialName('[HY-LOK] 3/8" Union'),
      );
    });

    test('따옴표 모양이 달라도 같게 본다', () {
      expect(
        normalizeMaterialName('[HY-LOK] 3/8” Union'),
        normalizeMaterialName('[HY-LOK] 3/8" Union'),
      );
      expect(
        normalizeMaterialName('[HY-LOK] 3/8″ Union'),
        normalizeMaterialName('[HY-LOK] 3/8" Union'),
      );
    });

    test('대소문자를 무시한다', () {
      expect(
        normalizeMaterialName('[hy-lok] 3/8" union'),
        normalizeMaterialName('[HY-LOK] 3/8" Union'),
      );
    });

    test('줄바꿈이나 탭도 빈칸으로 본다', () {
      expect(
        normalizeMaterialName('[HY-LOK]\t3/8"\nUnion'),
        normalizeMaterialName('[HY-LOK] 3/8" Union'),
      );
    });

    test('다른 자재는 다르게 본다', () {
      expect(
        normalizeMaterialName('[HY-LOK] 3/8" Union'),
        isNot(normalizeMaterialName('[HY-LOK] 1/2" Union')),
      );
    });
  });

  group('재고에서 자재 찾기', () {
    final stock = ['[HY-LOK] 3/8" Union', '튜브 3/8"', '찬넬 75x40x5'];
    final lookup = materialLookup(stock, (n) => n);

    test('똑같은 이름이면 그대로 찾는다', () {
      expect(findMaterial(lookup, '[HY-LOK] 3/8" Union'), stock[0]);
    });

    test('빈칸이 더 들어가도 찾는다', () {
      expect(findMaterial(lookup, '[HY-LOK]  3/8"  Union'), stock[0]);
    });

    test('따옴표 모양이 달라도 찾는다', () {
      expect(findMaterial(lookup, '[HY-LOK] 3/8” Union'), stock[0]);
    });

    test('없는 자재는 못 찾는다고 한다', () {
      expect(findMaterial(lookup, '[SWAGELOK] 3/8" Union'), isNull);
    });

    test('빈 이름은 못 찾는다', () {
      expect(findMaterial(lookup, '   '), isNull);
    });
  });

  group('한 본 길이·단위도 이름이 조금 달라도 찾는다', () {
    test('따옴표 모양이 달라도 한 본 길이를 읽는다', () {
      final takes = stockTakesFromMaterials(
        [
          {'db_name': '튜브 3/8”', 'type': 'TUBE', 'qty_mm': 7000},
        ],
        barLengthByName: {'튜브 3/8"': 3000},
      );
      expect(takes.first.qty, 3); // 3m로 나눠 3본
    });

    test('빈칸이 더 들어가도 세는 단위를 읽는다', () {
      final takes = stockTakesFromMaterials(
        [
          {'db_name': '튜브  3/8"', 'type': 'TUBE', 'qty_mm': 6500},
        ],
        unitByName: {'튜브 3/8"': 'm'},
      );
      expect(takes.first.unit, 'm');
      expect(takes.first.qty, 7);
    });
  });

  group('모자란 자재·불출 알림도 이름이 조금 달라도 본다', () {
    const take = StockTake(name: '[HY-LOK] 3/8” Union', qty: 5, unit: 'EA');

    test('모자란 것을 알아본다', () {
      final msg = shortStockWarning([take], {'[HY-LOK] 3/8" Union': 2});
      expect(msg, contains('창고에 2EA'));
    });

    test('불출 중인 것을 알아본다', () {
      final msg = doubleDeductWarning([take], {'[HY-LOK] 3/8" Union': 3});
      expect(msg, contains('3EA'));
    });
  });
}
