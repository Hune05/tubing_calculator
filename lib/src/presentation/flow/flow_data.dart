// 유량 계산 숫자 자료(화면 없음). 모두 두 출처 이상에서 확인한 값만 넣었다. 근거: docs/유량계산_근거.md.
library;

import 'dart:math' as math;

/// 물(1기압) (°C, 밀도 kg/m³, 점도 mPa·s). 사이 온도는 직선 보간.
/// 값: NIST Chemistry WebBook 등압 0.101325MPa(밀도 IAPWS-95, 점도 IAPWS 2008), 2026-09-26 조회.
/// 0°C 줄은 삼중점(0.01°C) 값. 밀도는 Engineering ToolBox·CRC(Wikipedia Water data page)와 0.007 이내,
/// 점도는 Engineering ToolBox(0.01·10·20·25·30…90°C)와 0.0001 이내, 5·15·35·45°C는 Chemcasts(IAPWS-95)와 0.12% 이내.
/// 55·65·75·85°C 점도는 두 번째 출처가 없어 넣지 않았다(10°C 사이 보간 오차 0.5% 이하).
/// 90°C 위는 1기압에서 끓는점(99.97°C)에 가까워 넣지 않았다.
const List<(double, double, double)> kWaterTable = [
  // dart format off
  (0, 999.844, 1.7911),
  (5, 999.967, 1.5182),
  (10, 999.702, 1.3059),
  (15, 999.103, 1.1376),
  (20, 998.207, 1.0016),
  (25, 997.048, 0.8900),
  (30, 995.649, 0.7972),
  (35, 994.033, 0.7191),
  (40, 992.216, 0.6527),
  (45, 990.213, 0.5958),
  (50, 988.035, 0.5465),
  (60, 983.196, 0.4660),
  (70, 977.765, 0.4035),
  (80, 971.790, 0.3541),
  (90, 965.310, 0.3142),
  // dart format on
];

/// 일반 기체 상수 J/(mol·K): 2019 SI 정의값(CODATA 2022, NIST).
const double kGasR = 8.314462618;

/// 기체 성질: 몰 질량과 Sutherland 점도 식 상수 μ = μ0·(T/T0)^1.5·(T0 + S)/(T + S).
class GasData {
  final String label;
  final double molarMass; // g/mol
  final double mu0; // Pa·s
  final double t0; // K
  final double s; // K
  const GasData(this.label, this.molarMass, this.mu0, this.t0, this.s);
}

/// 건조 공기: 몰 질량 28.9647(Engineering ToolBox; Wikipedia "Density of air" 28.9652, 차이 0.004%).
/// Sutherland 1.716e-5Pa·s, 273.15K, 110.4K(White 값: curiosityFluids·SU2 #301). Engineering ToolBox
/// 공기 점도 표(0·20·100·200°C)와 0.1% 이내.
const GasData kAir = GasData('공기', 28.9647, 1.716e-5, 273.15, 110.4);

/// 질소: 몰 질량 28.0134(NIST WebBook). Sutherland 1.663e-5Pa·s, 273K, 107K(White 값: COMSOL 표 5-2).
/// NIST WebBook 1기압 점도와 0°C +0.05%, 20°C 0.00%, 100°C −0.33%, 200°C −0.85%.
const GasData kN2 = GasData('질소', 28.0134, 1.663e-5, 273, 107);

/// 기체 온도 범위(°C): 점도를 두 번째 출처와 맞춰 본 0~200°C에 영하 20°C까지(White: 170K 위 ±2%).
const double kGasMinC = -20;
const double kGasMaxC = 200;

/// 이상기체 밀도 안내 압력(절대 kPa): 질소 20°C에서 NIST 밀도와 100bar까지 0.6% 이내, 200bar 약 5%.
const double kIdealGasLimitKpa = 10000;

/// 층류·난류 경계 레이놀즈 수(White, Fluid Mechanics 6.1절; Çengel 8장).
const double kReLaminar = 2300;
const double kReTurbulent = 4000;

class RoughData {
  final String id;
  final String label;
  final double? mm; // null: 직접 입력
  const RoughData(this.id, this.label, this.mm);
}

/// 절대 거칠기(mm). Moody(1944) 값: 인발 튜브 0.000005ft, 상용 강관 0.00015ft, 아연도금 0.0005ft, 주철 0.00085ft.
/// 확인: Hydraulic Institute Engineering Data Book 표 3.A.1(datatool.pumps.org), Pipeflow, Engineers Edge
/// (HI·White Fluid Mechanics 7판 인용), Engineering ToolBox. 스테인리스 관은 출처마다 달라(0.002~0.015mm) 넣지 않았다:
/// 인발한 계기용 스테인리스 튜브는 인발 튜브 값을 쓴다.
const List<RoughData> kRoughness = [
  RoughData('drawn', '인발 튜브', 0.0015),
  RoughData('steel', '상용 강관', 0.045),
  RoughData('galv', '아연도금 강관', 0.15),
  RoughData('cast', '주철관', 0.26),
  RoughData('custom', '직접 입력', null),
];

const String kRoughSource =
    'Moody(1944), Hydraulic Institute Engineering Data Book 표 3.A.1, White Fluid Mechanics 표 6.1. '
    '인발 튜브는 스테인리스·동관 계기용 튜브, 상용 강관은 탄소강 배관입니다.';

/// 피팅·밸브 저항 계수. 3-K 식(Darby 2001): K = K1/Re + Ki·(1 + Kd/Dn^0.3), Dn은 호칭 지름(인치).
/// [fixedK]가 있으면 그 값(관 입구·출구).
class FittingData {
  final String id;
  final String label;
  final double k1;
  final double ki;
  final double kd;
  final double? fixedK;
  const FittingData(this.id, this.label, this.k1, this.ki, this.kd)
    : fixedK = null;
  const FittingData.fixed(this.id, this.label, double k)
    : k1 = 0,
      ki = 0,
      kd = 0,
      fixedK = k;

  /// K. [re] 관 기준 레이놀즈 수, [dnInch] 호칭 지름(인치).
  double k(double re, double dnInch) =>
      fixedK ?? k1 / re + ki * (1 + kd / _pow03(dnInch));
}

double _pow03(double x) => math.pow(x, 0.3).toDouble();

/// 3-K 값: Darby, "Correlate Pressure Drops Through Fittings", Chem. Eng. 2001년 4월 표 1(원문),
/// Neutrium "Pressure loss from fittings: 3K method", Caleb Bell fluids 라이브러리 fittings.py가 모두 같은 값.
/// 볼 밸브 Kd는 원문 4.0, Neutrium·fluids 3.5로 달라 큰 값(원문 4.0)을 썼다(K 차이 약 10%, K 자체가 0.08 안팎).
/// 입구 0.5(각진 입구)·출구 1.0: Crane TP-410 A-30쪽(Fike TB8102 인용), simupipe K 표, fluids.
/// 나사 피팅 값이다. 튜브 압축 피팅의 K는 공개된 자료를 찾지 못해 같은 모양의 나사 피팅 값으로 계산한다.
const List<FittingData> kFittings = [
  FittingData('elbow90', '90° 엘보', 800, 0.14, 4.0),
  FittingData('elbow90lr', '90° 롱 엘보(r/D 1.5)', 800, 0.071, 4.2),
  FittingData('elbow45', '45° 엘보', 500, 0.071, 4.2),
  FittingData('teeRun', '티 직진', 200, 0.091, 4.0),
  FittingData('teeBranch', '티 분기', 500, 0.274, 4.0),
  FittingData('ball', '볼 밸브(풀 포트)', 300, 0.017, 4.0),
  FittingData('gate', '게이트 밸브', 300, 0.037, 3.9),
  FittingData('globe', '글로브 밸브', 1500, 1.7, 3.6),
  FittingData('swingCheck', '스윙 체크 밸브', 1500, 0.46, 4.0),
  FittingData('liftCheck', '리프트 체크 밸브', 2000, 2.85, 3.8),
  FittingData.fixed('entrance', '관 입구(각진 입구)', 0.5),
  FittingData.fixed('exit', '관 출구(탱크로)', 1.0),
];

const String kFittingSource =
    'Darby 3-K 식(Chem. Eng. 2001), Neutrium, fluids. 입구·출구는 Crane TP-410.';

/// 권장 유속(m/s). [min]이 없으면 최대만 본다.
class VelocityGuide {
  final String id;
  final String label;
  final List<String> fluids; // FluidKind.name
  final double? min;
  final double max;
  final String source;
  const VelocityGuide(
    this.id,
    this.label,
    this.fluids,
    this.min,
    this.max,
    this.source,
  );

  String get rangeText =>
      min == null ? '${_t(max)} m/s 이하' : '${_t(min!)}~${_t(max)} m/s';
}

String _t(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

/// 물: Crane TP-410 "Reasonable velocities for flow of water through pipe"와 ASHRAE Fundamentals가 같은 표
/// (펌프 흡입·배수 4~7ft/s, 일반 4~10ft/s). Engineering ToolBox "Flow velocity water pipes"(흡입 0.9~2.4,
/// 공정수 1.5~3m/s), ASHRAE 침식 한도(연 6000시간 10ft/s = 3m/s)와도 맞는다. Crane·ASHRAE 표는 원문을 직접 열지 못하고
/// 여러 요약에서 같은 값을 확인했다.
/// 압축공기·질소: Atlas Copco "Sizing compressed air pipe"(주관 6~7m/s 이하, 9m/s를 넘지 않음), Compressed Air
/// Challenge(분배 30ft/s = 9.1m/s 이하), CATZ(헤더 20ft/s = 6.1m/s, 분배 30ft/s). 질소만의 자료는 없어 공기 값을 쓴다.
/// 기름은 두 출처가 맞는 값을 찾지 못해 넣지 않았다.
const List<VelocityGuide> kVelocityGuides = [
  VelocityGuide(
    'wGeneral',
    '일반·펌프 토출',
    ['water'],
    1.2,
    3.0,
    'Crane TP-410·ASHRAE 일반 급수 4~10ft/s(1.2~3.0m/s). 3m/s는 연속 운전 침식 한도(ASHRAE)와 같습니다.',
  ),
  VelocityGuide(
    'wSuction',
    '펌프 흡입',
    ['water'],
    1.2,
    2.1,
    'Crane TP-410·ASHRAE 펌프 흡입 4~7ft/s(1.2~2.1m/s). 끓는점에 가까운 물은 더 낮게 잡습니다.',
  ),
  VelocityGuide(
    'gHeader',
    '압축공기 주관',
    ['air', 'n2'],
    null,
    6.0,
    'Atlas Copco(주관 6~7m/s 이하), CATZ(헤더 6.1m/s 이하). 질소도 같은 값을 씁니다.',
  ),
  VelocityGuide(
    'gBranch',
    '분배·분기관',
    ['air', 'n2'],
    null,
    9.0,
    'Atlas Copco(9m/s를 넘지 않음), Compressed Air Challenge·CATZ(분배 30ft/s = 9.1m/s 이하).',
  ),
];

/// 기체 압력손실 판정 경계(Crane TP-410): 입구 절대 압력의 10% 미만이면 밀도 일정, 10~40%는 평균 밀도,
/// 40% 초과는 압축성 계산. 확인: LMNO Engineering(Crane 인용), Pipe Flow Expert 검증 문서.
const double kGasDpOk = 0.10;
const double kGasDpAvg = 0.40;
