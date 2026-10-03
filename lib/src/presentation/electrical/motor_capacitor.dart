// 전동기 콘덴서·단상 운전·최대 토크 계산(10-03). 화면 없이 계산만 한다. 근거: docs/전동기_콘덴서_토크_근거.md.
//
// 확인 정도(2026-10-03 조사):
// - 콘덴서 한도 Qc ≤ 0.9·I0·Un·√3: Schneider Electrical Installation Guide 2007 장 L 7.2 원문. 도표 L24·L25도 원문.
// - 무부하 전류 추정 I0 ≈ 2·In·(1 − cosφn): 한 곳(Schneider 프랑스어판을 검색 요약 두 번으로 확인, 원문 도표 역산 일치).
// - 3상 모터 단상 운전(Steinmetz) C = 2P ÷ (√3·ω·U²): 한 곳(de.wikipedia)이고 직접 검산했다. 60 Hz 값은 식 환산이다.
// - 단상 전동기 µF/kW와 기동 콘덴서 배율은 20~50 µF/kW, 2~3배로 출처 간 폭이 넓다(명판 우선).
// - 최대 토크 표: NEMA MG-1 12.39(원문), IEC 60034-12 표 1 설계 N(원문). NEMA D·IEC 설계 H는 못 찾았다.
library;

import 'dart:math' as math;

// ─────────────── 전동기 단자 직접 콘덴서 한도 ───────────────

/// 자기여자를 피하는 콘덴서 상한(kvar) = 0.9 × I0 × Un × √3. [i0Amps] 무부하 전류(A), [volts] 선간 전압(V).
double? capacitorLimitKvar(double i0Amps, double volts) {
  if (i0Amps <= 0 || volts <= 0) return null;
  return 0.9 * i0Amps * (volts / 1000) * math.sqrt(3);
}

/// 무부하 전류 추정 I0 ≈ 2 × In × (1 − cosφn). 한 곳 자료이므로 측정값·제조사 값이 있으면 그것을 쓴다.
double? estimateNoLoadAmps(double ratedAmps, double ratedPf) {
  if (ratedAmps <= 0 || ratedPf <= 0 || ratedPf > 1) return null;
  return 2 * ratedAmps * (1 - ratedPf);
}

/// 콘덴서를 달면 전원 쪽 전류가 줄어든다. 과부하계전기가 콘덴서보다 전원 쪽이면 설정을 cosφ 전 ÷ cosφ 후 비율로 낮춘다.
double? relaySettingAfter(double setting, double pfBefore, double pfAfter) {
  if (setting <= 0 || pfBefore <= 0 || pfBefore > 1 || pfAfter <= 0 || pfAfter > 1) {
    return null;
  }
  return setting * pfBefore / pfAfter;
}

/// Schneider 도표 L25: 도표 L24의 kvar만큼 보상했을 때 계전기 설정 보정계수. 키는 동기 회전수(rpm).
const Map<int, double> kRelayFactorByRpm = {750: 0.88, 1000: 0.90, 1500: 0.91, 3000: 0.93};

/// Schneider 도표 L24(3상 230/400 V): 전동기 kW → 자기여자를 피하는 최대 kvar. 열 순서는 3000, 1500, 1000, 750 rpm.
const List<({double kw, List<double> kvar})> kSchneiderL24 = [
  (kw: 22, kvar: [6, 8, 9, 10]),
  (kw: 30, kvar: [7.5, 10, 11, 12.5]),
  (kw: 37, kvar: [9, 11, 12.5, 16]),
  (kw: 45, kvar: [11, 13, 14, 17]),
  (kw: 55, kvar: [13, 17, 18, 21]),
  (kw: 75, kvar: [17, 22, 25, 28]),
  (kw: 90, kvar: [20, 25, 27, 30]),
  (kw: 110, kvar: [24, 29, 33, 37]),
  (kw: 132, kvar: [31, 36, 38, 43]),
  (kw: 160, kvar: [35, 41, 44, 52]),
  (kw: 200, kvar: [43, 47, 53, 61]),
  (kw: 250, kvar: [52, 57, 63, 71]),
  (kw: 280, kvar: [57, 63, 70, 79]),
  (kw: 355, kvar: [67, 76, 86, 98]),
  (kw: 400, kvar: [78, 82, 97, 106]),
  (kw: 450, kvar: [87, 93, 107, 117]),
];

/// 도표 L24에서 [kw] 행, [syncRpm] 열(3000·1500·1000·750)의 최대 kvar. 없으면 null.
double? schneiderL24Kvar(double kw, int syncRpm) {
  final col = switch (syncRpm) {
    3000 => 0,
    1500 => 1,
    1000 => 2,
    750 => 3,
    _ => -1,
  };
  if (col < 0) return null;
  for (final r in kSchneiderL24) {
    if ((r.kw - kw).abs() < 1e-6) return r.kvar[col];
  }
  return null;
}

// ─────────────── 콘덴서 값 환산 ───────────────

/// 콘덴서 전류(A) = 2π f C V (C μF).
double capacitorAmps(double uf, double volts, double hz) =>
    2 * math.pi * hz * uf * 1e-6 * volts;

/// 콘덴서 무효전력(kvar) = 2π f C V² (C μF).
double capacitorKvarOf(double uf, double volts, double hz) =>
    2 * math.pi * hz * uf * 1e-6 * volts * volts / 1000;

// ─────────────── 3상 전동기 단상 운전(Steinmetz) ───────────────

/// 운전 콘덴서 C[μF] = 2 × P ÷ (√3 × 2πf × U²). [kw]는 전동기 정격 출력, [volts]는 권선(= 단상 전원) 전압.
/// Δ 결선 전동기에서 한 권선과 병렬로 단다. 230 V 50 Hz에서 약 70 μF/kW(DIN 48501 계열 자료)와 맞는 식이다.
double? steinmetzRunMicroFarad(double kw, double volts, double hz) {
  if (kw <= 0 || volts <= 0 || hz <= 0) return null;
  return 2 * kw * 1000 / (math.sqrt(3) * 2 * math.pi * hz * volts * volts) * 1e6;
}

/// 단상 운전 때 낼 수 있는 출력 범위(정격의 70~80 %, 자료마다 60~80 %로 갈린다).
const double kSteinmetzOutputLow = 0.7;
const double kSteinmetzOutputHigh = 0.8;

/// 기동 콘덴서 배율 범위(운전용의 2~3배, 시동 후 분리).
const double kStartCapLow = 2;
const double kStartCapHigh = 3;

// ─────────────── 단상 유도전동기 콘덴서 ───────────────

/// 운전 콘덴서 대략 범위(μF/kW): 20~50(자료마다 폭이 크다). 명판·제조사 값을 우선한다.
const double kPscUfPerKwLow = 20;
const double kPscUfPerKwHigh = 50;

/// 단상 전동기 운전 콘덴서 범위(μF) = 20~50 × 출력 kW.
(double, double)? singlePhaseRunRangeUf(double kw) {
  if (kw <= 0) return null;
  return (kw * kPscUfPerKwLow, kw * kPscUfPerKwHigh);
}

// ─────────────── 최대(breakdown) 토크 ───────────────

/// 최대 토크 = 정격 토크 × 배수(명판·제조사 자료의 값).
double? maxTorqueNm(double ratedNm, double multiple) {
  if (ratedNm <= 0 || multiple <= 0) return null;
  return ratedNm * multiple;
}

/// 최대 토크는 전압의 제곱에 비례한다(90 % 전압 → 81 %).
double torqueAtVoltage(double nm, double voltageRatio) =>
    nm * voltageRatio * voltageRatio;

/// IEC 60034-12 표 1 설계 N: 정격 토크에 대한 최대 토크 최소 배수. 극수 2·4·6·8, 정격 출력 [kw].
/// 상한은 없다(최소값). 설계 H는 확인하지 못했다.
double? iecDesignNMinMultiple(double kw, int poles) {
  if (kw <= 0) return null;
  const rows = <(double, List<double>)>[
    (0.63, [2.0, 2.0, 1.7, 1.6]),
    (1.0, [2.0, 2.0, 1.8, 1.7]),
    (6.3, [2.0, 2.0, 1.9, 1.8]),
    (16, [2.0, 2.0, 1.8, 1.7]),
    (40, [1.9, 1.9, 1.8, 1.7]),
    (63, [1.8, 1.8, 1.7, 1.7]),
    (100, [1.8, 1.8, 1.7, 1.6]),
    (160, [1.7, 1.7, 1.7, 1.6]),
    (250, [1.7, 1.7, 1.6, 1.6]),
    (double.infinity, [1.6, 1.6, 1.6, 1.6]),
  ];
  final col = switch (poles) {
    2 => 0,
    4 => 1,
    6 => 2,
    8 => 3,
    _ => -1,
  };
  if (col < 0) return null;
  for (final (upTo, v) in rows) {
    if (kw <= upTo) return v[col];
  }
  return null;
}

/// NEMA MG-1 12.39 설계 A·B: 정격 토크에 대한 최대 토크 최소 비율(%). [hp] 마력, [syncRpm] 3600·1800·1200·900(60 Hz).
/// 표에서 확인한 행만 있다(1·1.5·2·3·5·7.5 hp, 10~125 hp, 250 hp 이상). 나머지는 null.
double? nemaAbMinPercent(double hp, int syncRpm) {
  final col = switch (syncRpm) {
    3600 => 0,
    1800 => 1,
    1200 => 2,
    900 => 3,
    _ => -1,
  };
  if (col < 0 || hp <= 0) return null;
  const rows = <(double, List<double?>)>[
    (1, [null, 300, 265, 215]),
    (1.5, [250, 280, 250, 210]),
    (2, [240, 270, 240, 210]),
    (3, [230, 250, 230, 205]),
    (5, [215, 225, 215, 205]),
    (7.5, [200, 215, 205, 200]),
  ];
  for (final (h, v) in rows) {
    if ((h - hp).abs() < 1e-6) return v[col];
  }
  if (hp >= 10 - 1e-9 && hp <= 125 + 1e-9) return 200;
  if (hp >= 250 - 1e-9) return 175;
  return null;
}
