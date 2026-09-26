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
// 국내 자재(2026-09-26 카탈로그 확인):
// - 용성전기 고정식 단자대 FT: 카탈로그 11-3 Fixing Terminal Block p.336·337(표 L·W·H·M).
//   나사로 판에 다는 한 덩어리 제품이라 극수마다 길이가 따로 정해져 있다. 20A는 3·4·6·10·12·15·
//   20P, 30A는 3·4·6·10P만 나온다(5·7·8·9·11·13·14·16~19P는 없다 — 카탈로그·대리점 목록 같음).
//   깊이 = 몸통 H + 투명 커버 3.9. 8P가 필요하면 건흥 KH-6020-8이 있다.
// - 건흥전기(KOINO) 고정식 단자대 KH-6020: 카탈로그 PART8 p.419(가로 L·세로 W 30·높이 H 27).
// - 하니웰(한국하니웰) 서킷 프로텍터 GCP: 데이터시트 2016-05 p.5(1P 17.5·2P 35 × 73, 깊이 65).
//   DIN 레일에 달면 레일 7.5를 더했다(72.5). 예전에 "하이웰코리아"로 적었던 것은 하니웰이다.
// - 용성전기 문짝 부품(표시등·누름버튼·셀렉터, Ø22 A형·PL2·PL3): 카탈로그 p.155·169·171·174·266.
//   정면 = 베젤 지름, 깊이 = 패널 뒤로 들어가는 길이(접점 블록 1개).
// UE 압력 스위치는 계기 목록(kInstrumentPresets "UE")에 도면 치수로 넣었다.
//
// 2026-09-26 저녁 추가(사용자 요청 "허니웰·차단기 등 국내·발전소에서 많이 쓰는 것"):
// - ABB System pro M compact S200(S201/S202/S203) 소형 차단기: 데이터시트 2CDC002157D0202
//   (2012-08) p.3 표·p.10 치수도. 국내 자재는 아니지만 국내 EPC 규격서에 비교 브랜드로 자주 나온다.
// - 옴론 PYF08A·PYF14A 소켓 단품(릴레이 없이 소켓만): 카탈로그 J03E-EN-01A p.11·12. 이미 있는
//   "릴레이+소켓" 항목과 정면은 같고 깊이만 소켓 몸통(31)만큼.
// - 하니웰 GCP-33AN(3P): 대리점 재배포 도면에서 폭만 확인한 단일 출처 어림값, 단종 표기 있음.
//   조사에서 GCP 말고 다른 허니웰 기초 전기자재(단자대·릴레이·전원)는 국내 판매 근거를 못 찾았다.
//   LS Metasol 더 큰 프레임(225AF·400AF)은 카탈로그가 스캔 이미지라 이번에도 못 넣었다.
// - 슈나이더 Acti9 iC60N(1P·3P+N), 지멘스 5SY6102-7(1P): 제조사 정식 데이터시트 직접 열람,
//   국내 EPC 규격서 비교 브랜드로 자주 나온다(2026-09-26 저녁 추가 확인). 대륙(DACO) 전 계열과
//   LS 국내형 ABN203c·403c(225·400AF)는 조사됐지만 단일 출처·판매처뿐이라 넣지 않았다.
// - 성호제어기기(SUNGHO CONTROLS, "suncho") 조립식 단자대 SHT-TB-15·25: 사용자 요청으로
//   추가(2026-09-26 밤). 제조사 카탈로그(폰트 깨짐 → 이미지로 렌더링해 읽음) + 미수미 한국
//   교차 확인.
// - 조양전기 CYMAX CYIT-BT-120 온도 조절기(팬 히터 조절기): 처음엔 "CY MAX"만으로 19개
//   검색어를 돌려도 못 찾았는데, 사용자가 정확한 모델 번호(CYIT-BT-120)를 알려줘서 대리점이
//   재게시한 제조사 카탈로그 도면을 찾았다. 단일 출처, 깊이는 도면 숫자 두 개(55·42) 중 큰
//   쪽으로 넣었다(사용자 확인: 깊이는 크게 안 따져도 됨).

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

  /// 방폭형 압력 스위치(예전 사진 어림 항목). 목록에서는 뺐고(UE는 계기 목록에 도면 치수로 있다)
  /// 예전에 놓은 부품을 그리려고 이름만 남긴다.
  static const String pswitch = 'el_pswitch';

  /// 고정식 단자대(나사 고정 한 덩어리). 'el_ft:극 수'.
  static const String ft = 'el_ft';

  /// 문짝 부품: 표시등·누름버튼·비상 누름버튼·셀렉터(앞에서 본 둥근 베젤).
  static const String lamp = 'el_lamp';
  static const String pb = 'el_pb';
  static const String estop = 'el_estop';
  static const String selector = 'el_sel';

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

/// 고정식 단자대(용성 FT·건흥 KH-6020): [극 수, 길이 L] 목록, 폭 W, 깊이.
/// 모델 이름의 '##'은 두 자리 극 수(용성 FT020-04), '#'은 그냥 극 수(건흥 KH-6020-8).
List<ModulePreset> _ft(
  String model,
  String amp,
  List<(int, double)> rows,
  double w,
  double d,
) => [
  for (final (n, l) in rows)
    ModulePreset(
      "${model.replaceAll('##', n.toString().padLeft(2, '0')).replaceAll('#', '$n')} 단자대 $amp ${n}P",
      l,
      w,
      shape: '${ElecShape.ft}:$n',
      depth: d,
    ),
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
  // 성호제어기기(SUNGHO CONTROLS) 조립식 단자대 SHT-TB-15·25: 제조사 카탈로그(폰트가 깨져
  // 있어 페이지를 이미지로 렌더링해 직접 읽음) p.86·88 + 미수미 한국 성호 브랜드 페이지(피치
  // 값 교차 확인, 2026-09-26 조사). 끝판(세퍼레이터 SHNO) 두께는 카탈로그에 치수가 없어
  // 넣지 않았다(끝 0으로 계산 — 실제 묶음 길이는 이 값보다 끝판만큼 조금 더 길다).
  "조립식 단자대 (성호 SHT-TB)": [
    _tb("SHT-TB-15 단자대 15A", 10, 8.5, 0, 37.0, 39.0),
    _tb("SHT-TB-15 단자대 15A", 20, 8.5, 0, 37.0, 39.0),
    _tb("SHT-TB-25 단자대 25A", 10, 10.5, 0, 37.0, 39.0),
    _tb("SHT-TB-25 단자대 25A", 20, 10.5, 0, 37.0, 39.0),
  ],
  // 용성 FT020: W 30.2, H 19(+커버 3.9). FT030: W 35, H 26(+3.9).
  "고정식 단자대 (용성 FT)": [
    ..._ft(
      "YS FT020-##",
      "20A",
      const [
        (3, 56),
        (4, 67),
        (6, 89),
        (10, 136),
        (12, 162),
        (15, 200),
        (20, 257),
      ],
      30.2,
      22.9,
    ),
    ..._ft(
      "YS FT030-##",
      "30A",
      const [(3, 67), (4, 79), (6, 102.5), (10, 156)],
      35,
      29.9,
    ),
  ],
  // 건흥 KH-6020: 세로 W 30, 높이 H 27.
  "고정식 단자대 (건흥 KH-6020)": _ft(
    "KH-6020-#",
    "20A",
    const [
      (3, 54),
      (4, 66),
      (6, 89),
      (8, 112),
      (10, 136),
      (12, 160),
      (15, 196),
      (20, 251),
    ],
    30,
    27,
  ),
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
  // ABB System pro M compact S200: 데이터시트 2CDC002157D0202(2012-08) p.3 표·p.10 치수도.
  // 국내 자재는 아니지만 국내 EPC 규격서에 비교 브랜드로 자주 나온다(2026-09-26 조사).
  "차단기 (ABB)": [
    const ModulePreset(
      "S201 소형 차단기 1P (ABB)",
      17.5,
      88,
      shape: '${ElecShape.mcb}:1',
      depth: 69,
    ),
    const ModulePreset(
      "S202 소형 차단기 2P (ABB)",
      35,
      88,
      shape: '${ElecShape.mcb}:2',
      depth: 69,
    ),
    const ModulePreset(
      "S203 소형 차단기 3P (ABB)",
      52.5,
      88,
      shape: '${ElecShape.mcb}:3',
      depth: 69,
    ),
  ],
  // 슈나이더 Acti9 iC60N: 제조사 정식 Product datasheet 직접 열람(1P A9F74106 2022-09,
  // 3P+N A9F04732 2021-10). 높이가 1P(85)와 3P+N(91)에서 다른 건 실제로 그렇다(오타 아님,
  // 3P+N은 4모듈폭 72mm). 국내 EPC 규격서 비교 브랜드(2026-09-26 조사).
  "차단기 (슈나이더)": [
    const ModulePreset(
      "iC60N 소형 차단기 1P (슈나이더)",
      18,
      85,
      shape: '${ElecShape.mcb}:1',
      depth: 78.5,
    ),
    const ModulePreset(
      "iC60N 소형 차단기 3P+N (슈나이더)",
      72,
      91,
      shape: ElecShape.mccb,
      depth: 78.5,
    ),
  ],
  // 지멘스 5SY6102-7: 제조사 정식 Data sheet+치수도 직접 열람(2024-09). 판 면에서 깊이는
  // 전체 76mm(설치 깊이만 보면 70mm) — 다른 항목처럼 판 면 기준 큰 값을 썼다(2026-09-26 조사).
  "차단기 (지멘스)": [
    const ModulePreset(
      "5SY6 소형 차단기 1P (지멘스)",
      18,
      90,
      shape: '${ElecShape.mcb}:1',
      depth: 76,
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
    // 릴레이 없이 소켓만(이미 있는 릴레이를 꽂을 때). 옴론 카탈로그 J03E-EN-01A p.11·12,
    // 소켓 단품 깊이 31 — 위 "릴레이+소켓" 항목의 어림값(31+릴레이 몸통≈65)과 맞는다(2026-09-26 확인).
    const ModulePreset(
      "PYF08A 소켓 단품 (옴론, 8핀)",
      23,
      72,
      shape: ElecShape.relay,
      depth: 31,
    ),
    const ModulePreset(
      "PYF14A 소켓 단품 (옴론, 14핀)",
      29.5,
      72,
      shape: ElecShape.relay,
      depth: 31,
    ),
    const ModulePreset(
      "MC-9b·12b·18b 전자 접촉기 (LS)",
      45,
      73.5,
      shape: ElecShape.mc,
      depth: 86,
    ),
  ],
  // 조양전기 CYMAX CYIT-BT(온도조절기, "-120"은 0~120°C 눈금판): 베트남 대리점이 재게시한
  // 제조사 카탈로그 치수도(단일 출처, 스캔본이라 육안 확인) — thietbidienlocphat.vn
  // Catalog-CYMAX-THERMOSTAT-AL-SPACE-HEATER.pdf. 정면 65×100(고정귀 포함), 깊이는 도면에
  // 55·42 두 수치가 겹쳐 있어(사용자 확인: 깊이는 크게 안 따져도 됨) 큰 쪽 55로 넣는다.
  // 레일·판에 나사·클립으로 고정하는 표면 부착형(문짝 베젤형 아님).
  "온도 조절기 (조양 CYMAX)": [
    const ModulePreset(
      "CYIT-BT-120 온도 조절기 (조양)",
      65,
      100,
      shape: ElecShape.psu,
      depth: 55,
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
  // 하니웰 GCP 데이터시트 p.5: 1P 17.5·2P 35 × 73(단자 포함), 몸통 깊이 65 + DIN 레일 7.5.
  // GCP-33AN(3P): 대리점이 재배포한 도면에서 폭 52.5(=17.5×3)만 실측 확인, 높이·깊이는 1P/2P
  // 값을 그대로 늘려 잡은 값(2026-09-26, 단일 출처). 여러 판매처가 "제조 단종"이라 적어 두었다.
  "서킷 프로텍터 (하니웰)": [
    const ModulePreset(
      "GCP-31AN 서킷 프로텍터 1P",
      17.5,
      73,
      shape: '${ElecShape.mcb}:1',
      depth: 72.5,
    ),
    const ModulePreset(
      "GCP-32AN 서킷 프로텍터 2P",
      35,
      73,
      shape: '${ElecShape.mcb}:2',
      depth: 72.5,
    ),
    const ModulePreset(
      "GCP-33AN 서킷 프로텍터 3P (단종 표기, 어림값)",
      52.5,
      73,
      shape: '${ElecShape.mcb}:3',
      depth: 72.5,
    ),
  ],
  // 문짝에 다는 것. 정면 = 베젤 지름, 깊이 = 패널 뒤 길이(접점 블록 1개).
  // APL22 84(최대) − 앞 12.7 = 71, P1-22 33.6+22.5+3.6, EP22 32.4+22.5+3.6, R22 36.8+20.7.
  "표시등·스위치 (용성, 문짝)": [
    const ModulePreset(
      "APL22 표시등 Ø22",
      31,
      31,
      shape: ElecShape.lamp,
      depth: 71,
    ),
    const ModulePreset(
      "P1-22 누름버튼 Ø22",
      31.3,
      31.3,
      shape: ElecShape.pb,
      depth: 59.7,
    ),
    const ModulePreset(
      "EP22 비상 누름버튼 Ø22",
      40.3,
      40.3,
      shape: ElecShape.estop,
      depth: 58.5,
    ),
    const ModulePreset(
      "R22 셀렉터 스위치 Ø22",
      31.3,
      31.3,
      shape: ElecShape.selector,
      depth: 57.5,
    ),
    const ModulePreset(
      "PL2 표시등 Ø25",
      29.8,
      29.8,
      shape: ElecShape.lamp,
      depth: 48.8,
    ),
    const ModulePreset(
      "PL3 표시등 Ø30",
      34,
      34,
      shape: ElecShape.lamp,
      depth: 47.8,
    ),
  ],
};
