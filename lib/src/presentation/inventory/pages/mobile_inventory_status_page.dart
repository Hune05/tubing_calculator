import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';

// 🎨 화이트 & 마키타 테마 컬러 공통 선언
const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class MobileInventoryStatusPage extends StatefulWidget {
  const MobileInventoryStatusPage({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slate100, // 💡 전체 배경 밝게
      appBar: AppBar(
        backgroundColor: makitaTeal, // 💡 앱바는 마키타 컬러
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
      ),
      body: Column(
        children: [
          // 1. 검색 바
          Container(
            color: makitaTeal, // 앱바와 이어지는 느낌
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
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.normal,
                ),
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

          // 2. 카테고리 필터
          Container(
            height: 56,
            color: pureWhite, // 필터 영역 흰색 배경
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
                    side: BorderSide(
                      color: isSelected ? makitaTeal : Colors.grey.shade300,
                    ),
                    onSelected: (selected) {
                      setState(() => _selectedCategory = cat);
                    },
                  ),
                );
              },
            ),
          ),

          // 3. 자재 리스트 결과
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _inventoryDb
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      "데이터를 불러오는 중 에러가 발생했습니다.",
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: makitaTeal),
                  );
                }

                final docs = snapshot.data!.docs;
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  bool categoryMatch =
                      _selectedCategory == "ALL" ||
                      data['category'] == _selectedCategory;

                  String itemName = (data['name'] ?? "")
                      .toString()
                      .toLowerCase();
                  String itemSize = (data['size'] ?? "")
                      .toString()
                      .toLowerCase();
                  String itemLoc = (data['location'] ?? "")
                      .toString()
                      .toLowerCase();

                  bool searchMatch =
                      itemName.contains(_searchQuery) ||
                      itemSize.contains(_searchQuery) ||
                      itemLoc.contains(_searchQuery);

                  return categoryMatch && searchMatch;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Text(
                      "검색 결과가 없습니다.",
                      style: TextStyle(color: slate600, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data =
                        filteredDocs[index].data() as Map<String, dynamic>;
                    int qty = data['qty'] ?? 0;
                    int minQty = data['min_qty'] ?? 10;
                    bool isLowStock = qty < minQty;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: pureWhite, // 💡 카드 배경 하얗게
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLowStock
                              ? Colors.redAccent.withValues(alpha: 0.5)
                              : Colors.grey.shade300,
                          width: isLowStock ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['name'] ?? "이름 없음",
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
                                if ((data['maker'] ?? "").isNotEmpty)
                                  Text(
                                    "제조사: ${data['maker']}",
                                    style: const TextStyle(
                                      color: slate600,
                                      fontSize: 12,
                                    ),
                                  ),
                                if ((data['heatNo'] ?? "").isNotEmpty)
                                  Text(
                                    "Heat No: ${data['heatNo']}",
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
                                      : slate900, // 💡 정상 수량은 진한 글씨로
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
                              if (isLowStock)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.red.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    "재고 부족",
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
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
