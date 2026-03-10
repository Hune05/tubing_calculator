import 'package:flutter/material.dart';
import '../../../data/models/fitting_item.dart';

const Color darkBg = Color(0xFF1E2124);
const Color cardBg = Color(0xFF2A2E33);
const Color makitaTeal = Color(0xFF007580);
const Color mutedWhite = Color(0xFFD0D4D9);

class SmartFittingSelectorSheet extends StatefulWidget {
  const SmartFittingSelectorSheet({super.key});

  static Future<FittingItem?> show(BuildContext context) {
    return showModalBottomSheet<FittingItem>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const SmartFittingSelectorSheet(),
    );
  }

  @override
  State<SmartFittingSelectorSheet> createState() =>
      _SmartFittingSelectorSheetState();
}

class _SmartFittingSelectorSheetState extends State<SmartFittingSelectorSheet> {
  int _step = 1;

  String _selectedCategory = "";
  String _selectedThreadType = "NPT";
  String _selectedThreadSize = "1/2\"";

  // 🚀 에러 해결: maker와 tubeOD 필수값 추가
  final List<FittingItem> _quickPicks = [
    const FittingItem(
      id: "sw_mc_12_npt12",
      maker: "Swagelok",
      tubeOD: "1/2\"",
      category: "Connector",
      name: "Male Connector",
      threadType: "NPT",
      threadSize: "1/2\"",
      deduction: 27.4,
      icon: Icons.settings_input_component,
    ),
    const FittingItem(
      id: "sw_ue_12",
      maker: "Swagelok",
      tubeOD: "1/2\"",
      category: "Elbow",
      name: "Union Elbow",
      deduction: 25.9,
      icon: Icons.turn_right,
    ),
    const FittingItem(
      id: "none",
      maker: "ALL",
      tubeOD: "ALL",
      category: "직관",
      name: "없음 (직관)",
      deduction: 0.0,
      icon: Icons.horizontal_rule,
    ),
  ];

  final List<Map<String, dynamic>> _categories = [
    {"name": "Connector", "icon": Icons.settings_input_component},
    {"name": "Elbow", "icon": Icons.turn_right},
    {"name": "Tee", "icon": Icons.call_split},
    {"name": "Valve", "icon": Icons.gamepad},
  ];

  void _onQuickPick(FittingItem item) {
    Navigator.pop(context, item);
  }

  void _onCategorySelected(String category) {
    if (category == "Connector") {
      setState(() {
        _selectedCategory = category;
        _step = 2;
      });
    } else {
      // 🚀 에러 해결: 임시 데이터에도 maker와 tubeOD 추가
      Navigator.pop(
        context,
        FittingItem(
          id: "temp_id",
          maker: "ALL",
          tubeOD: "ALL",
          category: category,
          name: "Union $category",
          deduction: 24.5,
          icon: Icons.turn_right,
        ),
      );
    }
  }

  void _onCompleteSelection() {
    // 🚀 에러 해결: 커스텀 선택 데이터에도 maker와 tubeOD 추가
    Navigator.pop(
      context,
      FittingItem(
        id: "custom_mc",
        maker: "ALL",
        tubeOD: "ALL",
        category: _selectedCategory,
        name: "Male $_selectedCategory",
        threadType: _selectedThreadType,
        threadSize: _selectedThreadSize,
        deduction: 22.1,
        icon: Icons.settings_input_component,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: darkBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _step == 1 ? _buildStep1() : _buildStep2(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Padding(
      key: const ValueKey(1),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "⭐ 스마트 추천 (최근/자주 쓴 부속)",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickPicks
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ActionChip(
                        backgroundColor: cardBg,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        avatar: Icon(item.icon, color: makitaTeal, size: 18),
                        label: Text(
                          item.displayName,
                          style: const TextStyle(color: Colors.white),
                        ),
                        onPressed: () => _onQuickPick(item),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),

          const SizedBox(height: 40),
          const Text(
            "분류 선택 (Category)",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                return InkWell(
                  onTap: () => _onCategorySelected(cat["name"]),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(cat["icon"], color: Colors.white70, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          cat["name"],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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

  Widget _buildStep2() {
    return Padding(
      key: const ValueKey(2),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() => _step = 1),
              ),
              Text(
                "$_selectedCategory 상세 규격 선택",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          const Text(
            "1. 나사산 종류 (Thread Type)",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: ["NPT", "PT", "UNF"]
                .map(
                  (type) => ChoiceChip(
                    label: Text(type, style: const TextStyle(fontSize: 16)),
                    selected: _selectedThreadType == type,
                    selectedColor: makitaTeal,
                    backgroundColor: cardBg,
                    labelStyle: TextStyle(
                      color: _selectedThreadType == type
                          ? Colors.white
                          : Colors.grey,
                    ),
                    onSelected: (val) =>
                        setState(() => _selectedThreadType = type),
                  ),
                )
                .toList(),
          ),

          const SizedBox(height: 40),

          const Text(
            "2. 나사산 크기 (Thread Size)",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ["1/8\"", "1/4\"", "3/8\"", "1/2\""]
                .map(
                  (size) => ChoiceChip(
                    label: Text(
                      size,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    selected: _selectedThreadSize == size,
                    selectedColor: makitaTeal,
                    backgroundColor: cardBg,
                    labelStyle: TextStyle(
                      color: _selectedThreadSize == size
                          ? Colors.white
                          : Colors.grey,
                    ),
                    onSelected: (val) =>
                        setState(() => _selectedThreadSize = size),
                  ),
                )
                .toList(),
          ),

          const Spacer(),

          ElevatedButton(
            onPressed: _onCompleteSelection,
            style: ElevatedButton.styleFrom(
              backgroundColor: makitaTeal,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "선택 완료",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
