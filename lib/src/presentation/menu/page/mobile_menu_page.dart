import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 🚀 확실한 절대 경로로 리모컨과 자재관리 페이지 불러오기
import 'package:tubing_calculator/src/presentation/calculator/screens/mobile_remote_page.dart';
import 'package:tubing_calculator/src/presentation/inventory/pages/mobile_inventory_page.dart';

class MobileMenuPage extends StatelessWidget {
  const MobileMenuPage({super.key});

  final Color darkBg = const Color(0xFF1E2124);
  final Color cardBg = const Color(0xFF2A2E33);
  final Color makitaColor = const Color(0xFF00606B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        elevation: 0,
        title: const Text(
          "작업 모드 선택",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMenuButton(
              context: context,
              title: "벤딩 리모컨",
              subtitle: "현장 수치 입력 및 전송",
              icon: Icons.precision_manufacturing,
              color: makitaColor,
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
            const SizedBox(height: 30),
            _buildMenuButton(
              context: context,
              title: "자재 관리 (재고 조사)",
              subtitle: "튜브 및 피팅 수량 파악",
              icon: Icons.inventory_2,
              color: const Color(0xFF8A6345),
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
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
