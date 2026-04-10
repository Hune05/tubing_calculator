part of 'mobile_inventory_page.dart';

// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: library_private_types_in_public_api

// ★ 앱이 켜져 있는 동안 작업자가 추가한 보관 위치를 기억하는 리스트입니다.
List<String> _globalLocationOptions = ["A동 1열", "B동 2열", "튜빙 야적장", "공구함"];

extension MobileInventoryDialogsExt on _MobileInventoryPageState {
  // 🚀 1. 수량 입력 다이얼로그
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
              borderRadius: BorderRadius.circular(24),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            title: Text(
              "$item\n얼마나 있나요?",
              style: const TextStyle(
                color: slate900,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _categories[_currentCategory]['color'],
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -2,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: "0",
                    hintStyle: TextStyle(color: slate100),
                  ),
                ),
                const Text(
                  "숫자를 눌러서 수정하세요",
                  style: TextStyle(
                    color: slate600,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: slate100,
                        foregroundColor: slate600,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "취소",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _categories[_currentCategory]['color'],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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
                        "입력 완료",
                        style: TextStyle(
                          color: Colors.white,
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
        );
      },
    );
  }

  // 🚀 2. 신규 자재 등록 다이얼로그
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
                  borderRadius: BorderRadius.circular(24),
                ),
                titlePadding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                title: const Text(
                  "신규 자재 임시 등록",
                  style: TextStyle(
                    color: slate900,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent.shade700,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                LucideIcons.scanLine,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: const Text(
                                "QR 스캔",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
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
                                          final barcodes = capture.barcodes;
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
                                if (scannedCode != null &&
                                    scannedCode is String) {
                                  setDialogState(() {
                                    nameController.text = scannedCode;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: makitaTeal,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.text_fields,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: const Text(
                                "AI 글자 스캔",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
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
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "자재명 (필수)",
                        style: TextStyle(
                          color: slate900,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        style: const TextStyle(
                          color: slate900,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: "예: Union",
                          hintStyle: TextStyle(
                            color: slate600.withValues(alpha: 0.6),
                          ),
                          filled: true,
                          fillColor: slate100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "제조사 (Maker)",
                        style: TextStyle(
                          color: slate900,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: makerController,
                        style: const TextStyle(
                          color: slate900,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: "선택 또는 입력",
                          hintStyle: TextStyle(
                            color: slate600.withValues(alpha: 0.6),
                          ),
                          filled: true,
                          fillColor: slate100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: slate600,
                            ),
                            onSelected: (String value) {
                              setDialogState(() {
                                makerController.text = value;
                              });
                            },
                            itemBuilder: (BuildContext context) => makerOptions
                                .map(
                                  (opt) => PopupMenuItem<String>(
                                    value: opt,
                                    child: Text(
                                      opt,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "최소 유지 수량 (안전 재고)",
                        style: TextStyle(
                          color: slate900,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: minQtyController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: slate900,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: "예: 10 (부족 시 알람)",
                          hintStyle: TextStyle(
                            color: slate600.withValues(alpha: 0.6),
                          ),
                          filled: true,
                          fillColor: slate100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                actions: [
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: slate100,
                            foregroundColor: slate600,
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "취소",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _categories[_currentCategory]['color'],
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
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
                            if (maker.isNotEmpty) {
                              finalName += "[$maker] ";
                            }
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
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // 🚀 3. 상세 정보 수정 다이얼로그
  void _showExtraInfoDialog(String docId, ItemData data, String infoType) {
    String currentValue = "";
    try {
      if (infoType == 'HeatNo') {
        currentValue = data.heatNo;
      } else if (infoType == 'Maker') {
        currentValue = data.maker;
      } else if (infoType == 'Material') {
        currentValue = data.material;
      } else if (infoType == 'Location') {
        currentValue = data.location;
      } else if (infoType == 'Spec') {
        currentValue = data.spec;
      } else if (infoType == 'Project') {
        currentValue = data.projectName;
      } else if (infoType == 'Department') {
        currentValue = data.department;
      } else if (infoType == 'MinQty') {
        currentValue = data.minQty == 0 ? "" : data.minQty.toString();
      }
    } catch (_) {}

    TextEditingController ctrl = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            List<String> quickOptions = [];
            String titleText = "";
            TextInputType kbType = TextInputType.text;
            bool allowCustomAdd = false;

            if (infoType == 'Maker') {
              titleText = "제조사 선택";
              quickOptions = _categories[_currentCategory]['id'] == 'TUBE'
                  ? ["TSK", "SANDVIK", "세아특수강", "코리녹스"]
                  : ["HY-LOK", "SWAGELOK", "PARKER"];
            } else if (infoType == 'Material') {
              titleText = "재질 선택";
              quickOptions = ["SS316L", "SS304", "Carbon", "Teflon"];
            } else if (infoType == 'Location') {
              titleText = "보관 위치 지정";
              quickOptions = _globalLocationOptions;
              allowCustomAdd = true;
            } else if (infoType == 'Spec') {
              titleText = "규격(Spec) 입력";
              quickOptions = ["1/4\"", "3/8\"", "1/2\"", "6mm", "8mm"];
            } else if (infoType == 'Project') {
              titleText = "프로젝트 배정";
              quickOptions = ["유지보수 공용", "신규 공사", "테스트 벤치"];
            } else if (infoType == 'Department') {
              titleText = "담당 부서/팀";
              quickOptions = ["발전 설비", "한화 콤프레샤", "전기 제어", "배관 설비"];
            } else if (infoType == 'HeatNo') {
              titleText = "히트 넘버 (Heat No.)";
            } else if (infoType == 'MinQty') {
              titleText = "최소 유지 수량 (안전 재고)";
              quickOptions = ["5", "10", "20", "50"];
              kbType = TextInputType.number;
            }

            return Theme(
              data: ThemeData.light(),
              child: AlertDialog(
                backgroundColor: pureWhite,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                titlePadding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                title: Text(
                  titleText,
                  style: const TextStyle(
                    color: slate900,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
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
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: slate100,
                        hintText: "직접 입력해주세요",
                        hintStyle: TextStyle(
                          color: slate600.withValues(alpha: 0.6),
                          fontSize: 16,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        setDialogState(() {});
                      },
                    ),
                    if (quickOptions.isNotEmpty || allowCustomAdd) ...[
                      const SizedBox(height: 24),
                      Container(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          children: [
                            ...quickOptions.map((opt) {
                              bool isSelected = ctrl.text == opt;
                              return GestureDetector(
                                onLongPress: () {
                                  if (allowCustomAdd) {
                                    HapticFeedback.heavyImpact();
                                    setDialogState(() {
                                      _globalLocationOptions.remove(opt);
                                      if (ctrl.text == opt) {
                                        ctrl.clear();
                                      }
                                    });
                                  }
                                },
                                child: ChoiceChip(
                                  label: Text(
                                    opt,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : slate600,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  selected: isSelected,
                                  onSelected: (bool selected) {
                                    setDialogState(() {
                                      ctrl.text = selected ? opt : "";
                                    });
                                  },
                                  selectedColor: makitaTeal,
                                  backgroundColor: slate100,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide.none,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              );
                            }),
                            if (allowCustomAdd)
                              ActionChip(
                                label: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add, size: 16, color: slate600),
                                    SizedBox(width: 4),
                                    Text(
                                      "위치 추가",
                                      style: TextStyle(
                                        color: slate600,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: pureWhite,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(
                                  color: slate600.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                onPressed: () {
                                  TextEditingController newOptCtrl =
                                      TextEditingController();
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        backgroundColor: pureWhite,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        title: const Text(
                                          "새 보관 위치 등록",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        content: TextField(
                                          controller: newOptCtrl,
                                          autofocus: true,
                                          decoration: InputDecoration(
                                            hintText: "예: C구역 3열",
                                            filled: true,
                                            fillColor: slate100,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                          ),
                                        ),
                                        actionsPadding: const EdgeInsets.all(
                                          16,
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text(
                                              "취소",
                                              style: TextStyle(
                                                color: slate600,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: makitaTeal,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
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
                                              "추가하기",
                                              style: TextStyle(
                                                color: pureWhite,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      if (allowCustomAdd)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            "※ 칩을 길게 누르면 위치가 삭제돼요.",
                            style: TextStyle(
                              fontSize: 12,
                              color: slate600.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
                actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                actions: [
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: slate100,
                            foregroundColor: slate600,
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "취소",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _categories[_currentCategory]['color'],
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              if (!_localEdits.containsKey(docId)) {
                                _localEdits[docId] = data;
                              }
                              try {
                                if (infoType == 'HeatNo') {
                                  _localEdits[docId]!.heatNo = ctrl.text.trim();
                                } else if (infoType == 'Maker') {
                                  _localEdits[docId]!.maker = ctrl.text.trim();
                                } else if (infoType == 'Material') {
                                  _localEdits[docId]!.material = ctrl.text
                                      .trim();
                                } else if (infoType == 'Location') {
                                  _localEdits[docId]!.location = ctrl.text
                                      .trim();
                                } else if (infoType == 'Spec') {
                                  _localEdits[docId]!.spec = ctrl.text.trim();
                                } else if (infoType == 'Project') {
                                  _localEdits[docId]!.projectName = ctrl.text
                                      .trim();
                                } else if (infoType == 'Department') {
                                  _localEdits[docId]!.department = ctrl.text
                                      .trim();
                                } else if (infoType == 'MinQty') {
                                  _localEdits[docId]!.minQty =
                                      int.tryParse(ctrl.text.trim()) ?? 0;
                                }
                              } catch (_) {}
                            });
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "저장하기",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ), // 💡 AlertDialog 닫기
            ); // 💡 Theme 닫기
          }, // 💡 StatefulBuilder builder 닫기
        ); // 💡 StatefulBuilder 닫기
      }, // 💡 showDialog builder 닫기
    ); // 💡 showDialog 닫기
  } // 💡 _showExtraInfoDialog 닫기
}
