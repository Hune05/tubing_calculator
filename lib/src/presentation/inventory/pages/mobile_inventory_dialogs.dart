part of 'mobile_inventory_page.dart';

// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: library_private_types_in_public_api

extension MobileInventoryDialogsExt on _MobileInventoryPageState {
  void _showQuantityInputDialog(String docId, String item, int currentQty) {
    TextEditingController qtyController = TextEditingController(
      text: currentQty.toString(),
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            "$item\n실사 수량 입력",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.3,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: makitaTeal,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
            autofocus: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: darkBg,
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: _categories[_currentCategory]['color'],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _categories[_currentCategory]['color'],
              ),
              onPressed: () {
                int? newQty = int.tryParse(qtyController.text);
                if (newQty != null && newQty >= 0) {
                  setState(() {
                    if (!_localEdits.containsKey(docId)) {
                      _localEdits[docId] = ItemData();
                    }
                    _localEdits[docId]!.qty = newQty;
                  });
                }
                Navigator.pop(context);
              },
              child: const Text(
                "확인",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 💡 모바일 QR / 바코드 스캐너 연동 다이얼로그
  void _showAddNewItemDialog(String categoryId) {
    TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            "신규 자재 임시 등록",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(LucideIcons.scanLine, color: Colors.white),
                  label: const Text(
                    "QR / 바코드 스캔",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () async {
                    // 스캐너 페이지 띄우기
                    final scannedCode = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: AppBar(
                            title: const Text("바코드 스캔"),
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                          ),
                          body: MobileScanner(
                            onDetect: (capture) {
                              final List<Barcode> barcodes = capture.barcodes;
                              if (barcodes.isNotEmpty &&
                                  barcodes.first.rawValue != null) {
                                Navigator.pop(context, barcodes.first.rawValue);
                              }
                            },
                          ),
                        ),
                      ),
                    );

                    // 결과가 있으면 텍스트 박스에 자동 채우기
                    if (scannedCode != null && scannedCode is String) {
                      setState(() {
                        nameController.text = scannedCode;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "또는 직접 수동 입력",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "자재명 및 규격 입력",
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  filled: true,
                  fillColor: darkBg,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: _categories[_currentCategory]['color'],
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _categories[_currentCategory]['color'],
              ),
              onPressed: () {
                String name = nameController.text.trim();
                if (name.isNotEmpty) {
                  setState(() {
                    String tempId =
                        "NEW_${DateTime.now().millisecondsSinceEpoch}";
                    _newLocalItems[tempId] = {
                      'name': name,
                      'category': categoryId,
                    };
                    _localEdits[tempId] = ItemData()..qty = 0;
                  });
                }
                Navigator.pop(context);
              },
              child: const Text(
                "임시 추가",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showExtraInfoDialog(String docId, ItemData data, String infoType) {
    String currentValue = "";
    try {
      currentValue = infoType == 'HeatNo'
          ? data.heatNo
          : (infoType == 'Maker'
                ? data.maker
                : (infoType == 'Material' ? data.material : data.location));
    } catch (_) {}
    TextEditingController ctrl = TextEditingController(text: currentValue);
    List<String> quickOptions = [];
    if (infoType == 'Maker') quickOptions = ["HY-LOK", "SWAGELOK", "PARKER"];
    if (infoType == 'Material')
      quickOptions = ["SS316L", "SS304", "Carbon", "Teflon"];
    if (infoType == 'Location')
      quickOptions = ["A동 1열", "B동 2열", "튜빙 야적장", "공구함"];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            infoType == 'HeatNo'
                ? "히트 넘버 입력"
                : (infoType == 'Maker'
                      ? "제조사 선택"
                      : (infoType == 'Material' ? "재질 선택" : "보관 위치 입력")),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: darkBg,
                  hintText: "직접 입력",
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: _categories[_currentCategory]['color'],
                    ),
                  ),
                ),
              ),
              if (quickOptions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: quickOptions
                      .map(
                        (opt) => ActionChip(
                          label: Text(
                            opt,
                            style: TextStyle(
                              color: ctrl.text == opt ? slate900 : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: ctrl.text == opt
                              ? makitaTeal
                              : darkBg,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          onPressed: () {
                            setState(() => ctrl.text = opt);
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _categories[_currentCategory]['color'],
              ),
              onPressed: () {
                setState(() {
                  if (!_localEdits.containsKey(docId)) {
                    _localEdits[docId] = data;
                  }
                  try {
                    if (infoType == 'HeatNo')
                      _localEdits[docId]!.heatNo = ctrl.text
                          .trim()
                          .toUpperCase();
                    if (infoType == 'Maker')
                      _localEdits[docId]!.maker = ctrl.text
                          .trim()
                          .toUpperCase();
                    if (infoType == 'Material')
                      _localEdits[docId]!.material = ctrl.text
                          .trim()
                          .toUpperCase();
                    if (infoType == 'Location')
                      _localEdits[docId]!.location = ctrl.text
                          .trim()
                          .toUpperCase();
                  } catch (_) {}
                });
                Navigator.pop(context);
              },
              child: const Text(
                "저장",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Text(
                "현장 실사(Audit) 동기화 기록",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _historyLogs.isEmpty
                    ? Center(
                        child: Text(
                          "실사 기록이 없습니다.",
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _historyLogs.length,
                        itemBuilder: (context, index) {
                          var log = _historyLogs[index];
                          bool isCompleted = log['status'] == 'completed';
                          bool isFailed = log['status'] == 'failed';
                          int syncCount = log['syncCount'] ?? 0;
                          return ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: log['color'],
                              radius: 12,
                            ),
                            title: Text(
                              "${log['category']} • ${log['time']}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              "$syncCount개 항목 전송됨",
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Icon(
                              isFailed
                                  ? Icons.error
                                  : (isCompleted
                                        ? Icons.check_circle
                                        : Icons.sync),
                              color: isFailed
                                  ? Colors.redAccent
                                  : (isCompleted
                                        ? Colors.greenAccent
                                        : Colors.orangeAccent),
                            ),
                            children: const [
                              Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  "데이터가 서버에 안전하게 병합되었습니다.",
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
