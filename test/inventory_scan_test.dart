// 바코드로 자재 찾기: 찾은 개수에 따라 하나면 열고, 없으면 알리고, 여럿이면 목록에 둔다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/inventory_view_logic.dart';

void main() {
  test('찾은 개수에 따른 동작', () {
    expect(scanFindOutcome(0), ScanFindOutcome.none);
    expect(scanFindOutcome(1), ScanFindOutcome.open);
    expect(scanFindOutcome(2), ScanFindOutcome.many);
    expect(scanFindOutcome(50), ScanFindOutcome.many);
  });
}
