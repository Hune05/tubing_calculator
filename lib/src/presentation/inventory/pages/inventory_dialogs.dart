part of 'inventory_page.dart';

extension InventoryDialogsExt on _InventoryPageState {
  void _showMainStockActionDialog({
    required bool isDispatch,
    required String docId,
    required Map<String, dynamic> item,
  }) {
    final TextEditingController qtyCtrl = TextEditingController();
    final TextEditingController projCtrl = TextEditingController();
    final TextEditingController reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Row(
          children: [
            Icon(
              isDispatch ? LucideIcons.truck : LucideIcons.packagePlus,
              color: isDispatch ? Colors.orange.shade800 : makitaTeal,
            ),
            const SizedBox(width: 8),
            Text(
              isDispatch ? "자재 불출 (-)" : "자재 입고 (+)",
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
              item['name'],
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: slate600,
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
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "사용 목적 / 사유 (선택)",
                style: TextStyle(
                  fontSize: 13,
                  color: slate700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: reasonCtrl,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: slate900,
                ),
                decoration: InputDecoration(
                  hintText: "예: 성적서 미적용 구간 등",
                  hintStyle: const TextStyle(color: slate400, fontSize: 13),
                  filled: true,
                  fillColor: slate50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
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
                  borderRadius: BorderRadius.circular(4),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: () async {
              int qty = int.tryParse(qtyCtrl.text) ?? 0;
              String proj = projCtrl.text.trim();
              String reason = reasonCtrl.text.trim();

              if (qty <= 0 || (isDispatch && proj.isEmpty)) return;

              try {
                // 안전 증감 연산 처리
                await _inventoryDb.doc(docId).update({
                  'qty': FieldValue.increment(isDispatch ? -qty : qty),
                });

                if (isDispatch) {
                  final snapshot = await _projectInventoryDb
                      .where('project_name', isEqualTo: proj)
                      .where('material_name', isEqualTo: item['name'])
                      .limit(1)
                      .get();
                  if (snapshot.docs.isNotEmpty) {
                    await _projectInventoryDb
                        .doc(snapshot.docs.first.id)
                        .update({
                          'qty': FieldValue.increment(qty),
                          if (reason.isNotEmpty) 'reason': reason,
                        });
                  } else {
                    await _projectInventoryDb.add({
                      'project_name': proj,
                      'material_name': item['name'],
                      'category': item['category'],
                      'unit': item['unit'],
                      'heatNo': item['heatNo'] ?? "",
                      'location': item['location'] ?? "",
                      'qty': qty,
                      'reason': reason,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  }
                }

                await _logsDb.add({
                  'type': isDispatch ? 'OUT' : 'IN',
                  'project_name': isDispatch ? proj : '자재 창고 입고',
                  'material_name': item['name'],
                  'qty': qty,
                  'unit': item['unit'],
                  if (isDispatch && reason.isNotEmpty) 'reason': reason,
                  'timestamp': FieldValue.serverTimestamp(),
                });

                if (context.mounted) {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedDocId = null;
                    _selectedItemData = null;
                  });
                }
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

  void _showProjectReturnDialog({
    required String docId,
    required Map<String, dynamic> pItem,
  }) {
    final TextEditingController qtyCtrl = TextEditingController();
    String returnStatus = "정상";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: pureWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: const Row(
            children: [
              Icon(LucideIcons.cornerDownLeft, color: makitaTeal),
              SizedBox(width: 8),
              Text(
                "자재 창고 반납",
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: makitaTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  pItem['category'] ?? '기타',
                  style: const TextStyle(
                    color: makitaDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "[ ${pItem['material_name']} ]",
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: slate900,
                ),
              ),
              const SizedBox(height: 16),
              _buildInputLabelField(
                "반납 수량",
                qtyCtrl,
                "최대 ${pItem['qty']}",
                isNumber: true,
              ),
              const SizedBox(height: 16),
              const Text(
                "반납 상태 분류",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: slate700,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: slate300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text(
                        "정상품 (본 재고 합침)",
                        style: TextStyle(
                          fontSize: 13,
                          color: slate900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      value: "정상",
                      groupValue: returnStatus,
                      dense: true,
                      activeColor: makitaTeal,
                      onChanged: (v) => setDialogState(() => returnStatus = v!),
                    ),
                    RadioListTile<String>(
                      title: const Text(
                        "장기 보관 (희귀부속)",
                        style: TextStyle(
                          fontSize: 13,
                          color: slate900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      value: "장기 보관",
                      groupValue: returnStatus,
                      dense: true,
                      activeColor: Colors.green.shade700,
                      onChanged: (v) => setDialogState(() => returnStatus = v!),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: makitaTeal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              onPressed: () async {
                int qty = int.tryParse(qtyCtrl.text) ?? 0;
                int currentProjQty = pItem['qty'] ?? 0;

                if (qty <= 0 || qty > currentProjQty) return;

                try {
                  if (currentProjQty - qty == 0) {
                    await _projectInventoryDb.doc(docId).delete();
                  } else {
                    await _projectInventoryDb.doc(docId).update({
                      'qty': FieldValue.increment(-qty),
                    });
                  }

                  String targetMatName = pItem['material_name'];
                  if (returnStatus != "정상" &&
                      !targetMatName.contains("($returnStatus)"))
                    targetMatName = "$targetMatName ($returnStatus)";

                  final snapshot = await _inventoryDb
                      .where('name', isEqualTo: targetMatName)
                      .limit(1)
                      .get();
                  if (snapshot.docs.isNotEmpty) {
                    await _inventoryDb.doc(snapshot.docs.first.id).update({
                      'qty': FieldValue.increment(qty),
                    });
                  } else {
                    await _inventoryDb.add({
                      "name": targetMatName,
                      "category": pItem['category'],
                      "maker": pItem['maker'] ?? "알수없음",
                      "heatNo": pItem['heatNo'] ?? "",
                      "location": pItem['location'] ?? "반납/위치미상",
                      "qty": qty,
                      "min_qty": 10,
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

                  if (context.mounted) {
                    Navigator.pop(ctx);
                    setState(() {
                      _selectedDocId = null;
                      _selectedItemData = null;
                    });
                  }
                } catch (e) {
                  debugPrint("Error: $e");
                }
              },
              child: const Text(
                "반납",
                style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog({required String docId}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text(
          "아이템 삭제",
          style: TextStyle(fontWeight: FontWeight.bold, color: slate900),
        ),
        content: const Text(
          "이 자재 마스터를 영구적으로 삭제하시겠습니까?\n삭제된 데이터는 복구할 수 없습니다.",
          style: TextStyle(fontSize: 14, color: slate700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "취소",
              style: TextStyle(color: slate600, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: () {
              _inventoryDb.doc(docId).delete();
              if (_selectedDocId == docId)
                setState(() {
                  _selectedDocId = null;
                  _selectedItemData = null;
                });
              Navigator.pop(ctx);
            },
            child: const Text(
              "삭제",
              style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMaterialSheet() {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController sizeCtrl = TextEditingController();
    final TextEditingController qtyCtrl = TextEditingController(text: "0");
    final TextEditingController minQtyCtrl = TextEditingController(text: "10");
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
                          "제조사",
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
                  _buildInputLabelField("보관 위치", locationCtrl, "예: 랙 A-1열 등"),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildInputLabelField(
                          "히트 넘버",
                          heatNoCtrl,
                          "생략가능",
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
                  const SizedBox(height: 16),
                  _buildInputLabelField(
                    "최소 유지 수량 (안전 재고)",
                    minQtyCtrl,
                    "10",
                    isNumber: true,
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
                            makerCtrl.text.isEmpty)
                          return;
                        String fullName =
                            "[${makerCtrl.text}] ${sizeCtrl.text} ${nameCtrl.text}";
                        if (heatNoCtrl.text.isNotEmpty)
                          fullName += " (H:${heatNoCtrl.text})";

                        await _inventoryDb.add({
                          "name": fullName,
                          "maker": makerCtrl.text,
                          "size": sizeCtrl.text,
                          "raw_name": nameCtrl.text,
                          "category": selectedCategory,
                          "heatNo": heatNoCtrl.text,
                          "location": locationCtrl.text,
                          "qty": int.tryParse(qtyCtrl.text) ?? 0,
                          "min_qty": int.tryParse(minQtyCtrl.text) ?? 10,
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

  void _showDeleteLogsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
              "오래된 기록을 삭제합니다.",
              style: TextStyle(color: slate600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _buildLogDeleteOption(ctx, "1주일 이전 삭제", 7),
            _buildLogDeleteOption(ctx, "1개월 이전 삭제", 30),
            _buildLogDeleteOption(ctx, "전체 일괄 삭제", 0, isAll: true),
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
            final ts = doc['timestamp'] as Timestamp?;
            if (ts != null) {
              if (isAll || ts.toDate().isBefore(cutoff)) {
                batch.delete(doc.reference);
              }
            } else if (isAll) {
              batch.delete(doc.reference);
            }
          }
          await batch.commit();
          if (mounted)
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("삭제 완료")));
        } catch (e) {
          debugPrint("오류: $e");
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

  void _showAdjustmentDialog({
    required String docId,
    required Map<String, dynamic> item,
  }) {
    final TextEditingController physicalQtyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Row(
          children: [
            Icon(LucideIcons.scale, color: slate900),
            SizedBox(width: 8),
            Text(
              "재고 임의 수정",
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
                borderRadius: BorderRadius.circular(4),
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
              "실제 창고 수량 (Physical Qty)",
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
                  borderRadius: BorderRadius.circular(4),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: slate900,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
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
                  'project_name': '정기 재고 수정',
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
              borderRadius: BorderRadius.circular(4),
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
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
          ),
        ),
      ],
    );
  }
}
