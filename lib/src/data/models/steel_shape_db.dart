// 🚀 [형강 컷팅 신규] 찬넬/앵글은 튜브처럼 피팅을 꽂아 "라인"을 구성하는
// 개념이 없다 - 그냥 원자재를 필요한 길이로 잘라 쓰는 단순 절단이라, 부속
// 검색 팝업(SmartFittingSelectorSheet)과 똑같이 "표준 규격 목록에서 골라
// 넣고, 목록에 없으면 직접 입력"하는 방식의 가벼운 참고용 규격 DB를
// 새로 만들었다. 실제 자재 강도 계산이 아니라 "이 규격을 몇 mm로 몇 개
// 잘라야 하는지" 계산용이라, 정밀 구조계산이 필요하면 실제 자재 규격서를
// 함께 확인해야 한다(벤딩 계산기처럼 물리적 결과가 걸린 영역이 아니라
// 상용 KS 표준에 가까운 대표 규격만 담았다).

const String kCustomSteelShapeRequestId = '__custom_steel_shape_request__';

// 형강 종류(카테고리). 화면의 칩·아이콘·필터가 모두 이 목록을 따른다 — 새 종류를 넣으려면 여기에 한 줄과
// [SteelShapeDB]에 규격 목록만 추가하면 된다.
class SteelCategory {
  final String id; // 저장되는 값(항목·즐겨찾기에 들어간다). 한 번 정하면 바꾸지 않는다.
  final String label; // 화면에 보이는 이름
  const SteelCategory(this.id, this.label);
}

class SteelShapeItem {
  final String id;
  final String category; // SteelCategory.id 또는 'CUSTOM'
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

  // 찬넬(C형강, mm, 춤x폭xt) - KS 표준 규격에 가까운 대표 규격. 앞쪽은
  // 전선관 지지대/행거처럼 가벼운 작업에 흔히 쓰는 경량 규격, 뒤쪽은
  // 건축 구조용 중량 규격이다 - 둘 다 두께(t)를 라벨에 표기해서
  // 구분되게 했다.
  static const List<SteelShapeItem> channels = [
    SteelShapeItem(
      id: 'channel_25x25x1.6',
      category: 'CHANNEL',
      label: '찬넬 25x25x1.6',
    ),
    SteelShapeItem(
      id: 'channel_40x20x1.6',
      category: 'CHANNEL',
      label: '찬넬 40x20x1.6',
    ),
    SteelShapeItem(
      id: 'channel_50x25x1.6',
      category: 'CHANNEL',
      label: '찬넬 50x25x1.6',
    ),
    SteelShapeItem(
      id: 'channel_60x30x2.0',
      category: 'CHANNEL',
      label: '찬넬 60x30x2.0',
    ),
    SteelShapeItem(
      id: 'channel_75x35x2.3',
      category: 'CHANNEL',
      label: '찬넬 75x35x2.3',
    ),
    SteelShapeItem(
      id: 'channel_90x40x2.3',
      category: 'CHANNEL',
      label: '찬넬 90x40x2.3',
    ),
    SteelShapeItem(
      id: 'channel_100x50x2.3',
      category: 'CHANNEL',
      label: '찬넬 100x50x2.3',
    ),
    SteelShapeItem(
      id: 'channel_125x50x2.3',
      category: 'CHANNEL',
      label: '찬넬 125x50x2.3',
    ),
    SteelShapeItem(
      id: 'channel_150x50x2.3',
      category: 'CHANNEL',
      label: '찬넬 150x50x2.3',
    ),
    SteelShapeItem(
      id: 'channel_200x75x3.2',
      category: 'CHANNEL',
      label: '찬넬 200x75x3.2',
    ),
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

  // 아래는 전선관·배관 지지대와 제작 현장에서 자주 쓰는 종류를 더한 것이다. 규격은 시중에서 흔히 쓰는 대표
  // 값이며 제조사·등급에 따라 다를 수 있어서, 발주 전에는 자재 규격서로 확인해야 한다(표준에 없는 것은 "직접 입력").
  static SteelShapeItem _s(
    String cat,
    String prefix,
    String size, [
    String? idSize,
  ]) => SteelShapeItem(
    id: '${cat.toLowerCase()}_${idSize ?? size}',
    category: cat,
    label: '$prefix $size',
  );

  // 부등변 앵글(변1x변2xt)
  static final List<SteelShapeItem> unequalAngles = [
    for (final v in [
      '100x75x7',
      '125x75x7',
      '125x90x9',
      '150x90x9',
      '150x100x9',
    ])
      _s('UNEQUAL', '부등변앵글', v),
  ];

  // 평철(폭xt)
  static final List<SteelShapeItem> flatBars = [
    for (final v in [
      '19x3',
      '25x3',
      '32x3',
      '38x4.5',
      '40x4.5',
      '50x4.5',
      '50x6',
      '65x6',
      '75x6',
      '75x9',
      '100x6',
      '100x9',
    ])
      _s('FLAT', '평철', v),
  ];

  // 각파이프(변x변xt, 직사각은 가로x세로xt)
  static final List<SteelShapeItem> squarePipes = [
    for (final v in [
      '20x20x1.6',
      '25x25x1.6',
      '30x30x1.6',
      '30x30x2.3',
      '40x40x1.6',
      '40x40x2.3',
      '50x50x2.3',
      '50x50x3.2',
      '60x60x2.3',
      '60x60x3.2',
      '75x75x3.2',
      '100x100x3.2',
      '100x100x4.5',
      '50x25x1.6',
      '60x30x2.3',
      '75x45x2.3',
      '100x50x3.2',
    ])
      _s('SQUARE', '각파이프', v),
  ];

  // 강관(배관용 탄소강관 SGP: 호칭, 바깥지름)
  static final List<SteelShapeItem> roundPipes = [
    for (final v in const {
      '15A': '21.7',
      '20A': '27.2',
      '25A': '34.0',
      '32A': '42.7',
      '40A': '48.6',
      '50A': '60.5',
      '65A': '76.3',
      '80A': '89.1',
      '100A': '114.3',
    }.entries)
      _s('ROUND', '강관', '${v.key}(${v.value})', v.key),
  ];

  // 환봉(지름)
  static final List<SteelShapeItem> roundBars = [
    for (final v in ['6', '8', '10', '12', '16', '19', '22', '25'])
      _s('BAR', '환봉', 'Φ$v', v),
  ];

  // 전산볼트(나사봉, 호칭)
  static final List<SteelShapeItem> threadedRods = [
    for (final v in ['M6', 'M8', 'M10', 'M12', 'M16', 'M20'])
      _s('ROD', '전산볼트', v),
  ];

  // 스트럿 채널(전기 지지대, 폭x높이xt)
  static final List<SteelShapeItem> struts = [
    for (final v in [
      '41x21x2.0',
      '41x21x2.5',
      '41x41x2.0',
      '41x41x2.5',
      '41x62x2.5',
      '41x82x2.5',
    ])
      _s('STRUT', '스트럿', v),
  ];

  // 립 C형강(경량, 높이x폭x립xt). KS D 3530 표 규격과 시중에서 파는 두께(1.8·2.1·3.0)를 함께 담았다. 중량은 규격 이름으로 계산한다.
  // (2026-09 조사: 미주철근철강 KS 규격표, 부현철강 C형강 카탈로그. 150x50x20x2.3은 표에 없지만 예전부터 목록에 있어 둔다.)
  static final List<SteelShapeItem> lipChannels = [
    for (final v in [
      '60x30x10x1.6',
      '60x30x10x1.8',
      '60x30x10x2.0',
      '60x30x10x2.1',
      '60x30x10x2.3',
      '75x45x15x1.6',
      '75x45x15x1.8',
      '75x45x15x2.0',
      '75x45x15x2.1',
      '75x45x15x2.3',
      '100x50x20x1.6',
      '100x50x20x1.8',
      '100x50x20x2.0',
      '100x50x20x2.1',
      '100x50x20x2.3',
      '100x50x20x2.6',
      '100x50x20x3.0',
      '100x50x20x3.2',
      '125x50x20x2.0',
      '125x50x20x2.1',
      '125x50x20x2.3',
      '125x50x20x3.0',
      '125x50x20x3.2',
      '150x50x20x2.1',
      '150x50x20x2.3',
      '150x50x20x3.0',
      '150x50x20x3.2',
      '150x65x20x3.0',
      '150x65x20x3.2',
      '150x65x20x4.0',
      '150x65x20x4.5',
      '150x75x25x3.0',
      '150x75x25x3.2',
      '200x75x20x3.2',
      '200x75x20x4.5',
      '200x75x20x5.0',
      '200x75x25x3.0',
      '200x75x25x3.2',
      '200x75x25x4.0',
      '200x75x25x4.5',
      '250x80x20x4.5',
    ])
      _s('LIPC', '립C형강', v),
  ];

  // H형강(높이x폭x웨브tx플랜지t)
  static final List<SteelShapeItem> hBeams = [
    for (final v in [
      '100x100x6x8',
      '125x125x6.5x9',
      '150x150x7x10',
      '200x200x8x12',
      '250x250x9x14',
      '300x300x10x15',
      '150x75x5x7',
      '200x100x5.5x8',
      '250x125x6x9',
      '300x150x6.5x9',
      '350x175x7x11',
      '400x200x8x13',
    ])
      _s('BEAM', 'H형강', v),
  ];

  // 화면에 나오는 순서(앞쪽이 많이 쓰는 것). 카테고리 id는 저장되므로 바꾸지 않는다.
  static const List<SteelCategory> categories = [
    SteelCategory('ANGLE', '앵글'),
    SteelCategory('CHANNEL', '찬넬'),
    SteelCategory('STRUT', '스트럿'),
    SteelCategory('FLAT', '평철'),
    SteelCategory('SQUARE', '각파이프'),
    SteelCategory('ROUND', '강관'),
    SteelCategory('BAR', '환봉'),
    SteelCategory('ROD', '전산볼트'),
    SteelCategory('UNEQUAL', '부등변앵글'),
    SteelCategory('LIPC', '립C형강'),
    SteelCategory('BEAM', 'H형강'),
  ];

  static const SteelCategory customCategory = SteelCategory('CUSTOM', '커스텀');

  // 카테고리 id → 화면 이름(모르는 값은 "기타").
  static String categoryLabel(String id) {
    if (id == 'CUSTOM') return customCategory.label;
    for (final c in categories) {
      if (c.id == id) return c.label;
    }
    return '기타';
  }

  static List<SteelShapeItem> byCategory(String id) => [
    ...all.where((s) => s.category == id),
  ];

  static List<SteelShapeItem> get all => [
    ...angles,
    ...channels,
    ...struts,
    ...flatBars,
    ...squarePipes,
    ...roundPipes,
    ...roundBars,
    ...threadedRods,
    ...unequalAngles,
    ...lipChannels,
    ...hBeams,
  ];
}
