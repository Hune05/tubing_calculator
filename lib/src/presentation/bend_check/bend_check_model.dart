// 벤딩 실측 기록: 계산한 값과 실제로 잰 값을 남겨 두고, 같은 규격·장비의 지난 차이를 참고로 보여 준다.
// 계산 엔진에는 손대지 않는다. 이 기록은 화면에 참고로만 나오고 마킹 값을 바꾸지 않는다.
import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/record_sync.dart';

const String kBendChecksKey = 'bend_checks_v1';
const int kBendCheckCap = 300;

/// 무엇을 쟀는지(10-13). 다리 = 벤드 뒤 앞 꺾이는 점(첫 벤드는 관 끝)에서 이 꺾이는 점까지,
/// 자른 길이 = 자른 관 길이. 비면 정하지 않은 것(예전 기록).
const String kBendKindLeg = 'leg';
const String kBendKindCut = 'cut';

/// 기록 판. 2부터 계산값이 다리 길이·자른 길이다.
/// 10-13 전(1) 현장 탭은 줄자 마킹 눈금을 계산값으로 적어, 벤딩 뒤 잰 다리 길이와 견줄 수 없었다
/// (A9+ 965 줄 → 마킹 945, 다리 966을 넣으면 +21). 그래서 옛 기록은 목록에만 두고 참고 통계에서 뺀다(사용자 결정).
const int kBendCheckVersion = 2;

class BendCheck {
  final String id; // 만든 시각(밀리초)
  final DateTime at;

  /// 튜브 규격·장비를 한 줄로 적은 이름(예: "1/2\" SUS · 스웨이지락 수동"). 같은 이름끼리 묶어 통계를 낸다.
  final String group;
  final String what; // 무엇을 쟀는지(예: 90° 1번 마킹)
  final double calc; // 계산값(mm)
  final double actual; // 실측값(mm)
  final String note;

  /// [kBendKindLeg]·[kBendKindCut], 비면 정하지 않음.
  final String kind;

  /// 다리면 그 벤드 각도(같은 각도끼리만 센다 — 게인 오차는 각도마다 크기가 다르다).
  final double? angle;

  /// 그때 장비 값(예: "게인 40"). 시험 벤딩으로 값을 고친 뒤에는 고친 뒤 기록만 센다.
  final String setup;

  /// 기록 판([kBendCheckVersion]보다 낮으면 참고에서 뺀다).
  final int version;
  const BendCheck({
    required this.id,
    required this.at,
    required this.group,
    this.what = '',
    required this.calc,
    required this.actual,
    this.note = '',
    this.kind = '',
    this.angle,
    this.setup = '',
    this.version = kBendCheckVersion,
  });

  /// 실측 − 계산. 플러스면 실제가 계산보다 길다.
  double get diff => actual - calc;

  /// 참고 통계에 넣는지(10-13 전 기록은 뺀다).
  bool get counted => version >= kBendCheckVersion;

  /// 같이 셀 종류(자른 길이끼리, 같은 각도 다리끼리).
  String get kindKey => bendKindKey(kind, angle);

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toIso8601String(),
    'group': group,
    'what': what,
    'calc': calc,
    'actual': actual,
    'note': note,
    'kind': kind,
    'angle': ?angle,
    'setup': setup,
    'v': version,
  };

  static BendCheck? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final at = DateTime.tryParse((raw['at'] ?? '').toString());
    final calc = raw['calc'];
    final actual = raw['actual'];
    if (at == null || calc is! num || actual is! num) return null;
    return BendCheck(
      id: (raw['id'] ?? at.millisecondsSinceEpoch).toString(),
      at: at,
      group: (raw['group'] ?? '').toString(),
      what: (raw['what'] ?? '').toString(),
      calc: calc.toDouble(),
      actual: actual.toDouble(),
      note: (raw['note'] ?? '').toString(),
      kind: (raw['kind'] ?? '').toString(),
      angle: (raw['angle'] as num?)?.toDouble(),
      setup: (raw['setup'] ?? '').toString(),
      // 판이 없으면 10-13 전 기록이다.
      version: (raw['v'] as num?)?.toInt() ?? 1,
    );
  }
}

String _deg(double? a) {
  if (a == null) return '';
  final r = (a * 10).round() / 10;
  return r == r.roundToDouble() ? r.round().toString() : r.toStringAsFixed(1);
}

/// 같이 셀 종류 이름표.
String bendKindKey(String kind, double? angle) => switch (kind) {
  kBendKindCut => 'cut',
  kBendKindLeg => 'leg:${_deg(angle)}',
  _ => 'other',
};

/// 종류 이름(예: "90° 다리", "자른 길이").
String bendKindLabel(String kindKey) {
  if (kindKey == 'cut') return '자른 길이';
  if (kindKey.startsWith('leg:')) {
    final a = kindKey.substring(4);
    return a.isEmpty ? '벤드 다리' : '$a° 다리';
  }
  return '기타';
}

/// 한 묶음의 통계.
class BendStats {
  final int n;
  final double mean; // 차이 평균(mm)
  final double min;
  final double max;
  final double spread; // 차이가 흩어진 정도(표준편차, mm). 하나뿐이면 0
  const BendStats(this.n, this.mean, this.min, this.max, this.spread);
}

/// [group]에 맞는 기록의 차이 통계. 기록이 없으면 null.
/// 10-13 전 기록은 뺀다. [kindKey]를 주면 같은 종류(같은 각도 다리·자른 길이)만,
/// [setup]을 주면 그 장비 값으로 잰 기록만(장비 값이 안 적힌 기록 — 손으로 넣은 것 — 은 센다).
BendStats? statsFor(
  List<BendCheck> all,
  String group, {
  String? kindKey,
  String? setup,
}) {
  final d = [
    for (final c in all)
      if (c.counted &&
          c.group == group &&
          (kindKey == null || c.kindKey == kindKey) &&
          (setup == null || c.setup.isEmpty || c.setup == setup))
        c.diff,
  ];
  if (d.isEmpty) return null;
  final mean = d.reduce((a, b) => a + b) / d.length;
  final varSum = d.fold<double>(0, (s, v) => s + (v - mean) * (v - mean));
  final sd = d.length > 1 ? math.sqrt(varSum / (d.length - 1)) : 0.0;
  return BendStats(d.length, mean, d.reduce(math.min), d.reduce(math.max), sd);
}

/// 이 묶음·종류에서 가장 최근 기록의 장비 값(없으면 null). 기록 화면처럼 지금 장비 값을 모를 때 쓴다.
String? latestSetup(List<BendCheck> all, String group, String kindKey) {
  BendCheck? best;
  for (final c in all) {
    if (!c.counted || c.group != group || c.kindKey != kindKey) continue;
    if (c.setup.isEmpty) continue;
    if (best == null || c.at.isAfter(best.at)) best = c;
  }
  return best?.setup;
}

/// 묶음 이름들(최근에 쓴 것이 앞, 겹치지 않게).
List<String> groupNames(List<BendCheck> all) {
  final seen = <String>[];
  for (final c in [...all]..sort((a, b) => b.at.compareTo(a.at))) {
    if (c.group.isNotEmpty && !seen.contains(c.group)) seen.add(c.group);
  }
  return seen;
}

String _mm(double v) {
  final r = (v * 10).round() / 10;
  return r == r.roundToDouble() ? r.round().toString() : r.toStringAsFixed(1);
}

String signedMm(double v) => '${v > 0 ? '+' : ''}${_mm(v)} mm';

/// 참고 글: "지난 실측 5건: 평균 +1.2 mm (실측이 계산보다 김), 범위 -0.5 ~ +2.4".
String referenceText(BendStats s) {
  if (s.n == 0) return '';
  final dir = s.mean.abs() < 0.05
      ? '계산과 거의 같았습니다'
      : (s.mean > 0 ? '실측이 계산보다 길었습니다' : '실측이 계산보다 짧았습니다');
  final range = s.n > 1 ? ', 범위 ${signedMm(s.min)} ~ ${signedMm(s.max)}' : '';
  return '지난 실측 ${s.n}건: 평균 ${signedMm(s.mean)} ($dir)$range';
}

/// 몇 건이 쌓여야 참고로 믿을 만한지(적으면 "건수가 적다"고 덧붙인다).
const int kBendReliableCount = 3;

// ── 저장·읽기(폰 안) ──

Future<List<BendCheck>> loadBendChecks() async {
  try {
    final s = (await SharedPreferences.getInstance()).getString(kBendChecksKey);
    if (s == null || s.isEmpty) return [];
    final list = jsonDecode(s);
    if (list is! List) return [];
    // 한 건이 깨져도 나머지는 읽는다(10-08: 빈 목록이 되면 다음 저장이 기록 전체를 덮었다).
    final out = <BendCheck>[];
    for (final e in list) {
      try {
        final c = BendCheck.fromJson(e);
        if (c != null) out.add(c);
      } catch (_) {}
    }
    return out..sort((a, b) => b.at.compareTo(a.at));
  } catch (_) {
    return [];
  }
}

Future<void> _write(List<BendCheck> all) async {
  try {
    final keep = all.take(kBendCheckCap).toList();
    await (await SharedPreferences.getInstance()).setString(
      kBendChecksKey,
      jsonEncode([for (final c in keep) c.toJson()]),
    );
  } catch (_) {}
}

Future<void> addBendCheck(BendCheck c) async {
  final all = await loadBendChecks();
  await _write([c, ...all.where((e) => e.id != c.id)]);
  await bendCheckSync.saved(c.id);
}

Future<void> deleteBendCheck(String id) async {
  final all = await loadBendChecks();
  await _write([
    for (final e in all)
      if (e.id != id) e,
  ]);
  await bendCheckSync.removed(id);
}

/// 실측 기록을 서버(bend_check_records)에도 올린다(10-09 고도화 2번). 폰을 잃거나 바꿔도 남는다.
/// 개수 상한으로 폰에서 밀려난 옛 기록은 서버에 그대로 둔다(지운 것이 아니다).
final RecordSync bendCheckSync = RecordSync(
  key: kBendChecksKey,
  collection: 'bend_check_records',
  isValid: (j) => BendCheck.fromJson(j) != null,
);

/// 공유용 글(묶음별로 통계와 기록).
String buildBendCheckText(List<BendCheck> all, {String? group}) {
  final names = group == null ? groupNames(all) : [group];
  final b = StringBuffer('[벤딩 실측 기록]');
  for (final g in names) {
    final list = [
      for (final c in all)
        if (c.group == g) c,
    ]..sort((a, b) => a.at.compareTo(b.at));
    b.write('\n\n■ $g');
    // 종류(같은 각도 다리·자른 길이)마다 참고 한 줄. 장비 값이 바뀌었으면 마지막 값으로 잰 것만.
    final kinds = <String>[];
    for (final c in list) {
      if (c.counted && !kinds.contains(c.kindKey)) kinds.add(c.kindKey);
    }
    for (final k in kinds) {
      final setup = latestSetup(all, g, k);
      final s = statsFor(all, g, kindKey: k, setup: setup);
      if (s == null) continue;
      final tag = setup == null ? '' : ' ($setup)';
      b.write('\n${bendKindLabel(k)}$tag: ${referenceText(s)}');
    }
    for (final c in list) {
      final what = c.what.isEmpty ? '' : '${c.what} ';
      final old = c.counted ? '' : ' · 옛 기록(참고에서 뺌)';
      b.write(
        '\n${c.at.month}/${c.at.day} $what계산 ${_mm(c.calc)} → 실측 ${_mm(c.actual)} (${signedMm(c.diff)})$old',
      );
    }
  }
  return b.toString();
}
