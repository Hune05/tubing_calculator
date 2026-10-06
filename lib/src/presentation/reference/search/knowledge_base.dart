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
    ),
];

List<KnowledgeEntry>? _cache;

/// 모든 검색 항목. 한 번 만들어 두고 다시 쓴다.
List<KnowledgeEntry> knowledgeBase() => _cache ??= [
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
