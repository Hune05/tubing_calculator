import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_bend.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_bender_profile.dart';

void main() {
  test('k 역산: 엔진으로 만든 자르는 길이를 다시 넣으면 같은 k가 나온다', () {
    for (final k in [0.33, 0.4, 0.45, 0.5]) {
      final p = busbarL(d: 6, r: 6, k: k, a: 100, b: 80, deg: 90);
      final back = benderKFromTest(
        t: 6,
        r: 6,
        a: 100,
        b: 80,
        flat: p.cutLength,
      );
      expect(back, closeTo(k, 1e-9));
    }
    // 90°가 아닌 각도도 같다
    final p45 = busbarL(d: 5, r: 8, k: 0.38, a: 120, b: 90, deg: 60);
    expect(
      benderKFromTest(t: 5, r: 8, a: 120, b: 90, flat: p45.cutLength, deg: 60),
      closeTo(0.38, 1e-9),
    );
  });

  test('실제가 계산보다 짧으면 k가 작아진다(손 계산: 6mm, r6, 100×100)', () {
    // BD = 24 − (π/2)(6 + 6k). 실제 길이 190 → BD 10 → k = ((24 − 10)/(π/2) − 6)/6
    final k = benderKFromTest(t: 6, r: 6, a: 100, b: 100, flat: 190)!;
    expect(k, closeTo(((24 - 10) / (3.141592653589793 / 2) - 6) / 6, 1e-9));
  });

  test('말이 안 되는 입력은 null', () {
    expect(benderKFromTest(t: 0, r: 6, a: 100, b: 100, flat: 190), isNull);
    expect(benderKFromTest(t: 6, r: 6, a: 100, b: 100, flat: 0), isNull);
  });

  test('스프링백 비율과 기계 세팅 각도', () {
    expect(benderSpringRatio(95, 90), closeTo(95 / 90, 1e-9));
    expect(benderMachineAngle(90, 95 / 90), closeTo(95, 1e-9));
    expect(benderSpringRatio(90, 0), isNull);
    expect(benderSpringRatio(90, 30), isNull); // 비율 범위(0.8~1.5) 밖
  });

  test('프로필 JSON 왕복과 잘못된 값 무시', () {
    const p = BenderProfile(name: 'A벤더', radius: 8, k: 0.37, spring: 1.04);
    final back = BenderProfile.fromJson(p.toJson())!;
    expect(back.name, 'A벤더');
    expect(back.radius, 8);
    expect(back.k, 0.37);
    expect(back.spring, 1.04);
    expect(BenderProfile.fromJson({'name': 'x'}), isNull);
    expect(BenderProfile.fromJson('x'), isNull);
    expect(
      BenderProfile.fromJson({'name': 'x', 'r': 5, 'k': 0.4})!.spring,
      1.0,
    );
  });
}
