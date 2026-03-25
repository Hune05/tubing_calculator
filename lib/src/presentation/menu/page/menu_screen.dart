import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:tubing_calculator/src/core/utils/settings_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/electric_bending_workspace.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/electric_marking_page.dart';

// 💡 슬레이트 컬러 정의 (눈이 편안한 짙은 회색 톤)
const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF1E293B); // 버튼 글씨색 (고급스러움)
const Color slate600 = Color(0xFF475569); // 아이콘 색 (얇은 선 강조)
const Color slate100 = Color(0xFFF1F5F9); // 화면 전체 배경색
const Color pureWhite = Color(0xFFFFFFFF); // 버튼 배경색

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  // =========================================================================
  // 💡 [배포 스위치] 다른 사람에게 줄 APK를 만들 때만 여기를 true 로 바꾸세요!!
  // =========================================================================
  static const bool isLiteVersion = false;
  // false: 사장님 전용 풀버전 (격자형)
  // true: 남한테 배포할 라이트 버전 (세련된 얇은 선 왕버튼형)

  // 🚀 모드 인터록 검사 함수 (풀버전용 문지기)
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
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    var screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = screenWidth > 600 ? 4 : 2;

    return Scaffold(
      backgroundColor: slate100, // 💡 아주 밝은 회색 배경으로 하얀 버튼을 돋보이게 함
      appBar: AppBar(
        title: Text(
          isLiteVersion ? 'Tubing Calc Lite' : 'Tubing Calculator', // 제목 간소화
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        backgroundColor: makitaTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        // 💡 스위치 값에 따라 다른 메뉴판을 그립니다!
        child: isLiteVersion
            ? _buildLiteCleanOutlineMenu(context) // 🚀 요청하신 세련된 얇은 선 왕버튼 메뉴
            : _buildFullGridMenu(context, crossAxisCount), // 사장님용 격자 메뉴
      ),
    );
  }

  // =========================================================================
  // 🚀 [신규] 배포용 '세련된 얇은 선 왕버튼' 메뉴판 (흰 배경 + Outline 아이콘)
  // =========================================================================
  Widget _buildLiteCleanOutlineMenu(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28.0), // 💡 화면 가장자리 여백을 넓혀서 시원하게!
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildOutlineBigActionButton(
                    context,
                    // 💡 [교체] 계산기 + 튜브 느낌의 얇은 선 아이콘
                    icon: Icons.calculate_outlined,
                    title: '수동 계산기', // 💡 명칭 간소화
                    onTap: () => Navigator.pushNamed(context, '/calculator'),
                  ),
                ),
                Expanded(
                  child: _buildOutlineBigActionButton(
                    context,
                    // 💡 [교체] 연필 + 자 느낌의 '마킹' 전용 얇은 선 아이콘
                    icon: Icons.edit_note_outlined,
                    title: '마킹 가이드',
                    onTap: () => Navigator.pushNamed(context, '/marking'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildOutlineBigActionButton(
                    context,
                    // 💡 [교체] 폴더 안에 도면이 있는 느낌의 얇은 선 아이콘
                    icon: Icons.collections_bookmark_outlined,
                    title: '보관함',
                    onTap: () => Navigator.pushNamed(context, '/history'),
                  ),
                ),
                Expanded(
                  child: _buildOutlineBigActionButton(
                    context,
                    // 💡 [교체] 톱니바퀴 안에 조절 장치가 있는 느낌의 얇은 선 아이콘
                    icon: Icons.settings_suggest_outlined,
                    title: '기기 설정',
                    onTap: () => Navigator.pushNamed(context, '/settings'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 [신규] 세련된 '얇은 선 왕버튼' 위젯 (흰 배경 + Outline 아이콘 전용)
  Widget _buildOutlineBigActionButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(36), // 💡 더 둥글게 해서 부드러운 느낌
      child: Container(
        margin: const EdgeInsets.all(16), // 💡 버튼 사이 간격을 넓혀서 답답함 완전 해소!
        padding: const EdgeInsets.all(24), // 버튼 내부 여백
        decoration: BoxDecoration(
          color: pureWhite, // 💡 무조건 하얀색 배경! (깔끔함의 핵심)
          borderRadius: BorderRadius.circular(36),
          // 💡 답답한 굵은 테두리 선 제거!!!
          boxShadow: [
            // 💡 고급스럽고 부드러운 하이엔드 그림자 효과 적용
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03), // 아주 연한 그림자
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // 💡 중앙 정렬
          children: [
            // 💡 아이콘 크기는 '큼직하게' (72) + 얇은 선 색상 (slate600)
            Icon(icon, color: slate600, size: 72),
            const SizedBox(height: 20), // 아이콘과 글자 사이 적절한 여백
            Text(
              title, // 💡 간략한 명칭 적용!
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18, // 💡 글자 크기도 세련된 비율로 조정
                fontWeight: FontWeight.bold, // 너무 굵지 않게 볼드 적용
                color: slate900, // 글씨는 세련된 짙은 회색
                height: 1.2, // 줄 간격 쾌적하게
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 2. 사장님 전용 메뉴판 (isLiteVersion = false 일 때 - 기존 격자형 유지)
  // =========================================================================
  Widget _buildFullGridMenu(BuildContext context, int crossAxisCount) {
    return GridView.count(
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
          iconColor: makitaTeal,
          onTap: () => Navigator.pushNamed(context, '/cutting'),
        ),
        _buildGridCard(
          context,
          icon: Icons.precision_manufacturing,
          title: '전동 벤딩 계산기',
          subtitle: 'NC/CNC YBC 제원 산출',
          iconColor: Colors.orange.shade800,
          onTap: () async {
            bool isOk = await _checkMode(
              context,
              "전동 (Electric)",
              "현재 수동 모드입니다. 설정에서 전동 모드로 변경해 주세요.",
            );
            if (!isOk) return;

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
        _buildGridCard(
          context,
          icon: Icons.calculate_outlined,
          title: '수동 벤딩 계산기',
          subtitle: '단일/다중 벤딩 작업',
          iconColor: makitaTeal,
          onTap: () async {
            bool isOk = await _checkMode(
              context,
              "수동 (Hand)",
              "현재 전동 모드입니다. 설정에서 수동 모드로 변경해 주세요.",
            );
            if (!isOk) return;

            if (!context.mounted) return;
            Navigator.pushNamed(context, '/calculator');
          },
        ),
        _buildGridCard(
          context,
          icon: Icons.straighten,
          title: '마킹 및 컷팅',
          subtitle: '최종 컷팅 길이 확인',
          iconColor: makitaTeal,
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            final currentMode = prefs.getString('benderType') ?? "수동 (Hand)";

            if (!context.mounted) return;

            if (currentMode == "전동 (Electric)") {
              List<Map<String, double>> electricList = [];
              String? jsonString = prefs.getString('saved_electric_bend_list');

              if (jsonString != null && jsonString.isNotEmpty) {
                final List<dynamic> decoded = jsonDecode(jsonString);
                electricList = decoded.map<Map<String, double>>((item) {
                  final Map<String, dynamic> map = item as Map<String, dynamic>;
                  return map.map(
                    (key, value) => MapEntry(key, (value as num).toDouble()),
                  );
                }).toList();
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ElectricMarkingPage(
                    startDir: 'RIGHT',
                    bendList: electricList,
                  ),
                ),
              );
            } else {
              Navigator.pushNamed(context, '/marking');
            }
          },
        ),
        _buildGridCard(
          context,
          icon: Icons.folder_special_outlined,
          title: '도면 보관함',
          subtitle: '이전 도면 및 내역',
          iconColor: makitaTeal,
          onTap: () => Navigator.pushNamed(context, '/history'),
        ),
        _buildGridCard(
          context,
          icon: Icons.assignment_outlined,
          title: '프로젝트 관리',
          subtitle: 'BOM 및 소모량 집계',
          iconColor: makitaTeal,
          onTap: () => Navigator.pushNamed(context, '/projects'),
        ),
        _buildGridCard(
          context,
          icon: Icons.inventory_2_outlined,
          title: '자재 관리',
          subtitle: '튜브 및 피팅 재고',
          iconColor: makitaTeal,
          onTap: () => Navigator.pushNamed(context, '/inventory'),
        ),
        _buildGridCard(
          context,
          icon: Icons.settings_suggest_outlined,
          title: '장비 및 설정',
          subtitle: '벤더 제원 및 배관 설정',
          iconColor: makitaTeal,
          onTap: () => Navigator.pushNamed(context, '/settings'),
        ),
      ],
    );
  }

  // 사장님 풀버전용 격자 카드 위젯 (기존 유지)
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
