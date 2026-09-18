import 'package:flutter/material.dart';

import '../../../data/models/steel_shape_db.dart';
import '../../tube_cutting/cutting_theme.dart';

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

  static const List<String> _categories = ['전체', '앵글', '찬넬'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SteelShapeItem> get _filtered {
    Iterable<SteelShapeItem> list = SteelShapeDB.all;
    if (_categoryFilter == '앵글') {
      list = list.where((s) => s.category == 'ANGLE');
    } else if (_categoryFilter == '찬넬') {
      list = list.where((s) => s.category == 'CHANNEL');
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) => s.label.toLowerCase().contains(q));
    }
    return list.toList();
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
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
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
                      cuttingDialogIcon(Icons.view_week_rounded),
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
                      hintText: "규격으로 검색 (예: 40x40, 앵글, 찬넬)",
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
                  child: Row(
                    children: [
                      ..._categories.map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildCategoryChip(c),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "${results.length}개",
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
                            "검색 결과가 없습니다.\n위 '직접 입력'을 이용해보세요.",
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
                              leading: Icon(
                                item.category == 'ANGLE'
                                    ? Icons.change_history_rounded
                                    : Icons.view_week_rounded,
                                color: CuttingColors.primary,
                              ),
                              title: Text(
                                item.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: CuttingColors.textPrimary,
                                ),
                              ),
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
