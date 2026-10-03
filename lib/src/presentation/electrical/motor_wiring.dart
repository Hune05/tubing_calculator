// 3상 유도전동기 단자함 결선(9단자·12단자 이중 전압, 6단자 Y·Δ). 화면 없이 접속표만 가진다.
// 근거: docs/전동기_결선_근거.md. EASA 핸드북(NEMA·IEC 표기와 결선표)을 Electric Motor Warehouse·AEMC·BCcampus·Rockwell·
// WEG·Brook Crompton·한국 교육·업체 자료와 맞춰 본 값이다(NEMA MG-1·IEC 60034-8 원문은 열람하지 못했다).
// 단자는 NEMA 번호 T1~T12를 정수 1~12로 쓴다.
library;

/// 결선 하나: 전원선(L1·L2·L3)마다 물리는 단자와, 서로 묶는(점퍼) 단자 그룹.
class MotorWiring {
  const MotorWiring({
    required this.id,
    required this.terminals,
    required this.title,
    required this.use,
    required this.l1,
    required this.l2,
    required this.l3,
    required this.joins,
  });

  final String id;

  /// 단자 수: 6·9·12.
  final int terminals;
  final String title;

  /// 한 줄 설명(어느 전압에 쓰는 결선인지).
  final String use;

  /// 전원선에 물리는 단자.
  final List<int> l1;
  final List<int> l2;
  final List<int> l3;

  /// 서로 묶는 단자 그룹(점퍼). 한 그룹 안의 단자는 한 점으로 모인다.
  final List<List<int>> joins;

  /// 이 결선에서 쓰는 모든 단자(전원 + 점퍼).
  List<int> get usedTerminals => [...l1, ...l2, ...l3, for (final j in joins) ...j];
}

/// 9단자 결선(이중 전압, 전압비 1:2).
const List<MotorWiring> kWiring9 = [
  MotorWiring(
    id: 'y9_low',
    terminals: 9,
    title: 'Y 9단자 · 저전압 (YY)',
    use: '이중 전압 전동기를 낮은 전압에 쓸 때(예: 220 V). 권선 둘을 병렬로 합니다.',
    l1: [1, 7],
    l2: [2, 8],
    l3: [3, 9],
    joins: [
      [4, 5, 6],
    ],
  ),
  MotorWiring(
    id: 'y9_high',
    terminals: 9,
    title: 'Y 9단자 · 고전압 (Y)',
    use: '높은 전압에 쓸 때(예: 440 V). 권선 둘을 직렬로 잇습니다.',
    l1: [1],
    l2: [2],
    l3: [3],
    joins: [
      [4, 7],
      [5, 8],
      [6, 9],
    ],
  ),
  MotorWiring(
    id: 'd9_low',
    terminals: 9,
    title: 'Δ 9단자 · 저전압',
    use: 'Δ 결선 이중 전압 전동기를 낮은 전압에 쓸 때. 점퍼 없이 전원선만 둘~셋씩 물립니다.',
    l1: [1, 6, 7],
    l2: [2, 4, 8],
    l3: [3, 5, 9],
    joins: [],
  ),
  MotorWiring(
    id: 'd9_high',
    terminals: 9,
    title: 'Δ 9단자 · 고전압',
    use: '높은 전압에 쓸 때. 권선 둘을 직렬로 잇습니다.',
    l1: [1],
    l2: [2],
    l3: [3],
    joins: [
      [4, 7],
      [5, 8],
      [6, 9],
    ],
  ),
];

/// 12단자 결선(이중 전압, 전압비 1:2). 반권선 여섯: 1-4, 2-5, 3-6, 7-10, 8-11, 9-12.
const List<MotorWiring> kWiring12 = [
  MotorWiring(
    id: 'y12_high',
    terminals: 12,
    title: 'Y 12단자 · 고전압',
    use: '높은 전압에 Y로 쓸 때. 반권선을 직렬로 잇고 끝을 한 점에 모읍니다.',
    l1: [1],
    l2: [2],
    l3: [3],
    joins: [
      [4, 7],
      [5, 8],
      [6, 9],
      [10, 11, 12],
    ],
  ),
  MotorWiring(
    id: 'y12_low',
    terminals: 12,
    title: 'Y 12단자 · 저전압',
    use: '낮은 전압에 Y로 쓸 때. 반권선을 병렬로 합칩니다.',
    l1: [1, 7],
    l2: [2, 8],
    l3: [3, 9],
    joins: [
      [4, 5, 6],
      [10, 11, 12],
    ],
  ),
  MotorWiring(
    id: 'd12_high',
    terminals: 12,
    title: 'Δ 12단자 · 고전압',
    use: '높은 전압에 Δ로 쓸 때. 반권선을 직렬로 잇습니다.',
    l1: [1, 12],
    l2: [2, 10],
    l3: [3, 11],
    joins: [
      [4, 7],
      [5, 8],
      [6, 9],
    ],
  ),
  MotorWiring(
    id: 'd12_low',
    terminals: 12,
    title: 'Δ 12단자 · 저전압',
    use: '낮은 전압에 Δ로 쓸 때. 점퍼 없이 전원선만 넷씩 물립니다(반권선 병렬).',
    l1: [1, 6, 7, 12],
    l2: [2, 4, 8, 10],
    l3: [3, 5, 9, 11],
    joins: [],
  ),
];

/// 6단자 결선(Y·Δ). 단자 1~6 = U V W X Y Z = U1 V1 W1 U2 V2 W2.
const List<MotorWiring> kWiring6 = [
  MotorWiring(
    id: 'y6',
    terminals: 6,
    title: 'Y 6단자',
    use: 'Y로 쓸 때. 끝 단자 X·Y·Z(T4·T5·T6)를 한 점에 묶습니다.',
    l1: [1],
    l2: [2],
    l3: [3],
    joins: [
      [4, 5, 6],
    ],
  ),
  MotorWiring(
    id: 'd6',
    terminals: 6,
    title: 'Δ 6단자',
    use: 'Δ로 쓸 때. U-Z, V-X, W-Y를 잇습니다.',
    l1: [1, 6],
    l2: [2, 4],
    l3: [3, 5],
    joins: [],
  ),
];

List<MotorWiring> wiringsFor(int terminals) => switch (terminals) {
  6 => kWiring6,
  9 => kWiring9,
  12 => kWiring12,
  _ => const [],
};

/// 6단자 표기 대응: NEMA 번호 → (한국, IEC).
const Map<int, (String, String)> kLabels6 = {
  1: ('U', 'U1'),
  2: ('V', 'V1'),
  3: ('W', 'W1'),
  4: ('X', 'U2'),
  5: ('Y', 'V2'),
  6: ('Z', 'W2'),
};
