// 전기 계산기 계산(화면 없음). 표는 elec_tables.dart.
//
// 전선 굵기는 KEC 212.4.1(IB ≤ In ≤ IZ)과 232.3.9(전압강하)를 둘 다 만족하는 가장 가는 굵기.
// 전압강하는 ΔU = k·I·L·(R cosφ + X sinφ) (k: 단상 2, 삼상 √3) — R은 절연체 최고 온도에서의
// 저항(안전 쪽), X = 0.08 Ω/km. 한국 현장 간이식(35.6·30.8)은 역률 1·20°C라 작게 나온다.
library;

import 'dart:math' as math;

import 'elec_tables.dart';

enum Phase { single, three }

/// 허용전류 표: 일반 배선(KS C IEC 60364-5-52) 또는 제어반 내부(IEC 60204-1 표 6).
enum AmpacityTable { iec60364, panel60204 }

/// 부하 전류(A). [kw] 출력(전동기는 축 출력), [eff]·[pf]는 0~1.
double loadCurrent({
  required double kw,
  required double volts,
  required Phase phase,
  double pf = 1,
  double eff = 1,
}) {
  final w = kw * 1000;
  final d = volts * pf * eff * (phase == Phase.three ? math.sqrt(3) : 1);
  return d <= 0 ? 0 : w / d;
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

/// 전압강하(V). [lengthM] 편도 길이.
double voltageDrop({
  required double current,
  required double lengthM,
  required double size,
  required Phase phase,
  double pf = 0.85,
  double conductorTempC = 70,
}) {
  final r = cuResistance(size, conductorTempC); // Ω/km
  final sin = math.sqrt(math.max(0, 1 - pf * pf));
  final k = phase == Phase.three ? math.sqrt(3) : 2;
  return k * current * (lengthM / 1000) * (r * pf + kReactanceOhmPerKm * sin);
}

/// 한국 현장 간이식(역률 1, 20°C, 리액턴스 없음) — 비교용.
double voltageDropSimple({
  required double current,
  required double lengthM,
  required double size,
  required Phase phase,
}) => (phase == Phase.three ? 30.8 : 35.6) * lengthM * current / (1000 * size);

double conductorTemp(Insulation ins) => ins == Insulation.pvc70 ? 70 : 90;

/// IB 이상인 가장 작은 표준 차단기 정격. 800A 넘으면 null.
int? breakerFor(double ib) {
  for (final r in kBreakerRatings) {
    if (r >= ib - 1e-9) return r;
  }
  return null;
}

class CableChoice {
  final double ib; // 설계 전류(= 부하 전류 × 여유), 차단기·허용전류에 쓴다
  final double load; // 실제 부하 전류, 전압강하에 쓴다
  final int? breaker; // In
  final double? sizeByAmpacity; // IZ ≥ In 을 만족하는 가장 가는 굵기
  final double? sizeByDrop; // 전압강하 한도를 만족하는 가장 가는 굵기
  final double? size; // 둘 중 굵은 것
  final double? iz; // 고른 굵기의 보정 허용전류
  final double? dropV;
  final double? dropPct;
  final double dropLimitPct;
  final double tempFactor;
  final double groupFactor;
  final List<String> notes;
  const CableChoice({
    required this.ib,
    required this.load,
    required this.breaker,
    required this.sizeByAmpacity,
    required this.sizeByDrop,
    required this.size,
    required this.iz,
    required this.dropV,
    required this.dropPct,
    required this.dropLimitPct,
    required this.tempFactor,
    required this.groupFactor,
    required this.notes,
  });
}

/// 전선 굵기 고르기. [load] 실제 부하 전류(전압강하), [margin] 여유 배수 — 연속 운전 전동기는
/// 1.25(NEC 430.22·예전 내선규정). 차단기·허용전류는 load × margin으로 고른다.
CableChoice chooseCable({
  required double load,
  double margin = 1,
  required double volts,
  required Phase phase,
  required Insulation ins,
  required InstallMethod method,
  required double lengthM,
  double pf = 0.85,
  double ambientC = 30,
  int circuits = 1,
  GroupLayout layout = GroupLayout.bunched,
  SupplyType supply = SupplyType.lvOther,
  AmpacityTable table = AmpacityTable.iec60364,
}) {
  final notes = <String>[];
  final ib = load * margin;
  final panel = table == AmpacityTable.panel60204;
  if (panel) ins = Insulation.pvc70; // 표 6은 PVC 70°C
  final kt = panel
      ? panelTempFactor(ambientC)
      : tempFactor(ambientC, ins, ground: isGround(method));
  final kg = panel
      ? panelGroupFactor(circuits, method)
      : groupFactor(circuits, layout);
  double? izOf(double s) {
    if (!panel) {
      return correctedAmpacity(
        size: s,
        ins: ins,
        phase: phase,
        method: method,
        ambientC: ambientC,
        circuits: circuits,
        layout: layout,
      );
    }
    final b = panelBaseAmpacity(s, method);
    return b == null || kt == null ? null : b * kt * kg;
  }

  final limit = voltageDropLimit(supply, lengthM);
  final breaker = breakerFor(ib);
  if (breaker == null) notes.add('800A가 넘어 표준 차단기 목록 밖입니다. 병렬 케이블·설계 검토가 필요합니다.');
  if (kt == null) {
    notes.add(panel
        ? '반 안 온도가 IEC 60204-1 표 D.1(60°C까지)을 넘습니다.'
        : '주위 온도가 이 절연체의 보정표를 넘습니다(PVC 60°C, XLPE 80°C까지).');
  }
  final need = (breaker ?? ib).toDouble(); // IZ ≥ In
  double? byAmp;
  double? byDrop;
  for (final s in panel ? kPanelSizes : kCableSizes) {
    final iz = izOf(s);
    if (byAmp == null && iz != null && iz >= need - 1e-9) byAmp = s;
    final dv = voltageDrop(
      current: load,
      lengthM: lengthM,
      size: s,
      phase: phase,
      pf: pf,
      conductorTempC: conductorTemp(ins),
    );
    if (byDrop == null && volts > 0 && dv / volts * 100 <= limit + 1e-9) {
      byDrop = s;
    }
  }
  double? size;
  if (byAmp != null && byDrop != null) size = math.max(byAmp, byDrop);
  if (byAmp == null) notes.add('${panel ? '120' : '300'}mm² 한 가닥으로는 허용전류가 모자랍니다. 병렬 케이블을 검토하십시오.');
  if (byDrop == null) notes.add('${panel ? '120' : '300'}mm²로도 전압강하 한도를 넘습니다. 길이·전압·병렬을 검토하십시오.');
  double? iz;
  double? dv;
  if (size != null) {
    iz = izOf(size);
    dv = voltageDrop(
      current: load,
      lengthM: lengthM,
      size: size,
      phase: phase,
      pf: pf,
      conductorTempC: conductorTemp(ins),
    );
  }
  return CableChoice(
    ib: ib,
    load: load,
    breaker: breaker,
    sizeByAmpacity: byAmp,
    sizeByDrop: byDrop,
    size: size,
    iz: iz,
    dropV: dv,
    dropPct: dv == null || volts <= 0 ? null : dv / volts * 100,
    dropLimitPct: limit,
    tempFactor: kt ?? 0,
    groupFactor: kg,
    notes: notes,
  );
}

/// 역률 개선 콘덴서 용량(kvar) = P·(tanφ1 − tanφ2).
double capacitorKvar(double kw, double pfNow, double pfTarget) {
  double tanOf(double pf) => math.sqrt(1 - pf * pf) / pf;
  if (pfNow <= 0 || pfTarget <= 0 || pfTarget <= pfNow) return 0;
  return kw * (tanOf(pfNow) - tanOf(pfTarget.clamp(0, 1)));
}

/// 굵기 글: 2.5 → "2.5sq", 16 → "16sq".
String sqText(double s) =>
    '${s == s.roundToDouble() ? s.toInt() : s}sq';
