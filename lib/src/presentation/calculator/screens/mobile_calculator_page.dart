import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';

// 🚀 아래 파일들은 동일한 폴더 또는 적절한 경로에 있다고 가정합니다.
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
  // 🚀 스와이프를 없앴으므로 PageController는 완전히 삭제합니다.
  int _currentIndex = 0;
  String _startDir = "RIGHT";

  @override
  void initState() {
    super.initState();
    // 🚀 앱이 켜질 때 딱 한 번 과거 데이터를 무조건 불러와서 꽉 쥡니다!
    MobileBendDataManager().loadSavedSettings();
  }

  // 🚀 하단 탭바 터치 시 애니메이션 없이 즉각적으로 인덱스만 변경합니다.
  void _onTabTapped(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slate100,
      appBar: AppBar(
        backgroundColor: makitaTeal,
        title: const Text(
          "벤딩 마킹 계산기",
          style: TextStyle(fontWeight: FontWeight.bold, color: pureWhite),
        ),
        iconTheme: const IconThemeData(color: pureWhite),
        elevation: 0,
      ),
      // 🚀 PageView 대신 IndexedStack 사용: 스와이프 금지, 렉 제거, 상태 유지 완벽!
      body: IndexedStack(
        index: _currentIndex,
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
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 12,
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
