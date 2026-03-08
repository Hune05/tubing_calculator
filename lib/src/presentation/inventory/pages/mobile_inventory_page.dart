import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ★ 추가됨: 수량과 히트 넘버를 함께 관리하기 위한 데이터 클래스
class ItemData {
  int qty;
  String heatNo;

  ItemData({this.qty = 0, this.heatNo = ""});
}

class MobileInventoryPage extends StatefulWidget {
  const MobileInventoryPage({super.key});

  @override
  State<MobileInventoryPage> createState() => _MobileInventoryPageState();
}

class _MobileInventoryPageState extends State<MobileInventoryPage> {
  final PageController _pageController = PageController();
  int _currentCategory = 0;

  // 🎨 [무광 다크 테마 유지]
  final Color darkBg = const Color(0xFF1E2124);
  final Color cardBg = const Color(0xFF2A2E33);
  final Color mutedWhite = const Color(0xFFD0D4D9);

  // 카테고리 정의
  final List<Map<String, dynamic>> _categories = [
    {"name": "튜브 (Tube)", "color": const Color(0xFF4A5D66)},
    {"name": "피팅류 (Fitting)", "color": const Color(0xFF8A6345)},
    {"name": "밸브류 (Valve)", "color": const Color(0xFF00606B)},
    {"name": "가스켓 / 후렌지", "color": const Color(0xFF635666)},
    {"name": "볼트 / 너트", "color": const Color(0xFF3B5E52)},
  ];

  // ★ 수정됨: int 대신 ItemData 객체로 수량과 히트넘버 동시 관리
  final Map<int, Map<String, ItemData>> _inventoryData = {
    0: {
      "1/4 inch (6.35mm)": ItemData(qty: 0),
      "3/8 inch (9.52mm)": ItemData(qty: 0),
      "1/2 inch (12.7mm)": ItemData(qty: 0),
      "3/4 inch (19.05mm)": ItemData(qty: 0),
    },
    1: {
      "Union (유니온)": ItemData(qty: 0),
      "Elbow (엘보우)": ItemData(qty: 0),
      "Tee (티)": ItemData(qty: 0),
      "Male Connector": ItemData(qty: 0),
    },
    2: {
      "Ball Valve (볼밸브)": ItemData(qty: 0),
      "Needle Valve (니들밸브)": ItemData(qty: 0),
      "Check Valve (체크밸브)": ItemData(qty: 0),
    },
    3: {
      "10K 15A 가스켓": ItemData(qty: 0),
      "10K 20A 가스켓": ItemData(qty: 0),
      "10K 15A 후렌지 (RF)": ItemData(qty: 0),
    },
    4: {
      "M6 x 20 볼트세트": ItemData(qty: 0),
      "M8 x 25 볼트세트": ItemData(qty: 0),
      "M10 x 30 볼트세트": ItemData(qty: 0),
      "M12 너트 단품": ItemData(qty: 0),
    },
  };

  // 수량 증감 로직 (+1, -1)
  void _updateQuantity(int categoryIndex, String item, int delta) {
    HapticFeedback.lightImpact();
    setState(() {
      int current = _inventoryData[categoryIndex]![item]!.qty;
      int next = current + delta;
      if (next >= 0) {
        _inventoryData[categoryIndex]![item]!.qty = next;
      }
    });
  }

  // 수량 직접 입력 다이얼로그
  void _showQuantityInputDialog(
    int categoryIndex,
    String item,
    int currentQty,
  ) {
    TextEditingController qtyController = TextEditingController(
      text: currentQty.toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardBg,
          title: Text(
            "$item 수량 입력",
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            autofocus: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: darkBg,
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: _categories[_currentCategory]['color'],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _categories[_currentCategory]['color'],
              ),
              onPressed: () {
                int? newQty = int.tryParse(qtyController.text);
                if (newQty != null && newQty >= 0) {
                  setState(() {
                    _inventoryData[categoryIndex]![item]!.qty = newQty;
                  });
                }
                Navigator.pop(context);
              },
              child: const Text(
                "확인",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ★ 추가됨: 히트 넘버(Heat No) 입력 다이얼로그
  void _showHeatNoDialog(String item, String currentHeatNo) {
    TextEditingController heatCtrl = TextEditingController(text: currentHeatNo);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardBg,
          title: Text(
            "히트 넘버 (Heat No.) 입력",
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: TextField(
            controller: heatCtrl,
            textCapitalization: TextCapitalization.characters, // 영문 대문자 자동 변환
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            autofocus: true,
            decoration: InputDecoration(
              hintText: "예: HT-12345",
              hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              filled: true,
              fillColor: darkBg,
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: _categories[_currentCategory]['color'],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _categories[_currentCategory]['color'],
              ),
              onPressed: () {
                setState(() {
                  _inventoryData[0]![item]!.heatNo = heatCtrl.text
                      .trim()
                      .toUpperCase(); // 저장 시 무조건 대문자
                });
                Navigator.pop(context);
              },
              child: const Text(
                "저장",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 신규 자재 추가 다이얼로그
  void _showAddNewItemDialog() {
    TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardBg,
          title: const Text(
            "신규 자재 등록",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            autofocus: true,
            decoration: InputDecoration(
              hintText: "자재명 및 규격 입력",
              hintStyle: TextStyle(color: Colors.grey.shade600),
              filled: true,
              fillColor: darkBg,
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: _categories[_currentCategory]['color'],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _categories[_currentCategory]['color'],
              ),
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  setState(() {
                    _inventoryData[_currentCategory]![nameController.text
                        .trim()] = ItemData(
                      qty: 0,
                    );
                  });
                }
                Navigator.pop(context);
              },
              child: const Text(
                "추가",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 데이터 전송
  void _syncToServer() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "서버 동기화 완료: ${_categories[_currentCategory]['name']}",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _categories[_currentCategory]['color'],
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var catColor = _categories[_currentCategory]['color'];

    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: Column(
          children: [
            // [1단: 상단 카테고리 스와이프]
            Container(
              height: 90,
              width: double.infinity,
              color: catColor,
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
                    _categories[_currentCategory]['name'],
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

            // [2단: 자재 리스트]
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) =>
                    setState(() => _currentCategory = index),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  return _buildInventoryList(index);
                },
              ),
            ),

            // [3단: 하단 고정 액션 버튼]
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
                    Icon(Icons.cloud_upload, color: Colors.white, size: 26),
                    SizedBox(width: 12),
                    Text(
                      "재고 데이터 전송",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
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
      // 신규 자재 추가 플로팅 버튼
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90.0),
        child: FloatingActionButton.extended(
          onPressed: _showAddNewItemDialog,
          backgroundColor: catColor,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            "자재 추가",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // 자재 리스트 렌더링
  Widget _buildInventoryList(int categoryIndex) {
    var items = _inventoryData[categoryIndex]!.keys.toList();

    if (items.isEmpty) {
      return Center(
        child: Text(
          "등록된 자재가 없습니다.\n우측 하단 버튼을 눌러 추가해주세요.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 16,
            height: 1.5,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      itemCount: items.length,
      itemBuilder: (context, i) {
        String itemName = items[i];
        ItemData data = _inventoryData[categoryIndex]![itemName]!;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 메인 행 (이름 + 수량 조절)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      itemName,
                      style: TextStyle(
                        color: mutedWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      _buildRoundButton(
                        Icons.remove,
                        () => _updateQuantity(categoryIndex, itemName, -1),
                      ),
                      GestureDetector(
                        onTap: () => _showQuantityInputDialog(
                          categoryIndex,
                          itemName,
                          data.qty,
                        ),
                        child: Container(
                          width: 60,
                          alignment: Alignment.center,
                          color: Colors.transparent,
                          child: Text(
                            data.qty.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      _buildRoundButton(
                        Icons.add,
                        () => _updateQuantity(categoryIndex, itemName, 1),
                        isAdd: true,
                      ),
                    ],
                  ),
                ],
              ),

              // ★ 추가됨: 튜브(카테고리 0)일 경우에만 히트 넘버 입력 UI 표시
              if (categoryIndex == 0) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _showHeatNoDialog(itemName, data.heatNo),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: darkBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: data.heatNo.isEmpty
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.greenAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tag,
                          color: data.heatNo.isEmpty
                              ? Colors.grey
                              : Colors.greenAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data.heatNo.isEmpty
                                ? "제조사 히트 넘버(Heat No) 입력"
                                : "Heat No: ${data.heatNo}",
                            style: TextStyle(
                              color: data.heatNo.isEmpty
                                  ? Colors.grey.shade500
                                  : Colors.greenAccent,
                              fontSize: 14,
                              fontWeight: data.heatNo.isEmpty
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // 둥근 버튼 (+, -)
  Widget _buildRoundButton(
    IconData icon,
    VoidCallback onPressed, {
    bool isAdd = false,
  }) {
    var themeColor = _categories[_currentCategory]['color'];
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isAdd ? themeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isAdd ? themeColor : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(icon, color: isAdd ? Colors.white : mutedWhite, size: 24),
      ),
    );
  }
}
