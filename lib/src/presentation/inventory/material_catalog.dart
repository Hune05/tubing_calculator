// 자재 목록(카탈로그). 창고에 실제로 몇 개 있는지(재고)와는 별개로,
// "이런 자재가 있다"는 목록만 담는다. 재고에 넣을 때 여기서 골라 쓴다.
//
// 목록은 두 군데서 온다.
//  ① 업체 자료 — 경진전기(kjshop.kr)에서 상품 이름과 규격을 긁어온 것
//     (material_catalog_vendor.dart, 900건 남짓). 업체가 부르는 이름 그대로다.
//  ② 앱이 적어 둔 것 — 업체 목록에 없는 곤질레다(컨듈렛)
// 둘 다 서버 'material_catalog'에 담기고, 화면에서 이름·규격을 고치고 빼고
// 더할 수 있다.

import 'material_catalog_vendor.dart';

/// 자재 분류. 화면 칩과 카탈로그가 같은 이름을 쓰게 한 곳에 모아 둔다.
const Map<String, String> kMaterialCategoryLabels = {
  'CONDUIT': '전선관',
  'FLEX': '후렉시블',
  'ACC': '부속',
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
  final String source; // 어디서 온 자료인지 (예: 경진전기)

  const CatalogItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    this.spec = '',
    this.kind = '',
    this.order = 0,
    this.source = '',
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'category': category,
    'spec': spec,
    'kind': kind,
    'unit': unit,
    'order': order,
    'source': source,
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
    source: (m['source'] ?? '').toString(),
  );

  /// 검색에 쓰는 글자. 이름·규격·갈래·분류를 한 줄로 붙인다.
  String get searchText =>
      '$name $spec $kind ${materialCategoryLabel(category)}'.toLowerCase();
}

// ── 앱이 적어 둔 목록: 곤질레다(컨듈렛) ──
// 업체 목록에는 없어서 여기에 적어 둔다. 전선관 작업에서 선을 꺾거나 빼낼 때
// 쓰는 부속이다. 전선관 호칭을 따라간다.
const List<int> _conduletSizes = [16, 22, 28, 36, 42, 54];

const List<List<String>> _conduletKinds = [
  ['condulet_lb', '곤질레다 LB형'],
  ['condulet_ll', '곤질레다 LL형'],
  ['condulet_lr', '곤질레다 LR형'],
  ['condulet_t', '곤질레다 T형'],
  ['condulet_c', '곤질레다 C형'],
  ['condulet_cover', '곤질레다 커버'],
];

/// 앱이 적어 둔 자재(곤질레다).
List<CatalogItem> builtinMaterialCatalog() {
  final out = <CatalogItem>[];
  var order = 0;
  for (final kind in _conduletKinds) {
    for (final s in _conduletSizes) {
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

// ── 업체 자료: 경진전기에서 긁어온 목록 ──

/// 어디서 긁어온 자료인지.
const String kVendorCatalogSource = '경진전기';

/// 업체 목록을 읽어 자재 한 줄씩으로 만든다.
/// 한 줄 생김새: 아이디|이름|분류|규격|갈래|단위
List<CatalogItem> vendorMaterialCatalog() {
  final out = <CatalogItem>[];
  var order = 1000;
  for (final raw in kVendorCatalogRaw) {
    final p = raw.split('|');
    if (p.length < 6) continue;
    out.add(
      CatalogItem(
        id: p[0],
        name: p[1],
        category: p[2],
        spec: p[3],
        kind: p[4],
        unit: p[5],
        order: order += 10,
        source: kVendorCatalogSource,
      ),
    );
  }
  return out;
}

/// 서버에 심을 목록 전체(업체 자료 + 앱이 적어 둔 것).
List<CatalogItem> allMaterialCatalog() => [
  ...vendorMaterialCatalog(),
  ...builtinMaterialCatalog(),
];

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
