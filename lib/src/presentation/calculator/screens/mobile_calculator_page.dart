import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/core/utils/app_settings_controller.dart';

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

    // 🚀 [추가] 앱 전역 설정(단위, 최소 직선 구간, 화면 꺼짐 방지 등)도
    // 여기서 한 번 미리 로드해둔다. 이렇게 해두면 사용자가 설정 탭을
    // 아직 열지 않았어도 "화면 꺼짐 방지" 같은 값이 앱 시작 시점부터
    // 바로 적용된다. 이미 로드되어 있으면 ensureLoaded()는 아무 것도
    // 하지 않으므로 여러 곳에서 불러도 안전하다.
    AppSettingsController().ensureLoaded();
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
