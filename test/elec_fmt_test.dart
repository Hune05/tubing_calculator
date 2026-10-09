// 전기 탭 공용 숫자 글: 셀 수 없는 값은 "—"(8차, 10-09: "Infinity %"가 그대로 보였다).
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_form_parts.dart';

void main() {
  test('보통 값은 뒤 0을 떼고, 무한대·NaN은 —', () {
    expect(fmt(12.50, 2), '12.5');
    expect(fmt(3, 0), '3');
    expect(fmt(double.infinity), '—');
    expect(fmt(-double.infinity, 2), '—');
    expect(fmt(double.nan), '—');
    expect(fmt((5.0 - 4.0) / 0 * 100, 1), '—');
  });
}
