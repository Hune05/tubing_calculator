import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

// ---------------------------------------------------------
// 💡 [1] 일관된 테마 컬러 적용 (전역 변수)
// ---------------------------------------------------------
const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate200 = Color(0xFFE2E8F0);
const Color slate100 = Color(0xFFF1F5F9);
const Color slate50 = Color(0xFFF8FAFC);
const Color pureWhite = Color(0xFFFFFFFF);

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  // ---------------------------------------------------------
  // 💡 [2] 화면 상태 관리를 위한 변수들
  // ---------------------------------------------------------
  bool _showDeadStock = false; // 악성(장기) 재고만 볼 것인지 여부

  // 검색 기능 관련 변수
  bool _isSearching = false; // 현재 검색 모드인지 아닌지
  String _searchQuery = ""; // 사용자가 입력한 검색어
  final TextEditingController _searchController =
      TextEditingController(); // 검색창 텍스트 컨트롤러

  // 카테고리 필터 관련 변수
  String _selectedFilterCategory = "ALL"; // 현재 선택된 카테고리 (초기값: ALL)
  final List<String> _categories = [
    "ALL",
    "TUBE",
    "FITTING",
    "VALVE",
    "FLANGE",
    "GASKET",
    "기타",
  ];

  // 🔥 [핵심] 파이어베이스 서버의 'inventory' 창고(컬렉션)로 가는 직통 연결 고리입니다.
  // 이제부터 모든 데이터는 폰이 아니라 이 '_inventoryDb'를 통해 구글 서버로 직접 들어갑니다.
  final CollectionReference _inventoryDb = FirebaseFirestore.instance
      .collection('inventory');

  // ---------------------------------------------------------
  // 💾 [3] 파이어베이스 서버의 데이터를 수정하는 함수들
  // ---------------------------------------------------------

  // 3-1. 수량 업데이트 함수 (서버의 숫자 직접 변경)
  void _updateQuantity(String docId, int currentQty, int amount) {
    if (currentQty + amount >= 0) {
      // 폰에서 +나 -를 누르면, 해당 자재의 고유번호(docId)를 찾아가서 수량을 덮어씌웁니다.
      _inventoryDb.doc(docId).update({'qty': currentQty + amount});
    }
  }

  // 3-2. 재고 상태 토글 함수 (정상 재고 <-> 장기/악성 재고)
  void _toggleDeadStockStatus(String docId, bool currentStatus) {
    // 현재 상태의 반대값(!currentStatus)으로 서버에 업데이트 명령을 내립니다.
    _inventoryDb.doc(docId).update({'is_dead_stock': !currentStatus});
  }

  // ---------------------------------------------------------
  // 📝 [4] 신규 자재 추가 팝업 (바텀 시트) 띄우기 함수
  // ---------------------------------------------------------
  void _showAddMaterialSheet() {
    // 팝업 안에서 사용자가 글씨를 입력할 빈 칸(컨트롤러)들을 준비합니다.
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController sizeCtrl = TextEditingController();
    final TextEditingController qtyCtrl = TextEditingController(text: "0");
    final TextEditingController minQtyCtrl = TextEditingController(text: "10");

    String selectedCategory = "FITTING"; // 초기 카테고리 세팅
    String selectedUnit = "EA"; // 초기 단위 세팅

    // "ALL"이라는 카테고리는 조회용이므로, 자재 추가할 때는 뺍니다.
    final List<String> addCategories = _categories
        .where((c) => c != "ALL")
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 키보드가 올라올 때 팝업이 위로 밀려 올라가도록 설정
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(
                  context,
                ).viewInsets.bottom, // 키보드 높이만큼 패딩 주기
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: pureWhite,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "신규 자재 등록",
                        style: TextStyle(
                          color: slate900,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // --- [카테고리 & 단위 선택 영역] ---
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "카테고리",
                                  style: TextStyle(
                                    color: slate900,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: slate50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedCategory,
                                      isExpanded: true,
                                      dropdownColor:
                                          pureWhite, // 드롭다운 배경이 까맣게 되는 현상 방지
                                      style: const TextStyle(
                                        color: slate900,
                                        fontSize: 14,
                                      ),
                                      items: addCategories.map((String value) {
                                        return DropdownMenuItem(
                                          value: value,
                                          child: Text(value),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setSheetState(() {
                                          selectedCategory = val!;
                                          // TUBE를 고르면 단위를 자동으로 '본'으로 바꿔주는 센스!
                                          selectedUnit = val == "TUBE"
                                              ? "본"
                                              : "EA";
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "단위",
                                  style: TextStyle(
                                    color: slate900,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: slate50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedUnit,
                                      isExpanded: true,
                                      dropdownColor: pureWhite,
                                      style: const TextStyle(
                                        color: slate900,
                                        fontSize: 14,
                                      ),
                                      items: ["EA", "본", "BOX", "M", "SET"].map(
                                        (String value) {
                                          return DropdownMenuItem(
                                            value: value,
                                            child: Text(value),
                                          );
                                        },
                                      ).toList(),
                                      onChanged: (val) {
                                        setSheetState(
                                          () => selectedUnit = val!,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // --- [자재명 입력 영역] ---
                      const Text(
                        "자재명",
                        style: TextStyle(
                          color: slate900,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          hintText: "예: Union Tee 등",
                          filled: true,
                          fillColor: slate50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- [규격 입력 영역] ---
                      const Text(
                        "규격 (Size)",
                        style: TextStyle(
                          color: slate900,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: sizeCtrl,
                        decoration: InputDecoration(
                          hintText: "예: 1/2\", 50A 등",
                          filled: true,
                          fillColor: slate50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- [수량 및 안전 재고 입력 영역] ---
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "초기 수량",
                                  style: TextStyle(
                                    color: slate900,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: qtyCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: slate50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "안전 재고 (경고)",
                                  style: TextStyle(
                                    color: slate900,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: minQtyCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: slate50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // --- [취소 및 등록 버튼 영역] ---
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                "취소",
                                style: TextStyle(
                                  color: slate600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: makitaTeal,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              // 🔥🔥🔥 [집중!] 서버 전송 및 에러 낚아채기 구역입니다! 🔥🔥🔥
                              onPressed: () async {
                                // 서버 통신을 위해 async를 달아줍니다.
                                // 1. 필수 입력값(이름, 규격)을 안 적었으면 경고 띄우고 중단
                                if (nameCtrl.text.trim().isEmpty ||
                                    sizeCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("자재명과 규격을 모두 입력해주세요!"),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                  return;
                                }

                                // 2. 에러 잡는 그물망(try-catch) 시작
                                debugPrint(
                                  "🚀 [테스트] 등록 버튼 눌림! 서버로 데이터 전송 시도 중...",
                                );

                                try {
                                  // 구글 서버(파이어베이스)에 데이터를 쏘아보냅니다.
                                  await _inventoryDb.add({
                                    "name": nameCtrl.text.trim(),
                                    "size": sizeCtrl.text.trim(),
                                    "category": selectedCategory,
                                    "qty": int.tryParse(qtyCtrl.text) ?? 0,
                                    "min_qty":
                                        int.tryParse(minQtyCtrl.text) ?? 0,
                                    "is_dead_stock": false,
                                    "unit": selectedUnit,
                                    "createdAt":
                                        FieldValue.serverTimestamp(), // 서버에 생성된 시간 기준으로 정렬하기 위함
                                  });

                                  debugPrint("✅ [테스트] 서버 전송 완벽하게 성공!!");

                                  // 3. 통신이 끝날 때까지 기다렸다가, 창이 아직 열려있으면 팝업을 닫습니다. (노란색 경고 해결 코드)
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                } catch (e) {
                                  // 서버 문이 잠겨있거나 통신 에러가 나면 이 구역으로 떨어집니다.
                                  debugPrint("❌ [테스트] 에러 발생!!! 범인은 바로: $e");
                                  // 사용자에게도 에러가 났다고 알려줍니다.
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("서버 전송 실패: $e"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: const Text(
                                "등록하기",
                                style: TextStyle(
                                  color: pureWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------
  // 📱 [5] 화면 뼈대 (UI) 그리기
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slate50,

      // 상단 앱바 (검색창 포함)
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: pureWhite),
                decoration: const InputDecoration(
                  hintText: '자재명, 규격 검색...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              )
            : const Text(
                'INVENTORY',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.5,
                ),
              ),
        backgroundColor: makitaTeal,
        foregroundColor: pureWhite,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : LucideIcons.search,
              size: 24,
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = "";
                }
              });
            },
          ),
        ],
      ),

      body: Column(
        children: [
          // 카테고리 및 활성/장기 재고 필터 영역
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: pureWhite,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: slate50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedFilterCategory,
                        isExpanded: true,
                        dropdownColor: pureWhite, // 드롭다운 배경 까매짐 방지
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: slate600,
                          size: 20,
                        ),
                        style: const TextStyle(
                          color: slate900,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        items: _categories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedFilterCategory = val!;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        "활성",
                        !_showDeadStock,
                        () => setState(() => _showDeadStock = false),
                      ),
                      const SizedBox(width: 4),
                      _buildFilterChip(
                        "장기",
                        _showDeadStock,
                        () => setState(() => _showDeadStock = true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 🔥 [제일 중요] 서버 데이터를 실시간으로 보여주는 StreamBuilder 구역
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // 서버의 'inventory' 폴더를 최신 생성순으로 감시합니다.
              stream: _inventoryDb
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                // 1. 에러가 나면 띄워줄 화면
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      "서버 데이터를 불러오는데 실패했습니다.",
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }

                // 2. 서버 연결 기다리는 중 (로딩 화면)
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: makitaTeal),
                  );
                }

                // 3. 서버에서 가져온 전체 문서 리스트
                final docs = snapshot.data!.docs;

                // 4. 내가 선택한 필터와 검색어에 맞게 데이터 걸러내기
                final filteredDocs = docs.where((doc) {
                  // 데이터를 맵(Map) 형태로 꺼냄
                  final data = doc.data() as Map<String, dynamic>;

                  // 카테고리 일치 여부 확인
                  bool categoryMatch =
                      _selectedFilterCategory == "ALL" ||
                      data['category'] == _selectedFilterCategory;
                  // 장기/활성 재고 상태 일치 여부 확인
                  bool statusMatch = data['is_dead_stock'] == _showDeadStock;

                  // 검색어 일치 여부 확인 (이름 또는 규격)
                  bool searchMatch = true; // 기본값 참
                  if (_searchQuery.isNotEmpty) {
                    final nameMatch =
                        data['name']?.toString().toLowerCase().contains(
                          _searchQuery,
                        ) ??
                        false;
                    final sizeMatch =
                        data['size']?.toString().toLowerCase().contains(
                          _searchQuery,
                        ) ??
                        false;
                    searchMatch = nameMatch || sizeMatch;
                  }

                  return categoryMatch && statusMatch && searchMatch;
                }).toList();

                // 5. 필터링 했는데 아무 데이터도 없으면 띄워줄 화면
                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.packageOpen,
                          size: 60,
                          color: slate200,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? "검색 결과가 없습니다."
                              : (_showDeadStock
                                    ? "등록된 악성 재고가 없습니다."
                                    : "해당 분류에 등록된 자재가 없습니다."),
                          style: const TextStyle(
                            color: slate600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // 6. 무사히 데이터가 있으면 카드 리스트로 예쁘게 그려주기
                return ListView.separated(
                  padding: const EdgeInsets.only(
                    top: 16,
                    left: 16,
                    right: 16,
                    bottom: 80,
                  ),
                  itemCount: filteredDocs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    // 폰에서 수정을 명령하기 위해 고유 문서 번호(doc.id)도 같이 넘겨줍니다.
                    return _buildMaterialCard(doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),

      // 화면 우측 하단의 떠있는 [+] 버튼
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMaterialSheet,
        backgroundColor: makitaTeal,
        icon: const Icon(Icons.add, color: pureWhite),
        label: const Text(
          "자재 등록",
          style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // 필터 버튼 (활성/장기) 만드는 함수
  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? makitaTeal : slate100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? makitaTeal : Colors.grey.shade300,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? pureWhite : slate600,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // 자재 1개 정보(카드)를 화면에 그리는 함수
  Widget _buildMaterialCard(String docId, Map<String, dynamic> item) {
    // 수량이 안전재고(min_qty) 밑으로 떨어졌는지 계산
    bool isLowStock = false;
    if (item['qty'] != null && item['min_qty'] != null) {
      isLowStock =
          (item['qty'] < item['min_qty']) && (item['is_dead_stock'] == false);
    }

    // 혹시 모를 null 에러 방지를 위한 기본값 세팅
    final bool isDeadStock = item['is_dead_stock'] ?? false;
    final String category = item['category'] ?? "기타";
    final String name = item['name'] ?? "이름 없음";
    final String size = item['size'] ?? "-";
    final int minQty = item['min_qty'] ?? 0;
    final int qty = item['qty'] ?? 0;
    final String unit = item['unit'] ?? "EA";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDeadStock ? slate50 : pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLowStock ? Colors.red.shade300 : Colors.grey.shade300,
          width: isLowStock ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            // 🔥 노란색 경고 해결: withOpacity 대신 withValues 사용
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 아이콘 표시 구역
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDeadStock ? slate200 : slate100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getCategoryIcon(category),
                  color: isDeadStock ? slate600 : makitaTeal,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),

              // 자재 정보 글씨 구역
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 카테고리 태그 및 발주요망 태그
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: slate200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(
                              color: slate600,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isLowStock) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "발주 요망",
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (isDeadStock) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "장기 재고",
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      style: TextStyle(
                        color: isDeadStock ? slate600 : slate900,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        decoration: isDeadStock
                            ? TextDecoration.lineThrough
                            : null, // 장기재고면 취소선 긋기
                      ),
                    ),
                    const SizedBox(height: 2),
                    // 🔥 노란색 경고 해결: 문자열 결합은 '+' 기호 대신 $기호 사용
                    Text(
                      "규격: $size  |  안전재고: $minQty",
                      style: const TextStyle(color: slate600, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // 우측 수량 조절 버튼 구역
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$qty $unit",
                    style: TextStyle(
                      color: isDeadStock
                          ? slate600
                          : (isLowStock ? Colors.red.shade700 : makitaTeal),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // 마이너스 버튼 누르면 서버의 수량을 -1 깎음
                      _buildQtyBtn(
                        Icons.remove,
                        () => _updateQuantity(docId, qty, -1),
                      ),
                      const SizedBox(width: 8),
                      // 플러스 버튼 누르면 서버의 수량을 +1 올림
                      _buildQtyBtn(
                        Icons.add,
                        () => _updateQuantity(docId, qty, 1),
                        isAdd: true,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          // 하단 악성재고 편입/복구 버튼 구역
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _toggleDeadStockStatus(docId, isDeadStock),
                icon: Icon(
                  isDeadStock ? Icons.restore : Icons.archive_outlined,
                  size: 16,
                  color: slate600,
                ),
                label: Text(
                  isDeadStock ? "정상 재고로 복구" : "악성 재고로 격리",
                  style: const TextStyle(color: slate600, fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                  minimumSize: const Size(0, 30),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // + / - 작고 네모난 버튼 만드는 함수
  Widget _buildQtyBtn(IconData icon, VoidCallback onTap, {bool isAdd = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          // 🔥 노란색 경고 해결: withOpacity 대신 withValues 사용
          color: isAdd ? makitaTeal.withValues(alpha: 0.1) : slate100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isAdd ? makitaTeal.withValues(alpha: 0.3) : slate200,
          ),
        ),
        child: Icon(icon, size: 18, color: isAdd ? makitaTeal : slate600),
      ),
    );
  }

  // 카테고리 글씨를 받아서 예쁜 아이콘으로 매칭해주는 함수
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case "TUBE":
        return Icons.line_weight;
      case "FITTING":
        return Icons.device_hub;
      case "VALVE":
        return Icons.settings_input_component;
      case "FLANGE":
        return Icons.album;
      case "GASKET":
        return Icons.radio_button_unchecked;
      default:
        return LucideIcons.box;
    }
  }
}
