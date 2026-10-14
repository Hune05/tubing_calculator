// 이슈(펀치) 목록·상세가 같이 쓰는 셈(10-14 이슈 화면 개편).
// - 처리 기한: 검사일정에 연결했으면 그 날, 아니면 직접 정한 기한(dueDate).
// - 상태: 처리 완료 / 기한 초과 / 기한 임박(2일 안) / 미해결.
// - 정렬: 미해결이 먼저(기한 초과 → 긴급 → 기한 빠른 것 → 최근 등록), 처리 완료는 최근 처리 순.
// - 찾기: 내용·위치·유형·담당자·처리 메모.
library;

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

DateTime? issueDate(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  return DateTime.tryParse(v.toString());
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// 처리 기한: 연결한 검사일정 날짜가 먼저, 없으면 직접 정한 기한.
DateTime? issueDueOf(Map p, [List schedules = const []]) {
  final link = p['linkedScheduleId']?.toString();
  if (link != null && link.isNotEmpty) {
    for (final s in schedules) {
      if (s is Map && s['id']?.toString() == link) {
        final d = issueDate(s['dateTime']);
        if (d != null) return d;
      }
    }
  }
  return issueDate(p['dueDate']);
}

enum IssueState { done, overdue, dueSoon, open }

IssueState issueStateOf(Map p, {List schedules = const [], DateTime? now}) {
  if (p['is_completed'] == true) return IssueState.done;
  final due = issueDueOf(p, schedules);
  if (due == null) return IssueState.open;
  final left = _day(due).difference(_day(now ?? DateTime.now())).inDays;
  if (left < 0) return IssueState.overdue;
  if (left <= 2) return IssueState.dueSoon;
  return IssueState.open;
}

/// 기한 글: "기한 초과 3일" / "오늘까지" / "내일까지" / "2일 남음" / "10/20까지". 기한이 없으면 ''.
String issueDueLabel(Map p, {List schedules = const [], DateTime? now}) {
  final due = issueDueOf(p, schedules);
  if (due == null) return '';
  final left = _day(due).difference(_day(now ?? DateTime.now())).inDays;
  if (p['is_completed'] == true) return '기한 ${due.month}/${due.day}';
  if (left < 0) return '기한 초과 ${-left}일';
  if (left == 0) return '오늘까지';
  if (left == 1) return '내일까지';
  if (left <= 7) return '$left일 남음';
  return '${due.month}/${due.day}까지';
}

const Map<String, int> kIssuePriorityOrder = {'긴급': 0, '보통': 1, '여유': 2};

/// 목록 순서(설명은 파일 머리). 원본은 그대로 두고 새 목록을 돌려준다.
List<Map<String, dynamic>> sortIssues(
  Iterable<Map<String, dynamic>> list, {
  List schedules = const [],
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  int rank(Map p) => switch (issueStateOf(p, schedules: schedules, now: t)) {
    IssueState.overdue => 0,
    IssueState.dueSoon || IssueState.open => 1,
    IssueState.done => 2,
  };
  final out = [...list];
  out.sort((a, b) {
    final ra = rank(a), rb = rank(b);
    if (ra != rb) return ra.compareTo(rb);
    if (ra == 2) {
      final da = issueDate(a['resolved_at']), db = issueDate(b['resolved_at']);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    }
    final pa = kIssuePriorityOrder[a['priority']] ?? 1;
    final pb = kIssuePriorityOrder[b['priority']] ?? 1;
    if (pa != pb) return pa.compareTo(pb);
    final da = issueDueOf(a, schedules), db = issueDueOf(b, schedules);
    if (da != null || db != null) {
      if (da == null) return 1;
      if (db == null) return -1;
      final c = da.compareTo(db);
      if (c != 0) return c;
    }
    final ca = issueDate(a['created_at']), cb = issueDate(b['created_at']);
    if (ca == null && cb == null) return 0;
    if (ca == null) return 1;
    if (cb == null) return -1;
    return cb.compareTo(ca);
  });
  return out;
}

/// 찾는 말이 내용·위치·유형·담당자·처리 메모에 있는지(띄어쓰기·대소문자 무시).
bool issueMatches(Map p, String query) {
  final q = query.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  if (q.isEmpty) return true;
  final hay = [
    p['content'],
    p['location'],
    p['defect_type'],
    p['assignee'],
    p['resolution_note'],
  ].map((e) => (e ?? '').toString()).join(' ');
  return hay.replaceAll(RegExp(r'\s+'), '').toLowerCase().contains(q);
}

/// 등록할 때 찍은 사진(처리 전).
List<String> issueBeforePhotos(Map p) {
  final l = p['image_paths'];
  if (l is List && l.isNotEmpty) return [for (final e in l) e.toString()];
  final one = p['image_path'];
  return one == null ? const [] : [one.toString()];
}

/// 처리하며 찍은 사진(처리 후).
List<String> issueAfterPhotos(Map p) => [
  for (final e in (p['resolution_images'] as List?) ?? const []) e.toString(),
];

/// 위치 글(비었거나 "위치 모름"이면 '').
String issueLocation(Map p) {
  final l = (p['location'] ?? '').toString().trim();
  return l == '위치 모름' ? '' : l;
}
