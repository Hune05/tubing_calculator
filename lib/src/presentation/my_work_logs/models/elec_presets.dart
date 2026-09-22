import 'layout_board_models.dart';

// 🚀 캐비닛 측판·중판에 다는 전기 부품(DIN 레일). 정면 가로×세로(mm), 깊이는 판 면에서(레일 포함).
// 출처(2026-09 조사): 피닉스 컨택트 데이터시트(UK 2,5 N 3001501, UK 5 N 3004362, UT 2,5 3044076,
// UT 4 3044102, UT 4-MTD 3046184, UK 5-HESI 3004100, PT 2,5 3209510, PLT-SEC 2907925,
// VAL-MS 2800103, MINI MCR-2 2902037), LS ELECTRIC MCB&RCD 카탈로그(2022-04 p.55·58),
// LS Metasol MCCB(E_1112)·MS(p.86), 민웰 DR-60·DR-120·NDR-120·SDR-120·HDR-60 사양서,
// 옴론 MY·PYF 소켓, M-System ES-5518(W2VS)·ES-5026(M2DY).
// 어림: 단자대 묶음 = 극수 × 한 극 폭 + 끝판 한 장. 민웰 전원·LS 소형 차단기 깊이는 레일 윗면
// 기준 값에 레일 7.5를 더했다. 릴레이+소켓 깊이는 소켓 31 + 릴레이 몸통으로 어림(65).

class ElecShape {
  /// 단자대 묶음. 'el_tb:극 수'.
  static const String tb = 'el_tb';

  /// 소형 차단기·누전 차단기. 'el_mcb:극 수'.
  static const String mcb = 'el_mcb';
  static const String mccb = 'el_mccb';
  static const String psu = 'el_psu';
  static const String relay = 'el_relay';
  static const String mc = 'el_mc';
  static const String spd = 'el_spd';
  static const String iso = 'el_iso';
  static const String rail = 'el_rail';

  static bool isElec(String? s) => s != null && s.startsWith('el_');

  /// 'el_tb:10' → 10(극 수)
  static double? pitch(String s) {
    final i = s.indexOf(':');
    return i < 0 ? null : double.tryParse(s.substring(i + 1));
  }
}

ModulePreset _tb(
  String name,
  int poles,
  double pitch,
  double end,
  double h,
  double d,
) => ModulePreset(
  "$name ${poles}P",
  ((poles * pitch + end) * 10).roundToDouble() / 10,
  h,
  shape: '${ElecShape.tb}:$poles',
  depth: d,
);

final Map<String, List<ModulePreset>> kElecPresets = {
  "단자대 (피닉스)": [
    _tb("UK 2.5N 단자대", 10, 5.2, 1.8, 42.5, 47),
    _tb("UK 2.5N 단자대", 20, 5.2, 1.8, 42.5, 47),
    _tb("UK 5N 단자대", 10, 6.2, 1.8, 42.5, 47),
    _tb("UT 2.5 단자대", 10, 5.2, 2.2, 47.7, 47.5),
    _tb("UT 2.5 단자대", 20, 5.2, 2.2, 47.7, 47.5),
    _tb("UT 4 단자대", 10, 6.2, 2.2, 47.7, 47.5),
    _tb("PT 2.5 푸시인 단자대", 10, 5.2, 2.2, 48.5, 36.5),
    _tb("UT 4-MTD 단로 단자대", 10, 6.2, 2.2, 57.8, 47.5),
    _tb("UK 5-HESI 퓨즈 단자대", 5, 8.2, 0, 72.5, 56.5),
  ],
  "차단기 (LS)": [
    const ModulePreset(
      "BKN 소형 차단기 1P",
      17.8,
      81,
      shape: '${ElecShape.mcb}:1',
      depth: 75.5,
    ),
    const ModulePreset(
      "BKN 소형 차단기 2P",
      35.6,
      81,
      shape: '${ElecShape.mcb}:2',
      depth: 75.5,
    ),
    const ModulePreset(
      "BKN 소형 차단기 3P",
      53.4,
      81,
      shape: '${ElecShape.mcb}:3',
      depth: 75.5,
    ),
    const ModulePreset(
      "RKN-b 누전 차단기 2P",
      35.2,
      81,
      shape: '${ElecShape.mcb}:2',
      depth: 75.5,
    ),
    const ModulePreset(
      "ABN52c 배선용 차단기 2P",
      50,
      130,
      shape: ElecShape.mccb,
      depth: 82,
    ),
    const ModulePreset(
      "ABN53c 배선용 차단기 3P",
      75,
      130,
      shape: ElecShape.mccb,
      depth: 82,
    ),
    const ModulePreset(
      "ABN103c 배선용 차단기 3P",
      75,
      130,
      shape: ElecShape.mccb,
      depth: 82,
    ),
  ],
  "전원·릴레이·MC": [
    const ModulePreset(
      "DR-60-24 전원 (민웰)",
      78,
      93,
      shape: ElecShape.psu,
      depth: 63.5,
    ),
    const ModulePreset(
      "HDR-60-24 전원 (민웰)",
      52.5,
      90,
      shape: ElecShape.psu,
      depth: 62,
    ),
    const ModulePreset(
      "DR-120-24 전원 (민웰)",
      65.5,
      125.2,
      shape: ElecShape.psu,
      depth: 107.5,
    ),
    const ModulePreset(
      "NDR-120-24 전원 (민웰)",
      40,
      125.2,
      shape: ElecShape.psu,
      depth: 121,
    ),
    const ModulePreset(
      "SDR-120-24 전원 (민웰)",
      40,
      125.2,
      shape: ElecShape.psu,
      depth: 121,
    ),
    const ModulePreset(
      "MY2N 릴레이+PYF08A 소켓 (옴론)",
      23,
      72,
      shape: ElecShape.relay,
      depth: 65,
    ),
    const ModulePreset(
      "MY4N 릴레이+PYF14A 소켓 (옴론)",
      29.5,
      72,
      shape: ElecShape.relay,
      depth: 65,
    ),
    const ModulePreset(
      "MC-9b·12b·18b 전자 접촉기 (LS)",
      45,
      73.5,
      shape: ElecShape.mc,
      depth: 86,
    ),
  ],
  "서지·신호 변환": [
    const ModulePreset(
      "PLT-SEC 서지 보호기 (피닉스)",
      17.7,
      101,
      shape: ElecShape.spd,
      depth: 74.5,
    ),
    const ModulePreset(
      "VAL-MS 서지 보호기 2P (피닉스)",
      35.6,
      89.8,
      shape: ElecShape.spd,
      depth: 65.7,
    ),
    const ModulePreset(
      "W2VS 신호 변환기 (M-System)",
      29.5,
      88.5,
      shape: ElecShape.iso,
      depth: 114,
    ),
    const ModulePreset(
      "M2DY 분배기 (M-System)",
      23,
      70.5,
      shape: ElecShape.iso,
      depth: 114,
    ),
    const ModulePreset(
      "MINI MCR-2 변환기 5개 (피닉스)",
      31,
      110.5,
      shape: ElecShape.iso,
      depth: 120.5,
    ),
  ],
  "DIN 레일": [
    const ModulePreset(
      "DIN 레일 35×7.5",
      1000,
      35,
      shape: ElecShape.rail,
      depth: 7.5,
    ),
    const ModulePreset(
      "DIN 레일 35×15",
      1000,
      35,
      shape: ElecShape.rail,
      depth: 15,
    ),
  ],
};
