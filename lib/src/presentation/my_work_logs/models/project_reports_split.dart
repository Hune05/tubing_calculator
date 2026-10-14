// 작업 일지를 프로젝트 문서에서 하위 모음(my_projects/{id}/daily_reports/{일지 id})으로 나눈다(10-14).
//
// 왜: 일지·이슈·일정이 프로젝트 문서 하나에 다 들어가, 1년 넘게 매일 쓰면 Firestore 문서 한도(1MiB)에
// 닿아 그 뒤로 저장이 실패할 수 있었다. 일지가 문서 크기의 대부분이라 일지만 한 건씩 문서로 뺀다.
//
// 화면 코드는 그대로다: 저장소(WorkProjectRepository)가 읽을 때 하위 모음을 붙여 예전처럼
// project['daily_reports'] 목록으로 주고, 저장할 때 다시 나눠 바뀐 일지만 쓴다. 이 파일은 그 셈만
// 한다(Firestore 없이 시험할 수 있게).
//
// 옮기기: 따로 돌리지 않는다. 읽을 때 문서 안 옛 목록(embedded)과 하위 모음을 아이디로 합치고,
// 다음 저장 때 본문에서 목록 칸을 빼고 일지는 하위 모음에 쓴다. 옛 빌드가 본문에 목록을 다시 적어도
// 합쳐 읽으므로 사라지지 않는다.
library;

import 'dart:convert';

import 'report_tools.dart';

/// 하위 모음 이름(본문 칸 이름과 같게 둔다).
const String kReportsSubcollection = 'daily_reports';

/// 일지 문서 아이디. 아이디에 '/'가 있으면 경로가 깨지므로 바꾼다(일지 Map의 'id'는 그대로 둔다).
String reportDocId(Map report) {
  final raw = (report['id'] ?? '').toString().trim();
  return raw.replaceAll('/', '_');
}

DateTime? _updatedAt(Map m) {
  final v = m['updatedAt'];
  if (v is String) return DateTime.tryParse(v);
  if (v is DateTime) return v;
  return null;
}

/// 문서 안 옛 목록([embedded])과 하위 모음([sub])을 아이디로 합친 일지 목록(최신 날짜가 앞).
/// 같은 아이디는 updatedAt이 늦은 쪽, 모르면 하위 모음 것. 지운 아이디([deleted])는 뺀다.
/// 아이디 없는 옛 일지는 그대로 둔다(저장 때 아이디가 붙는다).
List<Map<String, dynamic>> joinReports({
  Object? embedded,
  required Iterable<Map<String, dynamic>> sub,
  Iterable<String> deleted = const [],
}) {
  final gone = deleted.toSet();
  final byId = <String, Map<String, dynamic>>{};
  final noId = <Map<String, dynamic>>[];
  final order = <String, int>{};
  var n = 0;
  void put(Map<String, dynamic> m, {required bool fromSub}) {
    final id = (m['id'] ?? '').toString();
    if (id.isEmpty) {
      noId.add(m);
      return;
    }
    if (gone.contains(id)) return;
    order.putIfAbsent(id, () => n++);
    final have = byId[id];
    if (have == null) {
      byId[id] = m;
      return;
    }
    final a = _updatedAt(have), b = _updatedAt(m);
    if (a != null && b != null) {
      if (b.isAfter(a)) byId[id] = m;
    } else if (fromSub) {
      byId[id] = m;
    }
  }

  if (embedded is List) {
    for (final e in embedded) {
      if (e is Map) put(Map<String, dynamic>.from(e), fromSub: false);
    }
  }
  for (final s in sub) {
    put(Map<String, dynamic>.from(s), fromSub: true);
  }

  // (일지, 처음 나온 순서). 날짜·작성 시각이 같으면 처음 순서를 지킨다.
  final rows = <(Map<String, dynamic>, int)>[
    for (final e in byId.entries) (e.value, order[e.key]!),
    for (var i = 0; i < noId.length; i++) (noId[i], n + i),
  ];
  rows.sort((x, y) {
    final a = x.$1, b = y.$1;
    // 날짜가 늦은 것이 앞(예전 목록도 새 일지를 맨 앞에 넣었다).
    final d = reportDateOf(b).compareTo(reportDateOf(a));
    if (d != 0) return d;
    final wa = a['authoredAt']?.toString() ?? '';
    final wb = b['authoredAt']?.toString() ?? '';
    final w = wb.compareTo(wa);
    if (w != 0) return w;
    return x.$2.compareTo(y.$2);
  });
  return [for (final r in rows) r.$1];
}

/// 저장할 때 하위 모음에 쓸 것과 지울 것.
class ReportWritePlan {
  /// 문서 아이디 → 쓸 일지.
  final Map<String, Map<String, dynamic>> toSet;

  /// 지울 문서 아이디.
  final List<String> toDelete;
  const ReportWritePlan(this.toSet, this.toDelete);

  bool get isEmpty => toSet.isEmpty && toDelete.isEmpty;
}

/// 합친 일지 목록([merged])과 서버 하위 모음([serverSub], 문서 아이디 → 내용)을 견줘, 바뀐 일지와
/// 새 일지만 쓰고 목록에서 빠진 것은 지운다. [deleteMissing]이 false면 지우지 않는다(서버 것을 못
/// 읽었을 때처럼 무엇이 빠졌는지 확실하지 않을 때).
ReportWritePlan planReportWrites({
  required Iterable<Map<String, dynamic>> merged,
  required Map<String, Map<String, dynamic>> serverSub,
  bool deleteMissing = true,
}) {
  final toSet = <String, Map<String, dynamic>>{};
  final keep = <String>{};
  for (final r in merged) {
    final docId = reportDocId(r);
    if (docId.isEmpty) continue;
    keep.add(docId);
    final have = serverSub[docId];
    if (have == null || canonicalJson(have) != canonicalJson(r)) {
      toSet[docId] = r;
    }
  }
  final toDelete = deleteMissing
      ? [
          for (final id in serverSub.keys)
            if (!keep.contains(id)) id,
        ]
      : <String>[];
  return ReportWritePlan(toSet, toDelete);
}

/// 견주기용 글: 칸 순서를 맞추고 숫자는 1과 1.0을 같게 본다.
String canonicalJson(Object? v) => jsonEncode(_canon(v));

Object? _canon(Object? v) {
  if (v is Map) {
    final keys = v.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in keys) k: _canon(v[k])};
  }
  if (v is List) return [for (final e in v) _canon(e)];
  if (v is num) return v == v.roundToDouble() && v.isFinite ? v.toInt() : v;
  if (v == null || v is String || v is bool) return v;
  return v.toString();
}
