import 'package:tubing_calculator/src/presentation/common/quick_tool_bar.dart';
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/core/theme/field_view.dart';
import 'package:tubing_calculator/src/presentation/common/app_icons.dart';
import 'package:flutter/services.dart';

import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/core/utils/app_settings_controller.dart';

// 🚀 아래 파일들은 동일한 폴더 또는 적절한 경로에 있다고 가정합니다.
import 'mobile_input_tab.dart';
import 'mobile_result_tabs.dart';
import 'mobile_settings_tab.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking_screen.dart';

Color get makitaTeal => fc.brand;
Color get slate900 => fc.text;
Color get slate600 => fc.textSub;
Color get slate100 => fc.background;
Color get pureWhite => fc.surface;

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
    _loadSavedStartDir();
  }

  /// 10-09: 저장해 둔 시작 방향을 페이지가 처음부터 쓴다. 예전에는 아이소 그림이 만들어질 때만
  /// 읽어서, 목록이 빈 채로 켜면 "우"로 시작했다가 첫 줄을 넣은 뒤에야 저장값으로 바뀌어
  /// 넣을 때 막히지 않던 방향이 "꺾을 수 없음"이 되었다(전선관 화면은 처음부터 읽는다).
  Future<void> _loadSavedStartDir() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(
        'mobile_saved_start_dir',
      );
      if (saved != null && saved.isNotEmpty && mounted && saved != _startDir) {
        setState(() => _startDir = saved);
      }
    } catch (_) {}
  }

  // 🚀 하단 탭바 터치 시 애니메이션 없이 즉각적으로 인덱스만 변경합니다.
  void _onTabTapped(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _currentIndex = index;
    });
  }

  // 🚀 [추가] "현장" 탭에서 뒤로가기를 누르면 메인 메뉴로 바로 나가는 대신
  // "마킹" 탭으로 돌아온다 (전선관 계산기의 _goToMarkingTab과 동일한 패턴).
  void _goToHistoryTab() {
    setState(() {
      _currentIndex = 2;
    });
  }

  void _goToMarkingTab() {
    setState(() {
      _currentIndex = 1;
    });
  }

  // 현장 보기(보통·햇빛·야간) 테마로 감싼다: 기본 위젯(입력칸·스위치·창)도 같은 색(D-D).
  @override
  Widget build(BuildContext context) =>
      FieldViewTheme(child: Builder(builder: _buildPage));

  Widget _buildPage(BuildContext context) {
    // 🚀 [버그 수정] "현장" 탭(가로 모드 전체화면 마킹 뷰)에 들어가도 이
    // 화면 자체의 AppBar/BottomNavigationBar가 계속 떠 있어서, 그만큼
    // 세로 공간이 줄어들며 내용이 잘려 보였다. 전선관 계산기와 동일하게
    // 이 탭일 때만 둘 다 숨긴다.
    final bool isFieldTab = _currentIndex == 3; // '현장' 탭

    // 머리 막대가 없어져 위쪽이 밝으므로 시계·배터리 글자를 어둡게.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: slate100,
        // 전선관 계산기처럼 청록 머리 막대 없이 각 탭이 제 제목을 단다.
        // 현장 탭은 화면 끝까지 쓰므로 위 여백을 두지 않는다(모양은 그대로 두어
        // 탭을 옮겨도 입력하던 내용이 사라지지 않게).
        body: SafeArea(
          top: !isFieldTab,
          bottom: false,
          // 막대는 앱 전체에 있다(GlobalQuickToolBar). 가로로 쓰는 현장 탭에서만 뺀다.
          child: QuickBarSuppress(
            enabled: isFieldTab,
            child: _buildNarrowBody(),
          ),
        ),
        bottomNavigationBar: isFieldTab
            ? const SizedBox.shrink()
            : Container(
                decoration: BoxDecoration(
                  color: pureWhite,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: BottomNavigationBar(
                      elevation: 0,
                      currentIndex: _currentIndex,
                      onTap: _onTabTapped,
                      backgroundColor: Colors.transparent,
                      selectedItemColor: makitaTeal,
                      unselectedItemColor: slate600,
                      type: BottomNavigationBarType.fixed,
                      selectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                      items: [
                        _buildGlyphNavItem(AppGlyph.navInput, "입력", 0),
                        _buildGlyphNavItem(AppGlyph.navMarking, "마킹", 1),
                        _buildGlyphNavItem(AppGlyph.navStorage, "보관함", 2),
                        _buildGlyphNavItem(AppGlyph.navField, "현장", 3),
                        _buildGlyphNavItem(AppGlyph.navIso, "아이소", 4),
                        _buildNavItem(
                          AppIcons.settings,
                          AppIcons.settings,
                          "설정",
                          5,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // 🚀 [추가] 전선관 계산기(main_navigation_page.dart)와 탭 이름/아이콘을
  // 통일하면서, 그쪽의 선택 시 아이콘이 채워진 형태로 바뀌는 방식도
  // 그대로 가져왔다 (전엔 항상 같은 아이콘이라 선택 표시가 색상뿐이었음).
  /// 직접 그린 아이콘 탭(고르면 속이 옅게 채워진다).
  BottomNavigationBarItem _buildGlyphNavItem(
    AppGlyph glyph,
    String label,
    int index,
  ) {
    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: AppIcon(glyph, size: 24, filled: _currentIndex == index),
      ),
      label: label,
    );
  }

  BottomNavigationBarItem _buildNavItem(
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
    int index,
  ) {
    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Icon(
          _currentIndex == index ? activeIcon : inactiveIcon,
          size: 24,
        ),
      ),
      label: label,
    );
  }

  /// 현장 탭(가로 줄자 화면). 전선관과 같은 화면을 쓴다.
  Widget _buildFieldTab() => FieldMarkingScreen(
    listenable: Listenable.merge([
      MobileBendDataManager(),
      MachineSpecs(),
      AppSettingsController(),
    ]),
    compute: () => computeTubeFieldData(startDir: _startDir),
    onCloseTab: _goToMarkingTab,
    isActive: _currentIndex == 3,
    measureGroup: () {
      // 실측 기록 묶음: 규격·장비 한 줄(예: 12.7mm SUS · Swagelok 수동 (Hand)).
      final c = AppSettingsController();
      final od = c.isInch ? '${c.tubeOD}"' : '${c.tubeOD}mm';
      return '$od ${c.tubeMaterial} · ${c.benderBrand} ${c.benderType}';
    },
  );

  Widget _buildNarrowBody() {
    // 🚀 PageView 대신 IndexedStack 사용: 스와이프 금지, 렉 제거, 상태 유지 완벽!
    return IndexedStack(
      index: _currentIndex,
      children: [
        MobileInputTab(startDir: _startDir),
        MobileResultTab(startDir: _startDir, onOpenArchive: _goToHistoryTab),
        MobileHistoryTab(onLoaded: _onDrawingLoaded),
        _buildFieldTab(),
        MobileViewerTab(
          startDir: _startDir,
          onStartDirChanged: (val) => setState(() => _startDir = val),
        ),
        const NormalViewTheme(child: MobileSettingsTab()),
      ],
    );
  }

  /// 보관함 도면을 불러왔을 때: 시작 방향을 맞추고 입력 탭으로.
  void _onDrawingLoaded(String startDir) {
    setState(() {
      _startDir = startDir;
      _currentIndex = 0;
    });
  }
}
