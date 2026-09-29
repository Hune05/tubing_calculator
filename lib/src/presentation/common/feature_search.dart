// 기능 검색 창: 메뉴 기능을 이름·설명으로 찾는다(초성 검색도 된다: "ㄱㅅㄱ" → "공학용 계산기").
// 홈 메뉴 머리의 검색 단추와 빠른 도구 막대의 "전체"가 같은 창을 쓴다.
import 'package:flutter/material.dart';

import '../../core/theme/app_icon_set.dart';
import '../../core/theme/field_view.dart';
import 'app_icons.dart';

/// 검색 창에 나오는 기능 하나.
class FeatureItem {
  final String title;
  final String subtitle;
  final AppGlyph? glyph;

  /// [glyph]가 없을 때 쓰는 선 아이콘(막대 세부 기능).
  final IconData? icon;
  final Color? color;

  /// 묶음 이름(검색어가 없을 때 머리글로 보인다). 없으면 묶지 않는다.
  final String? group;
  final VoidCallback onTap;

  /// 있으면 이 항목은 "폴더"다: 격자에서 아이콘 하나로 보이고, 누르면 안의 기능들이 열린다.
  /// 검색할 때는 폴더가 아니라 안의 기능이 하나하나 나온다.
  final List<FeatureItem>? children;

  const FeatureItem({
    required this.title,
    required this.subtitle,
    this.glyph,
    this.icon,
    required this.onTap,
    this.children,
    this.color,
    this.group,
  });
}

const List<String> _initials = [
  'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', //
  'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
];

/// 글자마다 초성만 뽑는다(한글이 아닌 글자는 그대로). 공백은 뺀다.
String hangulInitials(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r == 0x20) continue;
    if (r >= 0xAC00 && r <= 0xD7A3) {
      b.write(_initials[(r - 0xAC00) ~/ 588]);
    } else {
      b.write(String.fromCharCode(r).toLowerCase());
    }
  }
  return b.toString();
}

bool _isAllInitials(String q) =>
    q.isNotEmpty && q.runes.every((r) => r >= 0x3131 && r <= 0x314E);

/// 폴더를 풀어 안의 기능을 하나하나 꺼낸다(검색용). 폴더 이름은 설명 앞에 붙여 어느 폴더 것인지 보이게 한다.
List<FeatureItem> flattenFeatures(List<FeatureItem> items) {
  final out = <FeatureItem>[];
  for (final it in items) {
    final kids = it.children;
    if (kids == null) {
      out.add(it);
      continue;
    }
    for (final k in flattenFeatures(kids)) {
      out.add(
        FeatureItem(
          title: k.title == '전체 화면' ? it.title : k.title,
          subtitle: k.subtitle.isEmpty
              ? it.title
              : '${it.title} › ${k.subtitle}',
          glyph: k.glyph,
          icon: k.icon,
          color: k.color,
          group: it.group,
          onTap: k.onTap,
        ),
      );
    }
  }
  return out;
}

/// [q]가 [item]에 맞는 정도(0 = 안 맞음, 클수록 잘 맞음). 제목이 앞에서 맞으면 가장 높다.
int featureMatchScore(String q, FeatureItem item) {
  final query = q.replaceAll(' ', '').toLowerCase();
  if (query.isEmpty) return 1;
  final title = item.title.replaceAll(' ', '').toLowerCase();
  final sub = item.subtitle.replaceAll(' ', '').toLowerCase();
  if (title.startsWith(query)) return 5;
  if (title.contains(query)) return 4;
  if (_isAllInitials(query)) {
    if (hangulInitials(item.title).contains(query)) return 3;
    if (hangulInitials(item.subtitle).contains(query)) return 1;
    return 0;
  }
  if (sub.contains(query)) return 2;
  return 0;
}

/// [items]에서 [q]에 맞는 것만 잘 맞는 순서로(같으면 원래 순서). 검색어가 비면 그대로.
List<FeatureItem> searchFeatures(String q, List<FeatureItem> items) {
  if (q.trim().isEmpty) return items;
  final scored = <(int, int, FeatureItem)>[];
  for (var i = 0; i < items.length; i++) {
    final s = featureMatchScore(q, items[i]);
    if (s > 0) scored.add((s, i, items[i]));
  }
  scored.sort(
    (a, b) => b.$1 != a.$1 ? b.$1.compareTo(a.$1) : a.$2.compareTo(b.$2),
  );
  return [for (final e in scored) e.$3];
}

/// 검색 창을 연다. 항목을 누르면 창을 닫고 그 항목의 [FeatureItem.onTap]을 부른다.
Future<void> showFeatureSearchSheet(
  BuildContext context, {
  required String title,
  required List<FeatureItem> items,
  bool grid = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: fc.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => FractionallySizedBox(
      heightFactor: 0.92,
      child: FeatureSearchSheet(title: title, items: items, grid: grid),
    ),
  );
}

class FeatureSearchSheet extends StatefulWidget {
  final String title;
  final List<FeatureItem> items;

  /// true면 목록 대신 아이콘 격자로 보인다(빠른 도구 막대의 "전체").
  final bool grid;
  const FeatureSearchSheet({
    this.grid = false,
    super.key,
    required this.title,
    required this.items,
  });

  @override
  State<FeatureSearchSheet> createState() => _FeatureSearchSheetState();
}

class _FeatureSearchSheetState extends State<FeatureSearchSheet> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _pick(FeatureItem it) {
    Navigator.of(context).pop();
    it.onTap();
  }

  /// 안이 열려 있는 폴더(없으면 null). 검색 창 안에 작은 카드로 뜬다.
  FeatureItem? _folder;

  /// 폴더를 연다: 검색 창 안쪽에 창보다 좁은 카드가 뜨고, 안의 기능이 격자로 보인다.
  /// 하나를 누르면 폴더와 검색 창을 닫고 그 기능을 연다.
  void _openFolder(FeatureItem folder) => setState(() => _folder = folder);

  Widget _folderCard(double boxW, double boxH) {
    final folder = _folder!;
    final kids = folder.children ?? const <FeatureItem>[];
    const cols = 3;
    final rows = (kids.length / cols).ceil();
    // 내용이 딱 맞는 높이(머리글 + 줄 수 × 칸 높이)의 두 배. 창 높이의 90%는 넘지 않는다.
    final natural = 56.0 + rows * 104.0;
    final h = (natural * 2).clamp(0.0, boxH * 0.9);
    final w = boxW * 0.88;
    return Positioned.fill(
      child: GestureDetector(
        key: const Key('feature_folder_scrim'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _folder = null),
        child: Container(
          color: Colors.black38,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {}, // 카드 안을 눌러도 닫히지 않게
            child: Material(
              key: const Key('feature_folder_dialog'),
              color: fc.surface,
              elevation: 8,
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: w,
                height: h,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              folder.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: fc.text,
                              ),
                            ),
                          ),
                          IconButton(
                            key: const Key('feature_folder_close'),
                            tooltip: '닫기',
                            icon: Icon(AppIcons.close, color: fc.textSub),
                            onPressed: () => setState(() => _folder = null),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final tw = c.maxWidth / cols;
                            return Wrap(
                              children: [
                                for (final k in kids)
                                  _tile(
                                    k,
                                    tw,
                                    onPick: () {
                                      setState(() => _folder = null);
                                      _pick(k);
                                    },
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(FeatureItem it, double w, {VoidCallback? onPick}) {
    final color = it.color ?? fc.text;
    final kids = it.children;
    final isFolder = kids != null;
    return SizedBox(
      width: w,
      child: InkWell(
        key: Key(
          isFolder ? 'feature_folder_${it.title}' : 'feature_${it.title}',
        ),
        borderRadius: BorderRadius.circular(12),
        onTap: onPick ?? (isFolder ? () => _openFolder(it) : () => _pick(it)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isFolder
                          ? fc.brand.withValues(alpha: 0.10)
                          : color.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: isFolder
                          ? Border.all(
                              color: fc.brand.withValues(alpha: 0.35),
                              width: 1.4,
                            )
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: _iconOf(it, 28, color),
                  ),
                  if (isFolder)
                    Positioned(
                      right: -5,
                      bottom: -5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: fc.brand,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '${kids.length}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: fc.onBrand,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                it.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: fc.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gridOf(List<FeatureItem> list) => LayoutBuilder(
    builder: (context, c) {
      final cols = c.maxWidth >= 560 ? 6 : 4;
      final w = (c.maxWidth - 32) / cols;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(children: [for (final it in list) _tile(it, w)]),
      );
    },
  );

  Widget _row(FeatureItem it) {
    final color = it.color ?? fc.text;
    return InkWell(
      key: Key('feature_${it.title}'),
      onTap: () => _pick(it),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: _iconOf(it, 24, color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    it.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: fc.text,
                    ),
                  ),
                  if (it.subtitle.isNotEmpty)
                    Text(
                      it.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: fc.textSub),
                    ),
                ],
              ),
            ),
            Icon(AppIcons.forward, size: 20, color: fc.textSub),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _c.text;
    final searching0 = q.trim().isNotEmpty;
    // 검색할 때는 폴더를 풀어 안의 기능이 하나하나 나오게 한다.
    final found = searchFeatures(
      q,
      searching0 ? flattenFeatures(widget.items) : widget.items,
    );
    final children = <Widget>[];
    Widget header(String g) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Text(
        g,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: fc.textSub,
        ),
      ),
    );
    final searching = q.trim().isNotEmpty;
    if (widget.grid) {
      if (searching) {
        // 검색 결과는 잘 맞는 순서 그대로 한 격자로.
        children.add(_gridOf(found));
      } else {
        final groups = <String, List<FeatureItem>>{};
        for (final it in found) {
          (groups[it.group ?? ''] ??= []).add(it);
        }
        groups.forEach((g, list) {
          if (g.isNotEmpty) children.add(header(g));
          children.add(_gridOf(list));
        });
      }
    } else if (!searching) {
      String? last;
      for (final it in found) {
        if (it.group != null && it.group != last) {
          last = it.group;
          children.add(header(it.group!));
        }
        children.add(_row(it));
      }
    } else {
      children.addAll(found.map(_row));
    }
    final column = Column(
      key: const Key('feature_search_sheet'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: fc.text,
                  ),
                ),
              ),
              IconButton(
                tooltip: '닫기',
                icon: Icon(AppIcons.close, color: fc.textSub),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: TextField(
            key: const Key('feature_search_field'),
            controller: _c,
            autofocus: !widget.grid, // 격자(전체)는 아이콘을 먼저 보게 키보드를 자동으로 안 띄운다
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '기능 이름이나 설명으로 찾기 (초성도 됩니다)',
              prefixIcon: Icon(AppIcons.search, color: fc.textSub),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      key: const Key('feature_search_clear'),
                      icon: Icon(AppIcons.close, color: fc.textSub),
                      onPressed: () => setState(_c.clear),
                    ),
              filled: true,
              fillColor: fc.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: children.isEmpty
              ? Center(
                  child: Text(
                    '"$q"에 맞는 기능이 없습니다',
                    key: const Key('feature_search_empty'),
                    style: TextStyle(color: fc.textSub),
                  ),
                )
              : ListView(
                  key: const Key('feature_search_list'),
                  padding: const EdgeInsets.only(bottom: 16),
                  children: children,
                ),
        ),
      ],
    );
    // 폴더가 열리면 검색 창 안쪽에 창보다 작은 카드로 덮는다.
    return LayoutBuilder(
      builder: (context, box) => Stack(
        children: [
          column,
          if (_folder != null) _folderCard(box.maxWidth, box.maxHeight),
        ],
      ),
    );
  }
}

Widget _iconOf(FeatureItem it, double size, Color color) => it.glyph != null
    ? AppIcon(it.glyph!, size: size, color: color)
    : Icon(it.icon ?? AppIcons.more, size: size, color: color);
