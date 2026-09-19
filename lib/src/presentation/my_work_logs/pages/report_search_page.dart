import 'package:flutter/material.dart';

import '../models/report_tools.dart';
import '../models/photo_store.dart';
import '../widgets/photo_detail_modal.dart' show PhotoDetailModal;
import 'daily_report_page.dart'
    show tossBlue, tossText, tossSubText, tossInputBg, pureWhite;

// 🚀 [일보/이슈 통합 검색] 모든 프로젝트의 작업 내역·자재·계획·도면반영 사유·이슈
// 내용에서 단어를 찾는다. 결과를 누르면 그 프로젝트의 일지(또는 이슈) 탭이 열린다.
class ReportSearchPage extends StatefulWidget {
  final List<Map<String, dynamic>> logs;
  final void Function(SearchHit hit) onOpen;

  const ReportSearchPage({super.key, required this.logs, required this.onOpen});

  @override
  State<ReportSearchPage> createState() => _ReportSearchPageState();
}

class _ReportSearchPageState extends State<ReportSearchPage> {
  final _ctrl = TextEditingController();
  List<SearchHit> _hits = [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6),
      appBar: AppBar(
        backgroundColor: pureWhite,
        foregroundColor: tossText,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: "일보·이슈 검색 (예: 용접, 유니온)",
            border: InputBorder.none,
          ),
          onChanged: (v) =>
              setState(() => _hits = searchProjects(widget.logs, v)),
        ),
      ),
      body: _ctrl.text.trim().isEmpty
          ? const Center(
              child: Text(
                "찾고 싶은 단어를 입력하세요.",
                style: TextStyle(color: tossSubText),
              ),
            )
          : _hits.isEmpty
          ? const Center(
              child: Text("검색 결과가 없습니다.", style: TextStyle(color: tossSubText)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _hits.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final h = _hits[i];
                return Material(
                  color: pureWhite,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => widget.onOpen(h),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (h.kind == '이슈' ? Colors.red : tossBlue)
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  h.kind,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: h.kind == '이슈'
                                        ? Colors.red
                                        : tossBlue,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  h.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: tossText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            h.snippet,
                            style: const TextStyle(
                              fontSize: 13,
                              color: tossSubText,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// 🚀 [사진 모아보기] 프로젝트 일보의 모든 사진을 태그(작업 전/중/후 …)별로 본다.
class ProjectPhotosPage extends StatefulWidget {
  final Map<String, dynamic> log;
  const ProjectPhotosPage({super.key, required this.log});

  @override
  State<ProjectPhotosPage> createState() => _ProjectPhotosPageState();
}

class _PhotoItem {
  final String path;
  final String tag;
  final String date;
  _PhotoItem(this.path, this.tag, this.date);
}

class _ProjectPhotosPageState extends State<ProjectPhotosPage> {
  String? _filter;

  List<_PhotoItem> get _all {
    final out = <_PhotoItem>[];
    for (final r
        in (widget.log['daily_reports'] as List? ?? []).whereType<Map>()) {
      final tags = Map<String, dynamic>.from((r['image_tags'] as Map?) ?? {});
      for (final p in (r['image_paths'] as List? ?? [])) {
        out.add(
          _PhotoItem(
            p.toString(),
            tags[p.toString()]?.toString() ?? '미분류',
            r['date']?.toString() ?? '',
          ),
        );
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final tagsPresent = <String>{for (final i in all) i.tag};
    final shown = _filter == null
        ? all
        : all.where((i) => i.tag == _filter).toList();
    final paths = shown.map((e) => e.path).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6),
      appBar: AppBar(
        backgroundColor: pureWhite,
        foregroundColor: tossText,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          "사진 모아보기 (${all.length})",
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: all.isEmpty
          ? const Center(
              child: Text(
                "일보에 첨부된 사진이 없습니다.",
                style: TextStyle(color: tossSubText),
              ),
            )
          : Column(
              children: [
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    children: [
                      for (final t in [null, ...kPhotoTags, '미분류'])
                        if (t == null || tagsPresent.contains(t))
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(t ?? '전체'),
                              selected: _filter == t,
                              showCheckmark: false,
                              selectedColor: tossBlue,
                              backgroundColor: tossInputBg,
                              side: BorderSide.none,
                              labelStyle: TextStyle(
                                color: _filter == t ? pureWhite : tossSubText,
                                fontWeight: FontWeight.w700,
                              ),
                              onSelected: (_) => setState(() => _filter = t),
                            ),
                          ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                        ),
                    itemCount: shown.length,
                    itemBuilder: (_, i) {
                      final it = shown[i];
                      return GestureDetector(
                        onTap: () => PhotoDetailModal.show(
                          context: context,
                          title: "${it.date} · ${it.tag}",
                          content: "",
                          imagePaths: paths,
                          initialIndex: i,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              PhotoImage(it.path),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  color: Colors.black54,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  child: Text(
                                    "${it.date} · ${it.tag}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
