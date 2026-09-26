// 압력 시험 계산(화면 없음). 근거는 docs/압력시험계산기_근거.md.
//
// ASME B31.3(2018 본문, 2022·2024 바뀐 점 확인)과 B31.1(2022 본문)의 시험 압력·절차,
// ASME PCC-2 부록 II·III(공압 시험 저장 에너지·안전거리), 이상기체 식에 따른 압력 강하 누설률,
// Kell(1975) 물 성질로 수압 시험 중 물 온도 1°C당 압력 변화, DOE 압축공기 누설.
// 압력은 모두 kPa(게이지는 g, 절대는 abs)로 셈하고 화면에서 단위를 바꾼다.
library;

import 'dart:math' as math;

const double kAtmKpa = 101.325;

enum PipingCode { b313, b311 }

enum TestMedium { hydro, pneumatic }

/// 시험 압력과 절차 한 벌.
class TestPlan {
  final double minKpa; // 최소 시험 압력(게이지)
  final double? maxKpa; // 최대(공압). 수압은 항복·부품 등급으로 제한 — 따로 알림
  final double holdMin; // 최소 유지 시간(분)
  final double? prelimKpa; // 공압 사전 점검 압력
  final double? examKpa; // 누설 점검 압력(이 압력까지 낮춰 본다)
  final double? reliefMaxKpa; // 안전밸브 설정 최대(B31.3 공압)
  final double? reliefRecKpa; // 안전밸브 권장 설정(B31.1 수압 1⅓×PT)
  final List<String> steps; // 절차
  final List<String> notes; // 주의·조건
  const TestPlan({
    required this.minKpa,
    this.maxKpa,
    required this.holdMin,
    this.prelimKpa,
    this.examKpa,
    this.reliefMaxKpa,
    this.reliefRecKpa,
    required this.steps,
    required this.notes,
  });
}

/// 시험 압력 정하기. [designKpa] 설계 압력(게이지), [stressRatio] ST/S(설계 온도 > 시험 온도일 때,
/// 모르면 1). B31.3 수압만 쓴다.
TestPlan testPlan({
  required PipingCode code,
  required TestMedium medium,
  required double designKpa,
  double stressRatio = 1,
}) {
  final p = designKpa;
  if (code == PipingCode.b313 && medium == TestMedium.hydro) {
    final ratio = math.max(1.0, stressRatio);
    final pt = 1.5 * p * ratio;
    return TestPlan(
      minKpa: pt,
      holdMin: 10,
      examKpa: p,
      steps: [
        '물을 채우고 공기를 뺍니다(높은 곳 벤트).',
        '시험 압력까지 올려 10분 이상 유지합니다(345.2.2(a)).',
        '압력을 낮춰도 되지만 설계 압력 아래로는 내리지 않고, 모든 이음·연결부를 점검합니다.',
      ],
      notes: [
        '식: PT = 1.5 × P${ratio > 1 ? ' × ST/S(${_f(ratio, 3)})' : ''} (345.4.2). 설계 온도가 시험 온도보다 높으면 ST/S를 넣습니다.',
        '시험 압력으로 관 응력이 항복을 넘거나 부품 등급의 1.5배를 넘으면 그 아래로 낮출 수 있습니다(345.2.1(a)).',
        '고인 물이 데워지면 압력이 오릅니다 — 넘치지 않게 조치합니다(345.2.1(b)).',
        '용기와 함께 시험하려면 발주처 승인과 용기 시험 압력이 배관 PT의 77% 이상이어야 합니다(345.4.3).',
        '압력계: 전 범위가 시험 압력의 약 2배(1.5~4배), 12개월 안에 검교정(2022판 345.2.2(d)).',
      ],
    );
  }
  if (code == PipingCode.b313) {
    // 공압
    final pt = 1.1 * p;
    final max = 1.33 * p;
    final prelim = math.min(pt / 2, 170.0);
    return TestPlan(
      minKpa: pt,
      maxKpa: max,
      holdMin: 10,
      prelimKpa: prelim,
      examKpa: p,
      reliefMaxKpa: pt + math.min(345.0, 0.1 * pt),
      steps: [
        '사전 점검: ${_f(prelim)}kPa(½PT와 170kPa 중 작은 것)까지 천천히 올려 모든 이음을 점검합니다(345.5.5, 2022판).',
        '단계적으로 시험 압력까지 올리고, 단계마다 배관 변형이 고르게 될 때까지 기다립니다.',
        '시험 압력에서 10분 이상 유지합니다.',
        '설계 압력까지 낮춘 뒤 모든 이음·연결부를 점검합니다.',
      ],
      notes: [
        '시험 압력: 1.1 × P 이상, 1.33 × P와 항복 기준 압력의 90% 중 작은 것 이하(345.5.4).',
        '안전밸브 설정: PT + (345kPa와 PT의 10% 중 작은 것) 이하(345.5.2).',
        '공압 시험은 수압이 어려울 때 발주처가 정합니다. 가스에 쌓인 에너지와 취성 파괴를 조심합니다(345.5.1) — "저장 에너지" 탭으로 안전거리를 보십시오.',
        '시험 가스는 공기가 아니면 불연성·무독성이어야 합니다(345.5.3).',
      ],
    );
  }
  if (medium == TestMedium.hydro) {
    // B31.1 수압
    final pt = 1.5 * p;
    return TestPlan(
      minKpa: pt,
      holdMin: 10,
      examKpa: p,
      reliefRecKpa: pt * 4 / 3,
      steps: [
        '물을 채우고 공기를 뺍니다.',
        '시험 압력(설계 압력의 1.5배 이상)에서 10분 이상 계속 유지합니다(137.4.5).',
        '설계 압력까지 낮춰 점검에 필요한 만큼 유지하며 모든 이음·연결부를 봅니다 — 새거나 맺히면 안 됩니다(펌프·밸브 패킹 제외).',
      ],
      notes: [
        '시험 중 원주 응력과 축 응력은 항복강도의 90% 이하(102.3.3(b)). 분리 안 된 부품(용기·펌프·밸브)의 허용 시험 압력도 넘지 않습니다.',
        '유지 중 과압에 대비해 안전밸브를 시험 압력의 1⅓배로 두기를 권합니다(137.2.6).',
        '보일러 외부 배관은 BPVC Section I PG-99로, 검사원 입회(137.3.1).',
        '묻히거나 안 보이는 이음: 1시간 이상 유지하며 압력·대기 온도를 계속 기록합니다(137.4.6(d)).',
      ],
    );
  }
  // B31.1 공압
  final pt = 1.2 * p;
  final max = 1.5 * p;
  final prelim = math.min(175.0, pt / 2);
  final exam = math.min(p, 700.0);
  return TestPlan(
    minKpa: pt,
    maxKpa: max,
    holdMin: 10,
    prelimKpa: prelim,
    examKpa: exam,
    steps: [
      '사전 점검: 175kPa(25psig) 이하로 누설을 봅니다(137.5.4).',
      '시험 압력의 ½까지 올린 뒤, 약 1/10씩 단계로 시험 압력까지 올립니다(137.5.5).',
      '시험 압력에서 10분 유지합니다.',
      '설계 압력과 700kPa(100psig) 중 작은 압력(${_f(exam)}kPa)으로 낮춰 모든 이음을 비눗물 등으로 점검합니다.',
    ],
    notes: [
      '시험 압력: 설계 압력의 1.2배 이상 1.5배 이하, 분리 안 된 부품 한도 안(137.5.5).',
      '공압 시험은 발주처가 정하거나 허락할 때만(137.5.1). 시험 가스는 불연성·무독성(137.5.2).',
      '가스에 쌓인 에너지가 큽니다 — "저장 에너지" 탭으로 안전거리를 보십시오.',
    ],
  );
}

// ─────────────── 압력 강하(공압) ───────────────

class DecayResult {
  final double rawDropKpa; // 게이지 읽음 차이 P1 − P2
  final double correctedDropKpa; // 온도를 T1로 맞춘 차이
  final double tempEffectKpa; // 온도 때문에 바뀐 몫
  final double? leakPaM3s; // 누설률(Pa·m³/s, T1 기준) — 체적을 알 때
  const DecayResult({
    required this.rawDropKpa,
    required this.correctedDropKpa,
    required this.tempEffectKpa,
    this.leakPaM3s,
  });

  /// mbar·L/s (1 Pa·m³/s = 10 mbar·L/s).
  double? get leakMbarLs => leakPaM3s == null ? null : leakPaM3s! * 10;

  /// 표준 mL/min(0°C·1atm). 1 Pa·m³/s = 9.8692 atm·cm³/s.
  double? get leakSccm => leakPaM3s == null ? null : leakPaM3s! * 9.8692 * 60;
}

/// 공압 압력 강하 판정. 압력은 게이지 kPa, 온도 °C, [volumeL] 계통 체적(L), [minutes] 유지 시간.
DecayResult pressureDecay({
  required double p1Kpa,
  required double p2Kpa,
  required double t1C,
  required double t2C,
  double atmKpa = kAtmKpa,
  double? volumeL,
  double? minutes,
}) {
  final p1 = p1Kpa + atmKpa;
  final p2 = p2Kpa + atmKpa;
  final t1 = t1C + 273.15;
  final t2 = t2C + 273.15;
  final p2AtT1 = p2 * t1 / t2; // 끝 압력을 시작 온도로 되돌린 값
  final corrected = p1 - p2AtT1;
  double? leak;
  if (volumeL != null && minutes != null && minutes > 0) {
    // Q = V/Δt · T1 · (P1/T1 − P2/T2), Pa·m³/s
    leak =
        (volumeL / 1000) /
        (minutes * 60) *
        t1 *
        (p1 * 1000 / t1 - p2 * 1000 / t2);
  }
  return DecayResult(
    rawDropKpa: p1Kpa - p2Kpa,
    correctedDropKpa: corrected,
    tempEffectKpa: (p1Kpa - p2Kpa) - corrected,
    leakPaM3s: leak,
  );
}

// ─────────────── 수압: 물 온도 1°C당 압력 ───────────────

// Kell(1975) 표 III: 온도(°C) → 체적 팽창계수 β(1e-6/K), 등온 압축률 κ(1e-6/bar).
const List<(double, double, double)> _kell = [
  (5, 16.0, 49.17),
  (10, 87.97, 47.81),
  (15, 150.87, 46.73),
  (20, 206.78, 45.89),
  (25, 257.21, 45.25),
  (30, 303.24, 44.77),
  (40, 385.30, 44.24),
  (50, 457.59, 44.17),
];

(double beta, double kappa) waterProps(double tC) {
  final t = tC.clamp(5.0, 50.0);
  for (var i = 0; i < _kell.length - 1; i++) {
    final a = _kell[i], b = _kell[i + 1];
    if (t <= b.$1) {
      final f = (t - a.$1) / (b.$1 - a.$1);
      return (
        (a.$2 + (b.$2 - a.$2) * f) * 1e-6,
        (a.$3 + (b.$3 - a.$3) * f) * 1e-6,
      );
    }
  }
  return (_kell.last.$2 * 1e-6, _kell.last.$3 * 1e-6);
}

/// 배관 재질: 선팽창계수(1/K)·탄성계수(bar).
enum PipeMaterial { carbon, stainless }

/// 공기 없이 물로 가득 찬 막힌 배관에서 물 온도 1°C당 압력 변화(bar/°C). 축 방향 자유(지상).
/// dP/dT = (β − 3α) / (κ + D/(t·E)·(5/4 − ν)).
double hydroBarPerDegC({
  required double waterC,
  required double odMm,
  required double wallMm,
  PipeMaterial material = PipeMaterial.carbon,
}) {
  final (beta, kappa) = waterProps(waterC);
  final alpha = material == PipeMaterial.carbon ? 11.7e-6 : 16.5e-6;
  final eBar = material == PipeMaterial.carbon ? 2.0e6 : 1.93e6; // 200·193 GPa
  const nu = 0.3;
  final d = odMm - wallMm; // 평균 지름
  final flex = wallMm > 0 ? d / (wallMm * eBar) * (1.25 - nu) : 0;
  return (beta - 3 * alpha) / (kappa + flex);
}

// ─────────────── 공압 시험 저장 에너지 ───────────────

class StoredEnergy {
  final double joules;
  final double tntKg;
  final double distanceM; // 고정 거리와 식 거리 중 큰 것
  final double scaledM; // R = 20·TNT^(1/3)
  final bool beyondFixed; // 271 MJ 넘음 — 식으로 셈해야 함
  const StoredEnergy({
    required this.joules,
    required this.tntKg,
    required this.distanceM,
    required this.scaledM,
    required this.beyondFixed,
  });
}

/// ASME PCC-2 부록 II(식 II-2, 공기·질소 k=1.4)·III(안전거리). [testKpa] 게이지, [volumeL] 계통 체적.
StoredEnergy storedEnergy({required double testKpa, required double volumeL}) {
  const pa = 101.0; // kPa abs(식 II-2 정의)
  final pat = testKpa + kAtmKpa; // kPa abs
  final v = volumeL / 1000; // m³
  final e = 2.5 * pat * 1000 * v * (1 - math.pow(pa / pat, 0.286)); // J
  final tnt = e / 4266920;
  final scaled = 20 * math.pow(tnt, 1 / 3).toDouble();
  final double fixed = e <= 135.5e6 ? 30 : (e <= 271e6 ? 60 : 0);
  return StoredEnergy(
    joules: e,
    tntKg: tnt,
    distanceM: math.max(fixed, scaled),
    scaledM: scaled,
    beyondFixed: e > 271e6,
  );
}

/// 관 안 체적(L) = π/4 · ID² · 길이.
double pipeVolumeL({required double idMm, required double lengthM}) =>
    math.pi / 4 * math.pow(idMm / 1000, 2) * lengthM * 1000;

// ─────────────── 압축공기 구멍 누설 ───────────────

/// 구멍 누설(대기 상태 L/s, 20°C). 초킹 흐름 Q ≈ 0.154·Cd·d²·P0abs(bar). 0.9barg 아래는 부정확.
double holeLeakLps({
  required double holeMm,
  required double supplyKpa,
  double cd = 0.97,
}) {
  final p0 = (supplyKpa + kAtmKpa) / 100; // bar abs
  return 0.154 * cd * holeMm * holeMm * p0;
}

/// 누설을 메우는 압축기 전력(kW) — 100cfm당 18kW(DOE) = m³/min당 6.36kW.
double leakCompressorKw(double lps) => lps * 60 / 1000 * 6.36;

String _f(double v, [int d = 1]) {
  var s = v.toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}
