import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';

import 'inventory_model.dart';
import 'inventory_item_card.dart';
import 'mobile_inventory_ocr.dart';
import 'mobile_admin_management_page.dart';

part 'mobile_inventory_dialogs.dart';
part 'mobile_inventory_sync.dart';

// 🎨 미니멀 감성을 위한 색상 정의 (토스 스타일)
const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF191F28); // 부드러운 텍스트 블랙
const Color slate600 = Color(0xFF8B95A1); // 부드러운 텍스트 그레이
const Color slate100 = Color(0xFFF2F4F6); // 은은한 배경 그레이
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
      item.spec = docData['spec'] ?? '';
      item.projectName = docData['projectName'] ?? '';
      item.department = docData['department'] ?? '';
      item.minQty = docData['minQty'] ?? 0;
    } catch (_) {}
    return item;
  }

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
      // 🌟 전체 배경을 하얗게 변경하여 미니멀함 강조
      backgroundColor: pureWhite,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 🌟 상단 헤더: 그림자를 제거하고 깔끔한 면으로 처리
              Container(
                height: 100, // 헤더 높이를 키워 시원한 여백 확보
                width: double.infinity,
                decoration: BoxDecoration(color: catColor),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        catInfo['name'],
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900, // 토스 스타일의 강력한 타이포
                          color: Colors.white,
                          letterSpacing: -0.5, // 자간을 줄여 세련됨 강조
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
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

              // 🌟 카테고리 탭 표시기 (선택적)
              // 현재 스와이프로 넘어가지만, 시각적인 인디케이터 역할을 합니다.
              Container(
                color: pureWhite,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_categories.length, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _currentCategory == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentCategory == index ? catColor : slate100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),

              // 🌟 리스트 뷰 영역
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(), // 부드러운 스크롤
                  onPageChanged: (index) {
                    HapticFeedback.selectionClick();
                    setState(() => _currentCategory = index);
                  },
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
                              "등록된 자재가 없어요",
                              style: TextStyle(
                                color: slate600,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(
                            left: 24,
                            right: 24,
                            top: 8,
                            bottom: 40, // 하단 여백 넉넉히
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

                            // 🌟 아이템 카드 테마 설정 (그림자 제거, 은은한 테두리)
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

                            // 🌟 카드를 감싸는 영역 (여백 넉넉히)
                            Widget wrappedCard = Theme(
                              data: ThemeData.light().copyWith(
                                cardColor: pureWhite,
                                scaffoldBackgroundColor: pureWhite,
                                colorScheme: const ColorScheme.light(
                                  surface: pureWhite,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 16.0,
                                ), // 카드 간 간격 확대
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: pureWhite,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: slate100,
                                      width: 2,
                                    ), // 은은한 테두리
                                  ),
                                  child: itemCard,
                                ),
                              ),
                            );

                            return GestureDetector(
                              onLongPress: () {
                                HapticFeedback.heavyImpact();
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: pureWhite,
                                    surfaceTintColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: const Text(
                                      "항목 삭제",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    content: Text(
                                      isLocalNew
                                          ? "'$itemName' 항목을 전송 목록에서 지울까요?"
                                          : "'$itemName' 항목을 데이터베이스에서 완전히 지울까요?\n이 작업은 되돌릴 수 없어요.",
                                      style: const TextStyle(color: slate600),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
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
                                          backgroundColor: Colors.red.shade600,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
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
                                                    "삭제 중 오류가 발생했어요",
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
                                              content: Text("성공적으로 삭제됐어요"),
                                              behavior:
                                                  SnackBarBehavior.floating,
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

              // 🌟 하단 고정 버튼 영역 (그림자 제거, 미니멀한 라인 추가)
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    bottom: 24,
                    top: 16,
                  ),
                  decoration: const BoxDecoration(
                    color: pureWhite,
                    border: Border(top: BorderSide(color: slate100, width: 1)),
                  ),
                  child: SizedBox(
                    height: 60, // 버튼 높이 확대
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _syncToServer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: catColor,
                        elevation: 0, // 그림자 제거
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16), // 둥근 모서리
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
                              fontWeight: FontWeight.w800,
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
