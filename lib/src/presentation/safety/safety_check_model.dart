// 작업 전 안전 점검(TBM): 항목을 하나씩 "확인"이나 "해당 없음"으로 체크하고 기록으로 남긴다.
// 이 파일은 자료 구조와 글 만들기, 저장·읽기만 한다(화면과 따로 시험한다).
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/record_sync.dart';

/// 처음 나오는 점검 항목(발전소 계장·배관·전기 작업 기준). 쓰는 사람이 화면에서 고칠 수 있다.
const List<String> kDefaultSafetyItems = [
  '작업허가서 확인',
  '작업 범위·위험 요인 작업자 전원에게 공유',
  '보호구 착용 (안전모·안전화·보안경·장갑)',
  '정전·잠금(LOTO)과 표지 확인',
  '가압·고온·유해 배관 잔압 제거·냉각 확인',
  '고소 작업 시 안전대·발판 상태 확인',
  '밀폐 공간·가스 측정 확인 (해당 시)',
  '화기 작업 시 소화기·불티 방지 확인 (해당 시)',
  '공구·자재 정리와 통로 확보',
  '비상 연락망·대피로 확인',
];

const String kSafetyItemsKey = 'safety_items_v1';
const String kSafetyRecordsKey = 'safety_checks_v1';
const String kSafetySiteKey = 'safety_last_site_v1';
/// 적던 점검(오늘 것만 되살림, 10-08).
const String kSafetyDraftKey = 'safety_draft_v1';
const int kSafetyRecordCap = 100;

enum SafetyAnswer { none, yes, na }

class SafetyLine {
  final String label;
  final SafetyAnswer answer;
  const SafetyLine(this.label, this.answer);

  Map<String, dynamic> toJson() => {'l': label, 'a': answer.name};

  static SafetyLine fromJson(Map<String, dynamic> m) => SafetyLine(
    (m['l'] ?? '').toString(),
    SafetyAnswer.values.firstWhere(
      (a) => a.name == m['a'],
      orElse: () => SafetyAnswer.none,
    ),
  );
}

class SafetyRecord {
  final String id; // 만든 시각(밀리초)
  final DateTime at;
  final String site;
  final String work;
  final String people;
  final String risks;
  final List<SafetyLine> lines;
  const SafetyRecord({
    required this.id,
    required this.at,
    this.site = '',
    this.work = '',
    this.people = '',
    this.risks = '',
    required this.lines,
  });

  int get unanswered => lines.where((l) => l.answer == SafetyAnswer.none).length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toIso8601String(),
    'site': site,
    'work': work,
    'people': people,
    'risks': risks,
    'lines': [for (final l in lines) l.toJson()],
  };

  static SafetyRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final at = DateTime.tryParse((raw['at'] ?? '').toString());
    if (at == null) return null;
    final lines = raw['lines'];
    return SafetyRecord(
      id: (raw['id'] ?? at.millisecondsSinceEpoch).toString(),
      at: at,
      site: (raw['site'] ?? '').toString(),
      work: (raw['work'] ?? '').toString(),
      people: (raw['people'] ?? '').toString(),
      risks: (raw['risks'] ?? '').toString(),
      lines: [
        if (lines is List)
          for (final l in lines)
            if (l is Map) SafetyLine.fromJson(Map<String, dynamic>.from(l)),
      ],
    );
  }
}

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

String _two(int n) => n.toString().padLeft(2, '0');

/// 카톡에 보낼 글.
String buildSafetyCheckText(SafetyRecord r) {
  final b = StringBuffer(
    '[작업 전 안전 점검] ${r.at.month}/${r.at.day} (${_weekdays[r.at.weekday - 1]}) '
    '${_two(r.at.hour)}:${_two(r.at.minute)}',
  );
  if (r.site.trim().isNotEmpty) b.write('\n현장: ${r.site.trim()}');
  if (r.work.trim().isNotEmpty) b.write('\n작업: ${r.work.trim()}');
  for (final l in r.lines) {
    final mark = switch (l.answer) {
      SafetyAnswer.yes => '✔',
      SafetyAnswer.na => '-',
      SafetyAnswer.none => '□',
    };
    final tail = switch (l.answer) {
      SafetyAnswer.na => ' (해당 없음)',
      SafetyAnswer.none => ' (미확인)',
      SafetyAnswer.yes => '',
    };
    b.write('\n$mark ${l.label}$tail');
  }
  if (r.risks.trim().isNotEmpty) b.write('\n위험 요인·메모: ${r.risks.trim()}');
  if (r.people.trim().isNotEmpty) b.write('\n참석: ${r.people.trim()}');
  return b.toString();
}

/// 오늘 한 점검 중 가장 늦은 것(없으면 null).
SafetyRecord? safetyCheckToday(List<SafetyRecord> all, DateTime now) {
  SafetyRecord? best;
  for (final r in all) {
    final same = r.at.year == now.year && r.at.month == now.month && r.at.day == now.day;
    if (same && (best == null || r.at.isAfter(best.at))) best = r;
  }
  return best;
}

/// 최근 [days]일 안에 점검을 한 적이 있는지(습관이 있는 사람에게만 "오늘 안 했다"를 알리려고).
bool safetyUsedRecently(List<SafetyRecord> all, DateTime now, {int days = 14}) {
  final from = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
  return all.any((r) => !r.at.isBefore(from));
}

/// "8:05" 같은 시각 글.
String safetyTimeLabel(DateTime t) =>
    '${t.month}/${t.day} ${_two(t.hour)}:${_two(t.minute)}';

// ── 저장·읽기(폰 안) ──

Future<List<String>> loadSafetyItems() async {
  try {
    final p = await SharedPreferences.getInstance();
    final l = p.getStringList(kSafetyItemsKey);
    if (l != null && l.isNotEmpty) return l;
  } catch (_) {}
  return List.of(kDefaultSafetyItems);
}

Future<void> saveSafetyItems(List<String> items) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(kSafetyItemsKey, items);
  } catch (_) {}
}

Future<List<SafetyRecord>> loadSafetyRecords() async {
  try {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(kSafetyRecordsKey);
    if (s == null || s.isEmpty) return [];
    final list = jsonDecode(s);
    if (list is! List) return [];
    return [
      for (final e in list) ?SafetyRecord.fromJson(e),
    ]..sort((a, b) => b.at.compareTo(a.at));
  } catch (_) {
    return [];
  }
}

Future<void> writeSafetyRecords(List<SafetyRecord> all) async {
  try {
    final p = await SharedPreferences.getInstance();
    final keep = all.take(kSafetyRecordCap).toList();
    await p.setString(
      kSafetyRecordsKey,
      jsonEncode([for (final r in keep) r.toJson()]),
    );
  } catch (_) {}
}

Future<void> addSafetyRecord(SafetyRecord r) async {
  final all = await loadSafetyRecords();
  await writeSafetyRecords([r, ...all.where((e) => e.id != r.id)]);
  await safetyRecordSync.saved(r.id);
}

Future<void> deleteSafetyRecord(String id) async {
  final all = await loadSafetyRecords();
  await writeSafetyRecords([for (final e in all) if (e.id != id) e]);
  await safetyRecordSync.removed(id);
}

/// 점검 기록을 서버(safety_records)에도 올린다(10-09 고도화 2번). 폰을 잃거나 바꿔도 남는다.
/// 개수 상한으로 폰에서 밀려난 옛 기록은 서버에 그대로 둔다(지운 것이 아니다).
final RecordSync safetyRecordSync = RecordSync(
  key: kSafetyRecordsKey,
  collection: 'safety_records',
  isValid: (j) => SafetyRecord.fromJson(j) != null,
);
