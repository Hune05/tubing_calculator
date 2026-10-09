// 벤딩 실측 기록: 계산한 값과 실제로 잰 값을 남겨 두고, 같은 규격·장비의 지난 차이를 참고로 보여 준다.
// 계산 엔진에는 손대지 않는다. 이 기록은 화면에 참고로만 나오고 마킹 값을 바꾸지 않는다.
import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/record_sync.dart';

const String kBendChecksKey = 'bend_checks_v1';
const int kBendCheckCap = 300;

class BendCheck {
  final String id; // 만든 시각(밀리초)
  final DateTime at;

  /// 튜브 규격·장비를 한 줄로 적은 이름(예: "1/2\" SUS · 스웨이지락 수동"). 같은 이름끼리 묶어 통계를 낸다.
  final String group;
  final String what; // 무엇을 쟀는지(예: 90° 1번 마킹)
  final double calc; // 계산값(mm)
  final double actual; // 실측값(mm)
  final String note;
  const BendCheck({
    required this.id,
    required this.at,
    required this.group,
    this.what = '',
    required this.calc,
    required this.actual,
    this.note = '',
  });

  /// 실측 − 계산. 플러스면 실제가 계산보다 길다.
  double get diff => actual - calc;

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toIso8601String(),
    'group': group,
    'what': what,
    'calc': calc,
    'actual': actual,
    'note': note,
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
    );
  }
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
BendStats? statsFor(List<BendCheck> all, String group) {
  final d = [
    for (final c in all)
      if (c.group == group) c.diff,
  ];
  if (d.isEmpty) return null;
  final mean = d.reduce((a, b) => a + b) / d.length;
  final varSum = d.fold<double>(0, (s, v) => s + (v - mean) * (v - mean));
  final sd = d.length > 1 ? math.sqrt(varSum / (d.length - 1)) : 0.0;
  return BendStats(d.length, mean, d.reduce(math.min), d.reduce(math.max), sd);
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
  await _write([for (final e in all) if (e.id != id) e]);
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
    final list = [for (final c in all) if (c.group == g) c]
      ..sort((a, b) => a.at.compareTo(b.at));
    final s = statsFor(all, g);
    b.write('\n\n■ $g');
    if (s != null) b.write('\n${referenceText(s)}');
    for (final c in list) {
      final what = c.what.isEmpty ? '' : '${c.what} ';
      b.write(
        '\n${c.at.month}/${c.at.day} $what계산 ${_mm(c.calc)} → 실측 ${_mm(c.actual)} (${signedMm(c.diff)})',
      );
    }
  }
  return b.toString();
}
