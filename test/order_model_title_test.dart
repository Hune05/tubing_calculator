import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/data/models/cart_item_model.dart';
import 'package:tubing_calculator/src/data/models/order_model.dart';

OrderModel _order(List<CartItemModel> items) => OrderModel(
  id: 'o1',
  requester: '가',
  assignee: '나',
  items: items,
  status: '발주 대기',
  requestDate: DateTime(2026, 9, 22),
);

CartItemModel _item(String t, String q) =>
    CartItemModel(title: t, qty: q, type: '일반 자재');

void main() {
  test('발주 카드 제목: 품목이 없는 예전 문서도 오류 없이 보인다', () {
    expect(_order([]).mainTitle, '품목 없음');
    expect(_order([_item('유니온 1/2', '3')]).mainTitle, '유니온 1/2');
    expect(
      _order([_item('유니온 1/2', '3'), _item('엘보 1/2', '2')]).mainTitle,
      '유니온 1/2 외 1건',
    );
  });

  test('품목 없는 문서를 서버 모양에서 읽어도 제목이 나온다', () {
    final o = OrderModel.fromMap({'status': '발주 대기'}, 'x');
    expect(o.items, isEmpty);
    expect(o.mainTitle, '품목 없음');
    expect(o.firstItemTitle, '품목 없음');
    expect(o.firstItemQty, '');
  });
}
