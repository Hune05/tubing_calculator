// 자료 검색(10-03): 장비 고장 조치·계기 알람 코드·루프 이상값·축 정렬 지침·현장 자료를 한 곳에서 찾는다.
// 증상·코드·장비 이름 어느 것으로 찾아도 되고, 고르면 내용을 바로 보여 준다.
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/field_view.dart';
import '../../../core/utils/ai_ask.dart';
import '../page/reference_widgets.dart';
import 'knowledge_base.dart';
import 'knowledge_entry.dart';

/// 내용 창의 "보내기" 글: 제목·내용 줄·출처(카톡 등으로 그대로 보낼 수 있게).
String knowledgeShareText(KnowledgeEntry e) => [
  '[${e.category}] ${e.title}',
  ...e.lines,
  if (e.sourceLabel.isNotEmpty) '(출처: 필드 헬퍼 ${e.sourceLabel})',
].join('\n');

/// 보내기 함수(시험에서 바꿔 끼운다).
typedef KnowledgeShare = Future<void> Function(String text);

Future<void> _shareText(String text) async {
  // ignore: deprecated_member_use
  await Share.share(text);
}

/// 최근 검색어 저장 칸(이 폰에만).
const String kKnowledgeRecentKey = 'knowledge_recent_v1';

/// 최근 검색어를 몇 개까지 남기는지.
const int kKnowledgeRecentMax = 8;

/// [text]에서 찾은 말([terms], 다듬은 모양)이 나온 자리를 굵게 칠한다.
/// 띄어쓰기·대소문자가 달라도("ALM.07" ↔ alm07) 글자 사이 공백·기호를 건너뛰며 맞춘다.
List<TextSpan> highlightSpans(String text, List<String> terms, TextStyle hi) {
  if (terms.isEmpty || text.isEmpty) return [TextSpan(text: text)];
  // 글자마다 다듬은 글자(없으면 건너뜀)와 원래 위치를 함께 둔다.
  final norm = StringBuffer();
  final pos = <int>[];
  for (var i = 0; i < text.length; i++) {
    final ch = normalizeForSearch(text[i]);
    if (ch.isEmpty) continue;
    norm.write(ch);
    pos.add(i);
  }
  final n = norm.toString();
  // 한 글자가 두 글자로 바뀌는 드문 글자(대소문자 변환)가 있으면 자리가 어긋나므로 칠하지 않는다.
  if (n.length != pos.length) return [TextSpan(text: text)];
  final marks = List<bool>.filled(text.length, false);
  for (final t in terms) {
    if (t.isEmpty) continue;
    var from = 0;
    while (true) {
      final at = n.indexOf(t, from);
      if (at < 0) break;
      for (var k = pos[at]; k <= pos[at + t.length - 1]; k++) {
        marks[k] = true;
      }
      from = at + t.length;
    }
  }
  final out = <TextSpan>[];
  var start = 0;
  for (var i = 1; i <= text.length; i++) {
    if (i == text.length || marks[i] != marks[start]) {
      out.add(
        TextSpan(text: text.substring(start, i), style: marks[start] ? hi : null),
      );
      start = i;
    }
  }
  return out;
}

class KnowledgeSearchPage extends StatefulWidget {
  const KnowledgeSearchPage({
    super.key,
    this.entries,
    this.initialQuery = '',
    this.askAi = callAiAsk,
    this.share = _shareText,
  });

  /// 내용 창 "보내기"(시험에서 바꿔 끼운다).
  final KnowledgeShare share;

  /// "AI에게 물어보기" 서버 호출(시험에서 바꿔 끼운다).
  final AiAskCall askAi;

  /// 시험에서 바꿔 끼운다. 비우면 앱의 모든 자료.
  final List<KnowledgeEntry>? entries;
  final String initialQuery;

  @override
  State<KnowledgeSearchPage> createState() => _KnowledgeSearchPageState();
}

class _KnowledgeSearchPageState extends State<KnowledgeSearchPage> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initialQuery,
  );
  String? _category;
  List<String> _recent = const [];

  List<KnowledgeEntry> get _all => widget.entries ?? knowledgeBase();

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    try {
      final p = await SharedPreferences.getInstance();
      final list = p.getStringList(kKnowledgeRecentKey) ?? const <String>[];
      if (mounted) setState(() => _recent = list);
    } catch (_) {
      // 못 읽어도 검색에는 지장이 없다.
    }
  }

  /// 검색어를 최근 검색어 맨 앞에 남긴다(같은 말은 하나만, 최대 [kKnowledgeRecentMax]개).
  /// 결과를 열어 보거나 검색 단추를 눌렀을 때만 남겨, 치다 만 글자는 쌓이지 않는다.
  Future<void> _remember(String q) async {
    final t = q.trim();
    if (t.length < 2) return;
    final next = [
      t,
      for (final r in _recent)
        if (r != t) r,
    ].take(kKnowledgeRecentMax).toList();
    setState(() => _recent = next);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(kKnowledgeRecentKey, next);
    } catch (_) {}
  }

  Future<void> _clearRecent() async {
    setState(() => _recent = const []);
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(kKnowledgeRecentKey);
    } catch (_) {}
  }

  /// 앱 자료에서 답을 못 찾았을 때 AI에게 묻는다. 답은 따로 표시한 시트에 보인다.
  void _askAi(String question) {
    final q = question.trim();
    if (q.length < 2) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: refWhite,
      builder: (_) => _AiAnswerSheet(question: q, askAi: widget.askAi),
    );
  }

  /// 검색 결과 아래(또는 결과가 없을 때)에 붙는 "AI에게 물어보기" 카드.
  Widget _askAiCard(String q, {required bool noHits}) {
    final tooLong = q.trim().length > kAiAskMaxChars;
    return Container(
      key: const Key('ks_ai_card'),
      margin: EdgeInsets.only(top: noHits ? 0 : 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBD7F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF2563EB)),
              const SizedBox(width: 6),
              Text(
                noHits ? '앱 자료에 없습니다' : '찾는 답이 없으면',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: refTextMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'AI에게 물어볼 수 있습니다. AI는 앱 자료가 아니라 자기가 아는 지식으로 답하므로 틀릴 수 있습니다. 질문 글만 전송됩니다.',
            style: TextStyle(fontSize: 13, color: refTextSub, height: 1.45),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('ks_ask_ai'),
              onPressed: tooLong ? null : () => _askAi(q),
              icon: const Icon(Icons.auto_awesome),
              label: Text(tooLong ? '질문이 너무 깁니다 (최대 $kAiAskMaxChars자)' : 'AI에게 물어보기'),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(KnowledgeEntry e, {List<String> terms = const []}) {
    _remember(_c.text);
    FocusManager.instance.primaryFocus?.unfocus();
    final hi = TextStyle(
      fontWeight: FontWeight.w900,
      backgroundColor: const Color(0xFFFFF1B8),
      color: refTextMain,
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: refWhite,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            key: const Key('ks_sheet'),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.category,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: refTextSub,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText.rich(
                  TextSpan(children: highlightSpans(e.title, terms, hi)),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: refTextMain,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                for (final l in e.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SelectableText.rich(
                      TextSpan(children: highlightSpans(l, terms, hi)),
                      style: TextStyle(
                        fontSize: 16,
                        color: refTextMain,
                        height: 1.5,
                      ),
                    ),
                  ),
                if (e.sourceLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '출처 화면: ${e.sourceLabel}',
                      style: TextStyle(fontSize: 13, color: refTextSub),
                    ),
                  ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('ks_share'),
                    onPressed: () => widget.share(knowledgeShareText(e)),
                    icon: const Icon(Icons.share),
                    label: const Text('보내기 (카톡·문자)'),
                  ),
                ),
                if (e.open != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('ks_open_source'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        e.open!(context);
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: Text(e.openLabel),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, Key key) =>
      Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          key: key,
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final cats = knowledgeCategories(all, order: kKnowledgeCategoryOrder);
    final q = _c.text;
    final searching = q.trim().isNotEmpty || _category != null;
    final hits = searching
        ? searchKnowledge(all, q, category: _category)
        : const <KnowledgeHit>[];
    // 검색어가 있으면 분류 칩에 그 분류의 결과 수를 보이고, 결과가 없는 분류는 숨긴다(고른 분류는 남김).
    final typed = q.trim().isNotEmpty;
    final hitCounts = <String, int>{};
    if (typed) {
      for (final h in searchKnowledge(all, q)) {
        hitCounts[h.entry.category] = (hitCounts[h.entry.category] ?? 0) + 1;
      }
    }
    final partial = hits.isNotEmpty && hits.first.partial;
    final hi = TextStyle(
      fontWeight: FontWeight.w900,
      color: refTextMain,
      backgroundColor: const Color(0xFFFFF1B8),
    );

    Widget body;
    if (!searching) {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            '증상·코드·장비 이름으로 찾으십시오. 장비 고장 조치, 계기 알람 코드, 루프 이상값, 축 정렬 지침, 전기 고장 진단, 현장 자료와 계산기 바로가기를 한 곳에서 찾을 수 있습니다. 리크·모터·메가처럼 현장 말이나 초성(ㅈㅅㅇ)으로 찾아도 됩니다.',
            style: TextStyle(fontSize: 14, color: refTextSub, height: 1.5),
          ),
          if (_recent.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '최근 검색어',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: refTextMain,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('ks_recent_clear'),
                  onPressed: _clearRecent,
                  child: const Text('모두 지우기'),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in _recent)
                  ActionChip(
                    key: Key('ks_recent_$r'),
                    avatar: const Icon(Icons.history, size: 18),
                    label: Text(r),
                    onPressed: () => setState(() => _c.text = r),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Text(
            '자주 찾는 말',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: refTextMain,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in kKnowledgeSuggestions)
                ActionChip(
                  key: Key('ks_sug_$s'),
                  label: Text(s),
                  onPressed: () => setState(() => _c.text = s),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '들어 있는 자료 (${all.length}건)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: refTextMain,
            ),
          ),
          const SizedBox(height: 6),
          for (final (name, n) in cats)
            ListTile(
              key: Key('ks_catrow_$name'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(name, style: TextStyle(color: refTextMain)),
              trailing: Text('$n건', style: TextStyle(color: refTextSub)),
              onTap: () => setState(() => _category = name),
            ),
        ],
      );
    } else if (hits.isEmpty) {
      body = ListView(
        key: const Key('ks_empty'),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Text(
            '찾는 자료가 없습니다.\n다른 낱말(증상, 코드, 장비 이름)로 다시 찾아 보십시오.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: refTextSub, height: 1.5),
          ),
          if (q.trim().length >= 2) ...[
            const SizedBox(height: 18),
            _askAiCard(q, noHits: true),
          ],
        ],
      );
    } else {
      body = ListView.separated(
        key: const Key('ks_list'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: hits.length + (q.trim().length >= 2 ? 1 : 0) + (partial ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, idx) {
          if (partial && idx == 0) {
            return Container(
              key: const Key('ks_partial'),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '검색어를 모두 담은 자료가 없어, 일부 낱말만 맞는 자료를 보여 드립니다. 낱말을 줄이거나 바꿔 찾아 보십시오.',
                style: TextStyle(fontSize: 13.5, color: refTextMain, height: 1.45),
              ),
            );
          }
          final i = partial ? idx - 1 : idx;
          if (i == hits.length) return _askAiCard(q, noHits: false);
          final hit = hits[i];
          final e = hit.entry;
          // 찾은 말이 든 줄을 먼저 보인다(없으면 첫 두 줄).
          final snippet =
              matchingLine(e, hit.terms) ?? e.lines.take(2).join('\n');
          return Material(
            color: refWhite,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              key: Key('ks_hit_${e.id}'),
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                if (e.direct && e.open != null) {
                  // 계산기 바로가기는 내용 창 없이 곧바로 연다.
                  _remember(_c.text);
                  FocusManager.instance.primaryFocus?.unfocus();
                  e.open!(context);
                } else {
                  _showDetail(e, terms: hit.terms);
                }
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.direct ? '${e.category} · 누르면 바로 열림' : e.category,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: refTextSub,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text.rich(
                      TextSpan(children: highlightSpans(e.title, hit.terms, hi)),
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: refTextMain,
                        height: 1.3,
                      ),
                    ),
                    if (snippet.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(children: highlightSpans(snippet, hit.terms, hi)),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: refTextSub,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return FieldViewTheme(
      child: Scaffold(
        backgroundColor: refBg,
        appBar: AppBar(
          backgroundColor: refWhite,
          elevation: 0,
          iconTheme: IconThemeData(color: refTextMain),
          title: Text(
            '자료 검색',
            style: TextStyle(
              color: refTextMain,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: TextField(
                key: const Key('ks_field'),
                controller: _c,
                autofocus: widget.initialQuery.isEmpty,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                onSubmitted: (v) {
                  _remember(v);
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                decoration: InputDecoration(
                  hintText: '증상·코드·장비 이름 (예: ALM.07, 나사, 절삭유)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: q.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('ks_clear'),
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _c.clear()),
                        ),
                  filled: true,
                  fillColor: refWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _chip(
                    '전체',
                    _category == null,
                    () => setState(() => _category = null),
                    const Key('ks_cat_all'),
                  ),
                  for (final (name, n) in cats)
                    if (!typed || (hitCounts[name] ?? 0) > 0 || _category == name)
                    _chip(
                      typed ? '$name ${hitCounts[name] ?? 0}' : '$name $n',
                      _category == name,
                      () => setState(
                        () => _category = _category == name ? null : name,
                      ),
                      Key('ks_cat_$name'),
                    ),
                ],
              ),
            ),
            if (searching && hits.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 2),
                  child: Text(
                    partial ? '${hits.length}건 (일부만 맞음)' : '${hits.length}건',
                    key: const Key('ks_count'),
                    style: TextStyle(fontSize: 13, color: refTextSub),
                  ),
                ),
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// AI 답 시트: 보내는 중 → 답(또는 실패). 위에 늘 "AI 답변·앱 자료 아님"을 표시하고,
/// 안전과 관계된 질문이면 확인 경고를 더 크게 붙인다.
class _AiAnswerSheet extends StatefulWidget {
  const _AiAnswerSheet({required this.question, required this.askAi});

  final String question;
  final AiAskCall askAi;

  @override
  State<_AiAnswerSheet> createState() => _AiAnswerSheetState();
}

class _AiAnswerSheetState extends State<_AiAnswerSheet> {
  late Future<AiAskResult> _future = widget.askAi(widget.question);

  Widget _banner(String text, Color bg, Color fg, IconData icon, Key key) =>
      Container(
        key: key,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final safety = isSafetySensitive(widget.question);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          key: const Key('ks_ai_sheet'),
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _banner(
                'AI 답변입니다. 앱 자료가 아니라 AI가 아는 지식이므로 틀릴 수 있습니다.',
                const Color(0xFFEAF2FF),
                const Color(0xFF1D4ED8),
                Icons.auto_awesome,
                const Key('ks_ai_banner'),
              ),
              if (safety)
                _banner(
                  '압력·전기·가스 등 안전과 관계된 질문입니다. 이 답만 믿고 작업하지 말고 설명서·절차서·안전 담당자에게 꼭 확인하십시오.',
                  const Color(0xFFFEF2F2),
                  const Color(0xFFB91C1C),
                  Icons.priority_high,
                  const Key('ks_ai_safety'),
                ),
              Text(
                '질문',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: refTextSub),
              ),
              const SizedBox(height: 2),
              SelectableText(
                widget.question,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: refTextMain, height: 1.4),
              ),
              const SizedBox(height: 14),
              FutureBuilder<AiAskResult>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return Padding(
                      key: const Key('ks_ai_loading'),
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          const SizedBox(width: 12),
                          Text('AI가 답하는 중입니다…', style: TextStyle(color: refTextSub)),
                        ],
                      ),
                    );
                  }
                  final res = snap.data ?? const AiAskResult.fail('AI가 처리하지 못했습니다');
                  if (!res.ok) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          res.error ?? 'AI가 처리하지 못했습니다',
                          key: const Key('ks_ai_error'),
                          style: TextStyle(fontSize: 15, color: refTextMain, height: 1.5),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          key: const Key('ks_ai_retry'),
                          onPressed: () {
                            // setState 안에서 Future를 돌려주면 안 되므로 먼저 만들어 둔다.
                            final next = widget.askAi(widget.question);
                            setState(() {
                              _future = next;
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('다시 묻기'),
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI 답변',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: refTextSub),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        res.text!,
                        key: const Key('ks_ai_answer'),
                        style: TextStyle(fontSize: 16, color: refTextMain, height: 1.55),
                      ),
                      if (res.remaining != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            '오늘 남은 횟수 ${res.remaining}번',
                            key: const Key('ks_ai_remaining'),
                            style: TextStyle(fontSize: 12.5, color: refTextSub),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
