import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/inventory_view_logic.dart';

void main() {
  group('자재 규격 칸', () {
    test("등록 화면이 저장한 'spec'을 읽는다", () {
      expect(inventorySpecOf({'spec': '3/8"'}), '3/8"');
    });

    test("예전 자료의 'size'도 읽는다", () {
      expect(inventorySpecOf({'size': '1/2"'}), '1/2"');
    });

    test('둘 다 없으면 빈 글', () {
      expect(inventorySpecOf({'name': '유니온'}), '');
    });

    test('규격과 위치를 한 줄로 붙인다', () {
      expect(
        inventorySpecAndPlace({'spec': '3/8"', 'location': 'H-2 자재렉'}),
        '3/8"  |  H-2 자재렉',
      );
    });

    test('규격이 없으면 위치만 보여 준다(빈칸 - 안 붙인다)', () {
      expect(inventorySpecAndPlace({'location': 'H-2 자재렉'}), 'H-2 자재렉');
    });

    test('둘 다 없으면 미기재라고 적는다', () {
      expect(inventorySpecAndPlace({}), '규격·위치 미기재');
    });
  });

  group('내 불출 목록 사람 맞추기', () {
    test('이름이 같으면 내 것', () {
      expect(isSameWorker('차재훈', '차재훈'), isTrue);
    });

    test('팀 이름이 붙어도 내 것', () {
      expect(isSameWorker('차재훈', '생산팀 차재훈'), isTrue);
      expect(isSameWorker('생산팀 차재훈', '차재훈'), isTrue);
    });

    test('띄어쓰기만 다른 것도 내 것', () {
      expect(isSameWorker('생산팀차재훈', '생산팀 차재훈'), isTrue);
    });

    test('남의 이름은 아니다', () {
      expect(isSameWorker('차재훈', '홍길동'), isFalse);
    });

    test('이름이 비어 있으면 감추지 않는다', () {
      expect(isSameWorker('차재훈', null), isTrue);
      expect(isSameWorker('', '홍길동'), isTrue);
    });
  });

  group('모자란 자재', () {
    test('최소 수량까지 내려오면 모자란 것으로 본다', () {
      expect(isShortStock({'qty': 1, 'minQty': 1}), isTrue);
      expect(isShortStock({'qty': 0, 'minQty': 5}), isTrue);
    });

    test('최소 수량보다 많으면 아니다', () {
      expect(isShortStock({'qty': 6, 'minQty': 5}), isFalse);
    });

    test('최소 수량을 안 적어 뒀으면 따지지 않는다', () {
      expect(isShortStock({'qty': 0}), isFalse);
      expect(isShortStock({'qty': 0, 'minQty': 0}), isFalse);
    });
  });

  group('잔재 줄 순서', () {
    test('규격 이름순으로 묶는다', () {
      expect(compareLeftoverRow('앵글', 100, '찬넬', 100) < 0, isTrue);
    });

    test('같은 규격은 긴 것이 먼저다', () {
      expect(compareLeftoverRow('찬넬', 2000, '찬넬', 500) < 0, isTrue);
    });
  });
}
