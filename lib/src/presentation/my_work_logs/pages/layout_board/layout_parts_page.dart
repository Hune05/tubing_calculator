// 작업 배치도 "부품 담기" 페이지(10-13 개편). 아래 막대에 흩어져 있던 덕트·전기·계기·밸브·피팅(스키드는
// 형강·JB·부속) 단추를 한 페이지로 모았다. 위에 찾기 칸, 그 아래 묶음 단추, 목록은 제조사별.
// 고르면 그 부품을 돌려주고 닫힌다(배치도가 도면 가운데에 놓는다).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../common/pick_style.dart';
import '../../models/instrument_shape_painter.dart';
import '../../models/layout_board_models.dart';
import '../../widgets/korean_text.dart';
import '../../widgets/layout_board_ui.dart';

/// 부품 묶음 하나(덕트·전기·계기…). [groups]는 제조사(또는 종류) → 부품 목록.
class LayoutPartsCategory {
  final String key;
  final String label;
  final Map<String, List<ModulePreset>> groups;
  const LayoutPartsCategory(this.key, this.label, this.groups);
}

/// 바로 놓는 것: 빈 상자(이름·크기를 넣어 쓴다)와 메모 글자.
const ModulePreset kLayoutNewPartPreset = ModulePreset("신규 부품", 80, 80);
const ModulePreset kLayoutNotePreset = ModulePreset(
  "메모",
  160,
  40,
  shape: InstrumentShape.note,
);

class LayoutPartsPage extends StatefulWidget {
  final List<LayoutPartsCategory> categories;

  /// 내 프리셋(관리 창에서 지워질 수 있어 그때그때 읽는다).
  final List<ModulePreset> Function() customPresets;

  /// 즐겨찾기 이름(별을 누르면 바뀌므로 그때그때 읽는다).
  final Set<String> Function() favorites;

  /// 최근 쓴 부품 이름(앞이 최근).
  final List<String> recents;
  final void Function(String name) onToggleFavorite;

  /// 내 프리셋 관리 창. 끝나면 목록을 다시 그린다.
  final Future<void> Function()? onManagePresets;

  /// 피팅 묶음 키(크기 거르기 단추를 보인다). 없으면 ''.
  final String fittingCategoryKey;
  final String fittingSize;
  final ValueChanged<String> onFittingSize;

  /// 찾기 칸에 바로 자판을 올릴지("찾기" 단추로 열었을 때).
  final bool autofocusSearch;

  /// 처음 보일 묶음 키. 없으면 즐겨찾기가 있으면 즐겨찾기, 아니면 첫 묶음.
  final String? initialCategory;

  const LayoutPartsPage({
    super.key,
    required this.categories,
    required this.customPresets,
    required this.favorites,
    required this.recents,
    required this.onToggleFavorite,
    required this.onFittingSize,
    this.onManagePresets,
    this.fittingCategoryKey = '',
    this.fittingSize = '1/2"',
    this.autofocusSearch = false,
    this.initialCategory,
  });

  @override
  State<LayoutPartsPage> createState() => _LayoutPartsPageState();
}

class _LayoutPartsPageState extends State<LayoutPartsPage> {
  static const String _kFav = 'fav';
  static const String _kRecent = 'recent';
  static const String _kMine = 'mine';

  final TextEditingController _search = TextEditingController();
  String _query = '';
  late String _category;
  late String _fittingSize = widget.fittingSize;

  @override
  void initState() {
    super.initState();
    _category =
        widget.initialCategory ??
        (widget.favorites().isNotEmpty
            ? _kFav
            : (widget.categories.isNotEmpty
                  ? widget.categories.first.key
                  : _kMine));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// 찾기 글과 견줄 때: 소문자, 빈칸 없이.
  static String _key(String v) =>
      v.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  /// 모든 부품(묶음 이름 → 목록). 내 부품도 든다.
  Map<String, List<ModulePreset>> get _everything => {
    '바로 놓기': const [kLayoutNewPartPreset, kLayoutNotePreset],
    if (widget.customPresets().isNotEmpty) '내 프리셋': widget.customPresets(),
    for (final c in widget.categories)
      for (final g in c.groups.entries) '${c.label} · ${g.key}': g.value,
  };

  /// 지금 보일 묶음들(묶음 이름 → 목록).
  List<MapEntry<String, List<ModulePreset>>> _sections() {
    final q = _key(_query);
    bool match(ModulePreset p) => q.isEmpty || _key(p.name).contains(q);
    if (q.isNotEmpty) {
      return [
        for (final e in _everything.entries)
          if (e.value.any(match))
            MapEntry(e.key, [
              for (final p in e.value)
                if (match(p)) p,
            ]),
      ];
    }
    switch (_category) {
      case _kFav:
        final fav = widget.favorites();
        final list = <ModulePreset>[];
        for (final e in _everything.entries) {
          for (final p in e.value) {
            if (fav.contains(p.name) && !list.any((x) => x.name == p.name)) {
              list.add(p);
            }
          }
        }
        return [if (list.isNotEmpty) MapEntry('즐겨찾기', list)];
      case _kRecent:
        final list = <ModulePreset>[];
        for (final n in widget.recents) {
          for (final e in _everything.entries) {
            final p = e.value.where((x) => x.name == n).firstOrNull;
            if (p != null && !list.any((x) => x.name == n)) {
              list.add(p);
              break;
            }
          }
        }
        return [if (list.isNotEmpty) MapEntry('최근 쓴 부품', list)];
      case _kMine:
        return [
          const MapEntry('바로 놓기', [kLayoutNewPartPreset, kLayoutNotePreset]),
          MapEntry('내 프리셋', widget.customPresets()),
        ];
      default:
        final c = widget.categories
            .where((c) => c.key == _category)
            .firstOrNull;
        if (c == null) return const [];
        final bool fitting = c.key == widget.fittingCategoryKey;
        return [
          for (final g in c.groups.entries)
            MapEntry(g.key, [
              for (final p in g.value)
                if (!fitting || fittingTubeSize(p.name) == _fittingSize) p,
            ]),
        ];
    }
  }

  void _pick(ModulePreset p) {
    HapticFeedback.selectionClick();
    Navigator.pop(context, p);
  }

  @override
  Widget build(BuildContext context) {
    final bool searching = _query.trim().isNotEmpty;
    final sections = _sections().where((e) => e.value.isNotEmpty).toList();
    final bool showFittingSizes =
        !searching &&
        widget.fittingCategoryKey.isNotEmpty &&
        _category == widget.fittingCategoryKey;
    return Scaffold(
      backgroundColor: tossBg,
      appBar: AppBar(
        backgroundColor: tossBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        shape: const Border(bottom: BorderSide(color: layoutLine)),
        title: const Text(
          "부품 담기",
          style: TextStyle(
            color: tossText,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              key: const ValueKey("preset_search"),
              controller: _search,
              autofocus: widget.autofocusSearch,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 16, color: tossText),
              decoration: InputDecoration(
                hintText: "이름·모델·극수로 찾기 (예: UK 2.5, 10P, LB 22)",
                hintStyle: const TextStyle(fontSize: 14, color: tossSubText),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: tossSubText,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: "지우기",
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: tossSubText,
                        ),
                      ),
                isDense: true,
                filled: true,
                fillColor: pureWhite,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: layoutLine),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: layoutLine),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: tossBlue, width: 2),
                ),
              ),
            ),
          ),
          if (!searching) _buildCategoryRow(),
          if (showFittingSizes) _buildFittingSizes(),
          Expanded(
            child: sections.isEmpty
                ? _buildEmpty(searching)
                : ListView(
                    key: const ValueKey("preset_list"),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      for (final s in sections) ...[
                        const SizedBox(height: 12),
                        _sectionHeader(s.key),
                        Container(
                          decoration: layoutCardDecoration(radius: 14),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (int i = 0; i < s.value.length; i++) ...[
                                if (i > 0)
                                  const Divider(height: 1, color: layoutLine),
                                _row(s.value[i], s.key),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow() {
    final fav = widget.favorites();
    final entries = <(String, String)>[
      if (fav.isNotEmpty) (_kFav, '★ 즐겨찾기 ${fav.length}'),
      if (widget.recents.isNotEmpty) (_kRecent, '최근'),
      (_kMine, '내 부품'),
      for (final c in widget.categories) (c.key, c.label),
    ];
    if (!entries.any((e) => e.$1 == _category)) _category = entries.first.$1;
    // 옆으로 굴리는 줄이면 폰에서 마지막 묶음이 잘려 안 보인다. 줄이 넘치면 다음 줄로 내린다.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (key, label) in entries)
            Material(
              key: ValueKey("parts_cat_$key"),
              // 10-15 새 모양: 고른 묶음은 옅은 청록 + 짙은 청록 글자(앱 칩과 같게).
              color: key == _category ? pickFill() : pureWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(
                  color: key == _category ? pickLine() : layoutLine,
                  width: 1.5,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => setState(() => _category = key),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Center(
                      widthFactor: 1,
                      // 10-15 통일: 고른 묶음 앞에 ✓
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (key == _category) ...[
                            pickCheck(),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: key == _category ? pickInk() : tossText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 피팅 튜브 크기 거르기(1/4"·3/8"·1/2").
  Widget _buildFittingSizes() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
    child: Row(
      children: [
        const Text(
          "튜브 크기",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: tossSubText,
          ),
        ),
        const SizedBox(width: 10),
        // 10-15: ✓가 붙어 좁은 폰에서 넘치지 않게 크기 단추는 옆으로 밀리게.
        Flexible(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final size in kFittingSizes) ...[
                  Material(
                    key: ValueKey("fitting_size_$size"),
                    // 10-15 새 모양: 고른 크기는 옅은 청록 + 짙은 청록 글자.
                    color: size == _fittingSize ? pickFill() : pureWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(
                        color: size == _fittingSize ? pickLine() : layoutLine,
                        width: 1.5,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        setState(() => _fittingSize = size);
                        widget.onFittingSize(size);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        // 10-15 통일: 고른 크기 앞에 ✓
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (size == _fittingSize) ...[
                              pickCheck(),
                              const SizedBox(width: 3),
                            ],
                            Text(
                              size,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: size == _fittingSize
                                    ? pickInk()
                                    : tossText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _sectionHeader(String title) {
    final bool mine = title == '내 프리셋';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: tossSubText,
              ),
            ),
          ),
          if (mine && widget.onManagePresets != null)
            TextButton(
              key: const ValueKey("presets_manage_button"),
              onPressed: () async {
                await widget.onManagePresets!();
                if (mounted) setState(() {});
              },
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 40),
                foregroundColor: tossBlue,
              ),
              child: const Text(
                "관리",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(ModulePreset p, String section) {
    final bool quick = p == kLayoutNewPartPreset || p == kLayoutNotePreset;
    final bool fav = widget.favorites().contains(p.name);
    final String sub = p == kLayoutNewPartPreset
        ? "빈 상자를 놓고 이름·크기를 넣습니다"
        : p == kLayoutNotePreset
        ? "도면에 글만 적습니다(자재 수량에 안 셉니다)"
        // 덕트는 이름에 폭×높이가 있고(묶음 이름은 크기 구분이라 되풀이할 것 없음),
        // 도면 세로(길이)는 놓은 뒤 고친다.
        : p.shape == InstrumentShape.duct
        ? "길이는 놓은 뒤 고칩니다"
        : [
            if (section.contains(' · ')) section.split(' · ').last else section,
            "${p.width.toInt()}×${p.height.toInt()}",
          ].join(' · ');
    return ListTile(
      key: ValueKey("preset_row_${p.name}"),
      contentPadding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
      leading: quick
          ? Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tossBlue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tossBlue.withValues(alpha: 0.4)),
              ),
              child: Icon(
                p == kLayoutNotePreset
                    ? Icons.sticky_note_2_outlined
                    : Icons.add_box_rounded,
                color: tossBlue,
              ),
            )
          : layoutPresetThumb(p, box: 48),
      title: Text(
        p.name,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: tossText,
        ),
      ),
      subtitle: Text(
        keepWords(sub),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, color: tossSubText),
      ),
      trailing: quick
          ? null
          : IconButton(
              key: ValueKey("preset_fav_${p.name}"),
              tooltip: fav ? "즐겨찾기에서 빼기" : "즐겨찾기",
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: () {
                widget.onToggleFavorite(p.name);
                setState(() {});
              },
              icon: Icon(
                fav ? Icons.star_rounded : Icons.star_border_rounded,
                color: fav ? const Color(0xFFF59E0B) : tossSubText,
              ),
            ),
      onTap: () => _pick(p),
    );
  }

  Widget _buildEmpty(bool searching) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        keepWords(
          searching
              ? "'$_query'에 맞는 부품이 없습니다. 내 부품의 신규 부품으로 놓고 이름·크기를 넣으십시오."
              : (_category == _kMine
                    ? "아직 내 프리셋이 없습니다. 부품 편집 창의 \"내 프리셋으로 저장\"으로 넣습니다."
                    : "이 묶음에는 부품이 없습니다."),
        ),
        key: const ValueKey("preset_search_empty"),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: tossSubText, height: 1.5),
      ),
    ),
  );
}
