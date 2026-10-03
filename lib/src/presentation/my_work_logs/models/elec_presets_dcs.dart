import 'elec_presets.dart';
import 'layout_board_models.dart';

// 🚀 PLC·DCS·계장 캐비닛 부품: I/O 모듈, 노드 유닛, 본질안전 배리어, 인터페이스 릴레이, 24V 전원, 이더넷 스위치.
// 2026-09-27 제조사 데이터시트 원문에서 서로 다른 문서 두 곳 이상이 맞는 값만 넣었다(가로×세로, 깊이 = 설치 면에서 앞까지).
// "확정" 중 일부는 같은 제조사의 다른 판·문서끼리 맞은 것이다. 원자료: docs/전기부품_카탈로그_조사_2026-09-27/dcs_plc.md.
// 검색 요약이 세로·깊이를 뒤바꾼 사례가 있어(QUINT-PS/10 등) 원문 데이터시트 값만 썼다.
// 넣지 않은 것(단일 출처·충돌·못 읽음): LS XGT 모듈(단일), 로크웰 5069·1734·1756 I/O 모듈, 에머슨 CHARM·벌크 전원,
//   ABB S800 I/O 모듈(깊이 97/102 충돌)·TU830, 하니웰 C300 IOTA(깊이 없음), MTL 5500·4500, 허쉬만 RS20·피닉스 FL SWITCH(깊이 충돌),
//   웨이드뮬러 TOZ SSR·오므론 G2R·G3NA(단일), 지멘스 LOGO!Power·SITOP PSE202U(단일), QUINT-DIODE.

ModulePreset _io(String name, double w, double h, double d, String style) =>
    ModulePreset(name, w, h, shape: '${ElecShape.io}:$style', depth: d);

final Map<String, List<ModulePreset>> kDcsPresets = {
  // 지멘스 S7-1500: 데이터시트 원문(CPU 1511-1·PS 25W·DI 16 HF 35mm형, DI 16 BA 25mm형, PS 60W 70mm형).
  // ET 200SP: DI 8점 15mm, BaseUnit BU15, IM 155-6 PN ST. 로크웰 1756 섀시 A7·A13, 전원 PA72·PA50.
  "PLC 모듈 (지멘스 S7-1500·ET 200SP, 로크웰 1756)": [
    _io("S7-1500 35mm 모듈 (지멘스, CPU 1511·PS 25W·DI 16 HF)", 35, 147, 129, 's7'),
    _io("S7-1500 25mm 모듈 (지멘스, DI 16 BA)", 25, 147, 129, 's7'),
    _io("S7-1500 PS 60W 전원 (지멘스)", 70, 147, 129, 's7ps'),
    _io("ET 200SP 15mm 모듈 (지멘스, DI 8점)", 15, 73, 58, 'et'),
    _io("ET 200SP BaseUnit BU15 (지멘스)", 15, 117, 35, 'etbu'),
    _io("ET 200SP IM 155-6 PN ST (지멘스)", 50, 117, 74, 'etim'),
    const ModulePreset(
      "1756-A7 7슬롯 섀시 (로크웰)",
      367.6,
      158,
      shape: '${ElecShape.chassis}:7',
      depth: 145,
    ),
    const ModulePreset(
      "1756-A13 13슬롯 섀시 (로크웰)",
      587.6,
      158,
      shape: '${ElecShape.chassis}:13',
      depth: 145,
    ),
    _io("1756-PA72 전원 (로크웰)", 112, 140, 145, 'pa'),
    _io("1756-PA50 슬림 전원 (로크웰)", 78, 140, 145, 'pa'),
  ],
  // 요꼬가와 CENTUM: 노드 유닛 ANB10D/11D(19인치 랙), FIO 모듈, 제어 유닛 AFV10D/30D, 단자대 ATA4S·ATA4D·ATK4A,
  // DIN 단자판 A1BA4D·A1BD5D(요꼬가와 문서 확정). 에머슨 DeltaV SQ·SX 제어기와 CIOC 카리어. ABB AC 800M.
  "DCS (요꼬가와·에머슨·ABB)": [
    const ModulePreset(
      "ANB10D·ANB11D 노드 유닛 19인치 랙 (요꼬가와)",
      482.6,
      221.5,
      shape: '${ElecShape.rack}:anb',
      depth: 205,
    ),
    const ModulePreset(
      "AFV10D·AFV30D 제어 유닛 19인치 랙 (요꼬가와)",
      482.6,
      265.9,
      shape: '${ElecShape.rack}:afv',
      depth: 207,
    ),
    _io("FIO 모듈 AAI141·ADV151 등 (요꼬가와)", 32.8, 130, 107.5, 'fio'),
    _io("ATA4S계 단자대 (요꼬가와)", 32.6, 114, 60.5, 'tba'),
    _io("ATA4D계 단자대 (요꼬가와)", 65.6, 114, 72, 'tba2'),
    _io("ATK4A 단자대 (요꼬가와)", 32.6, 114, 36.2, 'tba'),
    _io("A1BA4D DIN 단자판 (요꼬가와)", 110, 85.5, 54, 'din'),
    _io("A1BD5D DIN 단자판 (요꼬가와)", 210, 85.5, 68, 'din'),
    _io("DeltaV SQ·SX 제어기 (에머슨)", 41.8, 199.3, 162, 'dv'),
    _io("DeltaV CIOC 이중화 캐리어 (에머슨)", 125, 186, 158.3, 'carrier'),
    _io("AC 800M PM851~PM866 + TP830 (ABB)", 119, 186, 135, 'cpu'),
    _io("AC 800M PM891 + 베이스 (ABB)", 200, 186, 102, 'cpu'),
    _io("CI854 통신 유닛 + TP854 (ABB)", 59, 185, 127.5, 'ci'),
    _io("TU810 단자 유닛 (ABB, S800)", 64, 170, 64, 'tu'),
  ],
  // 본질안전 배리어·신호 분리기: P+F KFD2·KCD2는 2023·2013 데이터시트(2007판은 높이 119로 달라 뺐다),
  // 튜르크 IM33-11Ex-Hi/24VDC. 정면은 얇은 세로 막대(위·아래 3핀 단자대, LED, 라벨 창).
  "본질안전 배리어 (P+F·튜르크)": [
    ModulePreset(
      "KFD2-STC4-Ex1 배리어 (P+F, 20mm)",
      20,
      124,
      shape: '${ElecShape.bar}:pf',
      depth: 115,
    ),
    ModulePreset(
      "KFD2-SOT2·SR2·UT2·EB2 배리어 (P+F, 20mm)",
      20,
      119,
      shape: '${ElecShape.bar}:pf',
      depth: 115,
    ),
    ModulePreset(
      "KFD2-CD-Ex1.32·CR-Ex1.30 배리어 (P+F, 20mm)",
      20,
      107,
      shape: '${ElecShape.bar}:pf',
      depth: 115,
    ),
    ModulePreset(
      "KFD2-GUT-Ex1.D 배리어 (P+F, 40mm)",
      40,
      119,
      shape: '${ElecShape.bar}:pf',
      depth: 115,
    ),
    ModulePreset(
      "KCD2-SR-Ex2 배리어 (P+F, 12.5mm)",
      12.5,
      119,
      shape: '${ElecShape.bar}:pf',
      depth: 114,
    ),
    ModulePreset(
      "IM33-11Ex-Hi/24VDC 절연 증폭기 (튜르크, 18mm)",
      18,
      110,
      shape: '${ElecShape.bar}:turck',
      depth: 110,
    ),
  ],
  // 피닉스 PLC-RSC-24DC/21: 데이터시트 3부 일치. 웨이드뮬러 TRS 24VDC 1CO: 4부 일치.
  "인터페이스 릴레이 (피닉스·웨이드뮬러)": [
    ModulePreset(
      "PLC-RSC-24DC/21 릴레이 모듈 (피닉스, 6.2mm)",
      6.2,
      80,
      shape: '${ElecShape.ifr}:phoenix',
      depth: 94,
    ),
    ModulePreset(
      "TRS 24VDC 1CO 릴레이 모듈 (웨이드뮬러, 6.4mm)",
      6.4,
      90,
      shape: '${ElecShape.ifr}:weid',
      depth: 88,
    ),
  ],
  // 24V 전원: 피닉스 QUINT-PS/1AC/24DC/10(문서 2부, 눕히면 122×130×63), 웨이드뮬러 PRO ECO 120W와 PRO DM 20(확정),
  // 지멘스 SITOP PSU100S 5A·10A(데이터시트 + 사용설명서).
  "24V 전원 (피닉스·웨이드뮬러·지멘스)": [
    const ModulePreset(
      "QUINT-PS/1AC/24DC/10 전원 (피닉스)",
      60,
      130,
      shape: '${ElecShape.psu}:quint',
      depth: 125,
    ),
    const ModulePreset(
      "PRO ECO 120W 24V 5A 전원 (웨이드뮬러)",
      40,
      125,
      shape: '${ElecShape.psu}:weid',
      depth: 100,
    ),
    const ModulePreset(
      "PRO DM 20 이중화 다이오드 모듈 (웨이드뮬러)",
      32,
      125,
      shape: '${ElecShape.psu}:diode',
      depth: 125,
    ),
    const ModulePreset(
      "SITOP PSU100S 24V 5A 전원 (지멘스)",
      50,
      125,
      shape: '${ElecShape.psu}:sitop',
      depth: 120,
    ),
    const ModulePreset(
      "SITOP PSU100S 24V 10A 전원 (지멘스)",
      70,
      125,
      shape: '${ElecShape.psu}:sitop',
      depth: 120,
    ),
  ],
  // DIN 레일 이더넷 스위치: Moxa EDS-205A·208A·G308·508A 데이터시트 확정, 지멘스 SCALANCE XB005.
  "이더넷 스위치 (Moxa·지멘스)": [
    const ModulePreset(
      "EDS-205A 5포트 스위치 (Moxa)",
      30,
      115,
      shape: '${ElecShape.sw}:moxa:5',
      depth: 70,
    ),
    const ModulePreset(
      "EDS-208A 8포트 스위치 (Moxa)",
      50,
      114,
      shape: '${ElecShape.sw}:moxa:8',
      depth: 70,
    ),
    const ModulePreset(
      "EDS-G308 8포트 기가 스위치 (Moxa)",
      53,
      135,
      shape: '${ElecShape.sw}:moxa:8',
      depth: 105,
    ),
    const ModulePreset(
      "EDS-508A 8포트 스위치 (Moxa)",
      80.2,
      135,
      shape: '${ElecShape.sw}:moxa:8',
      depth: 105,
    ),
    const ModulePreset(
      "SCALANCE XB005 5포트 스위치 (지멘스)",
      45,
      100,
      shape: '${ElecShape.sw}:scalance:5',
      depth: 87,
    ),
  ],
};
