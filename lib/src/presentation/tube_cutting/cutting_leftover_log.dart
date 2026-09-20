import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'cutting_leftovers.dart';

// 잔재 기록: 재단 최적화에서 "잘랐습니다 (잔재 저장)"를 누를 때마다 언제·어느 작업에서·어떤 잔재를 쓰고
// 어떤 잔재가 새로 생겼는지 한 건씩 적어 둔다. 튜브·형강이 함께 쓰고, 이 폰에만 저장한다(최근 100건).
// 창에서 저장을 되돌리면 그 기록도 함께 지운다.
const String kLeftoverLogPrefsKey = 'cutting_leftover_log_v1';
const int kMaxLeftoverLog = 100;

class LeftoverLogEntry {
  final String id;
  final DateTime at;
  final String source; // "튜브 컷팅 · 루마"처럼 어느 작업인지
  final List<Leftover> used; // 이번에 쓴 잔재
  final List<Leftover> added; // 새로 생긴 잔재

  const LeftoverLogEntry({
    required this.id,
    required this.at,
    required this.source,
    required this.used,
    required this.added,
  });

  String toJson() => jsonEncode({
    'id': id,
    't': at.toIso8601String(),
    's': source,
    'u': [for (final l in used) l.encode()],
    'a': [for (final l in added) l.encode()],
  });

  static LeftoverLogEntry? fromJson(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      List<Leftover> list(dynamic v) => [
        for (final s in (v as List? ?? const []))
          ?Leftover.decode(s.toString()),
      ];
      final at = DateTime.tryParse(m['t']?.toString() ?? '');
      if (at == null) return null;
      return LeftoverLogEntry(
        id: m['id']?.toString() ?? at.microsecondsSinceEpoch.toString(),
        at: at,
        source: m['s']?.toString() ?? '',
        used: list(m['u']),
        added: list(m['a']),
      );
    } catch (_) {
      return null;
    }
  }
}

// 최신 기록이 앞.
Future<List<LeftoverLogEntry>> loadLeftoverLog() async {
  try {
    final p = await SharedPreferences.getInstance();
    return [
      for (final raw
          in p.getStringList(kLeftoverLogPrefsKey) ?? const <String>[])
        ?LeftoverLogEntry.fromJson(raw),
    ];
  } catch (_) {
    return const [];
  }
}

Future<void> _save(List<LeftoverLogEntry> list) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(kLeftoverLogPrefsKey, [
      for (final e in list) e.toJson(),
    ]);
  } catch (_) {}
}

// 기록을 한 건 더한다. 쓴 것도 새로 생긴 것도 없으면 적지 않고 null. 더한 기록의 id를 돌려준다(되돌릴 때 지우려고).
Future<String?> appendLeftoverLog({
  required String source,
  required List<Leftover> used,
  required List<Leftover> added,
  DateTime? now,
}) async {
  if (used.isEmpty && added.isEmpty) return null;
  final at = now ?? DateTime.now();
  final entry = LeftoverLogEntry(
    id: '${at.microsecondsSinceEpoch}',
    at: at,
    source: source,
    used: used,
    added: added,
  );
  final list = [entry, ...await loadLeftoverLog()];
  if (list.length > kMaxLeftoverLog)
    list.removeRange(kMaxLeftoverLog, list.length);
  await _save(list);
  return entry.id;
}

Future<void> removeLeftoverLog(String id) async {
  final list = [...await loadLeftoverLog()]..removeWhere((e) => e.id == id);
  await _save(list);
}

// 같은 규격·길이를 "5400mm × 2"처럼 묶어 규격별로 적는다. 빈 목록이면 "없음".
String describeLeftovers(List<Leftover> list) {
  if (list.isEmpty) return '없음';
  final byLabel = <String, Map<double, int>>{};
  for (final l in list) {
    final m = byLabel.putIfAbsent(l.label, () => {});
    m[l.length] = (m[l.length] ?? 0) + 1;
  }
  final parts = <String>[];
  for (final e in byLabel.entries) {
    final lens = e.value.keys.toList()..sort((a, b) => b.compareTo(a));
    final text = [
      for (final len in lens)
        '${len.toStringAsFixed(0)}mm${e.value[len]! > 1 ? ' × ${e.value[len]}' : ''}',
    ].join(', ');
    parts.add('${e.key.isEmpty ? '' : '${e.key} '}$text');
  }
  return parts.join(' / ');
}
