import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

// ---------------------------------------------------------
// 💡 [1] 일관된 테마 컬러 적용 (전역 변수)
// ---------------------------------------------------------
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
  // ---------------------------------------------------------
  // 💡 [2] 화면 상태 관리를 위한 변수들
  // ---------------------------------------------------------
  bool _showDeadStock = false; // 악성(장기) 재고만 볼 것인지 여부

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

  // 🔥 [핵심] 파이어베이스 서버의 'inventory' 창고(컬렉션) 연결 고리
  final CollectionReference _inventoryDb = FirebaseFirestore.instance
      .collection('inventory');

  // ---------------------------------------------------------
  // 💾 [3] 파이어베이스 서버의 데이터를 수정하는 함수들
  // ---------------------------------------------------------

  void _updateQuantity(String docId, int currentQty, int amount) {
    if (currentQty + amount >= 0) {
      _inventoryDb.doc(docId).update({'qty': currentQty + amount});
    }
  }

  void _toggleDeadStockStatus(String docId, bool currentStatus) {
    _inventoryDb.doc(docId).update({'is_dead_stock': !currentStatus});
  }

  // ---------------------------------------------------------
  // 📝 [4] 신규 자재 추가 팝업 (바텀 시트)
  // ---------------------------------------------------------
  void _showAddMaterialSheet() {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController sizeCtrl = TextEditingController();
    final TextEditingController qtyCtrl = TextEditingController(text: "0");
    final TextEditingController minQtyCtrl = TextEditingController(text: "10");

    String selectedCategory = "FITTING";
    String selectedUnit = "EA";

    final List<String> addCategories = _categories
        .where((c) => c != "ALL")
        .toList();

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

                      // 카테고리 & 단위 선택
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "카테고리",
                                  style: TextStyle(
                                    color: slate900,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: slate50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedCategory,
                                      isExpanded: true,
                                      dropdownColor: pureWhite,
                                      style: const TextStyle(
                                        color: slate900,
                                        fontSize: 14,
                                      ),
                                      items: addCategories.map((String value) {
                                        return DropdownMenuItem(
                                          value: value,
                                          child: Text(value),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setSheetState(() {
                                          selectedCategory = val!;
                                          selectedUnit = val == "TUBE"
                                              ? "본"
                                              : "EA";
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "단위",
                                  style: TextStyle(
                                    color: slate900,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: slate50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedUnit,
                                      isExpanded: true,
                                      dropdownColor: pureWhite,
                                      style: const TextStyle(
                                        color: slate900,
                                        fontSize: 14,
                                      ),
                                      items: ["EA", "본", "BOX", "M", "SET"].map(
                                        (String value) {
                                          return DropdownMenuItem(
                                            value: value,
                                            child: Text(value),
                                          );
                                        },
                                      ).toList(),
                                      onChanged: (val) {
                                        setSheetState(
                                          () => selectedUnit = val!,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 자재명 입력
                      const Text(
                        "자재명",
                        style: TextStyle(
                          color: slate900,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          hintText: "예: Union Tee 등",
                          filled: true,
                          fillColor: slate50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 규격 입력
                      const Text(
                        "규격 (Size)",
                        style: TextStyle(
                          color: slate900,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: sizeCtrl,
                        decoration: InputDecoration(
                          hintText: "예: 1/2\", 50A 등",
                          filled: true,
                          fillColor: slate50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 수량 및 안전 재고 입력
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "초기 수량",
                                  style: TextStyle(
                                    color: slate900,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: qtyCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: slate50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "안전 재고 (경고)",
                                  style: TextStyle(
                                    color: slate900,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: minQtyCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: slate50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // 취소 및 등록 버튼
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
                                    sizeCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("자재명과 규격을 모두 입력해주세요!"),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                  return;
                                }

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
                                    // ★ 모바일 리모트와 데이터 구조를 맞추기 위해 빈 칸 세팅
                                    "heatNo": "",
                                    "maker": "",
                                    "material": "",
                                    "createdAt": FieldValue.serverTimestamp(),
                                  });

                                  if (context.mounted) Navigator.pop(context);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("서버 전송 실패: $e"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
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

  // ---------------------------------------------------------
  // 📱 [5] 화면 뼈대 (UI) 그리기
  // ---------------------------------------------------------
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
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = "";
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 카테고리 필터 영역
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
                        "활성",
                        !_showDeadStock,
                        () => setState(() => _showDeadStock = false),
                      ),
                      const SizedBox(width: 4),
                      _buildFilterChip(
                        "장기",
                        _showDeadStock,
                        () => setState(() => _showDeadStock = true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 🔥 실시간 서버 데이터 렌더링 구역
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _inventoryDb
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return const Center(
                    child: Text(
                      "서버 데이터를 불러오는데 실패했습니다.",
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(
                    child: CircularProgressIndicator(color: makitaTeal),
                  );

                final docs = snapshot.data!.docs;
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  bool categoryMatch =
                      _selectedFilterCategory == "ALL" ||
                      data['category'] == _selectedFilterCategory;
                  bool statusMatch = data['is_dead_stock'] == _showDeadStock;
                  bool searchMatch = true;
                  if (_searchQuery.isNotEmpty) {
                    final nameMatch =
                        data['name']?.toString().toLowerCase().contains(
                          _searchQuery,
                        ) ??
                        false;
                    final sizeMatch =
                        data['size']?.toString().toLowerCase().contains(
                          _searchQuery,
                        ) ??
                        false;
                    searchMatch = nameMatch || sizeMatch;
                  }
                  return categoryMatch && statusMatch && searchMatch;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.packageOpen,
                          size: 60,
                          color: slate200,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? "검색 결과가 없습니다."
                              : (_showDeadStock
                                    ? "등록된 악성 재고가 없습니다."
                                    : "해당 분류에 등록된 자재가 없습니다."),
                          style: const TextStyle(
                            color: slate600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(
                    top: 16,
                    left: 16,
                    right: 16,
                    bottom: 80,
                  ),
                  itemCount: filteredDocs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildMaterialCard(doc.id, data);
                  },
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

  // ★ 모바일 리모트의 히트넘버/메이커/재질을 수용하도록 카드 UI 강화
  Widget _buildMaterialCard(String docId, Map<String, dynamic> item) {
    bool isLowStock = false;
    if (item['qty'] != null && item['min_qty'] != null) {
      isLowStock =
          (item['qty'] < item['min_qty']) && (item['is_dead_stock'] == false);
    }

    final bool isDeadStock = item['is_dead_stock'] ?? false;
    final String category = item['category'] ?? "기타";
    final String name = item['name'] ?? "이름 없음";
    final String size = item['size'] ?? "-";
    final int minQty = item['min_qty'] ?? 0;
    final int qty = item['qty'] ?? 0;
    final String unit = item['unit'] ?? "EA";

    // 🔥 모바일 리모트에서 보낸 새 데이터 캐치
    final String heatNo = item['heatNo'] ?? "";
    final String maker = item['maker'] ?? "";
    final String material = item['material'] ?? "";

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
            color: Colors.black.withValues(alpha: 0.03),
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
                  _getCategoryIcon(category),
                  color: isDeadStock ? slate600 : makitaTeal,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: slate200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(
                              color: slate600,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isLowStock) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "발주 요망",
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (isDeadStock) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "장기 재고",
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      style: TextStyle(
                        color: isDeadStock ? slate600 : slate900,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        decoration: isDeadStock
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "규격: $size  |  안전재고: $minQty",
                      style: const TextStyle(color: slate600, fontSize: 12),
                    ),

                    // 🔥 부가 정보(히트넘버, 제조사, 재질)가 DB에 존재하면 표시하는 구역
                    if (heatNo.isNotEmpty ||
                        maker.isNotEmpty ||
                        material.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (heatNo.isNotEmpty)
                            _buildInfoBadge(
                              Icons.tag,
                              "Heat: $heatNo",
                              Colors.green.shade700,
                              Colors.green.shade50,
                            ),
                          if (maker.isNotEmpty)
                            _buildInfoBadge(
                              Icons.factory,
                              maker,
                              Colors.blue.shade700,
                              Colors.blue.shade50,
                            ),
                          if (material.isNotEmpty)
                            _buildInfoBadge(
                              Icons.category,
                              material,
                              Colors.orange.shade800,
                              Colors.orange.shade50,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$qty $unit",
                    style: TextStyle(
                      color: isDeadStock
                          ? slate600
                          : (isLowStock ? Colors.red.shade700 : makitaTeal),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildQtyBtn(
                        Icons.remove,
                        () => _updateQuantity(docId, qty, -1),
                      ),
                      const SizedBox(width: 8),
                      _buildQtyBtn(
                        Icons.add,
                        () => _updateQuantity(docId, qty, 1),
                        isAdd: true,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _toggleDeadStockStatus(docId, isDeadStock),
                icon: Icon(
                  isDeadStock ? Icons.restore : Icons.archive_outlined,
                  size: 16,
                  color: slate600,
                ),
                label: Text(
                  isDeadStock ? "정상 재고로 복구" : "악성 재고로 격리",
                  style: const TextStyle(color: slate600, fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                  minimumSize: const Size(0, 30),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 부가 정보 뱃지 UI 생성기
  Widget _buildInfoBadge(
    IconData icon,
    String text,
    Color textColor,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap, {bool isAdd = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isAdd ? makitaTeal.withValues(alpha: 0.1) : slate100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isAdd ? makitaTeal.withValues(alpha: 0.3) : slate200,
          ),
        ),
        child: Icon(icon, size: 18, color: isAdd ? makitaTeal : slate600),
      ),
    );
  }

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
