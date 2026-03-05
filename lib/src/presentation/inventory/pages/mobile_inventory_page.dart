import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  // 카테고리 정의 (반장님 지정 5대장)
  final List<Map<String, dynamic>> _categories = [
    {"name": "튜브 (Tube)", "color": const Color(0xFF4A5D66)},
    {"name": "피팅류 (Fitting)", "color": const Color(0xFF8A6345)},
    {"name": "밸브류 (Valve)", "color": const Color(0xFF00606B)},
    {"name": "가스켓 / 후렌지", "color": const Color(0xFF635666)},
    {"name": "볼트 / 너트", "color": const Color(0xFF3B5E52)},
  ];

  // 임시 자재 데이터 및 수량 상태 관리
  final Map<int, Map<String, int>> _inventoryData = {
    0: {
      "1/4 inch (6.35mm)": 0,
      "3/8 inch (9.52mm)": 0,
      "1/2 inch (12.7mm)": 0,
      "3/4 inch (19.05mm)": 0,
    },
    1: {"Union (유니온)": 0, "Elbow (엘보우)": 0, "Tee (티)": 0, "Male Connector": 0},
    2: {
      "Ball Valve (볼밸브)": 0,
      "Needle Valve (니들밸브)": 0,
      "Check Valve (체크밸브)": 0,
    },
    3: {"10K 15A 가스켓": 0, "10K 20A 가스켓": 0, "10K 15A 후렌지 (RF)": 0},
    4: {
      "M6 x 20 볼트세트": 0,
      "M8 x 25 볼트세트": 0,
      "M10 x 30 볼트세트": 0,
      "M12 너트 단품": 0,
    },
  };

  void _updateQuantity(int categoryIndex, String item, int delta) {
    HapticFeedback.lightImpact();
    setState(() {
      int current = _inventoryData[categoryIndex]![item] ?? 0;
      int next = current + delta;
      if (next >= 0) {
        // 마이너스 재고 방지
        _inventoryData[categoryIndex]![item] = next;
      }
    });
  }

  void _syncToServer() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "✅ ${_categories[_currentCategory]['name']} 재고가 서버에 반영되었습니다.",
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
                    "◀ 자재 카테고리 스와이프 ▶",
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

            // [2단: 자재 리스트 및 수량 조절]
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

            // [3단: 하단 고정 업데이트 버튼]
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
                    Icon(Icons.sync, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      "재고 서버에 반영",
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
    );
  }

  // 자재 리스트 렌더링
  Widget _buildInventoryList(int categoryIndex) {
    var items = _inventoryData[categoryIndex]!.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      itemCount: items.length,
      itemBuilder: (context, i) {
        String itemName = items[i];
        int qty = _inventoryData[categoryIndex]![itemName]!;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 자재 이름
              Expanded(
                child: Text(
                  itemName,
                  style: TextStyle(
                    color: mutedWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // 수량 조절 컨트롤러 (+, -, 직접입력)
              Row(
                children: [
                  _buildRoundButton(
                    Icons.remove,
                    () => _updateQuantity(categoryIndex, itemName, -1),
                  ),

                  // 숫자 표시 (터치하면 순정 키보드 띄우도록 확장 가능)
                  Container(
                    width: 60,
                    alignment: Alignment.center,
                    child: Text(
                      qty.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
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
