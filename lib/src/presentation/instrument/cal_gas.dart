// 교정 가스 소모량(화면 없음). 발전기 수소 순도계(요꼬가와 GD402 가스 밀도계) 교정에 쓰는 용기 가스가
// 얼마나 남았고 몇 번 더 교정할 수 있는지 계산한다. 근거는 docs/교정가스_근거.md.
//
// 압축 가스(수소·질소): 용기 안 가스(Nm³) = 내용적 × (절대압/Z) / 1.01325 × 273.15 / T.
// Z는 NIST Webbook 등온선(0·20·40°C, 0~250 bar abs)에서 이중 선형 보간.
// 액화 가스(이산화탄소): 20°C에서 57.3 bar로 압력이 머물러 압력으로는 남은 양을 알 수 없다. 무게(kg)로 받는다.
library;

import 'dart:math' as math;

/// 표준 대기압(bar).
const double kAtmBar = 1.01325;

/// 0°C(K).
const double kT0 = 273.15;

enum CalGas { h2, co2, n2 }

extension CalGasInfo on CalGas {
  String get label => switch (this) {
    CalGas.h2 => '수소(H₂)',
    CalGas.co2 => '이산화탄소(CO₂)',
    CalGas.n2 => '질소(N₂)',
  };

  /// 0°C, 101.325kPa 밀도(kg/Nm³). 요꼬가와 IM 11T03E01-01E 교정 가스 값(H₂·CO₂), TI 11T03E01-01E 부록 표 1(N₂, JIS K2301).
  double get normalDensity => switch (this) {
    CalGas.h2 => 0.0899,
    CalGas.co2 => 1.9771,
    CalGas.n2 => 1.2504,
  };

  /// 액화 가스라 무게로 남은 양을 보는지.
  bool get byWeight => this == CalGas.co2;
}

/// 공기 0°C, 101.325kPa 밀도(kg/Nm³).
const double kAirNormalDensity = 1.2929;

/// 이산화탄소 충전상수 C(L/kg): 고압가스 안전관리법 시행규칙 별표 1. 47L 용기면 47/1.47 = 32.0kg.
const double kCo2FillConstant = 1.47;

/// NIST 표의 압력(bar abs)과 온도(°C).
const List<double> _zP = [0, 25, 50, 75, 100, 125, 150, 175, 200, 225, 250];
const List<double> _zT = [0, 20, 40];

/// Z = P / (ρRT), NIST Webbook 유체 성질 등온선에서 계산(R = 8.314462618).
const Map<CalGas, List<List<double>>> _zTable = {
  CalGas.h2: [
    [
      1,
      1.0155,
      1.0313,
      1.0474,
      1.0637,
      1.0804,
      1.0973,
      1.1144,
      1.1316,
      1.1491,
      1.1667,
    ],
    [
      1,
      1.0149,
      1.0300,
      1.0453,
      1.0608,
      1.0765,
      1.0924,
      1.1085,
      1.1247,
      1.1411,
      1.1575,
    ],
    [
      1,
      1.0143,
      1.0287,
      1.0433,
      1.0580,
      1.0729,
      1.0880,
      1.1031,
      1.1184,
      1.1338,
      1.1492,
    ],
  ],
  CalGas.n2: [
    [
      1,
      0.9904,
      0.9845,
      0.9826,
      0.9848,
      0.9913,
      1.0019,
      1.0162,
      1.0338,
      1.0545,
      1.0776,
    ],
    [
      1,
      0.9954,
      0.9940,
      0.9957,
      1.0008,
      1.0091,
      1.0205,
      1.0348,
      1.0518,
      1.0711,
      1.0924,
    ],
    [
      1,
      0.9992,
      1.0010,
      1.0055,
      1.0125,
      1.0222,
      1.0343,
      1.0487,
      1.0652,
      1.0835,
      1.1036,
    ],
  ],
};

/// 표 안에서 계산할 수 있는 범위.
const double kZMaxBar = 250;
const double kZMinC = 0;
const double kZMaxC = 40;

/// 압축 계수 Z. 표 밖(250 bar abs 초과, 0~40°C 밖)이면 null.
double? zOf(CalGas g, double pAbsBar, double tC) {
  final t = _zTable[g];
  if (t == null) return null;
  if (pAbsBar < 0 || pAbsBar > kZMaxBar || tC < kZMinC || tC > kZMaxC) {
    return null;
  }
  int seg(List<double> xs, double x) {
    for (var i = 0; i < xs.length - 2; i++) {
      if (x <= xs[i + 1]) return i;
    }
    return xs.length - 2;
  }

  final i = seg(_zP, pAbsBar), j = seg(_zT, tC);
  final fp = (pAbsBar - _zP[i]) / (_zP[i + 1] - _zP[i]);
  final ft = (tC - _zT[j]) / (_zT[j + 1] - _zT[j]);
  double at(int r) => t[r][i] + (t[r][i + 1] - t[r][i]) * fp;
  return at(j) + (at(j + 1) - at(j)) * ft;
}

/// 용기 안 가스량(Nm³). [pGaugeBar]는 게이지 압력. 표 밖이면 null.
double? cylinderNm3({
  required CalGas gas,
  required double waterL,
  required double pGaugeBar,
  required double tC,
}) {
  final pAbs = pGaugeBar + kAtmBar;
  final z = zOf(gas, pAbs, tC);
  if (z == null) return null;
  return waterL / 1000 * (pAbs / z) / kAtmBar * kT0 / (tC + kT0);
}

/// 유량계 눈금이 공기 기준일 때 실제 유량 = 눈금 × √(ρ공기/ρ가스) (가변 면적 유량계 가스 보정, Brooks).
double airScaleFactor(CalGas g) =>
    math.sqrt(kAirNormalDensity / g.normalDensity);

/// 결과.
class CalGasResult {
  const CalGasResult({
    required this.availableNm3,
    this.totalNm3,
    this.actualLpm,
    this.perCalNL,
    this.calsLeft,
    this.dropPerCalBar,
    this.flowMinutes,
  });

  /// 쓸 수 있는 양(Nm³): 압축 가스는 남길 압력까지, 이산화탄소는 남은 무게 전부.
  final double availableNm3;

  /// 지금 용기 안 전체(Nm³, 압축 가스만).
  final double? totalNm3;

  /// 실제 유량(L/min, 유량계 자리 상태).
  final double? actualLpm;

  /// 교정 1회 사용량(NL).
  final double? perCalNL;

  /// 남은 교정 횟수(내림).
  final int? calsLeft;

  /// 교정 1회당 용기 압력 강하(bar, 압축 가스만, 지금 압력 근처).
  final double? dropPerCalBar;

  /// 이 유량으로 계속 흘리면 남길 압력(무게 0)까지 걸리는 시간(분).
  final double? flowMinutes;
}

/// [lpm] 유량계 읽음, [airScale] 눈금이 공기 기준인지, [minutes] 교정 1회에 이 가스를 흘리는 시간.
/// 유량계는 대기압 가까이에서 읽는다고 본다(분석계 출구가 벤트로 열려 있음).
/// 압축 가스는 [pGaugeBar]·[residualGaugeBar], 이산화탄소는 [netKg]가 있어야 한다. 모자라거나 표 밖이면 null.
CalGasResult? calGasUse({
  required CalGas gas,
  required double tC,
  double waterL = 47,
  double? pGaugeBar,
  double? residualGaugeBar,
  double? netKg,
  double? lpm,
  bool airScale = false,
  double? minutes,
}) {
  double available;
  double? total;
  double? z;
  if (gas.byWeight) {
    if (netKg == null || netKg < 0) return null;
    available = netKg / gas.normalDensity;
  } else {
    if (pGaugeBar == null || residualGaugeBar == null) return null;
    if (waterL <= 0 || residualGaugeBar < 0 || pGaugeBar < residualGaugeBar) {
      return null;
    }
    total = cylinderNm3(gas: gas, waterL: waterL, pGaugeBar: pGaugeBar, tC: tC);
    final rest = cylinderNm3(
      gas: gas,
      waterL: waterL,
      pGaugeBar: residualGaugeBar,
      tC: tC,
    );
    if (total == null || rest == null) return null;
    available = total - rest;
    z = zOf(gas, pGaugeBar + kAtmBar, tC);
  }

  final tK = tC + kT0;
  double? actual, perCal, drop, flowMin;
  int? left;
  if (lpm != null && lpm > 0) {
    actual = lpm * (airScale ? airScaleFactor(gas) : 1);
    final nlPerMin = actual * kT0 / tK;
    flowMin = available * 1000 / nlPerMin;
    if (minutes != null && minutes > 0) {
      perCal = nlPerMin * minutes;
      left = (available * 1000 / perCal + 1e-9).floor();
      if (z != null) {
        drop = perCal / 1000 * kAtmBar * tK / kT0 * z / (waterL / 1000);
      }
    }
  }
  return CalGasResult(
    availableNm3: available,
    totalNm3: total,
    actualLpm: actual,
    perCalNL: perCal,
    calsLeft: left,
    dropPerCalBar: drop,
    flowMinutes: flowMin,
  );
}
