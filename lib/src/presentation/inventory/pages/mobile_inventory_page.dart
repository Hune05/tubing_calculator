import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:async';

import 'inventory_model.dart';
import 'inventory_item_card.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);

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

  final CollectionReference _inventoryDb = FirebaseFirestore.instance
      .collection('inventory');
  final CollectionReference _logsDb = FirebaseFirestore.instance.collection(
    'inventory_logs',
  );

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            "$item 실사 수량 입력",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            "신규 자재 등록",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
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
                "자재등록 완료",
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
          : (infoType == 'Maker'
                ? data.maker
                : (infoType == 'Material' ? data.material : data.location)),
    );

    List<String> quickOptions = [];

    if (infoType == 'Maker') {
      quickOptions = ["HY-LOK", "SWAGELOK", "PARKER"];
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
                            setState(() {
                              ctrl.text = opt;
                            });
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
                  if (infoType == 'HeatNo') {
                    data.heatNo = ctrl.text.trim().toUpperCase();
                  }
                  if (infoType == 'Maker') {
                    data.maker = ctrl.text.trim().toUpperCase();
                  }
                  if (infoType == 'Material') {
                    data.material = ctrl.text.trim().toUpperCase();
                  }
                  if (infoType == 'Location') {
                    data.location = ctrl.text.trim().toUpperCase();
                  }
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
      _showErrorSnackBar("전송할 실사 수량이 없습니다.");
      return false;
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

  Future<void> _syncToServer() async {
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
          'location': value.location,
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
      "status": "syncing",
    };

    setState(() => _historyLogs.insert(0, newRecord));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("서버로 실사 데이터를 전송 중입니다..."),
        backgroundColor: makitaTeal,
      ),
    );

    try {
      for (var entry in snapshot.entries) {
        String itemName = entry.key;
        var data = entry.value;
        int physicalQty = data['qty'];

        final querySnap = await _inventoryDb
            .where('name', isEqualTo: itemName)
            .limit(1)
            .get();

        if (querySnap.docs.isNotEmpty) {
          var doc = querySnap.docs.first;
          int systemQty = doc['qty'] ?? 0;
          int diff = physicalQty - systemQty;

          await _inventoryDb.doc(doc.id).update({
            'qty': physicalQty,
            if (data['location'] != "") 'location': data['location'],
            if (data['heatNo'] != "") 'heatNo': data['heatNo'],
          });

          if (diff != 0) {
            await _logsDb.add({
              'type': 'AUDIT',
              'project_name': '📱 모바일 현장 실사',
              'material_name': itemName,
              'qty': diff.abs(),
              'sign': diff > 0 ? '+' : '-',
              'unit': 'EA',
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
        } else {
          await _inventoryDb.add({
            'name': itemName,
            'category': _categories[_currentCategory]['name'],
            'maker': data['maker'] != "" ? data['maker'] : "HY-LOK",
            'qty': physicalQty,
            'location': data['location'],
            'heatNo': data['heatNo'],
            'status': '정상',
            'is_dead_stock': false,
            'is_reorder_needed': false,
            'unit': 'EA',
            'createdAt': FieldValue.serverTimestamp(),
          });

          await _logsDb.add({
            'type': 'IN',
            'project_name': '📱 모바일 신규 등록',
            'material_name': itemName,
            'qty': physicalQty,
            'unit': 'EA',
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _historyLogs.firstWhere(
          (log) => log['id'] == newRecord['id'],
        )['status'] = "completed";
        currentItems.forEach((key, value) {
          value.qty = 0;
          value.heatNo = "";
          value.maker = "";
          value.material = "";
          value.location = "";
        });
      });
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("서버 동기화 완료!"),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _historyLogs.firstWhere(
          (log) => log['id'] == newRecord['id'],
        )['status'] = "failed",
      );
      _showErrorSnackBar("전송 실패: 네트워크를 확인하세요.");
    }
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
                "현장 실사(Audit) 기록",
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
                            children: items.entries.map((e) {
                              String detail = "실사 수량: ${e.value['qty']}";
                              if (e.value['location'] != "") {
                                detail += " | Loc: ${e.value['location']}";
                              }
                              if (e.value['heatNo'] != "") {
                                detail += " | Heat: ${e.value['heatNo']}";
                              }
                              if (e.value['maker'] != "") {
                                detail += " | Maker: ${e.value['maker']}";
                              }

                              return ListTile(
                                title: Text(
                                  e.key,
                                  style: TextStyle(
                                    color: Colors.grey.shade300,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
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
                    Icon(LucideIcons.scale, color: Colors.white, size: 26),
                    SizedBox(width: 12),
                    Text(
                      "실사 데이터(Audit) 서버 전송",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
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
