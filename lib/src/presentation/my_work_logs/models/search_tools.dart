import 'project_phase.dart';
import 'report_tools.dart' show reportDateOf;

// 🚀 통합 검색(일보·이슈 본문에서 단어 찾기).
// ───────────────────────── 통합 검색 ─────────────────────────
class SearchHit {
  final Map<String, dynamic> log;
  final String kind; // 일보 | 이슈
  final String title;
  final String snippet;
  final Map item; // 원본 일보/이슈 Map(바로 열기용)
  SearchHit(this.log, this.kind, this.title, this.snippet, this.item);
}

String _snippet(String text, String q) {
  final i = text.toLowerCase().indexOf(q.toLowerCase());
  if (i < 0) return text.length > 60 ? '${text.substring(0, 60)}…' : text;
  final s = (i - 20).clamp(0, text.length);
  final e = (i + q.length + 40).clamp(0, text.length);
  return '${s > 0 ? '…' : ''}${text.substring(s, e).replaceAll('\n', ' ')}${e < text.length ? '…' : ''}';
}

List<SearchHit> searchProjects(
  List<Map<String, dynamic>> logs,
  String query, {
  String? kind, // '일보' | '이슈' | null(전체)
  String? projectId,
  DateTime? from,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return [];
  final hits = <SearchHit>[];
  for (final log in logs) {
    if (projectId != null && log['id']?.toString() != projectId) continue;
    final name = log['name']?.toString() ?? '';
    for (final r in (log['daily_reports'] as List? ?? []).whereType<Map>()) {
      if (kind == '이슈') break;
      if (from != null && reportDateOf(r).isBefore(from)) continue;
      final wt = r['work_type'] is List
          ? (r['work_type'] as List).join(' ')
          : (r['work_type']?.toString() ?? '');
      final fields = [
        r['note'],
        r['materials_used'],
        r['next_day_plan'],
        r['as_built_reason'],
        wt,
      ].map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty);
      for (final f in fields) {
        if (f.toLowerCase().contains(q)) {
          hits.add(
            SearchHit(log, '일보', '$name · ${r['date']}', _snippet(f, q), r),
          );
          break;
        }
      }
    }
    for (final p in (log['punch_lists'] as List? ?? []).whereType<Map>()) {
      if (kind == '일보') break;
      if (from != null && p['created_at'] != null) {
        if (dayOnly(asDate(p['created_at'])).isBefore(from)) continue;
      }
      final f = [
        p['content'],
        p['location'],
      ].map((e) => e?.toString() ?? '').join(' ');
      if (f.toLowerCase().contains(q)) {
        hits.add(
          SearchHit(
            log,
            '이슈',
            '$name · ${p['location'] ?? ''}',
            _snippet(p['content']?.toString() ?? f, q),
            p,
          ),
        );
      }
    }
  }
  return hits;
}
