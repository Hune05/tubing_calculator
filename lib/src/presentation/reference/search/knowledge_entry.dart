// 자료 통합 검색(10-03): 흩어진 현장 자료(장비 고장 조치, GD402 알람, 축 정렬, 루프 이상값 …)를
// 같은 모양의 항목으로 모아 한 곳에서 찾는다. 이 파일은 화면이 없는 모델과 검색 함수다.
library;

import 'package:flutter/widgets.dart';

/// 검색되는 자료 한 항목.
class KnowledgeEntry {
  /// 다른 항목과 겹치지 않는 번호.
  final String id;

  /// 분류 이름(검색 화면의 칩): '장비 고장 조치', '계기 알람·고장 코드' …
  final String category;

  /// 목록에 크게 보이는 제목.
  final String title;

  /// 내용 줄(원인·조치·단계 등). 한 줄이 한 항목.
  final List<String> lines;

  /// 찾기용 말(장비 이름, 코드, 영어 …). 화면에는 안 보이고 검색에만 쓴다.
  final List<String> keywords;

  /// 출처 화면 이름("장비 사용법" 등). 상세 창의 "원래 화면 열기" 단추에 쓴다.
  final String sourceLabel;

  /// 원래 화면을 여는 함수. 없으면 단추를 숨긴다.
  final void Function(BuildContext context)? open;

  /// 검색 결과에서 먼저 보일 정도(1이면 문제해결 자료: 고장 조치·알람 코드·증상). 기본 0.
  final int priority;

  const KnowledgeEntry({
    required this.id,
    required this.category,
    required this.title,
    this.lines = const [],
    this.keywords = const [],
    this.sourceLabel = '',
    this.open,
    this.priority = 0,
  });
}

/// 비교용으로 다듬는다: 소문자, 글자·숫자·한글만 남김("ALM.07"·"alm 07"·"ALM07"이 같아진다).
String normalizeForSearch(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^0-9a-z가-힣ㄱ-ㅎ]'), '');

/// 검색 결과 한 줄(항목과 점수).
class KnowledgeHit {
  final KnowledgeEntry entry;
  final int score;
  const KnowledgeHit(this.entry, this.score);
}

/// [query]의 모든 낱말이 들어 있는 항목을 점수순으로 돌려준다.
/// 문제해결 자료(priority 1)가 먼저, 그 안에서 제목 3점·찾기용 말 2점·내용 1점(낱말마다), 같으면 원래 순서.
/// [category]를 주면 그 분류만. 검색어가 비면 빈 목록(분류만 고른 경우는 [category] 전체).
List<KnowledgeHit> searchKnowledge(
  List<KnowledgeEntry> all,
  String query, {
  String? category,
}) {
  final tokens = [
    for (final t in query.trim().split(RegExp(r'\s+')))
      if (normalizeForSearch(t).isNotEmpty) normalizeForSearch(t),
  ];
  final pool = category == null
      ? all
      : [
          for (final e in all)
            if (e.category == category) e,
        ];
  if (tokens.isEmpty) {
    return category == null
        ? const []
        : [for (final e in pool) KnowledgeHit(e, 0)];
  }
  final hits = <KnowledgeHit>[];
  for (final e in pool) {
    final title = normalizeForSearch(e.title);
    final keys = normalizeForSearch(e.keywords.join(' '));
    final body = normalizeForSearch(e.lines.join(' '));
    final cat = normalizeForSearch(e.category);
    var score = 0;
    var ok = true;
    for (final t in tokens) {
      if (title.contains(t)) {
        score += 3;
      } else if (keys.contains(t)) {
        score += 2;
      } else if (body.contains(t) || cat.contains(t)) {
        score += 1;
      } else {
        ok = false;
        break;
      }
    }
    if (ok) hits.add(KnowledgeHit(e, score));
  }
  // 정렬은 안정적이어야 한다(점수가 같으면 원래 순서). 인덱스를 함께 써서 보장한다.
  final order = {for (var i = 0; i < pool.length; i++) pool[i].id: i};
  hits.sort((a, b) {
    var c = b.entry.priority.compareTo(a.entry.priority);
    if (c != 0) return c;
    c = b.score.compareTo(a.score);
    return c != 0 ? c : order[a.entry.id]!.compareTo(order[b.entry.id]!);
  });
  return hits;
}

/// 분류 이름과 항목 수(항목이 있는 분류만, 처음 나온 순서).
List<(String, int)> knowledgeCategories(List<KnowledgeEntry> all) {
  final counts = <String, int>{};
  for (final e in all) {
    counts[e.category] = (counts[e.category] ?? 0) + 1;
  }
  return [for (final k in counts.entries) (k.key, k.value)];
}
