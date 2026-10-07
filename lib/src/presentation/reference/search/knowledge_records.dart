// 자료 검색의 "내 기록에서 찾음"(10-07): 내 프로젝트 이름·작업 일지·이슈, 압력시험 기록, 장비 관리 대장을
// 찾아 검색 항목 모양으로 돌려준다. 프로젝트 쪽 규칙은 홈 검색의 "기록에서 찾기"(record_search.dart)를
// 그대로 쓰고, 모두 폰에 저장된 사본에서 찾으므로 통신이 없어도 된다. 자재 카탈로그는 내 기록이 아니라 뺀다.
library;

import 'package:flutter/material.dart';

import '../../../data/repositories/work_project_repository.dart';
import '../../common/record_search.dart';
import '../../equipment/equipment_model.dart';
import '../../equipment/equipment_pages.dart';
import '../../equipment/equipment_store.dart';
import '../../my_work_logs/screens/work_log_main_screen.dart';
import '../../my_work_logs/widgets/work_theme.dart';
import '../../pressure_test/pressure_units.dart';
import '../../pressure_test/test_record.dart';
import '../../pressure_test/test_record_pdf.dart';
import 'knowledge_entry.dart';

/// 한 종류에서 찾을 최대 건수. 화면에는 몇 건만 보이고 "더 보기"로 펼친다(knowledge_search_page).
const int kRecordMaxPt = 30;
const int kRecordMaxEquip = 30;

/// 띄어쓰기·대소문자·줄표 같은 기호는 무시한다(GN101로 쳐도 GN-101이 나오게).
String _norm(String s) => s.replaceAll(RegExp(r'[\s\-_./·,()]+'), '').toLowerCase();

/// 찾은 기록 → 검색 항목(누르면 그 프로젝트의 그 탭이 곧바로 열린다).
List<KnowledgeEntry> recordsToKnowledge(List<RecordResult> results) => [
  for (final (i, r) in results.indexed)
    if (r.projectId != null)
      KnowledgeEntry(
        id: 'rec.$i.${r.projectId}',
        category: '내 기록 · ${r.kind}',
        title: r.title,
        lines: [r.subtitle],
        sourceLabel: '내 프로젝트',
        open: (c) => Navigator.push(
          c,
          WorkRoute<void>(
            builder: (_) => WorkLogMainScreen(
              initialProjectId: r.projectId,
              initialTab: r.tab,
            ),
          ),
        ),
        direct: true,
      ),
];

/// 압력시험 기록: 라인 번호·시험 번호·현장·계통·P&ID·구간·시험자·메모로 찾는다.
/// 누르면 내용 창(시험일·판정·압력)이 뜨고 "기록서 보기"로 기록서를 연다.
List<KnowledgeEntry> ptRecordsToKnowledge(String query, List<PtRecord> list) {
  final nq = _norm(query);
  if (nq.isEmpty) return const [];
  final out = <KnowledgeEntry>[];
  for (final r in list) {
    final hay = _norm(
      [r.line, r.testNo, r.site, r.system, r.pid, r.section, r.tester, r.memo].join(' '),
    );
    if (!hay.contains(nq)) continue;
    final kpa = r.testKpa;
    out.add(
      KnowledgeEntry(
        id: 'pt.${r.id}',
        category: '내 기록 · 압력시험',
        title: r.line.isEmpty ? '(라인 번호 없음)' : r.line,
        lines: [
          [
            ptDay(r.date),
            ptVerdictText(r.verdict.pass),
            if (kpa != null) '시험압력 ${ptPressure(kpa, r.unit)}',
          ].join(' · '),
          if (r.testNo.isNotEmpty) '시험 번호: ${r.testNo}',
          if (r.site.isNotEmpty || r.system.isNotEmpty)
            '현장·계통: ${[r.site, r.system].where((s) => s.isNotEmpty).join(' · ')}',
          if (r.section.isNotEmpty) '구간: ${r.section}',
          if (r.tester.isNotEmpty) '시험자: ${r.tester}',
          if (r.memo.isNotEmpty) '메모: ${r.memo}',
        ],
        sourceLabel: '압력시험 기록',
        open: (c) => openPtRecordPdf(c, r),
        openLabel: '기록서 보기',
      ),
    );
    if (out.length >= kRecordMaxPt) break;
  }
  return out;
}

/// 장비 관리 대장: 이름·관리번호·제조사·모델·일련번호·보관 위치·가진 사람·메모로 찾는다.
/// 누르면 그 장비 화면이 곧바로 열린다.
List<KnowledgeEntry> equipmentToKnowledge(String query, List<Equipment> list) {
  final nq = _norm(query);
  if (nq.isEmpty) return const [];
  final out = <KnowledgeEntry>[];
  for (final e in list) {
    final hay = _norm(
      [
        e.name,
        e.assetNo,
        e.maker,
        e.model,
        e.serial,
        e.location,
        e.holder,
        e.holderProject,
        e.note,
      ].join(' '),
    );
    if (!hay.contains(nq)) continue;
    out.add(
      KnowledgeEntry(
        id: 'eq.${e.id}',
        category: '내 기록 · 장비',
        title: e.name,
        lines: [
          [
            e.category.label,
            if (e.assetNo.isNotEmpty) e.assetNo,
            if (e.holder.isNotEmpty) '${e.holder} 사용 중' else if (e.location.isNotEmpty) e.location,
          ].join(' · '),
        ],
        sourceLabel: '장비 관리 대장',
        open: (c) => Navigator.push(
          c,
          MaterialPageRoute<void>(builder: (_) => EquipmentDetailPage(id: e.id)),
        ),
        direct: true,
      ),
    );
    if (out.length >= kRecordMaxEquip) break;
  }
  return out;
}

/// 폰에 있는 내 기록(프로젝트·압력시험·장비). 못 읽은 것은 빈 목록.
typedef MyRecords = (List<Map<String, dynamic>>, List<PtRecord>, List<Equipment>);

Future<MyRecords> loadMyRecords() async {
  Future<List<T>> safe<T>(Future<List<T>> Function() f) async {
    try {
      return await f();
    } catch (_) {
      return <T>[];
    }
  }

  final r = await Future.wait<Object>([
    safe(() => WorkProjectRepository().fetchCachedProjects()),
    safe(PtRecordStore.load),
    safe(EquipmentStore.load),
  ]);
  return (
    r[0] as List<Map<String, dynamic>>,
    r[1] as List<PtRecord>,
    r[2] as List<Equipment>,
  );
}

/// 읽어 둔 내 기록에서 찾는다(프로젝트 → 압력시험 → 장비 순).
List<KnowledgeEntry> searchInMyRecords(String query, MyRecords data) => [
  ...recordsToKnowledge(searchRecords(query, data.$1, const [])),
  ...ptRecordsToKnowledge(query, data.$2),
  ...equipmentToKnowledge(query, data.$3),
];

/// 자료 검색 화면 하나에 줄 찾기 함수. 내 기록은 처음 찾을 때 한 번만 읽고, 그 화면을 쓰는 동안
/// 글자를 칠 때마다 다시 읽지 않는다(기록이 쌓여도 검색 칸이 버벅이지 않게).
Future<List<KnowledgeEntry>> Function(String query) myRecordSearcher({
  Future<MyRecords> Function() load = loadMyRecords,
}) {
  Future<MyRecords>? cache;
  return (q) async => searchInMyRecords(q, await (cache ??= load()));
}
