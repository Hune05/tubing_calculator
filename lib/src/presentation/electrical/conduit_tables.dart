// 전선관 굵기(점유율) 표와 계산. 값은 docs/전기계산기_근거.md "전선관 굵기"의 출처에서 옮겼고,
// 칸마다 두 출처 이상이 같은 값만 넣었다(2026-09-26 조사).
//
// 점유율 = 전선 단면적 합(π/4 × 외경² × 가닥 수) ÷ 관 내 단면적(π/4 × 내경²).
//
// 전선관 내경:
//  · 후강(KS C 8401 = JIS C 8305 G): 외경·두께 Panasonic 카탈로그(16~82)·준우스틸(전체),
//    내경 宮地電機·y-326·보영전기(KS C 8401)·Denzai.Site·hayamihyou가 같은 값. 내선규정 표
//    "후강전선관의 내 단면적의 32% 및 48%"(eom.co.kr 표7·경기남도회·전선관 굵기선정 설계 자료 표1.10)와도 맞다.
//  · 박강(KS C 8401 = JIS C 8305 C): Panasonic·준우스틸·宮地電機, 32%·48% 표(eom 표8)와 맞다.
//  · 경질 비닐(KS C 8431 = JIS C 8430 VE): 유한 HI-VE(KS C 8431 표)·宮地電機·kcn·未来工業.
//    82는 KS 표(89 − 2 × 5.9 = 77.2)와 설계 자료 32% 값(1497mm²)이 맞는 77.2. 100은 내경 출처가 101(KS 표)과
//    100(kcn)으로 달라 넣지 않았다.
//  · 2종 금속제 가요(KS C 8422 표3 최소 내경): eom KS C 8422 표·宮地電機(12~76)·설계 자료 표1.12(32% 값).
//  · 합성수지제 가요(PF·CD, JIS C 8411): hayamihyou 내경, 설계 자료 표1.16(32%·48% 값).
// 케이블 외경: LS전선 배전 케이블 카탈로그(2017), 대한전선 MV/LV 카탈로그(2025-12), 넥상스(극동) TFR-CV 자료,
//  KBI 코스모링크 HFIX, 상진전선 CVV-SB, 금화전선·Ganghong 60227 IEC 01 표. 출처끼리 다르면 큰 값(안전 쪽).
library;

import 'dart:math' as math;

// ─────────────── 전선관 ───────────────

enum ConduitKind { thick, thin, pvc, flex2, pf }

String conduitKindLabel(ConduitKind k) => switch (k) {
  ConduitKind.thick => '후강',
  ConduitKind.thin => '박강',
  ConduitKind.pvc => '경질 비닐',
  ConduitKind.flex2 => '2종 가요관',
  ConduitKind.pf => 'PF·CD',
};

/// 전선관 한 규격: 호칭, 외경, 내경(mm).
class ConduitSpec {
  final int size;
  final double od;
  final double id;
  const ConduitSpec(this.size, this.od, this.id);
}

const String conduitKindGuide =
    '후강: 강제 전선관 두꺼운 것(KS C 8401). 호칭은 대략 내경(mm)입니다.\n'
    '박강: 강제 전선관 얇은 것(KS C 8401). 호칭은 대략 외경(mm)입니다.\n'
    '경질 비닐: 경질 비닐 전선관(KS C 8431, VE).\n'
    '2종 가요관: 2종 금속제 가요전선관(KS C 8422). 내경은 규격 최소 내경입니다.\n'
    'PF·CD: 합성수지제 가요관(JIS C 8411). 호칭이 내경입니다.';

const Map<ConduitKind, List<ConduitSpec>> _conduits = {
  // 외경 − 2 × 두께: 16 2.3, 22 2.3, 28~42 2.5, 54~82 2.8, 92·104 3.5mm.
  ConduitKind.thick: [
    ConduitSpec(16, 21.0, 16.4),
    ConduitSpec(22, 26.5, 21.9),
    ConduitSpec(28, 33.3, 28.3),
    ConduitSpec(36, 41.9, 36.9),
    ConduitSpec(42, 47.8, 42.8),
    ConduitSpec(54, 59.6, 54.0),
    ConduitSpec(70, 75.2, 69.6),
    ConduitSpec(82, 87.9, 82.3),
    ConduitSpec(92, 100.7, 93.7),
    ConduitSpec(104, 113.4, 106.4),
  ],
  // 두께 19~51 1.6, 63·75 2.0mm.
  ConduitKind.thin: [
    ConduitSpec(19, 19.1, 15.9),
    ConduitSpec(25, 25.4, 22.2),
    ConduitSpec(31, 31.8, 28.6),
    ConduitSpec(39, 38.1, 34.9),
    ConduitSpec(51, 50.8, 47.6),
    ConduitSpec(63, 63.5, 59.5),
    ConduitSpec(75, 76.2, 72.2),
  ],
  ConduitKind.pvc: [
    ConduitSpec(14, 18, 14),
    ConduitSpec(16, 22, 18),
    ConduitSpec(22, 26, 22),
    ConduitSpec(28, 34, 28),
    ConduitSpec(36, 42, 35),
    ConduitSpec(42, 48, 40),
    ConduitSpec(54, 60, 51),
    ConduitSpec(70, 76, 67),
    ConduitSpec(82, 89, 77.2),
  ],
  ConduitKind.flex2: [
    ConduitSpec(10, 13.3, 9.2),
    ConduitSpec(12, 16.1, 11.4),
    ConduitSpec(15, 19.0, 14.1),
    ConduitSpec(17, 21.5, 16.6),
    ConduitSpec(24, 28.8, 23.8),
    ConduitSpec(30, 34.9, 29.3),
    ConduitSpec(38, 42.9, 37.1),
    ConduitSpec(50, 54.9, 49.1),
    ConduitSpec(63, 69.1, 62.6),
    ConduitSpec(76, 82.9, 76.0),
    ConduitSpec(83, 88.1, 81.0),
    ConduitSpec(101, 107.3, 100.2),
  ],
  // 외경은 PF 값(CD는 더 가늘다).
  ConduitKind.pf: [
    ConduitSpec(14, 21.5, 14),
    ConduitSpec(16, 23.0, 16),
    ConduitSpec(22, 30.5, 22),
    ConduitSpec(28, 36.5, 28),
    ConduitSpec(36, 45.5, 36),
    ConduitSpec(42, 52.0, 42),
  ],
};

List<ConduitSpec> conduitSizes(ConduitKind k) => _conduits[k]!;

String conduitSource(ConduitKind k) => switch (k) {
  ConduitKind.thick =>
    '후강 내경: KS C 8401(= JIS C 8305 G) 외경 − 2 × 두께. Panasonic·준우스틸·宮地電機·보영전기 표가 같고, '
        '내선규정 표 "후강전선관의 내 단면적의 32% 및 48%"와 맞습니다.',
  ConduitKind.thin =>
    '박강 내경: KS C 8401(= JIS C 8305 C) 외경 − 2 × 두께. Panasonic·준우스틸·宮地電機 표가 같고, '
        '내선규정 표 "박강전선관의 내 단면적의 32% 및 48%"와 맞습니다.',
  ConduitKind.pvc =>
    '경질 비닐 내경: KS C 8431(유한 HI-VE 표)·JIS C 8430 VE(宮地電機·未来工業·kcn). 호칭 100은 출처끼리 '
        '내경이 달라 넣지 않았습니다.',
  ConduitKind.flex2 =>
    '2종 가요관 내경: KS C 8422 표3 최소 내경(eom.co.kr KS 표). 宮地電機 표·설계 자료 32% 값과 맞습니다.',
  ConduitKind.pf =>
    'PF·CD 내경: JIS C 8411(hayamihyou 표). 설계 자료 32%·48% 값과 맞습니다.',
};

/// 관 내 단면적(mm²).
double conduitArea(double id) => math.pi / 4 * id * id;

// ─────────────── 전선·케이블 외경 ───────────────

enum CableKind {
  hfix,
  iv,
  fcv1,
  fcv2,
  fcv3,
  fcv4,
  cvvs2,
  cvvs3,
  cvvs4,
  cvvs5,
  cvvs6,
  cvvs7,
  cvvs8,
  cvvs10,
  cvvs12,
  cvvs15,
  cvvs20,
  cvvs30,
}

/// F-CVV-S(제어용 차폐 케이블) 심 수.
int? cvvsCores(CableKind k) => switch (k) {
  CableKind.cvvs2 => 2,
  CableKind.cvvs3 => 3,
  CableKind.cvvs4 => 4,
  CableKind.cvvs5 => 5,
  CableKind.cvvs6 => 6,
  CableKind.cvvs7 => 7,
  CableKind.cvvs8 => 8,
  CableKind.cvvs10 => 10,
  CableKind.cvvs12 => 12,
  CableKind.cvvs15 => 15,
  CableKind.cvvs20 => 20,
  CableKind.cvvs30 => 30,
  _ => null,
};

String cableKindLabel(CableKind k) => switch (k) {
  CableKind.hfix => 'HFIX 450/750V',
  CableKind.iv => 'IV 450/750V',
  CableKind.fcv1 => 'F-CV 단심',
  CableKind.fcv2 => 'F-CV 2심',
  CableKind.fcv3 => 'F-CV 3심',
  CableKind.fcv4 => 'F-CV 4심',
  _ => 'F-CVV-S ${cvvsCores(k)}심',
};

/// 절연전선(케이블이 아닌 전선)인지.
bool isInsulatedWire(CableKind k) => k == CableKind.hfix || k == CableKind.iv;

// dart format off
// F-CVV-S 외경 [1.5, 2.5, 4, 6, 10mm²] (LS 카탈로그 42쪽 = 상진전선 CVV-SB 33쪽, 모든 칸 같음).
// null은 표에 없는 굵기.
const Map<CableKind, List<double?>> _cvvs = {
  CableKind.cvvs2: [12.0, 13.0, 14.5, 16.0, 17.5],
  CableKind.cvvs3: [12.5, 13.5, 15.5, 17.0, 18.5],
  CableKind.cvvs4: [13.5, 14.5, 16.5, 18.0, 20.5],
  CableKind.cvvs5: [14.5, 15.5, 18.0, 19.5, 22.5],
  CableKind.cvvs6: [15.5, 16.5, 19.5, 21.5, 24.5],
  CableKind.cvvs7: [15.5, 16.5, 19.5, 21.5, 24.5],
  CableKind.cvvs8: [16.5, 17.5, 21.5, 23.5, 26.5],
  CableKind.cvvs10: [18.5, 20.5, 24.5, 26.5, 30.5],
  CableKind.cvvs12: [18.5, 20.5, 25.5, 27.5, 31.5],
  CableKind.cvvs15: [20.5, 22.5, 27.5, 29.5, null],
  CableKind.cvvs20: [22.0, 25.0, 30.0, 33.0, null],
  CableKind.cvvs30: [26.0, 29.0, 36.0, null, null],
};
const List<double> _cvvsSizes = [1.5, 2.5, 4, 6, 10];

/// 외경(mm) 표. 열 순서는 [_sizes].
const List<double> _sizes = [
  1.5, 2.5, 4, 6, 10, 16, 25, 35, 50, 70, 95, 120, 150, 185, 240, 300,
];
const Map<CableKind, List<double?>> _od = {
  // KS C 3341 연선 외경 상한(LS·대한전선·KBI 카탈로그가 같은 값). 카탈로그에 "약" 값이 없어 상한을 쓴다.
  CableKind.hfix: [
    3.4, 4.1, 4.7, 5.4, 7.0, 8.0, 10.1, 11.3, 13.2, 15.1, 17.6, 19.4, 21.6,
    24.1, 27.5, 30.6,
  ],
  // 60227 IEC 01 연선 외경 상한(금화전선 "완성외경 Max."·Ganghong "upper limit"가 같은 값, IEC 60227-3 표 1).
  CableKind.iv: [
    3.3, 4.0, 4.6, 5.2, 6.7, 7.8, 9.7, 10.9, 12.8, 14.6, 17.1, 18.8, 20.9,
    23.3, 26.6, null,
  ],
  // 0.6/1kV F-CV 완성품 외경(약): LS·대한전선·넥상스 중 큰 값.
  CableKind.fcv1: [
    6.5, 7.0, 7.5, 8.0, 9.4, 10.0, 12.0, 13.0, 14.5, 16.0, 18.5, 20.0, 22.0,
    24.0, 27.0, 30.0,
  ],
  CableKind.fcv2: [
    11.5, 12.0, 13.0, 14.5, 17.0, 18.5, 22.0, 24.0, 27.0, 31.0, 35.0, 38.0,
    43.0, 47.0, 53.0, 58.0,
  ],
  CableKind.fcv3: [
    12.0, 12.5, 14.0, 15.0, 18.0, 19.5, 23.0, 25.0, 29.0, 33.0, 37.0, 41.0,
    46.0, 50.0, 57.0, 62.0,
  ],
  CableKind.fcv4: [
    12.5, 13.5, 15.0, 16.0, 20.0, 22.0, 26.0, 28.0, 32.0, 36.0, 42.0, 46.0,
    51.0, 56.0, 63.0, 70.0,
  ],
};
// dart format on

List<double> cableSizes(CableKind k) {
  final cv = _cvvs[k];
  if (cv != null) {
    return [
      for (var i = 0; i < _cvvsSizes.length; i++)
        if (cv[i] != null) _cvvsSizes[i],
    ];
  }
  final row = _od[k]!;
  return [
    for (var i = 0; i < _sizes.length; i++)
      if (row[i] != null) _sizes[i],
  ];
}

double? cableOd(CableKind k, double size) {
  final cv = _cvvs[k];
  if (cv != null) {
    final i = _cvvsSizes.indexOf(size);
    return i < 0 ? null : cv[i];
  }
  final i = _sizes.indexOf(size);
  return i < 0 ? null : _od[k]![i];
}

const String cableOdSource =
    '외경: F-CV는 LS전선·대한전선·넥상스 카탈로그 중 큰 값, HFIX는 KS C 3341 상한(LS·대한전선·KBI), '
    'IV는 60227 IEC 01 상한(금화전선·Ganghong), F-CVV-S는 LS전선·상진전선 카탈로그.';

// ─────────────── 점유율 ───────────────

class ConduitWire {
  final CableKind kind;
  final double size;
  final int count;
  const ConduitWire(this.kind, this.size, this.count);
}

/// 전선 단면적 합(mm², 외경 기준).
double wiresArea(List<ConduitWire> wires) {
  var a = 0.0;
  for (final w in wires) {
    final d = cableOd(w.kind, w.size) ?? 0;
    a += math.pi / 4 * d * d * w.count;
  }
  return a;
}

/// 점유율(%).
double fillPercent(List<ConduitWire> wires, double id) =>
    wiresArea(wires) / conduitArea(id) * 100;

enum FillRule { naesun, nec }

String fillRuleLabel(FillRule r) => switch (r) {
  FillRule.naesun => '내선규정',
  FillRule.nec => 'NEC',
};

const String fillRuleGuide =
    '내선규정: 굵기가 다른 전선을 넣거나 일반 배관이면 32% 이하입니다. 같은 굵기 절연전선만 넣고 굴곡이 적어 '
    '쉽게 인출할 수 있으면 48%까지 됩니다(구 내선규정 2225-5). 케이블 1본은 관 내경이 케이블 외경의 1.5배 이상입니다'
    '(내선규정 2275-1). 현행 내선규정은 1/3(33%) 이하를 권장합니다. 32%는 이보다 조금 엄격합니다.\n'
    'NEC: 미국 NEC 9장 표 1. 전선·케이블 1본 53%, 2본 31%, 3본 이상 40%. 다심 케이블 1본은 전선 1본으로 봅니다.';

/// 점유율 한도. [easyPull]은 내선규정 48% 조건(굴곡이 적어 쉽게 인출)을 켰는지.
class FillLimit {
  final double pct;
  final String reason;
  final List<String> notes;
  const FillLimit(this.pct, this.reason, [this.notes = const []]);
}

/// 케이블 1본: 관 내경 ≥ 외경 × 1.5 → 점유율 1/1.5² = 44.4%에 해당.
const double kCableIdFactor = 1.5;

FillLimit fillLimit(
  FillRule rule,
  List<ConduitWire> wires, {
  bool easyPull = false,
}) {
  final total = wires.fold<int>(0, (s, w) => s + w.count);
  final allWire = wires.every((w) => isInsulatedWire(w.kind));
  final sameSize =
      wires.isNotEmpty &&
      wires.every(
        (w) => w.kind == wires.first.kind && w.size == wires.first.size,
      );
  if (rule == FillRule.nec) {
    final pct = total <= 1 ? 53.0 : (total == 2 ? 31.0 : 40.0);
    return FillLimit(
      pct,
      'NEC 9장 표 1: 전선·케이블 $total본 → ${pct.toStringAsFixed(0)}% 이하',
    );
  }
  if (total == 1 && !allWire) {
    return const FillLimit(
      100 / (kCableIdFactor * kCableIdFactor),
      '케이블 1본: 관 내경이 케이블 외경의 1.5배 이상(내선규정 2275-1, 점유율 44.4%에 해당)',
    );
  }
  if (allWire && sameSize && easyPull) {
    return const FillLimit(
      48,
      '같은 굵기 절연전선, 굴곡이 적어 쉽게 인출: 48% 이하(구 내선규정 2225-5)',
    );
  }
  final notes = <String>[
    if (!allWire) '케이블 여러 본을 한 관에 넣는 규칙은 두 출처로 확인하지 못해 절연전선 기준 32%로 계산했습니다.',
    if (allWire && sameSize && !easyPull)
      '같은 굵기 절연전선이고 굴곡이 적어 쉽게 인출할 수 있으면 48%까지 됩니다(아래 스위치).',
  ];
  return FillLimit(
    32,
    sameSize && allWire
        ? '절연전선 32% 이하(구 내선규정 2225-5)'
        : '굵기가 다른 전선: 32% 이하(구 내선규정 2225-5)',
    notes,
  );
}

/// 48% 스위치를 쓸 수 있는지(같은 종류·같은 굵기 절연전선만).
bool easyPullApplies(List<ConduitWire> wires) =>
    wires.isNotEmpty &&
    wires.every(
      (w) =>
          isInsulatedWire(w.kind) &&
          w.kind == wires.first.kind &&
          w.size == wires.first.size,
    );

List<String> fillRuleBasis(FillRule r) => switch (r) {
  FillRule.naesun => const [
    '구 내선규정 2225-5(2016): 굵기가 다른 절연전선은 피복을 포함한 단면적 합이 관 내 단면적의 32% 이하, '
        '관의 굴곡이 적어 쉽게 인출할 수 있으면 같은 굵기 절연전선은 48% 이하(eom.co.kr 금속관공사, 대한전기협회 질의회신).',
    '케이블: 내선규정 2275-1 전선관 내경이 케이블 외경의 1.5배 이상(대한전기협회 질의회신, 전선관 굵기선정 설계 자료).',
    '현행 내선규정은 1/3 이하를 권장합니다(KS C IEC/TS 61200-52 521.6 인용, 다산에듀·한솔 답변). KEC에는 전선관 점유율 규정이 없습니다.',
    '구 내선규정은 가는 전선(단선 1.6·2.0mm 등)에 보정계수를 곱했습니다. IEC 굵기로 맞춘 값을 두 출처로 확인하지 못해 넣지 않았습니다.',
    '직각 굴곡은 3개소를 넘지 않게 하고, 관 길이가 30m를 넘으면 풀박스를 두는 것이 바람직합니다(내선규정 금속관공사).',
  ],
  FillRule.nec => const [
    'NEC Chapter 9 Table 1: 전선 1본 53%, 2본 31%, 2본 초과 40%. 주 9: 다심 케이블 1본은 전선 1본으로 봅니다.',
    '외경은 국산 케이블 카탈로그 값입니다. NEC 9장 표 5(THHN 등 미국 전선 외경)는 쓰지 않았습니다.',
  ],
};

/// 점유율 한도 이내인 가장 가는 전선관. 없으면 null.
ConduitSpec? minConduit(
  ConduitKind k,
  List<ConduitWire> wires,
  FillRule rule, {
  bool easyPull = false,
}) {
  final limit = fillLimit(rule, wires, easyPull: easyPull).pct;
  for (final c in conduitSizes(k)) {
    if (fillPercent(wires, c.id) <= limit + 1e-9) return c;
  }
  return null;
}
