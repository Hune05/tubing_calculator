import 'package:flutter/material.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: const Color(0xFF007580), // 마키타 테일
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildListTile(
              context,
              icon: Icons.calculate,
              title: '벤딩 계산기 (작업 화면)',
              subtitle: '단일/다중 벤딩 및 마킹 포인트 계산',
              onTap: () => Navigator.pushNamed(context, '/calculator'),
            ),
            const Divider(color: Colors.black12, height: 1),

            _buildListTile(
              context,
              icon: Icons.format_list_numbered,
              title: '마킹 및 컷팅 결과',
              subtitle: '계산된 최종 컷팅 길이와 마킹 지점 바로 확인',
              onTap: () => Navigator.pushNamed(context, '/marking'),
            ),
            const Divider(color: Colors.black12, height: 1),

            // 🔥 문제의 깡통 버튼 삭제 완료!
            // 이제 도면은 '작업 기록 보관함'에 들어가서 파일을 선택해야만 볼 수 있습니다. (정상적인 연동)
            _buildListTile(
              context,
              icon: Icons.history,
              title: '작업 기록 보관함',
              subtitle: '저장해둔 이전 계산 내역 및 도면 확인',
              onTap: () => Navigator.pushNamed(context, '/history'),
            ),
            const Divider(color: Colors.black12, height: 1),

            _buildListTile(
              context,
              icon: Icons.settings,
              title: '장비 및 배관 설정',
              subtitle: '벤더 제원, 삽입 깊이, 여유장 설정',
              onTap: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
      ),
    );
  }

  // 💡 리스트 헬퍼 함수
  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF007580), size: 36),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.black54)),
      onTap: onTap,
    );
  }
}
