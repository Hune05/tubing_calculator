import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 🚀 기존 모바일 페이지들 임포트
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_remote_page.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/mobile_inventory_page.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/mobile_inventory_status_page.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/calculator_page.dart';

// 🎨 테마 컬러 정의 (화이트 & 마키타 틸)
const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A); // 진한 텍스트
const Color slate600 = Color(0xFF475569); // 서브 텍스트
const Color slate100 = Color(0xFFF1F5F9); // 앱 배경 (아주 연한 회색)
const Color pureWhite = Color(0xFFFFFFFF); // 카드 배경

class MobileMenuPage extends StatelessWidget {
  const MobileMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slate100, // 💡 배경을 밝고 화사하게
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🌟 1. 마키타 컬러 베이스의 커스텀 헤더
              _buildHeader(),

              const SizedBox(height: 32),

              // 2. 섹션 타이틀
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  "작업 모드 선택",
                  style: TextStyle(
                    color: slate600,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 3. 화이트 카드 디자인의 메뉴 버튼들
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    _buildMenuButton(
                      context: context,
                      title: "메인 계산기 모드",
                      subtitle: "태블릿 권장 · 도면 생성 및 3D 뷰어",
                      icon: Icons.monitor,
                      color: makitaTeal,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CalculatorWrapper(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildMenuButton(
                      context: context,
                      title: "벤딩 리모컨",
                      subtitle: "스마트폰 권장 · 수치 입력 및 전송",
                      icon: Icons.precision_manufacturing,
                      color: const Color(0xFF00606B), // 살짝 진한 틸
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MobileRemotePage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildMenuButton(
                      context: context,
                      title: "자재 관리 (입/출고)",
                      subtitle: "신규 자재 등록 및 수량 변경",
                      icon: Icons.inventory_2,
                      color: const Color(0xFFD97706), // 따뜻한 오렌지 (포인트)
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MobileInventoryPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildMenuButton(
                      context: context,
                      title: "자재 현황 (실시간)",
                      subtitle: "파이어베이스 재고 및 위치 조회",
                      icon: Icons.fact_check_outlined,
                      color: const Color(0xFF2563EB), // 신뢰감 있는 블루
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const MobileInventoryStatusPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🌟 상단 마키타 테마 헤더
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 40, bottom: 40),
      decoration: BoxDecoration(
        color: makitaTeal,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: makitaTeal.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pureWhite.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.rocket_launch, size: 36, color: pureWhite),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "TUBING SYSTEM",
                  style: TextStyle(
                    color: pureWhite,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "DB 서버 연결됨 (Online)",
                      style: TextStyle(
                        color: pureWhite.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 화이트 테마 카드 메뉴 버튼
  Widget _buildMenuButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 32, color: color),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: slate900, // 진한 텍스트
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: slate600, // 서브 텍스트
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey.shade400,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CalculatorWrapper extends StatefulWidget {
  const CalculatorWrapper({super.key});

  @override
  State<CalculatorWrapper> createState() => _CalculatorWrapperState();
}

class _CalculatorWrapperState extends State<CalculatorWrapper> {
  List<Map<String, double>> _bendList = [];
  String _startDir = "RIGHT";

  void _addBend(double length, double angle, double rotation) {
    setState(() {
      _bendList.add({'length': length, 'angle': angle, 'rotation': rotation});
    });
  }

  void _updateBend(int index, double length, double angle, double rotation) {
    setState(() {
      _bendList[index] = {
        'length': length,
        'angle': angle,
        'rotation': rotation,
      };
    });
  }

  void _deleteBend(int index) {
    setState(() => _bendList.removeAt(index));
  }

  void _reorderBend(int oldIndex, int newIndex) {
    setState(() {
      final item = _bendList.removeAt(oldIndex);
      _bendList.insert(newIndex, item);
    });
  }

  void _clearBends() {
    setState(() => _bendList.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: makitaTeal, // 💡 래퍼 앱바도 마키타 컬러로
        title: const Text(
          "메인 계산기",
          style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: pureWhite),
        elevation: 0,
      ),
      body: CalculatorPage(
        bendList: _bendList,
        startDir: _startDir,
        onStartDirChanged: (dir) => setState(() => _startDir = dir),
        onAddBend: _addBend,
        onUpdateBend: _updateBend,
        onDeleteBend: _deleteBend,
        onReorderBend: _reorderBend,
        onClear: _clearBends,
      ),
    );
  }
}
