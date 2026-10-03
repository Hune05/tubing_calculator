// 전동기 점검(10-03): 절연저항 시험전압·40 ℃ 환산·최소값·성극지수, 권선 저항 불평형·온도 환산,
// 전압·전류 불평형. 화면 없이 계산만 한다. 근거와 확인 정도는 docs/전동기_점검_근거.md.
//
// 원문으로 확인한 것: IEEE 43-2000 표 1·2·3과 6.3.3 온도 보정, IEC 60034-27-4 표 1(합성수지 보정),
// ANSI/EASA AR100-2025 4.3.1(권선 저항 불평형 2 %·1 %), IEEE 112 5.2.1(구리 234.5),
// NEMA MG1 전압 불평형(DOE Tip Sheet #7). 출처끼리 다른 값은 화면에 같이 적는다.
library;

import 'dart:math' as math;

/// 절연저항계 시험전압(V DC, 범위) — IEEE 43 표 1. [ratedV] 정격 선간전압(V).
/// 12 kV를 넘으면 표 범위 밖이라 null.
(double, double)? megTestVoltage(double ratedV) {
  if (ratedV <= 0) return null;
  if (ratedV < 1000) return (500, 500);
  if (ratedV <= 2500) return (500, 1000);
  if (ratedV <= 5000) return (1000, 2500);
  if (ratedV <= 12000) return (2500, 5000);
  return null;
}

/// 절연저항 온도 보정 방식.
enum IrCorrection {
  /// IEEE 43 6.3.3: 40 ℃ 기준, 10 ℃마다 절반(근사).
  ieee43,

  /// IEC 60034-27-4 표 1 합성수지 절연: 10~40 ℃는 보정 안 함, 40 ℃ 초과는 17 K마다 절반.
  iecResin,
}

/// [measuredMOhm]를 [tempC]에서 측정했을 때 40 ℃ 환산값(MΩ).
/// 1분값이 5000 MΩ을 넘으면 보정하지 않는다(IEC 60034-27-4).
double irAt40({
  required double measuredMOhm,
  required double tempC,
  IrCorrection method = IrCorrection.ieee43,
}) {
  if (measuredMOhm > 5000) return measuredMOhm;
  switch (method) {
    case IrCorrection.ieee43:
      return measuredMOhm * math.pow(0.5, (40 - tempC) / 10);
    case IrCorrection.iecResin:
      if (tempC <= 40) return measuredMOhm;
      return measuredMOhm * math.pow(2, (tempC - 40) / 17);
  }
}

/// 권선 종류(IEEE 43 표 3의 최소 절연저항 구분).
enum WindingKind {
  /// 랜덤권선(저압 전동기 대부분)과 1 kV 미만 폼권선: 5 MΩ.
  random,

  /// 1970년 무렵 이후 폼권선(고압 전동기 대부분): 100 MΩ.
  form,

  /// 1970년 무렵 이전 권선: kV + 1 MΩ.
  old,
}

/// 40 ℃ 환산 1분값 최소 절연저항(MΩ). [ratedKv]는 [WindingKind.old]에만 쓴다.
double minIrMOhm(WindingKind k, {double ratedKv = 0}) => switch (k) {
  WindingKind.random => 5,
  WindingKind.form => 100,
  WindingKind.old => ratedKv + 1,
};

/// 성극지수 PI = 10분값 ÷ 1분값. 1분값이 5000 MΩ을 넘으면 평가하지 않아 null(IEEE 43).
double? polarizationIndex(double r1min, double r10min) {
  if (r1min <= 0 || r10min <= 0 || r1min > 5000) return null;
  return r10min / r1min;
}

/// PI 최소값: A종 1.5, B·F·H종 2.0(IEEE 43 표 2).
double minPi({required bool classA}) => classA ? 1.5 : 2.0;

/// 세 값의 불평형(%): 평균에서 가장 먼 값의 차 ÷ 평균 × 100(NEMA MG1·EASA 공통 정의).
double? unbalancePct(double a, double b, double c) {
  if (a <= 0 || b <= 0 || c <= 0) return null;
  final avg = (a + b + c) / 3;
  final dev = [a, b, c].map((x) => (x - avg).abs()).reduce(math.max);
  return dev / avg * 100;
}

/// 권선 저항 불평형 허용(%): 랜덤권선 2 %, 폼권선 1 %(ANSI/EASA AR100-2025 4.3.1).
double windingUnbalanceLimit(WindingKind k) => k == WindingKind.random ? 2 : 1;

/// 권선 저항 온도 환산: R_b = R_a × (t_b + 234.5) ÷ (t_a + 234.5). 구리 234.5, 알루미늄 225(IEEE 112 5.2.1).
double windingResistanceAt({
  required double ohms,
  required double fromC,
  required double toC,
  bool aluminum = false,
}) {
  final k = aluminum ? 225.0 : 234.5;
  return ohms * (toC + k) / (fromC + k);
}

/// NEMA 전압 불평형에 따른 출력 저감계수(대략). 1 % 이하 1.0, 2 % 0.95, 3 % 0.88(EPRI가 옮긴 NEMA MG1 그림),
/// 4 % 0.82, 5 % 0.75(검색 요약, 원문 미확인). 5 %를 넘으면 운전을 권장하지 않아 null.
double? nemaDerating(double unbalancePct) {
  if (unbalancePct < 0) return null;
  if (unbalancePct > 5) return null;
  const pts = [(1.0, 1.0), (2.0, 0.95), (3.0, 0.88), (4.0, 0.82), (5.0, 0.75)];
  if (unbalancePct <= 1) return 1.0;
  for (var i = 1; i < pts.length; i++) {
    final (x0, y0) = pts[i - 1];
    final (x1, y1) = pts[i];
    if (unbalancePct <= x1) {
      return y0 + (y1 - y0) * (unbalancePct - x0) / (x1 - x0);
    }
  }
  return 0.75;
}

/// 전압 불평형 때 온도상승 증가(%): 2 × (불평형 %)²(DOE Tip Sheet #7).
double unbalanceHeatingPct(double unbalancePct) =>
    2 * unbalancePct * unbalancePct;
