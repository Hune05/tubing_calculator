import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:async';

import 'inventory_model.dart';
import 'inventory_item_card.dart';

part 'mobile_inventory_dialogs.dart';
part 'mobile_inventory_sync.dart';

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
                          catInfo['name'],
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
                      onPressed: () => _showAddNewItemDialog(catId),
                      tooltip: "현장에서 신규 자재 추가",
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
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: makitaTeal),
                        );
                      }

                      var dbDocs = snapshot.data!.docs;
                      var localNewDocs = _newLocalItems.entries
                          .where((e) => e.value['category'] == currentCatId)
                          .toList();

                      int totalCount = dbDocs.length + localNewDocs.length;

                      if (totalCount == 0) {
                        return Center(
                          child: Text(
                            "등록된 자재가 없습니다.",
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        );
                      }

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

                          if (i < dbDocs.length) {
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

                          return InventoryItemCard(
                            itemName: itemName,
                            data: displayData,
                            categoryIndex: index,
                            themeColor: _categories[index]['color'],
                            onUpdateQuantity: (delta) {
                              HapticFeedback.lightImpact();
                              setState(() {
                                if (!_localEdits.containsKey(docId)) {
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
                        },
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
