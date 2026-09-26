// 4-20mA 계산(화면 없음). 근거는 docs/4-20mA계산기_근거.md.
//
// mA ↔ % ↔ 측정값 환산(선형, 차압 유량의 제곱근), NAMUR NE43 신호 상태, 교정 점검(기준값 대비
// 스팬 % 오차와 허용 오차 판정), 루프 전압(전원 − 전류 × 루프 저항 ≥ 계기 최소 전압).
library;

import 'dart:math' as math;

const double kMaLow = 4;
const double kMaHigh = 20;
const double kMaSpan = kMaHigh - kMaLow;

/// mA와 측정값의 관계.
/// [linear]: mA가 측정값에 비례. [sqrt]: mA는 차압에 비례하고 측정값은 유량(유량 = √차압).
enum Transfer { linear, sqrt }

/// 출력 %(0~100, 범위 밖도 셈) → mA.
double maFromPct(double pct) => kMaLow + kMaSpan * pct / 100;

/// mA → 출력 %.
double pctFromMa(double ma) => (ma - kMaLow) / kMaSpan * 100;

/// 측정값 → 측정 범위 %.
double pvToPct(double pv, double lrv, double urv) =>
    (pv - lrv) / (urv - lrv) * 100;

/// 측정 범위 % → 측정값.
double pctToPv(double pct, double lrv, double urv) =>
    lrv + (urv - lrv) * pct / 100;

/// 측정 % → 출력 %. 제곱근: 출력(차압) % = (유량 %)² / 100.
double outPctFromPvPct(double pvPct, Transfer t) =>
    t == Transfer.linear ? pvPct : (pvPct <= 0 ? 0 : pvPct * pvPct / 100);

/// 출력 % → 측정 %. 제곱근: 유량 % = 10 × √(차압 %). 0 아래는 0.
double pvPctFromOutPct(double outPct, Transfer t) =>
    t == Transfer.linear ? outPct : (outPct <= 0 ? 0 : 10 * math.sqrt(outPct));

/// 측정값 → 이론 mA.
double idealMa(double pv, double lrv, double urv, Transfer t) =>
    maFromPct(outPctFromPvPct(pvToPct(pv, lrv, urv), t));

/// mA → 측정값.
double pvFromMa(double ma, double lrv, double urv, Transfer t) =>
    pctToPv(pvPctFromOutPct(pctFromMa(ma), t), lrv, urv);

/// 전류가 어느 구간인지 — NAMUR NE43.
enum SignalState {
  failLow, // 3.6 이하: 고장 신호(낮음)
  gapLow, // 3.6 ~ 3.8: 정해지지 않은 구간
  underRange, // 3.8 ~ 4: 0% 아래지만 측정은 맞음
  normal, // 4 ~ 20
  overRange, // 20 ~ 20.5: 100% 위지만 측정은 맞음
  gapHigh, // 20.5 ~ 21
  failHigh, // 21 이상: 고장 신호(높음)
}

SignalState signalState(double ma) {
  if (ma <= 3.6) return SignalState.failLow;
  if (ma < 3.8) return SignalState.gapLow;
  if (ma < kMaLow) return SignalState.underRange;
  if (ma <= kMaHigh) return SignalState.normal;
  if (ma <= 20.5) return SignalState.overRange;
  if (ma < 21) return SignalState.gapHigh;
  return SignalState.failHigh;
}

// ─────────────── 교정 점검 ───────────────

/// 읽은 값이 무엇인지. [ma]: 계기 출력 전류(교정기·멀티미터). [pv]: 지시값(DCS·지시계, 측정값 단위).
enum ReadKind { ma, pv }

class CalPoint {
  final double applied; // 넣은 값(기준기로 가한 측정값)
  final double reading; // 읽은 값
  final double idealMa; // 넣은 값에 맞는 이론 mA
  final double errPct; // 오차(스팬 %): mA면 16mA 대비, 지시값이면 측정 범위 대비
  final double errMa; // 오차(mA) — 지시값이고 제곱근이면 0에서 멀수록 맞지 않아 NaN
  final double errPv; // 오차(측정값 단위)
  final bool? pass; // 허용 오차를 넣었을 때만
  const CalPoint({
    required this.applied,
    required this.reading,
    required this.idealMa,
    required this.errPct,
    required this.errMa,
    required this.errPv,
    required this.pass,
  });
}

/// 한 점 점검. [tolPct] 허용 오차(± 스팬 %), 없으면 판정 안 함.
CalPoint checkPoint({
  required double applied,
  required double reading,
  required ReadKind kind,
  required double lrv,
  required double urv,
  Transfer transfer = Transfer.linear,
  double? tolPct,
}) {
  final ideal = idealMa(applied, lrv, urv, transfer);
  final double errPct, errMa, errPv;
  if (kind == ReadKind.ma) {
    errMa = reading - ideal;
    errPct = errMa / kMaSpan * 100;
    errPv = pvFromMa(reading, lrv, urv, transfer) - applied;
  } else {
    errPv = reading - applied;
    errPct = errPv / (urv - lrv) * 100;
    errMa = transfer == Transfer.linear ? errPct / 100 * kMaSpan : double.nan;
  }
  return CalPoint(
    applied: applied,
    reading: reading,
    idealMa: ideal,
    errPct: errPct,
    errMa: errMa,
    errPv: errPv,
    pass: tolPct == null ? null : errPct.abs() <= tolPct + 1e-9,
  );
}

// ─────────────── 루프 전압 ───────────────

class LoopCheck {
  final double totalOhm; // 루프 저항 합
  final double volts20; // 20mA일 때 계기 단자 전압
  final double volts21; // 21mA(NE43 고장 신호)일 때
  final double maxOhm21; // 21mA까지 낼 수 있는 최대 루프 저항
  const LoopCheck({
    required this.totalOhm,
    required this.volts20,
    required this.volts21,
    required this.maxOhm21,
  });
  bool okAt20(double minV) => volts20 >= minV - 1e-9;
  bool okAt21(double minV) => volts21 >= minV - 1e-9;
}

/// [supplyV] 전원, [minV] 계기 최소 전압(사양서), [ohms] 루프에 든 저항들(Ω).
LoopCheck loopCheck({
  required double supplyV,
  required double minV,
  required List<double> ohms,
}) {
  final r = ohms.fold<double>(0, (a, b) => a + b);
  return LoopCheck(
    totalOhm: r,
    volts20: supplyV - 0.020 * r,
    volts21: supplyV - 0.021 * r,
    maxOhm21: math.max(0, (supplyV - minV) / 0.021),
  );
}

/// 전선 왕복 저항(Ω) — [ohmPerKm] 한 가닥 저항, [lengthM] 편도 길이.
double wireLoopOhm({required double ohmPerKm, required double lengthM}) =>
    ohmPerKm * lengthM * 2 / 1000;
