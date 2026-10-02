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

  test('왼쪽 끝 L 꺾기: 꺾기 끝선에서 끝 여유를 재고 꺾기 선 · 길이가 절곡 계산과 같다', () {
    final p = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 25,
      count: 4,
      tabLeft: 40,
    );
    // ρ = 8.4, 물림 8.4, 바깥 40 → 중립 36.4, 곧은 28, 호 13.195
    final arc = 8.4 * 3.141592653589793 / 2;
    expect(p.bends.single.start, closeTo(28, 1e-9));
    expect(p.bends.single.end, closeTo(28 + arc, 1e-9));
    expect(p.positions.first, closeTo(28 + arc + 25, 1e-9));
    expect(p.length, closeTo(28 + arc + 126.2, 1e-9));
    expect(p.bendPlan!.cutLength, closeTo(p.length, 1e-9));
    expect(p.startHeading, -90);
  });

  test('양쪽 끝 L 꺾기 · 길이로 정하기: 곧은 구간에 구멍을 넣고 오른쪽 꺾기 선이 뒤에 온다', () {
    final p = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 20,
      length: 400,
      tabLeft: 40,
      tabRight: 40,
    );
    expect(p.bends.length, 2);
    expect(p.bendPlan!.cutLength, closeTo(400, 1e-9));
    expect(p.bends[1].end, lessThan(400));
    expect(p.positions.last, lessThan(p.flatEnd));
    expect(p.endLeft, closeTo(p.endRight, 1e-9));
  });

  test('탭이 너무 짧으면 알린다', () {
    final p = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 25,
      count: 3,
      tabRight: 8,
    );
    expect(p.ok, isFalse);
  });

  test('모자: 길이 = 2F + 2H + W − 4BD, 곧은 구간 · 꺾기 4곳 · 시작/끝선', () {
    // t 6, r 6, k 0.4: BD = 2·12 − (π/2)·8.4 = 10.805, OS = 12
    const bd = 2 * 12 - 3.141592653589793 / 2 * 8.4;
    final p = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 25,
      count: 4,
      hat: true,
      hatHeight: 40,
      hatFlange: 40,
    );
    final w = 126.2 + 2 * 12; // 몸체 바깥 폭
    expect(p.hatWidth, closeTo(w, 1e-9));
    expect(p.length, closeTo(2 * 40 + 2 * 40 + w - 4 * bd, 1e-9));
    expect(p.bends.length, 4);
    expect(p.bends.first.start, closeTo(40 - 12, 1e-9));
    expect(p.bendPlan!.cutLength, closeTo(p.length, 1e-9));
    expect(p.positions.first, closeTo(p.bends[1].end + 25, 1e-9));
    expect(p.ok, isTrue);
  });

  test('챙 구멍: 평평한 길이 가운데, 오른쪽은 오른쪽 끝에서 같은 거리', () {
    final p = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 25,
      count: 4,
      hat: true,
      hatHeight: 40,
      hatFlange: 50,
      tabHoleCount: 1,
      tabHoleDia: 11.1,
      tabHolePitch: 25.4,
    );
    // 평평한 길이 50 − 12 = 38 → 구멍 중심 19
    expect(p.tabHoles.length, 2);
    expect(p.tabHoles.first, closeTo(19, 1e-9));
    expect(p.tabHoles.last, closeTo(p.length - 19, 1e-9));
  });

  test('탭 구멍이 안 들어가면 알린다', () {
    final p = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 25,
      count: 3,
      tabLeft: 25,
      tabHoleCount: 2,
      tabHoleDia: 11.1,
      tabHolePitch: 25.4,
    );
    expect(p.ok, isFalse);
  });
}
