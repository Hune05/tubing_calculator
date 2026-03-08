import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'inventory_model.dart';
import 'inventory_item_card.dart';

class MobileInventoryPage extends StatefulWidget {
  const MobileInventoryPage({super.key});

  @override
  State<MobileInventoryPage> createState() => _MobileInventoryPageState();
}

class _MobileInventoryPageState extends State<MobileInventoryPage> {
  final PageController _pageController = PageController();
  int _currentCategory = 0;

  final Color darkBg = const Color(0xFF1E2124);
  final Color cardBg = const Color(0xFF2A2E33);

  final List<Map<String, dynamic>> _categories = [
    {"name": "튜브 (Tube)", "color": const Color(0xFF4A5D66)},
    {"name": "피팅류 (Fitting)", "color": const Color(0xFF8A6345)},
    {"name": "밸브류 (Valve)", "color": const Color(0xFF00606B)},
    {"name": "가스켓 / 후렌지", "color": const Color(0xFF635666)},
    {"name": "볼트 / 너트", "color": const Color(0xFF3B5E52)},
  ];

  final Map<int, Map<String, ItemData>> _inventoryData = {
    0: {
      "1/4 inch (6.35mm)": ItemData(),
      "3/8 inch (9.52mm)": ItemData(),
      "1/2 inch (12.7mm)": ItemData(),
      "3/4 inch (19.05mm)": ItemData(),
    },
    1: {
      "Union (유니온)": ItemData(),
      "Elbow (엘보우)": ItemData(),
      "Tee (티)": ItemData(),
      "Male Connector": ItemData(),
    },
    2: {
      "Ball Valve (볼밸브)": ItemData(),
      "Needle Valve (니들밸브)": ItemData(),
      "Check Valve (체크밸브)": ItemData(),
    },
    3: {
      "10K 15A 가스켓": ItemData(),
      "10K 20A 가스켓": ItemData(),
      "10K 15A 후렌지 (RF)": ItemData(),
    },
    4: {
      "M6 x 20 볼트세트": ItemData(),
      "M8 x 25 볼트세트": ItemData(),
      "M10 x 30 볼트세트": ItemData(),
      "M12 너트 단품": ItemData(),
    },
  };

  final List<Map<String, dynamic>> _historyLogs = [];

  void _showQuantityInputDialog(
    int categoryIndex,
    String item,
    int currentQty,
  ) {
    TextEditingController qtyController = TextEditingController(
      text: currentQty.toString(),
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardBg,
          title: Text(
            "$item 수량 입력",
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
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
                  setState(
                    () => _inventoryData[categoryIndex]![item]!.qty = newQty,
                  );
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

  void _showAddNewItemDialog() {
    TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardBg,
          title: const Text(
            "신규 자재 등록",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: TextField(
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
                if (nameController.text.trim().isNotEmpty) {
                  setState(
                    () =>
                        _inventoryData[_currentCategory]![nameController.text
                            .trim()] = ItemData(
                          qty: 0,
                        ),
                  );
                }
                Navigator.pop(context);
              },
              child: const Text(
                "추가",
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

  void _showExtraInfoDialog(String item, ItemData data, String infoType) {
    TextEditingController ctrl = TextEditingController(
      text: infoType == 'HeatNo'
          ? data.heatNo
          : (infoType == 'Maker' ? data.maker : data.material),
    );
    List<String> quickOptions = [];
    if (infoType == 'Maker')
      quickOptions = ["Swagelok", "Parker", "Hy-Lok", "DK-Lok", "Sandvik"];
    if (infoType == 'Material')
      quickOptions = ["SS316L", "SS304", "Carbon Steel", "Brass", "Teflon"];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardBg,
          title: Text(
            infoType == 'HeatNo'
                ? "히트 넘버 입력"
                : (infoType == 'Maker' ? "제조사 선택" : "재질 선택"),
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  color: Colors.greenAccent,
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: darkBg,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          onPressed: () => ctrl.text = opt,
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
                  if (infoType == 'HeatNo')
                    data.heatNo = ctrl.text.trim().toUpperCase();
                  if (infoType == 'Maker')
                    data.maker = ctrl.text.trim().toUpperCase();
                  if (infoType == 'Material')
                    data.material = ctrl.text.trim().toUpperCase();
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

  bool _validateSync() {
    var currentItems = _inventoryData[_currentCategory]!;
    if (!currentItems.values.any((item) => item.qty > 0)) {
      _showErrorSnackBar("전송할 자재 수량이 0입니다.");
      return false;
    }
    for (var entry in currentItems.entries) {
      if (entry.value.qty > 0) {
        if (_currentCategory == 0 &&
            (entry.value.heatNo.isEmpty || entry.value.maker.isEmpty)) {
          _showErrorSnackBar("${entry.key}의 히트 넘버와 제조사를 확인해주세요.");
          return false;
        }
        if ((_currentCategory == 1 || _currentCategory == 2) &&
            entry.value.maker.isEmpty) {
          _showErrorSnackBar("${entry.key}의 제조사를 입력해주세요.");
          return false;
        }
        if ((_currentCategory == 3 || _currentCategory == 4) &&
            entry.value.material.isEmpty) {
          _showErrorSnackBar("${entry.key}의 재질을 입력해주세요.");
          return false;
        }
      }
    }
    return true;
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
    HapticFeedback.lightImpact();
  }

  void _syncToServer() {
    FocusScope.of(context).unfocus();
    if (!_validateSync()) return;

    HapticFeedback.heavyImpact();
    var currentItems = _inventoryData[_currentCategory]!;
    Map<String, dynamic> snapshot = {};
    currentItems.forEach((key, value) {
      if (value.qty > 0) {
        snapshot[key] = {
          'qty': value.qty,
          'heatNo': value.heatNo,
          'maker': value.maker,
          'material': value.material,
        };
      }
    });

    final newRecord = {
      "id": DateTime.now().millisecondsSinceEpoch.toString(),
      "time":
          "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
      "category": _categories[_currentCategory]['name'],
      "color": _categories[_currentCategory]['color'],
      "items": snapshot,
      "status": "pending",
    };

    setState(() {
      _historyLogs.insert(0, newRecord);
      currentItems.forEach((key, value) {
        value.qty = 0;
        value.heatNo = "";
        value.maker = "";
        value.material = "";
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("데이터를 전송 큐에 담았습니다."),
        backgroundColor: Colors.grey.shade800,
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(
        () => _historyLogs.firstWhere(
          (log) => log['id'] == newRecord['id'],
        )['status'] = "completed",
      );
      HapticFeedback.mediumImpact();
    });
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
                "자재 전송 기록",
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
                          "기록이 없습니다.",
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _historyLogs.length,
                        itemBuilder: (context, index) {
                          var log = _historyLogs[index];
                          bool isCompleted = log['status'] == 'completed';
                          Map<String, dynamic> items = log['items'];
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
                            trailing: Icon(
                              isCompleted ? Icons.check_circle : Icons.schedule,
                              color: isCompleted
                                  ? Colors.greenAccent
                                  : Colors.orangeAccent,
                            ),
                            children: items.entries.map((e) {
                              String detail = "수량: ${e.value['qty']}";
                              if (e.value['heatNo'] != "")
                                detail += " | Heat: ${e.value['heatNo']}";
                              if (e.value['maker'] != "")
                                detail += " | Maker: ${e.value['maker']}";
                              if (e.value['material'] != "")
                                detail += " | Mat: ${e.value['material']}";
                              return ListTile(
                                title: Text(
                                  e.key,
                                  style: TextStyle(
                                    color: Colors.grey.shade300,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  detail,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }).toList(),
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

  @override
  Widget build(BuildContext context) {
    var catColor = _categories[_currentCategory]['color'];

    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 90,
              width: double.infinity,
              color: catColor,
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "좌우로 스와이프하여 카테고리 변경",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _categories[_currentCategory]['name'],
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 16,
                    top: 0,
                    bottom: 0,
                    child: IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: _showAddNewItemDialog,
                      tooltip: "신규 자재 추가",
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) =>
                    setState(() => _currentCategory = index),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  var items = _inventoryData[index]!.keys.toList();
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      String itemName = items[i];
                      ItemData data = _inventoryData[index]![itemName]!;

                      return InventoryItemCard(
                        itemName: itemName,
                        data: data,
                        categoryIndex: index,
                        themeColor: catColor,
                        onUpdateQuantity: (delta) {
                          HapticFeedback.lightImpact();
                          setState(() {
                            int next = data.qty + delta;
                            if (next >= 0) data.qty = next;
                          });
                        },
                        onQuantityTap: () =>
                            _showQuantityInputDialog(index, itemName, data.qty),
                        onExtraInfoTap: (infoType) =>
                            _showExtraInfoDialog(itemName, data, infoType),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              color: darkBg,
              child: ElevatedButton(
                onPressed: _syncToServer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: catColor,
                  minimumSize: const Size.fromHeight(70),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload, color: Colors.white, size: 26),
                    SizedBox(width: 12),
                    Text(
                      "재고 데이터 전송",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showHistorySheet,
        backgroundColor: cardBg,
        child: const Icon(Icons.history, color: Colors.white),
      ),
    );
  }
}
