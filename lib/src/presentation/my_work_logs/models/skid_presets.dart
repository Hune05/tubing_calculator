import 'package:tubing_calculator/src/data/models/steel_shape_db.dart';

import 'layout_board_models.dart';

// 🚀 스키드 평면도(위에서 본 모습)에 놓는 모듈: 형강 틀, 후강 전선관, 정션박스.
// 길이는 기본 1000mm로 놓고, 놓은 뒤 편집 칸에서 실제 길이로 고친다.

/// 도면 종류. 저장 문서의 'kind' 칸. 칸이 없으면 캐비닛(예전 도면).
const String kLayoutKindCabinet = 'cabinet';
const String kLayoutKindSkid = 'skid';

/// 스키드 도면 탭: 평면(중판 자리 kPlateMain을 쓴다)·정면·좌측면·우측면.
const String kSkidViewFront = 'front';
const List<String> kSkidViewOrder = ['main', kSkidViewFront, 'left', 'right'];

String skidViewLabel(String id) => switch (id) {
  kSkidViewFront => '정면',
  'left' => '좌측면',
  'right' => '우측면',
  _ => '평면',
};

/// 정면·측면 새 탭의 기본 높이(mm, 바닥~스키드 위 끝).
const double kSkidDefaultHeight = 1500;

/// 스키드 새 도면 기본 크기(길이 × 폭, mm).
const double kSkidDefaultLength = 2400;
const double kSkidDefaultWidth = 1200;

class SkidShape {
  static const String beam = 'sk_beam';
  static const String channel = 'sk_channel';
  static const String angle = 'sk_angle';
  static const String square = 'sk_square';
  static const String strut = 'sk_strut';
  static const String conduit = 'sk_conduit';
  static const String jb = 'sk_jb';

  // 전선관 부속(삼화기전 F-7 곤질레다, 커플링, 유니온 커플링).
  static const String cdLB = 'sk_cd_lb';
  static const String cdLL = 'sk_cd_ll';
  static const String cdLR = 'sk_cd_lr';
  static const String cdLT = 'sk_cd_lt';
  static const String cdLC = 'sk_cd_lc';
  static const String cdLX = 'sk_cd_lx';
  static const String coupling = 'sk_coupling';
  static const String union = 'sk_union';

  static bool isSkid(String? s) => s != null && s.startsWith('sk_');
  static bool isCondulet(String? s) => s != null && s.startsWith('sk_cd_');

  /// 전선관 부속(곤질레다·커플링·유니온 커플링).
  static bool isFitting(String? s) =>
      isCondulet(s) || s == coupling || s == union;
}

const double _kMemberLength = 1000;

/// 형강 이름("H형강 150x150x7x10")에서 위에서 본 폭. H형강·찬넬·앵글은 플랜지 폭(둘째 숫자),
/// 각파이프·스트럿은 첫째 숫자.
double? steelPlanWidth(String category, String label) {
  final nums = RegExp(
    r'(\d+(?:\.\d+)?)',
  ).allMatches(label).map((m) => double.parse(m.group(1)!)).toList();
  if (nums.isEmpty) return null;
  switch (category) {
    case 'BEAM':
    case 'CHANNEL':
    case 'ANGLE':
      return nums.length > 1 ? nums[1] : nums[0];
    default:
      return nums[0];
  }
}

List<ModulePreset> _steel(
  String category,
  List<SteelShapeItem> items,
  String shape,
) => [
  for (final it in items)
    if (steelPlanWidth(category, it.label) != null)
      ModulePreset(
        it.label,
        _kMemberLength,
        steelPlanWidth(category, it.label)!,
        shape: shape,
      ),
];

/// 스키드 틀 형강(형강 컷팅 규격표를 그대로 쓴다).
final Map<String, List<ModulePreset>> kSkidSteelPresets = {
  "H형강": _steel('BEAM', SteelShapeDB.hBeams, SkidShape.beam),
  "찬넬": _steel('CHANNEL', SteelShapeDB.channels, SkidShape.channel),
  "앵글": _steel('ANGLE', SteelShapeDB.angles, SkidShape.angle),
  "각파이프": _steel('SQUARE', SteelShapeDB.squarePipes, SkidShape.square),
  "스트럿": _steel('STRUT', SteelShapeDB.struts, SkidShape.strut),
};

/// 후강 전선관 바깥지름(mm). KS C 8401(JIS C 8305 G관과 같다).
const Map<int, double> kThickConduitOd = {
  16: 21.0,
  22: 26.5,
  28: 33.3,
  36: 41.9,
  42: 47.8,
  54: 59.6,
};

/// 박강 전선관 호칭과 바깥지름(mm). KS C 8422. 앱은 박강도 후강 호칭(16~54)으로 고르므로
/// 참고용(현장 자료 전선관 탭·단위 환산 배관 호칭표).
const Map<int, double> kThinConduitOd = {
  19: 19.1,
  25: 25.4,
  31: 31.8,
  39: 38.1,
  51: 50.8,
  63: 63.5,
  75: 76.2,
};

final Map<String, List<ModulePreset>> kSkidConduitPresets = {
  "후강 전선관 (바깥지름)": [
    for (final e in kThickConduitOd.entries)
      ModulePreset(
        "후강 전선관 ${e.key}",
        _kMemberLength,
        e.value,
        shape: SkidShape.conduit,
      ),
  ],
};

/// 정션박스(위에서 본 가로×세로). 많이 쓰는 크기만, 다른 크기는 놓은 뒤 고친다.
final Map<String, List<ModulePreset>> kSkidJbPresets = {
  "정션박스": [
    for (final s in const [
      [150, 150],
      [200, 200],
      [300, 200],
      [300, 300],
      [400, 300],
      [400, 400],
      [600, 400],
    ])
      ModulePreset(
        "정션박스 ${s[0]}×${s[1]}",
        s[0].toDouble(),
        s[1].toDouble(),
        shape: SkidShape.jb,
      ),
  ],
};

// ── 전선관 부속: 삼화기전 F-7 곤질레다·커플링·유니온 커플링 ──
// 종류·규격은 삼화기전 카탈로그(F-7 TYPE: LB·LL·LR·LT·LTB·LX·LC, 16~104)를 따른다.
// 삼화는 몸통 치수를 공개하지 않는다(홈페이지·카탈로그 2019-ED1 p.32~41을 그림까지 확인,
// 2026-09-26). 그래서 같은 모양(Ex e, 타원 몸통·뚜껑 나사 둘)인 국산 JK(정광, 경진전기 판매)
// 곤질레다 표 값을 쓴다 — LB·LL·LR·LC·LT 표의 A(폭)·B(높이)·C(길이). 우정·대승공업 표와도
// 22~54에서 몇 mm 안에서 맞는다. LX는 JK 표가 없어 폭 = 몸통 + 옆 허브 둘로 셈했다.
// 삼화 실물과 다르면 놓은 뒤 편집 칸에서 고친다.
// 크기: 가로 = 길이(끝 허브 포함), 세로 = 위에서 본 폭(옆 허브 포함), 깊이 = 바닥에서 본 높이
// (뚜껑이 위를 보게, 뒤 허브 포함). 스키드에서 PlacedItem.depth는 이 높이로 쓴다.

/// 규격별 곤질레다 [ㄱ자형(LB·LL·LR) 길이, 곧은형(LC·LT·LX) 길이, 몸통 폭, 몸통 높이(뚜껑 포함),
/// 옆 허브 돌출, 뒤 허브 돌출] (mm). JK 표: 옆 돌출 = LL의 A − LC의 A, 뒤 돌출 = LB의 B − LC의 B.
const Map<int, List<double>> kConduletSize = {
  16: [125, 146, 40, 46, 20, 20],
  22: [134, 156, 45, 53, 22, 21],
  28: [161, 187, 59, 63, 27, 28],
  36: [171, 197, 68, 73, 27, 27],
  42: [190, 215, 74, 83, 26, 27],
  54: [216, 243, 85, 100, 25, 26],
};

/// 규격별 커플링 [길이, 바깥지름] (mm). KS 후강 커플링 표(대일전기조명 KS 제품 표, JIS C 8330
/// 후강 커플링 표와 같다). 삼화 SVC는 KS C 8460 인증품이고 치수는 공개하지 않는다.
/// 54는 지름(68)이 길이(64)보다 커서, 커플링은 칸 비율이 아니라 돌린 횟수로 방향을 본다.
const Map<int, List<double>> kCouplingSize = {
  16: [38, 25],
  22: [44, 31],
  28: [50, 37.5],
  36: [56, 48.5],
  42: [56, 54.5],
  54: [64, 68],
};

/// 규격별 유니온 커플링(방폭 유니온, 삼화 EUF = 암+암) [길이, 너트 최대 외경] (mm).
/// 삼화 치수가 없어 국산 대승공업 DA-UF(암+암) 표 값. 28부터는 너트 지름이 길이보다 크다.
const Map<int, List<double>> kUnionSize = {
  16: [41, 38],
  22: [45, 44],
  28: [47, 53],
  36: [52, 62],
  42: [52, 70],
  54: [63, 82],
};

/// 칸 가로·세로 비율로 돌린 것을 어림하지 않고 돌린 횟수(각도 칸)만 보는 스키드 부품.
/// 커플링·유니온은 지름이 길이보다 클 수 있어서, "긴 쪽이 길이 방향"이라는 어림이 틀린다.
bool skidTurnsOnly(String? s) =>
    s == SkidShape.coupling || s == SkidShape.union;

ModulePreset _condulet(String type, String shape, int size) {
  final d = kConduletSize[size]!;
  final bool elbow =
      shape == SkidShape.cdLB ||
      shape == SkidShape.cdLL ||
      shape == SkidShape.cdLR;
  final double l = elbow ? d[0] : d[1];
  final double w = d[2], h = d[3], side = d[4], back = d[5];
  final double planW = switch (shape) {
    SkidShape.cdLL || SkidShape.cdLR || SkidShape.cdLT => w + side,
    SkidShape.cdLX => w + 2 * side,
    _ => w,
  };
  final double high = shape == SkidShape.cdLB ? h + back : h;
  return ModulePreset("곤질레다 $type $size", l, planW, shape: shape, depth: high);
}

final Map<String, List<ModulePreset>> kSkidFittingPresets = {
  for (final t in const [
    ['LB', SkidShape.cdLB],
    ['LL', SkidShape.cdLL],
    ['LR', SkidShape.cdLR],
    ['LT', SkidShape.cdLT],
    ['LC', SkidShape.cdLC],
    ['LX', SkidShape.cdLX],
  ])
    "곤질레다 ${t[0]}": [
      for (final size in kConduletSize.keys) _condulet(t[0], t[1], size),
    ],
  "커플링": [
    for (final e in kCouplingSize.entries)
      ModulePreset(
        "커플링 ${e.key}",
        e.value[0],
        e.value[1],
        shape: SkidShape.coupling,
        depth: e.value[1],
      ),
  ],
  "유니온 커플링": [
    for (final e in kUnionSize.entries)
      ModulePreset(
        "유니온 커플링 ${e.key}",
        e.value[0],
        e.value[1],
        shape: SkidShape.union,
        depth: e.value[1],
      ),
  ],
};
