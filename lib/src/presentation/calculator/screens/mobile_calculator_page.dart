import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/core/utils/app_settings_controller.dart';

// 🚀 아래 파일들은 동일한 폴더 또는 적절한 경로에 있다고 가정합니다.
import 'mobile_input_tab.dart';
import 'mobile_result_tabs.dart';
import 'mobile_settings_tab.dart';
import 'package:tubing_calculator/src/data/machine_specs.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking_screen.dart';

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

  // 🚀 [추가] "현장" 탭에서 뒤로가기를 누르면 메인 메뉴로 바로 나가는 대신
  // "마킹" 탭으로 돌아온다 (전선관 계산기의 _goToMarkingTab과 동일한 패턴).
  void _goToMarkingTab() {
    setState(() {
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 [추가] 폴더블 대응 - 접힌 좁은 화면과 펼친 넓은 화면을 실시간으로
    // 구분한다. MobileInputTab/MobileResultTab 둘 다 데이터를
    // MobileBendDataManager 싱글톤에서 직접 읽으므로, 넓을 때 두 탭을
    // 나란히 붙여 보여줘도 데이터가 어긋나거나 사라지지 않는다.
    final bool isWide = MediaQuery.of(context).size.shortestSide >= 600;
    // 🚀 [버그 수정] "현장" 탭(가로 모드 전체화면 마킹 뷰)에 들어가도 이
    // 화면 자체의 AppBar/BottomNavigationBar가 계속 떠 있어서, 그만큼
    // 세로 공간이 줄어들며 내용이 잘려 보였다. 전선관 계산기와 동일하게
    // 이 탭일 때만 둘 다 숨긴다.
    final bool isFieldTab = _currentIndex == 2; // '현장' 탭

    // 머리 막대가 없어져 위쪽이 밝으므로 시계·배터리 글자를 어둡게.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        // 보관함 탭은 흰 바탕이라 맨 위(상태 표시줄 밑)도 흰색으로 맞춘다.
        backgroundColor: !isWide && _currentIndex == 4 ? pureWhite : slate100,
        // 전선관 계산기처럼 청록 머리 막대 없이 각 탭이 제 제목을 단다.
        // 현장 탭은 화면 끝까지 쓰므로 위 여백을 두지 않는다(모양은 그대로 두어
        // 탭을 옮겨도 입력하던 내용이 사라지지 않게).
        body: SafeArea(
          top: !isFieldTab,
          bottom: false,
          child: isWide ? _buildWideBody() : _buildNarrowBody(),
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
                      currentIndex: isWide
                          ? _wideIndexFor(_currentIndex)
                          : _currentIndex,
                      onTap: (tappedIndex) => _onTabTapped(
                        isWide ? _narrowIndexFor(tappedIndex) : tappedIndex,
                      ),
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
                      items: isWide
                          ? [
                              _buildNavItem(
                                Icons.edit_document,
                                Icons.edit_outlined,
                                "입력 / 마킹",
                                0,
                                isWide: true,
                              ),
                              _buildNavItem(
                                Icons.architecture_rounded,
                                Icons.architecture_outlined,
                                "현장",
                                1,
                                isWide: true,
                              ),
                              _buildNavItem(
                                Icons.view_in_ar_rounded,
                                Icons.view_in_ar_outlined,
                                "아이소",
                                2,
                                isWide: true,
                              ),
                              _buildNavItem(
                                Icons.folder_rounded,
                                Icons.folder_outlined,
                                "보관함",
                                3,
                                isWide: true,
                              ),
                              _buildNavItem(
                                Icons.settings_rounded,
                                Icons.settings_outlined,
                                "설정",
                                4,
                                isWide: true,
                              ),
                            ]
                          : [
                              _buildNavItem(
                                Icons.edit_document,
                                Icons.edit_outlined,
                                "입력",
                                0,
                                isWide: false,
                              ),
                              _buildNavItem(
                                Icons.format_list_numbered_rounded,
                                Icons.format_list_numbered_rtl_outlined,
                                "마킹",
                                1,
                                isWide: false,
                              ),
                              _buildNavItem(
                                Icons.architecture_rounded,
                                Icons.architecture_outlined,
                                "현장",
                                2,
                                isWide: false,
                              ),
                              _buildNavItem(
                                Icons.view_in_ar_rounded,
                                Icons.view_in_ar_outlined,
                                "아이소",
                                3,
                                isWide: false,
                              ),
                              _buildNavItem(
                                Icons.folder_rounded,
                                Icons.folder_outlined,
                                "보관함",
                                4,
                                isWide: false,
                              ),
                              _buildNavItem(
                                Icons.settings_rounded,
                                Icons.settings_outlined,
                                "설정",
                                5,
                                isWide: false,
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
  BottomNavigationBarItem _buildNavItem(
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
    int index, {
    required bool isWide,
  }) {
    final int currentDisplayIndex = isWide
        ? _wideIndexFor(_currentIndex)
        : _currentIndex;
    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Icon(
          currentDisplayIndex == index ? activeIcon : inactiveIcon,
          size: 24,
        ),
      ),
      label: label,
    );
  }

  // 🚀 좁은 화면 인덱스(0입력/1마킹/2현장/3아이소/4보관함/5설정, 6개) <->
  // 넓은 화면 인덱스(0입력+마킹/1현장/2아이소/3보관함/4설정, 5개) 매핑.
  // 넓은 화면에선 입력과 마킹을 한 탭에서 나란히 보여주므로 탭 개수가
  // 하나 줄어든다.
  int _wideIndexFor(int narrowIndex) {
    if (narrowIndex <= 1) return 0;
    return narrowIndex - 1;
  }

  int _narrowIndexFor(int wideIndex) {
    if (wideIndex == 0) return 0;
    return wideIndex + 1;
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
    isActive: _currentIndex == 2,
  );

  Widget _buildNarrowBody() {
    // 🚀 PageView 대신 IndexedStack 사용: 스와이프 금지, 렉 제거, 상태 유지 완벽!
    return IndexedStack(
      index: _currentIndex,
      children: [
        const MobileInputTab(),
        MobileResultTab(startDir: _startDir),
        _buildFieldTab(),
        MobileViewerTab(
          startDir: _startDir,
          onStartDirChanged: (val) => setState(() => _startDir = val),
        ),
        MobileHistoryTab(onLoaded: _onDrawingLoaded),
        const MobileSettingsTab(),
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

  Widget _buildWideBody() {
    final int wideIndex = _wideIndexFor(_currentIndex);
    return IndexedStack(
      index: wideIndex,
      children: [
        // 🚀 넓은 화면에서는 입력과 결과를 좌우로 나란히 - 둘 다
        // MobileBendDataManager를 직접 구독하므로 왼쪽에서 입력하면
        // 오른쪽 결과가 즉시 갱신된다.
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(flex: 5, child: MobileInputTab()),
            Container(width: 1, color: slate100),
            Expanded(flex: 6, child: MobileResultTab(startDir: _startDir)),
          ],
        ),
        _buildFieldTab(),
        MobileViewerTab(
          startDir: _startDir,
          onStartDirChanged: (val) => setState(() => _startDir = val),
        ),
        MobileHistoryTab(onLoaded: _onDrawingLoaded),
        const MobileSettingsTab(),
      ],
    );
  }
}
