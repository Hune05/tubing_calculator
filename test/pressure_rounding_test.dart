// 압력 시험 기준값 글(8차, 10-09): 최소 시험압력("이상")은 올리고, 최대·허용치("이하"·"이내")는 내린다.
// MPa는 셋째 자리까지 보인다(예전에는 1.035 MPa가 "1.03 이상"으로 보여 그대로 하면 불합격).
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_units.dart';

void main() {
  test('최소값은 올려 보인다', () {
    expect(ptPressureUp(1035, PUnit.mpa), '1.035 MPa');
    expect(ptPressureUp(1035.4, PUnit.mpa), '1.036 MPa');
    expect(ptPressureUp(1696.13, PUnit.bar), '16.97 bar');
    expect(ptPressureUp(1500, PUnit.bar), '15 bar'); // 딱 맞는 값은 그대로
    expect(ptPressureUp(1030, PUnit.mpa), '1.03 MPa');
  });

  test('최대·허용값은 내려 보이고, 작은 허용 강하도 뭉개지지 않는다', () {
    expect(ptPressureDown(5, PUnit.bar), '0.05 bar');
    expect(ptPressureDown(3.5, PUnit.mpa), '0.0035 MPa');
    expect(ptPressureDown(2069.9, PUnit.bar), '20.69 bar');
  });

  test('보통 값 글: MPa는 셋째 자리까지', () {
    expect(ptPressure(1035, PUnit.mpa), '1.035 MPa');
    expect(ptPressure(700, PUnit.bar), '7 bar');
    expect(ptDrop(-10, PUnit.bar), '0.1 bar 상승');
  });
}
