// 전기 계산기 계산(화면 없음). 표는 elec_tables.dart, 전동기 값은 motor_tables.dart.
//
// 전선 굵기는 KEC 212.4.1(IB ≤ In ≤ IZ)과 232.3.9(전압강하)를 둘 다 만족하는 가장 가는 굵기.
// 전압강하는 ΔU = k·I·L·(R cosφ + X sinφ) (k: 단상·직류 2, 삼상 √3). R은 절연체 최고 온도에서의
// 저항(안전 쪽), X = 0.096 Ω/km(60Hz, Schneider EIG). 직류는 R만 쓴다.
// 한국 현장 간이식(35.6·30.8)은 역률 1·20°C라 작게 나온다.
library;

import 'dart:math' as math;

import 'elec_tables.dart';
import 'motor_tables.dart';

/// 회로 종류. [dc]는 직류 회로(125VDC 축전지·제어 전원, 24VDC 계장 등).
/// 직류 허용전류는 2가닥 통전 열(단상 교류와 같은 값)을 쓴다: BS 7671 표 4D1A 등(IEC 60364-5-52 값을
/// 옮긴 표)의 열 이름이 "2 cables, single-phase AC or DC"다(Eland Cables·Caledonian Cables 표).
enum Phase { single, three, dc }

/// 허용전류 표: 일반 배선(KS C IEC 60364-5-52) 또는 제어반 내부(IEC 60204-1 표 6).
enum AmpacityTable { iec60364, panel60204 }

double _k(Phase p) => p == Phase.three ? math.sqrt(3) : 1;

/// 부하 전류(A). [kw] 출력(전동기는 축 출력), [eff]·[pf]는 0~1. 직류는 역률을 쓰지 않는다.
double loadCurrent({
  required double kw,
  required double volts,
  required Phase phase,
  double pf = 1,
  double eff = 1,
}) {
  final w = kw * 1000;
  final p = phase == Phase.dc ? 1.0 : pf;
  final d = volts * p * eff * _k(phase);
  return d <= 0 ? 0 : w / d;
}

/// 전류(A) → 피상전력(kVA). 삼상 √3·V·I, 단상·직류 V·I.
double kvaFromCurrent({
  required double current,
  required double volts,
  required Phase phase,
}) => current * volts * _k(phase) / 1000;

/// 피상전력(kVA) → 전류(A).
double currentFromKva({
  required double kva,
  required double volts,
  required Phase phase,
}) {
  final d = volts * _k(phase);
  return d <= 0 ? 0 : kva * 1000 / d;
}

/// 마력(HP) → kW (1 HP = 745.7 W).
double hpToKw(double hp) => hp * 0.7456998715822702;

/// 보정한 허용전류(A). 표에 없거나 온도가 표를 넘으면 null.
double? correctedAmpacity({
  required double size,
  required Insulation ins,
  required Phase phase,
  required InstallMethod method,
  double ambientC = 30,
  int circuits = 1,
  GroupLayout layout = GroupLayout.bunched,
}) {
  final base = baseAmpacity(size, ins, phase == Phase.three ? 3 : 2, method);
  final kt = tempFactor(ambientC, ins, ground: isGround(method));
  if (base == null || kt == null) return null;
  return base * kt * groupFactor(circuits, layout);
}

/// 전압강하(V). [lengthM] 편도 길이. 직류는 k = 2, 리액턴스 없이 R만.
double voltageDrop({
  required double current,
  required double lengthM,
  required double size,
  required Phase phase,
  double pf = 0.85,
  double conductorTempC = 70,
}) => voltageDropR(
  current: current,
  lengthM: lengthM,
  rOhmPerKm: cuResistance(size, conductorTempC),
  phase: phase,
  pf: pf,
);

/// 저항(Ω/km)을 직접 받는 전압강하(V). AWG 전선(NEC Chapter 9 Table 8 저항)도 이 식을 쓴다.
double voltageDropR({
  required double current,
  required double lengthM,
  required double rOhmPerKm,
  required Phase phase,
  double pf = 0.85,
}) {
  final r = rOhmPerKm;
  if (phase == Phase.dc) return 2 * current * (lengthM / 1000) * r;
  final sin = math.sqrt(math.max(0, 1 - pf * pf));
  final k = phase == Phase.three ? math.sqrt(3) : 2;
  return k * current * (lengthM / 1000) * (r * pf + kReactanceOhmPerKm * sin);
}

/// 한국 현장 간이식(역률 1, 20°C, 리액턴스 없음). 비교용.
double voltageDropSimple({
  required double current,
  required double lengthM,
  required double size,
  required Phase phase,
}) => (phase == Phase.three ? 30.8 : 35.6) * lengthM * current / (1000 * size);

double conductorTemp(Insulation ins) => ins == Insulation.pvc70 ? 70 : 90;

/// 전압강하 한도(KEC 232.3.9, 100m 넘는 만큼 더 허용) 안에서 가장 긴 편도 길이(m).
double? maxLengthForDrop({
  required double current,
  required double size,
  required Phase phase,
  required double volts,
  double pf = 0.85,
  double conductorTempC = 70,
  SupplyType supply = SupplyType.lvOther,
  double? rOhmPerKm,
}) {
  if (current <= 0 || volts <= 0) return null;
  // 1m당 전압강하(%). [rOhmPerKm]가 있으면(AWG) 그 저항을 쓴다.
  final a =
      (rOhmPerKm == null
          ? voltageDrop(
              current: current,
              lengthM: 1,
              size: size,
              phase: phase,
              pf: pf,
              conductorTempC: conductorTempC,
            )
          : voltageDropR(
              current: current,
              lengthM: 1,
              rOhmPerKm: rOhmPerKm,
              phase: phase,
              pf: pf,
            )) /
      volts *
      100;
  if (a <= 0) return null;
  final base = voltageDropLimit(supply, 0);
  final l1 = base / a;
  if (l1 <= 100) return l1;
  // 100~200m: 한도 = base + 0.005(L − 100). 200m에서 더하는 0.5%가 다 찬다.
  if (a > 0.005) {
    final l2 = (base - 0.5) / (a - 0.005);
    if (l2 <= 200) return l2;
  }
  return (base + 0.5) / a;
}

/// IB 이상인 가장 작은 표준 차단기 정격. 800A 넘으면 null.
int? breakerFor(double ib) {
  for (final r in kBreakerRatings) {
    if (r >= ib - 1e-9) return r;
  }
  return null;
}

/// [a] 이하인 가장 큰 표준 차단기 정격. 가장 작은 정격보다 작으면 null.
int? breakerAtMost(double a) {
  int? out;
  for (final r in kBreakerRatings) {
    if (r <= a + 1e-9) out = r;
  }
  return out;
}

/// 전동기 회로 차단기 범위. 하한은 IB ≤ In ≤ IZ로 고른 값, 상한은 아래 셋 중 가장 작은 값 이하의
/// 표준 정격: 정격전류의 250%(NEC 430.52), 정격전류의 3배·전선 허용전류의 2.5배(구 내선규정 방식,
/// LS ELECTRIC MCCB 선정 자료 A1-124).
class MotorBreakerRange {
  final int? low;
  final int? high;
  final double highA; // 상한 계산값(A)
  final double necA; // 정격 × 2.5
  final double ratedX3A; // 정격 × 3
  final double? izX25A; // 허용전류 × 2.5
  const MotorBreakerRange({
    required this.low,
    required this.high,
    required this.highA,
    required this.necA,
    required this.ratedX3A,
    required this.izX25A,
  });
}

MotorBreakerRange motorBreakerRange({
  required double load,
  required int? low,
  double? iz,
}) {
  final nec = load * kNecInverseTimeBreakerMaxPct / 100;
  final x3 = load * kMotorBreakerMaxRatedMult;
  final izA = iz == null ? null : iz * kMotorBreakerMaxIzMult;
  final highA = [nec, x3, ?izA].reduce(math.min);
  var high = breakerAtMost(highA);
  if (high != null && low != null && high < low) high = null;
  return MotorBreakerRange(
    low: low,
    high: high,
    highA: highA,
    necA: nec,
    ratedX3A: x3,
    izX25A: izA,
  );
}

/// 다조 포설 보정에 넣는 케이블 수: 같이 포설된 회로 수 + 이 회로의 병렬 가닥(1가닥은 회로 수에 이미 들어 있다).
/// 병렬 케이블도 서로 열을 주고받으므로 가닥마다 센다(Schneider EIG 2009 G장 1.5 "taking into account
/// the mutual heating effects").
int groupCount(int circuits, int parallel) =>
    (circuits < 1 ? 1 : circuits) + (parallel < 1 ? 1 : parallel) - 1;

class CableChoice {
  final double ib; // 설계전류(= 부하 전류 × 여유), 차단기·허용전류에 쓴다
  final double load; // 실제 부하 전류, 전압강하에 쓴다
  final int? breaker; // In
  final double? sizeByAmpacity; // IZ ≥ In 을 만족하는 가장 가는 굵기
  final double? sizeByDrop; // 전압강하 한도를 만족하는 가장 가는 굵기
  final double? size; // 둘 중 굵은 것
  final double? iz; // 선정한 굵기의 보정 허용전류(병렬이면 합)
  final double? base; // 선정한 굵기의 표 값(1가닥)
  final double? dropV;
  final double? dropPct;
  final double dropLimitPct;
  final bool dropChecked; // 길이를 넣어 전압강하를 봤는지
  final double tempFactor;
  final double groupFactor;
  final int groupCount;
  final int parallel;
  final bool tempOutOfRange;
  final MotorBreakerRange? motorRange;
  final List<String> notes;
  const CableChoice({
    required this.ib,
    required this.load,
    required this.breaker,
    required this.sizeByAmpacity,
    required this.sizeByDrop,
    required this.size,
    required this.iz,
    required this.base,
    required this.dropV,
    required this.dropPct,
    required this.dropLimitPct,
    required this.dropChecked,
    required this.tempFactor,
    required this.groupFactor,
    required this.groupCount,
    required this.parallel,
    required this.tempOutOfRange,
    required this.motorRange,
    required this.notes,
  });
}

/// 표·보정 준비(선정·점검이 같이 쓴다).
class _Ampacity {
  final bool panel;
  final Insulation ins;
  final double? kt;
  final double kg;
  final int count;
  final Phase phase;
  final InstallMethod method;
  const _Ampacity(
    this.panel,
    this.ins,
    this.kt,
    this.kg,
    this.count,
    this.phase,
    this.method,
  );

  factory _Ampacity.of({
    required Insulation ins,
    required Phase phase,
    required InstallMethod method,
    required double ambientC,
    required int circuits,
    required int parallel,
    required GroupLayout layout,
    required AmpacityTable table,
  }) {
    final panel = table == AmpacityTable.panel60204;
    final i = panel ? Insulation.pvc70 : ins; // 표 6은 PVC 70°C
    final n = groupCount(circuits, parallel);
    return _Ampacity(
      panel,
      i,
      panel
          ? panelTempFactor(ambientC)
          : tempFactor(ambientC, i, ground: isGround(method)),
      panel ? panelGroupFactor(n, method) : groupFactor(n, layout),
      n,
      phase,
      method,
    );
  }

  double? base(double s) => panel
      ? panelBaseAmpacity(s, method)
      : baseAmpacity(s, ins, phase == Phase.three ? 3 : 2, method);

  /// 1가닥 보정 허용전류.
  double? one(double s) {
    final b = base(s);
    return b == null || kt == null ? null : b * kt! * kg;
  }

  List<double> get sizes => panel ? kPanelSizes : kCableSizes;

  String tempNote(double ambientC) => panel
      ? '반 내부 온도 ${_f(ambientC)}°C가 IEC 60204-1 표 D.1 범위(60°C까지)를 넘습니다.'
      : '주위 온도 ${_f(ambientC)}°C가 온도 보정계수 표 범위를 넘습니다'
            '(PVC 60°C, XLPE 80°C까지). 내열 전선이나 제조사 자료를 확인하십시오.';
}

String _f(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s;
}

/// KEC 123 6 가: 병렬로 쓰는 전선은 구리 50mm² 이상.
const double kParallelMinSize = 50;

/// 전선 굵기 선정. [load] 실제 부하 전류(전압강하), [margin] 여유 배수(전동기는 [motorMargin]).
/// 차단기·허용전류는 load × margin으로 고른다. [lengthM]이 없거나 0이면 전압강하는 보지 않는다.
/// [parallel] 병렬 가닥 수: 가닥마다 같은 굵기·길이, 50sq 이상(KEC 123), 가닥 모두 다조 포설에 센다.
CableChoice chooseCable({
  required double load,
  double margin = 1,
  required double volts,
  required Phase phase,
  required Insulation ins,
  required InstallMethod method,
  double? lengthM,
  double pf = 0.85,
  double ambientC = 30,
  int circuits = 1,
  int parallel = 1,
  GroupLayout layout = GroupLayout.bunched,
  SupplyType supply = SupplyType.lvOther,
  AmpacityTable table = AmpacityTable.iec60364,
  bool motor = false,
}) {
  final notes = <String>[];
  final n = math.max(1, parallel);
  final ib = load * margin;
  final a = _Ampacity.of(
    ins: ins,
    phase: phase,
    method: method,
    ambientC: ambientC,
    circuits: circuits,
    parallel: n,
    layout: layout,
    table: table,
  );
  final len = lengthM ?? 0;
  final checkDrop = len > 0;
  final limit = voltageDropLimit(supply, len);
  // 직류는 교류 MCCB 정격 목록으로 차단기를 고르지 않는다(직류 정격 차단기는 제조사 표). IZ ≥ IB만 본다.
  final dc = phase == Phase.dc;
  final breaker = dc ? null : breakerFor(ib);
  if (!dc && breaker == null) {
    notes.add('800A를 넘어 표준 차단기 정격 범위 밖입니다. 병렬 케이블·설계 검토가 필요합니다.');
  }
  if (a.kt == null) notes.add(a.tempNote(ambientC));
  if (a.count > 20) notes.add('다조 포설은 표 끝 20회로로 계산했습니다(입력 ${a.count}).');
  final need = (breaker ?? ib).toDouble(); // IZ ≥ In
  double? byAmp;
  double? byDrop;
  for (final s in a.sizes) {
    if (n > 1 && s < kParallelMinSize) continue;
    final one = a.one(s);
    if (byAmp == null && one != null && one * n >= need - 1e-9) byAmp = s;
    if (!checkDrop) continue;
    final dv = voltageDrop(
      current: load / n,
      lengthM: len,
      size: s,
      phase: phase,
      pf: pf,
      conductorTempC: conductorTemp(a.ins),
    );
    if (byDrop == null && volts > 0 && dv / volts * 100 <= limit + 1e-9) {
      byDrop = s;
    }
  }
  final top = a.panel ? '120' : '300';
  double? size;
  if (byAmp != null && (byDrop != null || !checkDrop)) {
    size = checkDrop ? math.max(byAmp, byDrop!) : byAmp;
  }
  if (byAmp == null && a.kt != null) {
    notes.add(
      n == 1
          ? '${top}sq 1가닥으로는 허용전류가 부족합니다. 병렬 케이블을 검토하십시오.'
          : '${top}sq $n가닥 병렬로도 허용전류가 부족합니다.',
    );
  }
  if (checkDrop && byDrop == null) {
    notes.add('${top}sq로도 전압강하 한도를 초과합니다. 길이·전압·병렬을 검토하십시오.');
  }
  double? iz;
  double? base;
  double? dv;
  if (size != null) {
    final one = a.one(size);
    iz = one == null ? null : one * n;
    base = a.base(size);
    if (checkDrop) {
      dv = voltageDrop(
        current: load / n,
        lengthM: len,
        size: size,
        phase: phase,
        pf: pf,
        conductorTempC: conductorTemp(a.ins),
      );
    }
  }
  return CableChoice(
    ib: ib,
    load: load,
    breaker: breaker,
    sizeByAmpacity: byAmp,
    sizeByDrop: byDrop,
    size: size,
    iz: iz,
    base: base,
    dropV: dv,
    dropPct: dv == null || volts <= 0 ? null : dv / volts * 100,
    dropLimitPct: limit,
    dropChecked: checkDrop,
    tempFactor: a.kt ?? 0,
    groupFactor: a.kg,
    groupCount: a.count,
    parallel: n,
    tempOutOfRange: a.kt == null,
    // 전동기 회로 차단기 범위(NEC 430.52·LS 자료)는 교류 MCCB 기준이라 직류에는 쓰지 않는다.
    motorRange: motor && !dc
        ? motorBreakerRange(load: load, low: breaker, iz: iz)
        : null,
    notes: notes,
  );
}

/// 기존 회로 점검 결과.
class CircuitCheck {
  final double size;
  final int parallel;
  final double? base; // 표 값(1가닥)
  final double? iz; // 보정 허용전류(병렬이면 합)
  final double? load;
  final double? ib; // 설계전류 = load × margin
  final int? breaker; // 넣은 차단기 정격
  final bool? ibOk; // IB ≤ In (차단기 없으면 IB ≤ IZ)
  final bool? inOk; // In ≤ IZ
  final double? dropV;
  final double? dropPct;
  final double dropLimitPct;
  final double tempFactor;
  final double groupFactor;
  final int groupCount;
  final bool tempOutOfRange;
  final MotorBreakerRange? motorRange;
  final List<String> notes;
  const CircuitCheck({
    required this.size,
    required this.parallel,
    required this.base,
    required this.iz,
    required this.load,
    required this.ib,
    required this.breaker,
    required this.ibOk,
    required this.inOk,
    required this.dropV,
    required this.dropPct,
    required this.dropLimitPct,
    required this.tempFactor,
    required this.groupFactor,
    required this.groupCount,
    required this.tempOutOfRange,
    required this.motorRange,
    required this.notes,
  });

  /// 전동기 회로에서 차단기가 허용전류보다 크지만 전동기 상한 이내인지(과부하 계전기로 보호할 때).
  bool get motorOverIzAllowed {
    final r = motorRange;
    final b = breaker;
    if (r == null || b == null || inOk != false) return false;
    return b <= r.highA + 1e-9;
  }
}

/// 이미 포설된 회로 점검: 굵기·공사 조건으로 보정 허용전류를 구하고 IB ≤ In ≤ IZ를 본다.
/// [load]·[breaker]는 없어도 된다(허용전류만 보인다).
CircuitCheck checkCircuit({
  required double size,
  double? load,
  double margin = 1,
  int? breaker,
  required double volts,
  required Phase phase,
  required Insulation ins,
  required InstallMethod method,
  double? lengthM,
  double pf = 0.85,
  double ambientC = 30,
  int circuits = 1,
  int parallel = 1,
  GroupLayout layout = GroupLayout.bunched,
  SupplyType supply = SupplyType.lvOther,
  AmpacityTable table = AmpacityTable.iec60364,
  bool motor = false,
}) {
  final notes = <String>[];
  final n = math.max(1, parallel);
  final a = _Ampacity.of(
    ins: ins,
    phase: phase,
    method: method,
    ambientC: ambientC,
    circuits: circuits,
    parallel: n,
    layout: layout,
    table: table,
  );
  if (a.kt == null) notes.add(a.tempNote(ambientC));
  if (a.count > 20) notes.add('다조 포설은 표 끝 20회로로 계산했습니다(입력 ${a.count}).');
  if (n > 1 && size < kParallelMinSize) {
    notes.add('병렬로 쓰는 전선은 구리 50sq 이상이어야 합니다(KEC 123).');
  }
  final base = a.base(size);
  if (base == null) notes.add('${sqText(size)}은 이 표에 없습니다.');
  final one = a.one(size);
  final iz = one == null ? null : one * n;
  final ib = load == null || load <= 0 ? null : load * margin;
  bool? ibOk;
  bool? inOk;
  if (ib != null && breaker != null) ibOk = ib <= breaker + 1e-9;
  if (ib != null && breaker == null && iz != null) ibOk = ib <= iz + 1e-9;
  if (breaker != null && iz != null) inOk = breaker <= iz + 1e-9;
  final len = lengthM ?? 0;
  final amps = load ?? 0;
  final checkDrop = len > 0 && amps > 0;
  final limit = voltageDropLimit(supply, checkDrop ? len : 0);
  double? dv;
  if (checkDrop) {
    dv = voltageDrop(
      current: amps / n,
      lengthM: len,
      size: size,
      phase: phase,
      pf: pf,
      conductorTempC: conductorTemp(a.ins),
    );
  }
  return CircuitCheck(
    size: size,
    parallel: n,
    base: base,
    iz: iz,
    load: load,
    ib: ib,
    breaker: breaker,
    ibOk: ibOk,
    inOk: inOk,
    dropV: dv,
    dropPct: dv == null || volts <= 0 ? null : dv / volts * 100,
    dropLimitPct: limit,
    tempFactor: a.kt ?? 0,
    groupFactor: a.kg,
    groupCount: a.count,
    tempOutOfRange: a.kt == null,
    motorRange: motor && ib != null && phase != Phase.dc
        ? motorBreakerRange(load: amps, low: breakerFor(ib), iz: iz)
        : null,
    notes: notes,
  );
}

/// 역률 개선 콘덴서 용량(kvar) = P·(tanφ1 − tanφ2).
double capacitorKvar(double kw, double pfNow, double pfTarget) {
  double tanOf(double pf) => math.sqrt(1 - pf * pf) / pf;
  if (pfNow <= 0 || pfTarget <= 0 || pfTarget <= pfNow) return 0;
  return kw * (tanOf(pfNow) - tanOf(pfTarget.clamp(0, 1)));
}

/// kvar → 정전용량(μF). 국내 저압 진상 콘덴서 표기: Qc = 2π·f·C·V²·10⁻⁹ [kvar]
/// (C: μF, V: 정격전압(선간), 삼화엔지니어링 기술자료 https://samwhaeng.kr/pro_1_01/ — 예: 380V 20μF
/// 1.089kvar, 220V 100μF 1.82kvar). 삼상 콘덴서도 이 μF 값으로 표기한다.
double capacitorMicroFarad(double kvar, double volts, {double hz = 60}) {
  if (volts <= 0 || hz <= 0) return 0;
  return kvar * 1e9 / (2 * math.pi * hz * volts * volts);
}

/// 굵기 글: 2.5 → "2.5sq", 16 → "16sq".
String sqText(double s) => '${s == s.roundToDouble() ? s.toInt() : s}sq';
