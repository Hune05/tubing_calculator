// 접지 계산(10-03): 보호도체·접지도체·본딩 도체 굵기, 중성점 접지저항 기준, TT 계통 접지저항 한도,
// 접지봉 접지저항. 화면 없이 계산만 한다. 근거와 확인 정도는 docs/전기_접지_전동기보호_근거.md.
//
// 확인 정도: KEC 조문(표 142.3-1, 142.3.2의 1·2, 142.3.3의 2 가, 142.3.1의 1·4, 142.5의 1, 211.2.6의 3,
// 143.3.1의 1·2, 142.2의 7 나, 142.4.1)은 현행 KEC(공고 제2025-227호) 원문과 일치함을 확인했다.
// k 값(PVC·XLPE 구리·알루미늄)은 KEC가 KS C IEC 60364-5-54 부속서 A를 가리키기만 하고, IEC 원문은 유료라 못 봤다(해설 자료 세 곳 일치).
// 142.3.1의 4 나의 예외(25 kV 이하 다중접지 전로 등)는 따로 다루지 않는다.
// 접지봉 식·대지저항률은 한 곳이거나 출처마다 달라 "근사·참고"로만 쓴다.
library;

import 'dart:math' as math;

/// 도체 단면적 표준 규격(mm²).
const List<double> kGroundStdSizes = [
  1.5,
  2.5,
  4,
  6,
  10,
  16,
  25,
  35,
  50,
  70,
  95,
  120,
  150,
  185,
  240,
  300,
];

/// [mm2] 이상인 가장 작은 표준 규격. 표 끝을 넘으면 null.
double? roundUpToStd(double mm2) {
  for (final s in kGroundStdSizes) {
    if (s + 1e-9 >= mm2) return s;
  }
  return null;
}

/// KEC 표 142.3-1: 선도체와 보호도체가 같은 재질일 때 보호도체 최소 단면적(mm²).
/// S ≤ 16 → S, 16 < S ≤ 35 → 16, S > 35 → S/2.
double protectiveConductorFromTable(double phaseMm2) {
  if (phaseMm2 <= 16) return phaseMm2;
  if (phaseMm2 <= 35) return 16;
  return phaseMm2 / 2;
}

enum GroundMaterial { copper, aluminum }

enum GroundInsulation { pvc, xlpe }

/// 보호도체가 케이블에 병합되지 않고 묶이지도 않은 경우(true) / 다심 케이블의 한 심 또는 묶인 도체(false).
/// IEC 60364-5-54 부속서 A의 k 값(KEC는 이 부속서를 가리키기만 한다. IEC 원문은 유료라 못 봤고,
/// Legrand 전력 가이드·Sorivo·elec-mate가 일치). 없는 조합은 null.
double? groundK(
  GroundMaterial m,
  GroundInsulation ins, {
  required bool separate,
}) {
  if (separate) {
    return switch ((m, ins)) {
      (GroundMaterial.copper, GroundInsulation.pvc) => 143,
      (GroundMaterial.copper, GroundInsulation.xlpe) => 176,
      (GroundMaterial.aluminum, GroundInsulation.pvc) => 95,
      (GroundMaterial.aluminum, GroundInsulation.xlpe) => 116,
    };
  }
  return switch ((m, ins)) {
    (GroundMaterial.copper, GroundInsulation.pvc) => 115,
    (GroundMaterial.copper, GroundInsulation.xlpe) => 143,
    (GroundMaterial.aluminum, GroundInsulation.pvc) => 76,
    (GroundMaterial.aluminum, GroundInsulation.xlpe) => 94,
  };
}

/// 단열 식으로 구한 최소 단면적 S = √(I²·t) / k (mm²). [fault] 고장전류 실효값(A), [seconds] 차단시간(5초 이하).
double? adiabaticMinArea({
  required double fault,
  required double seconds,
  required double k,
}) {
  if (fault <= 0 || seconds <= 0 || seconds > 5 || k <= 0) return null;
  return fault * math.sqrt(seconds) / k;
}

/// 접지도체 최소 단면적. KEC 142.3.1의 1(2025.12.30 개정, 현행 원문 확인):
/// 구리 저압 6 / 고압 이상 16 mm², 철 50 mm², 알루미늄은 접지도체로 쓸 수 없다.
/// 반환: (최소 mm², 쓸 수 없으면 null, 설명).
({double? mm2, String note}) groundingConductorMin({
  required String material, // 'cu' | 'fe' | 'al'
  required bool highVoltage,
}) {
  switch (material) {
    case 'cu':
      return (
        mm2: highVoltage ? 16 : 6,
        note: highVoltage ? '구리, 고압 이상 설비 16 mm² 이상' : '구리, 저압 설비 6 mm² 이상',
      );
    case 'fe':
      return (mm2: 50, note: '철(아연도금 등) 50 mm² 이상');
    default:
      return (mm2: null, note: '알루미늄은 접지도체로 쓸 수 없습니다(142.3.1의 1 다)');
  }
}

/// 보호등전위본딩 도체 최소 단면적(구리): 가장 큰 보호도체의 1/2 이상, 6 mm² 이상, 25 mm²를 넘길 필요는 없다.
double bondingConductorMinCopper(double largestProtectiveMm2) =>
    math.min(25, math.max(6, largestProtectiveMm2 / 2));

/// 변압기 중성점 접지저항 최댓값(Ω), KEC 142.5. [groundFaultAmps] = 고압·특고압측 1선 지락전류(A).
/// [trip]: 'normal'(150), 'within2s'(300, 1초 초과 2초 이내 자동 차단), 'within1s'(600, 1초 이내 자동 차단).
double? neutralGroundMaxOhms(double groundFaultAmps, {String trip = 'normal'}) {
  if (groundFaultAmps <= 0) return null;
  final base = switch (trip) {
    'within2s' => 300.0,
    'within1s' => 600.0,
    _ => 150.0,
  };
  return base / groundFaultAmps;
}

/// TT 계통 누전차단기 보호: R_A × IΔn ≤ 50 V → 접지저항 최댓값(Ω). KEC 211.2.6의 3(직류 120 V 조건은 없다).
double? ttMaxOhms(double residualAmps) {
  if (residualAmps <= 0) return null;
  return 50 / residualAmps;
}

/// 접지봉 1본 접지저항(Ω): R = ρ/(2πl)·(ln(4l/r) − 1). [rho] Ω·m, [lengthM] m, [diaMm] 봉 지름 mm.
/// 근사식이며 한 곳 자료(eom)다.
double? rodResistance({
  required double rho,
  required double lengthM,
  required double diaMm,
}) {
  if (rho <= 0 || lengthM <= 0 || diaMm <= 0) return null;
  final r = diaMm / 2000;
  if (4 * lengthM / r <= math.e) return null;
  return rho / (2 * math.pi * lengthM) * (math.log(4 * lengthM / r) - 1);
}

/// 봉 [n]본 병렬: R_n = K·R₁ / n(같은 봉). 간격 1~10 m이면 K = 1.2, 10 m를 넘으면 1.0.
/// 간격이 1 m 미만이면 이 식을 쓸 수 없어 null.
double? rodsParallel(double single, int n, {required double spacingM}) {
  if (n < 1) return null;
  // 1본은 간격과 상관없다(10-07: 간격 검사가 먼저라, 2본에서 1본으로 돌리면 숨은 간격 칸 때문에 오류가 났다).
  if (n == 1) return single;
  if (spacingM < 1) return null;
  final k = spacingM > 10 ? 1.0 : 1.2;
  return k * single / n;
}

/// 대지저항률 참고값(Ω·m). 습도·계절·층 구조에 따라 크게 달라 측정이 우선이다.
/// 출처: HIOKI 접지저항계 사용 안내, 기술사 풀이 사이트(범위가 비슷). 습한 정도에 따라 다름.
const List<(String, double)> kSoilResistivity = [
  ('매우 습한 토양·늪지', 30),
  ('농경지·점토질', 100),
  ('사질 점토', 150),
  ('습한 모래', 300),
  ('습한 자갈', 500),
  ('건조한 모래·자갈', 1000),
];
