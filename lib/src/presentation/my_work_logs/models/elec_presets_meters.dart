import 'elec_presets.dart';
import 'layout_board_models.dart';

// 🚀 판넬 계기·변류기·퓨즈/PE 좁은 단자(발전소·플랜트 판넬 안 기기). 2026-09-27 조사에서 서로 다른 문서 두 곳 이상이
// 맞는 값만 넣었다(정면 가로×세로, 깊이 = 설치 면에서 앞까지, 모르면 비움). 원자료: docs/전기부품_카탈로그_조사_2026-09-27.
// 넣지 않은 것(단일 출처·충돌·못 찾음): Autonics MT4W·MT4N, 한영 MP3·MP6·WM3, 슈나이더 PM2120(깊이 불일치),
//   ABB AMT1, 운영 WY-S47/S72/S96 각형과 WYCR·WYCS CT, 시티이텍 CT, 한영 HY-SQ4·용성 캠 스위치, 웨이드뮬러 WSI, 삼화·LS 계기·CT
//   (국내 자료는 사용자가 카탈로그를 주면 넣는다). 판넬 부속(팬·히터·덕트·글랜드·조명·접지 바)은 사용자 요청으로 제외.

final Map<String, List<ModulePreset>> kMeterPresets = {
  // 운영(WOONYOUNG) 디지털 96×48: 운영 카탈로그·운영 CAD(92×45)·경보 K-MAC(91×45)이 앞면 96×48·판넬 구멍 91×45로 일치
  // (깊이는 112·78·97+7로 문서마다 달라 비웠다). 디지털 96×96 WYTM-3AA/3AV: 카탈로그와 CAD가 앞면 96×96·구멍 92×92·깊이 약 80.
  // 광각 아날로그: WY-W08 80×80(구멍 Ø66)은 경보 WB형과, WY-W11 110×110(구멍 Ø100)은 경보 WA형과,
  // WY-R08 80×80(구멍 Ø65)은 경보 SC형과 일치. 깊이는 자료에 없어 비웠다.
  "판넬 미터 (운영·경보)": [
    const ModulePreset(
      "WYPMN48 디지털 미터 96×48 (운영, 판넬 구멍 91×45)",
      96,
      48,
      shape: '${ElecShape.meter}:dig1',
    ),
    const ModulePreset(
      "WYTM-3AA·3AV 디지털 미터 96×96 (운영, 판넬 구멍 92×92)",
      96,
      96,
      shape: '${ElecShape.meter}:dig3',
      depth: 80,
    ),
    const ModulePreset(
      "WY-W08 광각 아날로그 미터 80×80 (운영, 구멍 Ø66)",
      80,
      80,
      shape: '${ElecShape.meter}:ana',
    ),
    const ModulePreset(
      "WY-R08 아날로그 미터 80×80 (운영, 구멍 Ø65)",
      80,
      80,
      shape: '${ElecShape.meter}:ana',
    ),
    const ModulePreset(
      "WY-W11 광각 아날로그 미터 110×110 (운영, 구멍 Ø100)",
      110,
      110,
      shape: '${ElecShape.meter}:ana',
    ),
  ],
  // 슈나이더 METSECT5CC(관통 Ø21)·METSECT5MA(관통 Ø27, 부스바 창 25.5×15.5): 제조사 문서 2건씩 일치.
  "변류기 CT (슈나이더 METSECT)": [
    const ModulePreset(
      "METSECT5CC 변류기 (슈나이더, 관통 Ø21)",
      44,
      66,
      shape: '${ElecShape.ct}:ring',
      depth: 37,
    ),
    const ModulePreset(
      "METSECT5MA 변류기 (슈나이더, 관통 Ø27·부스바 창 25.5×15.5)",
      56,
      80,
      shape: '${ElecShape.ct}:bar',
      depth: 63,
    ),
  ],
  // 피닉스 퓨즈·PE 단자: ST 4-HESI(5×20 퓨즈, 지렛대 홀더)는 Farnell·Octopart 사본 2건 일치, PT 4-PE·ST 4-PE·UT 4-PE는 데이터시트.
  "퓨즈·PE 단자 (피닉스)": [
    const ModulePreset(
      "ST 4-HESI 퓨즈 단자 (피닉스, 5×20)",
      6.2,
      61.5,
      shape: '${ElecShape.term}:fuse',
      depth: 62.5,
    ),
    const ModulePreset(
      "PT 4-PE·ST 4-PE 접지 단자 (피닉스)",
      6.2,
      56,
      shape: '${ElecShape.term}:pe',
      depth: 36.5,
    ),
    const ModulePreset(
      "UT 4-PE 접지 단자 (피닉스)",
      6.2,
      47.7,
      shape: '${ElecShape.term}:pe',
      depth: 47.5,
    ),
  ],
};
