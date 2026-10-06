// 교류 역산·임피던스·케이블 온도·손실·변압기·콘덴서 전압 환산(10-03). 화면 없이 계산만 한다. 정의식과 교재 일반식이다.
library;

import 'dart:math' as math;

double _k(bool three) => three ? math.sqrt(3) : 1.0;

// ─────────────── 교류 전압·역률 구하기 ───────────────

/// 역률 cosφ = P ÷ S (P kW, S kVA). 1을 넘으면 null.
double? pfFromKwKva(double kw, double kva) {
  if (kw < 0 || kva <= 0) return null;
  final pf = kw / kva;
  return pf > 1 + 1e-9 ? null : pf;
}

/// 역률 cosφ = P ÷ (√3 × V × I) (삼상) 또는 P ÷ (V × I) (단상). P kW, V 전압, I 전류. 1을 넘으면 null.
double? pfFromKwVi({required double kw, required double volts, required double amps, required bool three}) {
  if (kw < 0 || volts <= 0 || amps <= 0) return null;
  final pf = kw * 1000 / (_k(three) * volts * amps);
  return pf > 1 + 1e-9 ? null : pf;
}

/// 전압 V = P ÷ (√3 × I × cosφ) (삼상, 선간) 또는 P ÷ (I × cosφ) (단상).
double? voltageFromKwIPf({required double kw, required double amps, required double pf, required bool three}) {
  if (kw <= 0 || amps <= 0 || pf <= 0 || pf > 1) return null;
  return kw * 1000 / (_k(three) * amps * pf);
}

/// 전압 V = S ÷ (√3 × I) (S kVA).
double? voltageFromKva({required double kva, required double amps, required bool three}) {
  if (kva <= 0 || amps <= 0) return null;
  return kva * 1000 / (_k(three) * amps);
}

// ─────────────── 임피던스 ───────────────

class Impedance {
  const Impedance({required this.z, required this.x, required this.pf, required this.angleDeg, this.amps});

  /// 임피던스 크기 Z = √(R² + X²) (Ω). X = XL − XC (직렬).
  final double z;

  /// 합성 리액턴스 X = XL − XC(Ω). 양수면 유도성, 음수면 용량성.
  final double x;

  /// 역률 cosφ = R ÷ Z.
  final double pf;

  /// 위상각 φ = atan(X ÷ R) (도). 양수면 전류가 전압보다 늦다.
  final double angleDeg;

  /// 전압을 줬을 때 전류 I = V ÷ Z (A).
  final double? amps;
}

/// 직렬 RLC 임피던스: [r] 저항, [xl] 유도 리액턴스, [xc] 용량 리액턴스(Ω). [volts]를 주면 전류도 구한다.
Impedance? seriesImpedance({required double r, double xl = 0, double xc = 0, double? volts}) {
  if (r < 0 || xl < 0 || xc < 0) return null;
  final x = xl - xc;
  final z = math.sqrt(r * r + x * x);
  if (z <= 0) return null;
  return Impedance(
    z: z,
    x: x,
    pf: r / z,
    angleDeg: math.atan2(x, r) * 180 / math.pi,
    amps: (volts == null || volts <= 0) ? null : volts / z,
  );
}

/// 유도 리액턴스 XL = 2πfL (L 헨리).
double inductiveX(double hz, double henry) => 2 * math.pi * hz * henry;

/// 용량 리액턴스 XC = 1 ÷ (2πfC) (C 패럿).
double? capacitiveX(double hz, double farad) {
  if (hz <= 0 || farad <= 0) return null;
  return 1 / (2 * math.pi * hz * farad);
}

// ─────────────── 케이블 도체 온도와 전력 손실 ───────────────

/// 도체 온도 근사 Tc = Ta + (Tmax − Ta) × (I ÷ Iz)². Iz는 그 조건의 보정 허용전류, Tmax는 절연체 최고 온도(70·90℃).
/// 허용전류에서는 최고 온도에 닿고, 전류가 반이면 온도 상승이 1/4이다(손실이 I²에 비례). 근사식이다.
double? cableConductorTemp({required double ambientC, required double maxC, required double current, required double iz}) {
  if (current < 0 || iz <= 0 || maxC <= ambientC) return null;
  return ambientC + (maxC - ambientC) * math.pow(current / iz, 2);
}

class CableLoss {
  const CableLoss({required this.watts, required this.perM, required this.pctOfPower, this.kwhYear});

  /// 전체 전력 손실(W) = 도체 수 × I² × R × L. 삼상 3, 단상·직류 2(왕복).
  final double watts;

  /// 1 m당 손실(W/m).
  final double perM;

  /// 전송 전력에 대한 손실 비(%). 전송 전력을 줬을 때만.
  final double? pctOfPower;

  /// 연간 손실 전력량(kWh). 연간 시간을 줬을 때만.
  final double? kwhYear;
}

/// 케이블 전력 손실. [rOhmPerKm]는 운전 온도에서의 도체 저항, [lengthM]은 편도 길이.
/// 삼상 3·I²·R·L, 단상·직류 2·I²·R·L(왕복). [powerKw]는 전송 전력(선택), [hoursYear]는 연간 운전 시간(선택).
CableLoss? cableLoss({
  required double current,
  required double rOhmPerKm,
  required double lengthM,
  required bool three,
  double? powerKw,
  double? hoursYear,
}) {
  if (current <= 0 || rOhmPerKm <= 0 || lengthM <= 0) return null;
  final n = three ? 3 : 2;
  final w = n * current * current * rOhmPerKm * (lengthM / 1000);
  return CableLoss(
    watts: w,
    perM: w / lengthM,
    pctOfPower: (powerKw == null || powerKw <= 0) ? null : w / (powerKw * 1000) * 100,
    kwhYear: (hoursYear == null || hoursYear <= 0) ? null : w * hoursYear / 1000,
  );
}

/// 케이블 임피던스(편도 길이 [lengthM]): R = r·L, X = x·L, Z = √(R² + X²) (Ω).
({double r, double x, double z})? cableImpedance({required double rOhmPerKm, required double xOhmPerKm, required double lengthM}) {
  if (rOhmPerKm <= 0 || xOhmPerKm < 0 || lengthM <= 0) return null;
  final r = rOhmPerKm * lengthM / 1000;
  final x = xOhmPerKm * lengthM / 1000;
  return (r: r, x: x, z: math.sqrt(r * r + x * x));
}

// ─────────────── 다른 전압에서의 콘덴서 출력 ───────────────

/// 콘덴서 출력은 전압의 제곱에 비례한다: Q = Qn × (V ÷ Vn)². 주파수가 다르면 × (f ÷ fn)도 곱한다(Q = 2πf·C·V²).
double? capacitorKvarAtVoltage({
  required double ratedKvar,
  required double ratedVolts,
  required double volts,
  double ratedHz = 60,
  double hz = 60,
}) {
  if (ratedKvar <= 0 || ratedVolts <= 0 || volts <= 0 || ratedHz <= 0 || hz <= 0) return null;
  final r = volts / ratedVolts;
  return ratedKvar * r * r * (hz / ratedHz);
}

// ─────────────── 변압기 역률 개선 ───────────────

class TransformerQ {
  const TransformerQ({required this.noLoadKvar, required this.leakKvar});

  /// 무부하(여자) 무효전력 ≈ S × i0%.
  final double noLoadKvar;

  /// 부하 때 누설 리액턴스가 쓰는 무효전력 ≈ S × usc% × (부하율)².
  final double leakKvar;
  double get totalKvar => noLoadKvar + leakKvar;
}

/// 변압기가 소비하는 무효전력 근사: Q ≈ S × (i0% + usc% × k²) ÷ 100. [kva] 정격 용량, [i0Pct] 무부하 전류(%),
/// [uscPct] 단락 전압(%), [loadFactor] 부하율 k(0~1). 저항분은 무시한 근사식이다.
TransformerQ? transformerReactive({
  required double kva,
  required double i0Pct,
  required double uscPct,
  required double loadFactor,
}) {
  if (kva <= 0 || i0Pct < 0 || uscPct < 0 || loadFactor < 0) return null;
  return TransformerQ(
    noLoadKvar: kva * i0Pct / 100,
    leakKvar: kva * uscPct / 100 * loadFactor * loadFactor,
  );
}

// ─────────────── 자동 차단 기준 최대 케이블 길이 ───────────────

/// 단락(지락) 전류가 보호장치 동작전류 [iaA] 이상이 되는 최대 케이블 길이(m).
/// 고장 루프 임피던스 Zs = Ze + ρ × L × (1 ÷ S상 + 1 ÷ S보호) ≤ U0 ÷ Ia 에서 L = (U0 ÷ Ia − Ze) ÷ (ρ × (1 ÷ S상 + 1 ÷ S보호)).
/// 리액턴스는 뺀 근사이고 큰 단면적에서는 과대 평가된다. ρ는 운전 온도를 반영한 구리 값(기본 0.0225 Ω·mm²/m).
double? maxLengthForTrip({
  required double u0,
  required double iaA,
  double ze = 0,
  required double phaseMm2,
  required double peMm2,
  double rho = 0.0225,
}) {
  if (u0 <= 0 || iaA <= 0 || ze < 0 || phaseMm2 <= 0 || peMm2 <= 0 || rho <= 0) return null;
  final zsMax = u0 / iaA;
  final rem = zsMax - ze;
  if (rem <= 0) return 0;
  return rem / (rho * (1 / phaseMm2 + 1 / peMm2));
}

/// Schneider Electrical Installation Guide ch.L 그림 L22(2007판 L21): 20 kV 1차 유입 변압기가 쓰는 무효전력(kvar).
/// 키는 정격 kVA, 값은 [무부하, 전부하(무부하분 포함)]. 원문 두 판이 일치한다.
const Map<int, List<double>> kTransformerL22 = {
  100: [2.5, 6.1],
  160: [3.7, 9.6],
  250: [5.3, 14.7],
  315: [6.3, 18.4],
  400: [7.6, 22.9],
  500: [9.5, 28.7],
  630: [11.3, 35.7],
  800: [20, 54.5],
  1000: [23.9, 72.4],
  1250: [27.4, 94.5],
  1600: [31.9, 126],
  2000: [37.8, 176],
};
