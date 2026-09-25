// UI·UX 점검 묶음 U-A(숫자·자료) 고침 확인.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/mobile_inventory_logs_page.dart';

void main() {
  test('X2 재고 실사 기록: 부호대로 −3/+2, 부호 없는 예전 기록만 =', () {
    // 예전: 10→7로 고쳐도 "=3"(3개로 맞춤)처럼 보였다.
    expect(auditQtyPrefix({'qty': 3, 'sign': '-'}), '−');
    expect(auditQtyPrefix({'qty': 2, 'sign': '+'}), '+');
    expect(auditQtyPrefix({'qty': 5}), '=');
  });
}
