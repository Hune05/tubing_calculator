import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

// 🚀 분리된 탭 파일들 임포트 (경로는 프로젝트 구조에 맞게 수정하세요)
import 'mobile_input_tab.dart';
import 'mobile_result_tabs.dart';
import 'mobile_settings_tab.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class MobileCalculatorPage extends StatefulWidget {
  const MobileCalculatorPage({super.key});

  @override
  State<MobileCalculatorPage> createState() => _MobileCalculatorPageState();
}

class _MobileCalculatorPageState extends State<MobileCalculatorPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  String _startDir = "RIGHT";

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onTabTapped(int index) {
    HapticFeedback.lightImpact();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slate100,
      appBar: AppBar(
        backgroundColor: makitaTeal,
        title: const Text(
          "모바일 벤딩 계산기",
          style: TextStyle(fontWeight: FontWeight.bold, color: pureWhite),
        ),
        iconTheme: const IconThemeData(color: pureWhite),
        elevation: 0,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(),
        children: [
          const MobileInputTab(),
          MobileResultTab(startDir: _startDir),
          MobileViewerTab(
            startDir: _startDir,
            onStartDirChanged: (val) => setState(() => _startDir = val),
          ),
          const MobileHistoryTab(),
          const MobileSettingsTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          backgroundColor: pureWhite,
          selectedItemColor: makitaTeal,
          unselectedItemColor: slate600,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 10,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.penTool),
              label: "입력",
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.calculator),
              label: "결과",
            ),
            BottomNavigationBarItem(icon: Icon(LucideIcons.box), label: "도면"),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_open),
              label: "보관함",
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.settings),
              label: "설정",
            ),
          ],
        ),
      ),
    );
  }
}
