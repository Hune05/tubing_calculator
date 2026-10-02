import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_ground.dart';
import 'package:tubing_calculator/src/presentation/electrical/busbar_lug.dart';

List<GroundHole> _row({int n = 10, double dia = 11.1, double pitch = 25.4}) =>
    groundBar(
      t: 6,
      w: 50,
      holeDia: dia,
      pitch: pitch,
      endDist: 25,
      count: n,
    ).groundHoles;

void main() {
  test('2구멍 러그 간격이 피치와 같으면 이웃 구멍 둘씩, 러그 3개는 구멍 6개', () {
    final p = lugPlan(
      row: _row(),
      pitch: 25.4,
      lugHoles: 2,
      spacing: 25.4,
      count: 3,
    );
    expect(p.ok, isTrue);
    expect(p.lugs.length, 3);
    expect(p.lugs[0].holes.map((h) => h.label), ['1번', '2번']);
    expect(p.lugs[1].holes.map((h) => h.label), ['3번', '4번']);
    expect(p.bolts, 6);
  });

  test('간격이 피치의 정수배면 건너뛴 구멍을 쓴다(피치 19.05, 러그 간격 38.1)', () {
    final p = lugPlan(
      row: _row(pitch: 19.05),
      pitch: 19.05,
      lugHoles: 2,
      spacing: 38.1,
      count: 2,
    );
    expect(p.ok, isTrue);
    expect(p.lugs[0].holes.map((h) => h.label), ['1번', '3번']);
    expect(p.lugs[1].holes.map((h) => h.label), ['4번', '6번']);
  });

  test('간격이 피치와 안 맞으면 알린다', () {
    final p = lugPlan(
      row: _row(),
      pitch: 25.4,
      lugHoles: 2,
      spacing: 19.05,
      count: 1,
    );
    expect(p.ok, isFalse);
    expect(p.lugs, isEmpty);
    expect(p.problems.single, contains('정수배'));
  });

  test('1구멍 러그 · 시작 번호와 비움 · 구멍을 넘어가면 알림', () {
    final p = lugPlan(
      row: _row(n: 6),
      pitch: 25.4,
      lugHoles: 1,
      spacing: 0,
      count: 3,
      start: 2,
      skip: 1,
    );
    expect(p.lugs.map((l) => l.holes.single.label), ['2번', '4번', '6번']);
    final over = lugPlan(
      row: _row(n: 6),
      pitch: 25.4,
      lugHoles: 1,
      spacing: 0,
      count: 4,
      start: 2,
      skip: 1,
    );
    expect(over.ok, isFalse);
    expect(over.lugs.length, 3);
  });

  test('볼트 이름과 그립', () {
    final p = lugPlan(
      row: _row(),
      pitch: 25.4,
      lugHoles: 2,
      spacing: 25.4,
      count: 1,
      lugPad: 5,
      barThick: 6,
    );
    expect(p.grip, 11);
    expect(p.boltName, '3/8"(9.5mm) 또는 M10');
    expect(lugBoltFor(7.9), '1/4"(6.35mm)');
    expect(lugBoltFor(10.2), isNull);
  });

  test('가운데 정렬: 구멍 10개에 2구멍 러그 3개(6구멍)는 3~8번, 러그 묶음이 줄 가운데', () {
    final p = lugPlan(
      row: _row(),
      pitch: 25.4,
      lugHoles: 2,
      spacing: 25.4,
      count: 3,
      centered: true,
    );
    expect(p.lugs.first.holes.first.label, '3번');
    expect(p.lugs.last.holes.last.label, '8번');
    // 구멍 줄 가운데 = 묶음 가운데
    final row = _row();
    final mid = (row.first.x + row.last.x) / 2;
    final gm = (p.lugs.first.holes.first.x + p.lugs.last.holes.last.x) / 2;
    expect(gm, closeTo(mid, 1e-9));
  });

  test('가운데 정렬: 1구멍 러그 2개(구멍 10개)는 5·6번, 구멍이 홀수 개면 정가운데', () {
    final a = lugPlan(
      row: _row(),
      pitch: 25.4,
      lugHoles: 1,
      spacing: 0,
      count: 2,
      centered: true,
    );
    expect(a.lugs.map((l) => l.holes.single.label), ['5번', '6번']);
    final b = lugPlan(
      row: _row(n: 9),
      pitch: 25.4,
      lugHoles: 1,
      spacing: 0,
      count: 1,
      centered: true,
    );
    expect(b.lugs.single.holes.single.label, '5번');
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
    // 구멍은 다리 바깥면에서 50 − 19 = 31, 몸체 바깥 폭 100.8 + 24 = 124.8 → 31 + 124.8 + 31
    expect(pts.last.x, closeTo(31 + 124.8 + 31, 1e-9));
    expect(pts.first.y, 25);
  });
}
