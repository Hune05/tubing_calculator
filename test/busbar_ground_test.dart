import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_ground.dart';

void main() {
  test('구멍 수로: 길이 = 2e + (n−1)p, 위치는 e부터 피치씩', () {
    final p = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 25,
      count: 5,
    );
    expect(p.length, closeTo(50 + 4 * 25.4, 1e-9));
    expect(p.positions.first, 25);
    expect(p.positions.last, closeTo(25 + 4 * 25.4, 1e-9));
    expect(p.endRight, closeTo(25, 1e-9));
    expect(p.centerLine, 25);
    expect(p.ok, isTrue);
  });

  test('길이로: 들어가는 만큼 뚫고 남는 길이는 양 끝에 반씩', () {
    final p = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 20,
      length: 300,
    );
    // (300 − 40) ÷ 25.4 = 10.23 → 10칸, 11개
    expect(p.holes, 11);
    final rest = 300 - (40 + 10 * 25.4);
    expect(p.endLeft, closeTo(20 + rest / 2, 1e-9));
    expect(p.endLeft, closeTo(p.endRight, 1e-9));
  });

  test('딱 맞는 길이는 부동소수 오차로 한 개 줄지 않는다', () {
    final p = groundBar(
      t: 5,
      w: 40,
      holeDia: 9,
      pitch: 25.4,
      endDist: 20,
      length: 40 + 3 * 25.4,
    );
    expect(p.holes, 4);
  });

  test('무게: 구멍 뺀 부피 × 8.9 g/cm³', () {
    final p = groundBar(
      t: 6,
      w: 50,
      holeDia: 10,
      pitch: 30,
      endDist: 20,
      count: 3,
    ); // 길이 100
    final vol = 6 * 50 * 100 - 3 * 3.141592653589793 / 4 * 100 * 6;
    expect(p.weightKg, closeTo(vol * 8.9e-6, 1e-9));
  });

  test('겹침·폭·끝 면 문제를 알린다', () {
    expect(
      groundBar(
        t: 6,
        w: 50,
        holeDia: 11.1,
        pitch: 10,
        endDist: 20,
        count: 3,
      ).problems,
      contains('구멍 피치가 구멍 지름 이하라 구멍이 서로 겹칩니다.'),
    );
    expect(
      groundBar(
        t: 6,
        w: 10,
        holeDia: 11.1,
        pitch: 30,
        endDist: 20,
        count: 2,
      ).ok,
      isFalse,
    );
    expect(
      groundBar(t: 6, w: 50, holeDia: 11.1, pitch: 30, endDist: 3, count: 2).ok,
      isFalse,
    );
    expect(
      groundBar(
        t: 6,
        w: 50,
        holeDia: 11.1,
        pitch: 30,
        endDist: 20,
        length: 30,
      ).holes,
      0,
    );
  });
}
