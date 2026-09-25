import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:tubing_calculator/src/core/utils/settings_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/electric_bending_workspace.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/electric_marking_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_project_list_page.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/screens/work_log_main_screen.dart'
    show WorkLogMainScreen;
import 'package:tubing_calculator/src/presentation/conduit/screens/main_navigation_page.dart';
import 'package:tubing_calculator/src/presentation/reference/page/tube_reference_page.dart';
import 'package:tubing_calculator/src/presentation/profile/pages/mobile_profile_page.dart';
import 'package:tubing_calculator/src/presentation/profile/profile_tools.dart'
    show ProfileStore, kGuestName;

// 💡 슬레이트 컬러 정의 (눈이 편안한 짙은 회색 톤)
const Color makitaTeal = AppColors.brand;
const Color slate900 = Color(0xFF1E293B); // 버튼 글씨색 (고급스러움)
const Color slate600 = AppColors.textSub; // 아이콘 색 (얇은 선 강조)
const Color slate100 = AppColors.background; // 화면 전체 배경색
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
    // 🚀 [고침] PC(1280×800)에서 카드가 커서 8칸만 보였다. 넓은 화면은 칸을 늘린다.
    int crossAxisCount = screenWidth >= 1200
        ? 6
        : screenWidth >= 1000
        ? 5
        : screenWidth > 600
        ? 4
        : 2;

    return Scaffold(
      backgroundColor: slate100, // 💡 아주 밝은 회색 배경으로 하얀 버튼을 돋보이게 함
      appBar: AppBar(
        title: Text(
          isLiteVersion ? 'Tubing Calc Lite' : 'Tubing Calculator', // 제목 간소화
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.text,
            letterSpacing: 1,
          ),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        shape: const Border(bottom: BorderSide(color: AppColors.line)),
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
      padding: const EdgeInsets.all(20),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      // 🚀 [수정] 1.1로 고정돼 있으면 아이콘+제목+부제 내용 높이가 카드 높이보다
      // 커서 모든 카드에서 "BOTTOM OVERFLOWED BY 18 PIXELS"가 발생했음.
      // crossAxisCount가 늘어날수록(카드가 좁아질수록) 세로 여유가 더 필요해서
      // 컬럼 수에 따라 비율을 낮춰(카드를 더 높게) 내용이 들어갈 공간을 확보한다.
      childAspectRatio: crossAxisCount >= 5
          ? 1.0
          : crossAxisCount >= 4
          ? 0.85
          : 1.05,
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
          icon: Icons.square_foot,
          title: '형강 컷팅',
          subtitle: '찬넬/앵글 재단 계획·지시서',
          iconColor: makitaTeal,
          onTap: () => Navigator.pushNamed(context, '/steel-cutting'),
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
              "현재 수동 모드입니다. 설정에서 전동 모드로 변경해 주십시오.",
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
              "현재 전동 모드입니다. 설정에서 수동 모드로 변경해 주십시오.",
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
                // 저장된 글이 깨져 있어도 단추가 죽지 않게.
                try {
                  final List<dynamic> decoded = jsonDecode(jsonString);
                  electricList = decoded.map<Map<String, double>>((item) {
                    final Map<String, dynamic> map =
                        item as Map<String, dynamic>;
                    return map.map(
                      (key, value) =>
                          MapEntry(key, value is num ? value.toDouble() : 0.0),
                    );
                  }).toList();
                } catch (e) {
                  debugPrint('전동 벤딩 목록 읽기 실패: $e');
                  electricList = [];
                }
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
        // 🚀 [고침] PC·태블릿 홈에서 작업 일지(내 프로젝트)로 갈 길이 없었다.
        // 위 "프로젝트 관리"는 BOM 집계 화면이라 폰의 "내 프로젝트"와 다르다.
        _buildGridCard(
          context,
          icon: Icons.work_history_outlined,
          title: '내 프로젝트',
          subtitle: '작업 일지 · 이슈 · 공정',
          iconColor: makitaTeal,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WorkLogMainScreen()),
          ),
        ),
        _buildGridCard(
          context,
          icon: Icons.event_note_rounded,
          title: '내 일정 관리',
          subtitle: '프로젝트+개인 일정 통합 캘린더',
          iconColor: makitaTeal,
          onTap: () => Navigator.pushNamed(context, '/my-schedule'),
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
        // 🚀 [추가] 태블릿/데스크톱 폭(이 화면 자체의 진입 조건)에서는
        // 이 메뉴가 아예 없어서 TabletLayoutBoardPage에 도달할 방법이
        // 없었음. 모바일 목록형 메뉴의 "작업 배치도"와 같은 기능을 연결.
        _buildGridCard(
          context,
          icon: Icons.architecture_rounded,
          title: '작업 배치도',
          subtitle: '캐비닛 중판 레이아웃 스케치',
          iconColor: makitaTeal,
          onTap: () {
            // 폰 메뉴와 똑같이 저장된 배치도 목록부터 연다(예전엔 태블릿
            // 메뉴만 빈 도면이 바로 열려서 저장한 배치도를 다시 열 수 없었다).
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LayoutBoardProjectListPage(),
              ),
            );
          },
        ),
        // 🚀 [추가] 폰 홈에만 있던 것들. PC에서는 이름을 넣을 곳(프로필)이 없어 내 일정이
        // "프로필 수정에서 이름을 먼저 등록하십시오"라고만 했다.
        _buildGridCard(
          context,
          icon: Icons.electrical_services_rounded,
          title: '전선관 벤딩',
          subtitle: '장비 프로필 · 마킹 뷰어',
          iconColor: Colors.blueGrey,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ConduitMainNavigation()),
          ),
        ),
        _buildGridCard(
          context,
          icon: Icons.menu_book_rounded,
          title: '현장 자료',
          subtitle: '규격표 · 벤더·톱 사용법',
          iconColor: makitaTeal,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TubeReferencePage()),
          ),
        ),
        _buildGridCard(
          context,
          icon: Icons.person_rounded,
          title: '프로필',
          subtitle: '이름 · 구글 계정 · 설정 보관',
          iconColor: makitaTeal,
          onTap: () async {
            final name = await ProfileStore.instance.savedName() ?? '';
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MobileProfilePage(
                  currentWorker: name.isEmpty ? kGuestName : name,
                ),
              ),
            );
          },
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 40),
            ),
            const SizedBox(height: 12),
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
