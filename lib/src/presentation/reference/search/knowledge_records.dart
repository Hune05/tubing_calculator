// 자료 검색의 "내 기록에서 찾음"(10-07): 내 프로젝트 이름·작업 일지·이슈를 찾아 검색 항목 모양으로 돌려준다.
// 찾는 규칙은 홈 검색의 "기록에서 찾기"(record_search.dart)를 그대로 쓰고, 폰에 저장된 사본에서 찾으므로
// 통신이 없어도 된다. 자재 카탈로그는 내 기록이 아니라 뺀다.
library;

import 'package:flutter/material.dart';

import '../../../data/repositories/work_project_repository.dart';
import '../../common/record_search.dart';
import '../../my_work_logs/screens/work_log_main_screen.dart';
import '../../my_work_logs/widgets/work_theme.dart';
import 'knowledge_entry.dart';

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

/// 폰에 저장된 내 프로젝트 사본에서 찾는다. 못 읽으면 빈 목록.
Future<List<KnowledgeEntry>> searchMyRecords(String query) async {
  try {
    final logs = await WorkProjectRepository().fetchCachedProjects();
    return recordsToKnowledge(searchRecords(query, logs, const []));
  } catch (_) {
    return const [];
  }
}
