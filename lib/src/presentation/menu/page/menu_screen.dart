import 'package:flutter/material.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 기기 가로 길이에 따라 3칸 or 2칸 배치
    var screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = screenWidth > 600 ? 3 : 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // 밝고 깔끔한 배경
      appBar: AppBar(
        title: const Text(
          'Tubing Calculator',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        backgroundColor: const Color(0xFF007580), // 마키타 틸
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: GridView.count(
          padding: const EdgeInsets.all(24),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
          childAspectRatio: 1.2,
          children: [
            // 🚀 [신규 추가] 스마트 컷팅 작업실
            _buildGridCard(
              context,
              icon: Icons.content_cut,
              title: '스마트 컷팅',
              subtitle: '피팅 공제 및 절단장 계산',
              onTap: () => Navigator.pushNamed(context, '/cutting'),
            ),
            _buildGridCard(
              context,
              icon: Icons.calculate_outlined,
              title: '벤딩 계산기',
              subtitle: '단일/다중 벤딩 작업',
              onTap: () => Navigator.pushNamed(context, '/calculator'),
            ),
            _buildGridCard(
              context,
              icon: Icons.straighten,
              title: '마킹 및 컷팅',
              subtitle: '최종 컷팅 길이 확인',
              onTap: () => Navigator.pushNamed(context, '/marking'),
            ),
            _buildGridCard(
              context,
              icon: Icons.folder_special_outlined,
              title: '기록 보관함',
              subtitle: '이전 도면 및 내역',
              onTap: () => Navigator.pushNamed(context, '/history'),
            ),
            _buildGridCard(
              context,
              icon: Icons.assignment_outlined,
              title: '프로젝트 관리',
              subtitle: 'BOM 및 소모량 집계',
              onTap: () => Navigator.pushNamed(context, '/projects'),
            ),
            _buildGridCard(
              context,
              icon: Icons.inventory_2_outlined,
              title: '자재 관리',
              subtitle: '튜브 및 피팅 재고',
              onTap: () => Navigator.pushNamed(context, '/inventory'),
            ),
            _buildGridCard(
              context,
              icon: Icons.settings_suggest_outlined,
              title: '장비 및 설정',
              subtitle: '벤더 제원 및 배관 설정',
              onTap: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
      ),
    );
  }

  // 💡 리스트 헬퍼 함수 (그리드 카드 형태)
  Widget _buildGridCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF007580).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF007580), size: 56),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
