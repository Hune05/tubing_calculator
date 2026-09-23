// 재고조사를 올릴 때 "센 값 − 셀 때 장부 값"만 더하고 빼는 셈.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/audit_delta.dart';

void main() {
  group('재고조사 차이만 올리기', () {
    test('센 뒤 움직인 것이 없으면 센 값이 된다', () {
      final r = auditDelta(counted: 8, book: 10, server: 10);
      expect(r.delta, -2);
      expect(r.after, 8);
      expect(r.movedSinceCount, 0);
    });

    test('센 뒤 컷팅에서 뺀 것은 지우지 않는다', () {
      // 창고에서 10을 8로 셈 → 낮에 컷팅이 3을 뺌(서버 7) → 저녁에 올림.
      final r = auditDelta(counted: 8, book: 10, server: 7);
      expect(r.delta, -2);
      expect(r.after, 5);
      expect(r.movedSinceCount, -3);
    });

    test('센 값이 장부와 같으면 수량은 안 건드린다', () {
      final r = auditDelta(counted: 10, book: 10, server: 7);
      expect(r.delta, 0);
      expect(r.after, 7);
    });

    test('장부를 모르면 예전처럼 센 값으로 맞춘다', () {
      final r = auditDelta(counted: 8, book: null, server: 7);
      expect(r.delta, 1);
      expect(r.after, 8);
      expect(r.movedSinceCount, 0);
    });

    test('0 아래로 내려가면 0에서 멈춘다', () {
      final r = auditDelta(counted: 2, book: 5, server: 1);
      expect(r.after, 0);
      expect(r.delta, -1);
      expect(r.clamped, isTrue);
    });
  });
}
