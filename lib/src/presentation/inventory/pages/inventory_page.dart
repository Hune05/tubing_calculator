import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 일관된 테마 컬러 적용
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

  // 검색 기능용 상태 변수
  bool _isSearching = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // 드롭다운 필터용 변수 및 카테고리 목록
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

  // 초기 더미 데이터 (데이터가 없을 때만 사용)
  List<Map<String, dynamic>> materials = [
    {
      "name": "Seamless Tube (SUS316L)",
      "size": "1/2\"",
      "category": "TUBE",
      "qty": 25,
      "min_qty": 10,
      "is_dead_stock": false,
      "unit": "본",
    },
    {
      "name": "Seamless Tube (SUS316L)",
      "size": "3/8\"",
      "category": "TUBE",
      "qty": 4,
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
      "name": "Ball Valve",
      "size": "1/2\"",
      "category": "VALVE",
      "qty": 20,
      "min_qty": 10,
      "is_dead_stock": false,
      "unit": "EA",
    },
    {
      "name": "Slip-on Flange (10K)",
      "size": "50A",
      "category": "FLANGE",
      "qty": 8,
      "min_qty": 10,
      "is_dead_stock": false,
      "unit": "EA",
    },
    {
      "name": "Teflon Gasket (PTFE)",
      "size": "50A",
      "category": "GASKET",
      "qty": 150,
      "min_qty": 50,
      "is_dead_stock": false,
      "unit": "EA",
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadMaterials(); // 앱 켤 때 저장된 데이터 불러오기
  }

  // 💾 데이터 불러오기 함수
  Future<void> _loadMaterials() async {
    final prefs = await SharedPreferences.getInstance();
    final String? materialsJson = prefs.getString('materials_data');

    if (materialsJson != null) {
      final List<dynamic> decodedData = jsonDecode(materialsJson);
      setState(() {
        materials = decodedData
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    }
  }

  // 💾 데이터 저장하기 함수
  Future<void> _saveMaterials() async {
    final prefs = await SharedPreferences.getInstance();
    final String materialsJson = jsonEncode(materials);
    await prefs.setString('materials_data', materialsJson);
  }

  // 수량 업데이트 및 자동 저장
  void _updateQuantity(int index, int amount) {
    setState(() {
      int currentQty = materials[index]['qty'];
      if (currentQty + amount >= 0) {
        materials[index]['qty'] = currentQty + amount;
      }
    });
    _saveMaterials(); // 🔥 변경 시 자동 저장
  }

  // 재고 상태 토글 및 자동 저장
  void _toggleDeadStockStatus(int index) {
    setState(() {
      materials[index]['is_dead_stock'] = !materials[index]['is_dead_stock'];
    });
    _saveMaterials(); // 🔥 변경 시 자동 저장
  }

  // 신규 자재 추가 팝업
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
                                      dropdownColor: pureWhite, // 🔥 배경색 강제 지정
                                      style: const TextStyle(
                                        color: slate900,
                                        fontSize: 14,
                                      ), // 🔥 글자색 강제 지정
                                      items: addCategories.map((String value) {
                                        return DropdownMenuItem<String>(
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
                                      dropdownColor: pureWhite, // 🔥 배경색 강제 지정
                                      style: const TextStyle(
                                        color: slate900,
                                        fontSize: 14,
                                      ), // 🔥 글자색 강제 지정
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
                                _saveMaterials(); // 🔥 자재 추가 후 자동 저장
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
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
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
          // 필터 및 카테고리 영역
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
                        dropdownColor: pureWhite, // 🔥 배경색 흰색 고정
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: slate600,
                          size: 20,
                        ),
                        style: const TextStyle(
                          color: slate900,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ), // 🔥 글자색 진한 남색 고정
                        items: _categories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedFilterCategory = val!;
                          });
                        },
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

          Expanded(child: _buildMaterialList()),
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

  Widget _buildMaterialList() {
    final filteredList = materials.where((m) {
      bool categoryMatch =
          _selectedFilterCategory == "ALL" ||
          m['category'] == _selectedFilterCategory;
      bool statusMatch = m['is_dead_stock'] == _showDeadStock;
      bool searchMatch =
          _searchQuery.isEmpty ||
          m['name'].toString().toLowerCase().contains(_searchQuery) ||
          m['size'].toString().toLowerCase().contains(_searchQuery);

      return categoryMatch && statusMatch && searchMatch;
    }).toList();

    if (filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.packageOpen, size: 60, color: slate200),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? "검색 결과가 없습니다."
                  : (_showDeadStock ? "등록된 악성 재고가 없습니다." : "해당 분류에 자재가 없습니다."),
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
