// 케이블 트레이 점유율·폭 선정(10-03). 화면 없이 계산만 한다(전부 시험으로 확인).
//
// 기본(현행): KEC 232.41 케이블트레이공사. 트레이 종류·다심·단심·수평·수직을 가리지 않고
// "케이블 외경 합 ≤ 트레이 내측 폭, 한 층"(232.41.1 6~9호). 점유면적 표·비율 규정은 없다.
// 정부 공고문(산업부 2022-809·2023-563, 기후에너지환경부 2025-198) 신구조문과 cq4l 조문으로 확인.
//
// 참고(옛 기준): 전기설비기술기준의 판단기준 제213조의2. 표 값은 판단기준 해설 자료(jungi.net)·
// eom 조문·KRCCS 시방서가 같고, 미국 NEC 392.22를 mm로 바꾼 값과 같다. 해설 자료의 계산 예
// 7개를 시험(cable_tray_test.dart)으로 확인한다. 케이블 단면적은 완성품 외경으로 π/4 × 외경².
// 근거와 출처 목록은 docs/전기_케이블트레이_근거.md.
library;

import 'dart:math' as math;

import 'cable_weights.dart';
import 'conduit_tables.dart';
import 'elec_tables.dart' show GroupLayout, groupFactor;

/// 트레이 종류. 옛 기준에서 펀칭형·메시형은 통풍이 되는 쪽(사다리형 표)을 쓴다.
enum TrayType { ladder, punched, mesh, solid }

/// 판정 기준.
enum TrayStandard { kec, old213 }

String trayStandardLabel(TrayStandard s) => switch (s) {
  TrayStandard.kec => 'KEC 232.41 (현행)',
  TrayStandard.old213 => '구 판단기준 (참고)',
};

String trayTypeLabel(TrayType t) => switch (t) {
  TrayType.ladder => '사다리형',
  TrayType.punched => '펀칭형',
  TrayType.mesh => '메시형',
  TrayType.solid => '바닥밀폐형',
};

/// 바닥이 막혀 있어 열이 덜 빠지는 쪽(더 작은 표)인지.
bool isSolidTray(TrayType t) => t == TrayType.solid;

/// 표에 있는 폭(mm). 그 밖의 폭은 폭에 비례로 계산한다(표 값 ÷ 폭이 일정하다).
const List<double> kTrayTableWidths = [150, 300, 450, 600, 750, 900];

/// 고를 수 있는 폭(mm): KS C 8464 표(사다리형 200~1000, 펀칭·바닥밀폐형 150~600)와
/// 제조사 카탈로그(150·450·750 등)를 합친 것.
const List<double> kTrayWidths = [150, 200, 300, 400, 450, 500, 600, 700, 750, 800, 900, 1000];

/// 내측 깊이(측판 높이, mm): KS C 8464 높이 60·75·100·150.
const List<double> kTrayDepths = [60, 75, 100, 150];

// 표 1: 다심, 사다리형·통풍형, 100mm² 미만만 → 최대허용 점유면적(mm²).
const List<double> _multiOpen = [4510, 9030, 13540, 18060, 22580, 27090];
// 표 3: 다심, 바닥밀폐형.
const List<double> _multiSolid = [3540, 7090, 10640, 14190, 17740, 21290];
// 표 5: 단심, 사다리형·통풍형, 100~500mm².
const List<double> _singleOpen = [4190, 8380, 12580, 16770, 20960, 25160];

/// 섞여 있을 때 빼는 계수(mm²/mm): 표 − 계수 × (굵은 케이블 외경 합).
const double kMultiOpenSd = 30.5;
const double kMultiSolidSd = 25.4;
const double kSingleOpenSd = 28.0;

/// 다심 케이블을 "굵은 것"으로 보는 단면적(mm², 이상).
const double kMultiBig = 100;

/// 단심 케이블: 이 이상은 외경 합으로, [kSingleMid] 이상 이 미만은 면적 표로,
/// [kSingleSmall]~[kSingleMid]는 외경 합·한 층. 50mm² 미만은 옛 기준에 규정이 없다.
const double kSingleBig = 500;
const double kSingleMid = 100;
const double kSingleSmall = 50;

/// 제어·신호 다심만 있을 때 트레이 내 단면적에 대한 한도(깊이 150mm 이하).
const double kControlOpenPct = 50;
const double kControlSolidPct = 40;
const double kControlDepthMax = 150;

double _table(List<double> t, double width) {
  final i = kTrayTableWidths.indexOf(width);
  if (i >= 0) return t[i];
  // 표 사이 폭은 비례(표의 폭당 값은 거의 일정하다). 가장 넓은 칸의 비율을 쓴다.
  return t.last / kTrayTableWidths.last * width;
}

/// 트레이에 넣는 케이블 한 줄(같은 것 [count]가닥).
class TrayCable {
  final String name;

  /// 완성품 외경(mm).
  final double od;

  /// 도체 단면적(mm², 1심 기준). 다심·단심 규칙의 굵기 기준.
  final double size;

  /// 심 수(1이면 단심).
  final int cores;
  final int count;

  /// 제어·신호용인지(전력용이 아니면 true).
  final bool control;

  /// 한 가닥 무게(kg/km, 개산). 모르면 null(하중 계산에서 빠진다고 알린다).
  final double? weight;

  /// 차폐(동 테이프·편조·알루미늄 마일라)가 있는지. 굽힘 반경 배수가 달라진다.
  final bool shielded;

  const TrayCable({
    required this.name,
    required this.od,
    required this.size,
    required this.cores,
    required this.count,
    this.control = false,
    this.weight,
    bool? shielded,
  }) : shielded = shielded ?? control;

  bool get isMulti => cores > 1;

  /// 한 가닥 단면적(mm², 외경 기준).
  double get area1 => math.pi / 4 * od * od;
  double get area => area1 * count;
  double get diaSum => od * count;

  /// 앱 외경 표에서 만든다. 표에 없으면 null.
  static TrayCable? fromKind(CableKind k, double size, int count) {
    final od = cableOd(k, size);
    if (od == null) return null;
    final cores = switch (k) {
      CableKind.fcv2 => 2,
      CableKind.fcv3 => 3,
      CableKind.fcv4 => 4,
      _ => cvvsCores(k) ?? 1,
    };
    final sz = size == size.roundToDouble() ? size.toInt().toString() : size.toString();
    return TrayCable(
      name: '${cableKindLabel(k)} ${sz}sq',
      od: od,
      size: size,
      cores: cores,
      count: count,
      control: cvvsCores(k) != null,
      weight: cableWeight(k, size),
      shielded: cvvsCores(k) != null, // F-CVV-S만 차폐
    );
  }
}

/// 어떤 규칙으로 봤는지.
enum TrayRule {
  kecDia, // KEC: 모든 케이블 외경 합 ≤ 내측 폭, 한 층
  multiBigDia, // 옛 기준 다심 100 이상만: 외경 합 ≤ 폭(바닥밀폐 90%), 한 층
  multiSmallArea, // 옛 기준 다심 100 미만만: 단면적 합 ≤ 표
  multiMixed, // 옛 기준 다심 섞임: 작은 것 단면적 합 ≤ 표 − 계수 × 굵은 것 외경 합
  controlPct, // 옛 기준 제어·신호 다심만: 단면적 합 ≤ 내 단면적 × 50%(40%)
  singleBigDia, // 옛 기준 단심 500 이상만: 외경 합 ≤ 폭
  singleMidArea, // 옛 기준 단심 100~500만: 단면적 합 ≤ 표 5
  singleMixed, // 옛 기준 단심 500 이상과 100~500 섞임
  singleLayerDia, // 옛 기준 단심 50~100이 있을 때(또는 외경 합 규칙끼리 함께): 외경 합 ≤ 폭, 한 층
}

String trayRuleLabel(TrayRule r) => switch (r) {
  TrayRule.kecDia => 'KEC 232.41: 케이블 외경 합 ≤ 트레이 내측 폭, 한 층',
  TrayRule.multiBigDia => '다심 100mm² 이상: 외경 합 ≤ 트레이 폭(바닥밀폐 90%), 한 층',
  TrayRule.multiSmallArea => '다심 100mm² 미만: 단면적 합 ≤ 표의 최대 점유면적',
  TrayRule.multiMixed => '다심 섞임: 작은 케이블 단면적 합 ≤ 표 − 계수 × 굵은 케이블 외경 합',
  TrayRule.controlPct => '제어·신호 다심만: 단면적 합 ≤ 트레이 내 단면적의 일정 %',
  TrayRule.singleBigDia => '단심 500mm² 이상: 외경 합 ≤ 트레이 폭',
  TrayRule.singleMidArea => '단심 100~500mm²: 단면적 합 ≤ 표의 최대 점유면적',
  TrayRule.singleMixed => '단심 섞임: 100~500mm² 단면적 합 ≤ 표 − 계수 × 500mm² 이상 외경 합',
  TrayRule.singleLayerDia => '모두 한 층: 외경 합 ≤ 트레이 폭',
};

/// 한 트레이 판정 결과.
class TrayCheck {
  final TrayRule rule;

  /// 쓴 양과 한도. 단위는 [byDia]면 mm(외경 합), 아니면 mm²(단면적).
  final double used;
  final double limit;
  final bool byDia;

  /// 한 층으로 깔아야 하는지(외경 합 규칙).
  final bool singleLayer;

  /// 계산식 한 줄(근거로 보여 준다).
  final String formula;
  final List<String> notes;

  const TrayCheck({
    required this.rule,
    required this.used,
    required this.limit,
    required this.byDia,
    required this.singleLayer,
    required this.formula,
    this.notes = const [],
  });

  bool get ok => used <= limit + 1e-9;

  /// 한도에 대한 사용률(%).
  double get pct => limit <= 0 ? double.infinity : used / limit * 100;

  TrayCheck withNotes(List<String> more) => TrayCheck(
    rule: rule,
    used: used,
    limit: limit,
    byDia: byDia,
    singleLayer: singleLayer,
    formula: formula,
    notes: [...notes, ...more],
  );
}

/// 숫자 글: 100 이상은 반올림해 천 단위 쉼표(9,030), 그 아래는 소수 한 자리(뒤 0은 뗌).
String trayNum(double v) {
  if (v.abs() >= 100) {
    final t = v.round().abs().toString();
    final b = StringBuffer(v < 0 ? '-' : '');
    for (var i = 0; i < t.length; i++) {
      if (i > 0 && (t.length - i) % 3 == 0) b.write(',');
      b.write(t[i]);
    }
    return b.toString();
  }
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

String _n(double v) => trayNum(v);

/// KEC 232.41.1 이격 안내(판정에는 넣지 않는다).
const List<String> kKecSpacingNotes = [
  '트레이와 벽면은 20mm 이상, 트레이끼리 위아래 간격은 300mm 이상 띄웁니다. 더 좁으면 허용전류 저감계수를 적용합니다(232.41.1 6·7호).',
  '수직 트레이는 벽면과 가장 굵은 케이블 외경의 0.3배 이상 띄웁니다(8·9호).',
  '단심을 삼각(트레포일)으로 묶어 포설하면 묶음 사이를 단심 외경의 2배 이상 띄웁니다(7·9호).',
];

/// 트레이 하나를 판정한다. [margin]은 예비 여유(0.2 = 20%)로, 쓴 양에 (1 + margin)을 곱한다.
/// 케이블이 없으면 null.
TrayCheck? checkTray({
  required TrayType type,
  required double width,
  required double depth,
  required List<TrayCable> cables,
  double margin = 0,
  TrayStandard standard = TrayStandard.kec,
}) {
  final list = [for (final c in cables) if (c.count > 0) c];
  if (list.isEmpty) return null;
  final k = 1 + margin;
  final common = <String>[];
  if (margin > 0) common.add('예비 여유 ${(margin * 100).round()}%를 더해 판정했습니다.');
  final maxOd = list.map((c) => c.od).reduce(math.max);
  if (maxOd > depth) {
    common.add('가장 굵은 케이블(외경 ${_n(maxOd)}mm)이 측판 높이 ${_n(depth)}mm보다 높습니다. 깊은 트레이를 검토하십시오.');
  }
  if (standard == TrayStandard.kec) {
    final sd = list.fold(0.0, (a, c) => a + c.diaSum);
    return TrayCheck(
      rule: TrayRule.kecDia,
      used: sd * k,
      limit: width,
      byDia: true,
      singleLayer: true,
      formula: '외경 합 ${_n(sd)}mm${margin > 0 ? ' × ${k.toStringAsFixed(2)}' : ''} ≤ 내측 폭 ${_n(width)}mm',
      notes: [...common, '한 층으로 나란히 포설해야 합니다(겹쳐 쌓지 않음). 트레이 종류·다심·단심·수평·수직 모두 같은 규칙입니다.'],
    );
  }
  if (!kTrayTableWidths.contains(width)) {
    common.add('${_n(width)}mm는 구 기준 표에 없는 폭이라 표 값을 폭에 비례해 계산했습니다.');
  }
  final multi = [for (final c in list) if (c.isMulti) c];
  final single = [for (final c in list) if (!c.isMulti) c];
  final m = multi.isEmpty ? null : _oldMulti(type, width, depth, multi, k);
  final s = single.isEmpty ? null : _oldSingle(type, width, single, k);
  if (m != null && s != null) {
    // 판단기준 8호: 다심 규정과 단심 규정을 각각 만족해야 한다. 둘 다 외경 합 규칙이면 같은
    // 바닥을 나눠 쓰므로 외경을 합한다(해설 자료의 함께 넣는 예와 같은 방법).
    if (m.byDia && s.byDia && m.limit == width && s.limit == width) {
      final sd = list.fold(0.0, (a, c) => a + c.diaSum);
      return TrayCheck(
        rule: TrayRule.singleLayerDia,
        used: sd * k,
        limit: width,
        byDia: true,
        singleLayer: true,
        formula: '다심·단심 모두 외경 합 ${_n(sd)}mm${margin > 0 ? ' × ${k.toStringAsFixed(2)}' : ''} ≤ 폭 ${_n(width)}mm',
        notes: [...common, '한 층으로 나란히 포설해야 합니다(겹쳐 쌓지 않음).'],
      );
    }
    final worse = m.pct >= s.pct ? m : s;
    final other = identical(worse, m) ? s : m;
    return worse.withNotes([
      ...common,
      '다심과 단심을 함께 넣으면 다심 규정과 단심 규정을 각각 만족해야 합니다(판단기준 8호). 더 엄격한 쪽을 표시했고, 다른 쪽은 ${_n(other.pct)}%(${trayRuleLabel(other.rule)})입니다.',
    ]);
  }
  return (m ?? s)!.withNotes(common);
}

TrayCheck _dia(TrayRule rule, List<TrayCable> cs, String what, double limit, double k, {String limitText = '폭'}) {
  final sd = cs.fold(0.0, (a, c) => a + c.diaSum);
  return TrayCheck(
    rule: rule,
    used: sd * k,
    limit: limit,
    byDia: true,
    singleLayer: true,
    formula: '$what 외경 합 ${_n(sd)}mm${k > 1 ? ' × ${k.toStringAsFixed(2)}' : ''} ≤ $limitText ${_n(limit)}mm',
    notes: const ['한 층으로 나란히 포설해야 합니다(겹쳐 쌓지 않음).'],
  );
}

String _x(double k) => k > 1 ? ' × ${k.toStringAsFixed(2)}' : '';

/// 옛 판단기준 다심 규정.
TrayCheck _oldMulti(TrayType type, double width, double depth, List<TrayCable> multi, double k) {
  final solid = isSolidTray(type);
  // 제어·신호 다심만: 트레이 내 단면적의 50%(바닥밀폐 40%). 깊이는 150mm까지만 센다.
  if (multi.every((c) => c.control)) {
    final pct = solid ? kControlSolidPct : kControlOpenPct;
    final d = math.min(depth, kControlDepthMax);
    final a = multi.fold(0.0, (s, c) => s + c.area);
    return TrayCheck(
      rule: TrayRule.controlPct,
      used: a * k,
      limit: width * d * pct / 100,
      byDia: false,
      singleLayer: false,
      formula: '단면적 합 ${_n(a)}mm²${_x(k)} ≤ 내 단면적 ${_n(width)}×${_n(d)}mm²의 ${pct.round()}%',
      notes: [if (depth > kControlDepthMax) '깊이가 150mm를 초과해 150mm로 계산했습니다.'],
    );
  }
  final big = [for (final c in multi) if (c.size >= kMultiBig) c];
  final small = [for (final c in multi) if (c.size < kMultiBig) c];
  if (small.isEmpty) {
    return solid
        ? _dia(TrayRule.multiBigDia, big, '다심 100mm² 이상', width * 0.9, k, limitText: '폭의 90%')
        : _dia(TrayRule.multiBigDia, big, '다심 100mm² 이상', width, k);
  }
  final table = _table(solid ? _multiSolid : _multiOpen, width);
  final a = small.fold(0.0, (s, c) => s + c.area);
  if (big.isEmpty) {
    return TrayCheck(
      rule: TrayRule.multiSmallArea,
      used: a * k,
      limit: table,
      byDia: false,
      singleLayer: false,
      formula: '단면적 합 ${_n(a)}mm²${_x(k)} ≤ ${trayTypeLabel(type)} ${_n(width)}mm 표 ${_n(table)}mm²',
    );
  }
  final coef = solid ? kMultiSolidSd : kMultiOpenSd;
  final sd = big.fold(0.0, (s, c) => s + c.diaSum);
  return TrayCheck(
    rule: TrayRule.multiMixed,
    used: (a + coef * sd) * k,
    limit: table,
    byDia: false,
    singleLayer: false,
    formula: '100mm² 미만 단면적 합 ${_n(a)}mm² + ${coef.toStringAsFixed(1)} × 100mm² 이상 외경 합 ${_n(sd)}mm${k > 1 ? ' (${_x(k).trim()})' : ''} ≤ 표 ${_n(table)}mm²',
    notes: const ['100mm² 이상 케이블은 한 층으로 포설하고 그 위에 다른 케이블을 얹지 않습니다.'],
  );
}

/// 옛 판단기준 단심 규정.
TrayCheck _oldSingle(TrayType type, double width, List<TrayCable> single, double k) {
  if (single.any((c) => c.size < kSingleMid)) {
    final r = _dia(TrayRule.singleLayerDia, single, '단심 모두', width, k);
    return single.any((c) => c.size < kSingleSmall)
        ? r.withNotes(['50mm² 미만 단심은 구 기준에 규정이 없어 같은 방법(외경 합, 한 층)으로 판정했습니다.'])
        : r;
  }
  final big = [for (final c in single) if (c.size >= kSingleBig) c];
  final mid = [for (final c in single) if (c.size < kSingleBig) c];
  if (mid.isEmpty) return _dia(TrayRule.singleBigDia, big, '단심 500mm² 이상', width, k);
  final notes = [if (isSolidTray(type)) '단심 표는 사다리형·통풍형 기준입니다. 바닥밀폐형도 같은 표로 계산했습니다.'];
  final table = _table(_singleOpen, width);
  final a = mid.fold(0.0, (s, c) => s + c.area);
  if (big.isEmpty) {
    return TrayCheck(
      rule: TrayRule.singleMidArea,
      used: a * k,
      limit: table,
      byDia: false,
      singleLayer: false,
      formula: '단면적 합 ${_n(a)}mm²${_x(k)} ≤ ${_n(width)}mm 표 ${_n(table)}mm²',
      notes: notes,
    );
  }
  final sd = big.fold(0.0, (s, c) => s + c.diaSum);
  return TrayCheck(
    rule: TrayRule.singleMixed,
    used: (a + kSingleOpenSd * sd) * k,
    limit: table,
    byDia: false,
    singleLayer: false,
    formula: '100~500mm² 단면적 합 ${_n(a)}mm² + 28 × 500mm² 이상 외경 합 ${_n(sd)}mm${k > 1 ? ' (${_x(k).trim()})' : ''} ≤ 표 ${_n(table)}mm²',
    notes: [...notes, '500mm² 이상 케이블은 한 층으로 포설합니다.'],
  );
}

// ── 허용전류 보정(트레이에 모아 깔 때) ──

/// 트레이에 깐 모양에 맞는 IEC 60364-5-52 B.52.17 줄. 한 줄로 나란히([oneRow])가 아니면 겹쳐 쌓음(1행).
GroupLayout trayGroupLayout(TrayType t, {required bool oneRow}) {
  if (!oneRow) return GroupLayout.bunched;
  return switch (t) {
    TrayType.ladder || TrayType.mesh => GroupLayout.ladder,
    TrayType.punched => GroupLayout.perforatedTray,
    TrayType.solid => GroupLayout.wallSingleLayer,
  };
}

/// 보정에 세는 회로 수: 전력용 다심 케이블은 한 가닥이 한 회로, 전력용 단심은 3가닥이 한 회로(3상).
/// 제어·신호 케이블은 전류가 작아 세지 않는다.
int trayCircuits(List<TrayCable> cables) {
  var multi = 0, single = 0;
  for (final c in cables) {
    if (c.control) continue;
    if (c.isMulti) {
      multi += c.count;
    } else {
      single += c.count;
    }
  }
  return multi + (single / 3).ceil();
}

/// 회로 수 보정계수(표 B.52.17). 회로가 없으면 1.
double trayGroupFactor(TrayType t, List<TrayCable> cables, {required bool oneRow}) {
  final n = trayCircuits(cables);
  if (n <= 1) return 1;
  return groupFactor(n, trayGroupLayout(t, oneRow: oneRow));
}

// ── 하중 ──

/// 설치 방법. 바닥에 직접 놓으면 바닥이 계속 받쳐 지지 간격·허용 하중 판정이 필요 없다.
enum TrayMount { hanging, stand, floor }

String trayMountLabel(TrayMount m) => switch (m) {
  TrayMount.hanging => '매달기·브래킷',
  TrayMount.stand => '받침대 위',
  TrayMount.floor => '바닥에 직접',
};

/// 지지점 사이가 떠 있는지(지지 간격·허용 하중을 따지는지).
bool trayMountSpans(TrayMount m) => m != TrayMount.floor;

/// 고를 수 있는 지지 간격(m). 시방서: 2m 이하(변전실 1.5m), LH 찬넬 3m.
const List<double> kTraySpans = [1.5, 2, 3];

/// KEC 232.41.2 1호: 케이블트레이의 안전율은 1.5 이상.
const double kTraySafety = 1.5;

/// 하중 계산 결과(kg/m는 트레이 1m당).
class TrayLoad {
  final double cableKgM; // 케이블 무게(예비 여유 포함)
  final double trayKgM; // 트레이 자중
  final double span; // 지지 간격(m)
  final double? allowKgM; // 제조사 허용(사용) 하중(이 지지 간격에서, 케이블만 — 트레이 자중 제외)
  final List<String> missing; // 무게를 몰라 빠진 케이블

  const TrayLoad({
    required this.cableKgM,
    required this.trayKgM,
    required this.span,
    required this.allowKgM,
    required this.missing,
  });

  double get totalKgM => cableKgM + trayKgM;

  /// 지지점 하나가 받는 하중(kg) ≈ 1m당 하중 × 지지 간격(이어진 트레이 가운데 지지점).
  double get perSupportKg => totalKgM * span;

  /// 카탈로그 허용 하중(NEMA VE-1 working load·IEC 61537 SWL)은 케이블 하중 기준이라 케이블 하중과 견준다.
  bool? get ok => allowKgM == null ? null : cableKgM <= allowKgM! + 1e-9;
  double? get pct => allowKgM == null || allowKgM! <= 0 ? null : cableKgM / allowKgM! * 100;
}

/// 케이블 무게 합(kg/m)에 예비 여유를 더하고 트레이 자중을 더해 허용 하중과 견준다.
TrayLoad trayLoad({
  required List<TrayCable> cables,
  double trayKgM = 0,
  required double span,
  double? allowKgM,
  double margin = 0,
}) {
  var kg = 0.0;
  final missing = <String>[];
  for (final c in cables) {
    if (c.count <= 0) continue;
    final w = c.weight;
    if (w == null) {
      missing.add(c.name);
      continue;
    }
    kg += w / 1000 * c.count;
  }
  return TrayLoad(
    cableKgM: kg * (1 + margin),
    trayKgM: trayKgM,
    span: span,
    allowKgM: allowKgM,
    missing: missing,
  );
}

// ── 곡률(굽힘) 반경 ──

/// 굽힘 반경 기준.
enum BendRule { domestic, maker }

String bendRuleLabel(BendRule r) => switch (r) {
  BendRule.domestic => '국내 시방서',
  BendRule.maker => '제조사 (넥상스)',
};

/// 트레이 엘보(곡관) 반경(mm): LH 시방서 "300 이상", 에이인텍·B-Line 300·600·900.
const List<double> kTrayElbowRadii = [300, 600, 900];

/// 케이블 외경에 곱하는 최소 굽힘 반경 배수와 그 근거.
/// - 국내 시방서(서울시 SMCS·KRCCS·나라장터·LH 시방서, 600V 표): 다심 6D, 단심 8D. 차폐 케이블은
///   국내 규정이 없어 제조사 값(넥상스 TFR-CVV-S·TFR-CVV-AMS 12D)을 쓴다.
/// - 제조사(넥상스코리아 제품 자료): TFR-CV·TFR-CVV-S·TFR-CVV-AMS 12D.
(double, String) bendFactor(TrayCable c, BendRule rule) {
  if (rule == BendRule.maker) return (12, '제조사 12D');
  if (c.shielded) return (12, '차폐: 국내 규정 없음 → 제조사 12D');
  return c.isMulti ? (6, '다심 6D') : (8, '단심 8D');
}

/// 케이블 한 줄의 최소 굽힘 반경(mm).
double bendRadius(TrayCable c, BendRule rule) => c.od * bendFactor(c, rule).$1;

/// 목록에서 가장 큰 최소 굽힘 반경과 그 케이블.
(double, TrayCable)? maxBend(List<TrayCable> cables, BendRule rule) {
  (double, TrayCable)? best;
  for (final c in cables) {
    if (c.count <= 0) continue;
    final r = bendRadius(c, rule);
    if (best == null || r > best.$1) best = (r, c);
  }
  return best;
}

/// 엘보 반경 목록에서 [need] 이상인 가장 작은 것(없으면 null).
double? elbowFor(double need, {List<double> radii = kTrayElbowRadii}) {
  for (final r in [...radii]..sort()) {
    if (r >= need - 1e-9) return r;
  }
  return null;
}

/// 지지 간격 안내(국내 시방서). 판정에는 넣지 않는다.
String? spanWarning(TrayMount m, double span) {
  if (!trayMountSpans(m)) return null;
  if (span > 2) {
    return '국내 시방서 대부분은 지지 간격 2m 이하입니다(서울시 SMCS·KRCCS·나라장터). LH 시방서는 찬넬 3m도 둡니다. 시방서를 확인하십시오.';
  }
  return null;
}

/// 폭마다 판정한 결과와 처음 합격하는 폭.
class TraySizing {
  final List<(double width, TrayCheck check)> rows;
  final double? minWidth;
  const TraySizing(this.rows, this.minWidth);
}

/// [widths]를 작은 것부터 대 보고, 처음 합격하는 폭을 권장 폭으로 낸다(없으면 null).
TraySizing? sizeTray({
  required TrayType type,
  required double depth,
  required List<TrayCable> cables,
  double margin = 0,
  List<double> widths = kTrayWidths,
  TrayStandard standard = TrayStandard.kec,
}) {
  final rows = <(double, TrayCheck)>[];
  double? best;
  for (final w in [...widths]..sort()) {
    final c = checkTray(type: type, width: w, depth: depth, cables: cables, margin: margin, standard: standard);
    if (c == null) return null;
    rows.add((w, c));
    if (best == null && c.ok) best = w;
  }
  return TraySizing(rows, best);
}
