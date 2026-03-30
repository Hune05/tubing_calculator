import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'mobile_inventory_checkout_page.dart';
import 'mobile_inventory_logs_page.dart'; // 🚀 로그 페이지 연결 완료!

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

  final List<String> _categories = [
    "ALL",
    "TUBE",
    "FITTING",
    "VALVE",
    "FLANGE",
    "GASKET",
    "기타",
  ];

  void _navigateToCheckout(
    String docId,
    String itemName,
    int currentQty,
    bool isCheckout,
    bool isPinned,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MobileInventoryCheckoutPage(
          docId: docId,
          itemName: itemName,
          currentQty: currentQty,
          isCheckout: isCheckout,
          workerName: widget.workerName,
          isPinned: isPinned,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slate100,
      appBar: AppBar(
        backgroundColor: makitaTeal,
        elevation: 0,
        iconTheme: const IconThemeData(color: pureWhite),
        title: const Text(
          "자재 현황 조회",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: pureWhite,
          ),
        ),
        // 🚀 우측 상단에 로그 화면으로 가는 버튼 추가
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
      ),
      body: Column(
        children: [
          // 검색창
          Container(
            color: makitaTeal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                prefixIcon: Icon(
                  LucideIcons.search,
                  color: Colors.grey.shade500,
                ),
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
          // 카테고리 필터
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onSelected: (selected) =>
                        setState(() => _selectedCategory = cat),
                  ),
                );
              },
            ),
          ),
          // 자재 목록
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _inventoryDb.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: makitaTeal),
                  );
                }

                // 1. 검색 및 카테고리 필터링
                List<DocumentSnapshot> filteredDocs = snapshot.data!.docs.where(
                  (doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    bool categoryMatch =
                        _selectedCategory == "ALL" ||
                        data['category'] == _selectedCategory;
                    String target =
                        "${data['name']} ${data['size']} ${data['location']}"
                            .toLowerCase();
                    return categoryMatch && target.contains(_searchQuery);
                  },
                ).toList();

                // 2. 최상단 고정 정렬 로직 (내 자재를 맨 위로)
                filteredDocs.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;

                  List<dynamic> workersA = dataA['activeWorkers'] ?? [];
                  List<dynamic> workersB = dataB['activeWorkers'] ?? [];

                  bool isPinnedA = workersA.contains(widget.workerName);
                  bool isPinnedB = workersB.contains(widget.workerName);

                  if (isPinnedA && !isPinnedB) return -1;
                  if (!isPinnedA && isPinnedB) return 1;

                  Timestamp? timeA = dataA['createdAt'];
                  Timestamp? timeB = dataB['createdAt'];
                  if (timeA != null && timeB != null) {
                    return timeB.compareTo(timeA);
                  }
                  return 0;
                });

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text("검색 결과가 없습니다."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    int qty = data['qty'] ?? 0;
                    int minQty = data['min_qty'] ?? 10;
                    bool isLowStock = qty < minQty;
                    bool canCheckout = qty > 0;
                    String itemName = data['name'] ?? "이름 없음";

                    List<dynamic> activeWorkers = data['activeWorkers'] ?? [];
                    bool isPinned = activeWorkers.contains(widget.workerName);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isPinned ? Colors.blue.shade50 : pureWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPinned
                              ? Colors.blue.shade300
                              : (isLowStock
                                    // 🚀 경고 해결: withOpacity 대신 withValues 사용
                                    ? Colors.redAccent.withValues(alpha: 0.5)
                                    : Colors.grey.shade300),
                          width: isPinned || isLowStock ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            // 🚀 경고 해결: withOpacity 대신 withValues 사용
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isPinned)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade600,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.push_pin,
                                    size: 12,
                                    color: pureWhite,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    "내 작업 자재",
                                    style: TextStyle(
                                      color: pureWhite,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      itemName,
                                      style: const TextStyle(
                                        color: slate900,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    if ((data['location'] ?? "").isNotEmpty)
                                      _buildInfoBadge(
                                        Icons.location_on,
                                        data['location'],
                                        Colors.orange.shade800,
                                      ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "규격: ${data['size'] ?? '-'} | 재질: ${data['material'] ?? '-'}",
                                      style: const TextStyle(
                                        color: slate600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "$qty",
                                    style: TextStyle(
                                      color: isLowStock
                                          ? Colors.red.shade700
                                          : slate900,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    data['unit'] ?? "EA",
                                    style: const TextStyle(
                                      color: slate600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: canCheckout
                                    ? () => _navigateToCheckout(
                                        doc.id,
                                        itemName,
                                        qty,
                                        true,
                                        isPinned,
                                      )
                                    : null,
                                icon: Icon(
                                  LucideIcons.minusCircle,
                                  size: 16,
                                  color: canCheckout
                                      ? Colors.orange.shade700
                                      : Colors.grey.shade400,
                                ),
                                label: Text(
                                  "불출",
                                  style: TextStyle(
                                    color: canCheckout
                                        ? Colors.orange.shade700
                                        : Colors.grey.shade400,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: canCheckout
                                        ? Colors.orange.shade200
                                        : Colors.grey.shade200,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => _navigateToCheckout(
                                  doc.id,
                                  itemName,
                                  qty,
                                  false,
                                  isPinned,
                                ),
                                icon: const Icon(
                                  LucideIcons.plusCircle,
                                  size: 16,
                                  color: makitaTeal,
                                ),
                                label: const Text(
                                  "반납 / 완료",
                                  style: TextStyle(
                                    color: makitaTeal,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: makitaTeal),
                                ),
                              ),
                            ],
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
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        // 🚀 경고 해결: withOpacity 대신 withValues 사용
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
