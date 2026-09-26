// 압력 시험 계산(화면 없음). 근거는 docs/압력시험계산기_근거.md.
//
// ASME B31.3(2018 본문, 2022·2024 바뀐 점 확인)과 B31.1(2022 본문)의 시험압력·절차,
// ASME PCC-2-2022 Article 501 부록 501-II·501-III(공압 시험 저장 에너지·출입 통제 거리),
// 이상기체 식에 따른 압력강하 누설률, Kell(1975) 물 성질로 수압 시험 중 물 온도 1°C당 압력 변화,
// DOE 압축공기 누설, EN 837 압력계 눈금 범위.
// 압력은 모두 kPa(게이지는 g, 절대는 abs)로 계산하고 화면에서 단위를 바꾼다.
library;

import 'dart:math' as math;

const double kAtmKpa = 101.325;

enum PipingCode { b313, b311 }

enum TestMedium { hydro, pneumatic }

/// 시험압력과 절차 한 벌.
class TestPlan {
  final double minKpa; // 최소 시험압력(게이지)
  final double? maxKpa; // 최대(공압). 수압은 항복·부품 등급으로 제한하므로 따로 알림
  final double holdMin; // 최소 유지시간(분)
  final double? prelimKpa; // 공압 예비 점검 압력
  final bool prelimOptional; // 예비 점검이 선택인지(B31.1 137.5.4 "may")
  final double? examKpa; // 누설 확인 압력(이 압력까지 낮춰 본다)
  final double? reliefMaxKpa; // 안전밸브 설정압력 최대(B31.3 공압)
  final double? reliefRecKpa; // 안전밸브 권장 설정압력(B31.1 수압 1⅓×PT)
  final double usedKpa; // 안전밸브·예비 점검을 계산한 시험압력(실제 값을 넣었으면 그 값, 아니면 최소)
  final List<double> stepKpa; // 단계 압력(B31.1 공압: ½PT 뒤 PT/10씩)
  final List<String> steps; // 절차
  final List<String> notes; // 주의 사항

  /// 실제 시험압력이 허용 범위 이내인지. 넣지 않았으면 null.
  bool? actualInRange(double? actualKpa) => actualKpa == null
      ? null
      : actualKpa >= minKpa - 1e-9 &&
            (maxKpa == null || actualKpa <= maxKpa! + 1e-9);

  const TestPlan({
    required this.minKpa,
    this.maxKpa,
    required this.holdMin,
    this.prelimKpa,
    this.prelimOptional = false,
    this.examKpa,
    this.reliefMaxKpa,
    this.reliefRecKpa,
    required this.usedKpa,
    this.stepKpa = const [],
    required this.steps,
    required this.notes,
  });
}

// B31.3-2024 345.2.3: 누설 시험을 마친 기계적 이음부는 분해·재조립 뒤 재시험하지 않아도 된다.
// 이전 판은 플랜지와 계기 연결 나사·튜브 이음만.
// 출처: https://becht.com/becht-blog/entry/asme-b31-3-process-piping-changes-in-the-2024-edition/
const String _note3452 =
    '2024판 345.2.3: 누설 시험을 마친 기계적 이음부는 분해 후 다시 조립해도 재시험하지 않아도 됩니다. '
    '이전 판은 플랜지와 계기 연결 나사·튜브 이음만 해당했습니다.';

/// 시험압력 정하기. [designKpa] 설계압력(게이지), [stressRatio] ST/S(설계 온도 > 시험 온도일 때,
/// 모르면 1). B31.3 수압만 쓴다. [actualKpa] 실제로 올릴 시험압력. 넣으면 안전밸브·예비 점검을
/// 이 압력으로 계산한다(범위 밖이어도 그대로 계산하고 화면에서 알린다). 없으면 최소 시험압력으로.
TestPlan testPlan({
  required PipingCode code,
  required TestMedium medium,
  required double designKpa,
  double stressRatio = 1,
  double? actualKpa,
}) {
  final p = designKpa;
  final a = actualKpa != null && actualKpa > 0 ? actualKpa : null;
  if (code == PipingCode.b313 && medium == TestMedium.hydro) {
    final ratio = math.max(1.0, stressRatio);
    final pt = 1.5 * p * ratio;
    return TestPlan(
      minKpa: pt,
      holdMin: 10,
      examKpa: p,
      usedKpa: a ?? pt,
      steps: [
        '물을 채우고 공기를 뺍니다(높은 곳 벤트).',
        '시험압력까지 올려 10분 이상 유지합니다(345.2.2(a)).',
        '압력을 낮춰도 되지만 설계압력 미만으로는 내리지 않고, 모든 이음·연결부를 점검합니다.',
      ],
      notes: [
        // 2004판까지 ST/S 상한 6.5. 현행판에는 없다(docs 근거 참고).
        if (ratio > 6.5)
          'ST/S가 6.5를 초과합니다. 이전 판(2004판 등)은 6.5로 제한했습니다. 절차서를 확인하십시오.',
        '식: PT = 1.5 × P${ratio > 1 ? ' × ST/S(${_f(ratio, 3)})' : ''} (345.4.2). 설계 온도가 시험 온도보다 높으면 ST/S를 넣습니다.',
        '시험압력은 배관의 모든 지점에서 이 값 이상이어야 합니다(345.4.2).',
        '시험압력에서 관 응력이 항복강도를 초과하거나 부품 등급의 1.5배를 초과하면, 초과하지 않는 압력까지 낮출 수 있습니다(345.2.1(a)).',
        '갇힌 물이 데워지면 압력이 오릅니다. 과압되지 않게 압력을 빼 줄 수단을 둡니다(345.2.1(b)).',
        '용기와 함께 시험하려면 발주처 승인과 용기 시험압력이 배관 PT의 77% 이상이어야 합니다(345.4.3).',
        '압력계 눈금 범위는 시험압력의 약 2배(1.5~4배), 검교정 12개월 이내(2022판 345.2.2(d)).',
        _note3452,
      ],
    );
  }
  if (code == PipingCode.b313) {
    // 공압
    final min = 1.1 * p;
    final max = 1.33 * p;
    final pt = a ?? min;
    final prelim = math.min(pt / 2, 170.0);
    return TestPlan(
      minKpa: min,
      maxKpa: max,
      holdMin: 10,
      prelimKpa: prelim,
      examKpa: p,
      reliefMaxKpa: pt + math.min(345.0, 0.1 * pt),
      usedKpa: pt,
      steps: [
        '예비 점검: ${_f(prelim)}kPa(½PT와 170kPa 중 작은 것)까지 천천히 올려 모든 이음을 점검합니다(345.5.5, 2022판).',
        '단계적으로 시험압력까지 올립니다. 단계마다 잠시 유지해 압력을 안정시킵니다.',
        '시험압력에서 10분 이상 유지합니다.',
        '설계압력까지 낮춘 뒤 모든 이음·연결부를 점검합니다.',
      ],
      notes: [
        '시험압력: 1.1 × P 이상, 1.33 × P와 항복 기준 압력의 90% 중 작은 것 이하(345.5.4).',
        '안전밸브 설정압력: PT + (345kPa와 PT의 10% 중 작은 것) 이하(345.5.2).',
        '공압 시험은 수압이 어려울 때 발주처가 정합니다. 압축 기체의 저장 에너지와 취성 파괴 위험에 주의합니다(345.5.1). '
            '"공압 안전거리" 탭에서 출입 통제 거리를 확인하십시오.',
        '시험 가스는 공기가 아니면 불연성·무독성이어야 합니다(345.5.3).',
        _note3452,
      ],
    );
  }
  if (medium == TestMedium.hydro) {
    // B31.1 수압
    final min = 1.5 * p;
    final pt = a ?? min;
    return TestPlan(
      minKpa: min,
      holdMin: 10,
      examKpa: p,
      reliefRecKpa: pt * 4 / 3,
      usedKpa: pt,
      steps: [
        '물을 채우고 공기를 뺍니다.',
        '시험압력(설계압력의 1.5배 이상)에서 10분 이상 계속 유지합니다(137.4.5).',
        '설계압력까지 낮춰 점검에 필요한 만큼 유지하며 모든 이음·연결부를 확인합니다. '
            '누설이나 물맺힘이 없어야 합니다(펌프·밸브 패킹 제외).',
      ],
      notes: [
        '시험 중 원주 응력과 축 응력은 항복강도의 90% 이하(102.3.3(b)). 격리하지 않은 기기(용기·펌프·밸브)의 허용 시험압력도 초과하지 않습니다.',
        '유지 중 과압에 대비해 안전밸브 설정압력을 시험압력의 1⅓배로 두기를 권합니다(137.2.6).',
        '보일러 외부 배관은 BPVC Section I PG-99에 따르고 검사원이 입회합니다(137.3.1).',
        '매설되거나 가려진 이음부: 1시간 이상 유지하며 압력·대기 온도를 계속 기록합니다(137.4.6(d)).',
      ],
    );
  }
  // B31.1 공압
  final min = 1.2 * p;
  final max = 1.5 * p;
  final pt = a ?? min;
  // 137.5.4: 175kPa(25psig)를 넘지 않는 예비 공압 시험을 "할 수 있다"(may). ½PT 규칙은 이 조항에 없다.
  const prelim = 175.0;
  final exam = math.min(p, 700.0);
  return TestPlan(
    minKpa: min,
    maxKpa: max,
    holdMin: 10,
    prelimKpa: prelim,
    prelimOptional: true,
    examKpa: exam,
    usedKpa: pt,
    // 137.5.5: ½PT 이하까지 올린 뒤 약 PT/10씩 단계로 PT까지.
    stepKpa: [for (var i = 5; i <= 10; i++) pt * i / 10],
    steps: [
      '예비 점검(선택): 다른 시험 전에 175kPa(25psig) 이하 공압으로 큰 누설을 찾을 수 있습니다(137.5.4).',
      '시험압력의 ½까지 천천히 올린 뒤, 약 1/10씩 단계로 시험압력까지 올립니다(137.5.5).',
      '시험압력에서 10분 이상 유지합니다.',
      '설계압력과 700kPa(100psig) 중 작은 압력(${_f(exam)}kPa)으로 낮춰 모든 이음을 비눗물 등으로 점검합니다.',
    ],
    notes: [
      '시험압력: 설계압력의 1.2배 이상 1.5배 이하, 격리하지 않은 기기 한도 이내(137.5.5).',
      '공압 시험은 발주처가 정하거나 허락할 때만 합니다(137.5.1). 시험 가스는 불연성·무독성(137.5.2).',
      '압축 기체의 저장 에너지가 큽니다. "공압 안전거리" 탭에서 출입 통제 거리를 확인하십시오.',
    ],
  );
}

/// 물 기둥 압력(kPa). 물 1000kg/m³ × 9.81m/s² → 1m당 9.81kPa.
double waterHeadKpa(double heightM) => 9.81 * heightM;

// ─────────────── 압력계 눈금 범위 ───────────────

/// EN 837-1 압력계 표준 눈금 범위(bar, 0부터). 출처: WIKA 자료 IN 00.02(2021-05)
/// https://www.wika.com/media/Technical-information/English/ds_in0002_en_co.pdf
const List<double> kEn837Bar = [
  0.6,
  1,
  1.6,
  2.5,
  4,
  6,
  10,
  16,
  25,
  40,
  60,
  100,
  160,
  250,
  400,
  600,
  1000,
  1600,
];

class GaugeRange {
  final double recKpa; // 시험압력 × 2
  final double lowKpa; // × 1.5
  final double highKpa; // × 4
  final List<double> fitBar; // 1.5~4배 이내 EN 837 눈금(bar)
  final double? bestBar; // 2배에 가장 가까운 눈금
  const GaugeRange({
    required this.recKpa,
    required this.lowKpa,
    required this.highKpa,
    required this.fitBar,
    this.bestBar,
  });
}

/// 압력계 눈금 범위: 시험압력의 약 2배, 1.5배 이상 4배 이하(B31.3 2022판 345.2.2(d)).
GaugeRange gaugeRange(double testKpa) {
  final low = 1.5 * testKpa;
  final high = 4 * testKpa;
  final rec = 2 * testKpa;
  final fit = [
    for (final b in kEn837Bar)
      if (b * 100 >= low - 1e-9 && b * 100 <= high + 1e-9) b,
  ];
  double? best;
  for (final b in fit) {
    if (best == null ||
        math.log(b * 100 / rec).abs() < math.log(best * 100 / rec).abs()) {
      best = b;
    }
  }
  return GaugeRange(
    recKpa: rec,
    lowKpa: low,
    highKpa: high,
    fitBar: fit,
    bestBar: best,
  );
}

// ─────────────── 압력강하(공압) ───────────────

class DecayResult {
  final double rawDropKpa; // 게이지 측정값 차이 P1 − P2
  final double correctedDropKpa; // 온도를 T1 기준으로 환산한 차이
  final double tempEffectKpa; // 온도 영향
  final double t1K; // 시작 온도(K)
  final double? leakPaM3s; // 누설률(Pa·m³/s, T1 기준). 체적을 알 때
  const DecayResult({
    required this.rawDropKpa,
    required this.correctedDropKpa,
    required this.tempEffectKpa,
    required this.t1K,
    this.leakPaM3s,
  });

  /// mbar·L/s (1 Pa·m³/s = 10 mbar·L/s).
  double? get leakMbarLs => leakPaM3s == null ? null : leakPaM3s! * 10;

  /// 표준 mL/min(20°C·1기압, 101.325kPa·293.15K). T1 기준 값을 20°C로 환산한다.
  /// 1 Pa·m³/s = 1e6/101325 = 9.8692 atm·cm³/s. 20°C 표준은 Cincinnati Test Systems
  /// (https://www.cincinnati-test.com/leak-rate-units, NDT Handbook 293K·14.696psia)를 따른다.
  double? get leakSccm =>
      leakPaM3s == null ? null : leakPaM3s! * 293.15 / t1K * 9.8692 * 60;

  /// 허용 압력강하 [allowedKpa]를 주면 온도를 보정한 강하로 합격(true)/불합격(false). 없으면 null.
  bool? passes(double? allowedKpa) =>
      allowedKpa == null ? null : correctedDropKpa <= allowedKpa + 1e-9;
}

/// 공압 압력강하 판정. 압력은 게이지 kPa, 온도 °C, [volumeL] 시험 구간 체적(L), [minutes] 유지시간.
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
  final p2AtT1 = p2 * t1 / t2; // 종료 압력을 시작 온도 기준으로 환산한 값
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
    t1K: t1,
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

/// 물 성질 표가 있는 범위(5~50°C). 밖이면 끝 값으로 계산한다.
const double kWaterMinC = 5;
const double kWaterMaxC = 50;

(double beta, double kappa) waterProps(double tC) {
  final t = tC.clamp(kWaterMinC, kWaterMaxC);
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

/// 시험 가스. k = 비열비. 공기·질소 1.4(PCC-2 식 II-2), 헬륨·아르곤 1.67(단원자 기체).
enum TestGas { airN2, monatomic }

extension TestGasK on TestGas {
  double get k => this == TestGas.airN2 ? 1.4 : 1.67;
}

class StoredEnergy {
  final double joules;
  final double tntKg;
  final double distanceM; // 최소 거리와 식 거리 중 큰 것
  final double scaledM; // R = 20·(2·TNT)^(1/3)
  final bool beyondFixed; // 271 MJ 초과: 식으로 계산한 거리를 쓴다
  const StoredEnergy({
    required this.joules,
    required this.tntKg,
    required this.distanceM,
    required this.scaledM,
    required this.beyondFixed,
  });
}

/// ASME PCC-2-2022 Article 501 부록 501-II(저장 에너지)·501-III(거리). [testKpa] 게이지,
/// [volumeL] 시험 구간 체적.
///
/// E = [1/(k−1)]·Pat·V·[1 − (Pa/Pat)^((k−1)/k)] (식 II-1). 공기·질소(k = 1.4)는 식 II-2
/// E = 2.5·Pat·V·[1 − (Pa/Pat)^0.286] 그대로. TNT = E / 4,266,920 (식 II-3).
/// 거리: 30m(E ≤ 135.5MJ), 60m(E ≤ 271MJ)와 R = Rscaled·(2·TNT)^(1/3)(Rscaled 20m/kg^(1/3)) 중 큰 것.
/// 2018판부터 TNT에 2를 곱한다(지면 반사). 파편 거리(표 501-III-2-1)는 계산하지 않는다.
/// 확인: https://www.piping-world.com/safe-distance-and-stored-energy-calculator-pneumatic-test
///       https://www.piping-world.com/pneumatic-testing-safe-distances-from-stored-energy-calculations
///       (24" STD 600m 10barg → 224,057,795J, TNT 52.51kg, 94.36m)
///       https://humainengineering.com/tools/pneumatic-pressure-test.html (2022판, 최소 30m)
StoredEnergy storedEnergy({
  required double testKpa,
  required double volumeL,
  TestGas gas = TestGas.airN2,
}) {
  const pa = 101.0; // kPa abs(식 II-2 정의)
  final pat = testKpa + kAtmKpa; // kPa abs
  final v = volumeL / 1000; // m³
  final k = gas.k;
  final factor = gas == TestGas.airN2 ? 2.5 : 1 / (k - 1);
  final expo = gas == TestGas.airN2 ? 0.286 : (k - 1) / k;
  final e = factor * pat * 1000 * v * (1 - math.pow(pa / pat, expo)); // J
  final tnt = e / 4266920;
  final scaled = 20 * math.pow(2 * tnt, 1 / 3).toDouble();
  final double fixed = e <= 135.5e6 ? 30 : (e <= 271e6 ? 60 : 0);
  return StoredEnergy(
    joules: e,
    tntKg: tnt,
    distanceM: math.max(fixed, scaled),
    scaledM: scaled,
    beyondFixed: e > 271e6,
  );
}

/// 관 안 체적(L) = π/4 · 내경² · 길이.
double pipeVolumeL({required double idMm, required double lengthM}) =>
    math.pi / 4 * math.pow(idMm / 1000, 2) * lengthM * 1000;

class NitrogenNeed {
  final double nm3; // 필요한 질소(Nm³)
  final double perCylNm3; // 용기 1병에서 쓸 수 있는 양(Nm³)
  final int? cylinders; // null: 시험압력이 용기 압력 이상이라 용기만으로 못 채움
  const NitrogenNeed({
    required this.nm3,
    required this.perCylNm3,
    this.cylinders,
  });
}

/// 질소 필요량 ≈ 체적 × 절대 시험압력 ÷ 대기압(온도 영향 제외, 배관 안 공기까지 바꾼다고 봄).
/// 용기: 47L·150bar(가득 차면 약 7Nm³). 용기는 시험압력까지만 비울 수 있다고 보고
/// 1병에서 쓸 수 있는 양 = 47L × (150bar − 시험압력) ÷ 대기압.
NitrogenNeed nitrogenNeed({
  required double testKpa,
  required double volumeL,
  double cylL = 47,
  double cylKpa = 15000,
}) {
  final nm3 = volumeL / 1000 * (testKpa + kAtmKpa) / kAtmKpa;
  final usable = cylL / 1000 * (cylKpa - testKpa) / kAtmKpa;
  return NitrogenNeed(
    nm3: nm3,
    perCylNm3: usable > 0 ? usable : 0,
    cylinders: usable > 0 ? (nm3 / usable - 1e-9).ceil() : null,
  );
}

// ─────────────── 압축공기 에어 누설 ───────────────

/// 식이 맞는 최소 공급 압력(게이지 kPa). 초크 흐름 조건 P0abs ≥ 1.893 × 대기압.
const double kLeakMinKpa = 90;

/// 구멍 누설(대기압 기준 L/s, 20°C). 초크 흐름 Q ≈ 0.154·Cd·d²·P0abs(bar). 0.9barg 미만은 맞지 않는다.
double holeLeakLps({
  required double holeMm,
  required double supplyKpa,
  double cd = 0.97,
}) {
  final p0 = (supplyKpa + kAtmKpa) / 100; // bar abs
  return 0.154 * cd * holeMm * holeMm * p0;
}

/// 누설을 메우는 압축기 전력(kW). 100cfm당 18kW(DOE) = m³/min당 6.36kW.
double leakCompressorKw(double lps) => lps * 60 / 1000 * 6.36;

String _f(double v, [int d = 1]) {
  var s = v.toStringAsFixed(d);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}
