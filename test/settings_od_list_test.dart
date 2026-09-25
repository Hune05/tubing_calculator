// 설정의 튜브 바깥지름 목록: 저장된 값이 목록에 없어도 첫 값(3.0)으로 떨어지지 않는다.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/settings/controllers/settings_controller.dart';

void main() {
  test('mm 목록에 없는 12.7(1/2")을 끼워 넣고 크기 순으로 둔다', () {
    final l = SettingsController.odListIncluding(false, '12.7');
    expect(l, contains('12.7'));
    final i = l.indexOf('12.7');
    expect(double.parse(l[i - 1]), lessThan(12.7));
    expect(double.parse(l[i + 1]), greaterThan(12.7));
    expect(l.first, '3.0'); // 첫 값이 바뀐 게 아니라 끼워 넣은 것
  });

  test('이미 있는 값·잘못된 값이면 목록 그대로', () {
    final base = SettingsController.getOdList(false);
    expect(SettingsController.odListIncluding(false, '6.0'), base);
    expect(SettingsController.odListIncluding(false, ''), base);
    expect(SettingsController.odListIncluding(false, '0'), base);
  });

  test('inch 목록도 같은 방식', () {
    expect(SettingsController.odListIncluding(true, '0.5'), contains('0.5'));
    expect(SettingsController.odListIncluding(true, '1.25'), contains('1.25'));
  });
}
