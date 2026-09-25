import 'layout_board_models.dart';

// 🚀 캐비닛 측판·중판에 다는 전기 부품(DIN 레일). 정면 가로×세로(mm), 깊이는 판 면에서(레일 포함).
// 출처(2026-09 조사): 피닉스 컨택트 데이터시트(UK 2,5 N 3001501, UK 5 N 3004362, UT 2,5 3044076,
// UT 4 3044102, UT 4-MTD 3046184, UK 5-HESI 3004100, PT 2,5 3209510, PLT-SEC 2907925,
// VAL-MS 2800103, MINI MCR-2 2902037), LS ELECTRIC MCB&RCD 카탈로그(2022-04 p.55·58),
// LS Metasol MCCB(E_1112)·MS(p.86), 민웰 DR-60·DR-120·NDR-120·SDR-120·HDR-60 사양서,
// 옴론 MY·PYF 소켓, M-System ES-5518(W2VS)·ES-5026(M2DY).
// 어림: 단자대 묶음 = 극수 × 한 극 폭 + 끝판 한 장. 민웰 전원·LS 소형 차단기 깊이는 레일 윗면
// 기준 값에 레일 7.5를 더했다. 릴레이+소켓 깊이는 소켓 31 + 릴레이 몸통으로 어림(65).
//
// "용성 고정식 단자대 4p~20p" 요청 메모(2026-09, 대화로 확정): "용성"은 용성전기(국내 단자대·
// 차단기 제조사)이고, 사용자가 확인해 준 대로 이 요청은 용성전기의 "고정식 단자대 (FT Type)"
// 시리즈를 4~20극까지 채워 달라는 것이다(아래 "단자대 (용성전기 FT Type, 추정)" 항목).
// 이 세션에서는 용성전기 정식 데이터시트를 구할 방법이 없었다(네트워크 프록시가 검색·외부
// 접속을 거의 다 막아 국내외 사이트(위키백과 포함)가 열리지 않았다). 검색 엔진 요약만으로 봐도
// FT Type은 전류(A) 규격별(10·15·20·30·60·100·150·200·300·400·500·600A)로 나오고, 문서화된
// 극수도 2·3·4·6·10·12·15·20P처럼 띄엄띄엄이라, "극수만 다르고 한 극 크기는 늘 같은" 피닉스
// 컨택트류 모듈형 단자대와는 다른 제품일 가능성이 크다(정확한 확인 불가). 그래도 사용자가
// 명시적으로 4~20극 전 구간을 요청했으므로 그대로 채우되, 한 극 폭·끝판·높이·깊이는 실제
// 용성전기 수치가 아니라 이 파일에 이미 있는 같은 급 모듈형 단자대(피닉스 UT 4, 아래 참고)
// 치수를 임시로 빌려 쓴 자리표시(placeholder)다. 실제 카탈로그를 구하면 편집 칸에서 반드시
// 고쳐야 한다. UK 5-HESI 퓨즈 단자대는 5극 고정 규격품(카탈로그상 극수를 늘릴 수 있는 낱개
// 조립형이 아니다)이라 이 확장과 무관하다.
//
// 압력 스위치·차단기 참고 항목(2026-09, 사용자 제공 사진): 아래 "압력 스위치 (참고용)"·
// "회로 보호기 (하이웰코리아, 사진 기준 추정)" 두 항목은 이 파일의 다른 모든 항목과 달리
// 검증된 데이터시트가 없다(용성전기와는 무관한, 사진 속 제품 그대로의 브랜드다). 사용자가
// 올린 현장 사진만 보고 크기를 어림한 것이고(사진에 자를 비교할 기준자가 없어 mm를 정확히
// 잴 수 없었다), 삼화기전 F-7 곤질레다처럼(skid_presets.dart 참고, "카탈로그에 몸통 치수가
// 없어 대략값 — 실제를 재서 편집 칸에서 고칩니다") 대략값으로 넣어 두었다. 실제 치수는 놓은
// 뒤 편집 칸에서 반드시 실측해 고쳐야 한다.

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

  /// 방폭형 압력 스위치(둥근 몸통 + 아래 나사 목). 대략값(참고용, 위 머리말 참고).
  static const String pswitch = 'el_pswitch';

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

/// 4~20극(요청: "용성 고정식 단자대 4p~20p" → 용성전기 FT Type, 위 머리말 참고).
const List<int> _kTbPoleRange = [
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11,
  12,
  13,
  14,
  15,
  16,
  17,
  18,
  19,
  20,
];

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
  "단자대 (용성전기 FT Type, 추정)": [
    // 위 머리말 참고: 실제 용성전기 FT Type 데이터시트를 못 구했다. 한 극 폭 6.2·끝판 2.2·
    // 높이 47.7·깊이 47.5는 용성전기 실측치가 아니라 같은 파일의 피닉스 UT 4(모듈형 단자대)
    // 치수를 그대로 빌려 온 자리표시다. 실제 카탈로그가 생기면 편집 칸에서 고친다.
    for (final n in _kTbPoleRange)
      _tb("FT Type 고정식 단자대 (용성전기, 추정)", n, 6.2, 2.2, 47.7, 47.5),
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
  // 아래 두 항목은 데이터시트가 아니라 사용자가 보낸 현장 사진으로 어림한 대략값이다(위
  // 머리말 참고). 실제로는 놓은 뒤 편집 칸에서 실측해 고쳐야 한다.
  "압력 스위치 (참고용)": [
    const ModulePreset(
      // 유나이티드 일렉트릭 컨트롤스 방폭형 압력 스위치(태그 예: OIL PUMP DISCH. PSLL,
      // 발전 설비 보조계통에서 흔히 쓰는 오일펌프 토출 저저압 스위치). 사진에 기준자가 없어
      // 몸통 지름은 이 계열 방폭 하우징의 흔한 크기(85~100mm)로 어림했다.
      "방폭 압력 스위치 (United Electric, 대략값)",
      92,
      92,
      shape: ElecShape.pswitch,
      depth: 100,
    ),
  ],
  "회로 보호기 (하이웰코리아, 사진 기준 추정)": [
    const ModulePreset(
      // 하이웰코리아 서킷 프로텍터(Circuit Protector GCP-32AN, AC/DC 5A). 데이터시트를
      // 못 구해 겉모습이 비슷한 단극 소형 차단기(BKN 소형 차단기 1P 17.8×81, 깊이 75.5)와
      // 같은 크기로 어림했다. el_mcb 그림을 그대로 쓴다(DIN 레일에 다는 작은 상자 모양이 닮아서).
      // 용성전기와는 무관하다(사진 속 제품 그대로).
      "서킷 프로텍터 GCP-32AN (Hiwell, 대략값)",
      17.8,
      81,
      shape: '${ElecShape.mcb}:1',
      depth: 75.5,
    ),
  ],
};
