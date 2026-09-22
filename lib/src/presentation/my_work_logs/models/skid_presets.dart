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

  static bool isSkid(String? s) => s != null && s.startsWith('sk_');
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
