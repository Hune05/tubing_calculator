// 홈 화면 "재고 부족" 배지(필드 헬퍼 2번): 최소 수량 아래로 내려간 자재만 센다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/low_stock_count.dart';

void main() {
  group('countLowStock', () {
    test('최소 수량을 정한 것 중 그 아래로 내려간 것만 센다', () {
      final docs = [
        {'qty': 2, 'minQty': 5}, // 부족
        {'qty': 10, 'minQty': 5}, // 충분
        {'qty': 0, 'minQty': 0}, // 최소 수량 안 정함 → 안 침
      ];
      expect(countLowStock(docs, 'me'), 1);
    });

    test('남의 개인 재고는 부족해도 세지 않는다(공용·내 것만)', () {
      final docs = [
        {'qty': 1, 'minQty': 5, 'ownerUid': '남'}, // 남의 것
        {'qty': 1, 'minQty': 5, 'ownerUid': 'me'}, // 내 것
        {'qty': 1, 'minQty': 5}, // 공용
      ];
      expect(countLowStock(docs, 'me'), 2);
    });

    test('예전 태블릿 등록(min_qty)도 같이 본다', () {
      final docs = [
        {'qty': 1, 'min_qty': 5},
      ];
      expect(countLowStock(docs, 'me'), 1);
    });

    test('아무것도 부족하지 않으면 0', () {
      expect(countLowStock(const [], 'me'), 0);
    });
  });
}
