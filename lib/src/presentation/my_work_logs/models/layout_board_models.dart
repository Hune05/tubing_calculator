import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'elec_presets.dart';
import 'fitting_spec.dart';
import 'instrument_shape_painter.dart';

// 🚀 배치도(모바일·태블릿 두 화면)가 함께 쓰는 데이터 모양과 치수 계산.
// 예전에는 두 화면 파일에 똑같은 코드가 각각 들어 있었다. 저장 형식이나 치수 계산 규칙을
// 바꿀 때는 이 파일 하나만 고치면 되고, test/layout_board_models_test.dart가 규칙을 지킨다.

// ---------------------------------------------------------
// 1. 데이터 모델
// ---------------------------------------------------------
enum DimensionType { center, edge }

// 🚀 [정리] 정밀 튜빙 라인 모드는 폰 화면에서 점을 하나하나 정밀하게
// 찍어야 해서 부담이 크다는 판단으로 제거. 모듈 배치/이동, 고정 치수
// 측정 두 가지만 남긴다.
enum BoardMode { placeModule, measureDimension }

// 🚀 [추가] 드래그로 도면에 놓을 모듈의 기본값(이름+가로/세로)을 함께
// 실어 나르기 위한 드래그 페이로드. 예전엔 이름(String)만 옮기고 크기는
// 무조건 80×80으로 고정되어 있어서, ABS 덕트처럼 폭이 정해진 자재를
// 매번 배치 후 수동으로 크기를 고쳐야 했다.
class ModulePreset {
  final String name;
  final double width;
  final double height;

  /// 계기 모양(InstrumentShape). 없으면 네모 모듈.
  final String? shape;

  /// 판 면에서 앞으로 튀어나오는 깊이(mm). 모르면 null.
  final double? depth;
  const ModulePreset(
    this.name,
    this.width,
    this.height, {
    this.shape,
    this.depth,
  });

  /// 깊이를 모를 때 모양에서 어림한다(덕트는 이름의 높이, 피팅은 가장 굵은 육각).
  double? get depthOrGuess =>
      depth ?? kPresetDepth[name] ?? guessPresetDepth(this);
}

// 🚀 배선 덕트 크기 = 폭×높이(mm). 도면(정면)에는 폭만큼 놓이고, 세로(길이)는 기본 200에서
// 놓은 뒤 "모듈 속성 편집"에서 실제 길이로 고친다. 크기 목록은 국내 판넬 덕트 영신프라텍 DG 표준형
// (yspt.co.kr, 길이 2m, 백색·회색) 24가지. 자주 쓰는 10가지를 먼저 보인다(국내 판넬 부품몰 재고 기준).
const List<ModulePreset> kDuctPresets = [
  ModulePreset("ABS덕트 25×40", 25, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 30×40", 30, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 40×40", 40, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 40×60", 40, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 60×60", 60, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 60×80", 60, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 80×80", 80, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 80×100", 80, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 100×80", 100, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 100×100", 100, 200, shape: InstrumentShape.duct),
];

/// 덕트 나머지 크기(DG 표준형에서 kDuctPresets를 뺀 것).
const List<ModulePreset> kDuctMorePresets = [
  ModulePreset("ABS덕트 20×35", 20, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 60×40", 60, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 25×60", 25, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 30×60", 30, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 50×60", 50, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 80×60", 80, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 100×60", 100, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 30×80", 30, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 40×80", 40, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 50×80", 50, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 40×100", 40, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 60×100", 60, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 100×150", 100, 200, shape: InstrumentShape.duct),
  ModulePreset("ABS덕트 150×100", 150, 200, shape: InstrumentShape.duct),
];

/// 덕트 고르기 창에 나오는 묶음(이름 → 크기 목록).
const Map<String, List<ModulePreset>> kDuctPresetGroups = {
  "자주 쓰는 크기 (폭×높이)": kDuctPresets,
  "그 밖의 크기": kDuctMorePresets,
};

/// 계기(트랜스미터·스위치) 모듈. 정면에서 본 몸통 크기(2인치 브래킷 빼고)다.
/// 제조사 도면의 외곽 치수를 mm로 옮겼다(2026-09 판). 제조사 이름 순서가 화면에 나오는 순서다.
/// "≈"는 도면에 숫자가 없어 비례로 잰 값(±5mm 안팎).
///
/// 출처
/// - 요꼬가와: GS 01C31B01-01EN p.14(EJA110E), GS 01C31E01-01EN p.12(EJA430E),
///   GS 01C31F01-01EN p.11(EJA530E, 접속 코드 7). 수평 배관의 가로 115는 ≈.
/// - 오토롤(듀온시스템): 카탈로그 C3100-E05C p.12(APT3100), C3200-E05C p.8(APT3200).
/// - 로즈마운트: PDS 00813-0100-4001 p.97·100·102(3051), 00813-0100-4101 p.88·96(2051),
///   00813-0100-4030 p.23(2120 나사형 표준 길이), 00813-0100-4130 p.23(2130).
///   3051 재래식 플랜지 세로 200은 ≈(2051은 197).
/// - 로즈마운트 상표 압력 스위치는 없다(에머슨 압력 스위치는 ASCO 상표).
/// - 비카(WIKA) MA: PV 31.11(04/2022) p.8 MA·MAG·MAH 앞 그림. 가로 161 = 87+74(케이블 입구
///   포함, 브래킷 빼고). 세로 121 = 뚜껑 위~입구 중심 71(p.9) + 다이어프램 접속구 끝까지 50(p.8).
///   피스톤 감지는 +18(68), 용접 다이어프램 피스톤은 +38(88).
/// - SOR: CAT216(Form 216, 07.26) p.21 NN·p.22 RN·p.28 B3, CAT468 p.14(101 차압 NN).
///   세로는 상자 위~1/4" NPT 접속구 끝(1/2" NPT 피스톤형은 +13). 가로는 오른쪽 배관 허브 포함.
///   스위치 한 벌(SPDT)·두 벌(DPDT) 외곽은 같다. 청색은 카탈로그에 없고 현장 모습 기준.
/// - UE(United Electric): 100-B p13·120-B p21·22 표와 모델별 도면(A-12709 H100-701~706,
///   A-12848 H100-183~186, A-13417 H100K-544~548, A-12107 J120-126~164, A-12452 J120-701~705,
///   A-12456 J120K-147·157, A-13418 J120K-540~543, A-12464 H121-701~705). 가로·세로는 도면 숫자
///   (뚜껑 포함, 몸통 위~접속구 끝). H100-190~194(다이어프램)는 H100-701~706과, J120-190~194는
///   J120-701~705와 외곽이 같다. 차압은 접속구가 양 끝 옆(왼쪽 HIGH·오른쪽 LOW).
const Map<String, List<ModulePreset>> kInstrumentPresets = {
  "요꼬가와": [
    ModulePreset(
      "EJA110E DPT 수직배관",
      175,
      138,
      shape: InstrumentShape.ykVertical,
    ),
    ModulePreset(
      "EJA110E DPT 수평배관",
      115,
      175,
      shape: InstrumentShape.ykHorizontal,
    ),
    ModulePreset(
      "EJA430E PT 수직배관",
      175,
      138,
      shape: InstrumentShape.ykVertical,
    ),
    ModulePreset(
      "EJA430E PT 수평배관",
      115,
      175,
      shape: InstrumentShape.ykHorizontal,
    ),
    ModulePreset("EJA530E PT 인라인", 95, 159, shape: InstrumentShape.ykInline),
    // 2인치 파이프 브래킷 포함: 몸통 크기 + 가로 ≈60·세로 ≈40(어림, 도면 값 아님).
    ModulePreset(
      "EJA110E DPT 수직배관 (브래킷)",
      235,
      178,
      shape: '${InstrumentShape.ykVertical}${InstrumentShape.bracketSuffix}',
    ),
    ModulePreset(
      "EJA110E DPT 수평배관 (브래킷)",
      175,
      215,
      shape: '${InstrumentShape.ykHorizontal}${InstrumentShape.bracketSuffix}',
    ),
    ModulePreset(
      "EJA430E PT 수직배관 (브래킷)",
      235,
      178,
      shape: '${InstrumentShape.ykVertical}${InstrumentShape.bracketSuffix}',
    ),
    ModulePreset(
      "EJA430E PT 수평배관 (브래킷)",
      175,
      215,
      shape: '${InstrumentShape.ykHorizontal}${InstrumentShape.bracketSuffix}',
    ),
    ModulePreset(
      "EJA530E PT 인라인 (브래킷)",
      155,
      199,
      shape: '${InstrumentShape.ykInline}${InstrumentShape.bracketSuffix}',
    ),
  ],
  "오토롤": [
    ModulePreset("APT3100 DPT", 86, 194, shape: InstrumentShape.autrolDp),
    ModulePreset("APT3200 PT", 86, 160, shape: InstrumentShape.autrolPt),
    ModulePreset(
      "APT3100 DPT (브래킷)",
      146,
      234,
      shape: '${InstrumentShape.autrolDp}${InstrumentShape.bracketSuffix}',
    ),
    ModulePreset(
      "APT3200 PT (브래킷)",
      146,
      200,
      shape: '${InstrumentShape.autrolPt}${InstrumentShape.bracketSuffix}',
    ),
  ],
  "로즈마운트": [
    ModulePreset("3051CD DPT", 104, 181, shape: InstrumentShape.rmCoplanar),
    ModulePreset(
      "3051CD DPT 재래식 플랜지",
      115,
      200,
      shape: InstrumentShape.rmTraditional,
    ),
    ModulePreset("3051CG PT", 104, 181, shape: InstrumentShape.rmCoplanar),
    ModulePreset("3051TG PT 인라인", 104, 183, shape: InstrumentShape.rmInline),
    ModulePreset("2051CD DPT", 98, 179, shape: InstrumentShape.rmCoplanar),
    ModulePreset("2051TG PT 인라인", 98, 183, shape: InstrumentShape.rmInline),
    ModulePreset(
      "3051CD DPT (브래킷)",
      164,
      221,
      shape: '${InstrumentShape.rmCoplanar}${InstrumentShape.bracketSuffix}',
    ),
    ModulePreset(
      "3051CD DPT 재래식 플랜지 (브래킷)",
      175,
      240,
      shape: '${InstrumentShape.rmTraditional}${InstrumentShape.bracketSuffix}',
    ),
    ModulePreset(
      "3051CG PT (브래킷)",
      164,
      221,
      shape: '${InstrumentShape.rmCoplanar}${InstrumentShape.bracketSuffix}',
    ),
    ModulePreset(
      "3051TG PT 인라인 (브래킷)",
      164,
      223,
      shape: '${InstrumentShape.rmInline}${InstrumentShape.bracketSuffix}',
    ),
    ModulePreset(
      "2051CD DPT (브래킷)",
      158,
      219,
      shape: '${InstrumentShape.rmCoplanar}${InstrumentShape.bracketSuffix}',
    ),
    ModulePreset(
      "2051TG PT 인라인 (브래킷)",
      158,
      223,
      shape: '${InstrumentShape.rmInline}${InstrumentShape.bracketSuffix}',
    ),
    ModulePreset("2120 레벨 스위치", 120, 220, shape: InstrumentShape.fork2120),
    ModulePreset(
      "2120 레벨 스위치 나일론",
      141,
      196,
      shape: InstrumentShape.fork2120Nylon,
    ),
    ModulePreset("2130 레벨 스위치", 120, 251, shape: InstrumentShape.fork2130),
    ModulePreset(
      "2130 레벨 스위치 고온",
      120,
      418,
      shape: InstrumentShape.fork2130Long,
    ),
  ],
  "SOR": [
    ModulePreset("6NN 압력 스위치", 108, 147, shape: InstrumentShape.sorPiston),
    ModulePreset("12NN 압력 스위치 저압", 108, 150, shape: InstrumentShape.sorWide),
    ModulePreset("54NN 압력 스위치", 108, 151, shape: InstrumentShape.sorDiaphragm),
    ModulePreset("6RN 압력 스위치", 107, 172, shape: InstrumentShape.sorPiston),
    ModulePreset("54RN 압력 스위치", 107, 176, shape: InstrumentShape.sorDiaphragm),
    ModulePreset("6B3 방폭 압력 스위치", 150, 225, shape: InstrumentShape.sorExp),
    ModulePreset("101NN 차압 스위치", 108, 154, shape: InstrumentShape.sorDp),
  ],
  "비카": [ModulePreset("MA 압력 스위치", 161, 121, shape: InstrumentShape.exdSwitch)],
  "UE": [
    ModulePreset("H100 압력 스위치", 101.6, 168.3, shape: InstrumentShape.ueH100),
    ModulePreset(
      "H100 압력 스위치 저압",
      101.6,
      192.1,
      shape: InstrumentShape.ueH100Flange,
    ),
    ModulePreset("H100K 차압 스위치", 101.6, 216.6, shape: InstrumentShape.ueH100k),
    ModulePreset("J120 방폭 압력 스위치", 134.6, 184.2, shape: InstrumentShape.ueJ120),
    ModulePreset(
      "J120 방폭 압력 스위치 피스톤",
      134.6,
      188.6,
      shape: InstrumentShape.ueJ120Piston,
    ),
    ModulePreset("J120K 방폭 차압 스위치", 219, 192.5, shape: InstrumentShape.ueJ120k),
    ModulePreset(
      "J120K 방폭 저차압 스위치",
      152.4,
      237.1,
      shape: InstrumentShape.ueJ120kDia,
    ),
    ModulePreset("H121 방폭 압력 스위치", 129.9, 211.1, shape: InstrumentShape.ueH121),
  ],
};

/// 튜브 피팅(이중 페럴 압착). 하이록 H-200TF(2020)·스웨즈락 MS-01-140(Rev AJ) 표 값으로,
/// 1/4"·3/8"·1/2"는 두 회사 길이·너트 육각이 같다(너트 손으로 조인 상태).
/// 옆에서 본 가로×세로(mm): 곧은 것은 전체 길이 × 너트 육각, 엘보·티·크로스는
/// 가운데~끝 길이(A)에 몸통 육각 반을 더했다. 메일 엘보는 하이록 L·L1.
final Map<String, List<ModulePreset>> kFittingPresets = {
  "유니언": [
    ModulePreset('유니언 1/4"', 41, 14, shape: InstrumentShape.fitUnion),
    ModulePreset('유니언 3/8"', 45, 17, shape: InstrumentShape.fitUnion),
    ModulePreset('유니언 1/2"', 51, 22, shape: InstrumentShape.fitUnion),
  ],
  "유니언 엘보": [
    ModulePreset('유니언 엘보 1/4"', 33, 33, shape: InstrumentShape.fitElbow),
    ModulePreset('유니언 엘보 3/8"', 38, 38, shape: InstrumentShape.fitElbow),
    ModulePreset('유니언 엘보 1/2"', 46, 46, shape: InstrumentShape.fitElbow),
  ],
  "유니언 티": [
    ModulePreset('유니언 티 1/4"', 54, 33, shape: InstrumentShape.fitTee),
    ModulePreset('유니언 티 3/8"', 61, 38, shape: InstrumentShape.fitTee),
    ModulePreset('유니언 티 1/2"', 72, 46, shape: InstrumentShape.fitTee),
  ],
  "유니언 크로스": [
    ModulePreset('유니언 크로스 1/4"', 54, 54, shape: InstrumentShape.fitCross),
    ModulePreset('유니언 크로스 3/8"', 61, 61, shape: InstrumentShape.fitCross),
    ModulePreset('유니언 크로스 1/2"', 72, 72, shape: InstrumentShape.fitCross),
  ],
  "메일 커넥터": [
    ModulePreset(
      '메일 커넥터 1/4"×1/4" NPT',
      38,
      14,
      shape: InstrumentShape.fitMale,
    ),
    ModulePreset(
      '메일 커넥터 3/8"×3/8" NPT',
      40,
      17,
      shape: InstrumentShape.fitMale,
    ),
    ModulePreset(
      '메일 커넥터 1/2"×1/2" NPT',
      49,
      22,
      shape: InstrumentShape.fitMale,
    ),
  ],
  "메일 엘보": [
    ModulePreset(
      '메일 엘보 1/4"×1/4" NPT',
      34,
      30,
      shape: InstrumentShape.fitMaleElbow,
    ),
    ModulePreset(
      '메일 엘보 3/8"×3/8" NPT',
      42,
      35,
      shape: InstrumentShape.fitMaleElbow,
    ),
    ModulePreset(
      '메일 엘보 1/2"×1/2" NPT',
      46,
      43,
      shape: InstrumentShape.fitMaleElbow,
    ),
  ],
  "벌크헤드 유니언": [
    ModulePreset('벌크헤드 유니언 1/4"', 58, 16, shape: InstrumentShape.fitBulkhead),
    ModulePreset('벌크헤드 유니언 3/8"', 62, 19, shape: InstrumentShape.fitBulkhead),
    ModulePreset('벌크헤드 유니언 1/2"', 71, 24, shape: InstrumentShape.fitBulkhead),
  ],
  // ── 하이록 H-200TF(2020) 표 값을 조각 목록으로(fitting_spec.dart) ──
  // p.13 리듀싱 유니언, p.25 벌크헤드 메일, p.26 45° 메일 엘보, p.27·28 메일 런·브랜치 티,
  // p.29 피메일 커넥터, p.32 벌크헤드 피메일, p.33 피메일 엘보, p.34·35 피메일 런·브랜치 티,
  // p.36 리듀서, p.38 벌크헤드 리듀서, p.42·45 메일·피메일 어댑터, p.46 포트 커넥터, p.65 캡.
  // 어림: 어댑터 몸통 육각 길이 7, 벌크헤드 잠금 너트 6, 피메일 몸통 육각(1/4 NPT 11/16",
  // 3/8 NPT 13/16", 1/2 NPT 1"). 나머지 길이·육각은 카탈로그 인쇄 값.
  "리듀싱 유니언": [
    fittingPreset(
      '리듀싱 유니언 3/8"×1/4"',
      'fs:n:14.2:17.5,h:16.3:15.9,n:12.7:14.3',
    ),
    fittingPreset(
      '리듀싱 유니언 1/2"×1/4"',
      'fs:n:17.5:22.2,h:16.8:20.6,n:12.7:14.3',
    ),
    fittingPreset(
      '리듀싱 유니언 1/2"×3/8"',
      'fs:n:17.5:22.2,h:16.8:20.6,n:14.2:17.5',
    ),
  ],
  "피메일 커넥터": [
    fittingPreset('피메일 커넥터 3/8"×1/4" NPT', 'fs:n:14.2:17.5,h:23.4:19.1'),
    fittingPreset('피메일 커넥터 3/8"×3/8" NPT', 'fs:n:14.2:17.5,h:24.9:22.2'),
    fittingPreset('피메일 커넥터 3/8"×1/2" NPT', 'fs:n:14.2:17.5,h:29.7:27'),
    fittingPreset('피메일 커넥터 1/2"×1/4" NPT', 'fs:n:17.5:22.2,h:22.9:19.1'),
    fittingPreset('피메일 커넥터 1/2"×3/8" NPT', 'fs:n:17.5:22.2,h:24.4:22.2'),
    fittingPreset('피메일 커넥터 1/2"×1/2" NPT', 'fs:n:17.5:22.2,h:29.2:27'),
  ],
  "캡": [
    fittingPreset('캡 3/8"', 'fs:n:14.2:17.5,h:11.5:15.9'),
    fittingPreset('캡 1/2"', 'fs:n:17.5:22.2,h:11.7:20.6'),
  ],
  "리듀서": [
    fittingPreset('리듀서 3/8"×1/4" 관', 'fs:n:14.2:17.5,h:12:15.9,s:15.2:6.4'),
    fittingPreset('리듀서 3/8"×3/8" 관', 'fs:n:14.2:17.5,h:12.2:15.9,s:16.8:9.5'),
    fittingPreset('리듀서 3/8"×1/2" 관', 'fs:n:14.2:17.5,h:11.4:15.9,s:22.9:12.7'),
    fittingPreset('리듀서 1/2"×1/4" 관', 'fs:n:17.5:22.2,h:12.3:20.6,s:15.2:6.4'),
    fittingPreset('리듀서 1/2"×3/8" 관', 'fs:n:17.5:22.2,h:12.4:20.6,s:16.8:9.5'),
    fittingPreset('리듀서 1/2"×1/2" 관', 'fs:n:17.5:22.2,h:11.9:20.6,s:22.9:12.7'),
  ],
  "메일 어댑터": [
    fittingPreset(
      '메일 어댑터 3/8" 관×1/4" NPT',
      'fs:s:16.8:9.5,h:7:14.3,t:15.1:13.7',
    ),
    fittingPreset(
      '메일 어댑터 3/8" 관×3/8" NPT',
      'fs:s:16.8:9.5,h:7:17.5,t:15.8:17.1',
    ),
    fittingPreset(
      '메일 어댑터 3/8" 관×1/2" NPT',
      'fs:s:16.8:9.5,h:7:22.2,t:21.4:21.3',
    ),
    fittingPreset(
      '메일 어댑터 1/2" 관×1/4" NPT',
      'fs:s:22.9:12.7,h:7:14.3,t:14.6:13.7',
    ),
    fittingPreset(
      '메일 어댑터 1/2" 관×3/8" NPT',
      'fs:s:22.9:12.7,h:7:17.5,t:15.1:17.1',
    ),
    fittingPreset(
      '메일 어댑터 1/2" 관×1/2" NPT',
      'fs:s:22.9:12.7,h:7:22.2,t:20.9:21.3',
    ),
  ],
  "피메일 어댑터": [
    fittingPreset('피메일 어댑터 3/8" 관×1/4" NPT', 'fs:s:16.8:9.5,h:21.3:19.1'),
    fittingPreset('피메일 어댑터 3/8" 관×3/8" NPT', 'fs:s:16.8:9.5,h:23.6:22.2'),
    fittingPreset('피메일 어댑터 3/8" 관×1/2" NPT', 'fs:s:16.8:9.5,h:29.9:27'),
    fittingPreset('피메일 어댑터 1/2" 관×1/4" NPT', 'fs:s:22.9:12.7,h:20.5:19.1'),
    fittingPreset('피메일 어댑터 1/2" 관×3/8" NPT', 'fs:s:22.9:12.7,h:22.6:22.2'),
    fittingPreset('피메일 어댑터 1/2" 관×1/2" NPT', 'fs:s:22.9:12.7,h:28.9:27'),
  ],
  "포트 커넥터": [
    fittingPreset('포트 커넥터 3/8"', 'fs:p:26.7:9.5'),
    fittingPreset('포트 커넥터 1/2"', 'fs:p:36.3:12.7'),
  ],
  "벌크헤드 메일 커넥터": [
    fittingPreset(
      '벌크헤드 메일 커넥터 3/8"×1/4" NPT',
      'fs:n:14.2:17.5,h:7:19.1,t:4.8:15.2,l:6:19.1,t:4.8:15.2,t:20.6:13.7',
    ),
    fittingPreset(
      '벌크헤드 메일 커넥터 3/8"×3/8" NPT',
      'fs:n:14.2:17.5,h:7:19.1,t:4.8:15.2,l:6:19.1,t:4.8:15.2,t:20.6:17.1',
    ),
    fittingPreset(
      '벌크헤드 메일 커넥터 3/8"×1/2" NPT',
      'fs:n:14.2:17.5,h:7:22.2,t:4.8:17.8,l:6:22.2,t:4.8:17.8,t:27:21.3',
    ),
    fittingPreset(
      '벌크헤드 메일 커넥터 1/2"×3/8" NPT',
      'fs:n:17.5:22.2,h:7:23.8,t:5.7:19,l:6:23.8,t:5.7:19,t:21.3:17.1',
    ),
    fittingPreset(
      '벌크헤드 메일 커넥터 1/2"×1/2" NPT',
      'fs:n:17.5:22.2,h:7:23.8,t:5.7:19,l:6:23.8,t:5.7:19,t:26.9:21.3',
    ),
  ],
  "벌크헤드 피메일 커넥터": [
    fittingPreset(
      '벌크헤드 피메일 커넥터 3/8"×1/4" NPT',
      'fs:n:14.2:17.5,h:7:19.1,t:4.8:15.2,l:6:19.1,t:4.8:15.2,h:18.3:19.1',
    ),
    fittingPreset(
      '벌크헤드 피메일 커넥터 1/2"×3/8" NPT',
      'fs:n:17.5:22.2,h:7:23.8,t:5.7:19,l:6:23.8,t:5.7:19,h:19.8:22.2',
    ),
    fittingPreset(
      '벌크헤드 피메일 커넥터 1/2"×1/2" NPT',
      'fs:n:17.5:22.2,h:7:23.8,t:5.7:19,l:6:23.8,t:5.7:19,h:24.6:27',
    ),
  ],
  "벌크헤드 리듀서": [
    fittingPreset(
      '벌크헤드 리듀서 3/8"',
      'fs:n:14.2:17.5,h:7:19.1,t:4.8:15.2,l:6:19.1,t:4.8:15.2,s:24.4:9.5',
    ),
    fittingPreset(
      '벌크헤드 리듀서 1/2"',
      'fs:n:17.5:22.2,h:7:23.8,t:5.7:19,l:6:23.8,t:5.7:19,s:31:12.7',
    ),
  ],
  "45° 메일 엘보": [
    fittingPreset(
      '45° 메일 엘보 3/8"×1/4" NPT',
      'fl:b=15.88;r=n,27.9,17.5;x=t,22.9,13.7',
    ),
    fittingPreset(
      '45° 메일 엘보 3/8"×3/8" NPT',
      'fl:b=20.64;r=n,29.2,17.5;x=t,24.1,17.1',
    ),
    fittingPreset(
      '45° 메일 엘보 1/2"×3/8" NPT',
      'fl:b=20.64;r=n,32,22.2;x=t,24.1,17.1',
    ),
    fittingPreset(
      '45° 메일 엘보 1/2"×1/2" NPT',
      'fl:b=20.64;r=n,32,22.2;x=t,29,21.3',
    ),
  ],
  "메일 런 티": [
    fittingPreset(
      '메일 런 티 3/8"×1/4" NPT',
      'fl:b=15.88;l=n,30.5,17.5;d=n,30.5,17.5;r=t,25.4,13.7',
    ),
    fittingPreset(
      '메일 런 티 3/8"×3/8" NPT',
      'fl:b=17.46;l=n,31.2,17.5;d=n,31.2,17.5;r=t,26.2,17.1',
    ),
    fittingPreset(
      '메일 런 티 1/2"×3/8" NPT',
      'fl:b=20.64;l=n,36.1,22.2;d=n,36.1,22.2;r=t,28.2,17.1',
    ),
    fittingPreset(
      '메일 런 티 1/2"×1/2" NPT',
      'fl:b=20.64;l=n,36.1,22.2;d=n,36.1,22.2;r=t,33,21.3',
    ),
  ],
  "메일 브랜치 티": [
    fittingPreset(
      '메일 브랜치 티 3/8"×1/4" NPT',
      'fl:b=15.88;l=n,30.5,17.5;r=n,30.5,17.5;d=t,25.4,13.7',
    ),
    fittingPreset(
      '메일 브랜치 티 3/8"×3/8" NPT',
      'fl:b=17.46;l=n,31.2,17.5;r=n,31.2,17.5;d=t,26.2,17.1',
    ),
    fittingPreset(
      '메일 브랜치 티 1/2"×3/8" NPT',
      'fl:b=20.64;l=n,36.1,22.2;r=n,36.1,22.2;d=t,28.2,17.1',
    ),
    fittingPreset(
      '메일 브랜치 티 1/2"×1/2" NPT',
      'fl:b=20.64;l=n,36.1,22.2;r=n,36.1,22.2;d=t,33,21.3',
    ),
  ],
  "피메일 엘보": [
    fittingPreset(
      '피메일 엘보 3/8"×1/4" NPT',
      'fl:b=17.5;r=n,31.2,17.5;d=f,22.4,17.5',
    ),
    fittingPreset(
      '피메일 엘보 3/8"×3/8" NPT',
      'fl:b=20.6;r=n,33.3,17.5;d=f,22.4,20.6',
    ),
    fittingPreset(
      '피메일 엘보 3/8"×1/2" NPT',
      'fl:b=25.4;r=n,36.1,17.5;d=f,28.4,25.4',
    ),
    fittingPreset(
      '피메일 엘보 1/2"×1/4" NPT',
      'fl:b=17.5;r=n,36.1,22.2;d=f,22.4,17.5',
    ),
    fittingPreset(
      '피메일 엘보 1/2"×3/8" NPT',
      'fl:b=20.6;r=n,36.1,22.2;d=f,22.4,20.6',
    ),
    fittingPreset(
      '피메일 엘보 1/2"×1/2" NPT',
      'fl:b=25.4;r=n,38.9,22.2;d=f,28.4,25.4',
    ),
  ],
  "피메일 런 티": [
    fittingPreset(
      '피메일 런 티 3/8"×1/4" NPT',
      'fl:b=17.5;l=n,31.2,17.5;d=n,31.2,17.5;r=f,22.4,17.5',
    ),
    fittingPreset(
      '피메일 런 티 1/2"×3/8" NPT',
      'fl:b=20.6;l=n,36.1,22.2;d=n,36.1,22.2;r=f,22.4,20.6',
    ),
    fittingPreset(
      '피메일 런 티 1/2"×1/2" NPT',
      'fl:b=25.4;l=n,38.9,22.2;d=n,38.9,22.2;r=f,28.4,25.4',
    ),
  ],
  "피메일 브랜치 티": [
    fittingPreset(
      '피메일 브랜치 티 3/8"×1/4" NPT',
      'fl:b=17.5;l=n,31.2,17.5;r=n,31.2,17.5;d=f,22.4,17.5',
    ),
    fittingPreset(
      '피메일 브랜치 티 1/2"×1/4" NPT',
      'fl:b=17.5;l=n,36.1,22.2;r=n,36.1,22.2;d=f,22.4,17.5',
    ),
    fittingPreset(
      '피메일 브랜치 티 1/2"×3/8" NPT',
      'fl:b=20.6;l=n,36.1,22.2;r=n,36.1,22.2;d=f,22.4,20.6',
    ),
    fittingPreset(
      '피메일 브랜치 티 1/2"×1/2" NPT',
      'fl:b=25.4;l=n,38.9,22.2;r=n,38.9,22.2;d=f,28.4,25.4',
    ),
  ],
};

/// 조각 목록(fitting_spec.dart)으로 적은 피팅. 가로×세로는 조각 길이에서 셈한다.
ModulePreset fittingPreset(String name, String spec) {
  final Size size = fittingSpecSize(spec) ?? const Size(40, 20);
  double r(double v) => (v * 10).roundToDouble() / 10;
  return ModulePreset(name, r(size.width), r(size.height), shape: spec);
}

/// 피팅 고르기 창의 관 규격 단추.
const List<String> kFittingSizes = ['1/4"', '3/8"', '1/2"'];

/// 피팅 이름에서 관 규격(이름에 처음 나오는 1/4"·3/8"·1/2")을 꺼낸다. 없으면 null.
String? fittingTubeSize(String name) =>
    RegExp(r'\d/\d"').firstMatch(name)?.group(0);

/// 매니폴드·게이지 밸브. 스탠드에 단 모습을 앞(손잡이 쪽)에서 본 가로×세로 = 카탈로그 "Top"
/// 그림. 가로는 양옆 격리 손잡이를 다 연 길이("Open"), 세로는 블록(직결형은 플랜지판 포함).
/// 하이록 H-120MV(2023.3) p.11·13·18·23·28, 스웨즈락 MS-02-445(Rev G) p.6·10·12.
/// 앞으로 튀어나오는 깊이(손잡이 열림)는 하이록 85, 스웨즈락 V3 104 안팎.
final Map<String, List<ModulePreset>> kValvePresets = {
  "하이록 매니폴드·게이지 밸브": [
    ModulePreset("VM2V 2밸브 매니폴드", 104, 64, shape: InstrumentShape.mv2),
    ModulePreset("VM3V 3밸브 매니폴드", 192, 78, shape: InstrumentShape.mv3),
    ModulePreset("VM3V1F 3밸브 직결", 192, 97, shape: InstrumentShape.mv3Flange),
    ModulePreset("VM5V 5밸브 매니폴드", 192, 86, shape: InstrumentShape.mv5),
    ModulePreset("VM5V1F 5밸브 직결", 192, 113, shape: InstrumentShape.mv5Flange),
    ModulePreset("VGV 게이지 밸브 1/2\"", 67, 32, shape: InstrumentShape.gv1),
    ModulePreset("VGV2 게이지 2밸브 1/2\"", 78, 32, shape: InstrumentShape.gv2),
  ],
  // ── 하이록 밸브 카탈로그(앞 그림, 손잡이가 위, 다 연 상태) ──
  // H-110BV p.3, H-112BV p.2, H-100NV p.4·5, H-102NV p.2, H-P100 p.1, H-TG100 p.3,
  // H-700T p.2, H-RV100 p.2. 관 가운데~몸통 밑(bot)은 몸통 육각·네모 반으로 어림.
  "하이록 볼 밸브": [
    fittingPreset(
      "110 볼 밸브 3/8\" 튜브",
      'fv:ball;L=90;top=40;bot=10.3;end=n;reach=80;pipe=17.5',
    ),
    fittingPreset(
      "110 볼 밸브 3/8\" 암나사",
      'fv:ball;L=45;top=40;bot=10.3;end=f;reach=80;pipe=20.6',
    ),
    fittingPreset(
      "110 볼 밸브 1/2\" 튜브",
      'fv:ball;L=99;top=42;bot=13.5;end=n;reach=80;pipe=22.2',
    ),
    fittingPreset(
      "110 볼 밸브 1/2\" 암나사",
      'fv:ball;L=54.5;top=42;bot=13.5;end=f;reach=80;pipe=27',
    ),
    fittingPreset(
      "112 패널 볼 밸브 3/8\" 튜브",
      'fv:wing;L=77.8;top=52.8;bot=14;end=n;reach=51;pipe=17.5',
    ),
    fittingPreset(
      "112 패널 볼 밸브 3/8\" 암나사",
      'fv:wing;L=63.6;top=52.8;bot=14;end=f;reach=51;pipe=22',
    ),
    fittingPreset(
      "112 패널 볼 밸브 1/2\" 튜브",
      'fv:wing;L=100;top=67;bot=22;end=n;reach=77;pipe=22.2',
    ),
    fittingPreset(
      "112 패널 볼 밸브 1/2\" 암나사",
      'fv:wing;L=79.2;top=67;bot=22;end=f;reach=77;pipe=27',
    ),
  ],
  "하이록 니들 밸브": [
    fittingPreset(
      "NV 니들 밸브 3/8\" 튜브",
      'fv:needle;L=66.4;top=63.6;bot=14;end=n;bar=64;pipe=17.5',
    ),
    fittingPreset(
      "NV 니들 밸브 3/8\" 암나사",
      'fv:needle;L=56;top=63.6;bot=14;end=f;bar=64;pipe=22',
    ),
    fittingPreset(
      "NV 니들 밸브 1/2\" 튜브",
      'fv:needle;L=97;top=91.7;bot=16;end=n;bar=76;pipe=22.2',
    ),
    fittingPreset(
      "NV 니들 밸브 1/2\" 암나사",
      'fv:needle;L=76;top=91.7;bot=16;end=f;bar=76;pipe=27',
    ),
    fittingPreset(
      "GB 유니언 보닛 니들 3/8\" 튜브",
      'fv:gb;L=73;top=93.7;bot=14;end=n;bar=64;pipe=17.5',
    ),
    fittingPreset(
      "GB 유니언 보닛 니들 3/8\" 암나사",
      'fv:gb;L=57.2;top=93.7;bot=14;end=f;bar=64;pipe=22',
    ),
    fittingPreset(
      "GB 유니언 보닛 니들 1/2\" 튜브",
      'fv:gb;L=100;top=121.5;bot=16;end=n;bar=76;pipe=22.2',
    ),
    fittingPreset(
      "GB 유니언 보닛 니들 1/2\" 암나사",
      'fv:gb;L=79.4;top=121.5;bot=16;end=f;bar=76;pipe=27',
    ),
  ],
  "하이록 플러그·토글 밸브": [
    fittingPreset(
      "P 플러그 밸브 3/8\" 튜브",
      'fv:wing;L=68.4;top=40;bot=17.5;end=n;reach=40;pipe=17.5',
    ),
    fittingPreset(
      "P 플러그 밸브 1/2\" 튜브",
      'fv:wing;L=74;top=40;bot=17.5;end=n;reach=40;pipe=22.2',
    ),
    fittingPreset(
      "P 플러그 밸브 1/2\" 암나사",
      'fv:wing;L=73.2;top=40;bot=17.5;end=f;reach=40;pipe=27',
    ),
    fittingPreset(
      "TG 토글 밸브 3/8\" 튜브",
      'fv:toggle;L=65.5;top=90.4;bot=12;end=n;pipe=17.5',
    ),
    fittingPreset(
      "TG 토글 밸브 1/2\" 튜브",
      'fv:toggle;L=71.1;top=90.4;bot=12;end=n;pipe=22.2',
    ),
  ],
  "하이록 체크·릴리프 밸브": [
    // 체크 밸브 몸통은 c 조각(육각 + 흐름 화살표).
    fittingPreset("체크 밸브 3/8\" 튜브", 'fs:n:14.2:17.5,c:46.6:22.2,n:14.2:17.5'),
    fittingPreset("체크 밸브 3/8\" 암나사", 'fs:c:68:22.2'),
    fittingPreset("체크 밸브 1/2\" 튜브", 'fs:n:17.5:22.2,c:45.5:22.2,n:17.5:22.2'),
    fittingPreset("체크 밸브 1/2\" 암나사", 'fs:c:85:28.6'),
    fittingPreset(
      "RV 릴리프 밸브 1/2\" 튜브",
      'fv:relief;L=46.7;top=114;bot=14;out=46.7;pipe=22.2',
    ),
    fittingPreset(
      "RV 릴리프 밸브 1/2\" 암나사",
      'fv:relief;L=38;top=103;bot=14;out=35.7;pipe=27',
    ),
  ],
  "스웨즈락 매니폴드": [
    ModulePreset("V2 2밸브 매니폴드", 97, 64, shape: InstrumentShape.swV2),
    ModulePreset("V3 3밸브 매니폴드", 229, 48, shape: InstrumentShape.swV3),
    ModulePreset("V5 5밸브 매니폴드", 226, 56, shape: InstrumentShape.swV5),
  ],
};

/// 제조사 도면의 깊이(mm, 판 면~앞 끝). 계기는 몸통(브래킷 빼고), 매니폴드는 손잡이 다 연 상태.
/// 출처는 kInstrumentPresets·kValvePresets 주석과 같다(EJA GS p.14 D110, APT C3100 p.12 D112,
/// 3051 PDS p.97 D109, 2051 p.88 D111, SOR CAT216 D, MA PV 31.11 Ø136, 하이록 H-120MV 열림).
const Map<String, double> kPresetDepth = {
  'EJA110E DPT 수직배관': 110,
  'EJA110E DPT 수평배관': 110,
  'EJA430E PT 수직배관': 110,
  'EJA430E PT 수평배관': 110,
  'EJA530E PT 인라인': 110,
  'APT3100 DPT': 112,
  'APT3200 PT': 112,
  '3051CD DPT': 109,
  '3051CD DPT 재래식 플랜지': 109,
  '3051CG PT': 109,
  '3051TG PT 인라인': 109,
  '2051CD DPT': 111,
  '2051TG PT 인라인': 111,
  // 브래킷 포함(파이프는 뒤쪽이라 앞으로 나오는 깊이는 몸통과 같다).
  'EJA110E DPT 수직배관 (브래킷)': 110,
  'EJA110E DPT 수평배관 (브래킷)': 110,
  'EJA430E PT 수직배관 (브래킷)': 110,
  'EJA430E PT 수평배관 (브래킷)': 110,
  'EJA530E PT 인라인 (브래킷)': 110,
  'APT3100 DPT (브래킷)': 112,
  'APT3200 PT (브래킷)': 112,
  '3051CD DPT (브래킷)': 109,
  '3051CD DPT 재래식 플랜지 (브래킷)': 109,
  '3051CG PT (브래킷)': 109,
  '3051TG PT 인라인 (브래킷)': 109,
  '2051CD DPT (브래킷)': 111,
  '2051TG PT 인라인 (브래킷)': 111,
  '2120 레벨 스위치': 100,
  '2120 레벨 스위치 나일론': 102,
  '2130 레벨 스위치': 100,
  '2130 레벨 스위치 고온': 100,
  '6NN 압력 스위치': 57,
  '12NN 압력 스위치 저압': 95,
  '54NN 압력 스위치': 57,
  '6RN 압력 스위치': 66,
  '54RN 압력 스위치': 66,
  '6B3 방폭 압력 스위치': 110,
  '101NN 차압 스위치': 60,
  'MA 압력 스위치': 136,
  // UE: 100 계열 59.4(H100K는 다이어프램 93.7), 120 계열 109, H121 132(도면 숫자).
  'H100 압력 스위치': 59.4,
  'H100 압력 스위치 저압': 59.4,
  'H100K 차압 스위치': 93.7,
  'J120 방폭 압력 스위치': 109,
  'J120 방폭 압력 스위치 피스톤': 109,
  'J120K 방폭 차압 스위치': 109,
  'J120K 방폭 저차압 스위치': 109,
  'H121 방폭 압력 스위치': 132,
  'VM2V 2밸브 매니폴드': 85,
  'VM3V 3밸브 매니폴드': 85,
  'VM3V1F 3밸브 직결': 96,
  'VM5V 5밸브 매니폴드': 85,
  'VM5V1F 5밸브 직결': 101,
  'VGV 게이지 밸브 1/2"': 69,
  'VGV2 게이지 2밸브 1/2"': 85,
  'V2 2밸브 매니폴드': 78,
  'V3 3밸브 매니폴드': 104,
  'V5 5밸브 매니폴드': 78,
};

/// 목록에 있는 이름이면 그 깊이(예전에 깊이 없이 놓은 계기도 읽을 때 채운다).
double? _presetDepthByName(String? name) {
  if (name == null) return null;
  final d = kPresetDepth[name];
  if (d != null) return d;
  for (final list in [
    ...kFittingPresets.values,
    ...kValvePresets.values,
    ...kElecPresets.values,
    kDuctPresets,
    kDuctMorePresets,
  ]) {
    for (final p in list) {
      if (p.name == name) return p.depthOrGuess;
    }
  }
  return null;
}

/// 모양에서 깊이를 어림한다. 덕트 = 이름의 높이(폭×높이), 곧은 피팅 = 가장 굵은 육각,
/// 엘보·티 = 가장 굵은 팔, 인라인 밸브 = 몸통 굵기. 모르면 null.
double? guessPresetDepth(ModulePreset p) {
  final dm = RegExp(r'ABS덕트 \d+×(\d+)').firstMatch(p.name);
  if (dm != null) return double.parse(dm.group(1)!);
  final shape = p.shape;
  if (shape == null) return null;
  if (shape.startsWith('fs:')) return p.height;
  if (shape.startsWith('fl:')) {
    final (_, arms) = parseElbow(shape);
    if (arms.isEmpty) return null;
    return arms.map((a) => a.thick).reduce(math.max);
  }
  if (shape.startsWith('fv:')) {
    final v = parseValve(shape);
    return valveNum(v, 'pipe', 20);
  }
  return null;
}

/// 예전(모양 여섯 가지 시절) 이름으로 저장된 계기는, 이름이 목록에 있으면
/// 지금의 모델별 모양으로 바꿔 읽는다. 이름을 고친 것은 예전 모양 그대로 둔다.
String? _upgradeShape(String? name, String? shape) {
  const legacy = {'dp', 'gp', 'dp_trad', 'dp_side', 'inline', 'fork'};
  if (shape == null || !legacy.contains(shape) || name == null) return shape;
  for (final list in kInstrumentPresets.values) {
    for (final p in list) {
      if (p.name == name) return p.shape;
    }
  }
  return shape;
}

abstract class MeasurePoint {
  Offset get center;
  Rect get boundingBox;
  String get id;
  Map<String, dynamic> toJson();
}

/// 부품 상자 왼쪽 위에서 기준점(접속구 가운데)까지의 거리. 접속구가 없으면 상자 가운데.
///
/// 접속구마다 관이 나가는 쪽(가장 가까운 변)을 본다. 위·아래 변으로 나가는 관은 세로 축(x),
/// 왼쪽·오른쪽 변으로 나가는 관은 가로 축(y)을 준다. 기준 x = 세로 축들의 평균(없으면 접속구
/// x 평균), 기준 y = 가로 축들의 평균(없으면 접속구 y 평균). 그래서 곧은 피팅·밸브는 관 축 위
/// 가운데, 엘보·티는 관 축이 만나는 몸통 모서리, 아래로 관이 나가는 계기는 접속구 가운데가 된다.
Offset itemRefCenterOffset(PlacedItem it) {
  final Offset box = Offset(it.width / 2, it.height / 2);
  final String? s = it.shape;
  if (s == null || s.isEmpty || it.width <= 0 || it.height <= 0) return box;
  final Size size = Size(it.width, it.height);
  final int turns =
      it.quarterTurns ?? InstrumentShape.inferredQuarterTurns(s, size);
  final List<Offset> ports = shapeConnectionPoints(
    s,
    size,
    quarterTurns: turns,
    mirror: it.flipped,
  );
  if (ports.isEmpty) return box;
  double sx = 0, sy = 0;
  final vx = <double>[], hy = <double>[];
  for (final p in ports) {
    sx += p.dx;
    sy += p.dy;
    final double dl = p.dx, dr = it.width - p.dx;
    final double dt = p.dy, db = it.height - p.dy;
    final double side = math.min(dl, dr), vert = math.min(dt, db);
    if (vert <= side) {
      vx.add(p.dx);
    } else {
      hy.add(p.dy);
    }
  }
  double mean(List<double> l) => l.reduce((a, b) => a + b) / l.length;
  final double x = vx.isNotEmpty ? mean(vx) : sx / ports.length;
  final double y = hy.isNotEmpty ? mean(hy) : sy / ports.length;
  return Offset(x, y);
}

int _layoutIdSeq = 0;

/// 부품·경로·치수 아이디. 밀리초만 쓰면 같은 순간에 둘이 생겨 겹칠 수 있어
/// 마이크로초 뒤에 차례 번호를 붙인다. [prefix]는 'dup_'처럼 앞에 붙는 표시.
String newLayoutId([String prefix = '']) =>
    '$prefix${DateTime.now().microsecondsSinceEpoch}_${_layoutIdSeq++}';

class PlacedItem implements MeasurePoint {
  @override
  final String id;
  String name;
  Offset position;
  double width;
  double height;
  bool isSelected;
  // 🚀 [신규] 위치가 확정된 모듈을 잠가서 드래그해도 실수로 옮겨지지
  // 않게 하는 기능.
  bool isLocked;

  /// 계기 모양(InstrumentShape). 없으면 네모 모듈.
  String? shape;

  /// 판 면에서 앞으로 튀어나오는 깊이(mm). 모르면 null(간섭 확인에서 빠진다).
  double? depth;

  /// 스키드: 바닥에서 부품 가운데까지 높이(mm). 모르면 null.
  double? elevation;

  /// 스키드 전선관 부속: 길이 방향으로 좌우를 뒤집어 놓음(허브가 반대쪽). 크기는 그대로.
  bool flipped;

  /// 태그 번호(PT-101 같은 것). 없으면 null. 도면·자재 수량·PDF 표에 이름 앞에 적는다.
  String? tag;

  /// 돌린 각도(0·90·180·270, 시계 방향). null이면 예전처럼 가로·세로 비율로 가린다.
  int? rotation;

  PlacedItem({
    required this.id,
    required this.name,
    required this.position,
    this.width = 80.0,
    this.height = 80.0,
    this.isSelected = false,
    this.isLocked = false,
    this.shape,
    this.depth,
    this.elevation,
    this.flipped = false,
    this.tag,
    this.rotation,
  });

  /// 태그가 있으면 "태그 이름", 없으면 이름.
  String get label =>
      tag == null || tag!.trim().isEmpty ? name : "${tag!.trim()} $name";

  /// 돌린 각도를 90° 단위로(0~3). null이면 null.
  int? get quarterTurns => rotation == null ? null : ((rotation! ~/ 90) % 4);

  /// 상자 가운데(자리 + 가로·세로 반).
  Offset get boxCenter =>
      Offset(position.dx + width / 2, position.dy + height / 2);

  /// 센터 치수·가상선·맞춤 안내선의 기준점. 접속구(튜브 붙는 자리)가 있는 부품은 접속구
  /// 가운데(관 축이 만나는 점), 없는 부품은 상자 가운데. 비대칭 부품(수직 배관 계기·엘보·
  /// 손잡이 달린 밸브)은 상자 가운데가 배관 중심과 다르기 때문이다.
  @override
  Offset get center => position + itemRefCenterOffset(this);

  @override
  Rect get boundingBox =>
      Rect.fromLTWH(position.dx, position.dy, width, height);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'item',
    'id': id,
    'name': name,
    'x': position.dx,
    'y': position.dy,
    'w': width,
    'h': height,
    'locked': isLocked,
    if (shape != null) 'shape': shape,
    if (depth != null) 'depth': depth,
    if (elevation != null) 'elev': elevation,
    if (flipped) 'flip': true,
    if (tag != null && tag!.trim().isNotEmpty) 'tag': tag!.trim(),
    if (rotation != null) 'rot': rotation,
  };

  factory PlacedItem.fromJson(Map<String, dynamic> j) => PlacedItem(
    id: j['id'] as String,
    name: j['name'] as String? ?? "이름 없음",
    position: Offset((j['x'] as num).toDouble(), (j['y'] as num).toDouble()),
    width: (j['w'] as num?)?.toDouble() ?? 80.0,
    height: (j['h'] as num?)?.toDouble() ?? 80.0,
    isLocked: j['locked'] as bool? ?? false,
    shape: _upgradeShape(j['name'] as String?, j['shape'] as String?),
    depth:
        (j['depth'] as num?)?.toDouble() ??
        _presetDepthByName(j['name'] as String?),
    elevation: (j['elev'] as num?)?.toDouble(),
    flipped: j['flip'] == true,
    tag: (j['tag'] as String?)?.trim().isEmpty ?? true
        ? null
        : (j['tag'] as String).trim(),
    rotation: (j['rot'] as num?)?.toInt(),
  );
}

class WallPoint implements MeasurePoint {
  @override
  final String id;
  final Offset position;

  WallPoint({required this.position})
    : id = "wall_${position.dx}_${position.dy}";

  @override
  Offset get center => position;

  @override
  Rect get boundingBox => Rect.fromLTWH(position.dx, position.dy, 0, 0);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'wall',
    'id': id,
    'x': position.dx,
    'y': position.dy,
  };

  factory WallPoint.fromJson(Map<String, dynamic> j) => WallPoint(
    position: Offset((j['x'] as num).toDouble(), (j['y'] as num).toDouble()),
  );
}

// 🚀 [추가] 저장된 p1/p2는 "item"/"wall" 중 하나라 type 필드로 구분해서
// 복원한다. item 쪽은 저장 당시 좌표를 담은 별개의 PlacedItem이라, 불러온
// 뒤 실제 모듈을 옮겨도 이미 찍힌 치수선은 저장 시점 위치에 고정된다.
MeasurePoint _measurePointFromJson(Map<String, dynamic> j) {
  return j['type'] == 'wall' ? WallPoint.fromJson(j) : PlacedItem.fromJson(j);
}

class PlacedDimension {
  final String id;
  // 불러온 뒤 실제 부품 객체로 다시 잇는다(relinkDimensions). 그래서 final이 아니다.
  MeasurePoint p1;
  MeasurePoint p2;
  // 🚀 [수정] 기존 치수의 기준(센터/측면)을 그 자리에서 바꿀 수 있도록
  // final을 뗐다.
  DimensionType type;
  // 🚀 [신규] 이 치수선에 대한 짧은 메모(예: "케이블 트레이 통과 구간").
  String? note;
  // 🚀 [신규] 최소 유지 간격(mm). 설정해두면 실제 거리가 이 값보다
  // 좁아지는 순간 치수선이 경고색으로 바뀐다(전기 패널 이격거리 확인용).
  double? minGapMm;
  // 🚀 [신규] 대각선 모드 - 켜면 축(가로/세로)에 맞춰 정렬하지 않고
  // 두 중심점을 직선으로 그대로 잇는 실제 직선거리+각도를 측정한다.
  bool isDiagonal;
  // 🚀 [신규] 안전 이격거리처럼 규정과 관련된 중요한 치수선을 표시해
  // 두께/아이콘으로 다른 치수와 구분되게 한다.
  bool isSafetyCritical;

  PlacedDimension({
    required this.id,
    required this.p1,
    required this.p2,
    required this.type,
    this.note,
    this.minGapMm,
    this.isDiagonal = false,
    this.isSafetyCritical = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'p1': p1.toJson(),
    'p2': p2.toJson(),
    'type': type.name,
    'note': note,
    'minGapMm': minGapMm,
    'isDiagonal': isDiagonal,
    'isSafetyCritical': isSafetyCritical,
  };

  factory PlacedDimension.fromJson(Map<String, dynamic> j) => PlacedDimension(
    id: j['id'] as String,
    p1: _measurePointFromJson(Map<String, dynamic>.from(j['p1'] as Map)),
    p2: _measurePointFromJson(Map<String, dynamic>.from(j['p2'] as Map)),
    type: DimensionType.values.byName(j['type'] as String),
    note: j['note'] as String?,
    minGapMm: (j['minGapMm'] as num?)?.toDouble(),
    isDiagonal: j['isDiagonal'] as bool? ?? false,
    isSafetyCritical: j['isSafetyCritical'] as bool? ?? false,
  );
}

/// 저장본·되돌리기·탭 바꾸기에서 읽은 치수의 점은 저장 당시 좌표를 담은 별개 사본이라,
/// 그 뒤 부품을 옮기면 치수선이 옛 자리에 남았다. 같은 아이디의 실제 부품 객체로 바꿔 끼워
/// 치수선이 부품을 따라오게 한다. 정면·측면의 view_ 점은 그리기 때 따로 맞추므로 건드리지 않는다.
/// 다시 이은 점의 수를 돌려준다.
int relinkDimensions(List<PlacedDimension> dims, List<PlacedItem> items) {
  if (dims.isEmpty || items.isEmpty) return 0;
  final byId = {for (final it in items) it.id: it};
  var n = 0;
  for (final d in dims) {
    final a = d.p1;
    if (a is PlacedItem && !a.id.startsWith('view_')) {
      final real = byId[a.id];
      if (real != null && !identical(real, a)) {
        d.p1 = real;
        n++;
      }
    }
    final b = d.p2;
    if (b is PlacedItem && !b.id.startsWith('view_')) {
      final real = byId[b.id];
      if (real != null && !identical(real, b)) {
        d.p2 = real;
        n++;
      }
    }
  }
  return n;
}

/// 길이가 있는 부품(덕트·레일·형강·전선관)인지. 자재 수량에 길이 합을 같이 적는다.
bool isLengthItem(PlacedItem it) {
  final shape = it.shape ?? '';
  if (shape == InstrumentShape.note) return false;
  if (shape == InstrumentShape.duct) return true;
  if (it.name.contains('레일') || it.name.contains('덕트')) return true;
  return shape.startsWith('sk_') &&
      !shape.startsWith('sk_cd_') &&
      shape != 'sk_jb' &&
      !shape.contains('coupling') &&
      !shape.contains('union');
}

/// 부품의 길이(긴 변, mm).
double itemLengthMm(PlacedItem it) =>
    it.width >= it.height ? it.width : it.height;

// 🚀 [정리] 손으로 앵커를 옮기는 기능은 폰에서 쓰기 부담스럽다는 판단으로
// 제거하고, 센터/측면 자동 계산만 남겼다.
({Offset p1, Offset p2, double distance}) computeDimensionEndpoints(
  PlacedDimension dim,
) {
  final Rect r1 = dim.p1.boundingBox;
  final Rect r2 = dim.p2.boundingBox;
  // 센터는 부품의 기준점(접속구 가운데, 없으면 상자 가운데). 벽 점은 그 자리.
  final Offset c1 = dim.p1.center;
  final Offset c2 = dim.p2.center;

  // 🚀 [신규] 대각선 모드면 축 정렬 없이 두 중심점을 직선 그대로 잇는다.
  if (dim.isDiagonal) {
    return (p1: c1, p2: c2, distance: (c1 - c2).distance);
  }

  final double dxCenter = (c1.dx - c2.dx).abs();
  final double dyCenter = (c1.dy - c2.dy).abs();

  if (dim.type == DimensionType.center) {
    final Offset p1 = c1;
    final Offset p2 = dxCenter > dyCenter
        ? Offset(c2.dx, c1.dy)
        : Offset(c1.dx, c2.dy);
    return (p1: p1, p2: p2, distance: (p1 - p2).distance);
  }

  if (dxCenter > dyCenter) {
    final bool isR1Left = r1.center.dx < r2.center.dx;
    final double x1 = isR1Left ? r1.right : r1.left;
    final double x2 = isR1Left ? r2.left : r2.right;
    final double y = (r1.center.dy + r2.center.dy) / 2;
    return (p1: Offset(x1, y), p2: Offset(x2, y), distance: (x1 - x2).abs());
  } else {
    final bool isR1Top = r1.center.dy < r2.center.dy;
    final double y1 = isR1Top ? r1.bottom : r1.top;
    final double y2 = isR1Top ? r2.top : r2.bottom;
    final double x = (r1.center.dx + r2.center.dx) / 2;
    return (p1: Offset(x, y1), p2: Offset(x, y2), distance: (y1 - y2).abs());
  }
}

// ---------------------------------------------------------
// 3. 서버(layouts 모음)에 저장하는 칸과 불러오기
// ---------------------------------------------------------
// 저장된 배치도의 칸 이름은 절대 바꾸거나 빼지 않는다. 예전에 저장한 배치도가
// 그대로 열려야 하기 때문이다(test/layout_board_compat_test.dart가 지킨다).
// 새 칸을 더할 때는 여기에만 더하고, 읽을 때는 그 칸이 없어도 되게 만든다.

/// layouts 문서에 저장하는 칸(저장 시각 칸은 서버 시각이라 부르는 쪽에서 붙인다).
Map<String, dynamic> layoutSaveFields({
  required String projectId,
  required String projectName,
  required double panelWidth,
  required double panelHeight,
  required List<PlacedItem> items,
  required List<PlacedDimension> dimensions,
  required String? backgroundImagePath,
  required double backgroundOpacity,
}) => {
  'projectId': projectId,
  'projectName': projectName,
  'panelWidth': panelWidth,
  'panelHeight': panelHeight,
  'items': items.map((e) => e.toJson()).toList(),
  'dimensions': dimensions.map((e) => e.toJson()).toList(),
  'backgroundImagePath': backgroundImagePath,
  'backgroundOpacity': backgroundOpacity,
};

/// 저장된 문서(또는 임시 저장·템플릿)의 items 칸을 모듈 목록으로 읽는다. 칸이 없으면 빈 목록.
List<PlacedItem> layoutItemsFromData(Map<String, dynamic> data) =>
    ((data['items'] as List?) ?? const [])
        .map((e) => PlacedItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

/// 저장된 문서의 dimensions 칸을 치수선 목록으로 읽는다. 칸이 없으면 빈 목록.
List<PlacedDimension> layoutDimensionsFromData(Map<String, dynamic> data) =>
    ((data['dimensions'] as List?) ?? const [])
        .map(
          (e) => PlacedDimension.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

// ---------------------------------------------------------
// 4. 만든 사람 칸(목록에 내 배치도만 보이게)
// ---------------------------------------------------------
// 예전 배치도에는 만든 사람 칸이 없다. 그래서 새 칸 두 개(ownerUid, ownerName)는
// 새 문서를 처음 저장할 때만 붙이고, 칸이 없는 예전 배치도는 누구 목록에나 예전처럼 보인다.
// 남이 만든 예전 배치도를 고쳐 저장해도 칸을 붙이지 않는다(붙이면 그 사람 목록에서 사라진다).

/// 만든 사람 칸 이름. 이미 있는 칸 이름과 겹치지 않는다.
const String kLayoutOwnerUidField = 'ownerUid';
const String kLayoutOwnerNameField = 'ownerName';

/// 지금 앱을 쓰는 사람. uid는 로그인(인증)했을 때만, name은 프로필 이름.
class LayoutOwner {
  final String? uid;
  final String? name;
  const LayoutOwner({this.uid, this.name});

  bool get isEmpty =>
      (uid == null || uid!.isEmpty) && (name == null || name!.isEmpty);
}

/// 새 문서를 저장할 때 덧붙이는 만든 사람 칸. 아는 것이 없으면 빈 맵.
Map<String, dynamic> layoutOwnerFields(LayoutOwner me) => {
  if (me.uid != null && me.uid!.isNotEmpty) kLayoutOwnerUidField: me.uid,
  if (me.name != null && me.name!.isNotEmpty) kLayoutOwnerNameField: me.name,
};

/// 목록에 이 배치도를 보여 줄지.
/// - 만든 사람 칸이 없는 예전 배치도: 보여 준다.
/// - uid가 양쪽에 다 있으면 uid로 비교한다.
/// - 아니면 이름이 양쪽에 다 있을 때 이름으로 비교한다.
/// - 비교할 것이 없으면(로그인도 이름도 없음) 예전처럼 보여 준다.
bool layoutVisibleTo(Map<String, dynamic> data, LayoutOwner me) {
  final String docUid = (data[kLayoutOwnerUidField] as String?)?.trim() ?? '';
  final String docName = (data[kLayoutOwnerNameField] as String?)?.trim() ?? '';
  if (docUid.isEmpty && docName.isEmpty) return true;
  final String myUid = me.uid?.trim() ?? '';
  final String myName = me.name?.trim() ?? '';
  if (docUid.isNotEmpty && myUid.isNotEmpty) return docUid == myUid;
  if (docName.isNotEmpty && myName.isNotEmpty) return docName == myName;
  return true;
}

/// 문서가 마지막으로 고쳐진 때(updatedAt, 없으면 createdAt). 둘 다 없으면 1970년.
DateTime layoutEditedAt(Map<String, dynamic> data) {
  final Object? ts = data['updatedAt'] ?? data['createdAt'];
  if (ts is Timestamp) return ts.toDate();
  if (ts is DateTime) return ts;
  return DateTime.fromMillisecondsSinceEpoch(0);
}

/// "다른 도면에서 가져오기"에 보여 줄 도면. 목록 화면과 같은 규칙으로 내 배치도만,
/// 지금 열어 둔 도면은 빼고, 최근 고친 순으로 늘어놓는다.
List<T> layoutImportCandidates<T>(
  Iterable<T> docs, {
  required LayoutOwner me,
  required String? currentId,
  required Map<String, dynamic> Function(T) dataOf,
  required String Function(T) idOf,
}) {
  final list = docs
      .where((d) => idOf(d) != currentId && layoutVisibleTo(dataOf(d), me))
      .toList();
  list.sort(
    (a, b) => layoutEditedAt(dataOf(b)).compareTo(layoutEditedAt(dataOf(a))),
  );
  return list;
}
