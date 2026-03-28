import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';

import 'inventory_model.dart';
import 'inventory_item_card.dart';
import 'mobile_inventory_ocr.dart';

part 'mobile_inventory_dialogs.dart';
part 'mobile_inventory_sync.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class MobileInventoryPage extends StatefulWidget {
  final String workerName;

  const MobileInventoryPage({super.key, required this.workerName});

  @override
  State<MobileInventoryPage> createState() => _MobileInventoryPageState();
}

class _MobileInventoryPageState extends State<MobileInventoryPage> {
  final PageController _pageController = PageController();
  int _currentCategory = 0;

  final CollectionReference _inventoryDb = FirebaseFirestore.instance
      .collection('inventory');
  final CollectionReference _logsDb = FirebaseFirestore.instance.collection(
    'inventory_logs',
  );

  final List<Map<String, dynamic>> _categories = [
    {"id": "TUBE", "name": "튜브 (Tube)", "color": const Color(0xFF4A5D66)},
    {
      "id": "FITTING",
      "name": "피팅류 (Fitting)",
      "color": const Color(0xFF8A6345),
    },
    {"id": "VALVE", "name": "밸브류 (Valve)", "color": const Color(0xFF00606B)},
    {"id": "FLANGE", "name": "가스켓 / 후렌지", "color": const Color(0xFF635666)},
    {"id": "기타", "name": "기타 / 볼트", "color": const Color(0xFF3B5E52)},
  ];

  final Map<String, ItemData> _localEdits = {};
  final Map<String, Map<String, dynamic>> _newLocalItems = {};
  final List<Map<String, dynamic>> _historyLogs = [];

  ItemData _createItemDataFromDoc(Map<String, dynamic> docData) {
    ItemData item = ItemData();
    item.qty = docData['qty'] ?? 0;
    try {
      item.heatNo = docData['heatNo'] ?? '';
      item.maker = docData['maker'] ?? '';
      item.location = docData['location'] ?? '';
      item.material = docData['material'] ?? '';
    } catch (_) {}
    return item;
  }

  @override
  Widget build(BuildContext context) {
    var catInfo = _categories[_currentCategory];
    var catColor = catInfo['color'] as Color;
    var catId = catInfo['id'] as String;

    return Scaffold(
      backgroundColor: slate100,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              height: 90,
              width: double.infinity,
              decoration: BoxDecoration(
                color: catColor,
                boxShadow: [
                  BoxShadow(
                    color: catColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    // 🚀 쓸데없는 이름표와 스와이프 안내문 삭제, 카테고리 이름만 중앙에 시원하게 배치!
                    child: Text(
                      catInfo['name'],
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
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
                      onPressed: () => _showAddNewItemDialog(catId),
                      tooltip: "현장에서 신규 자재 추가",
                    ),
                  ),
                  Positioned(
                    left: 16,
                    top: 0,
                    bottom: 0,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
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
                  String currentCatId = _categories[index]['id'];

                  return StreamBuilder<QuerySnapshot>(
                    stream: _inventoryDb
                        .where('category', isEqualTo: currentCatId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const Center(
                          child: CircularProgressIndicator(color: makitaTeal),
                        );

                      var dbDocs = snapshot.data!.docs;
                      var localNewDocs = _newLocalItems.entries
                          .where((e) => e.value['category'] == currentCatId)
                          .toList();
                      int totalCount = dbDocs.length + localNewDocs.length;

                      if (totalCount == 0)
                        return const Center(
                          child: Text(
                            "등록된 자재가 없습니다.",
                            style: TextStyle(color: slate600, fontSize: 16),
                          ),
                        );

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 20,
                        ),
                        itemCount: totalCount,
                        itemBuilder: (context, i) {
                          String docId;
                          String itemName;
                          ItemData displayData;
                          bool isLocalNew = i >= dbDocs.length;

                          if (!isLocalNew) {
                            var doc = dbDocs[i];
                            docId = doc.id;
                            itemName = doc['name'] ?? '이름 없음';
                            if (_localEdits.containsKey(docId)) {
                              displayData = _localEdits[docId]!;
                            } else {
                              displayData = _createItemDataFromDoc(
                                doc.data() as Map<String, dynamic>,
                              );
                            }
                          } else {
                            var newDoc = localNewDocs[i - dbDocs.length];
                            docId = newDoc.key;
                            itemName = newDoc.value['name'];
                            displayData = _localEdits[docId]!;
                          }

                          Widget itemCard = InventoryItemCard(
                            itemName: itemName,
                            data: displayData,
                            categoryIndex: index,
                            themeColor: _categories[index]['color'],
                            onUpdateQuantity: (delta) {
                              HapticFeedback.lightImpact();
                              setState(() {
                                if (!_localEdits.containsKey(docId) &&
                                    !isLocalNew) {
                                  _localEdits[docId] = _createItemDataFromDoc(
                                    dbDocs[i].data() as Map<String, dynamic>,
                                  );
                                }
                                int next = _localEdits[docId]!.qty + delta;
                                if (next >= 0) _localEdits[docId]!.qty = next;
                              });
                            },
                            onQuantityTap: () => _showQuantityInputDialog(
                              docId,
                              itemName,
                              displayData.qty,
                            ),
                            onExtraInfoTap: (infoType) => _showExtraInfoDialog(
                              docId,
                              displayData,
                              infoType,
                            ),
                          );

                          if (isLocalNew) {
                            return GestureDetector(
                              onLongPress: () {
                                HapticFeedback.heavyImpact();
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text(
                                      "항목 삭제",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    content: Text(
                                      "'$itemName' 항목을 전송 목록에서 삭제하시겠습니까?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text(
                                          "취소",
                                          style: TextStyle(color: slate600),
                                        ),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red.shade600,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _newLocalItems.remove(docId);
                                            _localEdits.remove(docId);
                                          });
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text("삭제되었습니다."),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          "삭제",
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
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: itemCard,
                              ),
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: itemCard,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: pureWhite,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: ElevatedButton(
                  onPressed: _syncToServer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: catColor,
                    minimumSize: const Size.fromHeight(64),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.scale, color: Colors.white, size: 24),
                      SizedBox(width: 10),
                      Text(
                        "자재 목록 서버 전송",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showHistorySheet,
        backgroundColor: pureWhite,
        elevation: 4,
        child: const Icon(Icons.history, color: slate900),
      ),
    );
  }
}
