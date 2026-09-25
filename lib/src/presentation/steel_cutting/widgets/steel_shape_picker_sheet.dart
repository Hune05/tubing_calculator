import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/presentation/common/app_icons.dart';

import '../../../data/models/steel_shape_db.dart';
import '../../tube_cutting/cutting_theme.dart';
import '../steel_custom_shapes.dart';
import '../steel_shape_icons.dart';
import '../steel_weight.dart';

// 🚀 [형강 컷팅 신규] 부속 검색 팝업(SmartFittingSelectorSheet)과 같은
// 형식(흰 배경 + 원형 아이콘 헤더 + 검색 + 카테고리 칩 + 목록 + 커스텀
// 입력)으로 통일한 형강 규격 선택 시트. 표준 목록에 없는 규격은 "직접
// 입력"을 고르면 [kCustomSteelShapeRequestId]를 돌려줘서, 부른 쪽에서
// 커스텀 규격 입력 다이얼로그를 띄우게 한다.
class SteelShapePickerSheet extends StatefulWidget {
  const SteelShapePickerSheet({super.key});

  static Future<SteelShapeItem?> show(BuildContext context) {
    return showModalBottomSheet<SteelShapeItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SteelShapePickerSheet(),
    );
  }

  @override
  State<SteelShapePickerSheet> createState() => _SteelShapePickerSheetState();
}

class _SteelShapePickerSheetState extends State<SteelShapePickerSheet> {
  String _searchQuery = '';
  String _categoryFilter = '전체';
  final TextEditingController _searchController = TextEditingController();
  // 직접 입력해서 저장해 둔 "내 규격" 이름들(최근에 쓴 것이 앞).
  List<String> _custom = [];

  static const String _kMine = '내 규격';

  @override
  void initState() {
    super.initState();
    loadCustomSteelShapes().then((v) {
      if (mounted) setState(() => _custom = v);
    });
  }

  // 칩: 전체 + (있으면) 내 규격 + DB의 종류 전부(칩이 많아 옆으로 밀어서 본다).
  List<String> get _categories => [
    '전체',
    if (_custom.isNotEmpty) _kMine,
    ...SteelShapeDB.categories.map((c) => c.label),
  ];

  List<SteelShapeItem> get _customItems => [
    for (final label in _custom)
      SteelShapeItem(id: 'custom_$label', category: 'CUSTOM', label: label),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SteelShapeItem> get _filtered {
    Iterable<SteelShapeItem> list = [..._customItems, ...SteelShapeDB.all];
    if (_categoryFilter == _kMine) {
      list = _customItems;
    } else if (_categoryFilter != '전체') {
      final id = SteelShapeDB.categories
          .firstWhere((c) => c.label == _categoryFilter)
          .id;
      list = list.where((s) => s.category == id);
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      // 공백·"x"·"*"·"×"는 같은 것으로 본다("40 40 3", "40*40*3", "40×40×3" 모두 40x40x3).
      String norm(String v) => v
          .toLowerCase()
          .replaceAll(RegExp(r'[\s*×·,]+'), 'x')
          .replaceAll(RegExp(r'x+'), 'x');
      // "C찬넬"은 찬넬과 립C형강 둘 다 가리키는 현장 말이다.
      final cMatch = RegExp(r'^c\s*찬넬\s*(.*)$').firstMatch(q);
      final nq = norm(q);
      final cRest = cMatch == null ? '' : norm(cMatch.group(1)!);
      list = list.where((s) {
        if (cMatch != null &&
            (s.category == 'CHANNEL' || s.category == 'LIPC')) {
          // 찬넬 종류 안에서 뒤에 붙인 치수로 더 거른다("C찬넬 100").
          final nl = norm(s.label);
          if (cRest.isEmpty || nl.contains(cRest) || nl.contains('x$cRest')) {
            return true;
          }
        }
        return s.label.toLowerCase().contains(q) ||
            norm(s.label).contains(nq) ||
            SteelShapeDB.categoryLabel(s.category).contains(q);
      });
    }
    return list.toList();
  }

  Future<void> _confirmRemove(String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CuttingColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "'$label'을(를) 내 규격에서 지우겠습니까?",
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: CuttingColors.textPrimary,
            fontSize: 16,
          ),
        ),
        content: const Text(
          "이미 넣은 항목은 그대로 남습니다.",
          style: TextStyle(color: CuttingColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            key: const Key('custom_remove_confirm'),
            style: ElevatedButton.styleFrom(
              backgroundColor: CuttingColors.danger,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "지우기",
              style: TextStyle(color: CuttingColors.surface),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final left = await removeCustomSteelShape(label);
    if (!mounted) return;
    setState(() {
      _custom = left;
      if (_custom.isEmpty && _categoryFilter == _kMine) _categoryFilter = '전체';
    });
  }

  Widget _buildCategoryChip(String label) {
    final bool selected = _categoryFilter == label;
    return Material(
      color: selected ? CuttingColors.primary : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _categoryFilter = label),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomEntryRow(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(
          context,
          const SteelShapeItem(
            id: kCustomSteelShapeRequestId,
            category: 'CUSTOM',
            label: '',
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: CuttingColors.primary),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "목록에 없는 규격 직접 입력",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: CuttingColors.textPrimary,
                  ),
                ),
              ),
              Icon(AppIcons.forward, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    return Material(
      color: Colors.transparent,
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: CuttingColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: [
                      cuttingDialogIcon(AppGlyph.stChannel),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          "형강 규격 선택",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: CuttingColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.grey,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    style: const TextStyle(color: CuttingColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: "규격으로 검색 (예: 40x40, 스트럿, 25A)",
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: CuttingColors.primary,
                      ),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = "");
                              },
                            ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _categories
                              .map(
                                (c) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _buildCategoryChip(c),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${results.length}개",
                        key: const Key('steel_pick_count'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: 2,
                  color: Color(0xFFEEEEEE),
                ),
                _buildCustomEntryRow(context),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFEEEEEE),
                ),
                Expanded(
                  child: results.isEmpty
                      ? Center(
                          child: Text(
                            "검색 결과가 없습니다.\n위 '직접 입력'을 이용해 보십시오.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: results.length,
                          itemBuilder: (context, i) {
                            final item = results[i];
                            return ListTile(
                              leading: anyIcon(
                                iconForSteel(item.category),
                                color: CuttingColors.primary,
                              ),
                              subtitle: Text(
                                [
                                  SteelShapeDB.categoryLabel(item.category),
                                  if (steelShapeNote(item.label).isNotEmpty)
                                    steelShapeNote(item.label),
                                ].join(' · '),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              title: Text(
                                item.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: CuttingColors.textPrimary,
                                ),
                              ),
                              trailing: item.category == 'CUSTOM'
                                  ? IconButton(
                                      key: Key('custom_remove_${item.label}'),
                                      tooltip: '내 규격에서 지우기',
                                      icon: Icon(
                                        Icons.close_rounded,
                                        color: Colors.grey.shade500,
                                      ),
                                      onPressed: () =>
                                          _confirmRemove(item.label),
                                    )
                                  : null,
                              onTap: () => Navigator.pop(context, item),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
