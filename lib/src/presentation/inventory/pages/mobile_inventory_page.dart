import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart'; // 날짜 포맷팅을 위해 추가 (1단계 패키지 설치 필요)
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

  // 🔒 관리자 모드 상태 및 임시 비밀번호 설정
  bool _isAdminMode = false;
  final String _adminPassword = "admin";

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

  // 📡 [핵심 연동] 모바일 기기용 통합 로그 기록 함수
  Future<void> recordMobileLog({
    required String itemName,
    required String action, // 예: '수량 변경', '신규 등록', '삭제'
    required int qty,
  }) async {
    try {
      await _logsDb.add({
        'itemName': itemName,
        'action': action,
        'qty': qty,
        'workerName': widget.workerName, // 로그인한 작업자 이름
        'device': 'Mobile', // 📱 모바일에서 발생한 이벤트임을 명시
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("로그 저장 실패: $e");
    }
  }

  // 🔑 관리자 자물쇠 기능 로직
  void _toggleAdminMode() {
    if (_isAdminMode) {
      setState(() => _isAdminMode = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("관리자 모드가 해제되었습니다.")));
      return;
    }

    TextEditingController pwController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: slate900),
            SizedBox(width: 8),
            Text("관리자 권한 필요", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: TextField(
          controller: pwController,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: "관리자 비밀번호를 입력하세요",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소", style: TextStyle(color: slate600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: makitaTeal),
            onPressed: () {
              if (pwController.text == _adminPassword) {
                setState(() => _isAdminMode = true);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("관리자 모드가 활성화되었습니다.")),
                );
              } else {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("비밀번호가 틀렸습니다.")));
              }
            },
            child: const Text("잠금 해제", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 📜 모바일용 실시간 로그(기록) 확인 바텀 시트
  void _showMobileLogSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: slate900,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.history, color: pureWhite),
                  SizedBox(width: 10),
                  Text(
                    "전체 작업 기록 (태블릿/모바일 통합)",
                    style: TextStyle(
                      color: pureWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // 최신 기록이 위로 오도록 정렬하고, 최근 50개만 불러옵니다.
                stream: _logsDb
                    .orderBy('timestamp', descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: makitaTeal),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "아직 기록된 로그가 없습니다.",
                        style: TextStyle(color: slate600),
                      ),
                    );
                  }

                  var logs = snapshot.data!.docs;

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: logs.length,
                    // 경고 수정: (_, __) 대신 명확한 변수명 사용
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      var data = logs[index].data() as Map<String, dynamic>;
                      String itemName = data['itemName'] ?? '알 수 없음';
                      String action = data['action'] ?? '-';
                      int qty = data['qty'] ?? 0;
                      String worker = data['workerName'] ?? '미상';
                      String device = data['device'] ?? 'Tablet'; // 기본값은 태블릿

                      Timestamp? ts = data['timestamp'] as Timestamp?;
                      String timeStr = ts != null
                          ? DateFormat('MM-dd HH:mm').format(ts.toDate())
                          : '시간 정보 없음';

                      // 기기에 따라 아이콘 다르게 표시
                      IconData deviceIcon = device == 'Mobile'
                          ? Icons.smartphone
                          : Icons.tablet_mac;
                      Color iconColor = device == 'Mobile'
                          ? Colors.blue.shade700
                          : Colors.green.shade700;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: iconColor.withOpacity(0.1),
                          child: Icon(deviceIcon, color: iconColor, size: 20),
                        ),
                        title: Text(
                          itemName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Text(
                                worker,
                                style: const TextStyle(
                                  color: slate600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(" • "),
                              Text(
                                action,
                                style: TextStyle(
                                  color: action.contains('삭제')
                                      ? Colors.red
                                      : slate600,
                                ),
                              ),
                              const Text(" • "),
                              Text(
                                timeStr,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: Text(
                          "${qty > 0 ? '+' : ''}$qty",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: qty > 0
                                ? Colors.green.shade700
                                : (qty < 0 ? Colors.red.shade700 : slate900),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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
                        if (_isAdminMode)
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
                          icon: Icon(
                            _isAdminMode ? Icons.lock_open : Icons.lock,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: _toggleAdminMode,
                          tooltip: _isAdminMode ? "관리자 모드 해제" : "관리자 권한 잠금 해제",
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

                          Widget wrappedCard = Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: itemCard,
                          );

                          if (_isAdminMode || isLocalNew) {
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
                                              // 📡 삭제 시 로그 기록 호출
                                              await recordMobileLog(
                                                itemName: itemName,
                                                action: '완전 삭제',
                                                qty: displayData.qty,
                                              );
                                            } catch (e) {
                                              // 경고 수정: 안전장치 추가
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

                                          // 경고 수정: 안전장치 추가
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
                          }
                          return wrappedCard;
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
      // 📡 모바일용 로그 뷰어로 변경된 플로팅 액션 버튼
      floatingActionButton: FloatingActionButton(
        onPressed: _showMobileLogSheet,
        backgroundColor: pureWhite,
        elevation: 4,
        child: const Icon(Icons.history, color: slate900),
      ),
    );
  }
}
