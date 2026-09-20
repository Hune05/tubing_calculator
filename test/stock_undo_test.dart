import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_stock_deduct.dart';

void main() {
  group('불출로 이미 나가 있는 자재 알림', () {
    const tube = StockTake(name: '튜브 3/8"', qty: 2, unit: '본');
    const union = StockTake(name: '[HY-LOK] 3/8" Union', qty: 4, unit: 'EA');

    test('불출 중인 자재가 없으면 알림이 없다', () {
      expect(doubleDeductWarning([tube, union], const {}), '');
    });

    test('불출 중인 자재가 있으면 이름과 수량을 알려 준다', () {
      final msg = doubleDeductWarning([tube, union], {'튜브 3/8"': 3});
      expect(msg, contains('튜브 3/8" 3본'));
      expect(msg, contains('두 번'));
      // 불출 중이 아닌 자재는 끼지 않는다.
      expect(msg, isNot(contains('Union')));
    });

    test('여러 건이면 줄을 나눠 보여 준다', () {
      final msg = doubleDeductWarning([tube, union], {
        '튜브 3/8"': 3,
        '[HY-LOK] 3/8" Union': 5,
      });
      expect(msg.split('\n').length, greaterThanOrEqualTo(4));
      expect(msg, contains('[HY-LOK] 3/8" Union 5EA'));
    });

    test('수량이 0이면 나가 있는 것이 아니다', () {
      expect(doubleDeductWarning([tube], {'튜브 3/8"': 0}), '');
    });

    test('이름 앞뒤 빈칸은 무시한다', () {
      const t = StockTake(name: '  튜브 3/8"  ', qty: 1, unit: '본');
      final msg = doubleDeductWarning([t], {'튜브 3/8"': 2});
      expect(msg, contains('2본'));
    });
  });
}
