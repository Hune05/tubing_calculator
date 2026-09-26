// 4-20mA 계산(화면 없음). 근거는 docs/4-20mA계산기_근거.md.
//
// mA ↔ % ↔ 측정값 환산(선형, 차압 유량의 제곱근 두 가지), NAMUR NE43 신호 상태, 교정 점검(이론값
// 대비 스팬 % 오차와 허용오차 판정), 루프 전압(전원 − 전류 × 루프 저항 ≥ 계기 최소 동작 전압).
library;

import 'dart:math' as math;

const double kMaLow = 4;
const double kMaHigh = 20;
const double kMaSpan = kMaHigh - kMaLow;

/// mA와 측정값(측정 범위)의 관계.
/// - [linear]: mA가 측정값에 비례.
/// - [sqrt]: 제곱근을 DCS에서 연산. mA는 차압에 비례하고, 측정 범위는 유량(유량 = √차압).
/// - [sqrtOut]: 전송기가 제곱근 출력. 측정 범위는 차압(표준기로 넣는 값)이고, mA는 √차압(유량)에 비례.
enum Transfer { linear, sqrt, sqrtOut }

/// 출력 %(0~100, 범위 밖도 계산) → mA.
double maFromPct(double pct) => kMaLow + kMaSpan * pct / 100;

/// mA → 출력 %.
double pctFromMa(double ma) => (ma - kMaLow) / kMaSpan * 100;

/// 측정값 → 측정 범위 %.
double pvToPct(double pv, double lrv, double urv) =>
    (pv - lrv) / (urv - lrv) * 100;

/// 측정 범위 % → 측정값.
double pctToPv(double pct, double lrv, double urv) =>
    lrv + (urv - lrv) * pct / 100;

/// 측정 % → 출력 %.
/// - sqrt: 출력(차압) % = (유량 %)² / 100
/// - sqrtOut: 출력(유량) % = 10 × √(차압 %)
double outPctFromPvPct(double pvPct, Transfer t) => switch (t) {
  Transfer.linear => pvPct,
  Transfer.sqrt => pvPct <= 0 ? 0 : pvPct * pvPct / 100,
  Transfer.sqrtOut => pvPct <= 0 ? 0 : 10 * math.sqrt(pvPct),
};

/// 출력 % → 측정 %. 0 아래는 0(제곱근).
double pvPctFromOutPct(double outPct, Transfer t) => switch (t) {
  Transfer.linear => outPct,
  Transfer.sqrt => outPct <= 0 ? 0 : 10 * math.sqrt(outPct),
  Transfer.sqrtOut => outPct <= 0 ? 0 : outPct * outPct / 100,
};

/// 측정값 → 이론 mA.
double idealMa(double pv, double lrv, double urv, Transfer t) =>
    maFromPct(outPctFromPvPct(pvToPct(pv, lrv, urv), t));

/// mA → 측정값.
double pvFromMa(double ma, double lrv, double urv, Transfer t) =>
    pctToPv(pvPctFromOutPct(pctFromMa(ma), t), lrv, urv);

/// 전류가 어느 구간인지: NAMUR NE43.
enum SignalState {
  failLow, // 3.6 이하: 고장 신호(하한)
  gapLow, // 3.6 ~ 3.8: NE43에서 정하지 않은 구간(제조사 고장 신호 설정값일 수 있음)
  underRange, // 3.8 ~ 4: 0% 미만이지만 유효한 측정
  normal, // 4 ~ 20
  overRange, // 20 ~ 20.5: 100% 초과이지만 유효한 측정
  gapHigh, // 20.5 ~ 21(제조사 포화값일 수 있음)
  failHigh, // 21 이상: 고장 신호(상한)
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

/// 측정 방법.
/// - [ma]: 전송기 교정. 표준기로 공정값을 넣고 출력 mA를 측정.
/// - [pv]: 루프 점검. 표준기로 공정값을 넣고 DCS·지시계 지시값을 읽음.
/// - [maIn]: mA 입력 점검. 루프 교정기로 mA를 넣고 DCS 입력 카드·지시계·밸브 행정의 지시값을 읽음.
enum ReadKind { ma, pv, maIn }

/// 점 [pct](0~100)의 기본 입력값. mA 입력이면 mA, 아니면 측정 범위 값.
double nominalInput(double pct, ReadKind kind, double lrv, double urv) =>
    kind == ReadKind.maIn ? maFromPct(pct) : pctToPv(pct, lrv, urv);

class CalPoint {
  final double applied; // 입력값(공정값, mA 입력이면 mA)
  final double reading; // 측정값(mA) 또는 지시값
  final double expected; // 이론값(측정값과 같은 단위)
  final double idealMa; // 이 점의 이론 mA(mA 입력이면 입력 mA)
  final double errPct; // 오차(스팬 %): mA 측정이면 16mA 대비, 지시값이면 측정 범위 대비
  final double errMa; // 오차(mA). 비선형이라 뜻이 없으면 NaN
  final double errPv; // 오차(측정값 단위). 제곱근 0% 부근처럼 부풀려지면 NaN
  final bool? pass; // 허용오차를 넣었을 때만
  const CalPoint({
    required this.applied,
    required this.reading,
    required this.expected,
    required this.idealMa,
    required this.errPct,
    required this.errMa,
    required this.errPv,
    required this.pass,
  });
}

/// 한 점 점검. [tolPct] 허용오차(± 스팬 %). 없거나 0 이하면 판정하지 않음.
CalPoint checkPoint({
  required double applied,
  required double reading,
  required ReadKind kind,
  required double lrv,
  required double urv,
  Transfer transfer = Transfer.linear,
  double? tolPct,
}) {
  final span = urv - lrv;
  final double expected, ideal, errPct, errMa, errPv;
  switch (kind) {
    case ReadKind.ma:
      ideal = idealMa(applied, lrv, urv, transfer);
      expected = ideal;
      errMa = reading - ideal;
      errPct = errMa / kMaSpan * 100;
      // DCS 제곱근이면 0% 부근에서 유량 오차가 크게 부풀려져 보이므로 10% 아래는 보이지 않음.
      errPv = transfer == Transfer.sqrt && pvToPct(applied, lrv, urv) < 10
          ? double.nan
          : pvFromMa(reading, lrv, urv, transfer) - applied;
    case ReadKind.pv:
      ideal = idealMa(applied, lrv, urv, transfer);
      expected = applied;
      errPv = reading - applied;
      errPct = errPv / span.abs() * 100;
      errMa = transfer == Transfer.linear ? errPv * kMaSpan / span : double.nan;
    case ReadKind.maIn:
      ideal = applied;
      expected = pvFromMa(applied, lrv, urv, transfer);
      errPv = reading - expected;
      errPct = errPv / span.abs() * 100;
      errMa = transfer == Transfer.linear ? errPv * kMaSpan / span : double.nan;
  }
  final tol = tolPct != null && tolPct > 0 ? tolPct : null;
  return CalPoint(
    applied: applied,
    reading: reading,
    expected: expected,
    idealMa: ideal,
    errPct: errPct,
    errMa: errMa,
    errPv: errPv,
    pass: tol == null ? null : errPct.abs() <= tol + 1e-9,
  );
}

// ─────────────── 루프 전압 ───────────────

/// 확인 전류 고르기(mA). 21: NE43 고장 신호 하한, 21.75: Rosemount 3051 기본 고장 신호,
/// 22.5: Rosemount NAMUR 설정, 23: Rosemount 최대 부하 식(43.5 = 1/0.023) 기준.
const List<double> kLoopCheckMa = [21, 21.75, 22.5, 23];

class LoopCheck {
  final double totalOhm; // 루프 총저항
  final double checkMa; // 확인 전류
  final double volts20; // 20mA 때 계기 단자 전압
  final double voltsCheck; // 확인 전류 때 계기 단자 전압
  final double maxOhm; // 확인 전류까지 낼 수 있는 최대 루프 저항
  const LoopCheck({
    required this.totalOhm,
    required this.checkMa,
    required this.volts20,
    required this.voltsCheck,
    required this.maxOhm,
  });
  bool okAt20(double minV) => volts20 >= minV - 1e-9;
  bool okAtCheck(double minV) => voltsCheck >= minV - 1e-9;
}

/// [supplyV] 전원, [minV] 계기 최소 동작 전압(사양서), [ohms] 루프에 든 저항들(Ω),
/// [checkMa] 확인 전류, [extraV] 지시계 등 전류와 상관없는 전압 강하(V).
LoopCheck loopCheck({
  required double supplyV,
  required double minV,
  required List<double> ohms,
  double checkMa = 23,
  double extraV = 0,
}) {
  final r = ohms.fold<double>(0, (a, b) => a + b);
  final i = checkMa / 1000;
  return LoopCheck(
    totalOhm: r,
    checkMa: checkMa,
    volts20: supplyV - 0.020 * r - extraV,
    voltsCheck: supplyV - i * r - extraV,
    maxOhm: math.max(0, (supplyV - minV - extraV) / i),
  );
}

/// 전선 왕복 저항(Ω). [ohmPerKm] 한 가닥 저항, [lengthM] 편도 길이.
double wireLoopOhm({required double ohmPerKm, required double lengthM}) =>
    ohmPerKm * lengthM * 2 / 1000;
