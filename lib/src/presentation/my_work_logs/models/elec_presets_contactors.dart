import 'elec_presets.dart';
import 'layout_board_models.dart';

// 🚀 접촉기·열동 계전기·전동기 보호 계전기·타이머·감시 계전기(발전소·플랜트 MCC·제어반).
// 2026-09-27 카탈로그 조사에서 서로 다른 문서 두 곳 이상이 맞는 값만 넣었다(정면 가로×세로, 깊이 = 판 면에서 앞까지).
// 같은 제조사의 다른 판·문서끼리 맞은 것은 "동일 제조사"라고 밝혔다. 원자료: docs/전기부품_카탈로그_조사_2026-09-27.
// 넣지 않은 것(단일 출처·충돌): LS MC-22b~150a(폭 45/69 충돌), LS MT-63·95, ABB AF·TF, 이튼 DILM, 지멘스 3RT·3RU·3RB·3RP,
//   슈나이더 RE 타이머·LRD32, 오므론 H3Y, 한영넉스 T48N, 오토닉스 ATE·PG-08 소켓(부속).
// 이미 있는 것: LS MC-9b·12b·18b(elec_presets.dart "전원·릴레이·MC").

final Map<String, List<ModulePreset>> kContactorPresets = {
  // 슈나이더 TeSys D LC1D 나사 단자판: 슈나이더 데이터시트(동일 제조사) D09·D12·D18 / D25·D32 / D40A·D65A.
  "접촉기 (슈나이더 TeSys D)": [
    const ModulePreset(
      "LC1D09·12·18 접촉기 3P (슈나이더)",
      45,
      77,
      shape: '${ElecShape.mc}:sch',
      depth: 86,
    ),
    const ModulePreset(
      "LC1D25·32 접촉기 3P (슈나이더)",
      45,
      85,
      shape: '${ElecShape.mc}:sch',
      depth: 92,
    ),
    const ModulePreset(
      "LC1D40A·65A 접촉기 3P (슈나이더)",
      55,
      122,
      shape: '${ElecShape.mc}:sch',
      depth: 120,
    ),
  ],
  // LS MT 열동: LS Metasol 카탈로그 p.170과 UL 카탈로그(MT-32는 제품 데이터시트도) 일치. 정면 특징은 사진·문서 설명.
  // 슈나이더 LRD08·16: 데이터시트 2건과 검색 요약(폭 45).
  "과부하계전기 (LS MT·슈나이더 LRD)": [
    const ModulePreset(
      "MT-12 과부하계전기 (LS)",
      45,
      73.2,
      shape: '${ElecShape.ol}:ls',
      depth: 63.7,
    ),
    const ModulePreset(
      "MT-32 과부하계전기 (LS)",
      45,
      74.55,
      shape: '${ElecShape.ol}:ls',
      depth: 86.3,
    ),
    const ModulePreset(
      "LRD08·16 과부하계전기 (슈나이더)",
      45,
      66,
      shape: '${ElecShape.ol}:sch',
      depth: 70,
    ),
  ],
  // LS GMP(전자식 전동기 보호 계전기, 차단기가 아님): GMP40·60T는 LS 문서 2건(UL 카탈로그 p.38·EMPR 카탈로그 p.56~58,
  // 동일 제조사), GMP60-3T는 EMPR p.58과 Radwell 목록. 삼화 EOCR-3DM2: 슈나이더 데이터시트와 EOCR-DM2 카탈로그.
  "전동기 보호 계전기 (LS GMP·삼화 EOCR)": [
    const ModulePreset(
      "GMP40 전자식 전동기 보호 계전기 (LS, 직결형)",
      53,
      78,
      shape: '${ElecShape.pr}:gmp',
      depth: 87.5,
    ),
    const ModulePreset(
      "GMP60T 전자식 전동기 보호 계전기 (LS)",
      72,
      67,
      shape: '${ElecShape.pr}:gmp',
      depth: 69,
    ),
    const ModulePreset(
      "GMP60-3T 전자식 전동기 보호 계전기 (LS)",
      95.3,
      94.6,
      shape: '${ElecShape.pr}:gmp',
      depth: 97,
    ),
    const ModulePreset(
      "EOCR-3DM2 전자식 과전류 계전기 (삼화)",
      70,
      74.5,
      shape: '${ElecShape.pr}:eocr',
      depth: 83.8,
    ),
  ],
  // 오므론 H3CR-A(11핀)·A8(8핀): 오므론 데이터시트 2본(같은 도면), 앞판 48×48 앞으로 15, 뒷 소켓 P3G-08을 쓰면 총 81.5.
  // 오토닉스 AT8N: 카탈로그 K-64와 설명서 도면(앞 15 + 몸통 50, 핀·소켓 별도).
  // 오므론 K8AK-PM: 데이터시트 2건(레일형 22.5 × 90 × 100).
  "타이머·감시 계전기 (옴론·오토닉스)": [
    const ModulePreset(
      "H3CR-A·A8 타이머 (옴론, 판 매입 48×48, 소켓 포함 깊이)",
      48,
      48,
      shape: '${ElecShape.timer}:omron',
      depth: 81.5,
    ),
    const ModulePreset(
      "AT8N 타이머 (오토닉스, 판 매입 48×48, 소켓 별도)",
      48,
      48,
      shape: '${ElecShape.timer}:autonics',
      depth: 64.5,
    ),
    const ModulePreset(
      "K8AK-PM 전압 감시 계전기 (옴론, 레일형)",
      22.5,
      90,
      shape: '${ElecShape.mon}:omron',
      depth: 100,
    ),
  ],
};
