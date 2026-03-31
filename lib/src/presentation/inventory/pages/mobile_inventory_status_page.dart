import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'mobile_inventory_logs_page.dart';
import 'mobile_inventory_checkout_page.dart';

// 🎨 토스 스타일 색상 팔레트
const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color slate100 = Color(0xFFF2F4F6);
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
        backgroundColor: pureWhite, // 전체 배경 화이트
        appBar: AppBar(
          backgroundColor: pureWhite,
          scrolledUnderElevation: 0,
          elevation: 0,
          iconTheme: const IconThemeData(color: slate900),
          centerTitle: true,
          title: const Text(
            "자재 현장 지원",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: slate900,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.clipboardList, size: 26),
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
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            labelColor: slate900,
            unselectedLabelColor: slate600,
            indicatorColor: slate900,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            unselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            dividerColor: slate100, // 탭바 하단 옅은 선
            tabs: [
              Tab(text: "자재 찾기"), // 문구 심플하게 변경
              Tab(text: "내 불출 목록"),
            ],
          ),
        ),
        // 키보드 내리기 적용
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: TabBarView(
            physics: const BouncingScrollPhysics(),
            children: [_buildAllInventoryTab(), _buildMyCheckoutsTab()],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 탭 1: 전체 자재 목록
  // ==========================================
  Widget _buildAllInventoryTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        // 🌟 검색창 (선 없이 배경색으로만)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(
              color: slate900,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            onChanged: (val) =>
                setState(() => _searchQuery = val.toLowerCase()),
            decoration: InputDecoration(
              hintText: "자재명, 규격, 위치 검색",
              hintStyle: TextStyle(color: slate600.withValues(alpha: 0.6)),
              prefixIcon: const Icon(
                LucideIcons.search,
                color: slate600,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.cancel, color: slate600, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                      },
                    )
                  : null,
              filled: true,
              fillColor: slate100,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 🌟 카테고리 칩 (가로 스크롤, 그림자 제거)
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat),
                  labelStyle: TextStyle(
                    color: isSelected ? pureWhite : slate600,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 14,
                  ),
                  selected: isSelected,
                  selectedColor: slate900, // 선택 시 진한 검정
                  backgroundColor: slate100, // 미선택 시 연한 회색
                  showCheckmark: false,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  onSelected: (selected) =>
                      setState(() => _selectedCategory = cat),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),
        Divider(height: 1, color: slate100, thickness: 1),

        // 🌟 리스트 뷰
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _inventoryDb.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: slate300),
                );
              }

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

              if (filteredDocs.isEmpty) {
                return const Center(
                  child: Text(
                    "검색 결과가 없어요.",
                    style: TextStyle(
                      color: slate600,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }

              return ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: filteredDocs.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: slate100,
                  indent: 24,
                  endIndent: 24,
                ),
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  int qty = data['qty'] ?? 0;
                  String itemName = data['name'] ?? "이름 없음";
                  String unit = data['unit'] ?? "EA";
                  bool canCheckout = qty > 0;

                  // 🌟 카드 박스 제거, 여백 위주 디자인
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 1. 자재 정보
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                itemName,
                                style: const TextStyle(
                                  color: slate900,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800, // 타이틀 볼드 강조
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: canCheckout
                                          ? makitaTeal.withValues(alpha: 0.1)
                                          : Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "재고 $qty$unit",
                                      style: TextStyle(
                                        color: canCheckout
                                            ? makitaTeal
                                            : Colors.redAccent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "${data['size'] ?? '-'}  |  ${data['location'] ?? '-'}",
                                      style: const TextStyle(
                                        color: slate600,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),

                        // 2. 조용하지만 명확한 액션 버튼
                        ElevatedButton(
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: slate100, // 튀지 않는 배경색
                            foregroundColor: slate900,
                            disabledBackgroundColor: slate100.withValues(
                              alpha: 0.5,
                            ),
                            disabledForegroundColor: slate600.withValues(
                              alpha: 0.5,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            minimumSize: Size.zero,
                          ),
                          child: const Text(
                            "불출",
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
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
  // 탭 2: 내 불출 목록
  // ==========================================
  Widget _buildMyCheckoutsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _checkoutsDb
          .where('workerName', isEqualTo: widget.workerName)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: slate300),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.checkCircle2, size: 64, color: slate100),
                const SizedBox(height: 16),
                const Text(
                  "가져간 자재가 없어요.",
                  style: TextStyle(
                    color: slate600,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(top: 16, bottom: 80),
          itemCount: docs.length,
          separatorBuilder: (context, index) =>
              Divider(height: 1, color: slate100, indent: 24, endIndent: 24),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            String itemId = data['itemId'] ?? '';
            String itemName = data['itemName'] ?? '이름 없음';
            int qty = data['checkoutQty'] ?? 0;
            String unit = data['unit'] ?? 'EA';
            String reason = data['reason'] ?? '사유 없음';

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: slate900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              "불출 $qty$unit",
                              style: const TextStyle(
                                color: makitaTeal,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text(
                                "•",
                                style: TextStyle(color: slate300),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                reason,
                                style: const TextStyle(
                                  color: slate600,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: slate100, // 튀지 않는 배경
                      foregroundColor: slate900,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      minimumSize: Size.zero,
                    ),
                    child: const Text(
                      "반납/소진",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
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
