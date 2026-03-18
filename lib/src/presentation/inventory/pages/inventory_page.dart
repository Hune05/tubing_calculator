import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

const Color makitaTeal = Color(0xFF007580);
const Color makitaDark = Color(0xFF004D54);
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
  int _currentTabIndex = 0;
  int _logTabIndex = 0;

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
  final CollectionReference _logsDb = FirebaseFirestore.instance.collection(
    'inventory_logs',
  );

  void _updateQuantity(String docId, int currentQty, int amount) {
    if (currentQty + amount >= -9999) {
      _inventoryDb.doc(docId).update({'qty': currentQty + amount});
    }
  }

  void _toggleDeadStockStatus(String docId, bool currentStatus) {
    _inventoryDb.doc(docId).update({'is_dead_stock': !currentStatus});
  }

  Future<void> _confirmDelete(String docId, String itemName) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text(
              "자재 삭제",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: slate900,
              ),
            ),
          ],
        ),
        content: Text(
          "'$itemName'을(를) 재고 목록에서 완전히 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.",
          style: const TextStyle(color: slate600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              "취소",
              style: TextStyle(color: slate600, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "삭제",
              style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) await _inventoryDb.doc(docId).delete();
  }

  // 🚀 [핵심 수정] 출고 내역 삭제 시, 완벽하게 통합된 고유 이름표(material_name) 하나만으로 정확하게 복구합니다.
  Future<void> _confirmDeleteLog(
    String docId,
    Map<String, dynamic> logData,
  ) async {
    String type = logData['type'] ?? 'OUT';
    int qty = logData['qty'] ?? logData['deducted_qty'] ?? 0;
    String materialName = logData['material_name'] ?? "";

    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade600),
            const SizedBox(width: 8),
            Text(
              type == 'OUT' ? "출고 내역 삭제" : "입고 내역 삭제",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: slate900,
              ),
            ),
          ],
        ),
        content: Text(
          "이 기록을 삭제하시겠습니까?\n\n💡 삭제 시 창고 전체 재고에서 수량이 자동으로 ${type == 'OUT' ? '복구(+)' : '차감(-)'} 됩니다.",
          style: const TextStyle(color: slate600, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              "취소",
              style: TextStyle(color: slate600, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "삭제 및 재고 연동",
              style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _logsDb.doc(docId).delete();

      if (materialName.isNotEmpty && qty > 0) {
        try {
          // 💡 오직 고유한 이름표(material_name = "[제조사] 규격 자재명")로만 매칭합니다. 제조사나 규격 꼬일 일이 0%가 됩니다.
          final snapshot = await _inventoryDb
              .where('name', isEqualTo: materialName)
              .limit(1)
              .get();

          if (snapshot.docs.isNotEmpty) {
            final doc = snapshot.docs.first;
            final currentQty = doc['qty'] ?? 0;
            int newQty = type == 'OUT' ? currentQty + qty : currentQty - qty;
            await _inventoryDb.doc(doc.id).update({'qty': newQty});
          }
        } catch (e) {
          debugPrint("재고 연동 실패: $e");
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ 내역이 삭제되고 창고 재고가 연동되었습니다."),
            backgroundColor: slate600,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // 🚀 [핵심 수정] 수기 입/출고 등록 시 "제조사", "규격", "자재명"을 조합하여 고유한 db_name을 생성합니다.
  void _showAddLogSheet() {
    bool isOutbound = false;
    final TextEditingController projectCtrl = TextEditingController();
    final TextEditingController makerCtrl = TextEditingController(
      text: "SWAGELOK",
    ); // 💡 제조사 필수화
    final TextEditingController materialCtrl = TextEditingController();
    final TextEditingController sizeCtrl = TextEditingController();
    final TextEditingController qtyCtrl = TextEditingController(text: "1");

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
                        "입고 / 출고 수기 등록",
                        style: TextStyle(
                          color: slate900,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setSheetState(() => isOutbound = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: !isOutbound ? makitaTeal : slate100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: !isOutbound
                                        ? makitaTeal
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "입고 (반납/입고)",
                                  style: TextStyle(
                                    color: !isOutbound ? pureWhite : slate600,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setSheetState(() => isOutbound = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isOutbound
                                      ? Colors.red.shade500
                                      : slate100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isOutbound
                                        ? Colors.red.shade500
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "출고 (사용/반출)",
                                  style: TextStyle(
                                    color: isOutbound ? pureWhite : slate600,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildPopupLabel("관련 프로젝트명"),
                      _buildPopupTextField(
                        projectCtrl,
                        "예: MAIN LINE #1 (또는 '신규 입고')",
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildPopupDropdown(
                            "카테고리",
                            selectedCategory,
                            addCategories,
                            (val) => setSheetState(() {
                              selectedCategory = val!;
                              // 💡 TUBE면 강제로 '본'으로 락(Lock)
                              if (val == "TUBE") selectedUnit = "본";
                            }),
                          ),
                          const SizedBox(width: 12),
                          _buildPopupDropdown(
                            "단위 (Unit)",
                            selectedUnit,
                            ["EA", "본", "BOX", "M", "SET"],
                            (val) => setSheetState(() {
                              if (selectedCategory != "TUBE")
                                selectedUnit = val!;
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 💡 제조사 필수 입력 추가
                      _buildPopupLabel("제조사 (Maker)"),
                      _buildPopupTextField(makerCtrl, "예: Swagelok, Parker 등"),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPopupLabel("규격 (Size)"),
                                _buildPopupTextField(sizeCtrl, "예: 1/2\""),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPopupLabel("품명 (Description)"),
                                _buildPopupTextField(
                                  materialCtrl,
                                  "예: Union Tee",
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildPopupLabel("수량"),
                      _buildPopupTextField(qtyCtrl, "0", isNumber: true),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isOutbound
                                ? Colors.red.shade500
                                : makitaTeal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () async {
                            String proj = projectCtrl.text.trim();
                            String maker = makerCtrl.text.trim().toUpperCase();
                            String size = sizeCtrl.text.trim();
                            String mat = materialCtrl.text.trim();
                            int qty = int.tryParse(qtyCtrl.text) ?? 0;

                            // 💡 깐깐한 방어: 4가지가 완벽해야 등록 가능
                            if (maker.isEmpty ||
                                size.isEmpty ||
                                mat.isEmpty ||
                                qty <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("제조사, 규격, 품명, 수량을 모두 입력해주세요!"),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            // 🚀 [중요] 컷팅 페이지와 완전히 동일한 고유 이름표 생성
                            String combinedDbName = "[$maker] $size $mat";

                            try {
                              // 1. 로그 기록 (조합된 이름 사용)
                              await _logsDb.add({
                                "type": isOutbound ? "OUT" : "IN",
                                "project_name": proj.isEmpty ? "기타 수기등록" : proj,
                                "material_name": combinedDbName, // 고유 이름표
                                "qty": qty,
                                "unit": selectedUnit,
                                "timestamp": FieldValue.serverTimestamp(),
                              });

                              // 2. 창고에 고유 이름표(name)로 매칭하여 업데이트 또는 신규 생성
                              final snapshot = await _inventoryDb
                                  .where('name', isEqualTo: combinedDbName)
                                  .limit(1)
                                  .get();

                              if (snapshot.docs.isNotEmpty) {
                                final doc = snapshot.docs.first;
                                final currentQty = doc['qty'] ?? 0;
                                int newQty = isOutbound
                                    ? currentQty - qty
                                    : currentQty + qty;
                                await _inventoryDb.doc(doc.id).update({
                                  'qty': newQty,
                                });
                              } else {
                                // 창고에 처음 들어오는 자재라면 완벽한 규격으로 생성
                                await _inventoryDb.add({
                                  "name": combinedDbName, // 고유 이름표
                                  "size": size,
                                  "maker": maker,
                                  "raw_name": mat, // 순수 품명
                                  "category": selectedCategory,
                                  "qty": isOutbound ? -qty : qty,
                                  "min_qty": 10,
                                  "is_dead_stock": false,
                                  "unit": selectedUnit,
                                  "location": "수기 등록 확인요망",
                                  "createdAt": FieldValue.serverTimestamp(),
                                });
                              }

                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              debugPrint("수기 등록 에러: $e");
                            }
                          },
                          child: Text(
                            isOutbound ? "출고 등록" : "입고 등록",
                            style: const TextStyle(
                              color: pureWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
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

  void _showAddMaterialSheet() {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController sizeCtrl = TextEditingController();
    final TextEditingController qtyCtrl = TextEditingController(text: "0");
    final TextEditingController minQtyCtrl = TextEditingController(text: "10");
    final TextEditingController heatNoCtrl = TextEditingController();
    final TextEditingController makerCtrl = TextEditingController(
      text: "SWAGELOK",
    );
    final TextEditingController locationCtrl = TextEditingController();

    String selectedCategory = "FITTING";
    String selectedUnit = "EA";
    String selectedMaterial = "SS316";

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
                        "신규 자재 마스터 등록",
                        style: TextStyle(
                          color: slate900,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          _buildPopupDropdown(
                            "카테고리",
                            selectedCategory,
                            addCategories,
                            (val) => setSheetState(() {
                              selectedCategory = val!;
                              // 💡 TUBE 락 체결
                              if (val == "TUBE") selectedUnit = "본";
                            }),
                          ),
                          const SizedBox(width: 12),
                          _buildPopupDropdown(
                            "재질",
                            selectedMaterial,
                            materials,
                            (val) =>
                                setSheetState(() => selectedMaterial = val!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPopupLabel("제조사 (Maker)"),
                                _buildPopupTextField(makerCtrl, "예: Swagelok"),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPopupLabel("규격 (Size)"),
                                _buildPopupTextField(sizeCtrl, "예: 1/2\", 50A"),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildPopupLabel("품명 (Description)"),
                      _buildPopupTextField(
                        nameCtrl,
                        "예: Union Tee, Ball Valve 등",
                      ),
                      const SizedBox(height: 16),
                      _buildPopupLabel("보관 위치 (Location)"),
                      _buildPopupTextField(
                        locationCtrl,
                        "예: A창고-1열-3단, 선반 2번 등",
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPopupLabel("히트 번호"),
                                _buildPopupTextField(heatNoCtrl, "예: H1234"),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildPopupDropdown(
                            "단위",
                            selectedUnit,
                            ["EA", "본", "BOX", "M", "SET"],
                            (val) => setSheetState(() {
                              if (selectedCategory != "TUBE")
                                selectedUnit = val!;
                            }),
                            isSmall: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
                                String maker = makerCtrl.text
                                    .trim()
                                    .toUpperCase();
                                String size = sizeCtrl.text.trim();
                                String name = nameCtrl.text.trim();

                                if (maker.isEmpty ||
                                    size.isEmpty ||
                                    name.isEmpty)
                                  return;

                                // 🚀 완벽한 고유 이름표 생성
                                String combinedDbName = "[$maker] $size $name";

                                try {
                                  await _inventoryDb.add({
                                    "name": combinedDbName, // 고유키
                                    "size": size,
                                    "maker": maker,
                                    "raw_name": name,
                                    "category": selectedCategory,
                                    "qty": int.tryParse(qtyCtrl.text) ?? 0,
                                    "min_qty":
                                        int.tryParse(minQtyCtrl.text) ?? 0,
                                    "is_dead_stock": false,
                                    "unit": selectedUnit,
                                    "heatNo": heatNoCtrl.text
                                        .trim()
                                        .toUpperCase(),
                                    "material": selectedMaterial,
                                    "location": locationCtrl.text.trim(),
                                    "createdAt": FieldValue.serverTimestamp(),
                                  });
                                  if (context.mounted) Navigator.pop(context);
                                } catch (e) {
                                  debugPrint("Error: $e");
                                }
                              },
                              child: const Text(
                                "마스터 등록",
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
  }) => TextField(
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

  Widget _buildPopupDropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged, {
    bool isSmall = false,
  }) => Expanded(
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
                  hintText: '자재명, 규격, 제조사 검색...',
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
            padding: const EdgeInsets.only(
              top: 16,
              left: 16,
              right: 16,
              bottom: 4,
            ),
            color: slate50,
            child: Row(
              children: [
                _buildMainTabChip(
                  "전체 재고",
                  _currentTabIndex == 0,
                  () => setState(() => _currentTabIndex = 0),
                ),
                const SizedBox(width: 8),
                _buildMainTabChip(
                  "프로젝트 자재",
                  _currentTabIndex == 1,
                  () => setState(() => _currentTabIndex = 1),
                ),
              ],
            ),
          ),
          Expanded(
            child: _currentTabIndex == 0
                ? _buildMainInventoryTab()
                : _buildProjectUsageLogsTab(),
          ),
        ],
      ),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _showAddMaterialSheet,
              backgroundColor: makitaTeal,
              icon: const Icon(Icons.add, color: pureWhite),
              label: const Text(
                "자재 등록",
                style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
              ),
            )
          : FloatingActionButton.extended(
              onPressed: _showAddLogSheet,
              backgroundColor: makitaDark,
              icon: const Icon(Icons.swap_horiz, color: pureWhite),
              label: const Text(
                "수기 입출고",
                style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
              ),
            ),
    );
  }

  Widget _buildMainTabChip(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 46,
          decoration: BoxDecoration(
            color: isSelected ? makitaTeal : pureWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? makitaTeal : Colors.grey.shade300,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: makitaTeal.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? pureWhite : slate600,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
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

  Widget _buildMainInventoryTab() {
    return Column(
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
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
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
              if (snapshot.hasError) return const Center(child: Text("에러 발생"));
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
                bool statusMatch =
                    (data['is_dead_stock'] ?? false) == _showDeadStock;

                // 검색 강화 (이름, 규격, 메이커 모두 검색)
                String fullName = data['name'].toString().toLowerCase();
                String maker = (data['maker'] ?? "").toString().toLowerCase();
                String size = (data['size'] ?? "").toString().toLowerCase();
                bool searchMatch =
                    fullName.contains(_searchQuery) ||
                    maker.contains(_searchQuery) ||
                    size.contains(_searchQuery);

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
    );
  }

  Widget _buildProjectUsageLogsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: slate200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _logTabIndex = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _logTabIndex == 0
                            ? pureWhite
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "출고 내역 (-)",
                        style: TextStyle(
                          color: _logTabIndex == 0
                              ? Colors.red.shade600
                              : slate600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _logTabIndex = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _logTabIndex == 1
                            ? pureWhite
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "입고/반납 내역 (+)",
                        style: TextStyle(
                          color: _logTabIndex == 1 ? makitaTeal : slate600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _logsDb.orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text("에러 발생"));
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(
                  child: CircularProgressIndicator(color: makitaTeal),
                );

              final docs = snapshot.data!.docs;

              final filteredDocs = docs.where((doc) {
                final log = doc.data() as Map<String, dynamic>;
                final String type = log['type'] ?? 'OUT';
                if (_logTabIndex == 0) return type == 'OUT';
                if (_logTabIndex == 1) return type == 'IN';
                return true;
              }).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.packageOpen,
                        size: 60,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _logTabIndex == 0
                            ? "프로젝트 출고 내역이 없습니다."
                            : "프로젝트 입고(반납) 내역이 없습니다.",
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
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: filteredDocs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final logId = filteredDocs[index].id;
                  final log =
                      filteredDocs[index].data() as Map<String, dynamic>;
                  final Timestamp? ts = log['timestamp'] as Timestamp?;
                  final String dateStr = ts != null
                      ? "${ts.toDate().month}/${ts.toDate().day} ${ts.toDate().hour.toString().padLeft(2, '0')}:${ts.toDate().minute.toString().padLeft(2, '0')}"
                      : "방금 전";

                  bool isOut = (log['type'] ?? 'OUT') == 'OUT';
                  int qty = log['qty'] ?? log['deducted_qty'] ?? 0;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: isOut
                          ? Colors.red.shade50
                          : makitaTeal.withValues(alpha: 0.1),
                      child: Icon(
                        isOut
                            ? LucideIcons.arrowUpRight
                            : LucideIcons.arrowDownLeft,
                        color: isOut ? Colors.red.shade400 : makitaTeal,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      log['material_name'] ?? '알 수 없는 자재',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: slate900,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Row(
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
                              log['project_name'] ?? '프로젝트 미상',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: slate900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 12,
                              color: slate600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${isOut ? '-' : '+'} $qty ${log['unit'] ?? 'EA'}",
                          style: TextStyle(
                            color: isOut ? Colors.red.shade600 : makitaTeal,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.grey,
                            size: 22,
                          ),
                          onPressed: () => _confirmDeleteLog(logId, log),
                          tooltip: "내역 삭제",
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialCard(String docId, Map<String, dynamic> item) {
    final bool isLowStock = (item['qty'] ?? 0) < (item['min_qty'] ?? 10);
    final bool isDeadStock = item['is_dead_stock'] ?? false;
    final bool isNegative = (item['qty'] ?? 0) < 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDeadStock
            ? slate50
            : (isNegative ? Colors.red.shade50 : pureWhite),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNegative
              ? Colors.red.shade400
              : (isLowStock ? Colors.orange.shade300 : Colors.grey.shade300),
          width: isLowStock || isNegative ? 1.5 : 1.0,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item['name'] ??
                                "이름 없음", // 💡 [Swagelok] 1/2 밸브 형태로 출력됨
                            style: const TextStyle(
                              color: slate900,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 30,
                          height: 24,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.more_vert,
                              color: slate600,
                              size: 20,
                            ),
                            onSelected: (value) {
                              if (value == 'dead_stock')
                                _toggleDeadStockStatus(docId, isDeadStock);
                              else if (value == 'delete')
                                _confirmDelete(docId, item['name'] ?? "이 자재");
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'dead_stock',
                                child: Text(
                                  isDeadStock ? "가용 자재로 복구" : "장기 미사용 처리",
                                  style: const TextStyle(
                                    color: slate900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  "삭제하기",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "분류: ${item['category']} | 재질: ${item['material'] ?? '-'}",
                      style: const TextStyle(color: slate600, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if ((item['location'] ?? "").isNotEmpty)
                          _buildBadge(
                            Icons.location_on,
                            item['location'],
                            Colors.orange.shade700,
                          ),
                        if ((item['heatNo'] ?? "").isNotEmpty)
                          _buildBadge(
                            Icons.tag,
                            "Heat: ${item['heatNo']}",
                            Colors.green,
                          ),
                        if (isNegative)
                          _buildBadge(
                            Icons.warning,
                            "임시 생성 (입고 확인 요망)",
                            Colors.red.shade700,
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
                      color: isNegative
                          ? Colors.red.shade700
                          : (isLowStock ? Colors.orange.shade700 : makitaTeal),
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
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withValues(alpha: 0.3)),
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
        color: isAdd ? makitaTeal.withValues(alpha: 0.1) : slate100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isAdd ? makitaTeal.withValues(alpha: 0.3) : slate200,
        ),
      ),
      child: Icon(icon, size: 18, color: isAdd ? makitaTeal : slate600),
    ),
  );

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case "TUBE":
        return Icons.view_stream_rounded;
      case "FITTING":
        return Icons.call_split;
      case "VALVE":
        return Icons.settings_input_component;
      case "FLANGE":
        return Icons.donut_large;
      case "GASKET":
        return Icons.circle_outlined;
      default:
        return Icons.hardware;
    }
  }
}
