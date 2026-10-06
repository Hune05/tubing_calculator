// 자료 통합 검색의 자료 모음: 여러 화면에 흩어진 현장 자료를 한 목록으로 모은다.
// 각 자료는 원래 화면의 데이터를 그대로 읽어 오므로 화면 내용과 검색 내용이 어긋나지 않는다.
library;

import 'package:flutter/material.dart';

import '../../alignment/alignment_guide_data.dart';
import '../../instrument/gd402_guide_page.dart';
import '../../instrument/meter_loop_guide_page.dart';
import '../page/ref_machine_tab.dart';
import '../page/reference_search_index.dart';
import '../page/tube_reference_page.dart';
import 'knowledge_electrical.dart';
import 'knowledge_electrical_general.dart';
import 'knowledge_entry.dart';
import 'knowledge_pressure.dart';
import 'knowledge_signal.dart';
import 'knowledge_tools.dart';

/// 현장 자료 화면의 카드 제목 색인을 검색 항목으로(고르면 그 탭이 열린다).
List<KnowledgeEntry> fieldReferenceKnowledge() => [
  for (var i = 0; i < refSearchIndex.length; i++)
    KnowledgeEntry(
      id: 'ref.$i',
      category: '현장 자료',
      title: refSearchIndex[i].title,
      lines: ['현장 자료 · ${refTabNames[refSearchIndex[i].tab]} 탭에 있습니다.'],
      keywords: [
        ...refSearchIndex[i].keywords,
        refTabNames[refSearchIndex[i].tab],
      ],
      sourceLabel: '현장 자료 · ${refTabNames[refSearchIndex[i].tab]}',
      open: (c) => Navigator.push(
        c,
        MaterialPageRoute<void>(
          builder: (_) => TubeReferencePage(initialTab: refSearchIndex[i].tab),
        ),
      ),
      // 카드 제목 색인이라 내용 창에 보일 내용이 없다. 누르면 그 탭을 곧바로 연다.
      direct: true,
      openLabel: '현장 자료 열기',
    ),
];

List<KnowledgeEntry>? _cache;

/// 모든 검색 항목. 한 번 만들어 두고 다시 쓴다.
List<KnowledgeEntry> knowledgeBase() => _cache ??= mergeSmallCategories([
  ...equipmentKnowledge(),
  ...gd402Knowledge(),
  ...loopKnowledge(),
  ...alignmentKnowledge(),
  ...fieldReferenceKnowledge(),
  ...electricalKnowledge(),
  ...electricalGeneralKnowledge(),
  ...pressureKnowledge(),
  ...signalKnowledge(),
  ...diagnosisKnowledge(),
  ...toolKnowledge(),
]);

/// 장비 사용법에서 온 분류 가운데 항목이 [kSmallCategoryMax]개 이하인 것("장비 펜스 직각" 1건 같은 것)은
/// "[kEquipmentMiscCategory]" 하나로 묶는다. 원래 분류 이름은 찾기용 말로 남아 그 이름으로도 찾아진다.
List<KnowledgeEntry> mergeSmallCategories(List<KnowledgeEntry> all) {
  final counts = <String, int>{};
  for (final e in all) {
    counts[e.category] = (counts[e.category] ?? 0) + 1;
  }
  bool small(String c) =>
      c.startsWith('장비 ') && (counts[c] ?? 0) <= kSmallCategoryMax;
  return [
    for (final e in all)
      small(e.category) ? e.withCategory(kEquipmentMiscCategory) : e,
  ];
}

const int kSmallCategoryMax = 6;
const String kEquipmentMiscCategory = '장비 사용 요령';

/// 분류를 보여 주는 순서: 급할 때 찾는 고장·알람·진단 자료를 먼저.
const List<String> kKnowledgeCategoryOrder = [
  '장비 고장 조치',
  '계기 알람·고장 코드',
  '계기 신호 이상',
  '전기 고장 진단',
  '압력시험 누설',
  '접지·전동기 점검',
  '전기 일반 기준',
  '축 정렬 지침',
  '계산기 바로가기',
  '장비 안전 수칙',
  '장비 점검·정비',
  '장비 작업 순서',
  '장비 사용 요령',
];

/// 시험에서 쓴다: 모아 둔 목록을 지운다.
void resetKnowledgeBaseCache() => _cache = null;

/// 검색 첫 화면에 보여 줄 자주 찾는 말.
const List<String> kKnowledgeSuggestions = [
  'ALM.07',
  '0 mA',
  '나사',
  '절삭유',
  '진동',
  '튜브 주름',
  '차단기 트립',
  '전압강하',
];
