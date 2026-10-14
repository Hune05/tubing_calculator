// 10-14 전선관 규격 표기: 저장값 '22mm'는 그대로, 보여 줄 때는 한국 현장 말 '22C'.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_field_data.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_marking_logic.dart';

void main() {
  test("'22mm' → '22C', 다른 모양은 그대로", () {
    expect(conduitSizeLabel('22mm'), '22C');
    expect(conduitSizeLabel('16mm'), '16C');
    expect(conduitSizeLabel(' 28 mm '), '28C');
    expect(conduitSizeLabel('1/2"'), '1/2"');
    expect(conduitSizeLabel(''), '');
    expect(conduitSizeLabel(null), '');
  });

  test('마킹지 규격 줄도 22C로', () {
    final rows = conduitMarkingSheetSpecs({
      'benderType': 'ram',
      'manufacturer': 'UDT',
      'conduitType': 'Rigid',
      'conduitSize': '22mm',
      'gain': 40.0,
      'clr': 114.3,
      'springback': 3.0,
      'applySpringback': true,
    });
    final spec = rows.firstWhere((r) => r.$1 == '규격');
    expect(spec.$2, 'Rigid 22C');
  });
}
