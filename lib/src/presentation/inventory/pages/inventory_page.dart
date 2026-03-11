import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

// 테마 컬러 전역 변수 동일 유지
const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate200 = Color(0xFFE2E8F0);
const Color slate100 = Color(0xFFF1F5F9);
const Color slate50 = Color(0xFFF8FAFC);
const Color pureWhite = Color(0xFFFFFFFF);

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  bool _showDeadStock = false;
  bool _isSearching = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilterCategory = "ALL";
  final List<String> _categories = [
    "ALL",
    "TUBE",
    "FITTING",
    "VALVE",
    "FLANGE",
    "GASKET",
    "기타",
  ];

  final CollectionReference _inventoryDb = FirebaseFirestore.instance
      .collection('inventory');

  void _updateQuantity(String docId, int currentQty, int amount) {
    if (currentQty + amount >= 0) {
      _inventoryDb.doc(docId).update({'qty': currentQty + amount});
    }
  }

  void _toggleDeadStockStatus(String docId, bool currentStatus) {
    //
    _inventoryDb.doc(docId).update({'is_dead_stock': !currentStatus});
  }

  // ---------------------------------------------------------
  // 📝 [수정됨] 신규 자재 등록 팝업 (보관 위치 필드 추가)
  // ---------------------------------------------------------
  void _showAddMaterialSheet() {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController sizeCtrl = TextEditingController();
    final TextEditingController qtyCtrl = TextEditingController(text: "0");
    final TextEditingController minQtyCtrl = TextEditingController(text: "10");

    // 추가된 필드 컨트롤러
    final TextEditingController heatNoCtrl = TextEditingController();
    final TextEditingController makerCtrl = TextEditingController();

    // ★ 신규: 보관 위치 컨트롤러 추가
    final TextEditingController locationCtrl = TextEditingController();

    String selectedCategory = "FITTING";
    String selectedUnit = "EA";
    String selectedMaterial = "SS316"; // 기본 재질 설정

    final List<String> addCategories = _categories
        .where((c) => c != "ALL")
        .toList();
    final List<String> materials = [
      "SS304",
      "SS316",
      "SS316L",
      "CARBON",
      "PVC",
      "기타",
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: pureWhite,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "신규 자재 등록",
                        style: TextStyle(
                          color: slate900,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 카테고리 & 재질 선택
                      Row(
                        children: [
                          _buildPopupDropdown(
                            "카테고리",
                            selectedCategory,
                            addCategories,
                            (val) {
                              setSheetState(() {
                                selectedCategory = val!;
                                selectedUnit = val == "TUBE" ? "본" : "EA";
                              });
                            },
                          ),
                          const SizedBox(width: 12),
                          _buildPopupDropdown(
                            "재질 (Material)",
                            selectedMaterial,
                            materials,
                            (val) {
                              setSheetState(() => selectedMaterial = val!);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 자재명
                      _buildPopupLabel("자재명 (Description)"),
                      _buildPopupTextField(
                        nameCtrl,
                        "예: Union Tee, Ball Valve 등",
                      ),
                      const SizedBox(height: 16),

                      // ★ 신규 추가: 보관 위치
                      _buildPopupLabel("보관 위치 (Location)"),
                      _buildPopupTextField(
                        locationCtrl,
                        "예: A창고-1열-3단, 선반 2번 등",
                      ),
                      const SizedBox(height: 16),

                      // 규격 & 단위
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPopupLabel("규격 (Size)"),
                                _buildPopupTextField(sizeCtrl, "예: 1/2\", 50A"),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildPopupDropdown(
                            "단위",
                            selectedUnit,
                            ["EA", "본", "BOX", "M", "SET"],
                            (val) {
                              setSheetState(() => selectedUnit = val!);
                            },
                            isSmall: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 제조사 & 히트넘버
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPopupLabel("제조사 (Maker)"),
                                _buildPopupTextField(
                                  makerCtrl,
                                  "예: Swagelok, DK-Lok",
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPopupLabel("히트 번호 (Heat No)"),
                                _buildPopupTextField(heatNoCtrl, "예: H123456"),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 수량 및 안전 재고
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPopupLabel("초기 수량"),
                                _buildPopupTextField(
                                  qtyCtrl,
                                  "0",
                                  isNumber: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPopupLabel("안전 재고"),
                                _buildPopupTextField(
                                  minQtyCtrl,
                                  "10",
                                  isNumber: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // 등록 버튼
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                "취소",
                                style: TextStyle(
                                  color: slate600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: makitaTeal,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () async {
                                if (nameCtrl.text.trim().isEmpty ||
                                    sizeCtrl.text.trim().isEmpty)
                                  return;

                                try {
                                  await _inventoryDb.add({
                                    "name": nameCtrl.text.trim(),
                                    "size": sizeCtrl.text.trim(),
                                    "category": selectedCategory,
                                    "qty": int.tryParse(qtyCtrl.text) ?? 0,
                                    "min_qty":
                                        int.tryParse(minQtyCtrl.text) ?? 0,
                                    "is_dead_stock": false,
                                    "unit": selectedUnit,
                                    // 데이터 필드 저장
                                    "heatNo": heatNoCtrl.text
                                        .trim()
                                        .toUpperCase(),
                                    "maker": makerCtrl.text
                                        .trim()
                                        .toUpperCase(),
                                    "material": selectedMaterial,
                                    // ★ 신규 추가: DB에 보관 위치 저장
                                    "location": locationCtrl.text.trim(),
                                    "createdAt": FieldValue.serverTimestamp(),
                                  });
                                  if (context.mounted) Navigator.pop(context);
                                } catch (e) {
                                  debugPrint("Error: $e");
                                }
                              },
                              child: const Text(
                                "등록하기",
                                style: TextStyle(
                                  color: pureWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- 팝업용 헬퍼 위젯 ---
  Widget _buildPopupLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label,
      style: const TextStyle(
        color: slate900,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _buildPopupTextField(
    TextEditingController ctrl,
    String hint, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
        filled: true,
        fillColor: slate50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  Widget _buildPopupDropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged, {
    bool isSmall = false,
  }) {
    return Expanded(
      flex: isSmall ? 1 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPopupLabel(label),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: slate50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                items: items
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s, style: const TextStyle(fontSize: 13)),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slate50,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: pureWhite),
                decoration: const InputDecoration(
                  hintText: '자재명, 규격 검색...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (value) =>
                    setState(() => _searchQuery = value.toLowerCase()),
              )
            : const Text(
                'INVENTORY',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.5,
                ),
              ),
        backgroundColor: makitaTeal,
        foregroundColor: pureWhite,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : LucideIcons.search,
              size: 24,
            ),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchController.clear();
                _searchQuery = "";
              }
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: pureWhite,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: slate50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedFilterCategory,
                        isExpanded: true,
                        dropdownColor: pureWhite,
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: slate600,
                          size: 20,
                        ),
                        style: const TextStyle(
                          color: slate900,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        items: _categories
                            .map(
                              (String category) => DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedFilterCategory = val!),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        "가용 자재",
                        !_showDeadStock,
                        () => setState(() => _showDeadStock = false),
                      ),
                      const SizedBox(width: 4),
                      _buildFilterChip(
                        "장기 미사용",
                        _showDeadStock,
                        () => setState(() => _showDeadStock = true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _inventoryDb
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return const Center(child: Text("에러 발생"));
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  bool categoryMatch =
                      _selectedFilterCategory == "ALL" ||
                      data['category'] == _selectedFilterCategory;
                  bool statusMatch =
                      (data['is_dead_stock'] ?? false) == _showDeadStock;
                  bool searchMatch =
                      data['name'].toString().toLowerCase().contains(
                        _searchQuery,
                      ) ||
                      data['size'].toString().toLowerCase().contains(
                        _searchQuery,
                      );
                  return categoryMatch && statusMatch && searchMatch;
                }).toList();

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildMaterialCard(
                    filteredDocs[index].id,
                    filteredDocs[index].data() as Map<String, dynamic>,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMaterialSheet,
        backgroundColor: makitaTeal,
        icon: const Icon(Icons.add, color: pureWhite),
        label: const Text(
          "자재 등록",
          style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? makitaTeal : slate100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? makitaTeal : Colors.grey.shade300,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? pureWhite : slate600,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 📝 [수정됨] 자재 카드 위젯 (보관 위치 뱃지 추가)
  // ---------------------------------------------------------
  Widget _buildMaterialCard(String docId, Map<String, dynamic> item) {
    final bool isLowStock = (item['qty'] ?? 0) < (item['min_qty'] ?? 10);
    final bool isDeadStock = item['is_dead_stock'] ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDeadStock ? slate50 : pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLowStock ? Colors.red.shade300 : Colors.grey.shade300,
          width: isLowStock ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDeadStock ? slate200 : slate100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getCategoryIcon(item['category'] ?? ""),
                  color: isDeadStock ? slate600 : makitaTeal,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? "이름 없음",
                      style: const TextStyle(
                        color: slate900,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "규격: ${item['size']} | 재질: ${item['material'] ?? '-'}",
                      style: const TextStyle(color: slate600, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // ★ 신규 추가: 보관 위치 뱃지
                        if ((item['location'] ?? "").isNotEmpty)
                          _buildBadge(
                            Icons.location_on,
                            item['location'],
                            Colors.orange.shade700,
                          ),
                        // 제조사 뱃지
                        if ((item['maker'] ?? "").isNotEmpty)
                          _buildBadge(
                            Icons.factory,
                            item['maker'],
                            Colors.blue,
                          ),
                        // 히트번호 뱃지
                        if ((item['heatNo'] ?? "").isNotEmpty)
                          _buildBadge(
                            Icons.tag,
                            "Heat: ${item['heatNo']}",
                            Colors.green,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${item['qty']} ${item['unit']}",
                    style: TextStyle(
                      color: isLowStock ? Colors.red.shade700 : makitaTeal,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildQtyBtn(
                        Icons.remove,
                        () => _updateQuantity(docId, item['qty'], -1),
                      ),
                      const SizedBox(width: 8),
                      _buildQtyBtn(
                        Icons.add,
                        () => _updateQuantity(docId, item['qty'], 1),
                        isAdd: true,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );

  Widget _buildQtyBtn(
    IconData icon,
    VoidCallback onTap, {
    bool isAdd = false,
  }) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isAdd ? makitaTeal.withOpacity(0.1) : slate100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isAdd ? makitaTeal.withOpacity(0.3) : slate200,
        ),
      ),
      child: Icon(icon, size: 18, color: isAdd ? makitaTeal : slate600),
    ),
  );

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case "TUBE":
        return Icons.line_weight;
      case "FITTING":
        return Icons.device_hub;
      case "VALVE":
        return Icons.settings_input_component;
      case "FLANGE":
        return Icons.album;
      case "GASKET":
        return Icons.radio_button_unchecked;
      default:
        return LucideIcons.box;
    }
  }
}
