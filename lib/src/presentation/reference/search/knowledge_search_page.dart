// 자료 검색(10-03): 장비 고장 조치·계기 알람 코드·루프 이상값·축 정렬 지침·현장 자료를 한 곳에서 찾는다.
// 증상·코드·장비 이름 어느 것으로 찾아도 되고, 고르면 내용을 바로 보여 준다.
import 'package:flutter/material.dart';

import '../../../core/theme/field_view.dart';
import '../page/reference_widgets.dart';
import 'knowledge_base.dart';
import 'knowledge_entry.dart';

class KnowledgeSearchPage extends StatefulWidget {
  const KnowledgeSearchPage({super.key, this.entries, this.initialQuery = ''});

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

  List<KnowledgeEntry> get _all => widget.entries ?? knowledgeBase();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _showDetail(KnowledgeEntry e) {
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
                SelectableText(
                  e.title,
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
                    child: SelectableText(
                      l,
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
                if (e.open != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('ks_open_source'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        e.open!(context);
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('원래 화면 열기'),
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
    final cats = knowledgeCategories(all);
    final q = _c.text;
    final searching = q.trim().isNotEmpty || _category != null;
    final hits = searching
        ? searchKnowledge(all, q, category: _category)
        : const <KnowledgeHit>[];

    Widget body;
    if (!searching) {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            '증상·코드·장비 이름으로 찾으십시오. 고장 조치, 계기 알람 코드, 루프 이상값, 축 정렬 지침, 현장 자료를 한 곳에서 찾을 수 있습니다.',
            style: TextStyle(fontSize: 14, color: refTextSub, height: 1.5),
          ),
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
      body = Center(
        key: const Key('ks_empty'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '찾는 자료가 없습니다.\n다른 낱말(증상, 코드, 장비 이름)로 다시 찾아 보십시오.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: refTextSub, height: 1.5),
          ),
        ),
      );
    } else {
      body = ListView.separated(
        key: const Key('ks_list'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: hits.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final e = hits[i].entry;
          final snippet = e.lines.take(2).join('\n');
          return Material(
            color: refWhite,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              key: Key('ks_hit_${e.id}'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showDetail(e),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.category,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: refTextSub,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      e.title,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: refTextMain,
                        height: 1.3,
                      ),
                    ),
                    if (snippet.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        snippet,
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
                    _chip(
                      '$name $n',
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
                    '${hits.length}건',
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
