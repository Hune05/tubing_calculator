// 자재 목록(카탈로그). 창고에 실제로 몇 개 있는지(재고)와는 별개로,
// "이런 자재가 있다"는 목록만 담는다. 재고에 넣을 때 여기서 골라 쓴다.
//
// 아래 기본 목록은 앱이 심어 주는 씨앗이다. KS 호칭과 현장에서 부르는 이름을
// 따라 적었지만 현장·업체마다 부르는 말이 달라서, 화면에서 이름·규격을 고치고
// 빼고 더할 수 있게 해 뒀다(서버 'material_catalog'에 담긴다).

/// 자재 분류. 화면 칩과 카탈로그가 같은 이름을 쓰게 한 곳에 모아 둔다.
const Map<String, String> kMaterialCategoryLabels = {
  'CONDUIT': '전선관',
  'FLEX': '후렉시블',
  'ACC': '부속·악세사리',
  'TUBE': '튜브',
  'FITTING': '피팅',
  'VALVE': '밸브',
  'FLANGE': '가스켓·후렌지',
  '기타': '기타',
};

String materialCategoryLabel(String? id) {
  if (id == null || id.isEmpty) return '기타';
  return kMaterialCategoryLabels[id] ?? id;
}

/// 카탈로그 한 줄.
class CatalogItem {
  final String id;
  final String name; // 화면에 보이는 이름 (예: 후강 전선관 22mm)
  final String category; // CONDUIT / FLEX / ACC ...
  final String spec; // 규격 (예: 22mm). 규격이 없는 자재는 빈 글
  final String kind; // 갈래 (예: 후강, EMT, PF, 전선관 부속)
  final String unit; // 본 / m / EA
  final int order; // 목록에 보일 순서

  const CatalogItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    this.spec = '',
    this.kind = '',
    this.order = 0,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'category': category,
    'spec': spec,
    'kind': kind,
    'unit': unit,
    'order': order,
    'builtin': true,
  };

  static CatalogItem fromMap(String id, Map<String, dynamic> m) => CatalogItem(
    id: id,
    name: (m['name'] ?? '이름 없음').toString(),
    category: (m['category'] ?? '기타').toString(),
    spec: (m['spec'] ?? '').toString(),
    kind: (m['kind'] ?? '').toString(),
    unit: (m['unit'] ?? 'EA').toString(),
    order: (m['order'] as num?)?.toInt() ?? 0,
  );

  /// 검색에 쓰는 글자. 이름·규격·갈래·분류를 한 줄로 붙인다.
  String get searchText =>
      '$name $spec $kind ${materialCategoryLabel(category)}'.toLowerCase();
}

// ── 아래는 기본 목록을 만드는 부분 ──

const List<int> _rigidSizes = [16, 22, 28, 36, 42, 54, 70, 82, 92, 104];
const List<int> _thinSizes = [19, 25, 31, 39, 51, 63];
const List<int> _emtSizes = [16, 22, 28, 36, 42, 54];
const List<int> _pvcSizes = [14, 16, 22, 28, 36, 42, 54, 70, 82, 100];

const List<int> _flexMetalSizes = [15, 17, 24, 30, 38, 50, 63, 76];
const List<int> _flexPlasticSizes = [14, 16, 22, 28, 36, 42];

// 전선관 부속은 전선관 호칭을 따라간다.
const List<int> _accConduitSizes = [16, 22, 28, 36, 42, 54];
// 후렉시블 부속은 후렉시블 호칭을 따라간다.
const List<int> _accFlexSizes = [15, 17, 24, 30, 38, 50];

/// 전선관 부속 갈래. (아이디 조각, 이름)
const List<List<String>> _accConduitKinds = [
  ['coupling', '커플링'],
  ['normal_band', '노멀 밴드'],
  ['union_coupling', '유니온 커플링'],
  ['bushing', '부싱'],
  ['locknut', '로크 너트'],
  ['saddle', '새들'],
  ['box_connector', '박스 커넥터'],
  ['entrance_cap', '엔트런스 캡'],
];

const List<List<String>> _accFlexKinds = [
  ['flex_conn_st', '후렉시블 커넥터 (스트레이트)'],
  ['flex_conn_ang', '후렉시블 커넥터 (앵글)'],
  ['combi_coupling', '컴비네이션 커플링'],
];

/// 곤질레다(컨듈렛) 종류. 전선관 작업에서 선을 꺾거나 빼낼 때 쓰는 부속이다.
const List<List<String>> _conduletKinds = [
  ['condulet_lb', '곤질레다 LB형'],
  ['condulet_ll', '곤질레다 LL형'],
  ['condulet_lr', '곤질레다 LR형'],
  ['condulet_t', '곤질레다 T형'],
  ['condulet_c', '곤질레다 C형'],
  ['condulet_cover', '곤질레다 커버'],
];

/// 규격 없이 종류만 있는 부속.
const List<List<String>> _accNoSize = [
  ['box_octa', '8각 박스'],
  ['box_square', '4각 박스'],
  ['box_switch', '스위치 박스'],
  ['box_pull', '풀 박스'],
  ['box_cover', '박스 커버'],
];

/// 앱이 심어 주는 기본 자재 목록.
List<CatalogItem> builtinMaterialCatalog() {
  final out = <CatalogItem>[];
  var order = 0;

  void addConduit(String idKind, String kindName, List<int> sizes) {
    for (final s in sizes) {
      out.add(
        CatalogItem(
          id: 'conduit_${idKind}_$s',
          name: '$kindName ${s}mm',
          category: 'CONDUIT',
          spec: '${s}mm',
          kind: kindName,
          unit: '본',
          order: order += 10,
        ),
      );
    }
  }

  addConduit('rigid', '후강 전선관', _rigidSizes);
  addConduit('thin', '박강 전선관', _thinSizes);
  addConduit('emt', 'EMT 전선관', _emtSizes);
  addConduit('pvc', 'PVC 전선관', _pvcSizes);

  void addFlex(String idKind, String kindName, List<int> sizes) {
    for (final s in sizes) {
      out.add(
        CatalogItem(
          id: 'flex_${idKind}_$s',
          name: '$kindName ${s}mm',
          category: 'FLEX',
          spec: '${s}mm',
          kind: kindName,
          unit: 'm',
          order: order += 10,
        ),
      );
    }
  }

  addFlex('metal', '금속 후렉시블', _flexMetalSizes);
  addFlex('pf', 'PF관', _flexPlasticSizes);
  addFlex('cd', 'CD관', _flexPlasticSizes);

  for (final kind in _accConduitKinds) {
    for (final s in _accConduitSizes) {
      out.add(
        CatalogItem(
          id: 'acc_${kind[0]}_$s',
          name: '${kind[1]} ${s}mm',
          category: 'ACC',
          spec: '${s}mm',
          kind: '전선관 부속',
          unit: 'EA',
          order: order += 10,
        ),
      );
    }
  }

  for (final kind in _accFlexKinds) {
    for (final s in _accFlexSizes) {
      out.add(
        CatalogItem(
          id: 'acc_${kind[0]}_$s',
          name: '${kind[1]} ${s}mm',
          category: 'ACC',
          spec: '${s}mm',
          kind: '후렉시블 부속',
          unit: 'EA',
          order: order += 10,
        ),
      );
    }
  }

  for (final s in [16, 22, 28]) {
    out.add(
      CatalogItem(
        id: 'acc_ground_clamp_$s',
        name: '접지 클램프 ${s}mm',
        category: 'ACC',
        spec: '${s}mm',
        kind: '접지',
        unit: 'EA',
        order: order += 10,
      ),
    );
  }

  for (final kind in _accNoSize) {
    out.add(
      CatalogItem(
        id: 'acc_${kind[0]}',
        name: kind[1],
        category: 'ACC',
        kind: '박스류',
        unit: 'EA',
        order: order += 10,
      ),
    );
  }

  // 곤질레다는 목록 맨 끝에 붙인다. 앞에 끼우면 이미 서버에 올라간 자재들의
  // 순서 숫자와 어긋난다.
  for (final kind in _conduletKinds) {
    for (final s in _accConduitSizes) {
      out.add(
        CatalogItem(
          id: 'acc_${kind[0]}_$s',
          name: '${kind[1]} ${s}mm',
          category: 'ACC',
          spec: '${s}mm',
          kind: '곤질레다',
          unit: 'EA',
          order: order += 10,
        ),
      );
    }
  }

  return out;
}

// ── 제조사 ──
// 현장에서 많이 쓰는 곳을 기본으로 올려 둔다. 여기 없는 곳은 직접 적으면
// 앱이 기억해서 다음부터 목록에 같이 보여 준다.
const List<String> kCommonMaterialMakers = ['삼화', '동아산전'];

/// 앱이 기억한 제조사를 기본 목록 뒤에 붙인다(중복은 뺀다).
List<String> mergeMakers(List<String> remembered) {
  final out = <String>[...kCommonMaterialMakers];
  for (final m in remembered) {
    final v = m.trim();
    if (v.isEmpty) continue;
    if (out.contains(v)) continue;
    out.add(v);
  }
  return out;
}
