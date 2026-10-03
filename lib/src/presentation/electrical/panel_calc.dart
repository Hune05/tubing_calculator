// 분전반·조명 계산 계산(10-03): 조명 광속법, 분전반 상 평형, 여러 부하가 붙은 간선의 전압강하.
// 화면 없이 계산만 한다. 식은 모두 정의식이라 표 값이 필요 없고, 조도·보수율·조명률은 사용자가 설계 도서에서 읽어 넣는다.
import 'dart:math' as math;

import 'elec_calc.dart';

// ─────────────── 조명(광속법) ───────────────

/// 실지수 K = (X × Y) ÷ (H × (X + Y)). [x]·[y] 방의 가로·세로, [h] 작업면에서 등기구까지 높이(모두 m).
double? roomIndex({required double x, required double y, required double h}) {
  if (x <= 0 || y <= 0 || h <= 0) return null;
  return x * y / (h * (x + y));
}

/// 광속법 결과.
class LightingResult {
  const LightingResult({
    required this.exact,
    required this.count,
    required this.cols,
    required this.rows,
    required this.actualLux,
    required this.totalWatts,
    required this.spacingX,
    required this.spacingY,
  });

  /// 필요한 등기구 수(소수). N = E × A ÷ (F × U × M).
  final double exact;

  /// 올림한 등기구 수.
  final int count;

  /// 배치 열 수(가로 방향), 행 수(세로 방향). 열 × 행 ≥ 개수.
  final int cols;
  final int rows;

  /// 이 개수로 놓았을 때 실제 평균 조도(lx).
  final double actualLux;

  /// 전체 소비전력(W). 등기구 소비전력을 넣었을 때만 쓴다(없으면 0).
  final double totalWatts;

  /// 열·행 방향 등기구 간격(m). 방을 열·행으로 균등 분할한 값.
  final double spacingX;
  final double spacingY;
}

/// 광속법. [lux] 목표 조도(lx), [areaM2] 방 면적, [lumens] 등기구 한 개의 광속(lm),
/// [u] 조명률(0~1), [m] 보수율(0~1). [x]·[y]를 주면 배치 열·행과 간격을 낸다.
LightingResult? lighting({
  required double lux,
  required double areaM2,
  required double lumens,
  required double u,
  required double m,
  double? x,
  double? y,
  double wattsEach = 0,
}) {
  if (lux <= 0 || areaM2 <= 0 || lumens <= 0) return null;
  if (u <= 0 || u > 1 || m <= 0 || m > 1) return null;
  final exact = lux * areaM2 / (lumens * u * m);
  final n = exact.ceil().clamp(1, 100000);
  var cols = 1;
  var rows = n;
  if (x != null && y != null && x > 0 && y > 0) {
    // 방 가로세로비에 가까운 열·행: 열 ≈ √(N × x ÷ y)
    cols = math.sqrt(n * x / y).round().clamp(1, n);
    rows = (n / cols).ceil();
  }
  final actual = n * lumens * u * m / areaM2;
  final sx = (x != null && x > 0) ? x / cols : 0.0;
  final sy = (y != null && y > 0) ? y / rows : 0.0;
  return LightingResult(
    exact: exact,
    count: n,
    cols: cols,
    rows: rows,
    actualLux: actual,
    totalWatts: n * wattsEach,
    spacingX: sx,
    spacingY: sy,
  );
}

// ─────────────── 분전반 상 평형 ───────────────

/// 상 이름.
enum PanelPhase { r, s, t }

String phaseName(PanelPhase p) => switch (p) {
  PanelPhase.r => 'R',
  PanelPhase.s => 'S',
  PanelPhase.t => 'T',
};

/// 회로 하나: 이름, 부하(VA), 연결한 상. 삼상 부하는 [three]로 세 상에 3등분해 넣는다.
class PanelCircuit {
  const PanelCircuit({
    required this.name,
    required this.va,
    required this.phase,
    this.three = false,
  });
  final String name;
  final double va;
  final PanelPhase phase;
  final bool three;
}

/// 상 평형 결과.
class BalanceResult {
  const BalanceResult({
    required this.phaseVa,
    required this.totalVa,
    required this.unbalancePct,
    required this.maxPhase,
    required this.minPhase,
    required this.neutralAmps,
    required this.phaseAmps,
  });

  /// 상별 합계(VA): R, S, T 순서.
  final List<double> phaseVa;
  final double totalVa;

  /// 설비 불평형률(%) = (최대 상 − 최소 상) ÷ (총 부하 × 1/3) × 100.
  final double unbalancePct;
  final PanelPhase maxPhase;
  final PanelPhase minPhase;

  /// 세 상 부하의 역률이 같고 고조파가 없다고 보았을 때 중성선 전류(A).
  final double neutralAmps;

  /// 상별 전류(A) = 상 VA ÷ 상전압.
  final List<double> phaseAmps;
}

/// 상 평형 계산. [phaseVolts]는 상전압(예: 380/220V 계통이면 220).
BalanceResult? panelBalance(
  List<PanelCircuit> circuits, {
  required double phaseVolts,
}) {
  if (circuits.isEmpty || phaseVolts <= 0) return null;
  final v = [0.0, 0.0, 0.0];
  for (final c in circuits) {
    if (c.va < 0) return null;
    if (c.three) {
      for (var i = 0; i < 3; i++) {
        v[i] += c.va / 3;
      }
    } else {
      v[c.phase.index] += c.va;
    }
  }
  final total = v[0] + v[1] + v[2];
  if (total <= 0) return null;
  var maxI = 0, minI = 0;
  for (var i = 1; i < 3; i++) {
    if (v[i] > v[maxI]) maxI = i;
    if (v[i] < v[minI]) minI = i;
  }
  final pct = (v[maxI] - v[minI]) / (total / 3) * 100;
  final a = [for (final x in v) x / phaseVolts];
  final inSq =
      a[0] * a[0] +
      a[1] * a[1] +
      a[2] * a[2] -
      a[0] * a[1] -
      a[1] * a[2] -
      a[2] * a[0];
  return BalanceResult(
    phaseVa: v,
    totalVa: total,
    unbalancePct: pct,
    maxPhase: PanelPhase.values[maxI],
    minPhase: PanelPhase.values[minI],
    neutralAmps: math.sqrt(math.max(0, inSq)),
    phaseAmps: a,
  );
}

/// 단상 회로를 큰 것부터 가장 가벼운 상에 차례로 넣는 자동 배정(삼상 부하는 그대로).
/// 완전한 최적은 아니지만 현장에서 손으로 하는 방식과 같고 결과가 안정적이다.
List<PanelCircuit> autoBalance(List<PanelCircuit> circuits) {
  final load = [0.0, 0.0, 0.0];
  for (final c in circuits.where((c) => c.three)) {
    for (var i = 0; i < 3; i++) {
      load[i] += c.va / 3;
    }
  }
  final singles = [
    for (var i = 0; i < circuits.length; i++)
      if (!circuits[i].three) i,
  ]..sort((a, b) => circuits[b].va.compareTo(circuits[a].va));
  final out = List<PanelCircuit>.of(circuits);
  for (final idx in singles) {
    var best = 0;
    for (var i = 1; i < 3; i++) {
      if (load[i] < load[best]) best = i;
    }
    final c = circuits[idx];
    load[best] += c.va;
    out[idx] = PanelCircuit(
      name: c.name,
      va: c.va,
      phase: PanelPhase.values[best],
    );
  }
  return out;
}

// ─────────────── 분기회로 수 ───────────────

/// 상 불평형 한도(%): 3상 3선식·3상 4선식, 한전 전기공급약관과 내선규정 해설서 기준(원문 대조 전).
/// 단상 3선식은 40 %(식의 분모가 총 부하의 1/2). 계약전력 5 kW 이하 소규모 등 완전 평형이 어려우면 40 %까지 허용하는 설명이 있다.
const double kUnbalanceLimitPct = 30;

/// 분기회로 수 계산 결과.
class BranchResult {
  const BranchResult({
    required this.totalVa,
    required this.perCircuitVa,
    required this.exact,
    required this.count,
  });

  /// 부하설비용량(VA) = 바닥면적 × 표준부하 + 가산부하.
  final double totalVa;

  /// 분기회로 하나가 맡는 용량(VA) = 전압 × 분기 전류 × 이용률.
  final double perCircuitVa;

  /// 분기회로 수(소수), 올림한 수.
  final double exact;
  final int count;
}

/// 분기회로 수 = 부하설비용량 ÷ (전압 × 분기 전류 × 이용률). 올림한다.
/// [densityVaPerM2] 표준부하(VA/m²), [extraVa] 가산부하(VA), [utilization] 0~1(1이면 정격 전부).
BranchResult? branchCircuits({
  required double areaM2,
  required double densityVaPerM2,
  double extraVa = 0,
  required double volts,
  required double branchAmps,
  double utilization = 1,
}) {
  if (areaM2 < 0 || densityVaPerM2 < 0 || extraVa < 0) return null;
  if (volts <= 0 || branchAmps <= 0 || utilization <= 0 || utilization > 1) {
    return null;
  }
  final total = areaM2 * densityVaPerM2 + extraVa;
  if (total <= 0) return null;
  final per = volts * branchAmps * utilization;
  final exact = total / per;
  return BranchResult(
    totalVa: total,
    perCircuitVa: per,
    exact: exact,
    count: exact.ceil(),
  );
}

// ─────────────── 여러 부하가 붙은 간선의 전압강하 ───────────────

/// 간선의 구간 하나: 앞 지점에서 이 구간 끝까지의 길이(m)와, 구간 끝에서 빠지는 부하 전류(A).
class FeederSegment {
  const FeederSegment({required this.lengthM, required this.loadAmps});
  final double lengthM;
  final double loadAmps;
}

class FeederResult {
  const FeederResult({
    required this.segCurrents,
    required this.segDropV,
    required this.cumDropV,
    required this.cumDropPct,
    required this.totalDropV,
    required this.totalDropPct,
    required this.totalLengthM,
    required this.totalAmps,
  });

  /// 구간마다 흐르는 전류(A) = 그 구간 끝과 그 뒤 모든 부하의 합.
  final List<double> segCurrents;

  /// 구간마다 전압강하(V), 전원부터 누적(V·%).
  final List<double> segDropV;
  final List<double> cumDropV;
  final List<double> cumDropPct;
  final double totalDropV;
  final double totalDropPct;
  final double totalLengthM;
  final double totalAmps;
}

/// 전원에서 끝까지 구간을 이어 가며 전압강하를 낸다. 전선은 같은 굵기 하나로 본다.
/// [volts]는 공칭 선간 전압(교류) 또는 직류 전압. 전압강하 %는 이 전압 기준(회로 규정과 같게).
FeederResult? feederDrop({
  required List<FeederSegment> segments,
  required double size,
  required Phase phase,
  required double volts,
  double pf = 0.85,
  double conductorTempC = 70,
}) {
  if (segments.isEmpty || volts <= 0 || size <= 0) return null;
  for (final s in segments) {
    if (s.lengthM < 0 || s.loadAmps < 0) return null;
  }
  final n = segments.length;
  final cur = List<double>.filled(n, 0);
  var run = 0.0;
  for (var i = n - 1; i >= 0; i--) {
    run += segments[i].loadAmps;
    cur[i] = run;
  }
  final seg = <double>[];
  final cum = <double>[];
  final cumPct = <double>[];
  var total = 0.0, len = 0.0;
  for (var i = 0; i < n; i++) {
    final d = segments[i].lengthM == 0
        ? 0.0
        : voltageDrop(
            current: cur[i],
            lengthM: segments[i].lengthM,
            size: size,
            phase: phase,
            pf: pf,
            conductorTempC: conductorTempC,
          );
    seg.add(d);
    total += d;
    len += segments[i].lengthM;
    cum.add(total);
    cumPct.add(total / volts * 100);
  }
  return FeederResult(
    segCurrents: cur,
    segDropV: seg,
    cumDropV: cum,
    cumDropPct: cumPct,
    totalDropV: total,
    totalDropPct: total / volts * 100,
    totalLengthM: len,
    totalAmps: cur.first,
  );
}
