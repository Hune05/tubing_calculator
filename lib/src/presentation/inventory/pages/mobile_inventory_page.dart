import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import 'inventory_model.dart';
import 'inventory_item_card.dart';
import 'mobile_inventory_ocr.dart';
import 'mobile_admin_management_page.dart';

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

  bool _isAdminMode = true;

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
  // _historyLogs 변수는 로그 화면 삭제로 사용되지 않아 제거해도 되지만,
  // 다른 파트 파일에서 참조할 가능성을 대비해 유지합니다.
  final List<Map<String, dynamic>> _historyLogs = [];

  ItemData _createItemDataFromDoc(Map<String, dynamic> docData) {
    ItemData item = ItemData();
    item.qty = docData['qty'] ?? 0;
    try {
      item.heatNo = docData['heatNo'] ?? '';
      item.maker = docData['maker'] ?? '';
      item.location = docData['location'] ?? '';
      item.material = docData['material'] ?? '';

      // ★ 이 부분이 빠져있어서 화면에서 증발했던 것입니다! ★
      item.spec = docData['spec'] ?? '';
      item.projectName = docData['projectName'] ?? '';
      item.department = docData['department'] ?? '';
      item.minQty = docData['minQty'] ?? 0;
    } catch (_) {}
    return item;
  }

  // 화면(UI)은 날렸지만, 데이터베이스에 작업 이력을 남기는 필수 로직은 유지합니다.
  Future<void> recordMobileLog({
    required String itemName,
    required String action,
    required int qty,
  }) async {
    try {
      await _logsDb.add({
        'itemName': itemName,
        'action': action,
        'qty': qty,
        'workerName': widget.workerName,
        'device': 'Mobile',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("로그 저장 실패: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    var catInfo = _categories[_currentCategory];
    var catColor = catInfo['color'] as Color;
    var catId = catInfo['id'] as String;

    return Scaffold(
      backgroundColor: slate100,
      // [개선 적용] 다이얼로그나 검색창 등에서 키보드가 올라왔을 때, 빈 여백 터치 시 키보드를 숨겨줍니다.
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
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
                      color: catColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Center(
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
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed: () => _showAddNewItemDialog(catId),
                            tooltip: "현장에서 신규 자재 추가",
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.manage_accounts,
                              color: Colors.white,
                              size: 28,
                            ),
                            tooltip: "관리자 권한 관리",
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const MobileAdminManagementPage(),
                                ),
                              );
                            },
                          ),
                        ],
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
                          return const Center(
                            child: Text(
                              "등록된 자재가 없습니다.",
                              style: TextStyle(color: slate600, fontSize: 16),
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
                            bool isLocalNew = i >= dbDocs.length;

                            if (!isLocalNew) {
                              var doc = dbDocs[i];
                              docId = doc.id;

                              final dataMap =
                                  doc.data() as Map<String, dynamic>?;
                              itemName = dataMap?['name'] ?? '이름 없음';

                              if (_localEdits.containsKey(docId)) {
                                displayData = _localEdits[docId]!;
                              } else {
                                displayData = _createItemDataFromDoc(
                                  dataMap ?? {},
                                );
                              }
                            } else {
                              var newDoc = localNewDocs[i - dbDocs.length];
                              docId = newDoc.key;
                              itemName = newDoc.value['name'] ?? '이름 없음';
                              displayData =
                                  _localEdits[docId] ??
                                  _createItemDataFromDoc(newDoc.value);
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
                                      (dbDocs[i].data()
                                              as Map<String, dynamic>?) ??
                                          {},
                                    );
                                  }
                                  int next =
                                      (_localEdits[docId]?.qty ?? 0) + delta;
                                  if (next >= 0) _localEdits[docId]!.qty = next;
                                });
                              },
                              onQuantityTap: () => _showQuantityInputDialog(
                                docId,
                                itemName,
                                displayData.qty,
                              ),
                              onExtraInfoTap: (infoType) =>
                                  _showExtraInfoDialog(
                                    docId,
                                    displayData,
                                    infoType,
                                  ),
                            );

                            // 🚀 [핵심 해결 유지] 다크모드 무시하고 항상 흰색 카드로 렌더링
                            Widget wrappedCard = Theme(
                              data: ThemeData.light().copyWith(
                                cardColor: pureWhite,
                                scaffoldBackgroundColor: pureWhite,
                                colorScheme: const ColorScheme.light(
                                  surface: pureWhite,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: itemCard,
                              ),
                            );

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
                                      isLocalNew
                                          ? "'$itemName' 항목을 전송 목록에서 삭제하시겠습니까?"
                                          : "'$itemName' 항목을 데이터베이스에서 완전히 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.",
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
                                        onPressed: () async {
                                          Navigator.pop(context);

                                          if (isLocalNew) {
                                            setState(() {
                                              _newLocalItems.remove(docId);
                                              _localEdits.remove(docId);
                                            });
                                          } else {
                                            try {
                                              await _inventoryDb
                                                  .doc(docId)
                                                  .delete();
                                              setState(() {
                                                _localEdits.remove(docId);
                                              });
                                              await recordMobileLog(
                                                itemName: itemName,
                                                action: '완전 삭제',
                                                qty: displayData.qty,
                                              );
                                            } catch (e) {
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    "삭제 중 오류가 발생했습니다.",
                                                  ),
                                                ),
                                              );
                                              return;
                                            }
                                          }

                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text("성공적으로 삭제되었습니다."),
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
                              child: wrappedCard,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              // 하단 서버 전송 버튼 고정 영역
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: pureWhite,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: SizedBox(
                    height: 60,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _syncToServer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: catColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.scale,
                            color: Colors.white,
                            size: 24,
                          ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
