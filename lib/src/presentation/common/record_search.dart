// 홈 검색의 "기록에서 찾기": 프로젝트 이름·작업 일지·이슈 내용·자재 이름을 한 번에 찾는다.
// 계산만 하는 순수 함수라 화면과 따로 시험한다. 일지·이슈 찾기는 내 프로젝트 안 검색(searchProjects)을 그대로 쓴다.
import '../inventory/material_catalog.dart';
import '../my_work_logs/models/search_tools.dart';

/// 찾은 것 하나. [kind]는 프로젝트 | 작업 일지 | 이슈 | 자재.
class RecordResult {
  final String kind;
  final String title;
  final String subtitle;

  /// 프로젝트·일지·이슈일 때 열 프로젝트와 처음 보일 탭(0 개요, 2 이슈, 3 일지). 자재는 null.
  final String? projectId;
  final int tab;
  const RecordResult({
    required this.kind,
    required this.title,
    required this.subtitle,
    this.projectId,
    this.tab = 0,
  });
}

const int kRecordMaxProjects = 5;
const int kRecordMaxReports = 12;
const int kRecordMaxMaterials = 6;

String _norm(String s) => s.replaceAll(RegExp(r'\s+'), '').toLowerCase();

List<RecordResult> searchRecords(
  String query,
  List<Map<String, dynamic>> logs,
  List<CatalogItem> catalog,
) {
  final q = query.trim();
  if (q.isEmpty) return const [];
  final nq = _norm(q);
  final out = <RecordResult>[];

  // 프로젝트 이름
  var n = 0;
  for (final l in logs) {
    final name = l['name']?.toString() ?? '';
    if (name.isEmpty || !_norm(name).contains(nq)) continue;
    out.add(
      RecordResult(
        kind: '프로젝트',
        title: name,
        subtitle: '프로젝트',
        projectId: l['id']?.toString(),
        tab: 0,
      ),
    );
    if (++n >= kRecordMaxProjects) break;
  }

  // 작업 일지·이슈 내용(내 프로젝트 안 검색과 같은 규칙)
  for (final h in searchProjects(logs, q).take(kRecordMaxReports)) {
    out.add(
      RecordResult(
        kind: h.kind,
        // 제목에 프로젝트 이름과 날짜(일지) 또는 위치(이슈)가 들어 있다.
        title: h.title,
        subtitle: '${h.kind} · ${h.snippet}',
        projectId: h.log['id']?.toString(),
        tab: h.kind == '이슈' ? 2 : 3,
      ),
    );
  }

  // 자재 이름·규격
  var m = 0;
  for (final c in catalog) {
    if (!_norm('${c.name} ${c.spec}').contains(nq)) continue;
    out.add(
      RecordResult(
        kind: '자재',
        title: c.name,
        subtitle: [
          '자재',
          if (c.spec.isNotEmpty) c.spec,
          if (c.unit.isNotEmpty) c.unit,
        ].join(' · '),
      ),
    );
    if (++m >= kRecordMaxMaterials) break;
  }
  return out;
}
