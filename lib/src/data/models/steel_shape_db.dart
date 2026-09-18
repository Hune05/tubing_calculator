// 🚀 [형강 컷팅 신규] 찬넬/앵글은 튜브처럼 피팅을 꽂아 "라인"을 구성하는
// 개념이 없다 - 그냥 원자재를 필요한 길이로 잘라 쓰는 단순 절단이라, 부속
// 검색 팝업(SmartFittingSelectorSheet)과 똑같이 "표준 규격 목록에서 골라
// 넣고, 목록에 없으면 직접 입력"하는 방식의 가벼운 참고용 규격 DB를
// 새로 만들었다. 실제 자재 강도 계산이 아니라 "이 규격을 몇 mm로 몇 개
// 잘라야 하는지" 계산용이라, 정밀 구조계산이 필요하면 실제 자재 규격서를
// 함께 확인해야 한다(벤딩 계산기처럼 물리적 결과가 걸린 영역이 아니라
// 상용 KS 표준에 가까운 대표 규격만 담았다).

const String kCustomSteelShapeRequestId = '__custom_steel_shape_request__';

class SteelShapeItem {
  final String id;
  final String category; // 'ANGLE' | 'CHANNEL'
  final String label;

  const SteelShapeItem({
    required this.id,
    required this.category,
    required this.label,
  });
}

class SteelShapeDB {
  SteelShapeDB._();

  // 등변 앵글(Equal Angle, mm, 변x변xt) - 일반 제작/구조 보강에 흔히 쓰이는
  // 대표 규격.
  static const List<SteelShapeItem> angles = [
    SteelShapeItem(id: 'angle_25x25x3', category: 'ANGLE', label: '앵글 25x25x3'),
    SteelShapeItem(id: 'angle_30x30x3', category: 'ANGLE', label: '앵글 30x30x3'),
    SteelShapeItem(id: 'angle_40x40x3', category: 'ANGLE', label: '앵글 40x40x3'),
    SteelShapeItem(id: 'angle_40x40x4', category: 'ANGLE', label: '앵글 40x40x4'),
    SteelShapeItem(id: 'angle_45x45x4', category: 'ANGLE', label: '앵글 45x45x4'),
    SteelShapeItem(id: 'angle_50x50x4', category: 'ANGLE', label: '앵글 50x50x4'),
    SteelShapeItem(id: 'angle_50x50x5', category: 'ANGLE', label: '앵글 50x50x5'),
    SteelShapeItem(id: 'angle_60x60x5', category: 'ANGLE', label: '앵글 60x60x5'),
    SteelShapeItem(id: 'angle_65x65x6', category: 'ANGLE', label: '앵글 65x65x6'),
    SteelShapeItem(id: 'angle_75x75x6', category: 'ANGLE', label: '앵글 75x75x6'),
    SteelShapeItem(id: 'angle_75x75x9', category: 'ANGLE', label: '앵글 75x75x9'),
    SteelShapeItem(id: 'angle_90x90x7', category: 'ANGLE', label: '앵글 90x90x7'),
    SteelShapeItem(
      id: 'angle_100x100x7',
      category: 'ANGLE',
      label: '앵글 100x100x7',
    ),
    SteelShapeItem(
      id: 'angle_100x100x10',
      category: 'ANGLE',
      label: '앵글 100x100x10',
    ),
    SteelShapeItem(
      id: 'angle_125x125x9',
      category: 'ANGLE',
      label: '앵글 125x125x9',
    ),
    SteelShapeItem(
      id: 'angle_150x150x12',
      category: 'ANGLE',
      label: '앵글 150x150x12',
    ),
  ];

  // 찬넬(C형강, mm, 춤x폭xt) - KS 표준 규격에 가까운 대표 규격.
  static const List<SteelShapeItem> channels = [
    SteelShapeItem(
      id: 'channel_75x40x5',
      category: 'CHANNEL',
      label: '찬넬 75x40x5',
    ),
    SteelShapeItem(
      id: 'channel_100x50x5',
      category: 'CHANNEL',
      label: '찬넬 100x50x5',
    ),
    SteelShapeItem(
      id: 'channel_125x65x6',
      category: 'CHANNEL',
      label: '찬넬 125x65x6',
    ),
    SteelShapeItem(
      id: 'channel_150x75x6.5',
      category: 'CHANNEL',
      label: '찬넬 150x75x6.5',
    ),
    SteelShapeItem(
      id: 'channel_180x75x7',
      category: 'CHANNEL',
      label: '찬넬 180x75x7',
    ),
    SteelShapeItem(
      id: 'channel_200x80x7.5',
      category: 'CHANNEL',
      label: '찬넬 200x80x7.5',
    ),
    SteelShapeItem(
      id: 'channel_250x90x9',
      category: 'CHANNEL',
      label: '찬넬 250x90x9',
    ),
    SteelShapeItem(
      id: 'channel_300x90x9',
      category: 'CHANNEL',
      label: '찬넬 300x90x9',
    ),
    SteelShapeItem(
      id: 'channel_300x90x10',
      category: 'CHANNEL',
      label: '찬넬 300x90x10',
    ),
    SteelShapeItem(
      id: 'channel_380x100x10.5',
      category: 'CHANNEL',
      label: '찬넬 380x100x10.5',
    ),
  ];

  static List<SteelShapeItem> get all => [...angles, ...channels];
}
