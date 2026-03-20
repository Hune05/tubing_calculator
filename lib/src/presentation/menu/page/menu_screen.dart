import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // 전동 데이터 디코딩용

import 'package:tubing_calculator/src/core/utils/settings_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/electric_bending_workspace.dart';
// 🚀 마킹 페이지 직접 호출을 위해 임포트가 필요합니다. 경로가 다르다면 수정해 주세요!
import 'package:tubing_calculator/src/presentation/calculator/screens/electric_marking_page.dart';
// import 'package:tubing_calculator/src/presentation/calculator/screens/marking_page.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  // 🚀 [핵심 1] 모드 인터록 검사 함수 (문지기 역할)
  Future<bool> _checkMode(
    BuildContext context,
    String requiredMode,
    String errorMsg,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final currentMode = prefs.getString('benderType') ?? "수동 (Hand)";

    if (currentMode != requiredMode) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMsg,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false; // 진입 차단
    }
    return true; // 진입 허용
  }

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

            // 🚀 [수정] 전동 벤딩 계산기 (수동 모드일 때 차단)
            _buildGridCard(
              context,
              icon: Icons.precision_manufacturing,
              title: '전동 벤딩 계산기',
              subtitle: 'NC/CNC YBC 제원 산출',
              iconColor: Colors.orange.shade800,
              onTap: () async {
                // 1. 인터록 검사
                bool isOk = await _checkMode(
                  context,
                  "전동 (Electric)",
                  "현재 수동 모드입니다. 설정에서 전동 모드로 변경해 주세요.",
                );
                if (!isOk) return;

                // 2. 정상 진입
                final settings = await SettingsManager.loadSettings();
                final double clr = settings['bendRadius'] ?? 0.0;
                final double minClamp = settings['minStraight'] ?? 0.0;

                if (!context.mounted) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ElectricBendingWorkspace(
                      startDir: 'RIGHT',
                      clr: clr,
                      minClampLength: minClamp,
                      onSaveCallback: null,
                    ),
                  ),
                );
              },
            ),

            // 🚀 [수정] 수동 벤딩 계산기 (전동 모드일 때 차단)
            _buildGridCard(
              context,
              icon: Icons.calculate_outlined,
              title: '수동 벤딩 계산기',
              subtitle: '단일/다중 벤딩 작업',
              iconColor: const Color(0xFF007580),
              onTap: () async {
                // 1. 인터록 검사
                bool isOk = await _checkMode(
                  context,
                  "수동 (Hand)",
                  "현재 전동 모드입니다. 설정에서 수동 모드로 변경해 주세요.",
                );
                if (!isOk) return;

                // 2. 정상 진입
                if (!context.mounted) return;
                Navigator.pushNamed(context, '/calculator');
              },
            ),

            // 🚀 [핵심 2] 마킹 및 컷팅 (설정값에 따라 자동 분기)
            _buildGridCard(
              context,
              icon: Icons.straighten,
              title: '마킹 및 컷팅',
              subtitle: '최종 컷팅 길이 확인',
              iconColor: const Color(0xFF007580),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                final currentMode =
                    prefs.getString('benderType') ?? "수동 (Hand)";

                if (!context.mounted) return;

                if (currentMode == "전동 (Electric)") {
                  // 전동 데이터 불러오기 (ElectricBendingWorkspace에서 저장한 데이터)
                  List<Map<String, double>> electricList = [];
                  String? jsonString = prefs.getString(
                    'saved_electric_bend_list',
                  );

                  if (jsonString != null && jsonString.isNotEmpty) {
                    final List<dynamic> decoded = jsonDecode(jsonString);

                    // 🚀 바로 이 부분! map 뒤에 명시적 타입 <Map<String, double>>을 추가하고 (value as num) 처리
                    electricList = decoded.map<Map<String, double>>((item) {
                      final Map<String, dynamic> map =
                          item as Map<String, dynamic>;
                      return map.map(
                        (key, value) =>
                            MapEntry(key, (value as num).toDouble()),
                      );
                    }).toList();
                  }

                  // 전동 마킹 페이지로 즉시 연결
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ElectricMarkingPage(
                        startDir: 'RIGHT', // 방향은 저장된 값이나 기본값 사용
                        bendList: electricList,
                      ),
                    ),
                  );
                } else {
                  // 수동 모드면 기존 수동 라우터로 연결
                  Navigator.pushNamed(context, '/marking');
                }
              },
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

  // 기존 _buildGridCard 메서드는 동일하게 유지
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
