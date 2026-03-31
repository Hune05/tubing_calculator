import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'mobile_inventory_logs_page.dart';
import 'mobile_inventory_checkout_page.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class MobileInventoryStatusPage extends StatefulWidget {
  final String workerName;

  const MobileInventoryStatusPage({super.key, required this.workerName});

  @override
  State<MobileInventoryStatusPage> createState() =>
      _MobileInventoryStatusPageState();
}

class _MobileInventoryStatusPageState extends State<MobileInventoryStatusPage> {
  String _searchQuery = "";
  String _selectedCategory = "ALL";
  final TextEditingController _searchController = TextEditingController();

  final CollectionReference _inventoryDb = FirebaseFirestore.instance
      .collection('inventory');
  final CollectionReference _checkoutsDb = FirebaseFirestore.instance
      .collection('checkouts');

  final List<String> _categories = [
    "ALL",
    "TUBE",
    "FITTING",
    "VALVE",
    "FLANGE",
    "GASKET",
    "기타",
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: slate100,
        appBar: AppBar(
          backgroundColor: makitaTeal,
          elevation: 0,
          iconTheme: const IconThemeData(color: pureWhite),
          title: const Text(
            "자재 현장 지원",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: pureWhite,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.clipboardList),
              tooltip: '로그 기록 보기',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MobileInventoryLogsPage(),
                  ),
                );
              },
            ),
          ],
          bottom: const TabBar(
            labelColor: pureWhite,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.amber,
            indicatorWeight: 4,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            tabs: [
              Tab(text: "전체 자재 창고"),
              Tab(text: "내 불출 목록"),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildAllInventoryTab(), _buildMyCheckoutsTab()],
        ),
      ),
    );
  }

  // ==========================================
  // 탭 1: 전체 자재 목록
  // ==========================================
  Widget _buildAllInventoryTab() {
    return Column(
      children: [
        Container(
          color: makitaTeal,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(
              color: slate900,
              fontWeight: FontWeight.bold,
            ),
            onChanged: (val) =>
                setState(() => _searchQuery = val.toLowerCase()),
            decoration: InputDecoration(
              hintText: "자재명, 규격, 위치 검색...",
              prefixIcon: Icon(LucideIcons.search, color: Colors.grey.shade500),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey.shade500),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                      },
                    )
                  : null,
              filled: true,
              fillColor: pureWhite,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Container(
          height: 56,
          color: pureWhite,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected ? pureWhite : slate600,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: makitaTeal,
                  backgroundColor: slate100,
                  showCheckmark: false,
                  onSelected: (selected) =>
                      setState(() => _selectedCategory = cat),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _inventoryDb.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(
                  child: CircularProgressIndicator(color: makitaTeal),
                );

              List<DocumentSnapshot> filteredDocs = snapshot.data!.docs.where((
                doc,
              ) {
                final data = doc.data() as Map<String, dynamic>;
                bool categoryMatch =
                    _selectedCategory == "ALL" ||
                    data['category'] == _selectedCategory;
                String target =
                    "${data['name']} ${data['size']} ${data['location']}"
                        .toLowerCase();
                return categoryMatch && target.contains(_searchQuery);
              }).toList();

              if (filteredDocs.isEmpty)
                return const Center(
                  child: Text(
                    "검색 결과가 없습니다.",
                    style: TextStyle(color: slate600),
                  ),
                );

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  int qty = data['qty'] ?? 0;
                  String itemName = data['name'] ?? "이름 없음";
                  String unit = data['unit'] ?? "EA";
                  bool canCheckout = qty > 0;

                  // 🚀 시꺼멓게 변하는 원인(Card) 제거 -> 강제 하얀색 배경 Container 사용
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: pureWhite, // 절대 검게 안 변함
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 1. 자재 정보 (가장 눈에 먼저 띄게)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                itemName,
                                style: const TextStyle(
                                  color: slate900,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "재고: $qty $unit",
                                style: TextStyle(
                                  color: canCheckout
                                      ? Colors.orange.shade800
                                      : Colors.red,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "규격: ${data['size'] ?? '-'}  |  위치: ${data['location'] ?? '-'}",
                                style: const TextStyle(
                                  color: slate600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 2. 조용하고 얌전한 버튼 (우측)
                        OutlinedButton(
                          onPressed: canCheckout
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          MobileInventoryCheckoutPage(
                                            docId: doc.id,
                                            itemName: itemName,
                                            currentQty: qty,
                                            unit: unit,
                                            isCheckout: true,
                                            workerName: widget.workerName,
                                          ),
                                    ),
                                  );
                                }
                              : null,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: canCheckout
                                  ? Colors.orange.shade700
                                  : Colors.grey.shade300,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                          ),
                          child: Text(
                            "불출",
                            style: TextStyle(
                              color: canCheckout
                                  ? Colors.orange.shade700
                                  : Colors.grey.shade400,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
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
        ),
      ],
    );
  }

  // ==========================================
  // 탭 2: 내 불출 목록 (시꺼먼 오류 완벽 해결)
  // ==========================================
  Widget _buildMyCheckoutsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _checkoutsDb
          .where('workerName', isEqualTo: widget.workerName)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: makitaTeal),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 60,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                const Text(
                  "현재 불출 중인 자재가 없습니다.",
                  style: TextStyle(color: slate600, fontSize: 16),
                ),
              ],
            ),
          );
        }

        var docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          var aData = a.data() as Map<String, dynamic>;
          var bData = b.data() as Map<String, dynamic>;
          Timestamp? tA = aData['timestamp'] as Timestamp?;
          Timestamp? tB = bData['timestamp'] as Timestamp?;
          if (tA == null && tB == null) return 0;
          if (tA == null) return -1;
          if (tB == null) return 1;
          return tB.compareTo(tA);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            String itemId = data['itemId'] ?? '';
            String itemName = data['itemName'] ?? '이름 없음';
            int qty = data['checkoutQty'] ?? 0;
            String unit = data['unit'] ?? 'EA';
            String reason = data['reason'] ?? '사유 없음';

            // 🚀 시꺼멓게 변하는 원인(Card) 제거 -> 강제 하얀색 배경 Container 사용
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: pureWhite, // 절대 검게 안 변함
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. 자재 정보 (시선 집중 영역)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: slate900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "불출수량: $qty $unit",
                          style: const TextStyle(
                            color: makitaTeal,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "사유: $reason",
                          style: const TextStyle(color: slate600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 2. 조용하고 얌전한 버튼 (우측)
                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MobileInventoryCheckoutPage(
                            docId: itemId,
                            itemName: itemName,
                            currentQty: qty,
                            unit: unit,
                            isCheckout: false,
                            workerName: widget.workerName,
                            checkoutDocId: doc.id,
                            checkoutReason: reason,
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: makitaTeal),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                    ),
                    child: const Text(
                      "반납/완료",
                      style: TextStyle(
                        color: makitaTeal,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
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
}
