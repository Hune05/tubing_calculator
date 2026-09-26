// 전기 기초 계산(화면 없음): 옴의 법칙·전력, 교류 전력, Y·Δ 결선, 전력량, 도체 저항, 주파수.
// 물리 식만 쓴다. 표 값은 도체 고유저항·온도계수뿐(아래 출처).
library;

import 'dart:math' as math;

/// 옴의 법칙 결과. [from]은 계산에 쓴 두 값의 이름(V·I·R·P 중).
class OhmResult {
  final double v;
  final double i;
  final double r;
  final double p;
  final List<String> from;
  const OhmResult(this.v, this.i, this.r, this.p, this.from);
}

/// V·I·R·P 중 앞에서부터 두 값으로 나머지를 계산한다(V = I·R, P = V·I).
/// 0보다 큰 값이 둘 미만이면 null.
OhmResult? ohmLaw({double? v, double? i, double? r, double? p}) {
  bool ok(double? x) => x != null && x > 0 && x.isFinite;
  final given = <String>[
    if (ok(v)) 'V',
    if (ok(i)) 'I',
    if (ok(r)) 'R',
    if (ok(p)) 'P',
  ];
  if (given.length < 2) return null;
  final a = given[0];
  final b = given[1];
  final pair = '$a$b';
  late double vv, ii, rr, pp;
  switch (pair) {
    case 'VI':
      vv = v!;
      ii = i!;
      rr = vv / ii;
      pp = vv * ii;
    case 'VR':
      vv = v!;
      rr = r!;
      ii = vv / rr;
      pp = vv * vv / rr;
    case 'VP':
      vv = v!;
      pp = p!;
      ii = pp / vv;
      rr = vv * vv / pp;
    case 'IR':
      ii = i!;
      rr = r!;
      vv = ii * rr;
      pp = ii * ii * rr;
    case 'IP':
      ii = i!;
      pp = p!;
      vv = pp / ii;
      rr = pp / (ii * ii);
    default: // RP
      rr = r!;
      pp = p!;
      ii = math.sqrt(pp / rr);
      vv = math.sqrt(pp * rr);
  }
  return OhmResult(vv, ii, rr, pp, [a, b]);
}

/// 교류 전력. kW(유효)·kvar(무효)·kVA(피상)·A(선전류).
class AcPower {
  final double kw;
  final double kvar;
  final double kva;
  final double amps;
  final double pf;
  const AcPower(this.kw, this.kvar, this.kva, this.amps, this.pf);

  /// 위상각(도).
  double get angleDeg => math.acos(pf.clamp(0.0, 1.0)) * 180 / math.pi;
}

double _k(bool three) => three ? math.sqrt(3) : 1;

/// 선간전압 [volts]·선전류 [amps]·역률 [pf](0~1) → 전력. 삼상 S = √3·V·I, 단상 S = V·I.
AcPower acPowerFromCurrent({
  required double volts,
  required double amps,
  required double pf,
  required bool three,
}) {
  final kva = _k(three) * volts * amps / 1000;
  final kw = kva * pf;
  final kvar = math.sqrt(math.max(0, kva * kva - kw * kw));
  return AcPower(kw, kvar, kva, amps, pf);
}

/// 유효전력 [kw]·역률 [pf] → 피상·무효전력과 선전류.
AcPower acPowerFromKw({
  required double kw,
  required double pf,
  required double volts,
  required bool three,
}) {
  final kva = pf <= 0 ? 0.0 : kw / pf;
  final kvar = math.sqrt(math.max(0, kva * kva - kw * kw));
  final d = _k(three) * volts;
  return AcPower(kw, kvar, kva, d <= 0 ? 0 : kva * 1000 / d, pf);
}

/// Y(성형)·Δ(삼각) 결선의 선간 값 ↔ 상 값.
class StarDelta {
  final double? lineV;
  final double? phaseV;
  final double? lineI;
  final double? phaseI;
  const StarDelta(this.lineV, this.phaseV, this.lineI, this.phaseI);
}

/// [star] Y 결선이면 V선 = √3·V상, I선 = I상. Δ 결선이면 V선 = V상, I선 = √3·I상.
/// [fromLine]이 참이면 [volts]·[amps]는 선간 값, 아니면 상 값.
StarDelta starDelta({
  required bool star,
  required bool fromLine,
  double? volts,
  double? amps,
}) {
  final r3 = math.sqrt(3);
  double? lv, pv, li, pi;
  if (volts != null) {
    if (fromLine) {
      lv = volts;
      pv = star ? volts / r3 : volts;
    } else {
      pv = volts;
      lv = star ? volts * r3 : volts;
    }
  }
  if (amps != null) {
    if (fromLine) {
      li = amps;
      pi = star ? amps : amps / r3;
    } else {
      pi = amps;
      li = star ? amps : amps * r3;
    }
  }
  return StarDelta(lv, pv, li, pi);
}

/// 전력량(kWh) = kW × 하루 사용 시간 × 일수.
double energyKwh(double kw, double hoursPerDay, double days) =>
    kw * hoursPerDay * days;

/// 도체 재질.
enum ConductorMetal { copper, aluminium }

/// 20°C 고유저항(Ω·mm²/m)과 온도계수(1/°C): IEC 60287-1-1 표 1
/// (구리 1.7241×10⁻⁸ Ω·m·3.93×10⁻³, 알루미늄 2.8264×10⁻⁸ Ω·m·4.03×10⁻³).
/// 확인: Cableizer 문서(https://www.cableizer.com/documentation/rho_c/, /alpha_c/)와
/// IEE-Business 고유저항 계산기(IEC 60028 구리 1.724×10⁻⁸·0.00393, IEC 60889 알루미늄 2.828×10⁻⁸·0.00403).
const double kRhoCu20 = 0.017241;
const double kRhoAl20 = 0.028264;
const double kAlphaCu = 0.00393;
const double kAlphaAl = 0.00403;

double rho20(ConductorMetal m) =>
    m == ConductorMetal.copper ? kRhoCu20 : kRhoAl20;
double alpha20(ConductorMetal m) =>
    m == ConductorMetal.copper ? kAlphaCu : kAlphaAl;

/// 도체 저항(Ω) R = ρ20 × L ÷ A × (1 + α(θ − 20)). [areaMm2] mm², [lengthM] m, [tempC] 도체 온도.
double conductorResistance({
  required ConductorMetal metal,
  required double areaMm2,
  required double lengthM,
  double tempC = 20,
}) {
  if (areaMm2 <= 0) return 0;
  return rho20(metal) * lengthM / areaMm2 * (1 + alpha20(metal) * (tempC - 20));
}

/// 직렬 합성 저항.
double seriesResistance(List<double> rs) => rs.fold(0.0, (a, b) => a + b);

/// 병렬 합성 저항. 0 이하 값이 있으면 0.
double parallelResistance(List<double> rs) {
  if (rs.isEmpty || rs.any((r) => r <= 0)) return 0;
  return 1 / rs.fold(0.0, (a, b) => a + 1 / b);
}

/// 주기(초) T = 1/f.
double periodSec(double hz) => hz <= 0 ? 0 : 1 / hz;

/// 각주파수(rad/s) ω = 2πf.
double angularFreq(double hz) => 2 * math.pi * hz;

/// 동기속도(rpm) ns = 120f/p. [poles] 극수.
double syncSpeedRpm(double hz, int poles) => poles <= 0 ? 0 : 120 * hz / poles;

/// 슬립 s = (ns − n)/ns (0~1, 음수면 동기속도보다 빠름).
double slip(double syncRpm, double rpm) =>
    syncRpm <= 0 ? 0 : (syncRpm - rpm) / syncRpm;

/// 동기발전기 주파수(Hz) f = p·n/120.
double generatorHz(int poles, double rpm) => poles * rpm / 120;

/// 유도성 리액턴스(Ω) XL = 2πfL. [henry] H.
double inductiveReactance(double hz, double henry) => 2 * math.pi * hz * henry;

/// 용량성 리액턴스(Ω) XC = 1/(2πfC). [farad] F.
double capacitiveReactance(double hz, double farad) =>
    hz <= 0 || farad <= 0 ? 0 : 1 / (2 * math.pi * hz * farad);

/// 공진 주파수(Hz) f0 = 1/(2π√(LC)).
double resonanceHz(double henry, double farad) =>
    henry <= 0 || farad <= 0 ? 0 : 1 / (2 * math.pi * math.sqrt(henry * farad));
