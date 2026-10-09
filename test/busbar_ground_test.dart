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
    expect(p.rowY, [25]);
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
        holeDia: 14,
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
    expect(p.tabHoleList.length, 2);
    expect(p.tabHoleList.first.x, closeTo(19, 1e-9));
    expect(p.tabHoleList.last.x, closeTo(p.length - 19, 1e-9));
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

  test('탭이 꺾기에 다 들어가 평평한 길이가 0이면 탭 구멍을 말없이 빼지 않고 알린다(8차)', () {
    final p = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 25,
      count: 3,
      tabLeft: 12, // 안쪽 반경 6 + 두께 6 = 꺾기 자리 12 → 평평한 길이 0
      tabHoleCount: 1,
      tabHoleDia: 11.1,
      tabHolePitch: 25.4,
    );
    expect(p.tabHoleList, isEmpty);
    expect(p.problems.any((w) => w.contains("평평한 길이가 없어 탭 구멍을 뚫지 않았습니다")), isTrue);
  });

  test('챙 길이를 왼쪽·오른쪽 따로: 길이와 꺾기 선이 각각 맞다', () {
    final a = groundBar(
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
    final b = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 25,
      count: 4,
      hat: true,
      hatHeight: 40,
      hatFlange: 40,
      hatFlangeRight: 60,
    );
    expect(b.length, closeTo(a.length + 20, 1e-9));
    expect(b.bends.first.start, a.bends.first.start);
    expect(b.bendPlan!.cutLength, closeTo(b.length, 1e-9));
    expect(b.flatTabR, closeTo(48, 1e-9));
    expect(b.flatTabL, closeTo(28, 1e-9));
  });

  test('두 줄 대칭: 같은 x에 위아래로, 줄 간격은 가운데에서 반씩', () {
    final p = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 25,
      count: 3,
      rows: 2,
      rowGap: 20,
    );
    expect(p.groundHoles.length, 6);
    expect(p.rowY, [15, 35]);
    expect(p.positions, p.positionsB);
    expect(p.length, closeTo(50 + 2 * 25.4, 1e-9));
    expect(p.ok, isTrue);
    expect(p.groundHoles.first.label, 'A1');
  });

  test('두 줄 비대칭(엇갈림): B줄이 반 피치 이동하고 길이가 그만큼 늘어난다', () {
    final p = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 25,
      count: 3,
      rows: 2,
      rowGap: 20,
      staggered: true,
    );
    expect(p.stagger, closeTo(12.7, 1e-9));
    expect(p.positionsB.first, closeTo(p.positions.first + 12.7, 1e-9));
    expect(p.length, closeTo(50 + 2 * 25.4 + 12.7, 1e-9));
    expect(p.endRight, closeTo(25, 1e-9));
    expect(p.ok, isTrue);
  });

  test('두 줄이 너무 붙으면 겹침 알림, 줄 간격이 크면 폭 밖', () {
    final tight = groundBar(
      t: 6,
      w: 50,
      holeDia: 14,
      pitch: 25.4,
      endDist: 25,
      count: 3,
      rows: 2,
      rowGap: 8,
    );
    expect(tight.ok, isFalse);
    final wide = groundBar(
      t: 6,
      w: 30,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 25,
      count: 3,
      rows: 2,
      rowGap: 24,
    );
    expect(wide.problems.any((s) => s.contains('폭 밖')), isTrue);
    expect(wide.problems.length, lessThan(4)); // 구멍마다 반복하지 않고 한 줄로 묶는다
  });

  test('구멍 하나만 크기를 바꾼다: 그 구멍만 지름이 달라지고 무게가 줄어든다', () {
    final base = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 25,
      count: 4,
    );
    final p = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 25,
      count: 4,
      overrides: const {'gA2': 18},
    );
    expect(p.groundHoles[1].dia, 18);
    expect(p.groundHoles[1].custom, isTrue);
    expect(p.groundHoles[0].dia, 11.1);
    expect(p.customCount, 1);
    expect(p.weightKg, lessThan(base.weightKg));
    final big = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 25,
      count: 4,
      overrides: const {'gA2': 45},
    );
    expect(big.ok, isFalse); // 이웃 구멍과 겹침
  });

  test('챙 구멍도 두 줄 · 구멍 번호로 크기 바꾸기', () {
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
      rows: 2,
      rowGap: 20,
      tabHoleCount: 1,
      tabHoleDia: 9,
      tabHolePitch: 25.4,
      tabRows: 2,
      tabRowGap: 20,
      overrides: const {'tR-B1': 11},
    );
    expect(p.tabHoleList.length, 4); // 왼쪽 A·B, 오른쪽 A·B
    final rb = p.tabHoleList.firstWhere((h) => h.id == 'tR-B1');
    expect(rb.dia, 11);
    expect(rb.label, '오른쪽 B1');
    expect(rb.y, 35);
  });

  test('취부 구멍 줄은 접지 구멍 줄과 따로: 접지가 두 줄이어도 챙은 한 줄이면 챙마다 1개', () {
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
      rows: 2,
      rowGap: 20,
      tabHoleCount: 1,
      tabHoleDia: 11.1,
      tabHolePitch: 25.4,
    );
    expect(p.groundHoles.length, 6);
    expect(p.tabHoleList.length, 2); // 왼쪽 챙 1 + 오른쪽 챙 1
    expect(p.tabHoleList.first.label, '왼쪽 1');
    expect(p.tabHoleList.first.y, 25);
    expect(p.tabRows, 1);
  });

  test('취부 구멍을 뚫을 챙 고르기: 왼쪽만·오른쪽만', () {
    GroundBarPlan make(int sides) => groundBar(
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
      tabSides: sides,
    );
    expect(make(1).tabHoleList.map((h) => h.label), ['왼쪽 1']);
    expect(make(2).tabHoleList.map((h) => h.label), ['오른쪽 1']);
    expect(make(3).tabHoleList.length, 2);
  });

  test('구멍 간격은 12mm 밑으로 안 줄어든다: 피치·줄 간격·탭 피치를 12로 올려 계산하고 알린다', () {
    final p = groundBar(
      t: 6,
      w: 50,
      holeDia: 7.9,
      pitch: 9,
      endDist: 25,
      count: 3,
      rows: 2,
      rowGap: 5,
      hat: true,
      hatHeight: 40,
      hatFlange: 60,
      tabHoleCount: 2,
      tabHoleDia: 7.9,
      tabHolePitch: 8,
      tabRows: 2,
      tabRowGap: 6,
    );
    expect(p.pitchUsed, 12);
    expect(p.tabPitchUsed, 12);
    expect(p.positions[1] - p.positions[0], 12);
    expect(p.rowY, [19, 31]); // 줄 간격 12
    expect(p.tabRowY, [19, 31]);
    expect(p.notes.where((s) => s.contains("12mm로 계산")).length, 4);
    expect(p.notes.first, contains('최소 간격 12mm'));
    expect(p.ok, isTrue); // 알림일 뿐 문제가 아니다
    // 12 이상은 그대로
    final q = groundBar(
      t: 6,
      w: 50,
      holeDia: 7.9,
      pitch: 12,
      endDist: 25,
      count: 3,
    );
    expect(q.notes.where((s) => s.contains("12mm로 계산")), isEmpty);
    expect(q.pitchUsed, 12);
  });

  test('구멍 가장자리 ~ 꺾기 시작선 거리: 챙 구멍이 두께 2배보다 가까우면 주의 알림', () {
    GroundBarPlan make(double flange) => groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 25,
      count: 3,
      hat: true,
      hatHeight: 40,
      hatFlange: flange,
      tabHoleCount: 1,
      tabHoleDia: 11.1,
      tabHolePitch: 25.4,
    );
    final near = make(40); // 평평한 28, 구멍 중심 14 → 가장자리 14 − 5.55 = 8.45
    expect(near.minEdgeTab, closeTo(8.45, 1e-9));
    expect(near.minEdgeBody, closeTo(25 - 5.55, 1e-9));
    expect(
      near.notes.any(
        (s) => s.contains('꺾기 시작선에서 8.5mm') || s.contains('꺾기 시작선에서 8.4mm'),
      ),
      isTrue,
    );
    expect(near.ok, isTrue); // 알림일 뿐 문제가 아니다
    final far = make(60); // 평평한 48 → 24 − 5.55 = 18.45
    expect(far.minEdgeTab, closeTo(18.45, 1e-9));
    expect(far.notes.where((s) => s.contains('꺾기 시작선에서')), isEmpty);
    // 꺾지 않으면 거리 없음
    final flat = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 25,
      count: 3,
    );
    expect(flat.minEdgeBody, isNull);
    expect(flat.minEdgeTab, isNull);
  });

  test('필요 거리 2T + R: 두께 6·반경 6이면 18mm, 부족하면 필요한 만큼 늘리라고 알린다', () {
    final p = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 25,
      count: 3,
      hat: true,
      hatHeight: 40,
      hatFlange: 40,
      tabHoleCount: 1,
      tabHoleDia: 11.1,
      tabHolePitch: 25.4,
    );
    expect(p.reqEdgeTab, closeTo(18, 1e-9));
    expect(p.reqEdgeBody, closeTo(18, 1e-9));
    expect(p.minEdgeTab, closeTo(8.45, 1e-9));
    final note = p.notes.firstWhere((s) => s.contains('필요 거리 18mm'));
    expect(note, contains('9.6mm 이상 늘리거나')); // 18 − 8.45
    // 지름 25.4 이상은 2.5T + R = 21
    final big = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 30,
      endDist: 30,
      count: 2,
      hat: true,
      hatHeight: 40,
      hatFlange: 60,
      tabHoleCount: 1,
      tabHoleDia: 26,
      tabHolePitch: 30,
    );
    expect(big.reqEdgeTab, closeTo(21, 1e-9));
  });

  test('막대 가장자리·끝·구멍 사이 간격 주의(권장 2T, 최소 1T)', () {
    final p = groundBar(
      t: 6,
      w: 20,
      holeDia: 11.1,
      pitch: 15,
      endDist: 8,
      count: 3,
    );
    // 폭 20, 구멍 11.1: 가장자리까지 4.45mm
    expect(
      p.notes.any(
        (s) => s.contains('막대 가장자리(폭 방향)') && s.contains('최소에도 못 미칩니다'),
      ),
      isTrue,
    );
    expect(p.notes.any((s) => s.contains('꺾지 않은 막대 끝')), isTrue);
    expect(p.notes.any((s) => s.contains('이웃한 접지 구멍 가장자리 사이')), isTrue);
    expect(p.ok, isTrue); // 알림일 뿐 문제가 아니다
    final fine = groundBar(
      t: 6,
      w: 50,
      holeDia: 11.1,
      pitch: 25.4,
      endDist: 25,
      count: 3,
    );
    expect(fine.notes, isEmpty);
  });
}
