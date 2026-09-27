// 홈 날씨 자동 갱신(2026-09-27): 언제 다시 받고, 언제 기준 시각을 적는지.
import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/menu/page/mobile_menu_page.dart';

void main() {
  final t0 = DateTime(2026, 9, 27, 9, 0);

  test('한 번도 못 받았으면 낡았다고 보지 않는다(처음 받기는 따로 한다)', () {
    expect(weatherIsOld(null, t0), isFalse);
    expect(weatherIsStale(null, t0), isFalse);
  });

  test('받은 지 30분이 안 되면 그대로 두고, 30분이 되면 다시 받는다', () {
    expect(kWeatherRefreshEvery, const Duration(minutes: 30));
    expect(
      weatherIsOld(t0, t0.add(const Duration(minutes: 29, seconds: 59))),
      isFalse,
    );
    expect(weatherIsOld(t0, t0.add(const Duration(minutes: 30))), isTrue);
  });

  test('자동 갱신이 계속 실패해 한 시간이 넘으면 기준 시각을 적는다', () {
    expect(weatherIsStale(t0, t0.add(const Duration(minutes: 59))), isFalse);
    expect(weatherIsStale(t0, t0.add(const Duration(hours: 1))), isTrue);
  });
}
