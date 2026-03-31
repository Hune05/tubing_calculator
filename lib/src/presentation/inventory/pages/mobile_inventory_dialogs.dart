part of 'mobile_inventory_page.dart';

// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: library_private_types_in_public_api

// ★ 앱이 켜져 있는 동안 작업자가 추가한 보관 위치를 기억하는 리스트입니다.
// (나중에 모든 작업자가 공유하게 하려면 이 부분을 Firestore에 저장하도록 연결하면 됩니다.)
List<String> _globalLocationOptions = ["A동 1열", "B동 2열", "튜빙 야적장", "공구함"];

extension MobileInventoryDialogsExt on _MobileInventoryPageState {
  void _showQuantityInputDialog(String docId, String item, int currentQty) {
    TextEditingController qtyController = TextEditingController(
      text: currentQty.toString(),
    );
    showDialog(
      context: context,
      builder: (context) {
        return Theme(
          data: ThemeData.light(),
          child: AlertDialog(
            backgroundColor: pureWhite,
            surfaceTintColor: Colors.transparent,
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
          ),
        );
      },
    );
  }

  void _showAddNewItemDialog(String categoryId) {
    TextEditingController makerController = TextEditingController();
    TextEditingController nameController = TextEditingController();
    TextEditingController minQtyController = TextEditingController();

    String autoMaterial = "";
    String autoHeatNo = "";

    List<String> makerOptions = [
      "HY-LOK",
      "SWAGELOK",
      "PARKER",
      "TSK",
      "SANDVIK",
      "세아특수강",
    ];

    showDialog(
      context: context,
      builder: (context) {
        return Theme(
          data: ThemeData.light(),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: pureWhite,
                surfaceTintColor: Colors.transparent,
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
                                        if (!context.mounted) return;
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
                            if (!context.mounted) return;
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
                        "자재명 (필수)",
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
                          hintText: "예: Union",
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
                        "제조사 (Maker)",
                        style: TextStyle(
                          color: slate600,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: makerController,
                        style: const TextStyle(
                          color: slate900,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: "선택 또는 입력",
                          filled: true,
                          fillColor: slate100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.arrow_drop_down_circle,
                              color: makitaTeal,
                            ),
                            onSelected: (String value) => setDialogState(
                              () => makerController.text = value,
                            ),
                            itemBuilder: (BuildContext context) => makerOptions
                                .map(
                                  (opt) => PopupMenuItem<String>(
                                    value: opt,
                                    child: Text(opt),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        "최소 유지 수량 (안전 재고)",
                        style: TextStyle(
                          color: slate600,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: minQtyController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: slate900,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: "예: 10 (부족 시 알람)",
                          filled: true,
                          fillColor: slate100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
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
                      String maker = makerController.text.trim();
                      String name = nameController.text.trim();
                      int minQty =
                          int.tryParse(minQtyController.text.trim()) ?? 0;

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("자재명을 입력해주세요."),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }

                      String finalName = "";
                      if (maker.isNotEmpty) finalName += "[$maker] ";
                      finalName += name;
                      finalName = finalName
                          .replaceAll(RegExp(r'\s+'), ' ')
                          .trim();

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
                            ..maker = maker
                            ..material = autoMaterial
                            ..heatNo = autoHeatNo
                            ..minQty = minQty;
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
          ),
        );
      },
    );
  }

  void _showExtraInfoDialog(String docId, ItemData data, String infoType) {
    String currentValue = "";
    try {
      if (infoType == 'HeatNo')
        currentValue = data.heatNo;
      else if (infoType == 'Maker')
        currentValue = data.maker;
      else if (infoType == 'Material')
        currentValue = data.material;
      else if (infoType == 'Location')
        currentValue = data.location;
      else if (infoType == 'Spec')
        currentValue = data.spec;
      else if (infoType == 'Project')
        currentValue = data.projectName;
      else if (infoType == 'Department') // ★ 추가된 부분
        currentValue = data.department;
      else if (infoType == 'MinQty')
        currentValue = data.minQty == 0 ? "" : data.minQty.toString();
    } catch (_) {}

    TextEditingController ctrl = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) {
        // 🚀 StatefulBuilder를 적용하여 다이얼로그 안에서 즉각적인 UI 업데이트(칩 하이라이트 등)를 지원합니다.
        return StatefulBuilder(
          builder: (context, setDialogState) {
            List<String> quickOptions = [];
            String titleText = "";
            TextInputType kbType = TextInputType.text;
            bool allowCustomAdd = false;

            if (infoType == 'Maker') {
              titleText = "제조사 입력";
              quickOptions = _categories[_currentCategory]['id'] == 'TUBE'
                  ? ["TSK", "SANDVIK", "세아특수강", "코리녹스"]
                  : ["HY-LOK", "SWAGELOK", "PARKER"];
            } else if (infoType == 'Material') {
              titleText = "재질 선택";
              quickOptions = ["SS316L", "SS304", "Carbon", "Teflon"];
            } else if (infoType == 'Location') {
              titleText = "보관 위치 입력\n(칩을 길게 누르면 삭제됩니다)";
              quickOptions = _globalLocationOptions; // ★ 커스텀 리스트 적용
              allowCustomAdd = true; // ★ 직접 추가 기능 활성화
            } else if (infoType == 'Spec') {
              titleText = "규격(Spec) 입력";
              quickOptions = ["1/4\"", "3/8\"", "1/2\"", "6mm", "8mm"];
            } else if (infoType == 'Project') {
              titleText = "프로젝트 입력";
              quickOptions = ["유지보수", "신규공사", "테스트"];
            } else if (infoType == 'Department') {
              // ★ 추가된 부분
              titleText = "담당 부서/팀 입력";
              quickOptions = ["발전 설비", "한화 콤프레샤", "전기 제어", "배관 설비"];
            } else if (infoType == 'HeatNo') {
              titleText = "히트 넘버 입력";
            } else if (infoType == 'MinQty') {
              titleText = "최소 유지 수량 입력";
              quickOptions = ["5", "10", "20", "50"];
              kbType = TextInputType.number;
            }

            return Theme(
              data: ThemeData.light(),
              child: AlertDialog(
                backgroundColor: pureWhite,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  titleText,
                  style: const TextStyle(
                    color: slate900,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: ctrl,
                      keyboardType: kbType,
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
                      ),
                      onChanged: (val) {
                        setDialogState(() {}); // 텍스트 입력 시 칩 하이라이트 동기화
                      },
                    ),
                    if (quickOptions.isNotEmpty || allowCustomAdd) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...quickOptions.map((opt) {
                            bool isSelected = ctrl.text == opt;
                            return GestureDetector(
                              onLongPress: () {
                                // ★ 보관 위치 칩 길게 누르면 삭제
                                if (allowCustomAdd) {
                                  HapticFeedback.heavyImpact();
                                  setDialogState(() {
                                    _globalLocationOptions.remove(opt);
                                    if (ctrl.text == opt) ctrl.clear();
                                  });
                                }
                              },
                              child: ActionChip(
                                label: Text(
                                  opt,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : slate600,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: isSelected
                                    ? makitaTeal
                                    : slate100,
                                side: BorderSide(
                                  color: isSelected
                                      ? makitaTeal
                                      : Colors.grey.shade300,
                                ),
                                onPressed: () {
                                  setDialogState(() => ctrl.text = opt);
                                },
                              ),
                            );
                          }),

                          // ★ '보관 위치'일 때만 [+ 추가] 버튼 표시
                          if (allowCustomAdd)
                            ActionChip(
                              label: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add, size: 16, color: pureWhite),
                                  SizedBox(width: 4),
                                  Text(
                                    "추가",
                                    style: TextStyle(
                                      color: pureWhite,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: slate900,
                              side: const BorderSide(color: slate900),
                              onPressed: () {
                                TextEditingController newOptCtrl =
                                    TextEditingController();
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return Theme(
                                      data: ThemeData.light(),
                                      child: AlertDialog(
                                        backgroundColor: pureWhite,
                                        title: const Text(
                                          "새 보관 위치 등록",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        content: TextField(
                                          controller: newOptCtrl,
                                          autofocus: true,
                                          decoration: const InputDecoration(
                                            hintText: "예: C구역 3열",
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text(
                                              "취소",
                                              style: TextStyle(color: slate600),
                                            ),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: makitaTeal,
                                            ),
                                            onPressed: () {
                                              if (newOptCtrl.text
                                                  .trim()
                                                  .isNotEmpty) {
                                                setDialogState(() {
                                                  _globalLocationOptions.add(
                                                    newOptCtrl.text.trim(),
                                                  );
                                                });
                                              }
                                              Navigator.pop(context);
                                            },
                                            child: const Text(
                                              "추가",
                                              style: TextStyle(
                                                color: pureWhite,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                        ],
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
                        if (!_localEdits.containsKey(docId))
                          _localEdits[docId] = data;
                        try {
                          if (infoType == 'HeatNo')
                            _localEdits[docId]!.heatNo = ctrl.text.trim();
                          else if (infoType == 'Maker')
                            _localEdits[docId]!.maker = ctrl.text.trim();
                          else if (infoType == 'Material')
                            _localEdits[docId]!.material = ctrl.text.trim();
                          else if (infoType == 'Location')
                            _localEdits[docId]!.location = ctrl.text.trim();
                          else if (infoType == 'Spec')
                            _localEdits[docId]!.spec = ctrl.text.trim();
                          else if (infoType == 'Project')
                            _localEdits[docId]!.projectName = ctrl.text.trim();
                          else if (infoType == 'Department') // ★ 추가된 부분 저장 로직
                            _localEdits[docId]!.department = ctrl.text.trim();
                          else if (infoType == 'MinQty')
                            _localEdits[docId]!.minQty =
                                int.tryParse(ctrl.text.trim()) ?? 0;
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
              ),
            );
          },
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
        return Theme(
          data: ThemeData.light(),
          child: SafeArea(
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
          ),
        );
      },
    );
  }
}
