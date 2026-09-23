// 지난 재고조사 뒤로 자재가 얼마나 드나들었는지 세는 셈.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/usage_since_count.dart';

Map<String, dynamic> log(
  String name, {
  String type = 'OUT',
  String action = '',
  int qty = 1,
}) => {
  'material_name': name,
  'type': type,
  'action': action,
  'qty': qty,
};

void main() {
  group('드나듦 세기', () {
    test('나간 것을 더한다', () {
      final r = usageSinceLastCount([
        log('유니온', qty: 3),
        log('유니온', qty: 2),
      ]);
      expect(r['유니온']!.out, 5);
      expect(r['유니온']!.inQty, 0);
      expect(r['유니온']!.hasLastCount, isFalse);
    });

    test('재고조사를 만나면 거기서 멈춘다', () {
      final r = usageSinceLastCount([
        log('유니온', qty: 3), // 재고조사 뒤
        log('유니온', action: '재고 실사', type: 'IN', qty: 10),
        log('유니온', qty: 99), // 재고조사 전 — 세지 않는다
      ]);
      expect(r['유니온']!.out, 3);
      expect(r['유니온']!.hasLastCount, isTrue);
    });

    test('자재마다 따로 센다', () {
      final r = usageSinceLastCount([
        log('유니온', qty: 3),
        log('유니온', action: '재고 실사', qty: 10),
        log('튜브', qty: 7),
      ]);
      expect(r['유니온']!.out, 3);
      expect(r['유니온']!.hasLastCount, isTrue);
      expect(r['튜브']!.out, 7);
      expect(r['튜브']!.hasLastCount, isFalse);
    });

    test('들어온 것도 센다', () {
      final r = usageSinceLastCount([
        log('유니온', type: 'IN', action: '차감 되돌림', qty: 2),
        log('유니온', qty: 5),
      ]);
      expect(r['유니온']!.out, 5);
      expect(r['유니온']!.inQty, 2);
      expect(r['유니온']!.net, 3);
    });

    test('PC 반납(RETURN)도 들어온 것으로 센다', () {
      final r = usageSinceLastCount([
        log('유니온', type: 'RETURN', qty: 4),
        log('유니온', qty: 5),
      ]);
      expect(r['유니온']!.out, 5);
      expect(r['유니온']!.inQty, 4);
    });

    test('자재를 새로 넣거나 지운 기록은 드나듦이 아니다', () {
      final r = usageSinceLastCount([
        log('유니온', action: '자재 등록', qty: 0),
        log('유니온', action: '목록에서 삭제', qty: 5),
      ]);
      expect(r['유니온'], isNull);
    });

    test('드나든 것이 없으면 아예 넣지 않는다', () {
      final r = usageSinceLastCount([
        log('유니온', action: '재고 실사', qty: 10),
      ]);
      expect(r, isEmpty);
    });

    test('이름이 없는 기록은 건너뛴다', () {
      final r = usageSinceLastCount([log('', qty: 3)]);
      expect(r, isEmpty);
    });

    test('수량이 0이면 세지 않는다', () {
      final r = usageSinceLastCount([log('유니온', qty: 0)]);
      expect(r, isEmpty);
    });
  });

  group('재고조사 화면에 붙일 글', () {
    test('나가기만 했을 때', () {
      const u = UsageSinceCount(out: 5, inQty: 0, hasLastCount: true);
      expect(u.note, '지난 재고조사 뒤 5 나감');
    });

    test('들어오기만 했을 때', () {
      const u = UsageSinceCount(out: 0, inQty: 2, hasLastCount: true);
      expect(u.note, '지난 재고조사 뒤 2 들어옴');
    });

    test('둘 다 있을 때', () {
      const u = UsageSinceCount(out: 5, inQty: 2, hasLastCount: true);
      expect(u.note, '지난 재고조사 뒤 5 나가고 2 들어옴');
    });

    test('지난 재고조사가 없으면 그렇게 적는다', () {
      const u = UsageSinceCount(out: 5, inQty: 0, hasLastCount: false);
      expect(u.note, '기록에 남은 것만 5 나감');
    });

    test('드나든 것이 없으면 빈 글', () {
      const u = UsageSinceCount(out: 0, inQty: 0, hasLastCount: true);
      expect(u.note, '');
    });
  });
}
