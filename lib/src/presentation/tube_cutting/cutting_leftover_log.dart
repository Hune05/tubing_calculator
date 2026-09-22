import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'cutting_leftovers.dart';

// 잔재 기록: 재단 계획에서 "잘랐습니다 (잔재 저장)"를 누를 때마다 언제·어느 작업에서·어떤 잔재를 쓰고
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
  if (list.length > kMaxLeftoverLog) {
    list.removeRange(kMaxLeftoverLog, list.length);
  }
  await _save(list);
  return entry.id;
}

Future<void> removeLeftoverLog(String id) async {
  final list = [...await loadLeftoverLog()]..removeWhere((e) => e.id == id);
  await _save(list);
}

// 기록에 나온 규격들(최신 기록부터 처음 나온 순서).
List<String> leftoverLogLabels(List<LeftoverLogEntry> entries) {
  final out = <String>[];
  for (final e in entries) {
    for (final l in [...e.used, ...e.added]) {
      if (!out.contains(l.label)) out.add(l.label);
    }
  }
  return out;
}

// 최근 [days]일 안의 기록만, 규격 [label]이 있으면 그 규격의 잔재만 남긴다(둘 다 null이면 그대로).
// 고른 규격이 하나도 없는 기록은 뺀다.
List<LeftoverLogEntry> filterLeftoverLog(
  List<LeftoverLogEntry> entries, {
  int? days,
  String? label,
  DateTime? now,
}) {
  final since = days == null
      ? null
      : (now ?? DateTime.now()).subtract(Duration(days: days));
  final out = <LeftoverLogEntry>[];
  for (final e in entries) {
    if (since != null && e.at.isBefore(since)) continue;
    if (label == null) {
      out.add(e);
      continue;
    }
    final used = [
      for (final l in e.used)
        if (l.label == label) l,
    ];
    final added = [
      for (final l in e.added)
        if (l.label == label) l,
    ];
    if (used.isEmpty && added.isEmpty) continue;
    out.add(
      LeftoverLogEntry(
        id: e.id,
        at: e.at,
        source: e.source,
        used: used,
        added: added,
      ),
    );
  }
  return out;
}

const List<String> _wdKo = ['월', '화', '수', '목', '금', '토', '일'];

// "9월 20일(일) 09:05"
String fmtLogWhen(DateTime t) =>
    '${t.month}월 ${t.day}일(${_wdKo[t.weekday - 1]}) '
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

// 메신저에 붙여넣는 잔재 글: 지금 화면에 보이는 기록(거른 조건 포함)과, 있으면 지금 남아 있는 잔재.
// [filterText]는 "최근 7일 · 앵글 40x40x3"처럼 어떤 조건으로 걸렀는지.
String buildLeftoverLogText({
  required List<LeftoverLogEntry> entries,
  String filterText = '',
  List<Leftover> current = const [],
}) {
  final b = StringBuffer();
  b.writeln('[잔재 기록]${filterText.isEmpty ? '' : ' ($filterText)'}');
  if (entries.isEmpty) {
    b.writeln('기록이 없습니다.');
  } else {
    for (final e in entries) {
      b.writeln(
        '${fmtLogWhen(e.at)}${e.source.isEmpty ? '' : ' · ${e.source}'}',
      );
      b.writeln('  쓴 잔재: ${describeLeftovers(e.used)}');
      b.writeln('  새 잔재: ${describeLeftovers(e.added)}');
    }
  }
  if (current.isNotEmpty) {
    final total = current.fold<double>(0, (s, l) => s + l.length);
    b.writeln();
    b.writeln(
      '[지금 남은 잔재] 전체 ${current.length}개 · 합계 ${total.toStringAsFixed(0)}mm',
    );
    b.writeln(describeLeftovers(current));
  }
  return b.toString().trimRight();
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
