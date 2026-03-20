import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

const Color makitaTeal = Color(0xFF007580);
const Color makitaDark = Color(0xFF004D54);
const Color slate900 = Color(0xFF0F172A);
const Color slate800 = Color(0xFF1E293B);
const Color slate700 = Color(0xFF334155);
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
  bool _isSearching = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  int _stockFilterStatus = 0;

  String _selectedFilterCategory = "ALL";
  String _selectedFilterMaker = "ALL";

  final List<String> _categories = [
    "ALL",
    "TUBE",
    "FITTING",
    "VALVE",
    "FLANGE",
    "기타",
  ];
  final List<String> _makers = ["ALL", "HY-LOK", "SWAGELOK", "PARKER", "기타"];

  final CollectionReference _inventoryDb = FirebaseFirestore.instance
      .collection('inventory');
  final CollectionReference _projectInventoryDb = FirebaseFirestore.instance
      .collection('project_inventory');
  final CollectionReference _logsDb = FirebaseFirestore.instance.collection(
    'inventory_logs',
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateItemStatus(String docId, String status) {
    bool isDead = (status != "정상");
    _inventoryDb.doc(docId).update({'status': status, 'is_dead_stock': isDead});
  }

  void _toggleReorderStatus(String docId, bool currentStatus) {
    _inventoryDb.doc(docId).update({'is_reorder_needed': !currentStatus});
  }

  // ===========================================================================
  // 💡 [액션 1] 신규 마스터 등록
  // ===========================================================================
  void _showAddMaterialSheet() {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController sizeCtrl = TextEditingController();
    final TextEditingController qtyCtrl = TextEditingController(text: "0");
    final TextEditingController makerCtrl = TextEditingController(
      text: "HY-LOK",
    );
    final TextEditingController heatNoCtrl = TextEditingController();
    final TextEditingController locationCtrl = TextEditingController();

    String selectedCategory = "FITTING";
    String selectedUnit = "EA";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
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
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: slate900,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(LucideIcons.camera, color: pureWhite),
                      label: const Text(
                        "📷 도면/BOM 사진 찍어서 자동 입력 (준비중)",
                        style: TextStyle(
                          color: pureWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("스마트폰 카메라 연동 패키지 설치 후 활성화됩니다."),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "또는 직접 수동 입력",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: slate600,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    "제조사 퀵 선택",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: makitaTeal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ["HY-LOK", "SWAGELOK", "PARKER"]
                        .map(
                          (m) => ActionChip(
                            label: Text(m),
                            backgroundColor: makerCtrl.text == m
                                ? makitaTeal
                                : slate100,
                            labelStyle: TextStyle(
                              color: makerCtrl.text == m ? pureWhite : slate900,
                              fontWeight: FontWeight.bold,
                            ),
                            onPressed: () {
                              setSheetState(() {
                                makerCtrl.text = m;
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildPopupDropdown(
                        "카테고리",
                        selectedCategory,
                        _categories.where((c) => c != "ALL").toList(),
                        (v) {
                          setSheetState(() {
                            selectedCategory = v!;
                            if (v == "TUBE") selectedUnit = "본";
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      _buildPopupDropdown(
                        "단위",
                        selectedUnit,
                        ["EA", "본", "BOX", "M"],
                        (v) {
                          setSheetState(() {
                            if (selectedCategory != "TUBE") selectedUnit = v!;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildInputLabelField(
                          "제조사 (수동)",
                          makerCtrl,
                          "HY-LOK",
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _buildInputLabelField(
                          "규격 (Size)",
                          sizeCtrl,
                          "예: 1/2\"",
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInputLabelField("품명", nameCtrl, "예: Union Tee"),
                  const SizedBox(height: 16),
                  _buildInputLabelField(
                    "보관 위치 (Location)",
                    locationCtrl,
                    "예: 랙 A-1열, 튜빙 야적장 등",
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildInputLabelField(
                          "히트 넘버 (Heat No.)",
                          heatNoCtrl,
                          "미기재 시 생략",
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _buildInputLabelField(
                          "초기 수량",
                          qtyCtrl,
                          "0",
                          isNumber: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: makitaTeal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        if (nameCtrl.text.isEmpty ||
                            sizeCtrl.text.isEmpty ||
                            makerCtrl.text.isEmpty) {
                          return;
                        }

                        String fullName =
                            "[${makerCtrl.text}] ${sizeCtrl.text} ${nameCtrl.text}";
                        if (heatNoCtrl.text.isNotEmpty) {
                          fullName += " (H:${heatNoCtrl.text})";
                        }

                        await _inventoryDb.add({
                          "name": fullName,
                          "maker": makerCtrl.text,
                          "size": sizeCtrl.text,
                          "raw_name": nameCtrl.text,
                          "category": selectedCategory,
                          "heatNo": heatNoCtrl.text,
                          "location": locationCtrl.text,
                          "qty": int.tryParse(qtyCtrl.text) ?? 0,
                          "min_qty": 10,
                          "unit": selectedUnit,
                          "status": "정상",
                          "is_dead_stock": false,
                          "is_reorder_needed": false,
                          "createdAt": FieldValue.serverTimestamp(),
                        });

                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text(
                        "자재등록 완료",
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
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 💡 [액션 2] 자재 보관함 -> 현장 불출 OR 신규 입고
  // ===========================================================================
  void _showMainStockActionDialog({
    required bool isDispatch,
    required String docId,
    required Map<String, dynamic> item,
  }) {
    final TextEditingController qtyCtrl = TextEditingController();
    final TextEditingController projCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(
              isDispatch ? LucideIcons.truck : LucideIcons.packagePlus,
              color: isDispatch ? Colors.orange.shade800 : makitaTeal,
            ),
            const SizedBox(width: 8),
            Text(
              isDispatch ? "현장 불출 (출고)" : "신규 입고 (+)",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: slate900,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "[ ${item['name']} ]",
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: slate900,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 16),
            if (isDispatch) ...[
              const Text(
                "투입할 프로젝트",
                style: TextStyle(
                  fontSize: 13,
                  color: slate700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: projCtrl,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: slate900,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: slate50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              "수량",
              style: TextStyle(
                fontSize: 13,
                color: slate700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: slate900,
              ),
              decoration: InputDecoration(
                suffixText: item['unit'] ?? "EA",
                filled: true,
                fillColor: slate50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "취소",
              style: TextStyle(color: slate700, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDispatch ? Colors.orange.shade800 : makitaTeal,
            ),
            onPressed: () async {
              int qty = int.tryParse(qtyCtrl.text) ?? 0;
              String proj = projCtrl.text.trim();
              if (qty <= 0 || (isDispatch && proj.isEmpty)) return;

              try {
                int currentQty = item['qty'] ?? 0;
                int newWarehouseQty = isDispatch
                    ? currentQty - qty
                    : currentQty + qty;

                await _inventoryDb.doc(docId).update({'qty': newWarehouseQty});

                if (isDispatch) {
                  final snapshot = await _projectInventoryDb
                      .where('project_name', isEqualTo: proj)
                      .where('material_name', isEqualTo: item['name'])
                      .limit(1)
                      .get();
                  if (snapshot.docs.isNotEmpty) {
                    int pQty = snapshot.docs.first['qty'] ?? 0;
                    await _projectInventoryDb
                        .doc(snapshot.docs.first.id)
                        .update({'qty': pQty + qty});
                  } else {
                    await _projectInventoryDb.add({
                      'project_name': proj,
                      'material_name': item['name'],
                      'category': item['category'],
                      'unit': item['unit'],
                      'heatNo': item['heatNo'] ?? "",
                      'location': item['location'] ?? "",
                      'qty': qty,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  }
                }

                await _logsDb.add({
                  'type': isDispatch ? 'OUT' : 'IN',
                  'project_name': isDispatch ? proj : '자재 보관함 입고',
                  'material_name': item['name'],
                  'qty': qty,
                  'unit': item['unit'],
                  'timestamp': FieldValue.serverTimestamp(),
                });

                if (context.mounted) Navigator.pop(ctx);
              } catch (e) {
                debugPrint("Error: $e");
              }
            },
            child: Text(
              isDispatch ? "불출 완료" : "입고 완료",
              style: const TextStyle(
                color: pureWhite,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 💡 [액션 3] 현장 자재 -> 자재 보관함으로 반납
  // ===========================================================================
  void _showProjectReturnDialog({
    required String docId,
    required Map<String, dynamic> pItem,
  }) {
    final TextEditingController qtyCtrl = TextEditingController();
    String returnStatus = "테스트용";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Row(
            children: [
              Icon(LucideIcons.cornerDownLeft, color: makitaTeal),
              SizedBox(width: 8),
              Text(
                "자재 보관함 반납",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: slate900,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "출발 프로젝트: ${pItem['project_name']}",
                style: const TextStyle(
                  color: slate700,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "[ ${pItem['material_name']} ]",
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: slate900,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: slate900,
                ),
                decoration: InputDecoration(
                  hintText: "최대 ${pItem['qty']}",
                  suffixText: pItem['unit'],
                  filled: true,
                  fillColor: slate50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: slate50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "반납 자재 상태 (용도 지정)",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: slate900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildReturnRadio(
                      returnStatus,
                      "테스트용",
                      "테스트/막배관 전용 (B급)",
                      Colors.blue,
                      (v) => setDialogState(() => returnStatus = v),
                    ),
                    _buildReturnRadio(
                      returnStatus,
                      "특수보관",
                      "안 쓰지만 희귀 부속 (킵)",
                      Colors.green.shade700,
                      (v) => setDialogState(() => returnStatus = v),
                    ),
                    _buildReturnRadio(
                      returnStatus,
                      "정상",
                      "A급 신품 (본 재고 합침)",
                      makitaTeal,
                      (v) => setDialogState(() => returnStatus = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                "취소",
                style: TextStyle(color: slate700, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: makitaTeal),
              onPressed: () async {
                int qty = int.tryParse(qtyCtrl.text) ?? 0;
                int currentProjQty = pItem['qty'] ?? 0;

                if (qty <= 0 || qty > currentProjQty) return;

                try {
                  int newProjQty = currentProjQty - qty;
                  if (newProjQty == 0) {
                    await _projectInventoryDb.doc(docId).delete();
                  } else {
                    await _projectInventoryDb.doc(docId).update({
                      'qty': newProjQty,
                    });
                  }

                  String targetMatName = pItem['material_name'];
                  if (returnStatus != "정상" &&
                      !targetMatName.contains("($returnStatus)")) {
                    targetMatName = "$targetMatName ($returnStatus)";
                  }

                  final snapshot = await _inventoryDb
                      .where('name', isEqualTo: targetMatName)
                      .limit(1)
                      .get();
                  if (snapshot.docs.isNotEmpty) {
                    int wQty = snapshot.docs.first['qty'] ?? 0;
                    await _inventoryDb.doc(snapshot.docs.first.id).update({
                      'qty': wQty + qty,
                    });
                  } else {
                    await _inventoryDb.add({
                      "name": targetMatName,
                      "category": pItem['category'],
                      "maker": pItem['maker'] ?? "알수없음",
                      "heatNo": pItem['heatNo'] ?? "",
                      "location": pItem['location'] ?? "반납/위치미상",
                      "qty": qty,
                      "min_qty": 0,
                      "status": returnStatus,
                      "is_dead_stock": returnStatus != "정상",
                      "is_reorder_needed": false,
                      "unit": pItem['unit'],
                      "createdAt": FieldValue.serverTimestamp(),
                    });
                  }

                  await _logsDb.add({
                    'type': 'RETURN',
                    'project_name': pItem['project_name'],
                    'material_name': targetMatName,
                    'qty': qty,
                    'unit': pItem['unit'],
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) Navigator.pop(ctx);
                } catch (e) {
                  debugPrint("Error: $e");
                }
              },
              child: const Text(
                "반납 완료",
                style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnRadio(
    String groupValue,
    String value,
    String label,
    Color color,
    Function(String) onChanged,
  ) {
    return InkWell(
      onTap: () => onChanged(value),
      child: Row(
        children: [
          Radio<String>(
            activeColor: color,
            value: value,
            groupValue: groupValue,
            onChanged: (v) => onChanged(v!),
          ),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: groupValue == value ? color : slate700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 💡 [액션 4] 기록 삭제 다이얼로그 (주기별 소거)
  // ===========================================================================
  void _showDeleteLogsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(LucideIcons.trash2, color: slate900),
            SizedBox(width: 8),
            Text(
              "기록 정리",
              style: TextStyle(fontWeight: FontWeight.w900, color: slate900),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "오래된 입출고 및 실사 기록을 삭제합니다.\n삭제된 데이터는 복구할 수 없습니다.",
              style: TextStyle(color: slate600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _buildLogDeleteOption(ctx, "1주일 이전 기록 삭제", 7),
            _buildLogDeleteOption(ctx, "보름(15일) 이전 기록 삭제", 15),
            _buildLogDeleteOption(ctx, "1개월 이전 기록 삭제", 30),
            _buildLogDeleteOption(ctx, "1분기(90일) 이전 기록 삭제", 90),
            const Divider(height: 24),
            _buildLogDeleteOption(ctx, "전체 기록 일괄 삭제", 0, isAll: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "취소",
              style: TextStyle(color: slate700, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogDeleteOption(
    BuildContext ctx,
    String label,
    int days, {
    bool isAll = false,
  }) {
    return InkWell(
      onTap: () async {
        Navigator.pop(ctx);
        try {
          DateTime cutoff = DateTime.now().subtract(Duration(days: days));
          var snapshot = await _logsDb.get();

          WriteBatch batch = FirebaseFirestore.instance.batch();
          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final ts = data['timestamp'] as Timestamp?;
            if (ts != null) {
              if (isAll || ts.toDate().isBefore(cutoff)) {
                batch.delete(doc.reference);
              }
            } else if (isAll) {
              batch.delete(doc.reference);
            }
          }
          await batch.commit();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("선택한 주기의 기록이 삭제되었습니다.")),
            );
          }
        } catch (e) {
          debugPrint("기록 삭제 오류: $e");
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(
              isAll ? LucideIcons.alertTriangle : LucideIcons.calendarX,
              size: 18,
              color: isAll ? Colors.red.shade600 : slate700,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isAll ? Colors.red.shade600 : slate900,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 💡 [액션 5] 재고 실사 및 수량 보정 (Audit)
  // ===========================================================================
  void _showAdjustmentDialog({
    required String docId,
    required Map<String, dynamic> item,
  }) {
    final TextEditingController physicalQtyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(LucideIcons.scale, color: slate900),
            SizedBox(width: 8),
            Text(
              "재고 실사 (수량 보정)",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: slate900,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "[ ${item['name']} ]",
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: slate900,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: slate50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "현재 전산 수량:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: slate700,
                    ),
                  ),
                  Text(
                    "${item['qty']} ${item['unit']}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: makitaTeal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "실제 보관함 수량 (Physical Qty)",
              style: TextStyle(
                fontSize: 13,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: physicalQtyCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: slate900,
              ),
              decoration: InputDecoration(
                hintText: "실제 개수 입력",
                suffixText: item['unit'] ?? "EA",
                filled: true,
                fillColor: slate50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "취소",
              style: TextStyle(color: slate700, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: slate900),
            onPressed: () async {
              int physicalQty = int.tryParse(physicalQtyCtrl.text) ?? -1;
              if (physicalQty < 0) return;

              int systemQty = item['qty'] ?? 0;
              int diff = physicalQty - systemQty;

              if (diff == 0) {
                Navigator.pop(ctx);
                return;
              }

              try {
                await _inventoryDb.doc(docId).update({'qty': physicalQty});

                await _logsDb.add({
                  'type': 'AUDIT',
                  'project_name': '정기 재고 실사 보정',
                  'material_name': item['name'],
                  'qty': diff.abs(),
                  'sign': diff > 0 ? '+' : '-',
                  'unit': item['unit'],
                  'timestamp': FieldValue.serverTimestamp(),
                });

                if (context.mounted) Navigator.pop(ctx);
              } catch (e) {
                debugPrint("Error: $e");
              }
            },
            child: const Text(
              "보정 완료",
              style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // UI BUILDER
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slate50,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: pureWhite, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: '자재명, 규격 검색...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (v) =>
                    setState(() => _searchQuery = v.toLowerCase()),
              )
            : const Text(
                '자재 보관함 관리',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
        backgroundColor: makitaTeal,
        foregroundColor: pureWhite,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : LucideIcons.search),
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            color: pureWhite,
            child: Row(
              children: [
                _buildTab("자재 보관함", 0),
                const SizedBox(width: 4),
                _buildTab("현장 자재", 1),
                const SizedBox(width: 4),
                _buildTab("기록(Log)", 2),
                const SizedBox(width: 4),
                _buildTab("보관 가이드", 3),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _currentTabIndex,
              children: [
                _buildMainInventoryTab(),
                _buildProjectInventoryTab(),
                _buildLogsTab(),
                _buildStorageGuideTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _showAddMaterialSheet,
              backgroundColor: makitaDark,
              label: const Text(
                "신규 자재 등록",
                style: TextStyle(
                  color: pureWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              icon: const Icon(Icons.add, color: pureWhite),
            )
          : null,
    );
  }

  Widget _buildTab(String label, int index) {
    bool isSel = _currentTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTabIndex = index),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: isSel ? makitaTeal : slate100,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSel ? makitaTeal : Colors.grey.shade400,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSel ? pureWhite : slate700,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.visible,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 탭 1: 가용 자재 (자재 보관함)
  // ---------------------------------------------------------------------------
  Widget _buildMainInventoryTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: pureWhite,
            border: Border(bottom: BorderSide(color: slate200)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildSimpleDropdown(
                      "카테고리",
                      _selectedFilterCategory,
                      _categories,
                      (v) {
                        setState(() {
                          _selectedFilterCategory = v!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSimpleDropdown(
                      "제조사",
                      _selectedFilterMaker,
                      _makers,
                      (v) {
                        setState(() {
                          _selectedFilterMaker = v!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStatusChip(
                    "가용 재고",
                    _stockFilterStatus == 0,
                    () => setState(() => _stockFilterStatus = 0),
                  ),
                  const SizedBox(width: 6),
                  _buildStatusChip(
                    "추가 발주",
                    _stockFilterStatus == 1,
                    () => setState(() => _stockFilterStatus = 1),
                  ),
                  const SizedBox(width: 6),
                  _buildStatusChip(
                    "장기 미사용",
                    _stockFilterStatus == 2,
                    () => setState(() => _stockFilterStatus = 2),
                  ),
                ],
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
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: makitaTeal),
                );
              }

              final docs = snapshot.data!.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                bool catMatch =
                    _selectedFilterCategory == "ALL" ||
                    data['category'] == _selectedFilterCategory;
                bool makerMatch =
                    _selectedFilterMaker == "ALL" ||
                    data['maker'] == _selectedFilterMaker;

                bool isDead = data['is_dead_stock'] == true;
                bool isReorder = data['is_reorder_needed'] == true;

                bool statusMatch = false;
                if (_stockFilterStatus == 0) {
                  statusMatch = !isDead && !isReorder;
                } else if (_stockFilterStatus == 1) {
                  statusMatch = !isDead && isReorder;
                } else if (_stockFilterStatus == 2) {
                  statusMatch = isDead;
                }

                return catMatch &&
                    makerMatch &&
                    statusMatch &&
                    data['name'].toString().toLowerCase().contains(
                      _searchQuery,
                    );
              }).toList();

              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    "조건에 맞는 자재가 없습니다.",
                    style: TextStyle(
                      color: slate700,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16).copyWith(bottom: 80),
                itemCount: docs.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, idx) => _buildMaterialCard(
                  docs[idx].id,
                  docs[idx].data() as Map<String, dynamic>,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuRow(
    String value,
    IconData icon,
    String text, {
    Color color = slate900,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialCard(String id, Map<String, dynamic> item) {
    String status = item['status'] ?? "정상";
    Color statusColor;
    if (status == "폐기대기") {
      statusColor = Colors.red;
    } else if (status == "테스트용") {
      statusColor = Colors.blue;
    } else if (status == "특수보관") {
      statusColor = Colors.green.shade700;
    } else {
      statusColor = Colors.purple;
    }

    bool isDead = item['is_dead_stock'] ?? false;
    bool isReorder = item['is_reorder_needed'] ?? false;
    String heatNo = item['heatNo'] ?? "";
    String location = item['location'] ?? "";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDead ? statusColor.withValues(alpha: 0.05) : pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDead
              ? statusColor.withValues(alpha: 0.5)
              : (isReorder ? Colors.orange.shade500 : slate200),
          width: isDead || isReorder ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                item['category'] ?? "기타",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: makitaTeal,
                ),
              ),
              if (isDead) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      color: pureWhite,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              if (!isDead && isReorder) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "추가 발주 요청됨",
                    style: TextStyle(
                      color: pureWhite,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 22, color: slate600),
                color: pureWhite,
                surfaceTintColor: pureWhite,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onSelected: (v) {
                  if (v == 'audit') {
                    _showAdjustmentDialog(docId: id, item: item);
                  } else if (v == 'reorder') {
                    _toggleReorderStatus(id, isReorder);
                  } else if (v == 'test') {
                    _updateItemStatus(id, "테스트용");
                  } else if (v == 'keep') {
                    _updateItemStatus(id, "특수보관");
                  } else if (v == 'scrap') {
                    _updateItemStatus(id, "폐기대기");
                  } else if (v == 'normal') {
                    _updateItemStatus(id, "정상");
                    _inventoryDb.doc(id).update({'is_reorder_needed': false});
                  } else if (v == 'delete') {
                    _inventoryDb.doc(id).delete();
                  }
                },
                itemBuilder: (ctx) => [
                  if (!isDead)
                    _buildMenuRow(
                      'reorder',
                      LucideIcons.alertCircle,
                      isReorder ? "발주 완료 (요청 해제)" : "추가 발주 요청하기",
                      color: isReorder ? slate900 : Colors.orange.shade700,
                    ),
                  if (!isDead)
                    const PopupMenuItem(
                      value: '',
                      enabled: false,
                      height: 1,
                      child: Divider(),
                    ),
                  _buildMenuRow('audit', LucideIcons.scale, "재고 실사 (수량 보정)"),
                  const PopupMenuItem(
                    value: '',
                    enabled: false,
                    height: 1,
                    child: Divider(),
                  ),
                  if (isDead)
                    _buildMenuRow(
                      'normal',
                      LucideIcons.checkCircle,
                      "가용 자재로 복구",
                    ),
                  if (!isDead || status != '특수보관')
                    _buildMenuRow(
                      'keep',
                      LucideIcons.archive,
                      "특수보관 (희귀 부속 킵)",
                    ),
                  if (!isDead || status != '테스트용')
                    _buildMenuRow('test', LucideIcons.beaker, "테스트용/막배관 전환"),
                  if (!isDead || status != '폐기대기')
                    _buildMenuRow(
                      'scrap',
                      LucideIcons.trash2,
                      "폐기 대기로 분류",
                      color: Colors.red.shade600,
                    ),
                  const PopupMenuItem(
                    value: '',
                    enabled: false,
                    height: 1,
                    child: Divider(),
                  ),
                  _buildMenuRow(
                    'delete',
                    LucideIcons.xCircle,
                    "마스터 영구 삭제",
                    color: Colors.red.shade700,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item['name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: slate900,
                    height: 1.3,
                  ),
                ),
              ),
              Text(
                "${item['qty']} ${item['unit']}",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: isDead ? statusColor : makitaTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (location.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 12,
                        color: Colors.orange.shade800,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        location,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              if (heatNo.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tag, size: 12, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        "Heat: $heatNo",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                  "보관함 입고",
                  LucideIcons.packagePlus,
                  makitaTeal,
                  () => _showMainStockActionDialog(
                    isDispatch: false,
                    docId: id,
                    item: item,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  "현장 불출",
                  LucideIcons.truck,
                  Colors.orange.shade800,
                  () => _showMainStockActionDialog(
                    isDispatch: true,
                    docId: id,
                    item: item,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 탭 2: 현장 자재
  // ---------------------------------------------------------------------------
  Widget _buildProjectInventoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _projectInventoryDb
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: makitaTeal),
          );
        }
        final docs = snapshot.data!.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['project_name'].toString().toLowerCase().contains(
                _searchQuery,
              ) ||
              data['material_name'].toString().toLowerCase().contains(
                _searchQuery,
              );
        }).toList();

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "현장에 나가 있는 자재가 없습니다.",
              style: TextStyle(
                color: slate700,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            String heatNo = data['heatNo'] ?? "";

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueGrey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: makitaTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: makitaTeal.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      "${data['project_name']}",
                      style: const TextStyle(
                        color: makitaDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          data['material_name'] ?? "이름 없음",
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            color: slate900,
                            height: 1.3,
                          ),
                        ),
                      ),
                      Text(
                        "${data['qty']} ${data['unit']}",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                          color: Colors.blueGrey.shade800,
                        ),
                      ),
                    ],
                  ),
                  if (heatNo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "Heat No: $heatNo",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pureWhite,
                        foregroundColor: makitaTeal,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: makitaTeal, width: 1.5),
                      ),
                      child: const Text(
                        "자재 반납 (가용 재고 복귀)",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      onPressed: () => _showProjectReturnDialog(
                        docId: docs[index].id,
                        pItem: data,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 탭 3: 기록 (Logs)
  // ---------------------------------------------------------------------------
  Widget _buildLogsTab() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: pureWhite,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: slate100,
              foregroundColor: slate900,
              elevation: 0,
            ),
            icon: const Icon(LucideIcons.trash2, size: 16),
            label: const Text(
              "오래된 기록 정리하기",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: _showDeleteLogsDialog,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _logsDb.orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    "기록이 없습니다.",
                    style: TextStyle(
                      color: slate700,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final log = docs[index].data() as Map<String, dynamic>;
                  final Timestamp? ts = log['timestamp'] as Timestamp?;
                  final String dateStr = ts != null
                      ? "${ts.toDate().month}/${ts.toDate().day} ${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}"
                      : "방금 전";

                  String type = log['type'] ?? 'OUT';
                  Color iconColor;
                  IconData icon;
                  String sign = "";

                  if (type == 'IN') {
                    iconColor = makitaTeal;
                    icon = LucideIcons.packagePlus;
                    sign = "+";
                  } else if (type == 'OUT') {
                    iconColor = Colors.orange.shade800;
                    icon = LucideIcons.truck;
                    sign = "-";
                  } else if (type == 'AUDIT') {
                    iconColor = slate900;
                    icon = LucideIcons.scale;
                    sign = log['sign'] ?? "";
                  } else {
                    iconColor = Colors.blueAccent;
                    icon = LucideIcons.cornerDownLeft;
                    sign = "+";
                  }

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: iconColor.withValues(alpha: 0.1),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                    title: Text(
                      log['material_name'] ?? '알 수 없는 자재',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: slate900,
                      ),
                    ),
                    subtitle: Text(
                      "${log['project_name']} • $dateStr",
                      style: const TextStyle(
                        fontSize: 13,
                        color: slate700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Text(
                      "$sign ${log['qty']} ${log['unit']}",
                      style: TextStyle(
                        color: iconColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
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

  // ---------------------------------------------------------------------------
  // 탭 4: 현장 보관 가이드 (일체형 통합)
  // ---------------------------------------------------------------------------
  Widget _buildStorageGuideTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: slate200, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "현장 랙(Rack) 및 자재 정리정돈 가이드",
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: slate900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "앱 데이터와 실제 현장의 물리적 일치를 위한 필수 준수 사항입니다.",
              style: TextStyle(
                fontSize: 14,
                color: slate700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // 1. 소분 바구니
            _buildGuideSection(
              icon: LucideIcons.boxSelect,
              color: Colors.blue.shade700,
              title: "1. 소분 바구니(Bin) 및 라벨링 철저",
              points: [
                "박스째 뜯어서 선반에 굴리지 마세요. 자재가 섞이고 오염됩니다.",
                "피팅류는 규격별로 전용 소분 바구니에 담아 보관합니다.",
                "바구니 전면 라벨에 앱과 동일하게 [제조사 / 규격 / 품명 / 히트넘버]를 부착하세요.",
              ],
            ),

            // 2. A급 / B급 분리
            _buildGuideSection(
              icon: LucideIcons.alertTriangle,
              color: Colors.purple.shade600,
              title: "2. A급 신품 / B급 잉여 분리",
              points: [
                "현장에서 반납된 '포장 개봉품'이나 '성적서 불가' 피팅을 새 박스에 섞지 마세요.",
                "선반 맨 아래 칸이나 '빨간색 바구니'를 잉여/B급 전용칸으로 지정하세요.",
                "앱에서 파란색(테스트용) 마크가 뜬 잉여 자재는 막배관 작업 시 최우선으로 꺼내 씁니다.",
              ],
            ),

            // 3. 이종 금속 접촉 금지
            _buildGuideSection(
              icon: LucideIcons.pipette,
              color: Colors.orange.shade800,
              title: "3. 이종 금속 접촉 금지",
              points: [
                "카본(Carbon)과 서스(SUS) 배관재를 같은 선반에 혼합 보관하지 마세요.",
                "카본 분진이 스뎅에 묻으면 '갈바닉 부식'이 발생합니다.",
                "불가피하면 상단에 SUS, 하단에 Carbon을 배치하세요.",
              ],
            ),

            // 4. 튜빙과 피팅 분리 보관
            _buildGuideSection(
              icon: LucideIcons.mapPin,
              color: makitaTeal,
              title: "4. 튜빙과 피팅의 분리 보관 및 위치 식별",
              points: [
                "길이가 긴 튜빙은 휨 방지를 위해 전용 수평 캔틸레버 랙에 별도 보관합니다.",
                "튜빙 절단면에는 반드시 플라스틱 캡을 씌워 이물질을 차단하세요.",
                "신규 자재 등록 시 반드시 앱 내 '보관 위치(Location)' 필드에 정확한 랙 번호를 입력해야 합니다.",
              ],
            ),

            // 5. 정기 재고 조사
            _buildGuideSection(
              icon: LucideIcons.scale,
              color: slate900,
              title: "5. 정기 재고 조사(실사) 및 전산 보정",
              points: [
                "전산 수량과 실제 보관함 수량이 다를 경우, 임의로 '현장 불출' 처리해서 수량을 맞추지 마세요. (원가 산정 오류 발생)",
                "해당 자재 카드의 점 3개(⋮) 메뉴에서 [재고 실사 (수량 보정)] 기능을 사용해 실제 개수를 입력하세요.",
                "실사 보정 기록은 장부에 검은색 저울 아이콘(⚖️)으로 분리되어 투명하게 관리됩니다.",
              ],
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideSection({
    required IconData icon,
    required Color color,
    required String title,
    required List<String> points,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: slate900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...points.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "• ",
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      p,
                      style: const TextStyle(
                        color: slate700,
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isLast) ...[
            const SizedBox(height: 16),
            const Divider(color: slate200, height: 1),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 공통 UI 헬퍼
  // ---------------------------------------------------------------------------
  Widget _buildSimpleDropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: slate700,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: pureWhite,
              style: const TextStyle(
                color: slate900,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
              items: items
                  .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPopupDropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: slate700,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: slate50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: pureWhite,
                style: const TextStyle(
                  color: slate900,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                items: items
                    .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, bool isSel, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: isSel ? slate800 : slate100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSel ? slate800 : Colors.grey.shade300),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSel ? pureWhite : slate700,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
      ),
    );
  }

  Widget _buildInputLabelField(
    String label,
    TextEditingController ctrl,
    String hint, {
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: slate700,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: slate900,
          ),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: slate50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
          ),
        ),
      ],
    );
  }
}
