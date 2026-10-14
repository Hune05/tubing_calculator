// 심 기록(10-15): 기계마다 네 발 밑에 지금 심이 얼마 들어가 있는지 남긴다.
// - 시작 심: 작업 전에 발 밑에 있던 심(같은 기계의 지난 기록 끝 값으로 미리 채움, 고칠 수 있음).
// - 이번 작업: 회차에 적은 "한 일"의 누계(alignment_session.dart shimTotals).
// - 지금 심 = 시작 + 이번 작업. 가진 심 두께로 몇 장을 겹치면 되는지 조합을 보여 준다.
// 예전에는 회차 누계만 있고 저장하면 사라져서, 다음 정렬 때 발 밑에 무엇이 있는지 알 수 없었다.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../common/number_text.dart';
import 'alignment_record.dart';
import 'alignment_session.dart';

/// 처음 쓰는 심 두께(mm). 화면에서 가진 것으로 고칠 수 있다(규격표가 아니라 흔한 묶음).
const List<double> kAlignShimSizesDefault = [2.0, 1.0, 0.5, 0.2, 0.1, 0.05];

/// [mm]를 가진 두께로 겹칠 때의 판(큰 것부터) — 0.01 mm 단위로 센다. 딱 맞지 않으면 남는 양을 같이 준다.
({List<double> plates, double rest}) shimPlates(double mm, List<double> sizes) {
  final want = (mm.abs() * 100).round();
  final units = [
    for (final s in {...sizes}.toList()..sort((a, b) => b.compareTo(a)))
      if (s > 0) (s * 100).round(),
  ]..removeWhere((u) => u <= 0);
  var left = want;
  final out = <double>[];
  for (final u in units) {
    while (left >= u && out.length < 12) {
      out.add(u / 100);
      left -= u;
    }
  }
  return (plates: out, rest: left / 100);
}

String _fmt(double v) {
  final s = v.toStringAsFixed(2);
  return s.endsWith('0') ? v.toStringAsFixed(1) : s;
}

/// "1.0 + 0.2 + 0.05" (없으면 "없음"), 딱 맞지 않으면 "(0.03 모자람)".
String shimPlateText(double mm, List<double> sizes) {
  if (mm.abs() < 0.005) return '없음';
  final p = shimPlates(mm, sizes);
  final body = p.plates.isEmpty ? '' : p.plates.map(_fmt).join(' + ');
  if (p.rest.abs() < 0.005) return body;
  return '${body.isEmpty ? '' : '$body '}(${p.rest.toStringAsFixed(2)} 맞는 판 없음)';
}

String footMm(double v) => v.abs() < 0.005 ? '0' : v.toStringAsFixed(2);

/// 지금 심 = 시작 + 이번 작업 누계.
Map<AlignFoot, double> footNow(
  Map<AlignFoot, double> start,
  List<AlignRound> rounds,
) {
  final t = shimTotals(rounds);
  return {for (final f in AlignFoot.values) f: (start[f] ?? 0) + t[f]!};
}

bool sameMachine(String a, String b) {
  String n(String s) => s.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  return n(a).isNotEmpty && n(a) == n(b);
}

/// 같은 기계의 기록 중 발 밑 심을 남긴 것(최근 것 먼저).
List<AlignRecord> shimHistory(List<AlignRecord> all, String machine) => [
  for (final r in [...all]..sort((a, b) => b.at.compareTo(a.at)))
    if (sameMachine(r.machine, machine) && r.footEnd.isNotEmpty) r,
];

/// 같은 기계의 마지막 작업 끝 심(없으면 null).
Map<AlignFoot, double>? lastFeetFor(List<AlignRecord> all, String machine) {
  final h = shimHistory(all, machine);
  return h.isEmpty ? null : h.first.footEnd;
}

Map<String, double> feetToJson(Map<AlignFoot, double> m) => {
  for (final e in m.entries) e.key.name: e.value,
};

Map<AlignFoot, double> feetFromJson(Object? raw) => raw is Map
    ? {
        for (final f in AlignFoot.values)
          if (raw[f.name] is num) f: (raw[f.name] as num).toDouble(),
      }
    : const {};

/// 작업 중인 심 기록(기계 이름·시작 심)과 가진 심 두께. 폰에만 둔다.
class AlignShimStore {
  static const String key = 'align_shim_v1';
  static const String sizesKey = 'align_shim_sizes_v1';

  static Future<({String machine, Map<AlignFoot, double> start})> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(key);
      if (raw == null) return (machine: '', start: <AlignFoot, double>{});
      final m = jsonDecode(raw) as Map;
      return (
        machine: (m['machine'] ?? '').toString(),
        start: Map<AlignFoot, double>.from(feetFromJson(m['start'])),
      );
    } catch (_) {
      return (machine: '', start: <AlignFoot, double>{});
    }
  }

  static Future<void> save(String machine, Map<AlignFoot, double> start) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        key,
        jsonEncode({'machine': machine, 'start': feetToJson(start)}),
      );
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      await (await SharedPreferences.getInstance()).remove(key);
    } catch (_) {}
  }

  static Future<List<double>> sizes() async {
    try {
      final l = (await SharedPreferences.getInstance()).getStringList(sizesKey);
      final v = [for (final s in l ?? const <String>[]) ?double.tryParse(s)];
      return v.isEmpty ? List.of(kAlignShimSizesDefault) : v;
    } catch (_) {
      return List.of(kAlignShimSizesDefault);
    }
  }

  static Future<void> saveSizes(List<double> v) async {
    try {
      await (await SharedPreferences.getInstance()).setStringList(sizesKey, [
        for (final x in v) x.toString(),
      ]);
    } catch (_) {}
  }
}

// ── 소프트 풋(10-15) ──
// 네 발 볼트를 다 조인 뒤 다이얼을 발 위에 대고 한 발씩 풀어 올라오는 양. 현장 지침(softfoot)과 같은 기준.

/// 흔히 이보다 많이 올라오면 고친다(mm). 규격 값이 아니라 현장에서 흔히 쓰는 값.
const double kSoftFootLimit = 0.05;

/// 화면 칸·저장 값 이름.
String softFootKey(AlignFoot f) => 'sf_${f.name}';

/// 넣은 값(숫자인 것만).
Map<AlignFoot, double> softFootOf(Map<String, String> inputs) => {
  for (final f in AlignFoot.values)
    if (parseNumberText(inputs[softFootKey(f)] ?? '') case final v?) f: v.abs(),
};

/// 기준을 넘은 발.
List<AlignFoot> softFootOver(Map<AlignFoot, double> v) => [
  for (final f in AlignFoot.values)
    if ((v[f] ?? 0) > kSoftFootLimit + 1e-9) f,
];

/// "앞발 왼쪽 0.08, 뒷발 오른쪽 0.06"
String softFootList(Map<AlignFoot, double> v, Iterable<AlignFoot> feet) =>
    [for (final f in feet) '${f.label} ${(v[f] ?? 0).toStringAsFixed(2)}'].join(', ');
