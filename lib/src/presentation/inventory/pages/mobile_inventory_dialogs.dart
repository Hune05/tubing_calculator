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
          backgroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "$item\n실사 수량 입력",
            style: const TextStyle(
              color: slate900,
              fontSize: 16,
              height: 1.3,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: const TextStyle(
              color: makitaTeal,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: slate100,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: _categories[_currentCategory]['color'],
                  width: 2,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소", style: TextStyle(color: slate600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _categories[_currentCategory]['color'],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                int? newQty = int.tryParse(qtyController.text);
                if (newQty != null && newQty >= 0) {
                  setState(() {
                    if (!_localEdits.containsKey(docId))
                      _localEdits[docId] = ItemData();
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

  void _showAddNewItemDialog(String categoryId) {
    TextEditingController nameController = TextEditingController();
    TextEditingController specController = TextEditingController();

    String autoMaterial = "";
    String autoHeatNo = "";

    // 🚀 1/8인치 제거된 콤팩트 리스트
    List<String> inchOptions = ["1/4\"", "3/8\"", "1/2\"", "3/4\"", "1\""];
    List<String> mmOptions = ["6mm", "8mm", "10mm", "12mm", "25mm"];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: pureWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                "신규 자재 임시 등록",
                style: TextStyle(
                  color: slate900,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        icon: const Icon(
                          LucideIcons.scanLine,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "QR / 바코드 스캔",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          final scannedCode = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Scaffold(
                                appBar: AppBar(
                                  title: const Text("바코드 스캔"),
                                  backgroundColor: slate900,
                                  foregroundColor: Colors.white,
                                ),
                                body: MobileScanner(
                                  onDetect: (capture) {
                                    final List<Barcode> barcodes =
                                        capture.barcodes;
                                    if (barcodes.isNotEmpty &&
                                        barcodes.first.rawValue != null) {
                                      Navigator.pop(
                                        context,
                                        barcodes.first.rawValue,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          );
                          if (scannedCode != null && scannedCode is String) {
                            setDialogState(
                              () => nameController.text = scannedCode,
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: makitaTeal,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(
                          Icons.text_fields,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "라벨 글자 스캔 (AI 자동 분류)",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          final result = await OcrService.scanAndClassify(
                            context,
                          );
                          if (result != null) {
                            setDialogState(() {
                              nameController.text = result['name'] ?? "";
                              autoMaterial = result['material'] ?? "";
                              autoHeatNo = result['heatNo'] ?? "";
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      "자재명",
                      style: TextStyle(
                        color: slate600,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(
                        color: slate900,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: "스캔 또는 직접 입력",
                        filled: true,
                        fillColor: slate100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      "규격 (사이즈)",
                      style: TextStyle(
                        color: slate600,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: specController,
                      style: const TextStyle(
                        color: makitaTeal,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: "직접 입력 또는 우측 화살표 터치",
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: slate100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        // 🚀 까만 배경 해결 및 가로 4줄 콤팩트 팝업
                        suffixIcon: PopupMenuButton<String>(
                          color: pureWhite,
                          surfaceTintColor: pureWhite,
                          icon: const Icon(
                            Icons.arrow_drop_down_circle,
                            color: makitaTeal,
                          ),
                          offset: const Offset(0, 50),
                          onSelected: (String value) {
                            HapticFeedback.lightImpact();
                            setDialogState(() => specController.text = value);
                          },
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<String>>[
                                PopupMenuItem<String>(
                                  enabled: false,
                                  padding: const EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 260,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          "인치 (Inch)",
                                          style: TextStyle(
                                            color: slate600,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: inchOptions
                                              .map(
                                                (opt) => InkWell(
                                                  onTap: () => Navigator.pop(
                                                    context,
                                                    opt,
                                                  ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 8,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: slate100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors
                                                            .grey
                                                            .shade300,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      opt,
                                                      style: const TextStyle(
                                                        color: slate900,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8.0,
                                          ),
                                          child: Divider(color: Colors.grey),
                                        ),
                                        const Text(
                                          "미리 (mm)",
                                          style: TextStyle(
                                            color: slate600,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: mmOptions
                                              .map(
                                                (opt) => InkWell(
                                                  onTap: () => Navigator.pop(
                                                    context,
                                                    opt,
                                                  ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 8,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: slate100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors
                                                            .grey
                                                            .shade300,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      opt,
                                                      style: const TextStyle(
                                                        color: slate900,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("취소", style: TextStyle(color: slate600)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _categories[_currentCategory]['color'],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    String name = nameController.text.trim();
                    String spec = specController.text.trim();
                    String finalName = spec.isNotEmpty ? "$name $spec" : name;

                    if (finalName.isNotEmpty) {
                      setState(() {
                        String tempId =
                            "NEW_${DateTime.now().millisecondsSinceEpoch}";
                        _newLocalItems[tempId] = {
                          'name': finalName,
                          'category': categoryId,
                        };
                        _localEdits[tempId] = ItemData()
                          ..qty = 0
                          ..material = autoMaterial
                          ..heatNo = autoHeatNo;
                      });
                    }
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "목록에 추가",
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

    // 🚀 제조사(Maker) 클릭 시 카테고리별 맞춤 버튼 제공
    if (infoType == 'Maker') {
      if (_categories[_currentCategory]['id'] == 'TUBE') {
        // 튜브일 경우 튜브 전문 메이커 세팅
        quickOptions = ["TSK", "SANDVIK", "세아특수강", "코리녹스"];
      } else {
        // 피팅, 밸브 등일 경우 기존 메이커 세팅
        quickOptions = ["HY-LOK", "SWAGELOK", "PARKER"];
      }
    }

    if (infoType == 'Material') {
      quickOptions = ["SS316L", "SS304", "Carbon", "Teflon"];
    }
    if (infoType == 'Location') {
      quickOptions = ["A동 1열", "B동 2열", "튜빙 야적장", "공구함"];
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            infoType == 'HeatNo'
                ? "히트 넘버 입력"
                : (infoType == 'Maker'
                      ? "제조사 선택"
                      : (infoType == 'Material' ? "재질 선택" : "보관 위치 입력")),
            style: const TextStyle(
              color: slate900,
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
                  color: slate900,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: slate100,
                  hintText: "직접 입력",
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: _categories[_currentCategory]['color'],
                      width: 2,
                    ),
                  ),
                  suffixIcon: infoType == 'HeatNo'
                      ? IconButton(
                          icon: const Icon(
                            Icons.text_fields,
                            color: makitaTeal,
                          ),
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            final String? scannedText =
                                await OcrService.scanLabelText(context);
                            if (scannedText != null && scannedText.isNotEmpty) {
                              ctrl.text = scannedText.toUpperCase();
                            }
                          },
                        )
                      : null,
                ),
              ),
              if (quickOptions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: quickOptions.map((opt) {
                    bool isSelected = ctrl.text == opt;
                    return ActionChip(
                      label: Text(
                        opt,
                        style: TextStyle(
                          color: isSelected ? Colors.white : slate600,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: isSelected ? makitaTeal : slate100,
                      side: BorderSide(
                        color: isSelected ? makitaTeal : Colors.grey.shade300,
                      ),
                      onPressed: () => setState(() => ctrl.text = opt),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소", style: TextStyle(color: slate600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _categories[_currentCategory]['color'],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                setState(() {
                  if (!_localEdits.containsKey(docId)) {
                    _localEdits[docId] = data;
                  }
                  try {
                    if (infoType == 'HeatNo') {
                      _localEdits[docId]!.heatNo = ctrl.text
                          .trim()
                          .toUpperCase();
                    }
                    if (infoType == 'Maker') {
                      _localEdits[docId]!.maker = ctrl.text
                          .trim()
                          .toUpperCase();
                    }
                    if (infoType == 'Material') {
                      _localEdits[docId]!.material = ctrl.text
                          .trim()
                          .toUpperCase();
                    }
                    if (infoType == 'Location') {
                      _localEdits[docId]!.location = ctrl.text
                          .trim()
                          .toUpperCase();
                    }
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
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Text(
                "현장 실사(Audit) 동기화 기록",
                style: TextStyle(
                  color: slate900,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _historyLogs.isEmpty
                    ? const Center(
                        child: Text(
                          "실사 기록이 없습니다.",
                          style: TextStyle(color: slate600),
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
                                color: slate900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              "$syncCount개 항목 전송됨",
                              style: const TextStyle(
                                color: slate600,
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
                                  ? Colors.red.shade600
                                  : (isCompleted
                                        ? Colors.green.shade600
                                        : Colors.orange.shade600),
                            ),
                            children: const [
                              Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  "데이터가 서버에 안전하게 병합되었습니다.",
                                  style: TextStyle(
                                    color: slate600,
                                    fontWeight: FontWeight.bold,
                                  ),
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
