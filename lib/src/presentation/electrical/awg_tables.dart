// AWG·kcmil 전선(미국식 굵기) 표와 계산. 수입 설비·NEC 방식 제어반 배선용.
// 한국 KEC는 mm²(SQ)로 쓴다. 이 표는 NEC(미국 전기 규정) 기준이다.
//
// 값은 모두 두 출처 이상이 같은 것만 넣었다(2026-09-26 조사, docs/전기계산기_근거.md "AWG").
// · 단면적(mm²·cmil)·도체 저항: NEC Chapter 9 Table 8(구리, 연선, 도금 없음, 75°C 직류 저항).
// · 허용전류: NEC Table 310.16(구리, 통전 도체 3가닥 이하, 주위 30°C).
// · 주위 온도 보정: NEC Table 310.15(B)(1). 통전 도체 4가닥 이상 감소: NEC 310.15(C)(1).
// · 작은 전선 과전류 보호 한도: NEC 240.4(D). 단자 온도: NEC 110.14(C)(1).
library;

import 'dart:math' as math;

import 'elec_calc.dart';
import 'elec_tables.dart';

/// AWG·kcmil 굵기 한 줄.
class AwgSize {
  /// 화면 이름: '14 AWG', '1/0 AWG', '250 kcmil'.
  final String label;

  /// 단면적(mm²), NEC Chapter 9 Table 8.
  final double mm2;

  /// 단면적(circular mils), NEC Chapter 9 Table 8.
  final int cmil;

  /// 75°C 직류 저항(Ω/km), 구리 연선 도금 없음, NEC Chapter 9 Table 8.
  final double r75;

  /// NEC Table 310.16 구리 허용전류(A): 60°C·75°C·90°C 열. 표에 없는 칸은 null.
  final int? a60;
  final int? a75;
  final int? a90;

  const AwgSize(
    this.label,
    this.mm2,
    this.cmil,
    this.r75,
    this.a60,
    this.a75,
    this.a90,
  );

  bool get isKcmil => label.endsWith('kcmil');
}

/// 18 AWG ~ 500 kcmil. 18·16 AWG는 310.16에 90°C 값만 있다.
const List<AwgSize> kAwgSizes = [
  AwgSize('18 AWG', 0.823, 1620, 26.1, null, null, 14),
  AwgSize('16 AWG', 1.31, 2580, 16.4, null, null, 18),
  AwgSize('14 AWG', 2.08, 4110, 10.3, 15, 20, 25),
  AwgSize('12 AWG', 3.31, 6530, 6.50, 20, 25, 30),
  AwgSize('10 AWG', 5.261, 10380, 4.070, 30, 35, 40),
  AwgSize('8 AWG', 8.367, 16510, 2.551, 40, 50, 55),
  AwgSize('6 AWG', 13.30, 26240, 1.608, 55, 65, 75),
  AwgSize('4 AWG', 21.15, 41740, 1.010, 70, 85, 95),
  AwgSize('3 AWG', 26.67, 52620, 0.802, 85, 100, 115),
  AwgSize('2 AWG', 33.62, 66360, 0.634, 95, 115, 130),
  AwgSize('1 AWG', 42.41, 83690, 0.505, 110, 130, 145),
  AwgSize('1/0 AWG', 53.49, 105600, 0.399, 125, 150, 170),
  AwgSize('2/0 AWG', 67.43, 133100, 0.317, 145, 175, 195),
  AwgSize('3/0 AWG', 85.01, 167800, 0.2512, 165, 200, 225),
  AwgSize('4/0 AWG', 107.2, 211600, 0.1996, 195, 230, 260),
  AwgSize('250 kcmil', 127, 250000, 0.1687, 215, 255, 290),
  AwgSize('300 kcmil', 152, 300000, 0.1409, 240, 285, 320),
  AwgSize('350 kcmil', 177, 350000, 0.1205, 260, 310, 350),
  AwgSize('400 kcmil', 203, 400000, 0.1053, 280, 335, 380),
  AwgSize('500 kcmil', 253, 500000, 0.0845, 320, 380, 430),
];

AwgSize? awgByLabel(String? label) {
  for (final s in kAwgSizes) {
    if (s.label == label) return s;
  }
  return null;
}

/// 전선 굵기 탭에서 고르는 굵기(14 AWG부터). 18·16 AWG는 310.16에 60·75°C 값이 없어 뺀다.
final List<AwgSize> kAwgPowerSizes = [
  for (final s in kAwgSizes)
    if (s.a60 != null) s,
];

/// NEC Table 310.16 온도 열(전선 절연 온도).
enum NecColumn { c60, c75, c90 }

int necColumnTemp(NecColumn c) => switch (c) {
  NecColumn.c60 => 60,
  NecColumn.c75 => 75,
  NecColumn.c90 => 90,
};

int? necAmpacity(AwgSize s, NecColumn c) => switch (c) {
  NecColumn.c60 => s.a60,
  NecColumn.c75 => s.a75,
  NecColumn.c90 => s.a90,
};

/// NEC Table 310.15(B)(1) 주위 온도 보정계수(기준 30°C). [°C 상한, 60°C, 75°C, 90°C].
/// 표 칸은 온도 구간(예: 31~35°C)이다. 칸에 없는 값(해당 절연 온도 넘음)은 null.
const List<(double, double?, double?, double?)> _necAmbient = [
  (10, 1.29, 1.20, 1.15),
  (15, 1.22, 1.15, 1.12),
  (20, 1.15, 1.11, 1.08),
  (25, 1.08, 1.05, 1.04),
  (30, 1.00, 1.00, 1.00),
  (35, 0.91, 0.94, 0.96),
  (40, 0.82, 0.88, 0.91),
  (45, 0.71, 0.82, 0.87),
  (50, 0.58, 0.75, 0.82),
  (55, 0.41, 0.67, 0.76),
  (60, null, 0.58, 0.71),
  (65, null, 0.47, 0.65),
  (70, null, 0.33, 0.58),
  (75, null, null, 0.50),
  (80, null, null, 0.41),
  (85, null, null, 0.29),
];

/// 주위 온도 보정계수. 구간 표라 [ambientC]가 든 구간(더운 쪽 경계 포함)을 쓴다. 넘으면 null.
double? necTempFactor(double ambientC, NecColumn c) {
  for (final r in _necAmbient) {
    if (ambientC <= r.$1 + 1e-9) {
      return switch (c) {
        NecColumn.c60 => r.$2,
        NecColumn.c75 => r.$3,
        NecColumn.c90 => r.$4,
      };
    }
  }
  return null;
}

/// NEC 310.15(C)(1): 전선관·케이블 속 통전 도체가 3가닥을 넘을 때 감소계수.
double necAdjustFactor(int currentCarrying) {
  final n = currentCarrying;
  if (n <= 3) return 1.0;
  if (n <= 6) return 0.80;
  if (n <= 9) return 0.70;
  if (n <= 20) return 0.50;
  if (n <= 30) return 0.45;
  if (n <= 40) return 0.40;
  return 0.35;
}

/// NEC 240.4(D) 작은 전선의 과전류 보호 한도(A, 구리). 해당 없으면 null.
int? necSmallConductorMaxOcpd(AwgSize s) => switch (s.label) {
  '18 AWG' => 7,
  '16 AWG' => 10,
  '14 AWG' => 15,
  '12 AWG' => 20,
  '10 AWG' => 30,
  _ => null,
};

/// UL 508A 표 28.1(산업용 제어반 내부 배선, 구리) [60°C, 75°C] 허용전류. 참고로만 보인다.
/// UL 508A(2013 원문)·VRI Electrical·Eaton Control Panel Design Guide가 같은 값(60°C 열은 1 AWG까지).
/// 90°C 열은 없고 14 AWG가 75°C에서도 15A다(NEC 310.16과 다름).
const Map<String, (int?, int)> kUl508aT281 = {
  '14 AWG': (15, 15),
  '12 AWG': (20, 20),
  '10 AWG': (30, 30),
  '8 AWG': (40, 50),
  '6 AWG': (55, 65),
  '4 AWG': (70, 85),
  '3 AWG': (85, 100),
  '2 AWG': (95, 115),
  '1 AWG': (110, 130),
  '1/0 AWG': (null, 150),
  '2/0 AWG': (null, 175),
  '3/0 AWG': (null, 200),
  '4/0 AWG': (null, 230),
  '250 kcmil': (null, 255),
  '300 kcmil': (null, 285),
  '350 kcmil': (null, 310),
  '400 kcmil': (null, 335),
  '500 kcmil': (null, 380),
};

/// 단자 온도 선택. auto는 NEC 110.14(C)(1): 100A 이하 회로는 60°C, 넘으면 75°C.
enum NecTerminal { auto, c60, c75 }

NecColumn terminalColumn(NecTerminal t, double circuitA) => switch (t) {
  NecTerminal.c60 => NecColumn.c60,
  NecTerminal.c75 => NecColumn.c75,
  NecTerminal.auto => circuitA <= 100 ? NecColumn.c60 : NecColumn.c75,
};

/// NEC 방식 허용전류 한 굵기 계산 결과.
class AwgAmpacity {
  final double? corrected; // 절연 온도 열 × 온도 보정 × 가닥 감소
  final int? terminalLimit; // 단자 온도 열 값
  final double? iz; // 둘 중 작은 값
  final NecColumn terminal;
  const AwgAmpacity(this.corrected, this.terminalLimit, this.iz, this.terminal);
}

/// 허용전류 = min(절연 온도 열 × 온도 보정 × 가닥 감소, 단자 온도 열 값). 단자 열은 절연 열보다 높을 수 없다.
AwgAmpacity awgAmpacity(
  AwgSize s, {
  required NecColumn column,
  required NecTerminal terminal,
  required double circuitA,
  double ambientC = 30,
  int currentCarrying = 3,
}) {
  var term = terminalColumn(terminal, circuitA);
  if (term.index > column.index) term = column;
  final base = necAmpacity(s, column);
  final kt = necTempFactor(ambientC, column);
  final corrected = base == null || kt == null
      ? null
      : base * kt * necAdjustFactor(currentCarrying);
  final limit = necAmpacity(s, term);
  final iz = corrected == null || limit == null
      ? null
      : math.min(corrected, limit.toDouble());
  return AwgAmpacity(corrected, limit, iz, term);
}

/// AWG 전선 전압강하(V). 저항은 NEC Chapter 9 Table 8 75°C 값, 교류는 X = 0.096 Ω/km(60Hz).
double awgVoltageDrop({
  required double current,
  required double lengthM,
  required AwgSize size,
  required Phase phase,
  double pf = 0.85,
}) => voltageDropR(
  current: current,
  lengthM: lengthM,
  rOhmPerKm: size.r75,
  phase: phase,
  pf: pf,
);

/// AWG 굵기 선정 결과.
class AwgChoice {
  final double load;
  final double ib; // 설계전류
  final AwgSize? byAmpacity;
  final AwgSize? byDrop;
  final AwgSize? size;
  final AwgAmpacity? amp; // 선정한 굵기
  final double? tempFactor;
  final double adjustFactor;
  final double? dropV;
  final double? dropPct;
  final double dropLimitPct;
  final bool dropChecked;
  final List<String> notes;
  const AwgChoice({
    required this.load,
    required this.ib,
    required this.byAmpacity,
    required this.byDrop,
    required this.size,
    required this.amp,
    required this.tempFactor,
    required this.adjustFactor,
    required this.dropV,
    required this.dropPct,
    required this.dropLimitPct,
    required this.dropChecked,
    required this.notes,
  });
}

/// NEC 방식 굵기 선정: 허용전류 ≥ 설계전류, 작은 전선(14~10 AWG)은 240.4(D) 한도 ≥ 설계전류
/// (전동기 회로 제외), 길이가 있으면 전압강하 한도(KEC 232.3.9)도 본다.
AwgChoice chooseAwg({
  required double load,
  double margin = 1,
  required double volts,
  required Phase phase,
  NecColumn column = NecColumn.c90,
  NecTerminal terminal = NecTerminal.auto,
  double ambientC = 30,
  int currentCarrying = 3,
  double? lengthM,
  double pf = 0.85,
  SupplyType supply = SupplyType.lvOther,
  bool motor = false,
}) {
  final notes = <String>[];
  final ib = load * margin;
  final kt = necTempFactor(ambientC, column);
  final kadj = necAdjustFactor(currentCarrying);
  if (kt == null) {
    notes.add(
      '주위 온도 ${_f(ambientC)}°C가 ${necColumnTemp(column)}°C 전선의 보정표(NEC 310.15(B)(1)) 범위를 넘습니다.',
    );
  }
  final len = lengthM ?? 0;
  final checkDrop = len > 0;
  final limit = voltageDropLimit(supply, len);
  AwgSize? byAmp;
  AwgSize? byDrop;
  for (final s in kAwgPowerSizes) {
    if (byAmp == null) {
      final a = awgAmpacity(
        s,
        column: column,
        terminal: terminal,
        circuitA: ib,
        ambientC: ambientC,
        currentCarrying: currentCarrying,
      );
      final ocpd = motor ? null : necSmallConductorMaxOcpd(s);
      if (a.iz != null &&
          a.iz! >= ib - 1e-9 &&
          (ocpd == null || ocpd >= ib - 1e-9)) {
        byAmp = s;
      }
    }
    if (checkDrop && byDrop == null && volts > 0) {
      final dv = awgVoltageDrop(
        current: load,
        lengthM: len,
        size: s,
        phase: phase,
        pf: pf,
      );
      if (dv / volts * 100 <= limit + 1e-9) byDrop = s;
    }
  }
  if (byAmp == null && kt != null) {
    notes.add('500 kcmil 1가닥으로는 허용전류가 부족합니다. 병렬 포설은 설계 검토가 필요합니다.');
  }
  if (checkDrop && byDrop == null) {
    notes.add('500 kcmil로도 전압강하 한도를 초과합니다. 길이·전압을 검토하십시오.');
  }
  AwgSize? size;
  if (byAmp != null && (!checkDrop || byDrop != null)) {
    size = !checkDrop || kAwgSizes.indexOf(byAmp) >= kAwgSizes.indexOf(byDrop!)
        ? byAmp
        : byDrop;
  }
  AwgAmpacity? amp;
  double? dv;
  if (size != null) {
    amp = awgAmpacity(
      size,
      column: column,
      terminal: terminal,
      circuitA: ib,
      ambientC: ambientC,
      currentCarrying: currentCarrying,
    );
    if (checkDrop) {
      dv = awgVoltageDrop(
        current: load,
        lengthM: len,
        size: size,
        phase: phase,
        pf: pf,
      );
    }
  }
  return AwgChoice(
    load: load,
    ib: ib,
    byAmpacity: byAmp,
    byDrop: byDrop,
    size: size,
    amp: amp,
    tempFactor: kt,
    adjustFactor: kadj,
    dropV: dv,
    dropPct: dv == null || volts <= 0 ? null : dv / volts * 100,
    dropLimitPct: limit,
    dropChecked: checkDrop,
    notes: notes,
  );
}

/// 가장 가까운 SQ(mm²) 중 같거나 굵은 것. KS 굵기로 바꿔 쓸 때 참고.
double? sqAtLeast(double mm2) {
  for (final s in kCableSizes) {
    if (s >= mm2 * (1 - 0.005)) return s;
  }
  return null;
}

String _f(double v) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return s;
}
