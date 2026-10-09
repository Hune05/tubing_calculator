// 10-09: 튜브 설정에서 mm/inch를 누르면 외경이 늘 1/2"·12.7로 바뀌어, 10mm 관을 보다가 inch를 눌렀다
// 돌아오면 12.7이 되고 앞 관의 MAN 값이 남았다 → 같은 관의 다른 단위 값으로.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/settings/controllers/settings_controller.dart';

void main() {
  test('inch → mm는 같은 관(0.5 → 12.7, 0.375 → 9.53, 1.0 → 25.4)', () {
    expect(SettingsController.sameTubeOdInOtherUnit('0.5', toInch: false), '12.7');
    expect(SettingsController.sameTubeOdInOtherUnit('0.375', toInch: false), '9.53');
    expect(SettingsController.sameTubeOdInOtherUnit('1.0', toInch: false), '25.4');
    expect(SettingsController.sameTubeOdInOtherUnit('0.25', toInch: false), '6.35');
  });

  test('mm → inch는 같은 인치 관이 있을 때만(12.7 → 0.5), 10mm 관은 없음', () {
    expect(SettingsController.sameTubeOdInOtherUnit('12.7', toInch: true), '0.5');
    expect(SettingsController.sameTubeOdInOtherUnit('9.53', toInch: true), '0.375');
    expect(SettingsController.sameTubeOdInOtherUnit('10.0', toInch: true), isNull);
    expect(SettingsController.sameTubeOdInOtherUnit('', toInch: true), isNull);
  });

  test('왕복하면 제자리(0.5 → 12.7 → 0.5)', () {
    final mm = SettingsController.sameTubeOdInOtherUnit('0.5', toInch: false)!;
    expect(SettingsController.sameTubeOdInOtherUnit(mm, toInch: true), '0.5');
  });
}
