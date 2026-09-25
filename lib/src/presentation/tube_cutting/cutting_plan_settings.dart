// 재단 계획 설정(튜브·형강 같이): 끝 다듬기, 쓸 만한 잔재 최소 길이, 가진 원자재 본수.
// 그리고 재단 계획을 CSV(엑셀에서 열 수 있는 표)로 만드는 셈.
//
// 🚀 [추가] OptiCutter 같은 1D 재단 도구처럼. 예전에는 끝 다듬기가 없고, 잔재 최소
// 길이가 300mm로 박혀 있고, 가진 원자재 수량을 넣을 곳이 없었다(모자란지 알 수 없었다).
import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cutting_optimizer.dart';

const String kCutEndTrimKey = 'cutting_end_trim_mm';
const String kCutMinLeftoverKey = 'cutting_min_leftover_mm';
const String kCutOwnedBarsKey = 'cutting_owned_bars_v1';

class CutPlanSettings {
  /// 새 원자재마다 첫 절단 전에 다듬어 버리는 길이(mm).
  final double endTrim;

  /// 이보다 짧은 잔재는 남겨 두지 않는다(mm).
  final double minLeftover;

  const CutPlanSettings({this.endTrim = 0, this.minLeftover = kMinLeftoverMm});
}

Future<CutPlanSettings> loadCutPlanSettings() async {
  try {
    final p = await SharedPreferences.getInstance();
    final trim = p.getDouble(kCutEndTrimKey) ?? 0;
    final min = p.getDouble(kCutMinLeftoverKey) ?? kMinLeftoverMm;
    return CutPlanSettings(
      endTrim: trim < 0 ? 0 : trim,
      minLeftover: min < 0 ? 0 : min,
    );
  } catch (_) {
    return const CutPlanSettings();
  }
}

Future<void> saveCutPlanSettings(CutPlanSettings s) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(kCutEndTrimKey, s.endTrim);
    await p.setDouble(kCutMinLeftoverKey, s.minLeftover);
  } catch (_) {}
}

/// 규격별 가진 원자재 본수(적은 규격만). 규격 구분이 없으면 열쇠는 ''.
Future<Map<String, int>> loadOwnedBars() async {
  try {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(kCutOwnedBarsKey);
    if (raw == null) return {};
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final e in m.entries)
        if (e.value is num && (e.value as num) > 0)
          e.key: (e.value as num).toInt(),
    };
  } catch (_) {
    return {};
  }
}

Future<void> saveOwnedBars(Map<String, int> owned) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      kCutOwnedBarsKey,
      jsonEncode({
        for (final e in owned.entries)
          if (e.value > 0) e.key: e.value,
      }),
    );
  } catch (_) {}
}

/// 가진 본수보다 더 필요한 규격을 글로. 모자란 곳이 없으면 빈 목록.
List<String> ownedShortage(
  Map<String, int> needBySpec,
  Map<String, int> owned,
) {
  final out = <String>[];
  for (final e in needBySpec.entries) {
    final have = owned[e.key];
    if (have == null || have <= 0 || e.value <= have) continue;
    final name = e.key.isEmpty ? '원자재' : e.key;
    out.add('$name: ${e.value}본 필요 · 가진 $have본 → ${e.value - have}본 모자람');
  }
  return out;
}

String _mm(double v) => v.toStringAsFixed(0);

/// 재단 계획을 CSV 글로. 한 줄에 조각 하나(규격·원자재·원자재 길이·조각 이름표·자를 길이·
/// 그 원자재의 남는 길이). 엑셀에서 한글이 깨지지 않게 앞에 BOM을 붙인다.
/// [labels]는 규격마다 [잔재 배치..., 새 원자재 배치...] 순서의 본별 이름표(없어도 된다).
String planCsv(
  Map<String, CuttingOptimizationResult> results, {
  Map<String, List<List<String>>> labels = const {},
}) {
  final rows = <List<dynamic>>[
    ['규격', '원자재', '원자재 길이(mm)', '조각', '자를 길이(mm)', '남는 길이(mm)'],
  ];
  for (final e in results.entries) {
    final r = e.value;
    final spec = e.key.isEmpty ? '-' : e.key;
    final bars = [...r.leftoverBars, ...r.bars];
    final lbl = labels[e.key] ?? const [];
    var n = 0;
    for (var bi = 0; bi < bars.length; bi++) {
      final b = bars[bi];
      final name = b.isLeftover ? '잔재' : '${++n}번';
      for (var pi = 0; pi < b.pieces.length; pi++) {
        final label = bi < lbl.length && pi < lbl[bi].length ? lbl[bi][pi] : '';
        rows.add([
          spec,
          name,
          _mm(b.stockLength),
          label,
          _mm(b.pieces[pi]),
          pi == 0 ? _mm(b.remainderWithKerf(r.kerf)) : '',
        ]);
      }
    }
  }
  return '﻿${const CsvEncoder().convert(rows)}';
}
