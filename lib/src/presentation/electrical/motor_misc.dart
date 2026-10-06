// 전동기 구동·효율 계산(10-03): 권선 온도 상승, 효율 절감·회수, 감속기·벨트, 권상·컨베이어 동력, 소프트스타터, 제동 에너지,
// 직류 전동기. 화면 없이 계산만 한다. 모두 정의식·교재 일반식이고, 값(마찰계수·효율·전압 등)은 사용자가 넣는다.
library;

import 'dart:math' as math;

// ─────────────── 권선 온도 상승(저항법) ───────────────

/// 저항법 온도 계수: 구리 234.5, 알루미늄 225(IEEE 112 5.2.1). IEC 60034-1은 구리 235, 알루미늄 225를 쓴다.
double windingK(bool aluminum) => aluminum ? 225 : 234.5;

class WindingTemp {
  const WindingTemp({required this.hotTempC, required this.riseK});

  /// 운전 직후 권선 평균 온도(℃) = (R2/R1)(k + T1) − k.
  final double hotTempC;

  /// 온도 상승(K) = 권선 온도 − 주위 온도.
  final double riseK;
}

/// 저항법: 차가울 때 저항 [r1](Ω, 온도 [t1]℃)과 운전 직후 저항 [r2](Ω)로 권선 온도와 온도 상승을 구한다.
/// 온도 상승 ΔT = (R2/R1)(k + T1) − k − T2 ([t2] 주위 온도).
WindingTemp? windingTempRise({
  required double r1,
  required double t1,
  required double r2,
  required double t2,
  bool aluminum = false,
}) {
  if (r1 <= 0 || r2 <= 0) return null;
  final k = windingK(aluminum);
  if (t1 <= -k || t2 <= -k) return null;
  final hot = (r2 / r1) * (k + t1) - k;
  return WindingTemp(hotTempC: hot, riseK: hot - t2);
}

// ─────────────── 효율 절감·투자 회수 ───────────────

class EnergySaving {
  const EnergySaving({
    required this.kwhOld,
    required this.kwhNew,
    required this.savedKwh,
    required this.savedMoney,
    this.paybackYears,
  });

  /// 연간 소비 전력량(kWh) = P × 부하율 × 시간 ÷ 효율.
  final double kwhOld;
  final double kwhNew;

  /// 연간 절감 전력량(kWh)과 금액.
  final double savedKwh;
  final double savedMoney;

  /// 투자 회수 기간(년) = 추가 비용 ÷ 연간 절감액. 추가 비용을 안 주면 null.
  final double? paybackYears;
}

/// 효율 [effOld]에서 [effNew]로 바꿀 때: [kw] 축 출력, [loadFactor] 부하율(0~1), [hours] 연간 운전 시간,
/// [price] 전력 단가(원/kWh), [extraCost] 추가 비용(원).
EnergySaving? energySaving({
  required double kw,
  required double loadFactor,
  required double hours,
  required double effOld,
  required double effNew,
  required double price,
  double? extraCost,
}) {
  if (kw <= 0 || loadFactor <= 0 || loadFactor > 1.5 || hours <= 0) return null;
  if (effOld <= 0 || effOld > 1 || effNew <= 0 || effNew > 1 || price < 0) return null;
  final old = kw * loadFactor * hours / effOld;
  final nw = kw * loadFactor * hours / effNew;
  final saved = old - nw;
  final money = saved * price;
  return EnergySaving(
    kwhOld: old,
    kwhNew: nw,
    savedKwh: saved,
    savedMoney: money,
    paybackYears: (extraCost == null || extraCost < 0 || money <= 0) ? null : extraCost / money,
  );
}

// ─────────────── 감속기·벨트 ───────────────

class GearResult {
  const GearResult({required this.ratio, required this.outRpm, required this.outTorqueNm, required this.outKw});

  /// 감속비 i = 입력 속도 ÷ 출력 속도.
  final double ratio;
  final double outRpm;
  final double outTorqueNm;
  final double outKw;
}

/// 감속비 [ratio](i = N입력 ÷ N출력 = 출력 풀리 지름 ÷ 입력 풀리 지름 = 출력 잇수 ÷ 입력 잇수).
/// 출력 회전수 = 입력 ÷ i, 출력 토크 = 입력 토크 × i × η.
GearResult? gearOut({
  required double inRpm,
  required double inKw,
  required double ratio,
  required double eff,
}) {
  if (inRpm <= 0 || inKw <= 0 || ratio <= 0 || eff <= 0 || eff > 1) return null;
  final inNm = inKw * 1000 * 60 / (2 * math.pi * inRpm);
  final outRpm = inRpm / ratio;
  return GearResult(
    ratio: ratio,
    outRpm: outRpm,
    outTorqueNm: inNm * ratio * eff,
    outKw: inKw * eff,
  );
}

// ─────────────── 권상·컨베이어 동력 ───────────────

/// 권상(들어 올리기) 동력 P[kW] = m·g·v ÷ (1000·η). [massKg] 질량, [speed] m/s.
double? hoistPowerKw({required double massKg, required double speed, required double eff}) {
  if (massKg <= 0 || speed <= 0 || eff <= 0 || eff > 1) return null;
  return massKg * 9.80665 * speed / (1000 * eff);
}

/// 컨베이어 동력 P[kW] = F·v ÷ (1000·η), F = m·g·(μ·cosθ + sinθ). [massKg] 벨트 위 이동 질량, [mu] 마찰(저항) 계수,
/// [angleDeg] 경사각(수평 0).
double? conveyorPowerKw({
  required double massKg,
  required double speed,
  required double mu,
  required double angleDeg,
  required double eff,
}) {
  if (massKg <= 0 || speed <= 0 || mu < 0 || eff <= 0 || eff > 1) return null;
  if (angleDeg < 0 || angleDeg >= 90) return null;
  final a = angleDeg * math.pi / 180;
  final f = massKg * 9.80665 * (mu * math.cos(a) + math.sin(a));
  return f * speed / (1000 * eff);
}

// ─────────────── 소프트스타터(전압을 낮춰 기동) ───────────────

class SoftStart {
  const SoftStart({required this.motorAmps, required this.torqueRatio});

  /// 전동기 전류(= 소프트스타터 쪽 전류) = 직입 기동전류 × 전압비.
  final double motorAmps;

  /// 기동 토크 = 직입 기동 토크 × 전압비².
  final double torqueRatio;
}

/// 시작 전압 비 [voltageRatio](0~1)로 기동할 때의 전류와 토크 비. 직입 기동전류 = [ratedAmps] × [multiple].
/// 전동기 전류는 전압에 비례하고 토크는 전압의 제곱에 비례한다(소프트스타터는 직렬이라 선전류도 같다).
SoftStart? softStart({
  required double ratedAmps,
  required double multiple,
  required double voltageRatio,
}) {
  if (ratedAmps <= 0 || multiple <= 0 || voltageRatio <= 0 || voltageRatio > 1) return null;
  return SoftStart(
    motorAmps: ratedAmps * multiple * voltageRatio,
    torqueRatio: voltageRatio * voltageRatio,
  );
}

// ─────────────── 제동(감속) 에너지 ───────────────

class BrakeResult {
  const BrakeResult({required this.energyJ, required this.avgKw, required this.peakKw, this.maxOhm});

  /// 줄어든 운동 에너지(J) = ½·J·(ω1² − ω2²).
  final double energyJ;

  /// 감속 시간 동안 평균 제동 전력(kW) = E ÷ t.
  final double avgKw;

  /// 일정 토크로 감속할 때 시작 순간의 최대 제동 전력 = 평균의 2배(kW).
  final double peakKw;

  /// 제동 저항 상한 R ≤ V_dc² ÷ P_peak(Ω). 제동 개시 직류 전압을 줬을 때만.
  final double? maxOhm;
}

/// 총 관성 [j](kg·m²)의 [rpm1]에서 [rpm2](rpm)까지 [seconds]초 동안 감속할 때의 에너지와 제동 전력.
/// [vdc]는 인버터의 제동 개시 직류 전압(V). 허용 최소 저항·정격은 인버터 제조사 값을 따른다.
BrakeResult? brakeEnergy({
  required double j,
  required double rpm1,
  required double rpm2,
  required double seconds,
  double? vdc,
}) {
  if (j <= 0 || rpm1 <= 0 || rpm2 < 0 || rpm2 >= rpm1 || seconds <= 0) return null;
  final w1 = 2 * math.pi * rpm1 / 60;
  final w2 = 2 * math.pi * rpm2 / 60;
  final e = 0.5 * j * (w1 * w1 - w2 * w2);
  final avg = e / seconds / 1000;
  final peak = 2 * avg;
  return BrakeResult(
    energyJ: e,
    avgKw: avg,
    peakKw: peak,
    maxOhm: (vdc == null || vdc <= 0) ? null : vdc * vdc / (peak * 1000),
  );
}

// ─────────────── 직류 전동기 ───────────────

class DcMotor {
  const DcMotor({required this.backEmf, required this.devKw, this.torqueNm});

  /// 역기전력 Ea = V − Ia·Ra (V).
  final double backEmf;

  /// 전기자에서 기계로 바뀌는 전력 = Ea·Ia (kW).
  final double devKw;

  /// 발생 토크 = Ea·Ia ÷ ω (N·m). 회전수를 줬을 때만.
  final double? torqueNm;
}

/// 직류 전동기: [volts] 단자 전압, [ia] 전기자 전류, [ra] 전기자 저항(Ω), [rpm] 회전수(선택).
DcMotor? dcMotor({
  required double volts,
  required double ia,
  required double ra,
  double? rpm,
}) {
  if (volts <= 0 || ia <= 0 || ra < 0) return null;
  final ea = volts - ia * ra;
  if (ea <= 0) return null;
  final p = ea * ia / 1000;
  return DcMotor(
    backEmf: ea,
    devKw: p,
    torqueNm: (rpm == null || rpm <= 0) ? null : ea * ia / (2 * math.pi * rpm / 60),
  );
}

/// 직류 전동기 속도 변화: N2 = N1 × (Ea2 ÷ Ea1) × (Φ1 ÷ Φ2). [fluxRatio]는 Φ2 ÷ Φ1(계자 약화면 1 미만).
double? dcSpeedAfter({
  required double rpm1,
  required double ea1,
  required double ea2,
  double fluxRatio = 1,
}) {
  if (rpm1 <= 0 || ea1 <= 0 || ea2 <= 0 || fluxRatio <= 0) return null;
  return rpm1 * (ea2 / ea1) / fluxRatio;
}

// ─────────────── 절연 등급 ───────────────

/// 절연 등급(열적 등급) 하나. [maxC]는 IEC 60085 표 1의 최고 연속 사용 온도(원문 확인).
/// [riseK]는 IEC 60034-1:2010 표 7 항목 1a~1c 저항법 온도 상승 한계(주위 40℃, 해발 1000 m 이하, 원문 확인).
/// 600 W 미만 기계(1d)와 팬 없는 자냉식 IC40·봉입 권선 기계(1e)는 B 85·F 110·H 130 K다([riseKSmall]).
/// A·E급은 IEC 60034-1:2010 표 7에 없어 목록에서 뺐다.
class InsulationClass {
  const InsulationClass(this.name, this.maxC, this.riseK, this.note, {this.riseKSmall});
  final String name;
  final double maxC;

  /// 저항법 온도 상승 한계(K). 값을 확인하지 못했으면 null.
  final double? riseK;

  /// 600 W 미만 기계·IC40 자냉식·봉입 권선 기계(IEC 60034-1:2010 표 7 1d·1e)의 한계(K). 없으면 null.
  final double? riseKSmall;
  final String note;
}

const List<InsulationClass> kInsulation = [
  InsulationClass('B', 130, 80, '', riseKSmall: 85),
  InsulationClass(
    'F',
    155,
    105,
    '100 K라고 적은 자료는 IEC 60034-1 표 7 항목 4c(저항이 작은 계자 권선)의 값입니다. 일반 교류 권선은 105 K입니다.',
    riseKSmall: 110,
  ),
  InsulationClass('H', 180, 125, '', riseKSmall: 130),
  InsulationClass(
    'N',
    200,
    null,
    '온도 상승 한계를 확인하지 못했습니다(IEC 60034-1:2010 표 7에 없고, 2017판에 200(N)급이 더해졌다는 것까지만 확인).',
  ),
];

/// 등급 이름으로 찾기. 없으면 null.
InsulationClass? insulationByName(String name) {
  for (final c in kInsulation) {
    if (c.name == name) return c;
  }
  return null;
}

class InsulationCheck {
  const InsulationCheck({
    required this.hotTempC,
    required this.marginK,
    required this.lifeFactor,
    this.riseMarginK,
  });

  /// 권선 온도(℃) = 주위 온도 + 온도 상승.
  final double hotTempC;

  /// 등급 최고 온도와 권선 온도의 차(K). 음수면 등급 온도를 넘은 것.
  final double marginK;

  /// 수명 경험칙: 등급 온도에서의 수명을 1로 보고 10℃ 올라가면 1/2, 내려가면 2배(2^(마진 ÷ 10)).
  final double lifeFactor;

  /// 온도 상승 한계와 측정 상승의 차(K). 한계를 모르면 null.
  final double? riseMarginK;
}

/// 측정한 온도 상승 [riseK]와 주위 온도 [ambientC]를 등급과 비교한다.
InsulationCheck? insulationCheck({
  required InsulationClass cls,
  required double riseK,
  required double ambientC,
}) {
  if (riseK < 0) return null;
  final hot = ambientC + riseK;
  final margin = cls.maxC - hot;
  return InsulationCheck(
    hotTempC: hot,
    marginK: margin,
    lifeFactor: math.pow(2, margin / 10).toDouble(),
    riseMarginK: cls.riseK == null ? null : cls.riseK! - riseK,
  );
}
