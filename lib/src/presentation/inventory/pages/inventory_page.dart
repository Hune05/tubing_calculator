import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

// 💡 일관된 테마 컬러 적용
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

  // 💡 테스트용 더미 데이터 (튜브 단위를 '본'으로 변경, 수량도 본 단위에 맞게 조절)
  List<Map<String, dynamic>> materials = [
    {
      "name": "Seamless Tube (SUS316L)",
      "size": "1/2\"",
      "category": "TUBE",
      "qty": 25, // 25본
      "min_qty": 10, // 10본 미만이면 경고
      "is_dead_stock": false,
      "unit": "본", // 🔥 'M' 대신 '본'으로 수정
    },
    {
      "name": "Seamless Tube (SUS316L)",
      "size": "3/8\"",
      "category": "TUBE",
      "qty": 4, // 4본 (재고 부족 뜸!)
      "min_qty": 10,
      "is_dead_stock": false,
      "unit": "본",
    },
    {
      "name": "Male Connector",
      "size": "1/2\" x 1/2\"",
      "category": "FITTING",
      "qty": 45,
      "min_qty": 20,
      "is_dead_stock": false,
      "unit": "EA",
    },
    {
      "name": "Union Elbow",
      "size": "1/2\"",
      "category": "FITTING",
      "qty": 12,
      "min_qty": 15,
      "is_dead_stock": false,
      "unit": "EA",
    },
    {
      "name": "Union Cross (특수 현장용)",
      "size": "1/4\"",
      "category": "FITTING",
      "qty": 4,
      "min_qty": 0,
      "is_dead_stock": true,
      "unit": "EA",
    },
    {
      "name": "Ball Valve",
      "size": "1/2\"",
      "category": "VALVE",
      "qty": 20,
      "min_qty": 10,
      "is_dead_stock": false,
      "unit": "EA",
    },
  ];

  void _updateQuantity(int index, int amount) {
    setState(() {
      int currentQty = materials[index]['qty'];
      if (currentQty + amount >= 0) {
        materials[index]['qty'] = currentQty + amount;
      }
    });
  }

  void _toggleDeadStockStatus(int index) {
    setState(() {
      materials[index]['is_dead_stock'] = !materials[index]['is_dead_stock'];
    });
  }

  // 🔥 자재 추가 팝업 띄우기
  void _showAddMaterialSheet() {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController sizeCtrl = TextEditingController();
    final TextEditingController qtyCtrl = TextEditingController(text: "0");
    final TextEditingController minQtyCtrl = TextEditingController(text: "10");

    String selectedCategory = "FITTING";
    String selectedUnit = "EA";

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
                                      items: ["TUBE", "FITTING", "VALVE", "기타"]
                                          .map((String value) {
                                            return DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(value),
                                            );
                                          })
                                          .toList(),
                                      onChanged: (val) {
                                        setSheetState(() {
                                          selectedCategory = val!;
                                          // 🔥 튜브 선택 시 단위를 '본'으로 자동 변경
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
                                      // 🔥 단위 옵션에 '본' 추가
                                      items: ["EA", "본", "BOX", "M", "SET"].map(
                                        (String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(value),
                                          );
                                        },
                                      ).toList(),
                                      onChanged: (val) => setSheetState(
                                        () => selectedUnit = val!,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

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
                          hintText: "예: Union Tee, Seamless Tube 등",
                          filled: true,
                          fillColor: slate50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

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
                          hintText: "예: 1/2\", 3/8\" x 1/4\" 등",
                          filled: true,
                          fillColor: slate50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

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
                                  "안전 재고 (경고 기준)",
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
                              onPressed: () {
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

                                setState(() {
                                  materials.insert(0, {
                                    "name": nameCtrl.text.trim(),
                                    "size": sizeCtrl.text.trim(),
                                    "category": selectedCategory,
                                    "qty": int.tryParse(qtyCtrl.text) ?? 0,
                                    "min_qty":
                                        int.tryParse(minQtyCtrl.text) ?? 0,
                                    "is_dead_stock": false,
                                    "unit": selectedUnit,
                                  });
                                });
                                Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: slate50,
        appBar: AppBar(
          title: const Text(
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
              icon: const Icon(LucideIcons.search, size: 24),
              onPressed: () {},
            ),
          ],
          bottom: const TabBar(
            indicatorColor: pureWhite,
            indicatorWeight: 3,
            labelColor: pureWhite,
            unselectedLabelColor: Colors.white60,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(text: "ALL"),
              Tab(text: "TUBE"),
              Tab(text: "FITTING"),
              Tab(text: "VALVE"),
            ],
          ),
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
                  _buildFilterChip("📦 활성 자재", !_showDeadStock, () {
                    setState(() => _showDeadStock = false);
                  }),
                  const SizedBox(width: 8),
                  _buildFilterChip("⚠️ 악성/장기 재고", _showDeadStock, () {
                    setState(() => _showDeadStock = true);
                  }),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildMaterialList("ALL"),
                  _buildMaterialList("TUBE"),
                  _buildMaterialList("FITTING"),
                  _buildMaterialList("VALVE"),
                ],
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
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
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

  Widget _buildMaterialList(String category) {
    final filteredList = materials.where((m) {
      bool categoryMatch = category == "ALL" || m['category'] == category;
      bool statusMatch = m['is_dead_stock'] == _showDeadStock;
      return categoryMatch && statusMatch;
    }).toList();

    if (filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.packageOpen, size: 60, color: slate200),
            const SizedBox(height: 16),
            Text(
              _showDeadStock ? "등록된 악성 재고가 없습니다." : "해당 분류에 자재가 없습니다.",
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
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80),
      itemCount: filteredList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        int originalIndex = materials.indexOf(filteredList[index]);
        return _buildMaterialCard(materials[originalIndex], originalIndex);
      },
    );
  }

  Widget _buildMaterialCard(Map<String, dynamic> item, int index) {
    bool isLowStock = (item['qty'] < item['min_qty']) && !item['is_dead_stock'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: item['is_dead_stock'] ? slate50 : pureWhite,
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
                  color: item['is_dead_stock'] ? slate200 : slate100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getCategoryIcon(item['category']),
                  color: item['is_dead_stock'] ? slate600 : makitaTeal,
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
                            item['category'],
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
                        if (item['is_dead_stock']) ...[
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
                      item['name'],
                      style: TextStyle(
                        color: item['is_dead_stock'] ? slate600 : slate900,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        decoration: item['is_dead_stock']
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "규격: ${item['size']}  |  안전재고: ${item['min_qty']}",
                      style: const TextStyle(color: slate600, fontSize: 12),
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
                      color: item['is_dead_stock']
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
                        () => _updateQuantity(index, -1),
                      ),
                      const SizedBox(width: 8),
                      _buildQtyBtn(
                        Icons.add,
                        () => _updateQuantity(index, 1),
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
                onPressed: () => _toggleDeadStockStatus(index),
                icon: Icon(
                  item['is_dead_stock']
                      ? Icons.restore
                      : Icons.archive_outlined,
                  size: 16,
                  color: slate600,
                ),
                label: Text(
                  item['is_dead_stock'] ? "정상 재고로 복구" : "악성 재고로 격리",
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

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap, {bool isAdd = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
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
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case "TUBE":
        return Icons.line_weight;
      case "FITTING":
        return LucideIcons.gitMerge;
      case "VALVE":
        return LucideIcons.power;
      default:
        return LucideIcons.box;
    }
  }
}
