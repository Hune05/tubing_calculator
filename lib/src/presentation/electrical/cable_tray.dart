// 케이블 트레이 점유율·폭 선정(10-03). 화면 없이 계산만 한다(전부 시험으로 확인).
//
// 근거: KEC 232.41 케이블트레이공사(옛 전기설비기술기준의 판단기준 제213조의2). 표 값은
// 판단기준 해설 자료(jungi.net "다심케이블을 동일케이블트레이에 시설하는 경우 규격선정")에서
// 옮겼고, 미국 NEC 392.22를 mm로 바꾼 값과 같다(예: 사다리형 다심 150mm 폭 4,510mm² ≈ 7in²).
// 같은 자료의 계산 예 7개를 시험(cable_tray_test.dart)으로 그대로 확인한다.
//
// 케이블 단면적은 완성품 외경으로 잰다: π/4 × 외경².
library;

import 'dart:math' as math;

import 'conduit_tables.dart';

/// 트레이 종류. 펀칭형·메시형은 통풍이 되는 쪽(사다리형 표)을 쓴다.
enum TrayType { ladder, punched, mesh, solid }

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

/// 고를 수 있는 표준 폭(mm).
const List<double> kTrayWidths = [100, 150, 200, 300, 400, 450, 500, 600, 750, 900, 1000];

/// 표준 내측 깊이(측판 높이, mm).
const List<double> kTrayDepths = [75, 100, 150];

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

/// 단심 케이블: 이 이상은 외경 합으로, [kSingleMid] 이상 이 미만은 면적 표로.
const double kSingleBig = 500;
const double kSingleMid = 100;

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

  const TrayCable({
    required this.name,
    required this.od,
    required this.size,
    required this.cores,
    required this.count,
    this.control = false,
  });

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
    );
  }
}

/// 어떤 규칙으로 봤는지.
enum TrayRule {
  multiBigDia, // 다심 100 이상만: 외경 합 ≤ 폭, 한 층
  multiSmallArea, // 다심 100 미만만: 단면적 합 ≤ 표
  multiMixed, // 다심 섞임: 작은 것 단면적 합 ≤ 표 − 계수 × 굵은 것 외경 합
  controlPct, // 제어·신호 다심만: 단면적 합 ≤ 내 단면적 × 50%(40%)
  singleBigDia, // 단심 500 이상만: 외경 합 ≤ 폭
  singleMidArea, // 단심 100~500만: 단면적 합 ≤ 표 5
  singleMixed, // 단심 500 이상과 100~500 섞임
  singleLayerDia, // 단심 100 미만이 있거나, 다심·단심이 함께: 모두 외경 합 ≤ 폭, 한 층
}

String trayRuleLabel(TrayRule r) => switch (r) {
  TrayRule.multiBigDia => '다심 100mm² 이상: 외경 합 ≤ 트레이 폭, 한 층',
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

/// 트레이 하나를 판정한다. [margin]은 예비 여유(0.2 = 20%)로, 쓴 양에 (1 + margin)을 곱한다.
/// 케이블이 없으면 null.
TrayCheck? checkTray({
  required TrayType type,
  required double width,
  required double depth,
  required List<TrayCable> cables,
  double margin = 0,
}) {
  final list = [for (final c in cables) if (c.count > 0) c];
  if (list.isEmpty) return null;
  final k = 1 + margin;
  final notes = <String>[];
  if (margin > 0) notes.add('예비 여유 ${(margin * 100).round()}%를 더해 판정했습니다.');
  if (!kTrayTableWidths.contains(width)) {
    notes.add('${_n(width)}mm는 표에 없는 폭이라 표 값을 폭에 비례해 계산했습니다.');
  }
  final solid = isSolidTray(type);
  final multi = [for (final c in list) if (c.isMulti) c];
  final single = [for (final c in list) if (!c.isMulti) c];

  TrayCheck dia(TrayRule rule, List<TrayCable> cs, String what) {
    final sd = cs.fold(0.0, (a, c) => a + c.diaSum);
    return TrayCheck(
      rule: rule,
      used: sd * k,
      limit: width,
      byDia: true,
      singleLayer: true,
      formula: '$what 외경 합 ${_n(sd)}mm${margin > 0 ? ' × ${k.toStringAsFixed(2)}' : ''} ≤ 폭 ${_n(width)}mm',
      notes: [...notes, '한 층으로 나란히 깔아야 합니다(겹쳐 쌓지 않음).'],
    );
  }

  // 다심과 단심이 함께 있으면 모두 한 층으로 본다(판단기준 해설 자료의 함께 넣는 예와 같은 방법).
  if (multi.isNotEmpty && single.isNotEmpty) {
    return dia(TrayRule.singleLayerDia, list, '다심·단심 모두');
  }

  if (multi.isNotEmpty) {
    // 제어·신호 다심만: 트레이 내 단면적의 50%(바닥밀폐 40%).
    if (multi.every((c) => c.control) && depth <= kControlDepthMax) {
      final pct = solid ? kControlSolidPct : kControlOpenPct;
      final inner = width * depth;
      final a = multi.fold(0.0, (s, c) => s + c.area);
      return TrayCheck(
        rule: TrayRule.controlPct,
        used: a * k,
        limit: inner * pct / 100,
        byDia: false,
        singleLayer: false,
        formula: '단면적 합 ${_n(a)}mm²${margin > 0 ? ' × ${k.toStringAsFixed(2)}' : ''} ≤ 내 단면적 ${_n(width)}×${_n(depth)}mm²의 ${pct.round()}%',
        notes: notes,
      );
    }
    final big = [for (final c in multi) if (c.size >= kMultiBig) c];
    final small = [for (final c in multi) if (c.size < kMultiBig) c];
    if (small.isEmpty) return dia(TrayRule.multiBigDia, big, '다심 100mm² 이상');
    final table = _table(solid ? _multiSolid : _multiOpen, width);
    final a = small.fold(0.0, (s, c) => s + c.area);
    if (big.isEmpty) {
      return TrayCheck(
        rule: TrayRule.multiSmallArea,
        used: a * k,
        limit: table,
        byDia: false,
        singleLayer: false,
        formula: '단면적 합 ${_n(a)}mm²${margin > 0 ? ' × ${k.toStringAsFixed(2)}' : ''} ≤ ${trayTypeLabel(type)} ${_n(width)}mm 표 ${_n(table)}mm²',
        notes: notes,
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
      formula: '100mm² 미만 단면적 합 ${_n(a)}mm² + ${coef.toStringAsFixed(1)} × 100mm² 이상 외경 합 ${_n(sd)}mm${margin > 0 ? ' (× ${k.toStringAsFixed(2)})' : ''} ≤ 표 ${_n(table)}mm²',
      notes: [...notes, '100mm² 이상 케이블은 한 층으로 깝니다.'],
    );
  }

  // 단심만.
  if (single.any((c) => c.size < kSingleMid)) {
    return dia(TrayRule.singleLayerDia, single, '단심 모두');
  }
  final big = [for (final c in single) if (c.size >= kSingleBig) c];
  final mid = [for (final c in single) if (c.size < kSingleBig) c];
  if (mid.isEmpty) return dia(TrayRule.singleBigDia, big, '단심 500mm² 이상');
  if (solid) notes.add('단심 표는 사다리형·통풍형 기준입니다. 바닥밀폐형도 같은 표로 봤습니다.');
  final table = _table(_singleOpen, width);
  final a = mid.fold(0.0, (s, c) => s + c.area);
  if (big.isEmpty) {
    return TrayCheck(
      rule: TrayRule.singleMidArea,
      used: a * k,
      limit: table,
      byDia: false,
      singleLayer: false,
      formula: '단면적 합 ${_n(a)}mm²${margin > 0 ? ' × ${k.toStringAsFixed(2)}' : ''} ≤ ${_n(width)}mm 표 ${_n(table)}mm²',
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
    formula: '100~500mm² 단면적 합 ${_n(a)}mm² + 28 × 500mm² 이상 외경 합 ${_n(sd)}mm${margin > 0 ? ' (× ${k.toStringAsFixed(2)})' : ''} ≤ 표 ${_n(table)}mm²',
    notes: [...notes, '500mm² 이상 케이블은 한 층으로 깝니다.'],
  );
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
}) {
  final rows = <(double, TrayCheck)>[];
  double? best;
  for (final w in [...widths]..sort()) {
    final c = checkTray(type: type, width: w, depth: depth, cables: cables, margin: margin);
    if (c == null) return null;
    rows.add((w, c));
    if (best == null && c.ok) best = w;
  }
  return TraySizing(rows, best);
}
