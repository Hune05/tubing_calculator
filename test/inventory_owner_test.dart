// 재고 주인(내 것·공용·남의 것) 가르기.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/inventory_owner.dart';

void main() {
  const me = 'uid-me';
  final shared = <String, dynamic>{'name': '유니온'};
  final mine = <String, dynamic>{'name': '유니온', 'ownerUid': me};
  final others = <String, dynamic>{'name': '유니온', 'ownerUid': 'uid-other'};

  test('주인 칸이 없으면 공용(예전 재고)', () {
    expect(isSharedStock(shared), isTrue);
    expect(isSharedStock({'ownerUid': ''}), isTrue);
    expect(isSharedStock(mine), isFalse);
  });

  test('남의 개인 재고는 안 보인다', () {
    expect(canSeeStock(shared, me), isTrue);
    expect(canSeeStock(mine, me), isTrue);
    expect(canSeeStock(others, me), isFalse);
  });

  test('로그인을 안 했으면 공용만 보인다', () {
    expect(canSeeStock(shared, null), isTrue);
    expect(canSeeStock(mine, null), isFalse);
    expect(isMyStock(mine, ''), isFalse);
  });

  test('칩: 전체·내 것·공용', () {
    expect(matchesStockScope(mine, me, StockScope.all), isTrue);
    expect(matchesStockScope(shared, me, StockScope.all), isTrue);
    expect(matchesStockScope(others, me, StockScope.all), isFalse);
    expect(matchesStockScope(mine, me, StockScope.mine), isTrue);
    expect(matchesStockScope(shared, me, StockScope.mine), isFalse);
    expect(matchesStockScope(shared, me, StockScope.shared), isTrue);
    expect(matchesStockScope(mine, me, StockScope.shared), isFalse);
  });

  test('같은 이름이면 내 것 → 공용, 남의 것은 안 씀', () {
    expect(stockPreference(mine, me), 0);
    expect(stockPreference(shared, me), 1);
    expect(stockPreference(others, me), isNull);
  });

  test('새 재고 주인 칸', () {
    expect(stockOwnerFields(shared: true, uid: me, name: '홍'), isEmpty);
    expect(stockOwnerFields(shared: false, uid: null, name: '홍'), isEmpty);
    expect(stockOwnerFields(shared: false, uid: me, name: '홍'), {
      'ownerUid': me,
      'ownerName': '홍',
    });
    expect(stockOwnerFields(shared: false, uid: me), {'ownerUid': me});
  });
}
