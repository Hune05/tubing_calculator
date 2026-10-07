// 전기 설비 계산 독립 대조 시험(2026-10-03).
//
// 근거 문서(docs/전기계산기_근거.md, 전기_부하합산_근거.md, 전기_단락전류_근거.md, 전기_발전기_근거.md,
// 전기_축전지_근거.md, 전기_접지_전동기보호_근거.md, 전기_케이블트레이_근거.md)의 식·표만으로 계산을 따로
// 짜고(아래 "독립 모델"), 입력을 격자·무작위(씨앗 고정)로 많이 만들어 앱 계산 함수와 대조한다.
// 허용 차이: 상대 0.5%(값) 또는 표 한 칸(굵기·정격은 같아야 함).
//
// 표 값이 근거 문서에 숫자로 없는 것(IEC 60364-5-52 허용전류 표 대부분, NEC 310.16 대부분, 차단기 정격 목록,
// 전선 외경 대부분 등)은 굵기 선정 논리를 볼 때 앱 표를 "자료"로만 쓰고, 표 자체는 따로
// "문서 값" 대조와 "기억 값(참고)" 대조로 나눴다. 기억 값은 IEC·NEC 표준 표를 기억으로 옮긴 것이라 근거 문서
// 대조가 아니다(불일치가 나와도 앱 오류로 단정하지 않는다).
//
// lib 폴더는 고치지 않는다. 불일치를 찾으면 원인을 (a) 앱 오류 (b) 근거 문서와 앱의 기준 차이 (c) 독립 모델
// 실수로 가린다. (c)는 이 파일을 고쳤고, (a)(b)는 해당 항목만 skip으로 두고 이유를 주석으로 적는다.
// ignore_for_file: avoid_print

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tubing_calculator/src/presentation/electrical/awg_tables.dart';
import 'package:tubing_calculator/src/presentation/electrical/basic_calc.dart'
    as bc;
import 'package:tubing_calculator/src/presentation/electrical/cable_tray.dart';
import 'package:tubing_calculator/src/presentation/electrical/conduit_tables.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_battery.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_calc.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_generator.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_load_sum.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_short_circuit.dart';
import 'package:tubing_calculator/src/presentation/electrical/elec_tables.dart';
import 'package:tubing_calculator/src/presentation/electrical/ground_calc.dart'
    as gc;
import 'package:tubing_calculator/src/presentation/electrical/motor_protect.dart'
    as mp;
import 'package:tubing_calculator/src/presentation/electrical/motor_tables.dart';

// ═══════════════════════ 대조 도구 ═══════════════════════

String _s(Object? v) {
  if (v is double) {
    if (v.abs() >= 1000) return v.toStringAsFixed(1);
    return v.toStringAsPrecision(6);
  }
  return '$v';
}

/// 한 조합 안의 값 비교.
class Cmp {
  int count = 0;
  final List<String> diffs = [];

  void n(
    String what,
    num? app,
    num? ref, {
    double rel = 0.005,
    double abs = 1e-9,
  }) {
    count++;
    if (app == null || ref == null) {
      if (app != null || ref != null) {
        diffs.add('$what 앱 ${_s(app)} / 독립 ${_s(ref)}');
      }
      return;
    }
    final a = app.toDouble();
    final r = ref.toDouble();
    final d = (a - r).abs();
    if (d <= abs || d <= rel * r.abs()) return;
    diffs.add('$what 앱 ${_s(a)} / 독립 ${_s(r)}');
  }

  void eq(String what, Object? app, Object? ref) {
    count++;
    if (app != ref) diffs.add('$what 앱 $app / 독립 $ref');
  }
}

/// 항목 하나의 조합 수·일치 수·불일치 목록.
class Tally {
  Tally(this.name);
  final String name;
  int combos = 0;
  int matched = 0;
  int values = 0;
  final List<String> bad = [];

  void run(String input, void Function(Cmp c) body) {
    final c = Cmp();
    body(c);
    combos++;
    values += c.count;
    if (c.diffs.isEmpty) {
      matched++;
    } else {
      bad.add('$input → ${c.diffs.join(' | ')}');
    }
  }

  void finish({int show = 12}) {
    print(
      '[$name] 조합 $combos · 일치 $matched · 불일치 ${bad.length} (비교한 값 $values개)',
    );
    for (final b in bad.take(show)) {
      print('    - $b');
    }
    expect(bad, isEmpty, reason: '$name: 불일치 ${bad.length}건');
  }
}

T _pick<T>(math.Random r, List<T> xs) => xs[r.nextInt(xs.length)];

// ═══════════════════════ 독립 모델: 표 ═══════════════════════

/// IEC 60364-5-52 표가 있는 굵기(1.5~300mm²).
const List<double> refSizes = [
  1.5, 2.5, 4, 6, 10, 16, 25, 35, 50, 70, 95, 120, 150, 185, 240, 300,
];

/// IEC 60228 2종(연선) 구리 20°C 최대 저항(Ω/km).
/// 0.75·1.0은 근거 문서(전기계산기_근거.md "24.5·18.1")의 값. 나머지는 근거 문서에 숫자가 없어
/// IEC 60228 표를 기억으로 옮겼다(참고 값).
final Map<double, double> refR20 = {
  0.75: 24.5, 1.0: 18.1, 1.5: 12.1, 2.5: 7.41, 4: 4.61, 6: 3.08, 10: 1.83,
  16: 1.15, 25: 0.727, 35: 0.524, 50: 0.387, 70: 0.268, 95: 0.193,
  120: 0.153, 150: 0.124, 185: 0.0991, 240: 0.0754, 300: 0.0601,
};

/// 문서: R = R20 × (1 + 0.00393(θ − 20)).
double refR(double size, double theta) =>
    refR20[size]! * (1 + 0.00393 * (theta - 20));

/// 문서: X = 0.096 Ω/km(60Hz).
const double refX = 0.096;

/// 문서: ΔU = k·I·L·(R cosφ + X sinφ), k = 단상 2·삼상 √3. 직류 2·I·L·R.
double refVdR(double i, double lengthM, double rKm, Phase ph, double pf) {
  final lk = lengthM / 1000;
  if (ph == Phase.dc) return 2 * i * lk * rKm;
  final sin = math.sqrt(math.max(0, 1 - pf * pf));
  final k = ph == Phase.three ? math.sqrt(3) : 2.0;
  return k * i * lk * (rKm * pf + refX * sin);
}

double refVd(
  double i,
  double l,
  double size,
  Phase ph,
  double pf,
  double theta,
) => refVdR(i, l, refR(size, theta), ph, pf);

/// 문서 KEC 232.3.9: 저압 수전 조명 3·기타 5, 고압 이상 수전 6·8(%). 100m 넘으면 1m당 0.005%, 0.5%까지.
double refLimit(SupplyType t, double lengthM) {
  final base = switch (t) {
    SupplyType.lvLighting => 3.0,
    SupplyType.lvOther => 5.0,
    SupplyType.hvLighting => 6.0,
    SupplyType.hvOther => 8.0,
  };
  return base + (lengthM > 100 ? math.min(0.5, 0.005 * (lengthM - 100)) : 0);
}

/// 문서: 한도 이내 최대 편도 길이 = 전압강하(+ 전원 쪽 강하)와 한도(100m 넘는 만큼 더한 값)가 같아지는 길이.
/// 식을 풀지 않고 이분법으로 찾는다(앱과 다른 방법).
double? refMaxLen(double pctPerM, SupplyType t, double reserved) {
  if (pctPerM <= 0) return null;
  bool okAt(double l) => pctPerM * l + reserved <= refLimit(t, l) + 1e-12;
  if (!okAt(0) || refLimit(t, 0) - reserved <= 0) return null;
  var lo = 0.0;
  var hi = (refLimit(t, 1e9) + 1) / pctPerM + 10;
  for (var k = 0; k < 200; k++) {
    final mid = (lo + hi) / 2;
    if (okAt(mid)) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}

/// 온도 보정계수. 근거 문서에 표 숫자가 없어 표의 바탕 식 k = √((θmax − θa)/(θmax − θ기준))을
/// 소수 둘째 자리로 반올림해 쓴다(θ기준 공기 30°C·지중 20°C, θmax PVC 70·XLPE 90).
/// 문서 규칙: 표 사이 온도는 더운 쪽 칸, 표 범위(PVC 60·XLPE 80°C)를 넘으면 계산하지 않음.
double? refKt(double t, bool pvc, bool ground) {
  final theta = pvc ? 70.0 : 90.0;
  final base = ground ? 20.0 : 30.0;
  final maxT = pvc ? 60.0 : 80.0;
  var bin = (t / 5 - 1e-9).ceil() * 5.0;
  if (bin < 10) bin = 10;
  if (bin > maxT + 1e-9) return null;
  final v = math.sqrt((theta - bin) / (theta - base));
  return (v * 100).round() / 100;
}

const List<int> refGN = [1, 2, 3, 4, 5, 6, 7, 8, 9, 12, 16, 20];

/// B.52.17 1행은 근거 문서 값. 2·4·5행과 B.52.18·B.52.19는 근거 문서에 숫자가 없어 IEC 표를 기억으로 옮김(참고).
const Map<GroupLayout, List<double>> refGRows = {
  GroupLayout.bunched: [
    1.00, 0.80, 0.70, 0.65, 0.60, 0.57, 0.54, 0.52, 0.50, 0.45, 0.41, 0.38,
  ],
  GroupLayout.wallSingleLayer: [
    1.00, 0.85, 0.79, 0.75, 0.73, 0.72, 0.72, 0.71, 0.70, 0.70, 0.70, 0.70,
  ],
  GroupLayout.perforatedTray: [
    1.00, 0.88, 0.82, 0.77, 0.75, 0.73, 0.73, 0.72, 0.72, 0.72, 0.72, 0.72,
  ],
  GroupLayout.ladder: [
    1.00, 0.87, 0.82, 0.80, 0.80, 0.79, 0.79, 0.78, 0.78, 0.78, 0.78, 0.78,
  ],
  GroupLayout.groundDirect: [
    1.00, 0.75, 0.65, 0.60, 0.55, 0.50, 0.45, 0.43, 0.41, 0.36, 0.32, 0.29,
  ],
};
const List<double> refGDuct = [
  1.00, 0.85, 0.75, 0.70, 0.65, 0.60, 0.57, 0.54, 0.52, 0.49,
  0.47, 0.45, 0.44, 0.42, 0.41, 0.39, 0.38, 0.37, 0.35, 0.34,
];

/// 문서: 표 사이 회로 수는 많은 쪽(안전 쪽), 20 넘으면 20.
double refGroup(int n0, GroupLayout l) {
  final n = n0.clamp(1, 20);
  if (l == GroupLayout.groundDuct) return refGDuct[n - 1];
  final row = refGRows[l]!;
  for (var i = 0; i < refGN.length; i++) {
    if (refGN[i] >= n) return row[i];
  }
  return row.last;
}

/// IEC 60364-5-52 허용전류 기억 값(참고). 열: A1, A2, B1, B2, C, D1.
/// 표 이름: B.52.2 PVC 2가닥, B.52.3 XLPE 2가닥, B.52.4 PVC 3가닥, B.52.5 XLPE 3가닥.
final Map<double, List<double>> memPvc2 = {
  1.5: [14.5, 14, 17.5, 16.5, 19.5, 22], 2.5: [19.5, 18.5, 24, 23, 27, 29],
  4: [26, 25, 32, 30, 36, 37], 6: [34, 32, 41, 38, 46, 46],
  10: [46, 43, 57, 52, 63, 60], 16: [61, 57, 76, 69, 85, 78],
  25: [80, 75, 101, 90, 112, 99], 35: [99, 92, 125, 111, 138, 119],
  50: [119, 110, 151, 133, 168, 140], 70: [151, 139, 192, 168, 213, 173],
  95: [182, 167, 232, 201, 258, 204], 120: [210, 192, 269, 232, 299, 231],
  150: [240, 219, 300, 258, 344, 261], 185: [273, 248, 341, 294, 392, 292],
  240: [321, 291, 400, 344, 461, 336], 300: [367, 334, 458, 394, 530, 379],
};
final Map<double, List<double>> memPvc3 = {
  1.5: [13.5, 13, 15.5, 15, 17.5, 18], 2.5: [18, 17.5, 21, 20, 24, 24],
  4: [24, 23, 28, 27, 32, 30], 6: [31, 29, 36, 34, 41, 38],
  10: [42, 39, 50, 46, 57, 50], 16: [56, 52, 68, 62, 76, 64],
  25: [73, 68, 89, 80, 96, 82], 35: [89, 83, 110, 99, 119, 98],
  50: [108, 99, 134, 118, 144, 116], 70: [136, 125, 171, 149, 184, 143],
  95: [164, 150, 207, 179, 223, 169], 120: [188, 172, 239, 206, 259, 192],
  150: [216, 196, 262, 225, 299, 217], 185: [245, 223, 296, 255, 341, 243],
  240: [286, 261, 346, 297, 403, 280], 300: [328, 298, 394, 339, 464, 316],
};
final Map<double, List<double>> memXlpe2 = {
  1.5: [19, 18.5, 23, 22, 24, 25], 2.5: [26, 25, 31, 30, 33, 33],
  4: [35, 33, 42, 40, 45, 43], 6: [45, 42, 54, 51, 58, 53],
  10: [61, 57, 75, 69, 80, 71], 16: [81, 76, 100, 91, 107, 91],
  25: [106, 99, 133, 119, 138, 116], 35: [131, 121, 164, 146, 171, 139],
  50: [158, 145, 198, 175, 209, 164], 70: [200, 183, 253, 221, 269, 203],
  95: [241, 220, 306, 265, 328, 239], 120: [278, 253, 354, 305, 382, 271],
  150: [318, 290, 393, 334, 441, 306], 185: [362, 329, 449, 384, 506, 343],
  240: [424, 386, 528, 459, 599, 395], 300: [486, 442, 603, 532, 693, 446],
};
final Map<double, List<double>> memXlpe3 = {
  1.5: [17, 16.5, 20, 19.5, 22, 21], 2.5: [23, 22, 28, 26, 30, 28],
  4: [31, 30, 37, 35, 40, 36], 6: [40, 38, 48, 44, 52, 44],
  10: [54, 51, 66, 60, 71, 58], 16: [73, 68, 88, 80, 96, 75],
  25: [95, 89, 117, 105, 119, 96], 35: [117, 109, 144, 128, 147, 115],
  50: [141, 130, 175, 154, 179, 135], 70: [179, 164, 222, 194, 229, 167],
  95: [216, 197, 269, 233, 278, 197], 120: [249, 227, 312, 268, 322, 223],
  150: [285, 259, 342, 300, 371, 251], 185: [324, 295, 384, 340, 424, 281],
  240: [380, 346, 450, 398, 500, 324], 300: [435, 396, 514, 455, 576, 365],
};

/// NEC 310.16 구리 [60, 75, 90°C]. 근거 문서에 숫자가 있는 줄: 12 AWG, 4/0 AWG, 500 kcmil, 18·16 AWG(90°C).
/// 나머지는 NEC 표를 기억으로 옮김(참고).
const Map<String, List<int?>> refNec31016 = {
  '18 AWG': [null, null, 14], '16 AWG': [null, null, 18],
  '14 AWG': [15, 20, 25], '12 AWG': [20, 25, 30], '10 AWG': [30, 35, 40],
  '8 AWG': [40, 50, 55], '6 AWG': [55, 65, 75], '4 AWG': [70, 85, 95],
  '3 AWG': [85, 100, 115], '2 AWG': [95, 115, 130], '1 AWG': [110, 130, 145],
  '1/0 AWG': [125, 150, 170], '2/0 AWG': [145, 175, 195],
  '3/0 AWG': [165, 200, 225], '4/0 AWG': [195, 230, 260],
  '250 kcmil': [215, 255, 290], '300 kcmil': [240, 285, 320],
  '350 kcmil': [260, 310, 350], '400 kcmil': [280, 335, 380],
  '500 kcmil': [320, 380, 430],
};
const Set<String> docNecRows = {
  '12 AWG',
  '4/0 AWG',
  '500 kcmil',
  '18 AWG',
  '16 AWG',
};

/// NEC 430.250 [230V, 460V](A). 근거 문서에 숫자가 없어 NEC 표를 기억으로 옮김(참고). 230V는 200hp까지만 적음.
final Map<double, List<double?>> memNec430250 = {
  0.5: [2.2, 1.1], 0.75: [3.2, 1.6], 1: [4.2, 2.1], 1.5: [6.0, 3.0],
  2: [6.8, 3.4], 3: [9.6, 4.8], 5: [15.2, 7.6], 7.5: [22, 11], 10: [28, 14],
  15: [42, 21], 20: [54, 27], 25: [68, 34], 30: [80, 40], 40: [104, 52],
  50: [130, 65], 60: [154, 77], 75: [192, 96], 100: [248, 124],
  125: [312, 156], 150: [360, 180], 200: [480, 240], 250: [null, 302],
  300: [null, 361], 350: [null, 414], 400: [null, 477], 450: [null, 515],
  500: [null, 590],
};

// ═══════════════════════ 독립 모델: 식 ═══════════════════════

/// 문서: 교류 I = P ÷ (k·V·역률·효율)(삼상 k = √3, 단상 1), 직류 I = P ÷ (V × 효율).
double refLoadCurrent(double kw, double v, Phase ph, double pf, double eff) {
  final w = kw * 1000;
  return switch (ph) {
    Phase.dc => w / (v * eff),
    Phase.single => w / (v * pf * eff),
    Phase.three => w / (math.sqrt(3) * v * pf * eff),
  };
}

/// 문서: ΣIM ≤ 50A 1.25배, 50A 초과 1.1배.
double refMotorMargin(double a) => a <= 50 ? 1.25 : 1.1;

int? refBreakerAtLeast(double ib) {
  for (final r in kBreakerRatings) {
    if (r >= ib - 1e-9) return r;
  }
  return null;
}

int? refBreakerAtMost(double a) {
  int? out;
  for (final r in kBreakerRatings) {
    if (r <= a + 1e-9) out = r;
  }
  return out;
}

class RefMotorRange {
  RefMotorRange(this.low, this.high, this.highA);
  final int? low;
  final int? high;
  final double highA;
}

/// 문서: 하한 = IB ≤ In ≤ IZ로 고른 정격, 상한 = min(정격 × 250%, 정격 × 3, 허용전류 × 2.5) 이하 표준 정격.
RefMotorRange refMotorRange(double load, int? low, double? iz) {
  var h = math.min(load * 2.5, load * 3);
  if (iz != null) h = math.min(h, iz * 2.5);
  var high = refBreakerAtMost(h);
  if (high != null && low != null && high < low) high = null;
  return RefMotorRange(low, high, h);
}

class RefChoice {
  int? breaker;
  double? byAmp;
  double? byDrop;
  double? size;
  double? iz;
  double? kt;
  double kg = 1;
  int count = 1;
  double limit = 0;
  double? dropPct;
  RefMotorRange? motor;
}

/// 전선 굵기 선정(문서: IB ≤ In ≤ IZ, 전압강하 한도, 병렬은 50sq 이상·가닥 합, 다조 수 = 회로 + 가닥 − 1).
/// 표 기본값은 앱 표(baseAmpacity)를 자료로 쓴다(문서에 표 숫자가 없음). 보정·선정 규칙은 독립.
RefChoice refChoose({
  required double load,
  required double margin,
  required double volts,
  required Phase phase,
  required Insulation ins,
  required InstallMethod method,
  required double? lengthM,
  required double pf,
  required double ambient,
  required int circuits,
  required int parallel,
  required GroupLayout layout,
  required SupplyType supply,
  required bool motor,
}) {
  final o = RefChoice();
  final n = math.max(1, parallel);
  final ib = load * margin;
  final dc = phase == Phase.dc;
  o.breaker = dc ? null : refBreakerAtLeast(ib);
  o.count = math.max(1, circuits) + n - 1;
  final ground = method == InstallMethod.d1 || method == InstallMethod.d2;
  final pvc = ins == Insulation.pvc70;
  o.kt = refKt(ambient, pvc, ground);
  o.kg = refGroup(o.count, layout);
  final need = o.breaker?.toDouble() ?? ib;
  final len = lengthM ?? 0;
  final check = len > 0;
  o.limit = refLimit(supply, len);
  final theta = pvc ? 70.0 : 90.0;
  final loaded = phase == Phase.three ? 3 : 2;
  for (final s in refSizes) {
    if (n > 1 && s < 50) continue;
    final b = baseAmpacity(s, ins, loaded, method);
    if (o.byAmp == null && b != null && o.kt != null) {
      if (b * o.kt! * o.kg * n >= need - 1e-9) o.byAmp = s;
    }
    if (check && o.byDrop == null) {
      final pct = refVd(load / n, len, s, phase, pf, theta) / volts * 100;
      if (pct <= o.limit + 1e-9) o.byDrop = s;
    }
  }
  if (o.byAmp != null && (!check || o.byDrop != null)) {
    o.size = check ? math.max(o.byAmp!, o.byDrop!) : o.byAmp;
  }
  if (o.size != null) {
    final b = baseAmpacity(o.size!, ins, loaded, method);
    o.iz = b! * o.kt! * o.kg * n;
    if (check) {
      o.dropPct = refVd(load / n, len, o.size!, phase, pf, theta) / volts * 100;
    }
  }
  if (motor && !dc) o.motor = refMotorRange(load, o.breaker, o.iz);
  return o;
}

// ── AWG(NEC) ──

/// NEC 310.15(B)(1) 보정. 문서: 30°C 기준, 5°C 구간 표, 든 구간(더운 쪽 경계)을 쓴다.
/// 표 숫자가 문서에 없어 바탕 식 √((Tc − Ta)/(Tc − 30))을 구간 더운 쪽 경계로 계산해 반올림.
double? refNecKt(double t, int colTemp) {
  var bin = (t / 5 - 1e-9).ceil() * 5.0;
  if (bin < 10) bin = 10;
  if (bin >= colTemp - 1e-9) return null;
  final v = math.sqrt((colTemp - bin) / (colTemp - 30));
  return (v * 100).round() / 100;
}

/// 문서: NEC 310.15(C)(1) 4~6 80%, 7~9 70%, 10~20 50%, 21~30 45%, 31~40 40%, 41 이상 35%.
double refNecAdj(int n) {
  if (n <= 3) return 1;
  if (n <= 6) return 0.8;
  if (n <= 9) return 0.7;
  if (n <= 20) return 0.5;
  if (n <= 30) return 0.45;
  if (n <= 40) return 0.4;
  return 0.35;
}

/// 문서: NEC 240.4(D) 18 7, 16 10, 14 15, 12 20, 10 30A.
int? refSmallOcpd(String label) => switch (label) {
  '18 AWG' => 7,
  '16 AWG' => 10,
  '14 AWG' => 15,
  '12 AWG' => 20,
  '10 AWG' => 30,
  _ => null,
};

int _colTemp(NecColumn c) => switch (c) {
  NecColumn.c60 => 60,
  NecColumn.c75 => 75,
  NecColumn.c90 => 90,
};

int? _colVal(AwgSize s, int temp) => switch (temp) {
  60 => s.a60,
  75 => s.a75,
  _ => s.a90,
};

/// 문서: 허용전류 = min(절연 열 × 온도 보정 × 가닥 감소, 단자 열 값). 단자 자동은 100A 이하 60°C, 넘으면 75°C.
/// 단자 열은 절연 열보다 높을 수 없다.
({double? corrected, int? limit, double? iz, int term}) refAwgAmp(
  AwgSize s,
  NecColumn col,
  NecTerminal t,
  double circuitA,
  double amb,
  int ccc,
) {
  final ct = _colTemp(col);
  var term = switch (t) {
    NecTerminal.c60 => 60,
    NecTerminal.c75 => 75,
    NecTerminal.auto => circuitA <= 100 ? 60 : 75,
  };
  if (term > ct) term = ct;
  final base = _colVal(s, ct);
  final kt = refNecKt(amb, ct);
  final corr = base == null || kt == null ? null : base * kt * refNecAdj(ccc);
  final lim = _colVal(s, term);
  final iz = corr == null || lim == null ? null : math.min(corr, lim.toDouble());
  return (corrected: corr, limit: lim, iz: iz, term: term);
}

// ── 단락 전류 ──

class _Z {
  const _Z(this.r, this.x);
  final double r;
  final double x;
  _Z operator +(_Z o) => _Z(r + o.r, x + o.x);
  double get abs => math.sqrt(r * r + x * x);
  _Z operator *(_Z o) => _Z(r * o.r - x * o.x, r * o.x + x * o.r);
  _Z operator /(_Z o) {
    final d = o.r * o.r + o.x * o.x;
    return _Z((r * o.r + x * o.x) / d, (x * o.r - r * o.x) / d);
  }

  _Z times(double k) => _Z(r * k, x * k);
}

/// 같은 모선의 두 전원이 케이블을 같이 지날 때(10-07 기준 바꿈): 모선에서는 두 몫 크기의 합,
/// 케이블 끝은 병렬 등가 임피던스(크기를 모선 합계에 맞춤) + 케이블. (합계, 계통 몫, 전동기 몫)
(double, double, double) _shared(double cU, _Z src, _Z mot, _Z cab) {
  final s3 = math.sqrt(3);
  final a = cU / (s3 * src.abs), b = cU / (s3 * mot.abs);
  final par = (src * mot) / (src + mot);
  final eq = par.times((cU / (s3 * (a + b))) / par.abs);
  final t = cU / (s3 * (eq + cab).abs);
  return (t, t * a / (a + b), t * b / (a + b));
}

typedef Seg = ({double size, double len, int n});

class RefSc {
  double kt = 0, zt = 0, rt = 0, xt = 0;
  double ikNet = 0, ikMotor = 0, ikMax = 0, ikPct = 0;
  double rx = 0, kappa = 0, ip = 0, ikMin3 = 0, ikMin2 = 0, motorRated = 0;
  final List<double> starts = [];
  final List<double> startIp = [];
}

/// 문서 전기_단락전류_근거.md "식" 1~7을 그대로 옮긴 계산.
RefSc refShortCircuit({
  required double kva,
  required double v,
  required double zPct,
  double? pcu,
  double? upMax,
  double? upMin,
  double? motorKw,
  double? effPf,
  double? mult,
  required double cMax,
  required bool pvc,
  List<Seg> segs = const [],
}) {
  final o = RefSc();
  final s = kva * 1000;
  final zb = v * v / s;
  o.zt = zPct / 100 * zb;
  o.rt = pcu == null ? 0 : (pcu * 1000 / s) * zb;
  o.xt = math.sqrt(o.zt * o.zt - o.rt * o.rt);
  o.kt = 0.95 * cMax / (1 + 0.6 * (o.xt / zb));
  _Z net(double c, double? mva) {
    if (mva == null) return const _Z(0, 0);
    final z = c * v * v / (mva * 1e6);
    final x = 0.995 * z;
    return _Z(0.1 * x, x);
  }

  _Z cable(int upto, double theta) {
    var z = const _Z(0, 0);
    for (var i = 0; i < upto; i++) {
      final g = segs[i];
      z = z + _Z(refR(g.size, theta) * g.len / 1000 / g.n, refX * g.len / 1000 / g.n);
    }
    return z;
  }

  // 최소 단락 케이블: IEC 909:1988(= IS 13234:1992) 9.3.1 식 (32) R = [1 + 0.004 × (θe − 20)] × R20,
  // θe = 단락 종료 온도(KEC 표 212.5-1 최종 온도: PVC 160°C, XLPE·EPR 250°C). 앱 함수를 쓰지 않고 표 값으로 직접 계산.
  _Z cableMin(double thetaE) {
    var z = const _Z(0, 0);
    for (final g in segs) {
      final r = refR20[g.size]! * (1 + 0.004 * (thetaE - 20));
      z = z + _Z(r * g.len / 1000 / g.n, refX * g.len / 1000 / g.n);
    }
    return z;
  }

  final tr = _Z(o.rt * o.kt, o.xt * o.kt);
  final up = net(cMax, upMax);
  final hasMotor = motorKw != null && effPf != null && mult != null;
  o.motorRated = hasMotor ? motorKw * 1000 / (math.sqrt(3) * v * effPf) : 0;
  // 저압 전동기 묶음(IEC 909 8.3.2.5): |ZM| = Un ÷ (√3·배수·IrM), RM/XM = 0.42, κM = 1.3.
  final zmAbs = hasMotor ? v / (math.sqrt(3) * mult * o.motorRated) : 0.0;
  final xmM = zmAbs / math.sqrt(1 + 0.42 * 0.42);
  final zm = _Z(0.42 * xmM, xmM);
  double netAt(int k) => hasMotor
      ? _shared(cMax * v, up + tr, zm, cable(k, 20)).$2
      : cMax * v / (math.sqrt(3) * (up + tr + cable(k, 20)).abs);
  double motAt(int k) {
    if (!hasMotor) return 0;
    return _shared(cMax * v, up + tr, zm, cable(k, 20)).$3;
  }

  double ipAt(int k) {
    final z = up + tr + cable(k, 20);
    final rx = z.x == 0 ? 0.0 : z.r / z.x;
    final kap = 1.02 + 0.98 * math.exp(-3 * rx);
    return kap * math.sqrt2 * netAt(k) + 1.3 * math.sqrt2 * motAt(k);
  }

  for (var k = 0; k <= segs.length; k++) {
    o.starts.add(netAt(k) + motAt(k));
    o.startIp.add(ipAt(k));
  }
  final zf = up + tr + cable(segs.length, 20);
  o.ikNet = netAt(segs.length);
  o.ikMotor = motAt(segs.length);
  o.ikMax = o.ikNet + o.ikMotor;
  o.rx = zf.r / zf.x;
  o.kappa = 1.02 + 0.98 * math.exp(-3 * o.rx);
  o.ip = o.kappa * math.sqrt2 * o.ikNet + 1.3 * math.sqrt2 * o.ikMotor;
  final thetaE = pvc ? 160.0 : 250.0;
  final zMin = net(0.95, upMin ?? upMax) + tr + cableMin(thetaE);
  o.ikMin3 = 0.95 * v / (math.sqrt(3) * zMin.abs);
  o.ikMin2 = math.sqrt(3) / 2 * o.ikMin3;
  final zP = net(1.0, upMax) + _Z(o.rt, o.xt) + cable(segs.length, 20);
  // 문서에는 %임피던스법에 전동기 기여를 넣는지 적혀 있지 않다. 처음에는 빼고 짰다가 앱(ScResult 주석
  // "같은 조건을 %임피던스법으로")과 704조합이 달라 (c)로 보고, 같은 조건 = 전동기 기여도 c 없이(c = 1) 더하는
  // 것으로 맞췄다. 이 부분은 근거 문서로 확인한 것이 아니다.
  o.ikPct = hasMotor
      ? _shared(v, net(1.0, upMax) + _Z(o.rt, o.xt), zm, cable(segs.length, 20)).$1
      : v / (math.sqrt(3) * zP.abs);
  return o;
}

// ── 축전지 ──

/// K 값을 찾는 열쇠(앱 입력 약속: 분, 소수 둘째 자리, 뒤 0 뗌).
String refKey(double m) {
  var s = m.toStringAsFixed(2);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// 시험용 K(시간) — 아무 양수 함수면 된다(제조사 표 흉내).
double kOf(double minutes) =>
    0.25 + 1.04 * minutes / 60 + 0.18 * math.sqrt(minutes / 60);

// ═══════════════════════ 시험 ═══════════════════════

void main() {
  // ───────────── 1. 부하 전류 ─────────────
  group('부하 전류', () {
    test('단상·삼상·직류 부하 전류', () {
      final t = Tally('부하 전류(단상·삼상·직류)');
      const kws = <double>[0.1, 0.75, 1.5, 3.7, 5.5, 7.5, 11, 15, 22, 37, 55, 75, 110, 200, 500];
      const pfs = [0.7, 0.8, 0.85, 0.9, 1.0];
      const effs = [0.8, 0.9, 0.95, 1.0];
      const volts = {
        Phase.single: [110.0, 220.0],
        Phase.three: [380.0, 440.0, 480.0],
        Phase.dc: [24.0, 48.0, 110.0, 125.0, 220.0],
      };
      for (final ph in Phase.values) {
        for (final v in volts[ph]!) {
          for (final kw in kws) {
            for (final pf in pfs) {
              // 직류는 역률을 쓰지 않는다: 역률 0.7을 넣어도 무시되는지 본다.
              if (ph == Phase.dc && pf != 0.7) continue;
              for (final eff in effs) {
                t.run('$ph ${v}V ${kw}kW pf$pf eff$eff', (c) {
                  c.n(
                    'I',
                    loadCurrent(kw: kw, volts: v, phase: ph, pf: pf, eff: eff),
                    refLoadCurrent(kw, v, ph, pf, eff),
                  );
                });
              }
            }
          }
        }
      }
      t.finish();
    });

    test('전류 ↔ 피상전력', () {
      final t = Tally('전류↔kVA');
      for (final ph in Phase.values) {
        for (final v in [24.0, 110.0, 220.0, 380.0, 440.0, 480.0]) {
          for (final a in [0.5, 1.0, 10.0, 21.8, 50.0, 100.0, 400.0, 1500.0]) {
            t.run('$ph ${v}V ${a}A', (c) {
              final k = ph == Phase.three ? math.sqrt(3) : 1.0;
              final kva = k * v * a / 1000;
              c.n('kVA', kvaFromCurrent(current: a, volts: v, phase: ph), kva);
              c.n('A', currentFromKva(kva: kva, volts: v, phase: ph), a);
            });
          }
        }
      }
      t.finish();
    });
  });

  // ───────────── 2. 전압강하 ─────────────
  group('전압강하', () {
    test('KEC 식 ΔU = k·I·L·(R cosφ + X sinφ), 직류 2·I·L·R', () {
      final t = Tally('전압강하 KEC 식');
      for (final size in refR20.keys) {
        for (final i in [5.0, 20.0, 63.0, 150.0, 400.0]) {
          for (final l in [10.0, 50.0, 120.0, 300.0]) {
            for (final pf in [0.35, 0.8, 0.85, 1.0]) {
              for (final th in [20.0, 70.0, 90.0]) {
                for (final ph in Phase.values) {
                  t.run('${size}sq ${i}A ${l}m pf$pf ${th}°C $ph', (c) {
                    c.n(
                      'ΔU',
                      voltageDrop(
                        current: i,
                        lengthM: l,
                        size: size,
                        phase: ph,
                        pf: pf,
                        conductorTempC: th,
                      ),
                      refVd(i, l, size, ph, pf, th),
                    );
                  });
                }
              }
            }
          }
        }
      }
      t.finish();
    });

    test('현장 간이식 35.6·30.8', () {
      // 문서: 간이식 35.6(단상 2선)·30.8(삼상 3선) × L × I ÷ (1000 × A). 직류 2선도 35.6으로 본다.
      final t = Tally('전압강하 간이식');
      for (final size in refSizes) {
        for (final i in [5.0, 30.0, 100.0, 300.0]) {
          for (final l in [10.0, 75.0, 250.0]) {
            for (final ph in Phase.values) {
              t.run('${size}sq ${i}A ${l}m $ph', (c) {
                final k = ph == Phase.three ? 30.8 : 35.6;
                c.n(
                  'e',
                  voltageDropSimple(current: i, lengthM: l, size: size, phase: ph),
                  k * l * i / (1000 * size),
                );
              });
            }
          }
        }
      }
      t.finish();
    });

    test('전압강하 한도 KEC 232.3.9', () {
      final t = Tally('전압강하 한도');
      for (final s in SupplyType.values) {
        for (final l in [0.0, 50.0, 100.0, 100.5, 101.0, 150.0, 199.0, 200.0, 250.0, 1000.0]) {
          t.run('$s ${l}m', (c) {
            c.n('한도%', voltageDropLimit(s, l), refLimit(s, l));
          });
        }
      }
      t.finish();
    });

    test('한도 이내 최대 편도 길이', () {
      final t = Tally('최대 편도 길이');
      for (final size in refSizes) {
        for (final i in [10.0, 50.0, 150.0]) {
          for (final ph in Phase.values) {
            for (final sup in SupplyType.values) {
              for (final pf in [0.85, 1.0]) {
                for (final th in [70.0, 90.0]) {
                  for (final res in [0.0, 1.0, 2.5]) {
                    final v = switch (ph) {
                      Phase.single => 220.0,
                      Phase.three => 380.0,
                      Phase.dc => 125.0,
                    };
                    t.run('${size}sq ${i}A $ph $sup pf$pf ${th}°C 전원쪽$res%', (c) {
                      final a = refVd(i, 1, size, ph, pf, th) / v * 100;
                      c.n(
                        'L',
                        maxLengthForDrop(
                          current: i,
                          size: size,
                          phase: ph,
                          volts: v,
                          pf: pf,
                          conductorTempC: th,
                          supply: sup,
                          reservedPct: res,
                        ),
                        refMaxLen(a, sup, res),
                        rel: 1e-6,
                      );
                    });
                  }
                }
              }
            }
          }
        }
      }
      t.finish();
    });
  });

  // ───────────── 3. 허용전류 표·보정 ─────────────
  group('허용전류 표·보정계수', () {
    test('근거 문서에 숫자가 있는 표 칸', () {
      final t = Tally('허용전류 표(문서 값)');
      // 전기계산기_근거.md: "C열 2.5mm² PVC 2가닥 27A", "B.52.10 70mm² 196, 120mm² 276"(PVC, 방법 E, 3가닥).
      t.run('B.52.2 C 2.5 PVC 2가닥', (c) {
        c.n('A', baseAmpacity(2.5, Insulation.pvc70, 2, InstallMethod.c), 27);
      });
      t.run('B.52.10 E 70 PVC 3가닥', (c) {
        c.n('A', baseAmpacity(70, Insulation.pvc70, 3, InstallMethod.e), 196);
      });
      t.run('B.52.10 E 120 PVC 3가닥', (c) {
        c.n('A', baseAmpacity(120, Insulation.pvc70, 3, InstallMethod.e), 276);
      });
      // 직류는 2가닥 열(단상과 같은 값)을 쓴다: correctedAmpacity로 직류 = 단상인지.
      for (final s in refSizes) {
        for (final m in InstallMethod.values) {
          for (final ins in Insulation.values) {
            t.run('직류=단상 ${s}sq $m $ins', (c) {
              c.n(
                'A',
                correctedAmpacity(size: s, ins: ins, phase: Phase.dc, method: m),
                correctedAmpacity(size: s, ins: ins, phase: Phase.single, method: m),
              );
            });
          }
        }
      }
      t.finish();
    });

    test('온도 보정계수 B.52.14·B.52.15 (바탕 식으로 만든 값)', () {
      final t = Tally('온도 보정계수');
      final temps = <double>[
        for (var x = 0; x <= 90; x++) x.toDouble(),
        12.5, 30.01, 32.5, 47.3, 59.99, 60.01, 79.9, 80.2,
      ];
      for (final g in [false, true]) {
        for (final ins in Insulation.values) {
          for (final x in temps) {
            t.run('${g ? '지중' : '공기'} $ins ${x}°C', (c) {
              c.n(
                'k',
                tempFactor(x, ins, ground: g),
                refKt(x, ins == Insulation.pvc70, g),
              );
            });
          }
        }
      }
      t.finish();
    });

    test('다조 보정 B.52.17 1행(근거 문서 값)', () {
      final t = Tally('다조 보정 1행(문서)');
      for (var n = 1; n <= 30; n++) {
        t.run('묶음 $n회로', (c) {
          c.n('k', groupFactor(n, GroupLayout.bunched), refGroup(n, GroupLayout.bunched));
        });
      }
      t.finish();
    });

    test('병렬 가닥이 다조 수에 들어가는지(회로 + 가닥 − 1)', () {
      final t = Tally('다조 수');
      for (var c0 = 0; c0 <= 25; c0++) {
        for (var p = 0; p <= 6; p++) {
          t.run('회로 $c0 가닥 $p', (c) {
            c.eq('n', groupCount(c0, p), math.max(1, c0) + math.max(1, p) - 1);
          });
        }
      }
      t.finish();
    });

    test('참고: 다조 보정 2·4·5행·B.52.18·B.52.19(기억 값)', () {
      final t = Tally('다조 보정 다른 행(기억 값, 참고)');
      for (final l in GroupLayout.values) {
        if (l == GroupLayout.bunched) continue;
        for (var n = 1; n <= 25; n++) {
          t.run('$l $n', (c) => c.n('k', groupFactor(n, l), refGroup(n, l)));
        }
      }
      t.finish();
    });

    test('참고: IEC 60364-5-52 B.52.2~B.52.5 A1·A2·B1·B2·C·D1(기억 값)', () {
      final t = Tally('허용전류 표(기억 값, 참고)');
      const cols = [
        InstallMethod.a1,
        InstallMethod.a2,
        InstallMethod.b1,
        InstallMethod.b2,
        InstallMethod.c,
        InstallMethod.d1,
      ];
      final tables = <(String, Insulation, int, Map<double, List<double>>)>[
        ('B.52.2 PVC 2가닥', Insulation.pvc70, 2, memPvc2),
        ('B.52.4 PVC 3가닥', Insulation.pvc70, 3, memPvc3),
        ('B.52.3 XLPE 2가닥', Insulation.xlpe90, 2, memXlpe2),
        ('B.52.5 XLPE 3가닥', Insulation.xlpe90, 3, memXlpe3),
      ];
      for (final (name, ins, loaded, mem) in tables) {
        for (final s in refSizes) {
          for (var i = 0; i < cols.length; i++) {
            t.run('$name ${s}sq ${cols[i].name}', (c) {
              c.n('A', baseAmpacity(s, ins, loaded, cols[i]), mem[s]![i], rel: 0);
            });
          }
        }
      }
      t.finish(show: 30);
    });

    test('참고: IEC 60228 20°C 저항(0.75·1.0은 문서 값)', () {
      final t = Tally('도체 저항 R20');
      for (final e in refR20.entries) {
        t.run('${e.key}sq', (c) => c.n('Ω/km', kCuR20[e.key], e.value, rel: 0));
      }
      t.finish();
    });
  });

  // ───────────── 4. 전선 굵기 선정 ─────────────
  group('전선 굵기 선정', () {
    test('전동기 여유 배수(50A 이하 1.25, 초과 1.1)', () {
      final t = Tally('전동기 여유 배수');
      for (var a = 0.5; a <= 200; a += 0.5) {
        t.run('${a}A', (c) => c.n('배수', motorMargin(a), refMotorMargin(a)));
      }
      t.finish();
    });

    test('문서 예: 11kW 380V 21.8A 전동기 → 차단기 30A ~ 50A', () {
      final r = chooseCable(
        load: 21.8,
        margin: 1.25,
        volts: 380,
        phase: Phase.three,
        ins: Insulation.xlpe90,
        method: InstallMethod.e,
        motor: true,
      );
      expect(r.motorRange?.low, 30);
      expect(r.motorRange?.high, 50);
    });

    test('chooseCable 무작위 4000조합', () {
      final t = Tally('전선 굵기 선정(chooseCable)');
      var pickedN = 0;
      var dropN = 0;
      var parN = 0;
      final rnd = math.Random(20261003);
      const loads = [2.0, 5.0, 8.0, 13.0, 21.8, 30.0, 47.0, 63.0, 88.0, 120.0, 175.0, 240.0, 330.0, 450.0, 600.0];
      for (var k = 0; k < 4000; k++) {
        final ph = _pick(rnd, Phase.values);
        final volts = switch (ph) {
          Phase.single => _pick(rnd, [110.0, 220.0]),
          Phase.three => _pick(rnd, [380.0, 440.0, 480.0]),
          Phase.dc => _pick(rnd, [24.0, 110.0, 125.0]),
        };
        final load = _pick(rnd, loads);
        final motor = rnd.nextBool();
        final margin = motor ? refMotorMargin(load) : 1.0;
        final ins = _pick(rnd, Insulation.values);
        final m = _pick(rnd, InstallMethod.values);
        final ground = m == InstallMethod.d1 || m == InstallMethod.d2;
        final amb = ground
            ? _pick(rnd, [5.0, 10.0, 15.0, 20.0, 22.0, 25.0, 30.0, 45.0, 65.0])
            : _pick(rnd, [5.0, 10.0, 20.0, 25.0, 30.0, 32.0, 35.0, 40.0, 45.0, 50.0, 55.0, 62.0, 70.0, 85.0]);
        final circuits = _pick(rnd, [1, 1, 2, 3, 4, 6, 9, 10, 13, 20, 25]);
        final parallel = _pick(rnd, [1, 1, 1, 2, 3]);
        final layout = ground
            ? _pick(rnd, [GroupLayout.groundDirect, GroupLayout.groundDuct, GroupLayout.bunched])
            : _pick(rnd, [GroupLayout.bunched, GroupLayout.wallSingleLayer, GroupLayout.perforatedTray, GroupLayout.ladder]);
        final len = _pick(rnd, <double?>[null, 0, 15, 40, 80, 100, 150, 250]);
        final pf = _pick(rnd, [0.8, 0.85, 0.9, 1.0]);
        final sup = _pick(rnd, SupplyType.values);
        final label =
            '$ph ${volts}V ${load}A×$margin ${ins.name} ${m.name} ${amb}°C 회로$circuits 병렬$parallel ${layout.name} ${len}m pf$pf ${sup.name}${motor ? ' 전동기' : ''}';
        t.run(label, (c) {
          final a = chooseCable(
            load: load,
            margin: margin,
            volts: volts,
            phase: ph,
            ins: ins,
            method: m,
            lengthM: len,
            pf: pf,
            ambientC: amb,
            circuits: circuits,
            parallel: parallel,
            layout: layout,
            supply: sup,
            motor: motor,
          );
          final r = refChoose(
            load: load,
            margin: margin,
            volts: volts,
            phase: ph,
            ins: ins,
            method: m,
            lengthM: len,
            pf: pf,
            ambient: amb,
            circuits: circuits,
            parallel: parallel,
            layout: layout,
            supply: sup,
            motor: motor,
          );
          c.n('IB', a.ib, load * margin);
          c.eq('차단기', a.breaker, r.breaker);
          c.n('kt', a.tempFactor, r.kt ?? 0);
          c.n('kg', a.groupFactor, r.kg);
          c.eq('다조 수', a.groupCount, r.count);
          c.n('한도%', a.dropLimitPct, r.limit);
          c.eq('허용전류 굵기', a.sizeByAmpacity, r.byAmp);
          c.eq('전압강하 굵기', a.sizeByDrop, r.byDrop);
          c.eq('선정 굵기', a.size, r.size);
          if (r.size != null) pickedN++;
          if (r.size != null && r.size != r.byAmp) dropN++;
          if (parallel > 1 && r.size != null) parN++;
          c.n('IZ', a.iz, r.iz);
          c.n('강하%', a.dropPct, r.dropPct);
          c.eq('전동기 하한', a.motorRange?.low, r.motor?.low);
          c.eq('전동기 상한', a.motorRange?.high, r.motor?.high);
          c.n('전동기 상한A', a.motorRange?.highA, r.motor?.highA);
        });
      }
      print('    (굵기가 정해진 조합 $pickedN개, 전압강하로 굵어진 조합 $dropN개, 병렬 조합 $parN개)');
      t.finish();
    });

    test('checkCircuit(기존 회로 점검) 무작위 3000조합', () {
      final t = Tally('기존 회로 점검(checkCircuit)');
      final rnd = math.Random(777);
      for (var k = 0; k < 3000; k++) {
        final ph = _pick(rnd, Phase.values);
        final volts = switch (ph) {
          Phase.single => 220.0,
          Phase.three => _pick(rnd, [380.0, 440.0]),
          Phase.dc => 125.0,
        };
        final size = _pick(rnd, refSizes);
        final load = _pick(rnd, <double?>[null, 3, 12, 25, 48, 75, 130, 260, 420]);
        final motor = rnd.nextBool();
        final margin = motor && load != null ? refMotorMargin(load) : 1.0;
        final breaker = _pick(rnd, <int?>[null, ...kBreakerRatings]);
        final ins = _pick(rnd, Insulation.values);
        final m = _pick(rnd, InstallMethod.values);
        final ground = m == InstallMethod.d1 || m == InstallMethod.d2;
        final amb = _pick(rnd, [10.0, 20.0, 30.0, 37.0, 40.0, 50.0, 65.0]);
        final circuits = _pick(rnd, [1, 2, 5, 9, 14, 22]);
        final parallel = _pick(rnd, [1, 1, 2, 4]);
        final layout = ground
            ? _pick(rnd, [GroupLayout.groundDirect, GroupLayout.groundDuct])
            : _pick(rnd, [GroupLayout.bunched, GroupLayout.ladder, GroupLayout.perforatedTray, GroupLayout.wallSingleLayer]);
        final len = _pick(rnd, <double?>[null, 25, 90, 180]);
        final pf = _pick(rnd, [0.8, 0.9, 1.0]);
        final sup = _pick(rnd, SupplyType.values);
        t.run('$ph ${size}sq 부하$load×$margin 차단기$breaker ${ins.name} ${m.name} ${amb}°C 회로$circuits 병렬$parallel ${layout.name} ${len}m${motor ? ' 전동기' : ''}', (c) {
          final a = checkCircuit(
            size: size,
            load: load,
            margin: margin,
            breaker: breaker,
            volts: volts,
            phase: ph,
            ins: ins,
            method: m,
            lengthM: len,
            pf: pf,
            ambientC: amb,
            circuits: circuits,
            parallel: parallel,
            layout: layout,
            supply: sup,
            motor: motor,
          );
          final n = math.max(1, parallel);
          final count = math.max(1, circuits) + n - 1;
          final kt = refKt(amb, ins == Insulation.pvc70, ground);
          final kg = refGroup(count, layout);
          final b = baseAmpacity(size, ins, ph == Phase.three ? 3 : 2, m);
          final iz = b == null || kt == null ? null : b * kt * kg * n;
          final ib = load == null || load <= 0 ? null : load * margin;
          bool? ibOk;
          bool? inOk;
          if (ib != null && breaker != null) ibOk = ib <= breaker + 1e-9;
          if (ib != null && breaker == null && iz != null) ibOk = ib <= iz + 1e-9;
          if (breaker != null && iz != null) inOk = breaker <= iz + 1e-9;
          final checkDrop = (len ?? 0) > 0 && (load ?? 0) > 0;
          final theta = ins == Insulation.pvc70 ? 70.0 : 90.0;
          final dropPct = checkDrop
              ? refVd(load! / n, len!, size, ph, pf, theta) / volts * 100
              : null;
          final mr = motor && ib != null && ph != Phase.dc
              ? refMotorRange(load!, refBreakerAtLeast(ib), iz)
              : null;
          final overOk = mr != null && breaker != null && inOk == false
              ? breaker <= mr.highA + 1e-9
              : false;
          c.n('IZ', a.iz, iz);
          c.n('IB', a.ib, ib);
          c.eq('IB≤In', a.ibOk, ibOk);
          c.eq('In≤IZ', a.inOk, inOk);
          c.n('kt', a.tempFactor, kt ?? 0);
          c.n('kg', a.groupFactor, kg);
          c.eq('다조 수', a.groupCount, count);
          c.n('한도%', a.dropLimitPct, refLimit(sup, checkDrop ? len! : 0));
          c.n('강하%', a.dropPct, dropPct);
          c.eq('전동기 하한', a.motorRange?.low, mr?.low);
          c.eq('전동기 상한', a.motorRange?.high, mr?.high);
          c.eq('계전기로 보호 허용', a.motorOverIzAllowed, overOk);
        });
      }
      t.finish();
    });

    test('보호도체 KEC 표 142.3-1·따로 포설 최소', () {
      final t = Tally('보호도체');
      for (final s in [...refSizes, 0.75, 1.0, 17.0, 36.0, 400.0]) {
        // 문서: S ≤ 16 → S, ≤ 35 → 16, 넘으면 S/2.
        final tableVal = s <= 16 ? s : (s <= 35 ? 16.0 : s / 2);
        t.run('${s}sq 표 식(접지 탭)', (c) {
          c.n('S', gc.protectiveConductorFromTable(s), tableVal);
        });
        // 전선 굵기 탭의 peConductorSize는 S/2를 표준 굵기로 올린다(문서에 올림 규칙은 없음 → S/2 이상인
        // 가장 작은 표준 굵기인지로 본다. 표 끝을 넘으면 S/2 그대로).
        double up(double x) {
          for (final z in refSizes) {
            if (z >= x - 1e-9) return z;
          }
          return x;
        }

        final pe = s <= 35 ? tableVal : up(s / 2);
        t.run('${s}sq 표(전선 굵기 탭)', (c) {
          c.n('S', peConductorSize(s), pe);
          c.n('따로·보호', peSeparateSize(s, mechProtected: true), math.max(pe, 2.5));
          c.n('따로·비보호', peSeparateSize(s, mechProtected: false), math.max(pe, 4.0));
        });
      }
      t.finish();
    });
  });

  // ───────────── 5. AWG(NEC) ─────────────
  group('AWG·kcmil', () {
    test('NEC 310.16 표(문서 값)·Table 8(문서 값)·240.4(D)·310.15(C)(1)', () {
      final t = Tally('NEC 표(문서 값)');
      for (final s in kAwgSizes) {
        if (!docNecRows.contains(s.label)) continue;
        final r = refNec31016[s.label]!;
        t.run(s.label, (c) {
          c.eq('60', s.a60, r[0]);
          c.eq('75', s.a75, r[1]);
          c.eq('90', s.a90, r[2]);
        });
      }
      // 전기계산기_근거.md: 12 AWG 3.31mm² 6.50Ω/km, 4/0 107.2mm² 0.1996Ω/km, 500 kcmil 253mm² 0.0845Ω/km.
      for (final (l, a, r) in [
        ('12 AWG', 3.31, 6.50),
        ('4/0 AWG', 107.2, 0.1996),
        ('500 kcmil', 253.0, 0.0845),
      ]) {
        t.run('Table 8 $l', (c) {
          final s = awgByLabel(l)!;
          c.n('mm²', s.mm2, a, rel: 0);
          c.n('Ω/km', s.r75, r, rel: 0);
        });
      }
      for (final s in kAwgSizes) {
        t.run('240.4(D) ${s.label}', (c) {
          c.eq('A', necSmallConductorMaxOcpd(s), refSmallOcpd(s.label));
        });
      }
      for (var n = 0; n <= 60; n++) {
        t.run('310.15(C)(1) $n가닥', (c) => c.n('k', necAdjustFactor(n), refNecAdj(n)));
      }
      t.finish();
    });

    test('NEC 온도 보정 310.15(B)(1) (바탕 식으로 만든 값)', () {
      final t = Tally('NEC 온도 보정');
      final temps = <double>[
        for (var x = -5; x <= 95; x++) x.toDouble(),
        30.5, 35.01, 54.9, 85.5,
      ];
      for (final col in NecColumn.values) {
        for (final x in temps) {
          t.run('${col.name} ${x}°C', (c) {
            c.n('k', necTempFactor(x, col), refNecKt(x, _colTemp(col)));
          });
        }
      }
      t.finish();
    });

    test('참고: NEC 310.16 나머지 줄(기억 값)', () {
      final t = Tally('NEC 310.16(기억 값, 참고)');
      for (final s in kAwgSizes) {
        final r = refNec31016[s.label];
        t.run(s.label, (c) {
          c.eq('줄 있음', r != null, true);
          if (r == null) return;
          c.eq('60', s.a60, r[0]);
          c.eq('75', s.a75, r[1]);
          c.eq('90', s.a90, r[2]);
        });
      }
      t.finish();
    });

    test('awgAmpacity 격자', () {
      final t = Tally('AWG 허용전류(awgAmpacity)');
      for (final s in kAwgSizes) {
        for (final col in NecColumn.values) {
          for (final term in NecTerminal.values) {
            for (final amb in [10.0, 25.0, 30.0, 33.0, 41.0, 50.0, 58.0, 72.0, 84.0]) {
              for (final ccc in [2, 3, 5, 8, 15, 28, 35, 50]) {
                for (final ca in [40.0, 100.0, 100.5, 250.0]) {
                  t.run('${s.label} ${col.name} ${term.name} ${amb}°C ${ccc}가닥 ${ca}A', (c) {
                    final a = awgAmpacity(
                      s,
                      column: col,
                      terminal: term,
                      circuitA: ca,
                      ambientC: amb,
                      currentCarrying: ccc,
                    );
                    final r = refAwgAmp(s, col, term, ca, amb, ccc);
                    c.n('보정', a.corrected, r.corrected);
                    c.eq('단자 값', a.terminalLimit, r.limit);
                    c.n('IZ', a.iz, r.iz);
                    c.eq('단자 열', _colTemp(a.terminal), r.term);
                  });
                }
              }
            }
          }
        }
      }
      t.finish();
    });

    test('chooseAwg 무작위 2500조합', () {
      final t = Tally('AWG 굵기 선정(chooseAwg)');
      var pickedN = 0;
      var dropN = 0;
      final rnd = math.Random(4242);
      for (var k = 0; k < 2500; k++) {
        final ph = _pick(rnd, Phase.values);
        final volts = switch (ph) {
          Phase.single => _pick(rnd, [120.0, 220.0]),
          Phase.three => _pick(rnd, [380.0, 480.0]),
          Phase.dc => _pick(rnd, [24.0, 125.0]),
        };
        final load = _pick(rnd, [3.0, 9.0, 14.0, 16.0, 19.0, 24.0, 29.0, 38.0, 55.0, 80.0, 99.0, 130.0, 210.0, 330.0, 450.0]);
        final motor = rnd.nextBool();
        final margin = motor ? 1.25 : 1.0; // 문서: AWG 모드 전동기는 늘 1.25배(NEC 430.22).
        final col = _pick(rnd, NecColumn.values);
        final term = _pick(rnd, NecTerminal.values);
        final amb = _pick(rnd, [10.0, 20.0, 30.0, 33.0, 40.0, 47.0, 55.0, 65.0, 80.0]);
        final ccc = _pick(rnd, [2, 3, 4, 6, 8, 12, 25, 35, 45]);
        final len = _pick(rnd, <double?>[null, 30, 120, 250]);
        final pf = _pick(rnd, [0.8, 0.9, 1.0]);
        final sup = _pick(rnd, SupplyType.values);
        t.run('$ph ${volts}V ${load}A×$margin ${col.name} ${term.name} ${amb}°C ${ccc}가닥 ${len}m pf$pf ${sup.name}${motor ? ' 전동기' : ''}', (c) {
          final a = chooseAwg(
            load: load,
            margin: margin,
            volts: volts,
            phase: ph,
            column: col,
            terminal: term,
            ambientC: amb,
            currentCarrying: ccc,
            lengthM: len,
            pf: pf,
            supply: sup,
            motor: motor,
          );
          final ib = load * margin;
          final l = len ?? 0;
          final check = l > 0;
          final limit = refLimit(sup, l);
          AwgSize? byAmp;
          AwgSize? byDrop;
          for (final s in kAwgSizes) {
            if (s.a60 == null) continue; // 문서: 굵기 선정은 14 AWG부터
            if (byAmp == null) {
              final r = refAwgAmp(s, col, term, ib, amb, ccc);
              final ocpd = motor ? null : refSmallOcpd(s.label);
              if (r.iz != null && r.iz! >= ib - 1e-9 && (ocpd == null || ocpd >= ib - 1e-9)) {
                byAmp = s;
              }
            }
            if (check && byDrop == null) {
              final pct = refVdR(load, l, s.r75, ph, pf) / volts * 100;
              if (pct <= limit + 1e-9) byDrop = s;
            }
          }
          AwgSize? size;
          if (byAmp != null && (!check || byDrop != null)) {
            size = !check || byAmp.mm2 >= byDrop!.mm2 ? byAmp : byDrop;
          }
          c.n('IB', a.ib, ib);
          c.n('kt', a.tempFactor, refNecKt(amb, _colTemp(col)));
          c.n('k가닥', a.adjustFactor, refNecAdj(ccc));
          c.eq('허용전류 굵기', a.byAmpacity?.label, byAmp?.label);
          c.eq('전압강하 굵기', a.byDrop?.label, byDrop?.label);
          c.eq('선정 굵기', a.size?.label, size?.label);
          if (size != null) pickedN++;
          if (size != null && size != byAmp) dropN++;
          c.n('한도%', a.dropLimitPct, limit);
          if (size != null) {
            c.n('IZ', a.amp?.iz, refAwgAmp(size, col, term, ib, amb, ccc).iz);
            c.n(
              '강하%',
              a.dropPct,
              check ? refVdR(load, l, size.r75, ph, pf) / volts * 100 : null,
            );
          }
        });
      }
      print('    (굵기가 정해진 조합 $pickedN개, 전압강하로 굵어진 조합 $dropN개)');
      t.finish();
    });
  });

  // ───────────── 6. 역률 개선 ─────────────
  group('역률 개선', () {
    test('Qc = P(tanφ1 − tanφ2), μF = Qc ÷ (2πfV²·10⁻⁹)', () {
      final t = Tally('역률 개선 콘덴서');
      double tanOf(double pf) => math.tan(math.acos(pf));
      for (final p in [1.0, 5.5, 15.0, 37.0, 75.0, 150.0, 500.0]) {
        for (final pf1 in [0.5, 0.6, 0.7, 0.75, 0.8, 0.85, 0.9, 0.95]) {
          for (final pf2 in [0.85, 0.9, 0.92, 0.95, 0.98, 1.0]) {
            for (final v in [220.0, 380.0, 440.0]) {
              for (final f in [50.0, 60.0]) {
                t.run('${p}kW $pf1→$pf2 ${v}V ${f}Hz', (c) {
                  final q = pf2 <= pf1 ? 0.0 : p * (tanOf(pf1) - tanOf(pf2));
                  c.n('kvar', capacitorKvar(p, pf1, pf2), q, abs: 1e-9);
                  c.n('μF', capacitorMicroFarad(q, v, hz: f), q / (2 * math.pi * f * v * v * 1e-9), abs: 1e-9);
                });
              }
            }
          }
        }
      }
      // 문서 예(삼화엔지니어링): 220V 100μF 1.82kvar, 380V 20μF 1.089kvar, 440V 20μF 1.46kvar.
      for (final (v, uf, kvar) in [(220.0, 100.0, 1.82), (380.0, 20.0, 1.089), (440.0, 20.0, 1.46)]) {
        t.run('문서 예 ${v}V ${uf}μF', (c) {
          c.n('μF', capacitorMicroFarad(kvar, v), uf);
        });
      }
      t.finish();
    });
  });

  // ───────────── 7. 부하 합산 ─────────────
  group('부하 합산', () {
    test('부하 합산·변압기 이용률 무작위 1500조합', () {
      final t = Tally('부하 합산');
      final rnd = math.Random(99);
      for (var k = 0; k < 1500; k++) {
        final nRows = 1 + rnd.nextInt(10);
        final rows = <LoadRowInput>[];
        var sp = 0.0, sq = 0.0, total = 0.0;
        for (var i = 0; i < nRows; i++) {
          final kw = _pick(rnd, [0.4, 2.2, 5.5, 11.0, 18.5, 37.0, 75.0, 120.0, 250.0]);
          final pf = _pick(rnd, [70.0, 80.0, 85.0, 90.0, 95.0, 100.0]);
          final df = _pick(rnd, [30.0, 50.0, 70.0, 80.0, 100.0]);
          rows.add(LoadRowInput(name: 'L$i', kw: '$kw', pf: '$pf', df: '$df'));
          final p = kw * df / 100;
          sp += p;
          sq += p * math.tan(math.acos(pf / 100));
          total += kw;
        }
        final div = _pick(rnd, [1.0, 1.1, 1.3, 1.5]);
        final mar = _pick(rnd, [0.0, 10.0, 25.0]);
        final v = _pick(rnd, kLoadSumVolts);
        final sel = _pick(rnd, <double?>[null, 100, 300, 750, 1500]);
        t.run('$nRows줄 부등률$div 여유$mar% ${v}V 선정$sel', (c) {
          final r = computeLoadSum(
            LoadSumInput(
              rows: rows,
              diversity: '$div',
              margin: '$mar',
              volts: v,
              selectedKva: sel == null ? '' : '$sel',
            ),
          );
          c.eq('오류 없음', r.errors.isEmpty, true);
          final s = math.sqrt(sp * sp + sq * sq);
          final req = s / div * (1 + mar / 100);
          c.n('설비 kW', r.totalKw, total);
          c.n('최대수요 kW', r.demandKw, sp);
          c.n('kvar', r.demandKvar, sq, abs: 1e-9);
          c.n('kVA', r.demandKva, s);
          c.n('종합 역률', r.pf, sp / s);
          c.n('필요 kVA', r.requiredKva, req);
          c.n('2차 전류', r.ratedAmps, req * 1000 / (math.sqrt(3) * v));
          c.n('변압기 이용률', r.loadPct, sel == null ? null : req / sel * 100);
          c.n('변압기 이용률(여유 뺌)', r.loadPctNoMargin, sel == null ? null : s / div / sel * 100);
          c.eq('판정', r.pass, sel == null ? null : req / sel * 100 <= 100 + 1e-9);
        });
      }
      t.finish();
    });
  });

  // ───────────── 8. 단락 전류·I²t ─────────────
  group('단락 전류', () {
    test('독립 모델 자체 점검: 근거 문서 손계산 예 A·B·C', () {
      // (c) 독립 모델 실수를 먼저 가리기 위해, 독립 모델이 문서의 손계산 숫자를 내는지 본다.
      final a = refShortCircuit(kva: 1000, v: 380, zPct: 5.5, cMax: 1.05, pvc: true);
      expect(a.ikPct, closeTo(27624, 1));
      expect(a.kt, closeTo(0.96563, 1e-5));
      expect(a.zt * 1000, closeTo(7.942, 1e-3));
      expect(a.ikMax, closeTo(30038, 1));
      expect(a.kappa, closeTo(2.0, 1e-12));
      expect(a.ip, closeTo(84960, 2));
      const b240 = (size: 240.0, len: 50.0, n: 1);
      final b = refShortCircuit(kva: 1000, v: 380, zPct: 5.5, cMax: 1.05, pvc: false, segs: [b240]);
      expect(b.ikPct, closeTo(16511, 1));
      expect(b.ikMax, closeTo(17684, 1));
      // 최소(XLPE θe 250°C, R = 3.77 × 1.92 = 7.238 mΩ, Z = 14.418 mΩ): 3상 14,456 A, 2상 12,519 A.
      expect(b.ikMin3, closeTo(14456, 1));
      expect(b.ikMin2, closeTo(12519, 1));
      final cc = refShortCircuit(
        kva: 1000,
        v: 380,
        zPct: 5.5,
        pcu: 10,
        upMax: 500,
        cMax: 1.05,
        pvc: true,
        segs: [(size: 95, len: 30, n: 2), (size: 16, len: 20, n: 1)],
      );
      expect(cc.starts[0], closeTo(28884, 1));
      expect(cc.starts[1], closeTo(22490, 1));
      expect(cc.ikMax, closeTo(7801, 1));
      expect(cc.rx, closeTo(2.44, 0.005));
      expect(cc.kappa, closeTo(1.0207, 1e-4));
      expect(cc.ikPct, closeTo(7395, 1));
    });

    test('calcShortCircuit 무작위 2000조합', () {
      final t = Tally('단락 전류(calcShortCircuit)');
      var withMotorN = 0;
      var withSegN = 0;
      final rnd = math.Random(60909);
      const segChoices = <List<Seg>>[
        [],
        [(size: 95, len: 30, n: 1)],
        [(size: 240, len: 50, n: 1)],
        [(size: 95, len: 30, n: 2), (size: 16, len: 20, n: 1)],
        [(size: 300, len: 80, n: 3), (size: 50, len: 40, n: 1), (size: 4, len: 15, n: 1)],
        [(size: 2.5, len: 10, n: 1)],
        [(size: 150, len: 120, n: 2)],
      ];
      for (var k = 0; k < 2000; k++) {
        final kva = _pick(rnd, [100.0, 300.0, 500.0, 750.0, 1000.0, 1500.0, 2000.0]);
        final z = _pick(rnd, [4.0, 5.0, 5.5, 6.0, 7.0]);
        final v = _pick(rnd, [380.0, 440.0, 480.0]);
        final pcuPct = _pick(rnd, <double?>[null, 0.8, 1.2]);
        final pcu = pcuPct == null ? null : kva * pcuPct / 100;
        final upMax = _pick(rnd, <double?>[null, 100, 250, 500]);
        final upMin = upMax == null ? null : _pick(rnd, <double?>[null, upMax * 0.5, upMax * 0.8]);
        final withMotor = rnd.nextInt(3) == 0;
        final mKw = withMotor ? _pick(rnd, [30.0, 100.0, 200.0]) : null;
        final mEp = withMotor ? _pick(rnd, [0.7, 0.75, 0.8]) : null;
        final mMul = withMotor ? _pick(rnd, [3.5, 4.0, 5.0, 6.0]) : null;
        final cMax = _pick(rnd, [kScCMax6, kScCMax10]);
        final ins = _pick(rnd, Insulation.values);
        final segs = _pick(rnd, segChoices);
        t.run('${kva}kVA ${z}% ${v}V Pcu$pcu 계통$upMax/$upMin 전동기$mKw/$mEp/$mMul c$cMax ${ins.name} 구간${segs.length}', (c) {
          final a = calcShortCircuit(
            ScInput(
              kva: kva,
              volts: v,
              zPercent: z,
              pcuKw: pcu,
              upstreamMvaMax: upMax,
              upstreamMvaMin: upMin,
              motorKw: mKw,
              motorEffPf: mEp,
              motorMultiple: mMul,
              cMax: cMax,
              insulation: ins,
              segments: [
                for (final g in segs) ScSegment(sizeMm2: g.size, lengthM: g.len, parallel: g.n),
              ],
            ),
          );
          final r = refShortCircuit(
            kva: kva,
            v: v,
            zPct: z,
            pcu: pcu,
            upMax: upMax,
            upMin: upMin,
            motorKw: mKw,
            effPf: mEp,
            mult: mMul,
            cMax: cMax,
            pvc: ins == Insulation.pvc70,
            segs: segs,
          );
          c.eq('오류 없음', a.errors.isEmpty, true);
          if (mKw != null) withMotorN++;
          if (segs.isNotEmpty) withSegN++;
          c.n('KT', a.kT, r.kt);
          c.n('ZT', a.ztOhm, r.zt);
          c.n('RT', a.rtOhm, r.rt, abs: 1e-12);
          c.n('Ik″최대', a.ikMaxA, r.ikMax);
          c.n('계통분', a.ikNetA, r.ikNet);
          c.n('전동기분', a.ikMotorA, r.ikMotor, abs: 1e-6);
          c.n('전동기 정격', a.motorRatedA, r.motorRated, abs: 1e-6);
          c.n('%Z법', a.ikPercentZA, r.ikPct);
          c.n('R/X', a.rOverX, r.rx, abs: 1e-9);
          c.n('κ', a.kappa, r.kappa);
          c.n('ip', a.ipA, r.ip);
          c.n('최소 3상', a.ikMin3A, r.ikMin3);
          c.n('최소 2상', a.ikMin2A, r.ikMin2);
          c.eq('구간 시작점 수', a.startIkMaxA.length, r.starts.length);
          for (var i = 0; i < math.min(a.startIkMaxA.length, r.starts.length); i++) {
            c.n('시작점$i Ik', a.startIkMaxA[i], r.starts[i]);
          }
          for (var i = 0; i < math.min(a.startIpA.length, r.startIp.length); i++) {
            c.n('시작점$i ip', a.startIpA[i], r.startIp[i]);
          }
        });
      }
      print('    (전동기 포함 조합 $withMotorN개, 케이블 구간 있는 조합 $withSegN개)');
      t.finish();
    });

    test('케이블 열 견딤 I²t 격자', () {
      final t = Tally('케이블 단락 I²t');
      for (final s in refSizes) {
        for (final ins in Insulation.values) {
          for (final ik in [1000.0, 5000.0, 10000.0, 25000.0, 50000.0]) {
            for (final sec in [0.01, 0.1, 0.2, 0.5, 1.0, 3.0, 5.0]) {
              for (final n in [1, 2, 3]) {
                for (final lt in <double?>[null, 1e5, 5e6, 1e8]) {
                  t.run('${s}sq ${ins.name} ${ik}A ${sec}s 병렬$n 통과$lt', (c) {
                    final k = ins == Insulation.pvc70 ? 115.0 : 143.0; // 문서 k 표
                    final ikc = ik / n;
                    final smin = ikc * math.sqrt(sec) / k;
                    final allowed = n * n * k * k * s * s;
                    final a = cableWithstand(
                      sizeMm2: s,
                      insulation: ins,
                      ikA: ik,
                      tSec: sec,
                      parallel: n,
                      letThroughA2s: lt,
                    )!;
                    c.n('k', a.k, k);
                    c.n('Smin', a.sMinMm2, smin);
                    c.n('tmax', a.tMaxSec, math.pow(k * s / ikc, 2));
                    c.n('허용 I²t', a.allowedA2s, allowed);
                    c.eq('합격', a.ok, s >= smin - 1e-9);
                    c.eq('통과 에너지', a.letThroughOk, lt == null ? null : lt <= allowed);
                  });
                }
              }
            }
          }
        }
      }
      // 문서 예: 구리 PVC 95mm², 10kA → 1.1936초, XLPE 1.8456초, 허용 119,355,625 A²s.
      t.run('문서 예 95mm² 10kA', (c) {
        final p = cableWithstand(sizeMm2: 95, insulation: Insulation.pvc70, ikA: 10000, tSec: 1)!;
        final x = cableWithstand(sizeMm2: 95, insulation: Insulation.xlpe90, ikA: 10000, tSec: 1)!;
        c.n('PVC t', p.tMaxSec, 1.1936, rel: 1e-4);
        c.n('XLPE t', x.tMaxSec, 1.8456, rel: 1e-4);
        c.n('허용', p.allowedA2s, 119355625);
      });
      t.finish();
    });

    test('차단용량 판정', () {
      final t = Tally('차단용량 판정');
      for (final rating in [5.0, 10.0, 25.0, 35.0, 50.0, 65.0]) {
        for (final ik in [4.9, 5.0, 10.0, 24.99, 25.0, 25.01, 50.0, 70.0]) {
          t.run('${rating}kA vs ${ik}kA', (c) => c.eq('합격', breakingOk(rating, ik), rating >= ik));
        }
      }
      t.finish();
    });
  });

  // ───────────── 9. 발전기 ─────────────
  group('발전기 용량', () {
    test('문서 예: PG2 = 75 × 7.2 × 0.65 × 0.25 × 0.8 ÷ 0.2 = 351 kVA', () {
      final r = calcGenerator(
        const GenInput(
          loadKw: 300,
          demand: 1,
          eff: 0.85,
          pf: 0.8,
          motorKw: 75,
          beta: 7.2,
          startC: 0.65,
          xdPct: 25,
          dvPct: 20,
        ),
      );
      expect(r.pg2, closeTo(351, 0.01));
    });

    test('PG3 원문 식: 부하 역률로 나눈다', () {
      // 건축전기설비설계기준 제5장 3.1.2: PG3 = {(ΣPL − Pm) ÷ ηL + Pm × β × C × Pfm} × 1 ÷ cosθL
      // (300 − 75) ÷ 0.85 = 264.70588, 75 × 7.2 × 0.65 × 0.4 = 140.4, 합 405.10588 ÷ 0.8 = 506.382 kVA
      final r = calcGenerator(
        const GenInput(
          loadKw: 300,
          demand: 1,
          eff: 0.85,
          pf: 0.8,
          motorKw: 75,
          beta: 7.2,
          startC: 0.65,
          xdPct: 25,
          dvPct: 20,
          startPf: 0.4,
        ),
      );
      expect(r.pg3, closeTo(506.382, 0.01));
      expect(r.governing, 'PG3');
    });

    test('PG1~PG3 무작위 2000조합', () {
      final t = Tally('발전기 PG1~PG3');
      final rnd = math.Random(31);
      for (var k = 0; k < 2000; k++) {
        final load = _pick(rnd, [50.0, 120.0, 300.0, 750.0, 1500.0]);
        final dem = _pick(rnd, [0.6, 0.8, 1.0]);
        final eff = _pick(rnd, [0.8, 0.85, 0.9]);
        final pf = _pick(rnd, [0.8, 0.85, 0.9]);
        final hasMotor = rnd.nextInt(4) != 0;
        final pm = hasMotor ? load * _pick(rnd, [0.1, 0.3, 0.5]) : null;
        final beta = hasMotor ? _pick(rnd, GenStartClass.values).beta : null;
        final cS = hasMotor ? _pick(rnd, GenStartKind.values.where((e) => e.c != null).toList()).c : null;
        final xd = hasMotor ? _pick(rnd, [20.0, 25.0]) : null;
        final dv = hasMotor ? _pick(rnd, [15.0, 20.0, 25.0]) : null;
        final hasPg3 = hasMotor && rnd.nextBool();
        final sPf = hasPg3 ? _pick(rnd, [0.3, 0.4, 0.5]) : null;
        final v = _pick(rnd, <double?>[null, 380, 440, 6600]);
        final chosen = _pick(rnd, <double?>[null, 200, 500, 1250, 2500]);
        t.run('부하$load α$dem η$eff pf$pf Pm$pm β$beta C$cS Xd$xd ΔV$dv 기동pf$sPf ${v}V 선정$chosen', (c) {
          final a = calcGenerator(
            GenInput(
              loadKw: load,
              demand: dem,
              eff: eff,
              pf: pf,
              motorKw: pm,
              beta: beta,
              startC: cS,
              xdPct: xd,
              dvPct: dv,
              startPf: sPf,
              volts: v,
              chosenKva: chosen,
            ),
          );
          final pg1 = load * dem / (eff * pf);
          final pg2 = pm == null ? null : pm * beta! * cS! * (xd! / 100) * (1 - dv! / 100) / (dv / 100);
          // PG3는 원문대로 부하 종합 역률 pf로 나눈다.
          // 기동 역률을 비우면 원문 기본값 0.4(건축전기설비설계기준 3.1.2(5))로 계산한다.
          final pg3 = pm == null ? null : ((load - pm) / eff + pm * beta! * cS! * (sPf ?? 0.4)) / pf;
          final req = [pg1, ?pg2, ?pg3].reduce(math.max);
          c.eq('오류 없음', a.errors.isEmpty, true);
          c.n('PG1', a.pg1, pg1);
          c.n('PG2', a.pg2, pg2);
          c.n('PG3', a.pg3, pg3);
          c.n('필요', a.required, req);
          c.n('전류', a.currentA, v == null ? null : req * 1000 / (math.sqrt(3) * v));
          c.eq('선정 합격', a.chosenPass, chosen == null ? null : chosen >= req - 1e-9);
          c.n('선정 여유%', a.chosenMarginPct, chosen == null ? null : (chosen / req - 1) * 100, abs: 1e-6);
        });
      }
      t.finish();
    });
  });

  // ───────────── 10. 축전지 ─────────────
  group('축전지 용량', () {
    test('구간 방식 SBA·IEEE 무작위 2000조합', () {
      final t = Tally('축전지(SBA·IEEE)');
      final rnd = math.Random(485);
      for (var k = 0; k < 2000; k++) {
        final n = 1 + rnd.nextInt(6);
        final steps = <BatteryStep>[
          for (var i = 0; i < n; i++)
            BatteryStep(
              _pick(rnd, [5.0, 10.0, 20.0, 40.0, 80.0, 150.0, 300.0]),
              _pick(rnd, [0.5, 1.0, 5.0, 10.0, 29.0, 30.0, 59.0, 60.0, 90.0, 120.0, 180.0]),
            ),
        ];
        // 문서: 구간 s = Σp=1..s (Ap − Ap-1) × K(단계 p 시작부터 구간 s 끝까지의 시간).
        final times = <String, double>{};
        final sections = <double>[];
        for (var s = 0; s < n; s++) {
          var sum = 0.0;
          for (var p = 0; p <= s; p++) {
            var tm = 0.0;
            for (var q = p; q <= s; q++) {
              tm += steps[q].minutes;
            }
            times[refKey(tm)] = tm;
            final dA = steps[p].amps - (p == 0 ? 0 : steps[p - 1].amps);
            sum += dA * kOf(tm);
          }
          sections.add(sum);
        }
        final base = sections.reduce(math.max);
        final method = _pick(rnd, BatteryMethod.values);
        final l = _pick(rnd, [0.8, 0.7, 1.0]);
        final tf = _pick(rnd, [1.0, 1.04, 1.11, 1.19, 1.3]);
        final mar = _pick(rnd, [0.0, 10.0, 15.0, 25.0]);
        final aging = _pick(rnd, [1.25, 1.0]);
        final req = method == BatteryMethod.sba ? base / l : base * tf * (1 + mar / 100) * aging;
        final chosen = _pick(rnd, <double?>[null, 50, 200, 800]);
        final cells = _pick(rnd, <double?>[null, 55, 60, 62]);
        // SBA S 0601 4.3: Vd = (Va + Vc) ÷ n → 셀 수 × 셀당 최저 전압 − Vc ≥ Va면 합격.
        final vc = _pick(rnd, <double?>[null, 0, 1.5, 5]);
        t.run('${n}단계 ${method.name} L$l 온도$tf 여유$mar 노화$aging 선정$chosen 셀$cells 선로$vc', (c) {
          final a = calcBattery(
            BatteryInput(
              method: method,
              steps: steps,
              k: {for (final e in times.entries) e.key: kOf(e.value)},
              maintenance: l,
              tempFactor: tf,
              marginPct: mar,
              agingFactor: aging,
              chosenAh: chosen,
              busVolts: cells == null ? null : 125,
              cellNominal: cells == null ? null : 2.0,
              cellMin: cells == null ? null : 1.75,
              cells: cells,
              minBusVolts: cells == null ? null : 105,
              lineDropVolts: vc,
            ),
          );
          c.eq('오류 없음', a.errors.isEmpty, true);
          c.eq('필요 시간 수', battNeededTimes(steps).length, times.length);
          c.eq('구간 수', a.sections.length, n);
          for (var i = 0; i < math.min(n, a.sections.length); i++) {
            c.n('구간${i + 1}', a.sections[i].total, sections[i], abs: 1e-9);
          }
          c.n('최댓값', a.base, base);
          c.n('필요 Ah', a.required, req);
          final ties = sections.where((x) => (x - base).abs() <= 1e-9 * base.abs()).length;
          if (ties == 1) c.eq('최대 구간', a.maxSection, sections.indexOf(base) + 1);
          c.eq('선정 합격', a.chosenPass, chosen == null ? null : chosen >= req - 1e-9);
          c.n('여유%', a.chosenMarginPct, chosen == null ? null : (chosen / req - 1) * 100, abs: 1e-6);
          if (cells != null) {
            c.n('셀 수 계산', a.cellRatio, 125 / 2.0);
            final drop = vc ?? 0;
            c.n('종지 전압', a.endVolts, cells * 1.75);
            c.n('부하 쪽 전압', a.loadEndVolts, cells * 1.75 - drop);
            c.n('Vd', a.cellMinNeeded, (105 + drop) / cells);
            c.eq('종지 판정', a.endVoltsPass, 1.75 >= (105 + drop) / cells - 1e-9);
          }
        });
      }
      t.finish();
    });
  });

  // ───────────── 11. 접지 ─────────────
  group('접지', () {
    test('k 값·단열 식·접지도체·본딩·중성점·TT·접지봉', () {
      final t = Tally('접지');
      // 문서 표: 따로 포설 구리 PVC 143·XLPE 176, 알루미늄 PVC 95·XLPE 116 / 케이블 안·묶음 구리 115·143, 알루미늄 76·94.
      const kTab = {
        (true, gc.GroundMaterial.copper, gc.GroundInsulation.pvc): 143.0,
        (true, gc.GroundMaterial.copper, gc.GroundInsulation.xlpe): 176.0,
        (true, gc.GroundMaterial.aluminum, gc.GroundInsulation.pvc): 95.0,
        (true, gc.GroundMaterial.aluminum, gc.GroundInsulation.xlpe): 116.0,
        (false, gc.GroundMaterial.copper, gc.GroundInsulation.pvc): 115.0,
        (false, gc.GroundMaterial.copper, gc.GroundInsulation.xlpe): 143.0,
        (false, gc.GroundMaterial.aluminum, gc.GroundInsulation.pvc): 76.0,
        (false, gc.GroundMaterial.aluminum, gc.GroundInsulation.xlpe): 94.0,
      };
      for (final e in kTab.entries) {
        t.run('k ${e.key}', (c) => c.n('k', gc.groundK(e.key.$2, e.key.$3, separate: e.key.$1), e.value, rel: 0));
      }
      for (final i in [100.0, 1000.0, 5000.0, 12000.0, 30000.0]) {
        for (final sec in [0.05, 0.1, 0.4, 1.0, 5.0, 5.01, 0.0]) {
          for (final k in [76.0, 115.0, 143.0, 176.0]) {
            t.run('단열 ${i}A ${sec}s k$k', (c) {
              // 문서: S = √(I²t)/k, t ≤ 5초.
              final ref = sec <= 0 || sec > 5 ? null : math.sqrt(i * i * sec) / k;
              c.n('S', gc.adiabaticMinArea(fault: i, seconds: sec, k: k), ref);
            });
          }
        }
      }
      for (final (mat, hv, ref) in [('cu', false, 6.0), ('cu', true, 16.0), ('fe', false, 50.0), ('fe', true, 50.0), ('al', false, null), ('al', true, null)]) {
        t.run('접지도체 $mat ${hv ? '고압' : '저압'}', (c) {
          c.n('mm²', gc.groundingConductorMin(material: mat, highVoltage: hv).mm2, ref);
        });
      }
      for (final pe in [1.5, 4.0, 10.0, 12.0, 16.0, 35.0, 50.0, 60.0, 95.0, 150.0]) {
        // 문서: 가장 큰 보호도체의 1/2 이상, 6mm² 이상, 25mm² 넘길 필요 없음.
        t.run('본딩 PE$pe', (c) => c.n('mm²', gc.bondingConductorMinCopper(pe), math.min(25, math.max(6, pe / 2))));
      }
      for (final ig in [0.5, 1.0, 5.0, 10.0, 25.0, 100.0]) {
        for (final (trip, v) in [('normal', 150.0), ('within2s', 300.0), ('within1s', 600.0)]) {
          t.run('중성점 ${ig}A $trip', (c) => c.n('Ω', gc.neutralGroundMaxOhms(ig, trip: trip), v / ig));
        }
      }
      // KEC 211.2.6의 3: TT는 50 V 하나(직류 120 V 조건 없음, 원문 확인).
      for (final idn in [0.03, 0.1, 0.3, 0.5, 1.0]) {
        t.run('TT ${idn}A', (c) => c.n('Ω', gc.ttMaxOhms(idn), 50 / idn));
      }
      for (final rho in [30.0, 100.0, 300.0, 1000.0]) {
        for (final l in [1.0, 1.5, 2.4, 3.0, 6.0]) {
          for (final d in [10.0, 14.0, 16.0, 20.0]) {
            // 문서: R = ρ/(2πl)·(ln(4l/r) − 1), r = 반지름(m).
            final r1 = rho / (2 * math.pi * l) * (math.log(4 * l / (d / 2000)) - 1);
            t.run('봉 ρ$rho l$l d$d', (c) => c.n('Ω', gc.rodResistance(rho: rho, lengthM: l, diaMm: d), r1));
            for (final nn in [1, 2, 4, 8]) {
              for (final sp in [0.5, 1.0, 3.0, 10.0, 10.5, 20.0]) {
                // 문서: R_n = K·R₁/n, K = 1.2(간격 1~10m), 1.0(10m 초과), 1m 미만 불가.
                // 1본은 간격과 상관없이 R₁(10-07: 병렬 식이 아니라 간격 조건이 없다).
                final ref = nn == 1 ? r1 : (sp < 1 ? null : (sp > 10 ? 1.0 : 1.2) * r1 / nn);
                t.run('봉 병렬 ρ$rho l$l d$d ${nn}본 ${sp}m', (c) => c.n('Ω', gc.rodsParallel(r1, nn, spacingM: sp), ref));
              }
            }
          }
        }
      }
      t.finish();
    });
  });

  // ───────────── 12. 전동기 보호 ─────────────
  group('전동기 보호', () {
    test('열동 설정·NEC 430.32·EOCR·트립 클래스·NEC 430.52·전선 125%', () {
      final t = Tally('전동기 보호');
      for (final fla in [1.1, 3.4, 7.6, 21.8, 40.0, 96.0, 240.0]) {
        t.run('설정 ${fla}A', (c) {
          c.n('직입', mp.thrSetting(fla), fla);
          c.n('Y-Δ 델타 안', mp.thrSetting(fla, method: mp.StartMethod.starDelta), fla / math.sqrt(3));
          c.n('Y-Δ 라인', mp.thrSetting(fla, method: mp.StartMethod.starDelta, place: mp.RelayPlace.line), fla);
          c.n('직입(라인)', mp.thrSetting(fla, place: mp.RelayPlace.line), fla);
          c.n('430.32 SF1.15', mp.necOverloadMax(fla, sf115OrTemp40: true), fla * 1.25);
          c.n('430.32 그 밖', mp.necOverloadMax(fla, sf115OrTemp40: false), fla * 1.15);
          final (lo, hi) = mp.eocrRange(fla);
          c.n('EOCR 하한', lo, fla * 1.10);
          c.n('EOCR 상한', hi, fla * 1.25);
          c.n('전선 125%', mp.motorConductorMin(fla), fla * 1.25);
          for (final (type, pct) in [('이중소자(지연) 퓨즈', 175.0), ('반한시 차단기', 250.0), ('비지연 퓨즈', 300.0), ('순시트립 차단기', 800.0)]) {
            c.n('430.52 $type', mp.necShortCircuitMax(fla, type), fla * pct / 100);
          }
        });
      }
      // 문서: 7.2배에서 10A 2~10s, 10 4~10s, 20 6~20s, 30 9~30s.
      for (final (cls, lo, hi) in [('10A', 2.0, 10.0), ('10', 4.0, 10.0), ('20', 6.0, 20.0), ('30', 9.0, 30.0)]) {
        t.run('트립 클래스 $cls', (c) {
          final r = mp.kTripClass72[cls];
          c.n('하한', r?.$1, lo);
          c.n('상한', r?.$2, hi);
        });
      }
      t.run('트립 클래스 개수', (c) => c.eq('개수', mp.kTripClass72.length, 4));
      t.finish();
    });

    test('참고: NEC 430.250 전동기 전류(기억 값)', () {
      final t = Tally('NEC 430.250(기억 값, 참고)');
      for (final row in kNec430250) {
        final m = memNec430250[row.hpValue];
        t.run('${row.hp}hp', (c) {
          c.eq('줄 있음', m != null, true);
          if (m == null) return;
          if (m[0] != null) c.n('230V', row.a230, m[0], rel: 0);
          c.n('460V', row.a460, m[1], rel: 0);
        });
      }
      t.finish();
    });
  });

  // ───────────── 13. 케이블 트레이 ─────────────
  group('케이블 트레이', () {
    // 문서 표(옛 판단기준 제213조의2): 폭 150·300·450·600·750·900.
    const widths = [150.0, 300.0, 450.0, 600.0, 750.0, 900.0];
    const multiOpen = [4510.0, 9030.0, 13540.0, 18060.0, 22580.0, 27090.0];
    const multiSolid = [3540.0, 7090.0, 10640.0, 14190.0, 17740.0, 21290.0];
    const singleOpen = [4190.0, 8380.0, 12580.0, 16770.0, 20960.0, 25160.0];
    double tab(List<double> t, double w) {
      final i = widths.indexOf(w);
      // 문서: 표에 없는 폭은 표 값을 폭에 비례(계산기가 정한 것). 비율은 표마다 거의 일정해 0.5% 안.
      return i >= 0 ? t[i] : t.last / widths.last * w;
    }

    double a1(TrayCable c) => math.pi / 4 * c.od * c.od * c.count;
    double d1(TrayCable c) => c.od * c.count;

    /// 독립 판정: (사용률 %, 합격).
    double refOldMulti(TrayType type, double w, double depth, List<TrayCable> m, double k) {
      final solid = type == TrayType.solid;
      if (m.every((c) => c.control)) {
        final d = math.min(depth, 150);
        return m.fold(0.0, (s, c) => s + a1(c)) * k / (w * d * (solid ? 0.4 : 0.5)) * 100;
      }
      final big = m.where((c) => c.size >= 100).toList();
      final small = m.where((c) => c.size < 100).toList();
      if (small.isEmpty) return big.fold(0.0, (s, c) => s + d1(c)) * k / (solid ? 0.9 * w : w) * 100;
      final table = tab(solid ? multiSolid : multiOpen, w);
      final a = small.fold(0.0, (s, c) => s + a1(c));
      final sd = big.fold(0.0, (s, c) => s + d1(c));
      return (a + (solid ? 25.4 : 30.5) * sd) * k / table * 100;
    }

    double refOldSingle(double w, List<TrayCable> s, double k) {
      if (s.any((c) => c.size < 100)) return s.fold(0.0, (x, c) => x + d1(c)) * k / w * 100;
      final big = s.where((c) => c.size >= 500).toList();
      final mid = s.where((c) => c.size < 500).toList();
      if (mid.isEmpty) return big.fold(0.0, (x, c) => x + d1(c)) * k / w * 100;
      final a = mid.fold(0.0, (x, c) => x + a1(c));
      final sd = big.fold(0.0, (x, c) => x + d1(c));
      return (a + 28 * sd) * k / tab(singleOpen, w) * 100;
    }

    TrayCable randCable(math.Random rnd, {required bool multi, int? sizeClass}) {
      if (multi) {
        final ctrl = rnd.nextInt(4) == 0;
        final size = ctrl ? _pick(rnd, [1.5, 2.5]) : _pick(rnd, [2.5, 6.0, 16.0, 35.0, 70.0, 95.0, 120.0, 185.0, 240.0]);
        final od = ctrl ? _pick(rnd, [12.0, 15.5, 20.5]) : 10 + size * 0.18;
        return TrayCable(name: 'm', od: od, size: size, cores: ctrl ? 10 : 4, count: 1 + rnd.nextInt(6), control: ctrl);
      }
      final size = switch (sizeClass) {
        0 => _pick(rnd, [25.0, 50.0, 70.0, 95.0]),
        1 => _pick(rnd, [120.0, 185.0, 300.0, 400.0]),
        _ => _pick(rnd, [500.0, 630.0]),
      };
      return TrayCable(name: 's', od: 8 + size * 0.07, size: size, cores: 1, count: 1 + rnd.nextInt(9));
    }

    test('KEC 232.41: 외경 합 × (1 + 여유) ≤ 내측 폭', () {
      final t = Tally('트레이 KEC 판정');
      final rnd = math.Random(23241);
      for (var k = 0; k < 1500; k++) {
        final cs = [for (var i = 0; i < 1 + rnd.nextInt(6); i++) randCable(rnd, multi: rnd.nextBool(), sizeClass: rnd.nextInt(3))];
        final w = _pick(rnd, kTrayWidths);
        final depth = _pick(rnd, kTrayDepths);
        final type = _pick(rnd, TrayType.values);
        final m = _pick(rnd, [0.0, 0.1, 0.2, 0.3]);
        t.run('${cs.length}줄 폭$w ${type.name} 여유$m', (c) {
          final a = checkTray(type: type, width: w, depth: depth, cables: cs, margin: m)!;
          final used = cs.fold(0.0, (s, x) => s + d1(x)) * (1 + m);
          c.n('사용', a.used, used);
          c.n('한도', a.limit, w);
          c.eq('합격', a.ok, used <= w + 1e-9);
        });
      }
      t.finish();
    });

    test('옛 판단기준 제213조의2(참고 모드)', () {
      final t = Tally('트레이 옛 판단기준');
      final rnd = math.Random(2132);
      for (var k = 0; k < 2500; k++) {
        final w = _pick(rnd, kTrayWidths);
        final depth = _pick(rnd, kTrayDepths);
        final type = _pick(rnd, TrayType.values);
        final m = _pick(rnd, [0.0, 0.0, 0.2]);
        final kind = rnd.nextInt(3); // 0 다심만, 1 단심만, 2 함께
        if (kind == 2 && type == TrayType.solid) continue; // 바닥밀폐형 다심 90%와 단심 함께는 문서에 방법이 없어 뺌
        final cls = rnd.nextInt(3); // 단심은 한 등급만(문서: 등급이 섞인 경우 규칙은 등급별 표)
        final multi = kind == 1 ? <TrayCable>[] : [for (var i = 0; i < 1 + rnd.nextInt(5); i++) randCable(rnd, multi: true)];
        final single = kind == 0 ? <TrayCable>[] : [for (var i = 0; i < 1 + rnd.nextInt(3); i++) randCable(rnd, multi: false, sizeClass: cls == 2 && rnd.nextBool() ? 1 : cls)];
        final cs = [...multi, ...single];
        t.run('${multi.length}다심 ${single.length}단심 폭$w 깊이$depth ${type.name} 여유$m', (c) {
          final a = checkTray(type: type, width: w, depth: depth, cables: cs, margin: m, standard: TrayStandard.old213)!;
          final kk = 1 + m;
          double ref;
          final pm = multi.isEmpty ? null : refOldMulti(type, w, depth, multi, kk);
          final ps = single.isEmpty ? null : refOldSingle(w, single, kk);
          final mDia = multi.isNotEmpty && multi.any((x) => !x.control) && multi.every((x) => x.size >= 100);
          final sDia = single.isNotEmpty && (single.any((x) => x.size < 100) || single.every((x) => x.size >= 500));
          if (pm != null && ps != null && mDia && sDia) {
            // 문서: 둘 다 외경 합 규칙이면 외경을 합한다.
            ref = cs.fold(0.0, (s, x) => s + d1(x)) * kk / w * 100;
          } else {
            ref = math.max(pm ?? 0, ps ?? 0);
          }
          c.n('사용률%', a.pct, ref);
          if ((ref - 100).abs() > 0.6) c.eq('합격', a.ok, ref <= 100);
        });
      }
      t.finish();
    });

    test('트레이 다조 보정: 회로 수와 행', () {
      final t = Tally('트레이 다조 보정');
      final rnd = math.Random(5217);
      for (var k = 0; k < 1500; k++) {
        final cs = [for (var i = 0; i < 1 + rnd.nextInt(6); i++) randCable(rnd, multi: rnd.nextBool(), sizeClass: rnd.nextInt(3))];
        final type = _pick(rnd, TrayType.values);
        final oneRow = rnd.nextBool();
        t.run('${cs.length}줄 ${type.name} ${oneRow ? '한 줄' : '겹쳐'}', (c) {
          // 문서: 전력용 다심 1가닥 = 1회로, 전력용 단심 3가닥 = 1회로, 제어·신호는 뺀다.
          var mc = 0, sc = 0;
          for (final x in cs) {
            if (x.control) continue;
            if (x.cores > 1) {
              mc += x.count;
            } else {
              sc += x.count;
            }
          }
          final n = mc + (sc / 3).ceil();
          // 문서: 한 층이면 사다리·메시 5행, 펀칭 4행, 바닥밀폐 2행. 여러 줄로 쌓이면 1행.
          final layout = !oneRow
              ? GroupLayout.bunched
              : switch (type) {
                  TrayType.ladder || TrayType.mesh => GroupLayout.ladder,
                  TrayType.punched => GroupLayout.perforatedTray,
                  TrayType.solid => GroupLayout.wallSingleLayer,
                };
          c.eq('회로 수', trayCircuits(cs), n);
          c.n('k', trayGroupFactor(type, cs, oneRow: oneRow), n <= 1 ? 1.0 : refGroup(n, layout));
        });
      }
      t.finish();
    });
  });

  // ───────────── 14. 전선관 ─────────────
  group('전선관', () {
    // 근거 문서 "전선관 내경"의 숫자(외경/내경, 2종 가요관은 최소 내경만).
    const refConduits = <ConduitKind, Map<int, (double?, double)>>{
      ConduitKind.thick: {
        16: (21.0, 16.4), 22: (26.5, 21.9), 28: (33.3, 28.3), 36: (41.9, 36.9), 42: (47.8, 42.8),
        54: (59.6, 54.0), 70: (75.2, 69.6), 82: (87.9, 82.3), 92: (100.7, 93.7), 104: (113.4, 106.4),
      },
      ConduitKind.thin: {
        19: (19.1, 15.9), 25: (25.4, 22.2), 31: (31.8, 28.6), 39: (38.1, 34.9), 51: (50.8, 47.6),
        63: (63.5, 59.5), 75: (76.2, 72.2),
      },
      ConduitKind.pvc: {
        14: (18.0, 14.0), 16: (22.0, 18.0), 22: (26.0, 22.0), 28: (34.0, 28.0), 36: (42.0, 35.0),
        42: (48.0, 40.0), 54: (60.0, 51.0), 70: (76.0, 67.0), 82: (89.0, 77.2), 100: (114.0, 101.0),
      },
      ConduitKind.flex2: {
        10: (null, 9.2), 12: (null, 11.4), 15: (null, 14.1), 17: (null, 16.6), 24: (null, 23.8),
        30: (null, 29.3), 38: (null, 37.1), 50: (null, 49.1), 63: (null, 62.6), 76: (null, 76.0),
        83: (null, 81.0), 101: (null, 100.2),
      },
      ConduitKind.pf: {
        14: (21.5, 14.0), 16: (23.0, 16.0), 22: (30.5, 22.0), 28: (36.5, 28.0), 36: (45.5, 36.0),
        42: (52.0, 42.0),
      },
    };

    test('전선관 내경·외경 표(문서 값)와 전선 외경(문서에 숫자가 있는 칸)', () {
      final t = Tally('전선관·전선 외경 표(문서 값)');
      for (final k in ConduitKind.values) {
        final app = {for (final s in conduitSizes(k)) s.size: s};
        final ref = refConduits[k]!;
        t.run('${k.name} 호칭 목록', (c) => c.eq('호칭', app.keys.toList().join(','), ref.keys.toList().join(',')));
        for (final e in ref.entries) {
          t.run('${k.name} ${e.key}', (c) {
            final s = app[e.key];
            c.n('내경', s?.id, e.value.$2, rel: 0);
            if (e.value.$1 != null) c.n('외경', s?.od, e.value.$1, rel: 0);
          });
        }
      }
      // F-GV(문서 전체), HIV 1.5·2.5, HFIX 1.5·2.5·300, F-CV 4심 16·단심 10.
      final fgv = <double, double>{1.5: 6.5, 2.5: 7.0, 4.0: 8.0, 6.0: 8.5, 10.0: 9.5, 16.0: 10.0, 25.0: 12.0, 35.0: 13.0, 50.0: 14.5, 70.0: 16.0, 95.0: 18.5, 120.0: 20.0, 150.0: 22.0, 185.0: 25.0, 240.0: 28.0, 300.0: 30.0};
      for (final e in fgv.entries) {
        t.run('F-GV ${e.key}', (c) => c.n('외경', cableOd(CableKind.fgv, e.key), e.value, rel: 0));
      }
      for (final (k, s, od) in [
        (CableKind.hiv, 1.5, 3.2),
        (CableKind.hiv, 2.5, 3.9),
        (CableKind.hiv, 4.0, null),
        (CableKind.hfix, 1.5, 3.4),
        (CableKind.hfix, 2.5, 4.1),
        (CableKind.hfix, 300.0, 30.6),
        (CableKind.fcv4, 16.0, 22.0),
        (CableKind.fcv1, 10.0, 9.4),
      ]) {
        t.run('${k.name} $s', (c) => c.n('외경', cableOd(k, s), od, rel: 0));
      }
      t.finish();
    });

    test('점유율·한도·최소 전선관 무작위 3000조합', () {
      final t = Tally('전선관 점유율');
      final rnd = math.Random(2225);
      final kinds = CableKind.values;
      for (var k = 0; k < 3000; k++) {
        final rows = <ConduitWire>[];
        final nRows = 1 + rnd.nextInt(3);
        final sameMode = rnd.nextInt(3) == 0;
        for (var i = 0; i < nRows; i++) {
          final kind = sameMode && rows.isNotEmpty ? rows.first.kind : _pick(rnd, kinds);
          final sizes = cableSizes(kind);
          final size = sameMode && rows.isNotEmpty ? rows.first.size : _pick(rnd, sizes);
          rows.add(ConduitWire(kind, size, _pick(rnd, [1, 1, 2, 3, 4, 6])));
        }
        final rule = _pick(rnd, FillRule.values);
        final easy = rnd.nextBool();
        final ck = _pick(rnd, ConduitKind.values);
        t.run('${rows.map((w) => '${w.kind.name}${w.size}×${w.count}').join('+')} ${rule.name} 쉬운인출$easy ${ck.name}', (c) {
          bool isWire(CableKind x) => x == CableKind.hfix || x == CableKind.iv || x == CableKind.hiv || x == CableKind.fgv; // 문서: 절연전선 HFIX·IV·HIV·F-GV
          final total = rows.fold<int>(0, (s, w) => s + w.count);
          final allWire = rows.every((w) => isWire(w.kind));
          final noWire = rows.every((w) => !isWire(w.kind));
          final same = rows.every((w) => w.kind == rows.first.kind && w.size == rows.first.size);
          double limit;
          if (rule == FillRule.nec) {
            limit = total <= 1 ? 53 : (total == 2 ? 31 : 40); // 문서: 1본 53, 2본 31, 2본 초과 40
          } else if (total == 1 && noWire) {
            limit = 100 / (1.5 * 1.5); // 문서: 케이블 1본 내경 ≥ 외경 × 1.5
          } else if (allWire && same && easy) {
            limit = 48;
          } else if (noWire) {
            limit = 100 / 3; // 문서: 케이블 2본 이상 1/3
          } else {
            limit = 32; // 문서: 절연전선 32%, 케이블과 절연전선 함께 32%
          }
          final sumD2 = rows.fold(0.0, (s, w) => s + math.pow(cableOd(w.kind, w.size)!, 2) * w.count);
          c.n('한도%', fillLimit(rule, rows, easyPull: easy).pct, limit);
          int? minSize;
          for (final e in refConduits[ck]!.entries) {
            if (sumD2 / (e.value.$2 * e.value.$2) * 100 <= limit + 1e-9) {
              minSize = e.key;
              break;
            }
          }
          for (final e in refConduits[ck]!.entries) {
            c.n('점유율 ${e.key}', fillPercent(rows, e.value.$2), sumD2 / (e.value.$2 * e.value.$2) * 100);
          }
          c.eq('최소 전선관', minConduit(ck, rows, rule, easyPull: easy)?.size, minSize);
          c.eq('48% 스위치', easyPullApplies(rows), allWire && same);
          // 문서: 케이블만 딱 2본이면 참고 내경 = (d1 + d2) × 1.5.
          final ds = [for (final w in rows) for (var i = 0; i < w.count; i++) cableOd(w.kind, w.size)!];
          c.n('2본 참고 내경', cablePairSumId(rows), noWire && total == 2 ? 1.5 * (ds[0] + ds[1]) : null);
        });
      }
      t.finish();
    });
  });

  // ───────────── 15. 기초 계산 ─────────────
  group('기초 계산', () {
    test('옴의 법칙·교류 전력·Y-Δ·전력량·도체 저항·주파수', () {
      final t = Tally('기초 계산');
      const vals = [0.5, 2.0, 12.0, 220.0];
      for (final v in [null, ...vals]) {
        for (final i in [null, ...vals]) {
          for (final r in [null, ...vals]) {
            for (final p in [null, ...vals]) {
              final given = [v, i, r, p].where((x) => x != null).length;
              t.run('V$v I$i R$r P$p', (c) {
                final a = bc.ohmLaw(v: v, i: i, r: r, p: p);
                if (given < 2) {
                  c.eq('없음', a, null);
                  return;
                }
                // 문서: V·I·R·P 순서로 앞의 두 값만 쓴다.
                final names = ['V', 'I', 'R', 'P'];
                final xs = [v, i, r, p];
                final idx = [for (var k = 0; k < 4; k++) if (xs[k] != null) k].take(2).toList();
                final pair = '${names[idx[0]]}${names[idx[1]]}';
                late double vv, ii, rr;
                switch (pair) {
                  case 'VI':
                    vv = v!;
                    ii = i!;
                    rr = vv / ii;
                  case 'VR':
                    vv = v!;
                    rr = r!;
                    ii = vv / rr;
                  case 'VP':
                    vv = v!;
                    ii = p! / vv;
                    rr = vv / ii;
                  case 'IR':
                    ii = i!;
                    rr = r!;
                    vv = ii * rr;
                  case 'IP':
                    ii = i!;
                    vv = p! / ii;
                    rr = vv / ii;
                  default:
                    rr = r!;
                    ii = math.sqrt(p! / rr);
                    vv = ii * rr;
                }
                c.n('V', a?.v, vv);
                c.n('I', a?.i, ii);
                c.n('R', a?.r, rr);
                c.n('P', a?.p, vv * ii);
              });
            }
          }
        }
      }
      for (final three in [false, true]) {
        for (final volts in [220.0, 380.0, 440.0]) {
          for (final amps in [1.0, 21.8, 150.0]) {
            for (final pf in [0.6, 0.85, 1.0]) {
              t.run('교류 ${three ? '삼상' : '단상'} ${volts}V ${amps}A pf$pf', (c) {
                final k = three ? math.sqrt(3) : 1.0;
                final s = k * volts * amps / 1000;
                final a = bc.acPowerFromCurrent(volts: volts, amps: amps, pf: pf, three: three);
                c.n('kVA', a.kva, s);
                c.n('kW', a.kw, s * pf);
                c.n('kvar', a.kvar, math.sqrt(math.max(0, s * s - s * pf * s * pf)), abs: 1e-9);
                final b = bc.acPowerFromKw(kw: s * pf, pf: pf, volts: volts, three: three);
                c.n('역산 A', b.amps, amps);
                c.n('역산 kVA', b.kva, s);
              });
            }
          }
        }
      }
      for (final star in [false, true]) {
        for (final fromLine in [false, true]) {
          t.run('${star ? 'Y' : 'Δ'} ${fromLine ? '선' : '상'} 기준', (c) {
            final a = bc.starDelta(star: star, fromLine: fromLine, volts: 380, amps: 10);
            final r3 = math.sqrt(3);
            // 문서: Y는 V선 = √3·V상, I선 = I상. Δ는 V선 = V상, I선 = √3·I상.
            final lv = fromLine ? 380.0 : (star ? 380 * r3 : 380.0);
            final pv = fromLine ? (star ? 380 / r3 : 380.0) : 380.0;
            final li = fromLine ? 10.0 : (star ? 10.0 : 10 * r3);
            final pi = fromLine ? (star ? 10.0 : 10 / r3) : 10.0;
            c.n('V선', a.lineV, lv);
            c.n('V상', a.phaseV, pv);
            c.n('I선', a.lineI, li);
            c.n('I상', a.phaseI, pi);
          });
        }
      }
      t.run('전력량', (c) => c.n('kWh', bc.energyKwh(7.5, 8, 30), 7.5 * 8 * 30));
      for (final metal in bc.ConductorMetal.values) {
        for (final area in [1.5, 16.0, 240.0]) {
          for (final len in [1.0, 100.0, 1000.0]) {
            for (final th in [-10.0, 20.0, 70.0, 90.0]) {
              t.run('도체 ${metal.name} ${area}mm² ${len}m ${th}°C', (c) {
                // 문서: ρ20 구리 0.017241·알루미늄 0.028264, α 구리 0.00393·알루미늄 0.00403.
                final cu = metal == bc.ConductorMetal.copper;
                final rho = cu ? 0.017241 : 0.028264;
                final al = cu ? 0.00393 : 0.00403;
                c.n('Ω', bc.conductorResistance(metal: metal, areaMm2: area, lengthM: len, tempC: th), rho * len / area * (1 + al * (th - 20)));
              });
            }
          }
        }
      }
      t.run('직렬·병렬', (c) {
        c.n('직렬', bc.seriesResistance([1, 2, 3.5]), 6.5);
        c.n('병렬', bc.parallelResistance([2, 3, 6]), 1);
      });
      for (final f in [50.0, 60.0]) {
        for (final p in [2, 4, 6, 8]) {
          t.run('주파수 ${f}Hz $p극', (c) {
            final ns = 120 * f / p;
            c.n('T', bc.periodSec(f), 1 / f);
            c.n('ω', bc.angularFreq(f), 2 * math.pi * f);
            c.n('ns', bc.syncSpeedRpm(f, p), ns);
            c.n('슬립', bc.slip(ns, ns * 0.965), 0.035, abs: 1e-12);
            c.n('발전기 f', bc.generatorHz(p, ns), f);
            c.n('XL', bc.inductiveReactance(f, 0.01), 2 * math.pi * f * 0.01);
            c.n('XC', bc.capacitiveReactance(f, 100e-6), 1 / (2 * math.pi * f * 100e-6));
            c.n('f0', bc.resonanceHz(0.01, 100e-6), 1 / (2 * math.pi * math.sqrt(0.01 * 100e-6)));
          });
        }
      }
      t.finish();
    });
  });
}
