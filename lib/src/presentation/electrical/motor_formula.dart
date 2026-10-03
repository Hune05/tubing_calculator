// 전동기 필수 공식(10-03): 속도·슬립, 전류·효율, 토크·출력, 기동 방식, 부하율. 화면 없이 계산만 한다.
// 모두 정의식·교재에 나오는 일반식이라 표 값이 필요 없다. 명판 값(효율·역률·정격전류)은 사용자가 넣는다.
library;

import 'dart:math' as math;

import 'elec_calc.dart' show Phase, loadCurrent;

// ─────────────── 속도·슬립 ───────────────

/// 동기속도 Ns = 120 × f ÷ P (rpm). [poles]는 극수(2 이상 짝수).
double? motorSyncRpm(double hz, int poles) {
  if (hz <= 0 || poles < 2 || poles.isOdd) return null;
  return 120 * hz / poles;
}

/// 슬립 s = (Ns − N) ÷ Ns (0~1 소수).
double? motorSlip(double syncRpm, double rpm) {
  if (syncRpm <= 0 || rpm < 0) return null;
  return (syncRpm - rpm) / syncRpm;
}

/// 회전수 N = (1 − s) × Ns.
double motorRpmFromSlip(double syncRpm, double slip) => (1 - slip) * syncRpm;

/// 회전자 전류 주파수 f2 = s × f.
double rotorHz(double hz, double slip) => slip * hz;

// ─────────────── 전류·효율 ───────────────

/// 축 출력 [kw]·전압·효율·역률로 정격전류와 입력을 구한다.
class MotorElectrical {
  const MotorElectrical({
    required this.current,
    required this.inputKw,
    required this.apparentKva,
    required this.lossKw,
  });

  /// 정격전류 I (A).
  final double current;

  /// 입력 전력 P1 = P ÷ η (kW).
  final double inputKw;

  /// 피상전력 S (kVA).
  final double apparentKva;

  /// 손실 = P1 − P (kW).
  final double lossKw;
}

/// 출력 [kw] → 정격전류. [eff]·[pf]는 0~1. 삼상이면 √3을 쓴다.
MotorElectrical? motorElectrical({
  required double kw,
  required double volts,
  required double eff,
  required double pf,
  required bool three,
}) {
  if (kw <= 0 || volts <= 0 || eff <= 0 || eff > 1 || pf <= 0 || pf > 1) {
    return null;
  }
  final i = loadCurrent(
    kw: kw,
    volts: volts,
    phase: three ? Phase.three : Phase.single,
    pf: pf,
    eff: eff,
  );
  final p1 = kw / eff;
  return MotorElectrical(
    current: i,
    inputKw: p1,
    apparentKva: p1 / pf,
    lossKw: p1 - kw,
  );
}

// ─────────────── 토크·출력 ───────────────

/// 토크 T[N·m] = 9549.3 × P[kW] ÷ N[rpm] (= P ÷ ω, ω = 2πN/60).
double? motorTorqueNm(double kw, double rpm) {
  if (kw <= 0 || rpm <= 0) return null;
  return kw * 1000 * 60 / (2 * math.pi * rpm);
}

/// 출력 P[kW] = T[N·m] × N[rpm] ÷ 9549.3.
double? motorPowerKw(double torqueNm, double rpm) {
  if (torqueNm <= 0 || rpm <= 0) return null;
  return torqueNm * 2 * math.pi * rpm / 60 / 1000;
}

/// N·m → kgf·m.
double nmToKgfM(double nm) => nm / 9.80665;

// ─────────────── 기동 방식 ───────────────

enum StartKind { direct, starDelta, autoTransformer, reactor }

/// 기동 결과: 전원 쪽 기동전류와, 직입 기동에 대한 기동 토크 비.
class MotorStart {
  const MotorStart({
    required this.lineAmps,
    required this.currentRatio,
    required this.torqueRatio,
  });

  /// 전원 쪽(선로) 기동전류(A).
  final double lineAmps;

  /// 직입 기동전류에 대한 비(0~1).
  final double currentRatio;

  /// 직입 기동 토크에 대한 비(0~1).
  final double torqueRatio;
}

/// 기동 방식별 전원 쪽 기동전류와 토크 비. 직입 기동전류 = [multiple] × [ratedAmps].
/// [tap]은 기동보상기·리액터로 전동기 단자에 걸리는 전압 비(0~1, 65 % → 0.65).
/// - 직입: 전류 1, 토크 1
/// - Y-Δ: 전류 1/3, 토크 1/3
/// - 기동보상기: 전동기 전류 tap, 전원 쪽 전류 tap², 토크 tap²
/// - 리액터: 전원 쪽 전류 = 전동기 전류 = tap, 토크 tap²
MotorStart? motorStart({
  required double ratedAmps,
  required double multiple,
  required StartKind kind,
  double tap = 1,
}) {
  if (ratedAmps <= 0 || multiple <= 0) return null;
  final direct = ratedAmps * multiple;
  final needTap =
      kind == StartKind.autoTransformer || kind == StartKind.reactor;
  if (needTap && !(tap > 0 && tap < 1)) return null;
  final (ci, ti) = switch (kind) {
    StartKind.direct => (1.0, 1.0),
    StartKind.starDelta => (1 / 3, 1 / 3),
    StartKind.autoTransformer => (tap * tap, tap * tap),
    StartKind.reactor => (tap, tap * tap),
  };
  return MotorStart(
    lineAmps: direct * ci,
    currentRatio: ci,
    torqueRatio: ti,
  );
}

// ─────────────── 부하율·실제 출력 ───────────────

class MotorLoad {
  const MotorLoad({
    required this.loadPct,
    required this.inputKw,
    this.outputKw,
  });

  /// 전류 부하율(%) = 측정 전류 ÷ 정격전류 × 100.
  final double loadPct;

  /// 입력 전력(kW) = √3 × V × I × cosφ (단상은 V × I × cosφ).
  final double inputKw;

  /// 효율을 알면 축 출력(kW) = 입력 × 효율.
  final double? outputKw;
}

/// 측정 전류로 부하율과 입력 전력을 구한다. [eff]를 주면 축 출력도 낸다(부분 부하 효율은 정격과 다를 수 있다).
MotorLoad? motorLoad({
  required double measuredAmps,
  required double ratedAmps,
  required double volts,
  required double pf,
  required bool three,
  double? eff,
}) {
  if (measuredAmps <= 0 || ratedAmps <= 0 || volts <= 0) return null;
  if (pf <= 0 || pf > 1) return null;
  if (eff != null && (eff <= 0 || eff > 1)) return null;
  final k = three ? math.sqrt(3) : 1.0;
  final pin = k * volts * measuredAmps * pf / 1000;
  return MotorLoad(
    loadPct: measuredAmps / ratedAmps * 100,
    inputKw: pin,
    outputKw: eff == null ? null : pin * eff,
  );
}

// ─────────────── 전압·역률 구하기 ───────────────

/// 전압 V = P ÷ (√3 × I × η × cosφ). 출력 [kw]는 축 출력, 입력 전력을 알면 [eff]에 1을 넣는다.
double? motorVoltage({
  required double kw,
  required double amps,
  required double eff,
  required double pf,
  required bool three,
}) {
  if (kw <= 0 || amps <= 0 || eff <= 0 || eff > 1 || pf <= 0 || pf > 1) {
    return null;
  }
  final k = three ? math.sqrt(3) : 1.0;
  return kw * 1000 / (k * amps * eff * pf);
}

/// 역률 cosφ = P ÷ (√3 × V × I × η). 1을 넘으면 입력값이 서로 맞지 않는 것이라 null.
double? motorPowerFactor({
  required double kw,
  required double volts,
  required double amps,
  required double eff,
  required bool three,
}) {
  if (kw <= 0 || volts <= 0 || amps <= 0 || eff <= 0 || eff > 1) return null;
  final k = three ? math.sqrt(3) : 1.0;
  final pf = kw * 1000 / (k * volts * amps * eff);
  return pf > 1 + 1e-9 ? null : pf;
}

// ─────────────── 펌프·팬 소요 동력 ───────────────

class LoadPower {
  const LoadPower({
    required this.hydraulicKw,
    required this.shaftKw,
    required this.motorKw,
  });

  /// 유체가 받는 동력(수동력·공기동력, kW).
  final double hydraulicKw;

  /// 펌프·팬 축동력 = 유체 동력 ÷ 펌프(팬) 효율 (kW).
  final double shaftKw;

  /// 전동기 소요 출력 = 축동력 × (1 + 여유율) ÷ 전달 효율 (kW). 표준 정격으로 올림해서 고른다.
  final double motorKw;
}

/// 펌프: 수동력 P = ρ·g·Q·H ÷ 1000 (Q m³/s). [flowM3h]는 m³/h, [headM]은 전양정(m), [density]는 kg/m³.
/// [pumpEff]는 펌프 효율, [margin]은 여유율(0.1 = 10 %), [driveEff]는 커플링·벨트 전달 효율(직결 1).
LoadPower? pumpPower({
  required double flowM3h,
  required double headM,
  double density = 1000,
  required double pumpEff,
  double margin = 0,
  double driveEff = 1,
}) {
  if (flowM3h <= 0 || headM <= 0 || density <= 0) return null;
  if (pumpEff <= 0 || pumpEff > 1 || driveEff <= 0 || driveEff > 1) return null;
  if (margin < 0) return null;
  final hyd = density * 9.80665 * (flowM3h / 3600) * headM / 1000;
  final shaft = hyd / pumpEff;
  return LoadPower(
    hydraulicKw: hyd,
    shaftKw: shaft,
    motorKw: shaft * (1 + margin) / driveEff,
  );
}

/// 팬·블로어: 공기동력 P = Q × Δp ÷ 1000 (Q m³/s, Δp Pa).
LoadPower? fanPower({
  required double flowM3h,
  required double pressurePa,
  required double fanEff,
  double margin = 0,
  double driveEff = 1,
}) {
  if (flowM3h <= 0 || pressurePa <= 0) return null;
  if (fanEff <= 0 || fanEff > 1 || driveEff <= 0 || driveEff > 1) return null;
  if (margin < 0) return null;
  final air = (flowM3h / 3600) * pressurePa / 1000;
  final shaft = air / fanEff;
  return LoadPower(
    hydraulicKw: air,
    shaftKw: shaft,
    motorKw: shaft * (1 + margin) / driveEff,
  );
}

/// 표준 목록에서 [kw] 이상인 가장 작은 값. 없으면 null.
double? roundUpToList(double kw, List<double> list) {
  for (final x in list) {
    if (x >= kw - 1e-9) return x;
  }
  return null;
}

// ─────────────── 상사법칙 ───────────────

class Affinity {
  const Affinity({required this.ratio, required this.flow, required this.head, required this.power});

  /// 속도비 N2 ÷ N1.
  final double ratio;

  /// 새 유량·양정·동력(입력한 기준값에 비를 곱한 것).
  final double? flow;
  final double? head;
  final double? power;
}

/// 상사법칙: 유량 Q2 = Q1 × r, 양정 H2 = H1 × r², 동력 P2 = P1 × r³ (r = N2 ÷ N1).
/// 양정이 대부분 정적 양정이거나 배관 저항이 일정하지 않으면 어긋난다.
Affinity? affinity({
  required double n1,
  required double n2,
  double? q1,
  double? h1,
  double? p1,
}) {
  if (n1 <= 0 || n2 <= 0) return null;
  final r = n2 / n1;
  return Affinity(
    ratio: r,
    flow: q1 == null ? null : q1 * r,
    head: h1 == null ? null : h1 * r * r,
    power: p1 == null ? null : p1 * r * r * r,
  );
}

// ─────────────── 가속(기동) 시간 ───────────────

/// 환산 관성: 전동기 축으로 옮긴 부하 관성 J = J부하 × (N부하 ÷ N전동기)² (kg·m²).
double reflectedInertia(double loadJ, double loadRpm, double motorRpm) =>
    loadJ * (loadRpm / motorRpm) * (loadRpm / motorRpm);

/// GD²(kgf·m²) → J(kg·m²) = GD² ÷ 4.
double gd2ToJ(double gd2) => gd2 / 4;

class AccelResult {
  const AccelResult({required this.seconds, required this.totalJ, required this.accelTorqueNm});

  /// 가속 시간(초) = J × ω ÷ T가속.
  final double seconds;

  /// 전동기 축 기준 총 관성(kg·m²).
  final double totalJ;

  /// 평균 가속 토크 = 전동기 평균 토크 − 부하 평균 토크 (N·m).
  final double accelTorqueNm;
}

/// 정지에서 정격 속도 [rpm]까지 가속하는 시간. [totalJ]는 전동기 + 환산한 부하 관성(kg·m²).
/// [motorAvgNm]·[loadAvgNm]은 기동 구간 평균 토크(N·m). 가속 토크가 0 이하면 기동하지 못하므로 null.
AccelResult? accelTime({
  required double totalJ,
  required double rpm,
  required double motorAvgNm,
  required double loadAvgNm,
}) {
  if (totalJ <= 0 || rpm <= 0 || motorAvgNm <= 0 || loadAvgNm < 0) return null;
  final ta = motorAvgNm - loadAvgNm;
  if (ta <= 0) return null;
  final w = 2 * math.pi * rpm / 60;
  return AccelResult(seconds: totalJ * w / ta, totalJ: totalJ, accelTorqueNm: ta);
}
