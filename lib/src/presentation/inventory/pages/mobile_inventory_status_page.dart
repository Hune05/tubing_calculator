import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';

const Color darkBg = Color(0xFF1E2124);
const Color cardBg = Color(0xFF2A2E33);
const Color mutedWhite = Color(0xFFD0D4D9);
const Color makitaTeal = Color(0xFF007580);

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
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        elevation: 0,
        title: const Text(
          "자재 현황 조회",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          // 1. 검색 바
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: "자재명, 규격, 위치 검색...",
                hintStyle: TextStyle(color: Colors.grey.shade600),
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
                fillColor: cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 2. 카테고리 필터
          Container(
            height: 50,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        color: isSelected ? Colors.white : mutedWhite,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: makitaTeal,
                    backgroundColor: cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: BorderSide(
                      color: isSelected ? makitaTeal : Colors.transparent,
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
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
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
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLowStock
                              ? Colors.redAccent.withValues(alpha: 0.5)
                              : Colors.transparent, // ★ 경고 수정
                          width: 1.5,
                        ),
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
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if ((data['location'] ?? "").isNotEmpty)
                                  _buildInfoBadge(
                                    Icons.location_on,
                                    data['location'],
                                    Colors.orangeAccent,
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  "규격: ${data['size'] ?? '-'} | 재질: ${data['material'] ?? '-'}",
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 12,
                                  ),
                                ),
                                if ((data['maker'] ?? "").isNotEmpty)
                                  Text(
                                    "제조사: ${data['maker']}",
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 12,
                                    ),
                                  ),
                                if ((data['heatNo'] ?? "").isNotEmpty)
                                  Text(
                                    "Heat No: ${data['heatNo']}",
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
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
                                      ? Colors.redAccent
                                      : Colors.greenAccent,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                data['unit'] ?? "EA",
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
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
                                    color: Colors.redAccent.withValues(
                                      alpha: 0.2,
                                    ), // ★ 경고 수정
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    "재고 부족",
                                    style: TextStyle(
                                      color: Colors.redAccent,
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
        color: color.withValues(alpha: 0.1), // ★ 경고 수정
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)), // ★ 경고 수정
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
