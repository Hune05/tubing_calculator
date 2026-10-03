import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_ground.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_lug.dart';

GroundBarPlan _bar({
  int lugHoles = 0,
  double lugSpacing = 25.4,
  int lugCount = 0,
  double lugPitch = 50,
  int rows = 1,
  int count = 10,
  double lugDia = 11.1,
}) => groundBar(
  t: 6,
  w: 50,
  holeDia: 11.1,
  pitch: 25.4,
  endDist: 25,
  count: count,
  rows: rows,
  rowGap: 30,
  lugHoles: lugHoles,
  lugSpacing: lugSpacing,
  lugCount: lugCount,
  lugPitch: lugPitch,
  lugHoleDia: lugDia,
);

void main() {
  test('러그 구멍은 접지 구멍을 쓰지 않고 따로 추가되고, 부스바 가운데에 놓인다(두 줄 사이)', () {
    final p = _bar(lugHoles: 2, lugCount: 2, rows: 2);
    expect(p.groundHoles.length, 20); // 접지 구멍은 그대로
    expect(p.lugHoleList.length, 4);
    final mid = p.length / 2;
    final xs = p.lugHoleList.map((h) => h.x).toList();
    expect((xs.first + xs.last) / 2, closeTo(mid, 1e-9));
    expect(p.lugHoleList.every((h) => h.y == 25), isTrue);
    // 러그 1: 가운데 − 25 ± 12.7
    expect(p.lugHoleList[0].x, closeTo(mid - 25 - 12.7, 1e-9));
    expect(p.lugHoleList[1].x, closeTo(mid - 25 + 12.7, 1e-9));
    expect(p.lugHoleList[2].x, closeTo(mid + 25 - 12.7, 1e-9));
    expect(p.lugHoleList[0].label, '러그 1-1');
    expect(p.ok, isTrue);
  });

  test('1구멍 러그는 구멍 하나씩, 이름은 러그 번호', () {
    final p = _bar(lugHoles: 1, lugCount: 3, rows: 2);
    expect(p.lugHoleList.map((h) => h.label), ['러그 1', '러그 2', '러그 3']);
    expect(p.lugHoleList[1].x, closeTo(p.length / 2, 1e-9));
  });

  test('한 줄 접지 구멍은 가운데 줄과 겹치니 알린다', () {
    final p = _bar(
      lugHoles: 1,
      lugCount: 1,
      rows: 1,
      count: 9,
    ); // 홀수 개면 가운데가 구멍 자리
    expect(p.ok, isFalse);
    expect(p.problems.any((s) => s.contains('접지 구멍과 겹칩니다')), isTrue);
  });

  test('러그 구멍 간격·러그 사이 간격도 12mm 밑으로 안 줄어든다', () {
    final p = _bar(
      lugHoles: 2,
      lugCount: 2,
      rows: 2,
      lugSpacing: 5,
      lugPitch: 7,
      lugDia: 6,
    );
    expect(p.lugHoleList[1].x - p.lugHoleList[0].x, closeTo(12, 1e-9));
    expect(p.lugHoleList[2].x - p.lugHoleList[0].x, closeTo(12, 1e-9));
    expect(p.notes.where((s) => s.contains('12mm로 계산')).length, 2);
  });

  test('러그 구멍끼리 겹치거나 곧은 구간을 벗어나면 알린다', () {
    final clash = _bar(
      lugHoles: 2,
      lugCount: 2,
      rows: 2,
      lugSpacing: 25.4,
      lugPitch: 20,
    );
    expect(clash.problems.any((s) => s.contains('서로 겹칩니다')), isTrue);
    final far = _bar(
      lugHoles: 1,
      lugCount: 10,
      rows: 2,
      count: 3,
      lugPitch: 60,
    );
    expect(far.problems.any((s) => s.contains('곧은 구간')), isTrue);
  });

  test('러그 구멍 크기만 바꾸기와 무게', () {
    final base = _bar(lugHoles: 1, lugCount: 1, rows: 2);
    final p = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 25,
      count: 10,
      rows: 2,
      rowGap: 30,
      lugHoles: 1,
      lugCount: 1,
      lugHoleDia: 11.1,
      overrides: const {'u1-1': 16},
    );
    expect(p.lugHoleList.single.dia, 16);
    expect(p.lugHoleList.single.custom, isTrue);
    expect(p.weightKg, lessThan(base.weightKg));
  });

  test('볼트 이름', () {
    expect(lugBoltFor(11.1), '3/8"(9.5mm) 또는 M10');
    expect(lugBoltFor(7.9), '1/4"(6.35mm)');
    expect(lugBoltFor(10.2), isNull);
  });

  test('판넬 취부 자리: 왼쪽 구멍을 0으로 한 가로 거리 = 챙 안쪽 + 몸체 폭 + 챙 안쪽', () {
    final p = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 25,
      count: 3,
      hat: true,
      hatHeight: 40,
      hatFlange: 50,
      tabHoleCount: 1,
      tabHoleDia: 11.1,
      tabHolePitch: 25.4,
    );
    final pts = panelPattern(p, flangeLeft: 50, flangeRight: 50);
    expect(pts.length, 2);
    expect(pts.first.x, 0);
    // 구멍은 다리 바깥면에서 50 − 19 = 31, 몸체 바깥 폭 100.8 + 24 = 124.8
    expect(pts.last.x, closeTo(31 + 124.8 + 31, 1e-9));
    expect(pts.first.y, 25);
  });

  test('접지 구멍을 뒤(왼쪽 끝)로 몰고 러그 구멍은 그 뒤 남는 자리 가운데에 같은 줄로', () {
    final p = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 25,
      count: 7,
      lugHoles: 2,
      lugSpacing: 44.45,
      lugCount: 1,
      lugHoleDia: 13.5,
      packGround: true,
    );
    // 접지 구멍은 왼쪽 끝 25부터 피치 25.4씩: 마지막 구멍 177.4
    expect(p.positions.first, 25);
    expect(p.positions.last, closeTo(25 + 6 * 25.4, 1e-9));
    // 길이 = 마지막 접지 구멍 + 피치 + 러그 묶음 폭 44.45 + 끝 여유 25
    expect(p.length, closeTo(25 + 6 * 25.4 + 25.4 + 44.45 + 25, 1e-9));
    // 러그 구멍은 같은 줄(폭 가운데), 남는 자리 가운데
    expect(p.lugHoleList.length, 2);
    expect(
      p.lugHoleList.every((h) => h.y == 25 && p.rowY.single == 25),
      isTrue,
    );
    final c = (p.lugHoleList[0].x + p.lugHoleList[1].x) / 2;
    expect(c, closeTo((p.positions.last + 25.4 + p.length - 25) / 2, 1e-9));
    expect(p.lugHoleList[1].x - p.lugHoleList[0].x, closeTo(44.45, 1e-9));
    expect(p.ok, isTrue);
  });

  test('길이로 정하면 러그 자리를 남기고 접지 구멍을 채운다', () {
    final p = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 25,
      length: 400,
      lugHoles: 2,
      lugSpacing: 44.45,
      lugCount: 1,
      lugHoleDia: 13.5,
      packGround: true,
    );
    // (400 − 50 − 25.4 − 44.45) ÷ 25.4 = 11.0 → 11칸 → 12개
    expect(p.holes, 12);
    expect(p.positions.first, 25);
    expect(p.lugHoleList.first.x, greaterThan(p.positions.last + 25.4 - 1e-9));
    expect(p.lugHoleList.last.x, lessThan(400 - 25 + 1e-9));
    expect(p.ok, isTrue);
  });
}
