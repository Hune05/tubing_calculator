// 압력시험 불합격 사유의 경과 시간은 반올림하지 않는다(10-08: 9분 58초가 "10분: 10분 미만"으로 보였다).
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_calc.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/pressure_units.dart';
import 'package:tubing_calculator/src/presentation/pressure_test/test_record.dart';

void main() {
  test('유지시간에 조금 못 미치면 사유의 경과 시간이 유지시간보다 작게 보인다', () {
    const v = PtVerdict(
      medium: TestMedium.hydro,
      started: true,
      ended: true,
      elapsedMin: 9 + 58 / 60,
      requiredMin: 10,
      leakOk: true,
    );
    expect(v.holdMet, isFalse);
    final r = v.reasons(PUnit.values.first).first;
    expect(r, contains('경과 시간 9.9분'));
    expect(r, isNot(contains('경과 시간 10분')));
  });
}
