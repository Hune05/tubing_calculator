import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tubing_calculator/src/core/utils/settings_manager.dart';
import 'package:tubing_calculator/src/data/models/cutting_project_model.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/cutting_main_screen.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/electric_calculator_page.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = screenWidth > 600 ? 4 : 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Tubing Calculator',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        backgroundColor: const Color(0xFF007580),
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
          childAspectRatio: 1.1,
          children: [
            _buildGridCard(
              context,
              icon: Icons.content_cut,
              title: '스마트 컷팅',
              subtitle: '피팅 공제 및 절단장 계산',
              iconColor: const Color(0xFF007580),
              onTap: () => Navigator.pushNamed(context, '/cutting'),
            ),

            // 🚀 [수정] 명칭을 "전동 벤딩 계산기"로 변경!
            _buildGridCard(
              context,
              icon: Icons.precision_manufacturing,
              title: '전동 벤딩 계산기',
              subtitle: 'NC/CNC YBC 제원 산출',
              iconColor: Colors.orange.shade800,
              onTap: () async {
                final settings = await SettingsManager.loadSettings();
                final double clr = settings['bendRadius'] ?? 0.0;
                final double minClamp = settings['minStraight'] ?? 0.0;

                if (!context.mounted) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ElectricCalculatorPage(
                      startDir: 'RIGHT',
                      clr: clr,
                      minClampLength: minClamp,
                      onSaveCallback: null,
                    ),
                  ),
                );
              },
            ),

            _buildGridCard(
              context,
              icon: Icons.calculate_outlined,
              title: '벤딩 계산기',
              subtitle: '단일/다중 벤딩 작업',
              iconColor: const Color(0xFF007580),
              onTap: () => Navigator.pushNamed(context, '/calculator'),
            ),

            _buildGridCard(
              context,
              icon: Icons.straighten,
              title: '마킹 및 컷팅',
              subtitle: '최종 컷팅 길이 확인',
              iconColor: const Color(0xFF007580),
              onTap: () => Navigator.pushNamed(context, '/marking'),
            ),

            _buildGridCard(
              context,
              icon: Icons.folder_special_outlined,
              title: '기록 보관함',
              subtitle: '이전 도면 및 내역',
              iconColor: const Color(0xFF007580),
              onTap: () => Navigator.pushNamed(context, '/history'),
            ),

            _buildGridCard(
              context,
              icon: Icons.assignment_outlined,
              title: '프로젝트 관리',
              subtitle: 'BOM 및 소모량 집계',
              iconColor: const Color(0xFF007580),
              onTap: () => Navigator.pushNamed(context, '/projects'),
            ),

            _buildGridCard(
              context,
              icon: Icons.inventory_2_outlined,
              title: '자재 관리',
              subtitle: '튜브 및 피팅 재고',
              iconColor: const Color(0xFF007580),
              onTap: () => Navigator.pushNamed(context, '/inventory'),
            ),

            _buildGridCard(
              context,
              icon: Icons.settings_suggest_outlined,
              title: '장비 및 설정',
              subtitle: '벤더 제원 및 배관 설정',
              iconColor: const Color(0xFF007580),
              onTap: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
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
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
