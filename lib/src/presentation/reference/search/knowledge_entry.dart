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

  /// 검색 낱말 가운데 이 항목에서 찾은 낱말 수와 전체 낱말 수.
  /// 모두 찾으면 [matched] == [total]. 모두 맞는 항목이 하나도 없을 때만 일부만 맞는 항목을 돌려준다.
  final int matched;
  final int total;

  /// 이 항목에서 찾은 낱말(화면에서 굵게 칠하고 맞는 줄을 고르는 데 쓴다, 다듬은 모양).
  final List<String> terms;
  const KnowledgeHit(
    this.entry,
    this.score, {
    this.matched = 0,
    this.total = 0,
    this.terms = const [],
  });

  /// 검색 낱말을 다 찾지 못하고 일부만 맞은 항목.
  bool get partial => matched < total;
}

/// 낱말 끝에 붙는 조사·말끝(긴 것부터). 낱말 그대로 못 찾을 때만 떼어 본다
/// ("절삭유가" → "절삭유", "진동이" → "진동", "나와요" → "나와"). 그대로 찾으면 떼지 않는다("온도"는 그대로).
const List<String> _kEndings = [
  '에서는', '으로는', '이에요', '했어요', '해서요', '해요', '어요', '아요', '에요', '예요', '네요', //
  '에서', '으로', '이요', '하고', '인데', '는데', '은데', '거나', '이나', '부터', '까지', //
  '은', '는', '이', '가', '을', '를', '에', '의', '도', '만', '로', '와', '과', '요', '고',
];

/// 현장에서 같은 뜻으로 쓰는 다른 말. 한 묶음 안의 말은 서로 바꿔 찾는다(모두 [normalizeForSearch] 모양).
/// 자료에 실제로 쓰인 말(누설·알람·메거·전동기 …)이 묶음마다 하나 이상 들어 있다.
const List<List<String>> kSearchSynonyms = [
  ['누설', '누출', '리크', 'leak', 'leakage', '샘', '새는', '새요', '새다', '샌다', '새어'],
  ['알람', '경보', 'alarm', 'alm', '에러', '오류', 'error', 'err', '고장코드'],
  ['메거', '메가', '메거테스트', '메가테스트', 'megger', '절연저항'],
  ['전동기', '모터', 'motor'],
  ['트립', 'trip', '떨어', '떨어짐', '떨어져', '내려감'],
  ['과열', '발열', '뜨거', '뜨거움', '뜨거워', '열남', '열나', 'overheat'],
  ['정렬', '센터링', '얼라인먼트', '얼라이먼트', 'alignment', 'centering'],
  ['swagelok', '스웨지락', '스와지락', '스웨즈락', '스웨즈로크'],
  ['진동', '떨림', '흔들', '흔들림', 'vibration'],
  ['소음', '소리', '이상음', '시끄러', 'noise'],
  ['누전', '지락', '누전차단기', 'elb', 'rcd', 'elcb'],
  ['차단기', '브레이커', 'breaker', 'mccb'],
  ['튜브', '튜빙', 'tube', 'tubing'],
  ['전선관', '컨듀잇', 'conduit'],
  ['접지', '어스', 'earth'],
];

final Map<String, List<String>> _synonymOf = {
  for (final g in kSearchSynonyms)
    for (final w in g) w: g,
};

/// 검색 낱말 하나를 찾을 때 쓰는 말들: 그대로 → 조사·말끝 뗀 것 → 같은 뜻 다른 말.
List<String> searchVariants(String token) {
  final out = <String>[token];
  for (final e in _kEndings) {
    if (token.length > e.length + 1 && token.endsWith(e)) {
      final s = token.substring(0, token.length - e.length);
      if (!out.contains(s)) out.add(s);
    }
  }
  for (final v in List.of(out)) {
    final g = _synonymOf[v];
    if (g == null) continue;
    for (final w in g) {
      if (!out.contains(w)) out.add(w);
    }
  }
  return out;
}

const List<String> _kInitials = [
  'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', //
  'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
];

/// 한글은 초성만, 나머지는 그대로(초성 검색용, [normalizeForSearch] 뒤에 쓴다).
String initialsForSearch(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    b.write(
      r >= 0xAC00 && r <= 0xD7A3
          ? _kInitials[(r - 0xAC00) ~/ 588]
          : String.fromCharCode(r),
    );
  }
  return b.toString();
}

bool _allInitials(String t) =>
    t.length >= 2 && t.runes.every((r) => r >= 0x3131 && r <= 0x314E);

/// 항목마다 한 번만 다듬어 둔다(검색어 한 글자마다 509개를 다시 다듬지 않게).
class _Prepared {
  _Prepared(KnowledgeEntry e)
    : title = normalizeForSearch(e.title),
      keys = normalizeForSearch(e.keywords.join(' ')),
      body = normalizeForSearch(e.lines.join(' ')),
      cat = normalizeForSearch(e.category);
  final String title, keys, body, cat;
  late final String titleInitials = initialsForSearch(title);
  late final String keysInitials = initialsForSearch(keys);
}

final Expando<_Prepared> _prepared = Expando<_Prepared>();
_Prepared _prep(KnowledgeEntry e) => _prepared[e] ??= _Prepared(e);

/// 낱말 하나가 항목에 맞는 점수(제목 3·찾기용 말 2·내용·분류 1, 못 찾으면 0)와 찾은 말.
(int, String?) _tokenScore(_Prepared p, String token, List<String> variants) {
  if (_allInitials(token)) {
    if (p.titleInitials.contains(token)) return (3, null);
    if (p.keysInitials.contains(token)) return (2, null);
    return (0, null);
  }
  // 같은 자리 안에서는 그대로 찾은 말이 먼저(뗀 말·다른 말은 그다음).
  for (final (field, score) in [(p.title, 3), (p.keys, 2)]) {
    for (final v in variants) {
      if (v.length >= 2 || v == token) {
        if (field.contains(v)) return (score, v);
      }
    }
  }
  for (final v in variants) {
    if (v.length >= 2 || v == token) {
      if (p.body.contains(v) || p.cat.contains(v)) return (1, v);
    }
  }
  return (0, null);
}

/// [query]의 낱말을 찾아 점수순으로 돌려준다.
/// - 낱말마다 그대로·조사 뗀 말·같은 뜻 다른 말·초성(ㅈㅅㅇ) 가운데 하나라도 맞으면 찾은 것으로 본다.
/// - 모든 낱말을 찾은 항목만 돌려준다. 그런 항목이 하나도 없으면 두 글자 이상 낱말을 하나 이상,
///   낱말의 절반 이상 찾은 항목을 "일부만 맞음"([KnowledgeHit.partial])으로 돌려준다(찾은 낱말 수가 많은 순).
/// - 문제해결 자료(priority 1)가 먼저, 그 안에서 점수(제목 3·찾기용 말 2·내용 1, 낱말마다), 같으면 원래 순서.
/// [category]를 주면 그 분류만. 검색어가 비면 빈 목록(분류만 고른 경우는 [category] 전체).
List<KnowledgeHit> searchKnowledge(
  List<KnowledgeEntry> all,
  String query, {
  String? category,
}) {
  final tokens = <String>[];
  for (final t in query.trim().split(RegExp(r'\s+'))) {
    final n = normalizeForSearch(t);
    if (n.isNotEmpty && !tokens.contains(n)) tokens.add(n);
  }
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
  final variants = [for (final t in tokens) searchVariants(t)];
  final full = <KnowledgeHit>[];
  final part = <KnowledgeHit>[];
  for (final e in pool) {
    final p = _prep(e);
    var score = 0;
    var matched = 0;
    var longMatched = 0;
    final terms = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      final (s, term) = _tokenScore(p, tokens[i], variants[i]);
      if (s == 0) continue;
      score += s;
      matched++;
      if (tokens[i].length >= 2) longMatched++;
      if (term != null && !terms.contains(term)) terms.add(term);
    }
    if (matched == 0) continue;
    final hit = KnowledgeHit(
      e,
      score,
      matched: matched,
      total: tokens.length,
      terms: terms,
    );
    if (matched == tokens.length) {
      full.add(hit);
    } else if (full.isEmpty && longMatched > 0 && matched * 2 >= tokens.length) {
      part.add(hit);
    }
  }
  final hits = full.isNotEmpty ? full : part;
  // 정렬은 안정적이어야 한다(점수가 같으면 원래 순서). 인덱스를 함께 써서 보장한다.
  final order = {for (var i = 0; i < pool.length; i++) pool[i].id: i};
  hits.sort((a, b) {
    var c = b.matched.compareTo(a.matched);
    if (c != 0) return c;
    c = b.entry.priority.compareTo(a.entry.priority);
    if (c != 0) return c;
    c = b.score.compareTo(a.score);
    return c != 0 ? c : order[a.entry.id]!.compareTo(order[b.entry.id]!);
  });
  return hits;
}

/// 항목 내용 가운데 찾은 낱말이 든 첫 줄(없으면 null). 목록 미리보기에 첫 두 줄 대신 쓴다.
String? matchingLine(KnowledgeEntry e, List<String> terms) {
  if (terms.isEmpty) return null;
  for (final l in e.lines) {
    final n = normalizeForSearch(l);
    if (terms.any(n.contains)) return l;
  }
  return null;
}

/// 분류 이름과 항목 수(항목이 있는 분류만, 처음 나온 순서).
List<(String, int)> knowledgeCategories(List<KnowledgeEntry> all) {
  final counts = <String, int>{};
  for (final e in all) {
    counts[e.category] = (counts[e.category] ?? 0) + 1;
  }
  return [for (final k in counts.entries) (k.key, k.value)];
}
