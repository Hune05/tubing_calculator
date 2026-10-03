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
