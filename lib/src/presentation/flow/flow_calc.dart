// 유량 계산(화면 없음): 유속·레이놀즈 수, 마찰 계수(Colebrook–White 반복 계산, 층류 64/Re),
// Darcy–Weisbach 압력손실, 피팅 K, 높이 차 ρgh, 이상기체 밀도, 차압 유량계(제곱근 환산·ISO 5167-2 오리피스).
// 숫자 자료(물 성질·거칠기·K·권장 유속)는 flow_data.dart. 근거는 docs/유량계산_근거.md.
library;

import 'dart:math' as math;

import 'flow_data.dart';

/// 표준 중력 가속도(m/s², CGPM 1901 표준값).
const double kG = 9.80665;

/// 표준 대기압(kPa). 게이지 압력 → 절대 압력에 더한다.
const double kAtmKpa = 101.325;

/// 1 psi = 6.894757293168361 kPa, 1 US gal = 3.785411784 L(정의값).
const double kPsiKpaFlow = 6.894757293168361;
const double kUsGalL = 3.785411784;

// ─────────────── 단위 ───────────────

/// 유량 단위. kg/h는 밀도로, Nm³/h는 기준 상태(0°C, 101.325kPa) 밀도로 부피 유량을 구한다.
enum FlowUnit { lpm, m3h, gpm, kgh, nm3h }

extension FlowUnitInfo on FlowUnit {
  String get label => switch (this) {
    FlowUnit.lpm => 'L/min',
    FlowUnit.m3h => 'm³/h',
    FlowUnit.gpm => 'GPM(US)',
    FlowUnit.kgh => 'kg/h',
    FlowUnit.nm3h => 'Nm³/h',
  };
}

/// 입력 유량 → 운전 상태 부피 유량(m³/s).
/// [rho] 운전 상태 밀도, [rhoNormal] 기준 상태 밀도(Nm³/h일 때만 필요).
double? flowToM3s(double v, FlowUnit u, {double? rho, double? rhoNormal}) =>
    switch (u) {
      FlowUnit.lpm => v / 1000 / 60,
      FlowUnit.m3h => v / 3600,
      FlowUnit.gpm => v * kUsGalL / 1000 / 60,
      FlowUnit.kgh => rho == null || rho <= 0 ? null : v / 3600 / rho,
      FlowUnit.nm3h =>
        rho == null || rhoNormal == null || rho <= 0
            ? null
            : v * rhoNormal / rho / 3600,
    };

/// 운전 상태 부피 유량(m³/s) → 단위 값.
double? m3sToFlow(double q, FlowUnit u, {double? rho, double? rhoNormal}) =>
    switch (u) {
      FlowUnit.lpm => q * 1000 * 60,
      FlowUnit.m3h => q * 3600,
      FlowUnit.gpm => q * 1000 * 60 / kUsGalL,
      FlowUnit.kgh => rho == null ? null : q * 3600 * rho,
      FlowUnit.nm3h =>
        rho == null || rhoNormal == null || rhoNormal <= 0
            ? null
            : q * rho / rhoNormal * 3600,
    };

/// 압력 입력 단위(게이지). kgf/cm² = 98.0665kPa(정의값).
enum GaugeUnit { bar, kpa, mpa, psi, kgf }

extension GaugeUnitInfo on GaugeUnit {
  String get label => switch (this) {
    GaugeUnit.bar => 'bar',
    GaugeUnit.kpa => 'kPa',
    GaugeUnit.mpa => 'MPa',
    GaugeUnit.psi => 'psi',
    GaugeUnit.kgf => 'kgf/cm²',
  };

  double get kpa => switch (this) {
    GaugeUnit.bar => 100,
    GaugeUnit.kpa => 1,
    GaugeUnit.mpa => 1000,
    GaugeUnit.psi => kPsiKpaFlow,
    GaugeUnit.kgf => 98.0665,
  };
}

/// 차압 단위. mmH₂O는 관용 단위(9.80665Pa, NIST SP 811).
enum DpUnit { kpa, mbar, bar, mmh2o, psi }

extension DpUnitInfo on DpUnit {
  String get label => switch (this) {
    DpUnit.kpa => 'kPa',
    DpUnit.mbar => 'mbar',
    DpUnit.bar => 'bar',
    DpUnit.mmh2o => 'mmH₂O',
    DpUnit.psi => 'psi',
  };

  double get kpa => switch (this) {
    DpUnit.kpa => 1,
    DpUnit.mbar => 0.1,
    DpUnit.bar => 100,
    DpUnit.mmh2o => 0.00980665,
    DpUnit.psi => kPsiKpaFlow,
  };
}

// ─────────────── 유체 성질 ───────────────

/// 유체 한 상태의 밀도(kg/m³)·점도(Pa·s).
class FluidState {
  final double rho;
  final double mu;

  /// 기체일 때 입구 절대 압력(kPa). 액체는 null.
  final double? pAbsKpa;

  /// 기체일 때 기준 상태(0°C, 101.325kPa) 밀도. 액체는 null.
  final double? rhoNormal;

  const FluidState({
    required this.rho,
    required this.mu,
    this.pAbsKpa,
    this.rhoNormal,
  });

  bool get gas => pAbsKpa != null;

  /// 동점도(m²/s).
  double get nu => mu / rho;
}

/// 표 [rows]의 (x, y)를 직선 보간. 범위 밖이면 null.
double? interp(List<(double, double)> rows, double x) {
  if (x < rows.first.$1 - 1e-9 || x > rows.last.$1 + 1e-9) return null;
  for (var i = 0; i < rows.length - 1; i++) {
    final a = rows[i], b = rows[i + 1];
    if (x <= b.$1 + 1e-12) {
      return a.$2 + (b.$2 - a.$2) * (x - a.$1) / (b.$1 - a.$1);
    }
  }
  return rows.last.$2;
}

/// 물(1기압) 밀도·점도. [tC]가 표 범위 밖이면 null.
FluidState? waterState(double tC) {
  final rho = interp([for (final r in kWaterTable) (r.$1, r.$2)], tC);
  final mu = interp([for (final r in kWaterTable) (r.$1, r.$3)], tC);
  if (rho == null || mu == null) return null;
  return FluidState(rho: rho, mu: mu / 1000);
}

/// 이상기체 밀도(kg/m³) = P·M / (R·T). [pAbsKpa] 절대 압력, [molarMass] g/mol.
double idealGasDensity(double pAbsKpa, double tC, double molarMass) =>
    pAbsKpa * 1000 * (molarMass / 1000) / (kGasR * (tC + 273.15));

/// Sutherland 식 점도(Pa·s) = μ0·(T/T0)^1.5·(T0 + S)/(T + S).
double sutherlandMu(GasData g, double tC) {
  final t = tC + 273.15;
  return g.mu0 * math.pow(t / g.t0, 1.5) * (g.t0 + g.s) / (t + g.s);
}

/// 공기·질소 운전 상태. [pGaugeKpa] 게이지 압력, [tC] 온도. 온도가 식 적용 범위 밖이거나
/// 절대 압력이 0 이하이면 null.
FluidState? gasState(GasData g, double pGaugeKpa, double tC) {
  final pAbs = pGaugeKpa + kAtmKpa;
  if (pAbs <= 0) return null;
  if (tC < kGasMinC - 1e-9 || tC > kGasMaxC + 1e-9) return null;
  return FluidState(
    rho: idealGasDensity(pAbs, tC, g.molarMass),
    mu: sutherlandMu(g, tC),
    pAbsKpa: pAbs,
    rhoNormal: idealGasDensity(kAtmKpa, 0, g.molarMass),
  );
}

/// 기름: 밀도(kg/m³)·동점도(cSt = mm²/s)를 직접 넣는다.
FluidState? oilState(double rho, double cSt) {
  if (rho <= 0 || cSt <= 0) return null;
  return FluidState(rho: rho, mu: cSt * 1e-6 * rho);
}

// ─────────────── 유속·레이놀즈 수 ───────────────

/// 원 단면적(m²). [idMm] 내경.
double areaM2(double idMm) => math.pi / 4 * math.pow(idMm / 1000, 2);

/// 평균 유속(m/s).
double velocity(double qM3s, double idMm) => qM3s / areaM2(idMm);

/// 레이놀즈 수 Re = ρ·v·D/μ.
double reynolds(double v, double idMm, FluidState f) =>
    f.rho * v * (idMm / 1000) / f.mu;

enum FlowRegime { laminar, transition, turbulent }

/// Re < 2300 층류, 2300~4000 천이, 4000 이상 난류.
FlowRegime regimeOf(double re) => re < kReLaminar
    ? FlowRegime.laminar
    : (re < kReTurbulent ? FlowRegime.transition : FlowRegime.turbulent);

extension FlowRegimeLabel on FlowRegime {
  String get label => switch (this) {
    FlowRegime.laminar => '층류',
    FlowRegime.transition => '천이 구간',
    FlowRegime.turbulent => '난류',
  };
}

/// 권장 유속을 만족하는 최소 내경(mm): v ≤ [vMax].
double minIdForVelocity(double qM3s, double vMax) =>
    math.sqrt(4 * qM3s / (math.pi * vMax)) * 1000;

// ─────────────── 마찰 계수 ───────────────

/// Swamee–Jain(1976) 명시식: f = 0.25 / [log10(ε/3.7D + 5.74/Re^0.9)]².
double swameeJain(double re, double relRough) =>
    0.25 /
    math.pow(
      math.log(relRough / 3.7 + 5.74 / math.pow(re, 0.9)) / math.ln10,
      2,
    );

/// Colebrook–White: 1/√f = −2·log10(ε/3.7D + 2.51/(Re·√f)). Swamee–Jain 값에서 시작해 반복한다.
double colebrook(double re, double relRough) {
  var x = 1 / math.sqrt(swameeJain(re, relRough)); // x = 1/√f
  for (var i = 0; i < 100; i++) {
    final nx = -2 * math.log(relRough / 3.7 + 2.51 * x / re) / math.ln10;
    if ((nx - x).abs() < 1e-12) {
      x = nx;
      break;
    }
    x = nx;
  }
  return 1 / (x * x);
}

/// Darcy 마찰 계수: 층류(Re < 2300) 64/Re, 그 밖은 Colebrook–White.
double darcyF(double re, double relRough) =>
    re < kReLaminar ? 64 / re : colebrook(re, relRough);

// ─────────────── 압력손실 ───────────────

class PressureDrop {
  final double v; // m/s
  final double re;
  final FlowRegime regime;
  final double f; // Darcy
  final double sumK; // 피팅·밸브 K 합
  final double straightKpa;
  final double fittingKpa;
  final double elevKpa; // 올라가면 +, 내려가면 −
  final double per100mKpa; // 직관 100m당

  const PressureDrop({
    required this.v,
    required this.re,
    required this.regime,
    required this.f,
    required this.sumK,
    required this.straightKpa,
    required this.fittingKpa,
    required this.elevKpa,
    required this.per100mKpa,
  });

  double get totalKpa => straightKpa + fittingKpa + elevKpa;

  /// 동압 ρv²/2(kPa).
  double dynKpa(double rho) => rho * v * v / 2 / 1000;
}

/// 피팅 한 종류와 개수.
typedef FittingCount = (FittingData, int);

/// 피팅 K 합(3-K 식). [re] 관 레이놀즈 수, [dnInch] 호칭 지름(인치), [extraK] 직접 넣은 K 합.
double sumFittingK(
  double re,
  double dnInch,
  List<FittingCount> items, {
  double extraK = 0,
}) {
  var k = extraK;
  for (final (fit, n) in items) {
    if (n > 0) k += n * fit.k(re, dnInch);
  }
  return k;
}

/// 호칭 글 → 인치: '1-1/4' → 1.25, '1/2' → 0.5, '2' → 2. 읽지 못하면 null.
double? nominalInch(String b) {
  final mixed = RegExp(r'^(\d+)(?:-(\d+)/(\d+))?$').firstMatch(b);
  if (mixed != null) {
    final whole = double.parse(mixed.group(1)!);
    if (mixed.group(2) == null) return whole;
    return whole +
        double.parse(mixed.group(2)!) / double.parse(mixed.group(3)!);
  }
  final frac = RegExp(r'^(\d+)/(\d+)$').firstMatch(b);
  if (frac == null) return null;
  return double.parse(frac.group(1)!) / double.parse(frac.group(2)!);
}

/// Darcy–Weisbach 압력손실. [lengthM] 직관 길이, [roughMm] 절대 거칠기, [dzM] 높이 차(출구가 높으면 +).
/// 피팅은 [fittings]와 [dnInch](3-K 식의 호칭 지름, 없으면 내경 인치)로 K를 구하고 [extraK]를 더한다.
PressureDrop pressureDrop({
  required double qM3s,
  required double idMm,
  required FluidState fluid,
  required double lengthM,
  required double roughMm,
  List<FittingCount> fittings = const [],
  double? dnInch,
  double extraK = 0,
  double dzM = 0,
}) {
  final v = velocity(qM3s, idMm);
  final re = reynolds(v, idMm, fluid);
  final sumK = sumFittingK(re, dnInch ?? idMm / 25.4, fittings, extraK: extraK);
  final f = darcyF(re, roughMm / idMm);
  final dyn = fluid.rho * v * v / 2; // Pa
  final perM = f / (idMm / 1000) * dyn; // Pa/m
  return PressureDrop(
    v: v,
    re: re,
    regime: regimeOf(re),
    f: f,
    sumK: sumK,
    straightKpa: perM * lengthM / 1000,
    fittingKpa: sumK * dyn / 1000,
    elevKpa: fluid.rho * kG * dzM / 1000,
    per100mKpa: perM * 100 / 1000,
  );
}

/// 기체 압력손실 판정(Crane TP-410): 입구 절대 압력 대비 ΔP 비율.
enum GasDropCheck { ok, useAverage, invalid }

GasDropCheck gasDropCheck(double dpKpa, double pAbsKpa) {
  final r = dpKpa / pAbsKpa;
  if (r < kGasDpOk) return GasDropCheck.ok;
  if (r <= kGasDpAvg) return GasDropCheck.useAverage;
  return GasDropCheck.invalid;
}

// ─────────────── 차압 유량계 ───────────────

/// 차압 → 유량: Q = Qmax·√(ΔP/ΔPmax). ΔP가 0 이하이면 0.
double dpToFlow(double dp, double dpMax, double qMax) =>
    dp <= 0 ? 0 : qMax * math.sqrt(dp / dpMax);

/// 유량 → 차압: ΔP = ΔPmax·(Q/Qmax)².
double flowToDp(double q, double dpMax, double qMax) =>
    q <= 0 ? 0 : dpMax * math.pow(q / qMax, 2);

/// ISO 5167-2 탭 위치.
enum OrificeTap { corner, dd2, flange }

extension OrificeTapLabel on OrificeTap {
  String get label => switch (this) {
    OrificeTap.corner => '코너 탭',
    OrificeTap.dd2 => 'D·D/2 탭',
    OrificeTap.flange => '플랜지 탭',
  };
}

/// Reader-Harris/Gallagher(1998) 유출 계수(ISO 5167-2:2003 5.3.2.1 식 (4)).
/// [dPipeMm] 관 내경 D, [beta] d/D, [reD] 관 기준 레이놀즈 수.
double rhgC(double beta, double reD, double dPipeMm, OrificeTap tap) {
  final (l1, l2) = switch (tap) {
    OrificeTap.corner => (0.0, 0.0),
    OrificeTap.dd2 => (1.0, 0.47),
    OrificeTap.flange => (25.4 / dPipeMm, 25.4 / dPipeMm),
  };
  final a = math.pow(19000 * beta / reD, 0.8).toDouble();
  final m2 = 2 * l2 / (1 - beta);
  final b4 = math.pow(beta, 4).toDouble();
  var c =
      0.5961 +
      0.0261 * beta * beta -
      0.216 * math.pow(beta, 8) +
      0.000521 * math.pow(1e6 * beta / reD, 0.7) +
      (0.0188 + 0.0063 * a) * math.pow(beta, 3.5) * math.pow(1e6 / reD, 0.3) +
      (0.043 + 0.080 * math.exp(-10 * l1) - 0.123 * math.exp(-7 * l1)) *
          (1 - 0.11 * a) *
          b4 /
          (1 - b4) -
      0.031 * (m2 - 0.8 * math.pow(m2, 1.1)) * math.pow(beta, 1.3);
  if (dPipeMm < 71.12) c += 0.011 * (0.75 - beta) * (2.8 - dPipeMm / 25.4);
  return c;
}

class OrificeResult {
  final double beta;
  final double c;
  final double reD;
  final double qmKgS;
  final double qM3s;
  final double lossKpa; // 영구 압력손실(ISO 5167-2 5.4)
  final List<String> outOfRange; // ISO 5167-2 5.3.1 적용 한계를 벗어난 항목
  final double? uncertaintyPct; // C 불확도(5.3.3.1). 확인한 조건 밖이면 null

  const OrificeResult({
    required this.beta,
    required this.c,
    required this.reD,
    required this.qmKgS,
    required this.qM3s,
    required this.lossKpa,
    required this.outOfRange,
    required this.uncertaintyPct,
  });
}

/// 액체 오리피스 유량(ε = 1). qm = C/√(1−β⁴)·π/4·d²·√(2·ΔP·ρ). C가 Re에 따라 바뀌므로 반복한다.
/// β·D·d가 계산할 수 없는 값이면 null.
OrificeResult? orificeFlow({
  required double dPipeMm,
  required double dBoreMm,
  required double dpKpa,
  required FluidState fluid,
  required OrificeTap tap,
}) {
  if (dPipeMm <= 0 || dBoreMm <= 0 || dBoreMm >= dPipeMm || dpKpa <= 0) {
    return null;
  }
  final beta = dBoreMm / dPipeMm;
  final b4 = math.pow(beta, 4).toDouble();
  final d = dBoreMm / 1000;
  final dp = dpKpa * 1000;
  final k =
      math.pi / 4 * d * d * math.sqrt(2 * dp * fluid.rho) / math.sqrt(1 - b4);
  var c = 0.6;
  var qm = c * k;
  var re = 4 * qm / (math.pi * fluid.mu * dPipeMm / 1000);
  for (var i = 0; i < 100; i++) {
    final nc = rhgC(beta, re, dPipeMm, tap);
    final done = (nc - c).abs() < 1e-12;
    c = nc;
    qm = c * k;
    re = 4 * qm / (math.pi * fluid.mu * dPipeMm / 1000);
    if (done) break;
  }
  // 영구 압력손실 Δϖ = (√(1−β⁴(1−C²)) − Cβ²)/(√(1−β⁴(1−C²)) + Cβ²)·ΔP.
  final s = math.sqrt(1 - b4 * (1 - c * c));
  final loss = (s - c * beta * beta) / (s + c * beta * beta) * dpKpa;
  final out = <String>[
    if (dBoreMm < 12.5) 'd ≥ 12.5mm',
    if (dPipeMm < 50 || dPipeMm > 1000) '50mm ≤ D ≤ 1000mm',
    if (beta < 0.1 || beta > 0.75) '0.1 ≤ β ≤ 0.75',
    ..._reLimits(beta, re, dPipeMm, tap),
  ];
  return OrificeResult(
    beta: beta,
    c: c,
    reD: re,
    qmKgS: qm,
    qM3s: qm / fluid.rho,
    lossKpa: loss,
    outOfRange: out,
    uncertaintyPct: _cUncertainty(beta, re, dPipeMm),
  );
}

List<String> _reLimits(double beta, double re, double dMm, OrificeTap tap) {
  if (tap == OrificeTap.flange) {
    return [
      if (re < 5000) 'ReD ≥ 5000',
      if (re < 170 * beta * beta * dMm) 'ReD ≥ 170β²D',
    ];
  }
  return [
    if (beta <= 0.56 && re < 5000) 'ReD ≥ 5000',
    if (beta > 0.56 && re < 16000 * beta * beta) 'ReD ≥ 16000β²',
  ];
}

/// C의 상대 불확도(%, ISO 5167-2 5.3.3.1): 0.2 ≤ β ≤ 0.6은 0.5, 0.6 < β ≤ 0.75는 (1.667β − 0.5).
/// 두 출처에서 확인한 이 두 경우만 보인다. β < 0.2, D < 71.12mm, β > 0.5이면서 ReD < 10000은 더하는 값을
/// 한 출처에서만 확인해 null(화면에 보이지 않음).
double? _cUncertainty(double beta, double re, double dMm) {
  if (beta < 0.2 || beta > 0.75 || dMm < 71.12) return null;
  if (beta > 0.5 && re < 10000) return null;
  return beta <= 0.6 ? 0.5 : 1.667 * beta - 0.5;
}
