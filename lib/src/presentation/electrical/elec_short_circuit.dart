// 단락 전류 계산(화면 없음). 근거와 출처: docs/전기_단락전류_근거.md.
//
// 원문 대조: IEC 909:1988(= IS 13234:1992 무료 공개본)과 KEC 2026. c와 KT는 2016판 원문을 못 봤다.
// 주 방식은 IEC 60909 등가 전압원법(c 계수, 변압기 보정계수 KT), 비교용으로 %임피던스법(c와 KT 없이
// 공칭 전압 그대로). 구리 도체, 3상 대칭 단락, 저압(1kV 이하), 발전기 근처 단락이 아닌 경우만 다룬다.
// 최대 단락은 차단기 차단용량 선정용, 최소 단락은 보호 감도용이다. 지락(1선) 단락은 영상 임피던스가 필요해 뺐다.
library;

import 'dart:math' as math;

import 'elec_tables.dart';

/// IEC 60909-0 저압(100V~1kV) 전압 계수: 최소 단락용 cmin, 최대 단락용 cmax(허용오차 +6%, +10%).
/// 원문 못 봄: 2016판(유료) 값은 2차 자료 값이다. 1988판(IS 13234:1992 표 I)은 230/400V가 cmax 1.00·cmin 0.95,
/// 그 밖의 저압이 cmax 1.05·cmin 1.00이라 지금 값과 다르다. docs/전기_단락전류_근거.md.
const double kScCMin = 0.95;
const double kScCMax6 = 1.05;
const double kScCMax10 = 1.10;

/// 상위 계통 임피던스 분해: X = 0.995 Z, R = 0.1 X (IEC 909:1988 = IS 13234:1992 8.3.2.1).
const double kScNetX = 0.995;
const double kScNetRoverX = 0.1;

/// 저압 전동기 묶음(IEC 909:1988 = IS 13234:1992 8.3.2.5·13장): ILR/IrM = 5(화면 권장값), RM/XM = 0.42, κM = 1.3.
const double kScMotorRoverX = 0.42;
const double kScMotorKappa = 1.3;

/// 원문 권장 기여 배수 ILR/IrM(저압 전동기 묶음). 칸을 자동으로 채우지는 않는다.
const double kScMotorMultipleGuide = 5;

/// 최소 단락 케이블 저항 온도계수(1/°C). IEC 909:1988 = IS 13234:1992 9.3.1 식 (32):
/// R_L = [1 + 0.004/°C × (θe − 20°C)] × R_L20.
const double kScMinAlpha = 0.004;

/// 단열 계산이 성립하는 차단 시간 상한(초). KEC 212.5.5 식 212.5-1.
const double kScAdiabaticMaxSec = 5;

/// 이 시간보다 짧으면 차단기가 순시 영역에서 끊는 것으로 보고 제조사 통과 에너지(I²t) 확인을 권한다(초).
const double kScShortSec = 0.1;

/// 구리 도체 k(초기·최종 온도): PVC 300mm² 이하 115(70→160°C), XLPE·EPR 143(90→250°C). KEC 표 212.5-1.
double cableK(Insulation ins) => ins == Insulation.pvc70 ? 115 : 143;

/// 최소 단락에서 케이블 저항을 잡는 도체 온도 θe: 단락이 끝날 때의 온도(IEC 909 9.3.1).
/// 절연체의 단락 최종 온도(KEC 표 212.5-1: PVC 300mm² 이하 160°C, XLPE·EPR 250°C)를 쓴다.
double minScConductorTemp(Insulation ins) =>
    ins == Insulation.pvc70 ? 160 : 250;

/// 최소 단락용 구리 저항(Ω/km): R20 × (1 + 0.004 × (θe − 20)).
double minScResistance(double sizeMm2, double thetaE) =>
    kCuR20[sizeMm2]! * (1 + kScMinAlpha * (thetaE - 20));

/// 저항·리액턴스 한 쌍(Ω).
class ScZ {
  const ScZ(this.r, this.x);
  final double r;
  final double x;
  ScZ operator +(ScZ o) => ScZ(r + o.r, x + o.x);
  ScZ scale(double k) => ScZ(r * k, x * k);
  double get abs => math.sqrt(r * r + x * x);
}

/// 변압기 임피던스 보정계수 KT = 0.95·cmax / (1 + 0.6·xT). xT = XT / (U²/S) (정격 기준 리액턴스).
/// 원문 못 봄(2016판 유료): pandapower 논문 식 (5)·ECalPro 문서 값.
double transformerKt(double cMax, double xT) => 0.95 * cMax / (1 + 0.6 * xT);

/// 피크 전류 계수 κ = 1.02 + 0.98·e^(−3R/X) (IEC 909:1988 = IS 13234:1992 9.1.1.2).
double peakKappa(double rOverX) => 1.02 + 0.98 * math.exp(-3 * rOverX);

/// 케이블 구간 하나(편도 길이, 병렬 가닥 수).
class ScSegment {
  const ScSegment({
    required this.sizeMm2,
    required this.lengthM,
    this.parallel = 1,
  });
  final double sizeMm2;
  final double lengthM;
  final int parallel;

  /// 도체 온도 [tempC]에서의 임피던스. 병렬이면 저항·리액턴스를 가닥 수로 나눈다(상호 리액턴스는 뺌).
  ScZ z(double tempC) => ScZ(
    cuResistance(sizeMm2, tempC) * lengthM / 1000 / parallel,
    kReactanceOhmPerKm * lengthM / 1000 / parallel,
  );

  /// 최소 단락용 임피던스: 저항은 단락 종료 온도 [thetaE]에서 온도계수 0.004로 올린다(IEC 909 식 32).
  ScZ zMin(double thetaE) => ScZ(
    minScResistance(sizeMm2, thetaE) * lengthM / 1000 / parallel,
    kReactanceOhmPerKm * lengthM / 1000 / parallel,
  );
}

/// 전동기 임피던스 |ZM| = Un ÷ (√3 × 배수 × IrM)를 RM/XM = 0.42로 나눈다.
ScZ motorImpedance(double zMAbs) {
  final x = zMAbs / math.sqrt(1 + kScMotorRoverX * kScMotorRoverX);
  return ScZ(kScMotorRoverX * x, x);
}

/// 계산 입력. 선택 칸은 null이면 "넣지 않음"이다.
class ScInput {
  const ScInput({
    required this.kva,
    required this.volts,
    required this.zPercent,
    this.pcuKw,
    this.upstreamMvaMax,
    this.upstreamMvaMin,
    this.motorKw,
    this.motorEffPf,
    this.motorMultiple,
    this.cMax = kScCMax6,
    this.insulation = Insulation.pvc70,
    this.segments = const [],
  });

  final double kva;
  final double volts;
  final double zPercent;

  /// 변압기 부하손(kW, 명판). null이면 순리액턴스로 본다.
  final double? pcuKw;

  /// 상위 계통 단락용량(MVA). 최대 단락용, 최소 단락용. null이면 무한 전원(최대) 또는 최대용 값(최소).
  final double? upstreamMvaMax;
  final double? upstreamMvaMin;

  /// 저압 전동기 합계 kW, 효율×역률(0~1), 기여 배수(기동전류/정격전류).
  final double? motorKw;
  final double? motorEffPf;
  final double? motorMultiple;

  final double cMax;
  final Insulation insulation;
  final List<ScSegment> segments;
}

class ScResult {
  const ScResult({
    this.errors = const [],
    this.notes = const [],
    this.ikMaxA = 0,
    this.ikNetA = 0,
    this.ikMotorA = 0,
    this.ikPercentZA = 0,
    this.kappa = 1,
    this.rOverX = 0,
    this.ipA = 0,
    this.startIpA = const [],
    this.startIkMaxA = const [],
    this.ikMin3A = 0,
    this.ikMin2A = 0,
    this.kT = 1,
    this.ztOhm = 0,
    this.rtOhm = 0,
    this.motorRatedA = 0,
    this.motorsIncluded = false,
    this.infiniteSource = false,
    this.minUsesMaxUpstream = false,
    this.hasLoss = false,
  });

  /// 입력 오류(있으면 나머지 값은 쓰지 않는다).
  final List<String> errors;

  /// 결과와 함께 보일 경고·안내.
  final List<String> notes;

  /// Ik″ 최대(A): IEC 60909, 전동기 포함.
  final double ikMaxA;

  /// 그중 상위 계통·변압기에서 오는 것과 전동기에서 오는 것(A).
  final double ikNetA;
  final double ikMotorA;

  /// 같은 조건을 %임피던스법으로 계산한 값(A).
  final double ikPercentZA;

  /// 피크 전류 계수 κ, 고장점 R/X, 피크 전류 ip(A).
  final double kappa;
  final double rOverX;
  final double ipA;

  /// 구간 앞뒤 자리마다의 피크 전류(A). [startIkMaxA]와 같은 자리 번호.
  final List<double> startIpA;

  /// 구간 i의 시작점(= 앞 구간 i개를 지난 자리)에서 Ik″ 최대(A). 길이는 구간 수 + 1이고 마지막이 고장점 값.
  /// 케이블 열 견딤은 이 구간 시작점 값을 쓴다: 케이블 시작점이 전류가 가장 크다.
  final List<double> startIkMaxA;

  /// 최소 단락 3상, 2상(A).
  final double ikMin3A;
  final double ikMin2A;

  final double kT;
  final double ztOhm;
  final double rtOhm;
  final double motorRatedA;
  final bool motorsIncluded;
  final bool infiniteSource;
  final bool minUsesMaxUpstream;
  final bool hasLoss;

  bool get ok => errors.isEmpty;
}

bool _pos(double? v) => v != null && v.isFinite && v > 0;

/// 입력 검사. 오류 글 목록(비면 계산 가능).
List<String> validateShortCircuit(ScInput i) {
  final e = <String>[];
  if (!_pos(i.kva)) e.add('변압기 용량(kVA)은 0보다 커야 합니다.');
  if (!_pos(i.volts)) e.add('2차 전압(V)은 0보다 커야 합니다.');
  if (!_pos(i.zPercent) || i.zPercent >= 100) {
    e.add('%Z는 0보다 크고 100보다 작아야 합니다.');
  }
  if (i.cMax != kScCMax6 && i.cMax != kScCMax10) {
    e.add('전압 허용오차 선택이 올바르지 않습니다.');
  }
  final zOk = _pos(i.kva) && _pos(i.zPercent) && i.zPercent < 100;
  if (i.pcuKw != null) {
    if (!i.pcuKw!.isFinite || i.pcuKw! < 0) {
      e.add('부하손(kW)은 0 이상이어야 합니다.');
    } else if (zOk && i.pcuKw! >= i.kva * i.zPercent / 100) {
      e.add('부하손이 너무 큽니다. 부하손 kW ÷ 용량 kVA는 %Z ÷ 100보다 작아야 합니다.');
    }
  }
  if (i.upstreamMvaMax != null && !_pos(i.upstreamMvaMax)) {
    e.add('상위 계통 단락용량(MVA)은 0보다 커야 합니다.');
  }
  if (i.upstreamMvaMin != null && !_pos(i.upstreamMvaMin)) {
    e.add('상위 계통 최소 단락용량(MVA)은 0보다 커야 합니다.');
  }
  if (_pos(i.upstreamMvaMax) &&
      _pos(i.upstreamMvaMin) &&
      i.upstreamMvaMin! > i.upstreamMvaMax!) {
    e.add('최소 단락용량이 최대 단락용량보다 큽니다.');
  }
  if (i.motorKw != null && !_pos(i.motorKw)) {
    e.add('전동기 합계 kW는 0보다 커야 합니다.');
  }
  if (i.motorEffPf != null &&
      (!i.motorEffPf!.isFinite || i.motorEffPf! <= 0 || i.motorEffPf! > 1)) {
    e.add('전동기 효율×역률은 0보다 크고 1 이하여야 합니다.');
  }
  if (i.motorMultiple != null && !_pos(i.motorMultiple)) {
    e.add('전동기 기여 배수는 0보다 커야 합니다.');
  }
  for (var n = 0; n < i.segments.length; n++) {
    final s = i.segments[n];
    if (!kCuR20.containsKey(s.sizeMm2)) {
      e.add('구간 ${n + 1}: 표에 없는 굵기입니다.');
    }
    if (!_pos(s.lengthM)) e.add('구간 ${n + 1}: 편도 길이(m)는 0보다 커야 합니다.');
    if (s.parallel < 1 || s.parallel > 10) {
      e.add('구간 ${n + 1}: 병렬 가닥 수는 1~10이어야 합니다.');
    }
  }
  return e;
}

/// 3상 대칭 단락전류(최대·최소). 입력이 틀리면 [ScResult.errors]만 채워 돌려준다.
ScResult calcShortCircuit(ScInput i) {
  final errors = validateShortCircuit(i);
  if (errors.isNotEmpty) return ScResult(errors: errors);

  final u = i.volts;
  final s3 = math.sqrt(3);
  final zBase = u * u / (i.kva * 1000); // 변압기 정격 임피던스(Ω), 2차 쪽
  final zt = i.zPercent / 100 * zBase;
  final hasLoss = i.pcuKw != null;
  final rt = hasLoss ? i.pcuKw! / i.kva * zBase : 0.0;
  final xt = math.sqrt(zt * zt - rt * rt);
  final kT = transformerKt(i.cMax, xt / zBase);
  final n = i.segments.length;
  final notes = <String>[];

  // 케이블 누적 임피던스(20°C): [k]는 앞 구간 k개까지 더한 값.
  ScZ cum20(int k) {
    var z = const ScZ(0, 0);
    for (var j = 0; j < k; j++) {
      z += i.segments[j].z(20);
    }
    return z;
  }

  // 상위 계통: Z = c·U²/S, X = 0.995 Z, R = 0.1 X. c는 호출하는 쪽에서 곱한다(cFactor).
  ScZ network(double? mva, double cFactor) {
    if (mva == null) return const ScZ(0, 0);
    final z = cFactor * u * u / (mva * 1e6);
    final x = kScNetX * z;
    return ScZ(kScNetRoverX * x, x);
  }

  // 전동기: |ZM| = Un ÷ (√3 × 배수 × IrM), RM/XM = 0.42(IEC 909 8.3.2.5).
  final motorsIncluded =
      _pos(i.motorKw) && _pos(i.motorEffPf) && _pos(i.motorMultiple);
  var motorRatedA = 0.0;
  var zM = const ScZ(0, 0);
  if (motorsIncluded) {
    motorRatedA = i.motorKw! * 1000 / (s3 * u * i.motorEffPf!);
    zM = motorImpedance(u / (s3 * i.motorMultiple! * motorRatedA));
  }

  // ── 최대 단락(IEC 60909): c = cmax, 케이블 저항 20°C, 전동기 포함.
  final cMax = i.cMax;
  final srcMax = network(i.upstreamMvaMax, cMax) + ScZ(rt, xt).scale(kT);
  final netMax = <double>[];
  final motMax = <double>[];
  for (var k = 0; k <= n; k++) {
    final cab = cum20(k);
    netMax.add(cMax * u / (s3 * (srcMax + cab).abs));
    motMax.add(motorsIncluded ? cMax * u / (s3 * (zM + cab).abs) : 0.0);
  }
  final startMax = [for (var k = 0; k <= n; k++) netMax[k] + motMax[k]];
  final startIp = <double>[];
  var rOverX = 0.0;
  var kappa = 1.0;
  for (var k = 0; k <= n; k++) {
    final z = srcMax + cum20(k);
    rOverX = z.r / z.x;
    kappa = peakKappa(rOverX);
    startIp.add(
      kappa * math.sqrt2 * netMax[k] + kScMotorKappa * math.sqrt2 * motMax[k],
    );
  }

  // ── 비교: %임피던스법(c와 KT 없음, 공칭 전압 그대로).
  final srcPct = network(i.upstreamMvaMax, 1) + ScZ(rt, xt);
  final cabF = cum20(n);
  final pctNet = u / (s3 * (srcPct + cabF).abs);
  final pctMot = motorsIncluded ? u / (s3 * (zM + cabF).abs) : 0.0;

  // ── 최소 단락: c = cmin, 케이블 저항은 단락 종료 온도 θe에서 0.004/°C(IEC 909 식 32), 전동기 뺌,
  // 상위 계통은 최소 용량.
  final minMva = i.upstreamMvaMin ?? i.upstreamMvaMax;
  final srcMin = network(minMva, kScCMin) + ScZ(rt, xt).scale(kT);
  final thetaE = minScConductorTemp(i.insulation);
  var cabMin = const ScZ(0, 0);
  for (final s in i.segments) {
    cabMin += s.zMin(thetaE);
  }
  final min3 = kScCMin * u / (s3 * (srcMin + cabMin).abs);
  final min2 = min3 * s3 / 2;

  // ── 경고·안내.
  final infinite = i.upstreamMvaMax == null;
  if (infinite) {
    notes.add('상위 계통 단락용량을 넣지 않아 무한 전원으로 계산했습니다. 최대값이며 실제보다 큽니다(안전 쪽).');
  }
  if (!hasLoss) {
    notes.add(
      '부하손을 넣지 않아 변압기 저항을 0으로 봤습니다. 최대 단락(시험한 예에서 최대 약 15%)과 피크 전류(최대 약 50%)는'
      ' 실제보다 크게 나와 안전 쪽입니다. 최소 단락도 실제보다 크게 나오므로 안전 쪽이 아닙니다.',
    );
  }
  final anyMotorInput =
      i.motorKw != null || i.motorEffPf != null || i.motorMultiple != null;
  if (anyMotorInput && !motorsIncluded) {
    notes.add(
      '전동기 세 칸(합계 kW, 효율×역률, 기여 배수)이 다 차야 반영됩니다. 지금은 전동기 기여를 빼고 계산했습니다(안전 쪽 아님).',
    );
  }
  if (!anyMotorInput) {
    notes.add('전동기 기여를 넣지 않았습니다. 전동기가 많으면 최대 단락이 실제보다 작게 나옵니다(안전 쪽 아님).');
  }
  final minUsesMax = i.upstreamMvaMin == null;
  if (minUsesMax) {
    notes.add(
      i.upstreamMvaMax == null
          ? '최소 단락도 무한 전원으로 계산해 실제 최소값보다 큽니다(안전 쪽 아님). 상위 계통 최소 단락용량을 넣으십시오.'
          : '상위 계통 최소 단락용량을 넣지 않아 최소 단락에도 최대용 값을 썼습니다. 실제 최소값은 더 작을 수 있습니다(안전 쪽 아님).',
    );
  }
  if (i.segments.any((s) => s.sizeMm2 >= 150)) {
    notes.add(
      '150mm² 이상 케이블의 표피 효과(교류 저항 증가)는 넣지 않았습니다. 최소 단락에서는 실제보다 조금 크게 나옵니다.',
    );
  }
  if (i.segments.any((s) => s.parallel > 1)) {
    notes.add('병렬 가닥은 저항·리액턴스를 가닥 수로 나눴습니다. 가닥 사이 상호 리액턴스는 뺐습니다.');
  }

  return ScResult(
    notes: notes,
    ikMaxA: startMax[n],
    ikNetA: netMax[n],
    ikMotorA: motMax[n],
    ikPercentZA: pctNet + pctMot,
    kappa: kappa,
    rOverX: rOverX,
    ipA: startIp[n],
    startIpA: startIp,
    startIkMaxA: startMax,
    ikMin3A: min3,
    ikMin2A: min2,
    kT: kT,
    ztOhm: zt,
    rtOhm: rt,
    motorRatedA: motorRatedA,
    motorsIncluded: motorsIncluded,
    infiniteSource: infinite,
    minUsesMaxUpstream: minUsesMax,
    hasLoss: hasLoss,
  );
}

/// 차단용량(kA) ≥ 단락전류(kA)이면 합격. 같으면 합격.
bool breakingOk(double ratingKa, double ikKa) => ratingKa >= ikKa;

/// 케이블 열 견딤(I²t) 결과. 단면적·전류는 도체 한 가닥 기준이다.
class CableWithstand {
  const CableWithstand({
    required this.k,
    required this.sMinMm2,
    required this.sMm2,
    required this.ok,
    required this.tMaxSec,
    required this.ikPerConductorA,
    required this.allowedA2s,
    this.letThroughOk,
  });

  final double k;

  /// 필요한 최소 단면적 S = Ik·√t / k (mm²).
  final double sMinMm2;
  final double sMm2;
  final bool ok;

  /// 이 전류에서 허용 최대 시간 t = (k·S/Ik)² (초).
  final double tMaxSec;
  final double ikPerConductorA;

  /// 회로 전체 허용 통과 에너지 (병렬 가닥 수)²·k²·S² (A²s).
  final double allowedA2s;

  /// 차단기 통과 에너지를 넣었을 때만: 허용 이내인지.
  final bool? letThroughOk;
}

/// [ikA] 케이블 시작점의 단락전류(회로 전체, A). 병렬이면 가닥마다 같이 나눠 흐른다고 본다.
/// [tSec] 차단 시간, [letThroughA2s] 차단기 통과 에너지(회로 전체, 선택). 잘못된 입력이면 null.
CableWithstand? cableWithstand({
  required double sizeMm2,
  required Insulation insulation,
  required double ikA,
  required double tSec,
  int parallel = 1,
  double? letThroughA2s,
}) {
  if (!(sizeMm2 > 0) || !(ikA > 0) || !(tSec > 0) || parallel < 1) return null;
  if (letThroughA2s != null && !(letThroughA2s > 0)) return null;
  final k = cableK(insulation);
  final ikc = ikA / parallel;
  final sMin = ikc * math.sqrt(tSec) / k;
  final tMax = math.pow(k * sizeMm2 / ikc, 2).toDouble();
  final allowed = parallel * parallel * k * k * sizeMm2 * sizeMm2;
  return CableWithstand(
    k: k,
    sMinMm2: sMin,
    sMm2: sizeMm2,
    ok: sizeMm2 >= sMin - 1e-9,
    tMaxSec: tMax,
    ikPerConductorA: ikc,
    allowedA2s: allowed,
    letThroughOk: letThroughA2s == null
        ? null
        : letThroughA2s <= allowed + 1e-6,
  );
}
