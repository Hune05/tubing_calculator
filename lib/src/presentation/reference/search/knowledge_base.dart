// 자료 통합 검색의 자료 모음: 여러 화면에 흩어진 현장 자료를 한 목록으로 모은다.
// 각 자료는 원래 화면의 데이터를 그대로 읽어 오므로 화면 내용과 검색 내용이 어긋나지 않는다.
library;

import 'package:flutter/material.dart';

import '../../alignment/alignment_guide_data.dart';
import '../../instrument/gd402_guide_page.dart';
import '../../instrument/meter_loop_guide_page.dart';
import '../page/ref_machine_tab.dart';
import '../page/ref_card_text.g.dart';
import '../page/reference_search_index.dart';
import '../page/tube_reference_page.dart';
import 'knowledge_electrical.dart';
import 'knowledge_electrical_general.dart';
import 'knowledge_entry.dart';
import 'knowledge_pressure.dart';
import 'knowledge_signal.dart';
import 'knowledge_tools.dart';

/// 카드 제목 앞 번호("3. ")를 뗀다(색인 표 제목과 맞추려고).
String _plainCardTitle(String t) => t.replaceFirst(RegExp(r'^\d+\.\s*'), '');

void _openRefTab(BuildContext c, int tab) => Navigator.push(
  c,
  MaterialPageRoute<void>(builder: (_) => TubeReferencePage(initialTab: tab)),
);

/// 현장 자료 카드를 검색 항목으로. 카드 본문은 ref_card_text.g.dart(현장 자료 탭을 그려 모은 글)에서,
/// 찾기용 말은 색인 표(reference_search_index.dart)에서 가져온다. 고르면 내용을 보이고 그 탭을 열 수 있다.
/// 본문이 없는 색인 항목(단위 환산 탭 등)은 전처럼 누르면 그 탭이 곧바로 열린다.
List<KnowledgeEntry> fieldReferenceKnowledge() {
  final out = <KnowledgeEntry>[];
  // 색인 표 항목마다 같은 탭의 카드 하나를 고른다: 제목이 같으면 그 카드, 아니면 색인 제목에
  // 카드 제목이 들어 있는 카드 가운데 제목이 가장 긴 것("앵글 이론 중량표" → "앵글", "부등변앵글"이 있으면 그쪽).
  final cardOf = <int, int>{};
  for (var i = 0; i < refSearchIndex.length; i++) {
    final r = refSearchIndex[i];
    final rt = normalizeForSearch(_plainCardTitle(r.title));
    int? best;
    var bestLen = -1;
    for (var n = 0; n < kRefCardText.length; n++) {
      final (tab, rawTitle, _) = kRefCardText[n];
      if (tab != r.tab) continue;
      final ct = normalizeForSearch(_plainCardTitle(rawTitle));
      if (ct.isEmpty) continue;
      final len = ct == rt ? 1 << 20 : (rt.contains(ct) ? ct.length : -1);
      if (len > bestLen) {
        best = n;
        bestLen = len;
      }
    }
    if (best != null) cardOf[i] = best;
  }
  for (var n = 0; n < kRefCardText.length; n++) {
    final (tab, rawTitle, lines) = kRefCardText[n];
    final title = _plainCardTitle(rawTitle);
    final keys = <String>[refTabNames[tab]];
    for (final e in cardOf.entries) {
      if (e.value != n) continue;
      final r = refSearchIndex[e.key];
      keys
        ..add(r.title)
        ..addAll(r.keywords);
    }
    out.add(
      KnowledgeEntry(
        id: 'refcard.$tab.$n',
        category: '현장 자료',
        title: '${refTabNames[tab]}: $title',
        lines: lines.isEmpty ? ['현장 자료 · ${refTabNames[tab]} 탭에 있습니다.'] : lines,
        keywords: keys,
        sourceLabel: '현장 자료 · ${refTabNames[tab]}',
        open: (c) => _openRefTab(c, tab),
        openLabel: '현장 자료 열기',
      ),
    );
  }
  for (var i = 0; i < refSearchIndex.length; i++) {
    if (cardOf.containsKey(i)) continue;
    final r = refSearchIndex[i];
    out.add(
      KnowledgeEntry(
        id: 'ref.$i',
        category: '현장 자료',
        title: r.title,
        lines: ['현장 자료 · ${refTabNames[r.tab]} 탭에 있습니다.'],
        keywords: [...r.keywords, refTabNames[r.tab]],
        sourceLabel: '현장 자료 · ${refTabNames[r.tab]}',
        open: (c) => _openRefTab(c, r.tab),
        // 본문이 없는 색인이라 내용 창에 보일 것이 없다. 누르면 그 탭을 곧바로 연다.
        direct: true,
        openLabel: '현장 자료 열기',
      ),
    );
  }
  return out;
}

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
