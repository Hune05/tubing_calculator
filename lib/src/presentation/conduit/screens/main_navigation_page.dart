import 'package:tubing_calculator/src/presentation/common/quick_tool_bar.dart';
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/swipe_delete.dart'
    show calcNavCompact;
import 'package:tubing_calculator/src/core/theme/field_view.dart';
import 'package:tubing_calculator/src/presentation/common/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_marking_logic.dart';

import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_input_tab.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_result_tab.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_history_tab.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_field_data.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking_screen.dart';
import 'package:tubing_calculator/src/presentation/field/measured_pipe_visualizer.dart';

Color get makitaTeal => fc.brand;
Color get slate900 => fc.text;
Color get slate600 => fc.textSub;
Color get slate100 => fc.background;
Color get pureWhite => fc.surface;

const Color paperBg = Color(0xFFF2F0E9);
const Color strokeColor = Color(0xFF2D2D2D);
const Color accentRed = Color(0xFFD32F2F);
const Color tapeYellow = Color(0xFFFFD54F);
const Color tableHeaderGray = Color(0xFFDFDDD3);
const Color highlightColor = Colors.deepOrange;

// =========================================================
// 1. 메인 네비게이션 (총 6개 탭)
// =========================================================
class ConduitMainNavigation extends StatefulWidget {
  const ConduitMainNavigation({super.key});

  @override
  State<ConduitMainNavigation> createState() => _ConduitMainNavigationState();
}

class _ConduitMainNavigationState extends State<ConduitMainNavigation> {
  /// 가로로 눕힌 폰처럼 높이가 낮으면 아래 탭 막대를 얇게(10-09).
  bool _compactNav = false;

  // 폰에 적어 둔 전선관 설정을 다 읽었는지.
  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    // 폰에 적어 둔 전선관 설정(테이크업·게인·CLR…)을 읽어 온다.
    // 🚀 [고침] 예전에는 읽기를 기다리지 않고 탭들을 만들어서, 같이 만들어지는
    // 설정 탭이 처음 기본값(게인 81.2)으로 칸을 채웠다. 그 상태로 저장을 누르면
    // 저장해 둔 값(예: 82.5)이 기본값으로 덮였다. 다 읽은 뒤에 탭을 만든다.
    loadGlobalBenderSettings().whenComplete(() {
      if (mounted) setState(() => _settingsLoaded = true);
    });
    installConduitHistoryExtras();
  }

  // 🚀 [수정] 폴더블 대응. 예전엔 PageView+PageController로 탭을
  // 넘겼는데, 넓은 화면에서 "입력"과 "마킹" 탭을 한 페이지로 합치면
  // 탭 개수가 6→5로 줄어들어 PageController가 들고 있던 스크롤
  // 페이지 번호가 범위를 벗어나 죽을 수 있었다(예: 설정 탭(5)에
  // 있다가 화면을 펼치면 5칸짜리 PageView엔 인덱스 5가 없음).
  // 이 화면은 이미 NeverScrollableScrollPhysics라 스와이프를 안 쓰고
  // 있었으므로, 인덱스만 바꿔주면 되는 IndexedStack으로 교체해 이
  // 위험을 원천적으로 없앴다.
  //
  // _selectedIndex는 항상 "좁은 화면" 기준 인덱스(0입력/1마킹/2보관함/
  // 3현장/4아이소/5설정)로만 저장하고, 넓은 화면에서 보여줄 때만
  // _wideIndexFor로 변환한다.
  int _selectedIndex = 0;

  // 🚀 [고침] 좁은 화면과 넓은 화면은 탭을 놓는 자리(부모)가 달라서, 폴드를
  // 펼치거나 접으면 탭들이 새로 만들어져 입력 중인 칸과 저장 안 한 설정이
  // 날아갔다. 탭마다 열쇠를 붙여 같은 상태를 옮겨 쓴다.
  final GlobalKey _inputKey = GlobalKey(debugLabel: 'conduit_input');
  final GlobalKey _resultKey = GlobalKey(debugLabel: 'conduit_result');
  final GlobalKey _historyKey = GlobalKey(debugLabel: 'conduit_history');
  final GlobalKey _fieldKey = GlobalKey(debugLabel: 'conduit_field');
  final GlobalKey _viewerKey = GlobalKey(debugLabel: 'conduit_viewer');
  final GlobalKey _settingsKey = GlobalKey(debugLabel: 'conduit_settings');

  void _goToInputTab() {
    setState(() => _selectedIndex = 0);
  }

  void _goToHistoryTab() {
    setState(() => _selectedIndex = 2);
  }

  void _goToMarkingTab() {
    setState(() => _selectedIndex = 1);
  }

  // 현장 보기(보통·햇빛·야간) 테마로 감싼다: 기본 위젯(입력칸·스위치·창)도 같은 색(D-D).
  @override
  Widget build(BuildContext context) =>
      FieldViewTheme(child: Builder(builder: _buildPage));

  Widget _buildPage(BuildContext context) {
    final bool isFieldTab = _selectedIndex == 3; // '현장'(가로) 탭
    _compactNav = calcNavCompact(context);

    return Scaffold(
      backgroundColor: slate100,
      body: !_settingsLoaded
          ? Center(child: CircularProgressIndicator(color: makitaTeal))
          : QuickBarSuppress(enabled: isFieldTab, child: _buildNarrowBody()),
      bottomNavigationBar: isFieldTab
          ? const SizedBox.shrink() // 현장(가로) 탭일 때만 네비바 숨김
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
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(_compactNav ? 6 : 8),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: _compactNav ? 0 : 8,
                  ),
                  child: BottomNavigationBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    type: BottomNavigationBarType.fixed,
                    currentIndex: _selectedIndex,
                    selectedItemColor: makitaTeal,
                    unselectedItemColor: slate600,
                    selectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                    onTap: (tappedIndex) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedIndex = tappedIndex;
                      });
                    },
                    items: [
                      _buildGlyphNavItem(AppGlyph.navInput, '입력', 0),
                      _buildGlyphNavItem(AppGlyph.navMarking, '마킹', 1),
                      _buildGlyphNavItem(AppGlyph.navStorage, '보관함', 2),
                      _buildGlyphNavItem(AppGlyph.navField, '현장', 3),
                      _buildGlyphNavItem(AppGlyph.navIso, '아이소', 4),
                      _buildNavItem(
                        AppIcons.settings,
                        AppIcons.settings,
                        '설정',
                        5,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  /// 현장 탭(가로 줄자 화면). 튜브와 같은 화면을 쓴다.
  Widget _buildFieldTab() => FieldMarkingScreen(
    key: _fieldKey,
    progressKey: 'field_progress_conduit_v1',
    listenable: conduitFieldListenable(),
    compute: computeConduitFieldData,
    onCloseTab: _goToMarkingTab,
    isActive: _selectedIndex == 3,
    measureGroup: conduitMeasureGroup,
    measureSetup: () => conduitMeasureSetup(globalBenderSettings.value),
    measureRef: () => conduitRefPhrase(globalBenderSettings.value),
    measureSource: 'conduit',
  );

  Widget _buildNarrowBody() {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        ConduitInputTab(key: _inputKey), // 0. 입력
        ConduitResultTab(
          key: _resultKey,
          onOpenArchive: _goToHistoryTab,
        ), // 1. 마킹
        NormalViewTheme(
          child: ConduitHistoryTab(key: _historyKey, onLoaded: _goToInputTab),
        ), // 2
        _buildFieldTab(), // 3. 현장
        ConduitViewerTab(key: _viewerKey), // 4. 아이소
        NormalViewTheme(
          child: ConduitSettingsPage(
            key: _settingsKey,
            isActive: _selectedIndex == 5,
          ),
        ), // 5. 설정
      ],
    );
  }

  /// 직접 그린 아이콘 탭(고르면 속이 옅게 채워진다).
  BottomNavigationBarItem _buildGlyphNavItem(
    AppGlyph glyph,
    String label,
    int index,
  ) {
    return BottomNavigationBarItem(
      icon: Padding(
        padding: EdgeInsets.only(bottom: _compactNav ? 0 : 4),
        child: AppIcon(glyph, size: 24, filled: _selectedIndex == index),
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
        padding: EdgeInsets.only(bottom: _compactNav ? 0 : 4),
        child: Icon(
          _selectedIndex == index ? activeIcon : inactiveIcon,
          size: 24,
        ),
      ),
      label: label,
    );
  }
}

// =========================================================
// 2. 뷰어 탭 래퍼 (데이터 연결)
// =========================================================
class ConduitViewerTab extends StatefulWidget {
  const ConduitViewerTab({super.key});

  @override
  State<ConduitViewerTab> createState() => _ConduitViewerTabState();
}

class _ConduitViewerTabState extends State<ConduitViewerTab> {
  @override
  void initState() {
    super.initState();
    // 커플링 체결·시작 방향을 되살린다(마킹 탭을 안 열어도 현장 탭·아이소가 맞게).
    loadConduitStartDir();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      // 굽힘 반경·관 굵기·커플링 깊이를 설정에서 읽으므로 설정이 바뀌어도 다시 그린다.
      // 10-13: 보관함 불러오기·↶로 시작 방향이 바뀌어도 아이소가 따라가게 시작 방향도 듣는다.
      animation: Listenable.merge([
        ConduitDataManager(),
        globalMarkingState,
        globalBenderSettings,
        conduitStartDir,
      ]),
      builder: (context, child) {
        final manager = ConduitDataManager();
        final bendList = manager.bendList;
        final totalCut = globalMarkingState.value['totalCutLength'] ?? 0.0;

        // 🚀 [추가] 실제 형상으로 그리려면 전선관 제원이 필요하다.
        // 튜브 제원이 아니라 전선관 설정(굽힘 반경·관 굵기·커플링 깊이)을 쓴다.
        final cs = globalBenderSettings.value;
        final double clr = (cs['clr'] as num?)?.toDouble() ?? 0.0;
        final double coupling =
            (cs['couplingDepth'] as num?)?.toDouble() ?? 0.0;
        final double od = conduitDrawOuterDiameterMm(cs);

        return Scaffold(
          backgroundColor: const Color(0xFF151B22),
          body: SafeArea(
            // 10-18: 튜브와 같은 그림 + 캐드식 치수·검사 실측(길이·각도).
            child: MeasuredPipeVisualizer(
              bendList: bendList,
              totalCutLength: totalCut,
              bendRadius: clr,
              outerDiameter: od,
              fittingDepth: coupling,
              initialStartDir: conduitStartDir.value,
              useSavedDirection: false,
              startDirPrefKey: 'conduit_saved_start_dir',
              // 여기서 바꾼 시작 방향이 현장 탭에도 가게(전엔 앱을 다시 켜야 반영됐다).
              onStartDirChanged: (v) => conduitStartDir.value = v,
              compute: computeConduitFieldData,
              progressKey: 'field_progress_conduit_v1',
              dataListenable: conduitFieldListenable(),
              measureGroup: conduitMeasureGroup,
              measureSetup: () =>
                  conduitMeasureSetup(globalBenderSettings.value),
              measureRef: () => conduitRefPhrase(globalBenderSettings.value),
              source: 'conduit',
              skipEmptyStraight: false,
            ),
          ),
        );
      },
    );
  }
}

// =========================================================
// 3. 기존 현장(가로 모드) 줄자 화면 (코드 유지)
// =========================================================
// 10-18: 전선관 아이소 그림은 튜브와 같은 MobilePipeVisualizer(MeasuredPipeVisualizer)를 쓴다.
// 예전 복사본(ConduitIsoVisualizer·ConduitIsoPainter)은 지웠다.

/// 전선관 벤딩 실측 기록 묶음 이름. 현장 탭과 아이소가 같은 이름으로 적는다(10-18).
String conduitMeasureGroup() {
  // 실측 기록 묶음: 종류·규격·제조사·장비·치수 기준 한 줄(예: Rigid 22mm · Custom 유압식 · 관 중심).
  // 10-13: 제조사·치수 기준을 넣었다(관 중심과 관 등으로 잰 값이 한 묶음에 섞였다).
  final s = globalBenderSettings.value;
  final type = switch (s['benderType']) {
    'ram' => '유압식',
    'chicago' => '시카고식',
    _ => '수동',
  };
  final ref = conduitCenterRef(s) ? '관 중심' : '관 등';
  return '${s['conduitType']} ${s['conduitSize']} · ${s['manufacturer']} $type · $ref';
}
