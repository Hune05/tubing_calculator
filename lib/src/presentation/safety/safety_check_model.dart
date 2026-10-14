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

/// fix = 조치 필요(10-10): 저장한 뒤 프로젝트 이슈로 올릴 수 있다(safety_issue_link.dart).
enum SafetyAnswer { none, yes, na, fix }

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

/// 참석자 한 명(10-14 TBM 서명): 이름, 업체(선택), 손가락 서명(없으면 '').
/// 서명은 그림 파일이 아니라 획 좌표 글([encodeSignature])로 적어 작다(한 명 1~3KB).
class SafetyAttendee {
  final String name;
  final String company;
  final String sig;
  const SafetyAttendee(this.name, {this.company = '', this.sig = ''});

  bool get signed => sig.isNotEmpty;

  /// "대성 홍길동" (업체가 없으면 이름만).
  String get label =>
      [company.trim(), name.trim()].where((e) => e.isNotEmpty).join(' ');

  Map<String, dynamic> toJson() => {
    'n': name,
    if (company.isNotEmpty) 'c': company,
    if (sig.isNotEmpty) 's': sig,
  };

  static SafetyAttendee? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final n = (raw['n'] ?? '').toString().trim();
    if (n.isEmpty) return null;
    return SafetyAttendee(
      n,
      company: (raw['c'] ?? '').toString().trim(),
      sig: (raw['s'] ?? '').toString(),
    );
  }
}

/// 서명 칸 비율(가로:세로 = 1000:400). 좌표는 이 정수 칸에 맞춰 적는다.
const double kSigW = 1000, kSigH = 400;

/// 획 목록(칸 크기 [w]×[h] 안의 좌표)을 글로: "v1:x,y x,y;x,y …". 가까운 점(4칸 안)은 건너뛴다.
String encodeSignature(
  List<List<(double, double)>> strokes,
  double w,
  double h,
) {
  if (w <= 0 || h <= 0) return '';
  final out = <String>[];
  for (final st in strokes) {
    final pts = <String>[];
    int? lx, ly;
    for (var i = 0; i < st.length; i++) {
      final x = (st[i].$1 / w * kSigW).round().clamp(0, kSigW.toInt());
      final y = (st[i].$2 / h * kSigH).round().clamp(0, kSigH.toInt());
      if (lx == x && ly == y) continue;
      final last = i == st.length - 1;
      if (lx != null && !last && (x - lx).abs() + (y - ly!).abs() < 4) {
        continue;
      }
      pts.add('$x,$y');
      lx = x;
      ly = y;
    }
    if (pts.isNotEmpty) out.add(pts.join(' '));
  }
  return out.isEmpty ? '' : 'v1:${out.join(';')}';
}

/// [encodeSignature] 글을 획 목록(가로 0~1000, 세로 0~400)으로. 깨진 글이면 빈 목록.
List<List<(double, double)>> decodeSignature(String sig) {
  if (!sig.startsWith('v1:')) return const [];
  final out = <List<(double, double)>>[];
  for (final st in sig.substring(3).split(';')) {
    final pts = <(double, double)>[];
    for (final p in st.split(' ')) {
      final xy = p.split(',');
      if (xy.length != 2) continue;
      final x = double.tryParse(xy[0]), y = double.tryParse(xy[1]);
      if (x != null && y != null) pts.add((x, y));
    }
    if (pts.isNotEmpty) out.add(pts);
  }
  return out;
}

/// 지난 점검에 나온 참석자(최근 것 먼저, 이름이 같으면 한 번). 이름 칩에 쓴다.
List<SafetyAttendee> recentAttendees(List<SafetyRecord> all, {int max = 16}) {
  final seen = <String>{};
  final out = <SafetyAttendee>[];
  final sorted = [...all]..sort((a, b) => b.at.compareTo(a.at));
  for (final r in sorted) {
    final list = r.attendees.isNotEmpty
        ? r.attendees
        : attendeesFromText(r.people);
    for (final a in list) {
      if (seen.add(a.name)) out.add(SafetyAttendee(a.name, company: a.company));
      if (out.length >= max) return out;
    }
  }
  return out;
}

/// 예전 "참석자" 글(쉼표로 구분)을 참석자 목록으로(서명 없음).
List<SafetyAttendee> attendeesFromText(String people) => [
  for (final n in people.split(RegExp(r'[,，、\n]')))
    if (n.trim().isNotEmpty) SafetyAttendee(n.trim()),
];

class SafetyRecord {
  final String id; // 만든 시각(밀리초)
  final DateTime at;
  final String site;
  final String work;
  final String people;
  final String risks;
  final List<SafetyLine> lines;

  /// 참석자와 서명(10-14). 예전 기록은 비어 있고 [people] 글만 있다.
  final List<SafetyAttendee> attendees;
  const SafetyRecord({
    required this.id,
    required this.at,
    this.site = '',
    this.work = '',
    this.people = '',
    this.risks = '',
    required this.lines,
    this.attendees = const [],
  });

  int get signedCount => attendees.where((a) => a.signed).length;

  int get unanswered =>
      lines.where((l) => l.answer == SafetyAnswer.none).length;
  int get fixCount => lines.where((l) => l.answer == SafetyAnswer.fix).length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toIso8601String(),
    'site': site,
    'work': work,
    'people': people,
    'risks': risks,
    'lines': [for (final l in lines) l.toJson()],
    if (attendees.isNotEmpty) 'att': [for (final a in attendees) a.toJson()],
  };

  static SafetyRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final at = DateTime.tryParse((raw['at'] ?? '').toString());
    if (at == null) return null;
    final lines = raw['lines'];
    final att = raw['att'];
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
      attendees: [
        if (att is List)
          for (final a in att) ?SafetyAttendee.fromJson(a),
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
      SafetyAnswer.fix => '✖',
    };
    final tail = switch (l.answer) {
      SafetyAnswer.na => ' (해당 없음)',
      SafetyAnswer.none => ' (미확인)',
      SafetyAnswer.fix => ' (조치 필요)',
      SafetyAnswer.yes => '',
    };
    b.write('\n$mark ${l.label}$tail');
  }
  if (r.risks.trim().isNotEmpty) b.write('\n위험 요인·메모: ${r.risks.trim()}');
  if (r.attendees.isNotEmpty) {
    final signed = r.signedCount;
    b.write(
      '\n참석 ${r.attendees.length}명: ${r.attendees.map((a) => a.label).join(', ')}'
      '${signed > 0 ? ' (서명 $signed명)' : ''}',
    );
  } else if (r.people.trim().isNotEmpty) {
    b.write('\n참석: ${r.people.trim()}');
  }
  return b.toString();
}

/// 오늘 한 점검 중 가장 늦은 것(없으면 null).
SafetyRecord? safetyCheckToday(List<SafetyRecord> all, DateTime now) {
  SafetyRecord? best;
  for (final r in all) {
    final same =
        r.at.year == now.year && r.at.month == now.month && r.at.day == now.day;
    if (same && (best == null || r.at.isAfter(best.at))) best = r;
  }
  return best;
}

/// 최근 [days]일 안에 점검을 한 적이 있는지(습관이 있는 사람에게만 "오늘 안 했다"를 알리려고).
bool safetyUsedRecently(List<SafetyRecord> all, DateTime now, {int days = 14}) {
  final from = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: days));
  return all.any((r) => !r.at.isBefore(from));
}

/// 점검 결과 한 마디: "항목 모두 확인" / "조치 필요 N개" / "미확인 N개"(목록·정리에 쓴다).
String safetyResultLabel(SafetyRecord r) => [
  if (r.fixCount > 0) '조치 필요 ${r.fixCount}개',
  if (r.unanswered > 0) '미확인 ${r.unanswered}개',
  if (r.fixCount == 0 && r.unanswered == 0) '항목 모두 확인',
].join(' · ');

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
    return [for (final e in list) ?SafetyRecord.fromJson(e)]
      ..sort((a, b) => b.at.compareTo(a.at));
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
  await writeSafetyRecords([
    for (final e in all)
      if (e.id != id) e,
  ]);
  await safetyRecordSync.removed(id);
}

/// 점검 기록을 서버(safety_records)에도 올린다(10-09 고도화 2번). 폰을 잃거나 바꿔도 남는다.
/// 개수 상한으로 폰에서 밀려난 옛 기록은 서버에 그대로 둔다(지운 것이 아니다).
final RecordSync safetyRecordSync = RecordSync(
  key: kSafetyRecordsKey,
  collection: 'safety_records',
  isValid: (j) => SafetyRecord.fromJson(j) != null,
);
