import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vmath;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_marking_logic.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/pipe_path_points.dart';

import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_input_tab.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_result_tab.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_history_tab.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

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

  bool _isWide(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  // 넓은 화면: 0=입력+마킹 합침, 1=보관함, 2=현장, 3=아이소, 4=설정 (5개)
  int _wideIndexFor(int narrowIndex) {
    if (narrowIndex <= 1) return 0;
    return narrowIndex - 1;
  }

  int _narrowIndexFor(int wideIndex, {required bool wasOnMarking}) {
    if (wideIndex == 0) return wasOnMarking ? 1 : 0;
    return wideIndex + 1;
  }

  void _goToMarkingTab() {
    setState(() => _selectedIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = _isWide(context);
    final bool isFieldTab = _selectedIndex == 3; // '현장'(가로) 탭

    return Scaffold(
      backgroundColor: slate100,
      body: isWide ? _buildWideBody() : _buildNarrowBody(),
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
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    type: BottomNavigationBarType.fixed,
                    currentIndex: isWide
                        ? _wideIndexFor(_selectedIndex)
                        : _selectedIndex,
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
                        _selectedIndex = isWide
                            ? _narrowIndexFor(
                                tappedIndex,
                                wasOnMarking: _selectedIndex == 1,
                              )
                            : tappedIndex;
                      });
                    },
                    items: isWide
                        ? [
                            _buildNavItem(
                              Icons.edit_document,
                              Icons.edit_outlined,
                              '입력/마킹',
                              0,
                              isWide: true,
                            ),
                            _buildNavItem(
                              Icons.folder_rounded,
                              Icons.folder_outlined,
                              '보관함',
                              1,
                              isWide: true,
                            ),
                            _buildNavItem(
                              Icons.architecture_rounded,
                              Icons.architecture_outlined,
                              '현장',
                              2,
                              isWide: true,
                            ),
                            _buildNavItem(
                              Icons.view_in_ar_rounded,
                              Icons.view_in_ar_outlined,
                              '아이소',
                              3,
                              isWide: true,
                            ),
                            _buildNavItem(
                              Icons.settings_rounded,
                              Icons.settings_outlined,
                              '설정',
                              4,
                              isWide: true,
                            ),
                          ]
                        : [
                            _buildNavItem(
                              Icons.edit_document,
                              Icons.edit_outlined,
                              '입력',
                              0,
                              isWide: false,
                            ),
                            _buildNavItem(
                              Icons.format_list_numbered_rounded,
                              Icons.format_list_numbered_rtl_outlined,
                              '마킹',
                              1,
                              isWide: false,
                            ),
                            _buildNavItem(
                              Icons.folder_rounded,
                              Icons.folder_outlined,
                              '보관함',
                              2,
                              isWide: false,
                            ),
                            _buildNavItem(
                              Icons.architecture_rounded,
                              Icons.architecture_outlined,
                              '현장',
                              3,
                              isWide: false,
                            ),
                            _buildNavItem(
                              Icons.view_in_ar_rounded,
                              Icons.view_in_ar_outlined,
                              '아이소',
                              4,
                              isWide: false,
                            ),
                            _buildNavItem(
                              Icons.settings_rounded,
                              Icons.settings_outlined,
                              '설정',
                              5,
                              isWide: false,
                            ),
                          ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildNarrowBody() {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        const ConduitInputTab(), // 0. 입력
        const ConduitResultTab(), // 1. 마킹
        const ConduitHistoryTab(), // 2. 보관함
        LandscapeMarkingScreen(
          onCloseTab: _goToMarkingTab,
          isActive: _selectedIndex == 3,
        ), // 3. 현장
        const ConduitViewerTab(), // 4. 아이소
        const ConduitSettingsPage(), // 5. 설정
      ],
    );
  }

  Widget _buildWideBody() {
    return IndexedStack(
      index: _wideIndexFor(_selectedIndex),
      children: [
        // 🚀 넓은 화면에서는 입력과 마킹을 좌우로 나란히 - 둘 다
        // ConduitDataManager를 직접 구독하므로 왼쪽에서 입력하면
        // 오른쪽 마킹 결과가 즉시 갱신된다.
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            Expanded(flex: 5, child: ConduitInputTab()),
            VerticalDivider(width: 1, color: slate100),
            Expanded(flex: 6, child: ConduitResultTab()),
          ],
        ),
        const ConduitHistoryTab(),
        LandscapeMarkingScreen(
          onCloseTab: _goToMarkingTab,
          isActive: _selectedIndex == 3,
        ),
        const ConduitViewerTab(),
        const ConduitSettingsPage(),
      ],
    );
  }

  BottomNavigationBarItem _buildNavItem(
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
    int index, {
    required bool isWide,
  }) {
    final int currentDisplayIndex = isWide
        ? _wideIndexFor(_selectedIndex)
        : _selectedIndex;
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
}

// =========================================================
// 2. 뷰어 탭 래퍼 (데이터 연결)
// =========================================================
class ConduitViewerTab extends StatelessWidget {
  const ConduitViewerTab({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([ConduitDataManager(), globalMarkingState]),
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
        final double od = conduitOuterDiameterMm(
          (cs['conduitSize'] ?? '').toString(),
        );

        return Scaffold(
          backgroundColor: const Color(0xFF151B22),
          body: SafeArea(
            child: ConduitIsoVisualizer(
              bendList: bendList,
              totalCutLength: totalCut,
              isLightMode: false,
              bendRadius: clr,
              outerDiameter: od,
              fittingDepth: coupling,
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
class LandscapeMarkingScreen extends StatefulWidget {
  final VoidCallback? onCloseTab;
  // 🚀 [버그 수정] ConduitMainNavigation이 IndexedStack으로 바뀌면서 이
  // 화면이 실제로 보이지 않을 때도(다른 탭을 보고 있어도) 계속 마운트된
  // 상태로 남아있게 됐다. 아래 PopScope(canPop:false)가 항상 켜져 있으면
  // 다른 탭을 보고 있을 때 폰 뒤로가기를 눌러도 이 화면이 가로채서
  // "마킹 탭으로 전환"만 하고 실제로는 메인 메뉴로 못 나가지는 버그가
  // 생긴다. 이 탭이 화면에 실제로 보이고 있을 때만(isActive) 뒤로가기를
  // 가로채도록 한다. 별도 라우트로 그냥 push된 경우(예: 마킹 탭의 "가로
  // 도면 보기" 버튼)는 항상 활성 상태이므로 기본값을 true로 둔다.
  final bool isActive;

  const LandscapeMarkingScreen({
    super.key,
    this.onCloseTab,
    this.isActive = true,
  });

  @override
  State<LandscapeMarkingScreen> createState() => _LandscapeMarkingScreenState();
}

class _LandscapeMarkingScreenState extends State<LandscapeMarkingScreen> {
  final ScrollController _mainScrollController = ScrollController();
  final double mmToPixel = 2.0;
  int? _selectedIndex;

  final List<Map<String, dynamic>> _directions = [
    {"label": "UP (위)", "val": 0.0},
    {"label": "RIGHT (우)", "val": 90.0},
    {"label": "DOWN (아래)", "val": 180.0},
    {"label": "LEFT (좌)", "val": 270.0},
    {"label": "FRONT (앞)", "val": 360.0},
    {"label": "BACK (뒤)", "val": 450.0},
  ];

  String _getDirectionText(double rot) {
    return _directions
        .firstWhere(
          (d) => d['val'] == rot,
          orElse: () => {"label": "${rot.toInt()}°"},
        )['label']
        .toString()
        .split(' ')
        .first;
  }

  @override
  void initState() {
    super.initState();
    // 🚀 [버그 수정] IndexedStack이 이 탭을 항상 미리 마운트해두기 때문에,
    // 무조건 가로 고정을 걸면 "현장" 탭이 선택되지 않은 채로 전선관
    // 계산기에 처음 들어가도 앱 전체가 강제로 가로 화면이 되어버렸다.
    // 이 탭이 실제로 활성 상태일 때만 가로로 고정한다.
    if (widget.isActive) {
      _setLandscapeMode();
    }
  }

  @override
  void didUpdateWidget(covariant LandscapeMarkingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 🚀 IndexedStack 안에서 위젯이 dispose되지 않고 계속 살아있는 채로
    // 다른 탭으로 넘어갔다 돌아왔다 하므로, isActive가 바뀔 때마다
    // 화면 방향을 맞춰 전환해줘야 한다.
    if (widget.isActive && !oldWidget.isActive) {
      _setLandscapeMode();
    } else if (!widget.isActive && oldWidget.isActive) {
      _restorePortraitMode();
    }
  }

  void _setLandscapeMode() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _restorePortraitMode() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _restorePortraitMode();
    _mainScrollController.dispose();
    super.dispose();
  }

  void _handleClose(BuildContext context) {
    _restorePortraitMode();
    if (widget.onCloseTab != null) {
      widget.onCloseTab!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: globalMarkingState,
      builder: (context, data, child) {
        final totalCutLength = data['totalCutLength'] as double;
        final markings = data['markings'] as List<Map<String, dynamic>>;

        if (markings.isEmpty) {
          return PopScope(
            canPop: !widget.isActive,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop && widget.isActive) _handleClose(context);
            },
            child: Scaffold(
              backgroundColor: paperBg,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.straighten_rounded,
                      size: 64,
                      color: strokeColor.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "데이터를 입력해 주십시오",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: strokeColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "입력 탭에서 배관 형태와 길이를 추가하면 현장 도면이 생성됩니다.",
                      style: TextStyle(
                        fontSize: 14,
                        color: strokeColor.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        double contentWidth = (totalCutLength * mmToPixel) + 150;

        return PopScope(
          canPop: !widget.isActive,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && widget.isActive) _handleClose(context);
          },
          child: Scaffold(
            backgroundColor: paperBg,
            body: SafeArea(
              child: Column(
                children: [
                  _buildResponsiveOverviewBar(
                    context,
                    totalCutLength,
                    markings,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _mainScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: SizedBox(
                        width: contentWidth,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: 160,
                              left: 50,
                              right: 50,
                              height: 30,
                              child: _buildPipeBody(),
                            ),
                            Positioned(
                              top: 190,
                              left: 50,
                              child: SizedBox(
                                width: totalCutLength * mmToPixel,
                                height: 50,
                                child: CustomPaint(
                                  painter: MetricTapeMeasurePainter(mmToPixel),
                                ),
                              ),
                            ),
                            ...markings.asMap().entries.map(
                              (entry) =>
                                  _buildMarkingPoint(entry.value, entry.key),
                            ),
                            ...markings.asMap().entries.map((entry) {
                              int index = entry.key;
                              double positionMm = (entry.value['mark'] as num)
                                  .toDouble();
                              double xPos = 50 + (positionMm * mmToPixel);
                              bool isSelected = _selectedIndex == index;

                              return Positioned(
                                left: xPos,
                                top: 155,
                                height: 40,
                                child: Container(
                                  width: isSelected ? 2.5 : 1.5,
                                  color: isSelected
                                      ? highlightColor
                                      : strokeColor.withValues(alpha: 0.4),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildBottomDataTable(markings),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResponsiveOverviewBar(
    BuildContext context,
    double totalCutLength,
    List<Map<String, dynamic>> markings,
  ) {
    return Container(
      height: 60,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: strokeColor.withValues(alpha: 0.2)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double mapWidth = constraints.maxWidth - 200;
          if (mapWidth < 100) mapWidth = 100;

          return Row(
            children: [
              Text(
                "TOTAL: ${totalCutLength.toInt()}mm",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: strokeColor,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: mapWidth,
                height: 20,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 4,
                      width: mapWidth,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    ...markings.asMap().entries.map((entry) {
                      int index = entry.key;
                      Map<String, dynamic> m = entry.value;
                      double pos = (m['mark'] as num).toDouble();
                      double dotPos = totalCutLength > 0
                          ? (pos / totalCutLength) * mapWidth
                          : 0;
                      bool isSelected = _selectedIndex == index;

                      return Positioned(
                        left: dotPos - (isSelected ? 4 : 3),
                        child: Container(
                          width: isSelected ? 8 : 6,
                          height: isSelected ? 8 : 6,
                          decoration: BoxDecoration(
                            color: isSelected ? highlightColor : accentRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: strokeColor,
                  size: 28,
                ),
                onPressed: () => _handleClose(context),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPipeBody() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey[600]!, Colors.grey[300]!, Colors.grey[800]!],
        ),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: strokeColor, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 4),
        ],
      ),
    );
  }

  Widget _buildMarkingPoint(Map<String, dynamic> item, int index) {
    double positionMm = (item['mark'] as num).toDouble();
    double angle = (item['angle'] as num).toDouble();
    double rotation = (item['rotation'] as num).toDouble();
    bool isStraight = angle == 0.0;
    String title = isStraight ? "직관 연장" : "${angle.toInt()}° 벤딩";
    String rotText = _getDirectionText(rotation);

    double xPos = 50 + (positionMm * mmToPixel);
    bool isEven = index % 2 == 0;
    double topPosition = isEven ? 20 : 80;
    bool isSelected = _selectedIndex == index;

    return Positioned(
      left: xPos - 60,
      top: topPosition,
      width: 120,
      child: AnimatedScale(
        scale: isSelected ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.bottomCenter,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: strokeColor, width: 1.5),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(2, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "${positionMm.toInt()}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: strokeColor,
                    ),
                  ),
                  if (!isStraight)
                    Text(
                      "↺ $rotText",
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -4),
              child: Icon(
                Icons.arrow_drop_down,
                color: isSelected
                    ? highlightColor
                    : strokeColor.withValues(alpha: 0.7),
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomDataTable(List<Map<String, dynamic>> markings) {
    return Container(
      height: 85,
      color: tableHeaderGray,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: markings.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final m = markings[index];
          double positionMm = (m['mark'] as num).toDouble();
          bool isSelected = _selectedIndex == index;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedIndex = (_selectedIndex == index) ? null : index;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 130,
              margin: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? highlightColor.withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? highlightColor : strokeColor,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "STEP ${index + 1}",
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? highlightColor : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${positionMm.toInt()} mm",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? highlightColor : strokeColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class MetricTapeMeasurePainter extends CustomPainter {
  final double scale;
  MetricTapeMeasurePainter(this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = 1.0;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (double i = 0; i <= size.width; i += (1 * scale)) {
      double mmValue = i / scale;
      double tickHeight = 0;

      if (mmValue % 100 == 0) {
        tickHeight = 22;
        _drawText(
          canvas,
          textPainter,
          "${(mmValue / 10).toInt()}cm",
          i,
          24,
          isBold: true,
        );
      } else if (mmValue % 50 == 0) {
        tickHeight = 15;
      } else if (mmValue % 10 == 0) {
        tickHeight = 10;
      }
      if (tickHeight > 0) {
        canvas.drawLine(Offset(i, 0), Offset(i, tickHeight), paint);
      }
    }
  }

  void _drawText(
    Canvas canvas,
    TextPainter tp,
    String text,
    double x,
    double y, {
    bool isBold = false,
  }) {
    tp.text = TextSpan(
      text: text,
      style: TextStyle(
        color: strokeColor,
        fontSize: 11,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      ),
    );
    tp.layout();
    double dx = x - (tp.width / 2);
    if (dx < 0) dx = 0;
    tp.paint(canvas, Offset(dx, y));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// =========================================================
// 4. 3D 아이소 뷰어
// =========================================================
/// 전선관 3D 그림.
///
/// 🚀 [고침] 공간 걷기를 따로 한 벌 들고 있었고 모서리를 각지게 이어 붙였다.
/// 마킹 값과 같은 계산(pipeDrawPath)을 쓰고, 실제 비율로 그린다.
class ConduitIsoVisualizer extends StatefulWidget {
  final List<Map<String, dynamic>> bendList;
  final double tailLength;
  final int? selectedSegmentIndex;
  final String initialStartDir;
  final ValueChanged<String>? onStartDirChanged;
  final bool isLightMode;
  final bool startFit;
  final bool endFit;
  final double totalCutLength;

  /// 굽힘 중심선 반경(CLR). 실제 형상으로 그릴 때 모서리를 이만큼 둥글게 그린다.
  final double bendRadius;

  /// 전선관 바깥지름. 실제 형상으로 그릴 때 관 굵기를 이만큼 그린다.
  final double outerDiameter;

  /// 커플링에 관이 들어가는 깊이.
  final double fittingDepth;

  const ConduitIsoVisualizer({
    super.key,
    required this.bendList,
    this.tailLength = 0.0,
    this.selectedSegmentIndex,
    this.initialStartDir = 'RIGHT',
    this.onStartDirChanged,
    this.isLightMode = false,
    this.startFit = false,
    this.endFit = false,
    this.totalCutLength = 0.0,
    this.bendRadius = 0.0,
    this.outerDiameter = 0.0,
    this.fittingDepth = 0.0,
  });

  @override
  State<ConduitIsoVisualizer> createState() => _ConduitIsoVisualizerState();
}

class _ConduitIsoVisualizerState extends State<ConduitIsoVisualizer> {
  static const double _defaultRotX = -math.pi / 6;
  static const double _defaultRotY = -math.pi / 4;

  /// 실제 비율로 그릴지. 켜면 길이를 있는 그대로, 모서리는 반경만큼 둥글게,
  /// 관 굵기도 바깥지름대로 그린다.
  bool _realScale = true;

  double _rotationX = _defaultRotX;
  double _rotationY = _defaultRotY;
  double _zoomLevel = 1.0;
  double _baseZoom = 1.0;
  double _panX = 0.0;
  double _panY = 0.0;
  bool _isFlippedX = false;
  bool _isFlippedY = false;

  late String _startDir;

  @override
  void initState() {
    super.initState();
    _startDir = widget.initialStartDir;
    _loadSavedDirection();
  }

  Future<void> _loadSavedDirection() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDir = prefs.getString('conduit_saved_start_dir');
    if (savedDir != null && mounted) {
      setState(() {
        _startDir = savedDir;
      });
      if (widget.onStartDirChanged != null) {
        widget.onStartDirChanged!(savedDir);
      }
    }
  }

  void _resetView() {
    setState(() {
      _rotationX = _defaultRotX;
      _rotationY = _defaultRotY;
      _zoomLevel = 1.0;
      _panX = 0.0;
      _panY = 0.0;
      _isFlippedX = false;
      _isFlippedY = false;
    });
  }

  void _rotateCamera() {
    setState(() => _rotationY -= math.pi / 2);
  }

  void _toggleFlipX() {
    setState(() => _isFlippedX = !_isFlippedX);
  }

  void _toggleFlipY() {
    setState(() => _isFlippedY = !_isFlippedY);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseZoom = _zoomLevel;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      if (details.scale == 1.0) {
        _panX += details.focalPointDelta.dx;
        _panY += details.focalPointDelta.dy;
      } else {
        _zoomLevel = (_baseZoom * details.scale).clamp(0.2, 10.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onScaleStart: widget.isLightMode ? null : _onScaleStart,
          onScaleUpdate: widget.isLightMode ? null : _onScaleUpdate,
          onDoubleTap: widget.isLightMode ? null : _resetView,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: widget.isLightMode
                ? Colors.transparent
                : const Color(0xFF151B22),
            child: CustomPaint(
              painter: ConduitIsoPainter(
                bendList: widget.bendList,
                tailLength: widget.tailLength,
                rotationX: _rotationX,
                rotationY: _rotationY,
                zoomLevel: _zoomLevel,
                panX: _panX,
                panY: _panY,
                isFlippedX: _isFlippedX,
                isFlippedY: _isFlippedY,
                startDirection: _startDir,
                realScale: _realScale,
                bendRadius: widget.bendRadius,
                outerDiameter: widget.outerDiameter,
                fittingDepth: widget.fittingDepth,
                selectedSegmentIndex: widget.selectedSegmentIndex,
                isLightMode: widget.isLightMode,
                startFit: widget.startFit,
                endFit: widget.endFit,
              ),
            ),
          ),
        ),
        Positioned(top: 16, left: 16, child: _buildStartDirSelector()),
        if (widget.totalCutLength > 0)
          Positioned(top: 16, right: 16, child: _buildTotalCutBadge()),
        if (!widget.isLightMode)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B3643).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIconBtn(
                      Icons.swap_vert,
                      _isFlippedY ? Colors.redAccent : Colors.white,
                      _toggleFlipY,
                    ),
                    _buildDivider(),
                    _buildIconBtn(
                      Icons.swap_horiz,
                      _isFlippedX ? Colors.redAccent : Colors.white,
                      _toggleFlipX,
                    ),
                    _buildDivider(),
                    _buildIconBtn(
                      Icons.rotate_90_degrees_cw,
                      Colors.white,
                      _rotateCamera,
                    ),
                    _buildDivider(),
                    _buildIconBtn(
                      Icons.remove_circle_outline,
                      Colors.white70,
                      () => setState(
                        () => _zoomLevel = (_zoomLevel - 0.2).clamp(0.2, 10.0),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _buildIconBtn(
                      Icons.add_circle_outline,
                      Colors.white70,
                      () => setState(
                        () => _zoomLevel = (_zoomLevel + 0.2).clamp(0.2, 10.0),
                      ),
                    ),
                    _buildDivider(),
                    _buildIconBtn(
                      Icons.straighten,
                      _realScale ? makitaTeal : Colors.white,
                      () => setState(() => _realScale = !_realScale),
                    ),
                    _buildDivider(),
                    _buildIconBtn(Icons.refresh, makitaTeal, _resetView),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStartDirSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: widget.isLightMode
            ? Colors.white.withValues(alpha: 0.9)
            : const Color(0xFF2B3643).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
        border: Border.all(
          color: widget.isLightMode ? Colors.grey.shade300 : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "시작 방향:",
            style: TextStyle(
              fontSize: 12,
              color: widget.isLightMode ? Colors.black54 : Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _startDir,
              isDense: true,
              dropdownColor: widget.isLightMode
                  ? Colors.white
                  : const Color(0xFF2B3643),
              icon: Icon(
                Icons.arrow_drop_down,
                color: widget.isLightMode ? Colors.black87 : Colors.white,
              ),
              style: TextStyle(
                color: widget.isLightMode ? Colors.black87 : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              items: ['UP', 'DOWN', 'LEFT', 'RIGHT', 'FRONT', 'BACK']
                  .map((dir) => DropdownMenuItem(value: dir, child: Text(dir)))
                  .toList(),
              onChanged: (val) async {
                if (val != null) {
                  setState(() => _startDir = val);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('conduit_saved_start_dir', val);
                  if (widget.onStartDirChanged != null) {
                    widget.onStartDirChanged!(val);
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCutBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isLightMode
            ? Colors.white.withValues(alpha: 0.9)
            : const Color(0xFF2B3643).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
        border: Border.all(
          color: widget.isLightMode ? Colors.grey.shade300 : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.straighten, size: 14, color: makitaTeal),
          const SizedBox(width: 6),
          Text(
            "총 기장: ",
            style: TextStyle(
              fontSize: 12,
              color: widget.isLightMode ? Colors.black54 : Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "${widget.totalCutLength.round()} mm",
            style: TextStyle(
              fontSize: 13,
              color: widget.isLightMode
                  ? Colors.red.shade700
                  : Colors.redAccent,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 20,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: Colors.white24,
    );
  }
}

abstract class ConduitRenderable {
  double get z;
  void draw(
    Canvas canvas,
    Paint pipePaint,
    Paint highlightPaint,
    Paint outlinePaint,
  );
}

class ConduitFittingRenderable implements ConduitRenderable {
  final Offset p1, p2;
  @override
  final double z;
  final bool isLightMode;

  ConduitFittingRenderable(
    this.p1,
    this.p2,
    this.z, {
    this.isLightMode = false,
  });

  @override
  void draw(
    Canvas canvas,
    Paint pipePaint,
    Paint highlightPaint,
    Paint outlinePaint,
  ) {
    double sf = isLightMode ? 1.2 : 1.0;
    final fitPaint = Paint()
      ..color = isLightMode ? Colors.blueGrey.shade300 : const Color(0xFF90A4AE)
      ..strokeWidth = 14.0 * sf
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fitOutline = Paint()
      ..color = isLightMode ? Colors.black87 : Colors.black54
      ..strokeWidth = 18.0 * sf
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(p1, p2, fitOutline);
    canvas.drawLine(p1, p2, fitPaint);
  }
}

/// 이어진 여러 토막(벤드가 휘는 호)을 한 붓으로 그린다.
///
/// 🚀 [고침] 호를 토막마다 따로 그리면 검은 테두리가 앞 토막을 덮어서
/// 휜 자리가 뭉개지고 각지게 꺾인 것처럼 보였다.
class ConduitPolylineRenderable implements ConduitRenderable {
  final List<Offset> pts;
  @override
  final double z;
  final bool isSelected;

  ConduitPolylineRenderable(this.pts, this.z, {this.isSelected = false});

  @override
  void draw(
    Canvas canvas,
    Paint pipePaint,
    Paint highlightPaint,
    Paint outlinePaint,
  ) {
    if (pts.length < 2) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, outlinePaint);
    canvas.drawPath(path, isSelected ? highlightPaint : pipePaint);
    drawConduitCenterLine(canvas, path, pipePaint);
  }
}

/// 관 한가운데에 긋는 가는 선(중심선).
///
/// 🚀 [고침] 관을 바깥지름대로 굵게 그리면, 반경이 관 굵기의 서너 배밖에
/// 안 되는 튜브에서는 휘는 자리가 굵기에 묻혀 각지게 꺾인 것처럼 보였다
/// (3/8" 튜브 R38이면 호가 부푸는 양이 11mm라 관 굵기 12.7mm와 비슷하다).
/// 관 굵기는 실제대로 두고, 가운데에 가는 선을 하나 더 그어 휜 모양이
/// 드러나게 한다. 배관 도면에서 중심선을 긋는 것과 같다.
void drawConduitCenterLine(Canvas canvas, Path path, Paint pipePaint) {
  final w = pipePaint.strokeWidth;
  if (w < 8.0) return;
  canvas.drawPath(
    path,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = (w * 0.16).clamp(1.0, 3.0)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
}

class ConduitSegmentRenderable implements ConduitRenderable {
  final Offset p1, p2;
  @override
  final double z;
  final bool isSelected;
  final bool isLightMode;

  ConduitSegmentRenderable(
    this.p1,
    this.p2,
    this.z, {
    this.isSelected = false,
    this.isLightMode = false,
  });

  @override
  void draw(
    Canvas canvas,
    Paint pipePaint,
    Paint highlightPaint,
    Paint outlinePaint,
  ) {
    double sf = isLightMode ? 1.2 : 1.0;
    canvas.drawLine(p1, p2, outlinePaint);
    canvas.drawLine(p1, p2, isSelected ? highlightPaint : pipePaint);

    double dx = p2.dx - p1.dx;
    double dy = p2.dy - p1.dy;
    double length = math.sqrt(dx * dx + dy * dy);

    if (length > 15 * sf) {
      double arrowSize = 6.0 * sf;
      double lineAngle = math.atan2(dy, dx);
      Offset mid = Offset(p1.dx + dx * 0.55, p1.dy + dy * 0.55);

      Offset arrowP1 = Offset(
        mid.dx - arrowSize * math.cos(lineAngle - math.pi / 6),
        mid.dy - arrowSize * math.sin(lineAngle - math.pi / 6),
      );
      Offset arrowP2 = Offset(
        mid.dx - arrowSize * math.cos(lineAngle + math.pi / 6),
        mid.dy - arrowSize * math.sin(lineAngle + math.pi / 6),
      );

      Path arrowPath = Path()
        ..moveTo(mid.dx, mid.dy)
        ..lineTo(arrowP1.dx, arrowP1.dy)
        ..lineTo(arrowP2.dx, arrowP2.dy)
        ..close();
      Paint arrowPaint = Paint()
        ..color = isLightMode
            ? (isSelected ? Colors.black : Colors.black87)
            : (isSelected ? Colors.white : Colors.white.withValues(alpha: 0.8))
        ..style = PaintingStyle.fill;
      canvas.drawPath(arrowPath, arrowPaint);
    }
  }
}

class ConduitDashedLineRenderable implements ConduitRenderable {
  final Offset p1, p2;
  @override
  final double z;
  final bool isLightMode;

  ConduitDashedLineRenderable(
    this.p1,
    this.p2,
    this.z, {
    this.isLightMode = false,
  });

  @override
  void draw(
    Canvas canvas,
    Paint pipePaint,
    Paint highlightPaint,
    Paint outlinePaint,
  ) {
    double sf = isLightMode ? 1.2 : 1.0;
    final dashPaint = Paint()
      ..color = isLightMode
          ? Colors.orange.shade800
          : Colors.amberAccent.withValues(alpha: 0.9)
      ..strokeWidth = 2.5 * sf
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    double dx = p2.dx - p1.dx;
    double dy = p2.dy - p1.dy;
    double distance = math.sqrt(dx * dx + dy * dy);
    if (distance <= 0) return;

    double dashWidth = 10.0 * sf;
    double dashSpace = 8.0 * sf;
    double unitDx = dx / distance;
    double unitDy = dy / distance;
    double startX = p1.dx;
    double startY = p1.dy;
    double drawn = 0.0;

    while (drawn < distance) {
      double nextDraw = math.min(dashWidth, distance - drawn);
      double endX = startX + unitDx * nextDraw;
      double endY = startY + unitDy * nextDraw;
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), dashPaint);
      drawn += nextDraw + dashSpace;
      startX = endX + unitDx * dashSpace;
      startY = endY + unitDy * dashSpace;
    }

    double arrowSize = 8.0 * sf;
    double lineAngle = math.atan2(dy, dx);
    Offset arrowP1 = Offset(
      p2.dx - arrowSize * math.cos(lineAngle - math.pi / 6),
      p2.dy - arrowSize * math.sin(lineAngle - math.pi / 6),
    );
    Offset arrowP2 = Offset(
      p2.dx - arrowSize * math.cos(lineAngle + math.pi / 6),
      p2.dy - arrowSize * math.sin(lineAngle + math.pi / 6),
    );

    Path arrowPath = Path()
      ..moveTo(p2.dx, p2.dy)
      ..lineTo(arrowP1.dx, arrowP1.dy)
      ..lineTo(arrowP2.dx, arrowP2.dy)
      ..close();
    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = isLightMode ? Colors.orange.shade800 : Colors.amberAccent
        ..style = PaintingStyle.fill,
    );
  }
}

class ConduitLabelRenderable implements ConduitRenderable {
  final Offset centerPos;
  @override
  final double z;
  final String text;
  final bool isStraightPipe;
  final bool isSelected;
  final bool isLightMode;
  final bool isStartLabel;

  ConduitLabelRenderable(
    this.centerPos,
    this.z,
    this.text, {
    this.isStraightPipe = false,
    this.isSelected = false,
    this.isLightMode = false,
    this.isStartLabel = false,
  });

  @override
  void draw(
    Canvas canvas,
    Paint pipePaint,
    Paint highlightPaint,
    Paint outlinePaint,
  ) {
    double sf = isLightMode ? 1.2 : 1.0;

    Color textColor = isStartLabel
        ? (isLightMode ? Colors.red.shade800 : Colors.redAccent)
        : (isStraightPipe
              ? (isLightMode ? Colors.black87 : Colors.white70)
              : (isLightMode ? Colors.black : Colors.white));
    double baseFontSize = isStartLabel
        ? 12.0
        : (isStraightPipe ? 11.0 : (isSelected ? 20.0 : 16.0));
    double fontSize = baseFontSize * sf;

    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: textColor,
        fontSize: fontSize,
        fontWeight: isStartLabel
            ? FontWeight.w900
            : (isStraightPipe ? FontWeight.bold : FontWeight.w900),
        letterSpacing: isStartLabel ? 1.0 * sf : 0.0,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    Offset drawPos = Offset(
      centerPos.dx - (textPainter.width / 2),
      centerPos.dy - (textPainter.height / 2),
    );
    double padX = (isStraightPipe ? 4.0 : 8.0) * sf;
    double padY = (isStraightPipe ? 2.0 : 4.0) * sf;
    final rect = Rect.fromLTWH(
      drawPos.dx - padX,
      drawPos.dy - padY,
      textPainter.width + padX * 2,
      textPainter.height + padY * 2,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular((isStraightPipe ? 4.0 : 8.0) * sf),
    );

    Color bgColor = isStartLabel
        ? (isLightMode
              ? Colors.white.withValues(alpha: 0.8)
              : const Color(0xFF151B22).withValues(alpha: 0.8))
        : (isStraightPipe
              ? (isLightMode
                    ? Colors.white70
                    : Colors.grey.shade800.withValues(alpha: 0.7))
              : (isSelected
                    ? Colors.orange.shade400
                    : (isLightMode
                          ? Colors.white
                          : const Color(0xFF151B22).withValues(alpha: 0.95))));
    Color borderColor = isStartLabel
        ? (isLightMode
              ? Colors.red.shade200
              : Colors.red.shade900.withValues(alpha: 0.5))
        : (isStraightPipe
              ? Colors.grey.shade600
              : (isSelected
                    ? Colors.orange.shade800
                    : (isLightMode ? Colors.black54 : Colors.grey.shade600)));

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = bgColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = (isStraightPipe ? 1.0 : 1.5) * sf,
    );
    textPainter.paint(canvas, drawPos);
  }
}

class ConduitIsoPainter extends CustomPainter {
  final List<Map<String, dynamic>> bendList;
  final double tailLength;
  final double rotationX;
  final double rotationY;
  final double zoomLevel;
  final double panX;
  final double panY;
  final bool isFlippedX;
  final bool isFlippedY;
  final String startDirection;
  final int? selectedSegmentIndex;
  final bool isLightMode;
  final bool startFit;
  final bool endFit;

  /// 실제 비율로 그릴지.
  final bool realScale;
  final double bendRadius;
  final double outerDiameter;
  final double fittingDepth;

  ConduitIsoPainter({
    required this.bendList,
    this.tailLength = 0.0,
    required this.rotationX,
    required this.rotationY,
    required this.zoomLevel,
    required this.panX,
    required this.panY,
    required this.isFlippedX,
    required this.isFlippedY,
    required this.startDirection,
    this.selectedSegmentIndex,
    required this.isLightMode,
    required this.startFit,
    required this.endFit,
    this.realScale = false,
    this.bendRadius = 0.0,
    this.outerDiameter = 0.0,
    this.fittingDepth = 0.0,
  });

  double _getVisualLength(double realLength) {
    if (realLength <= 0) return 0.0;
    return 40.0 + math.pow(realLength, 0.5) * 6.0;
  }

  void _drawBlueprintGrid(Canvas canvas, Size size, double sf) {
    final minorPaint = Paint()
      ..color = isLightMode ? Colors.grey.shade200 : const Color(0xFF202A36)
      ..strokeWidth = 1.0 * sf;
    final majorPaint = Paint()
      ..color = isLightMode ? Colors.grey.shade300 : const Color(0xFF2C3948)
      ..strokeWidth = 1.5 * sf;
    double step = 30.0 * sf;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        i % (step * 5) == 0 ? majorPaint : minorPaint,
      );
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        i % (step * 5) == 0 ? majorPaint : minorPaint,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    double sf = isLightMode ? 1.2 : 1.0;
    _drawBlueprintGrid(canvas, size, sf);

    // 🚀 [고침] 이 그림도 공간 걷기를 따로 한 벌 들고 있었고, 모서리를
    // 각지게 이어 붙였다. 마킹 값과 같은 계산(pipeDrawPath)을 쓰고,
    // "실제 비율"을 켜면 모서리를 반경만큼 둥근 호로 그린다.
    final drawPath = pipeDrawPath(
      bendList,
      startDir: startDirection,
      radius: realScale ? bendRadius : 0.0,
      tail: tailLength,
      visualLength: realScale ? null : _getVisualLength,
    );
    final List<vmath.Vector3> pts3D = drawPath.points;
    final List<int> segOwner = drawPath.owner;

    List<int> internalMarkNums = [];
    int currentMarkNum = 1;
    for (int i = 0; i < bendList.length; i++) {
      double angle = (bendList[i]['angle'] as num?)?.toDouble() ?? 0.0;
      if (angle == 0.0) {
        internalMarkNums.add(0);
      } else {
        internalMarkNums.add(currentMarkNum);
        currentMarkNum++;
      }
    }

    vmath.Vector3 center3D = _calculateCenter(pts3D);
    double maxRadius = _calculateMaxRadius(pts3D, center3D);
    double scale =
        (math.min(size.width, size.height) * 0.4) / maxRadius * zoomLevel;

    vmath.Matrix4 cameraMatrix = vmath.Matrix4.identity()
      ..rotateX(rotationX)
      ..rotateY(rotationY);
    List<vmath.Vector3> projectedPts = [];
    for (var p in pts3D) {
      vmath.Vector3 translated = p - center3D;
      projectedPts.add(cameraMatrix.transformed3(translated));
    }

    Offset to2D(vmath.Vector3 p) {
      double finalX = isFlippedX ? -p.x : p.x;
      double finalY = isFlippedY ? -p.y : p.y;
      return Offset(
        finalX * scale + size.width / 2 + panX,
        -finalY * scale + size.height / 2 + panY,
      );
    }

    // 실제 비율이면 관 굵기를 바깥지름대로 그린다.
    final double pipeWidth = (realScale && outerDiameter > 0)
        ? (outerDiameter * scale).clamp(3.0, 40.0)
        : 6.0 * sf;

    List<ConduitRenderable> renderQueue = [];
    List<ConduitLabelRenderable> labelQueue = [];

    int pipeEndIndex = projectedPts.length - 1;

    // 🚀 [고침] 이어진 호 토막을 한 덩어리로 묶어 한 붓으로 그린다.
    int i = 0;
    while (i < pipeEndIndex) {
      final int owner = i < segOwner.length ? segOwner[i] : -1;

      if (owner < 0) {
        int j = i;
        while (j < pipeEndIndex &&
            (j < segOwner.length ? segOwner[j] : -1) < 0) {
          j++;
        }
        final pts = <Offset>[
          for (int k = i; k <= j; k++) to2D(projectedPts[k]),
        ];
        var zSum = 0.0;
        for (int k = i; k <= j; k++) {
          zSum += projectedPts[k].z;
        }
        renderQueue.add(ConduitPolylineRenderable(pts, zSum / (j - i + 1)));
        i = j;
        continue;
      }

      renderQueue.add(
        ConduitSegmentRenderable(
          to2D(projectedPts[i]),
          to2D(projectedPts[i + 1]),
          (projectedPts[i].z + projectedPts[i + 1].z) / 2,
          isSelected: selectedSegmentIndex == owner,
          isLightMode: isLightMode,
        ),
      );
      i++;
    }

    // 글자는 곧은 토막마다 한 번씩만. 겹치면 바깥으로 밀어낸다.
    for (final run in drawPath.straightRuns) {
      final idx = run.bendIndex;
      if (idx < 0 || idx >= bendList.length) continue;
      final double realL = (bendList[idx]['length'] as num?)?.toDouble() ?? 0.0;
      if (realL <= 0) continue;
      final double angle = (bendList[idx]['angle'] as num?)?.toDouble() ?? 0.0;
      final int mNum = internalMarkNums[idx];
      final bool isSelected = selectedSegmentIndex == idx;

      final pa = cameraMatrix.transformed3(run.a - center3D);
      final pb = cameraMatrix.transformed3(run.b - center3D);
      final a2 = to2D(pa);
      final b2 = to2D(pb);
      final zAvg = (pa.z + pb.z) / 2;

      final mid = (a2 + b2) / 2;
      final dx = b2.dx - a2.dx;
      final dy = b2.dy - a2.dy;
      final len = math.sqrt(dx * dx + dy * dy);
      Offset normal = len > 0
          ? Offset(-dy / len, dx / len)
          : const Offset(0, -1);
      if (normal.dy > 0) normal = Offset(-normal.dx, -normal.dy);
      var labelPos = mid + normal * (18.0 * sf);
      for (var push = 0; push < 6; push++) {
        final tooClose = labelQueue.any(
          (l) => (l.centerPos - labelPos).distance < 34.0 * sf,
        );
        if (!tooClose) break;
        labelPos = labelPos + normal * (20.0 * sf);
      }

      labelQueue.add(
        ConduitLabelRenderable(
          labelPos,
          zAvg,
          angle == 0.0 ? "L:${realL.toInt()}" : "$mNum",
          isStraightPipe: angle == 0.0,
          isSelected: isSelected,
          isLightMode: isLightMode,
        ),
      );
    }

    final double minOnScreen = 14.0 / scale;
    final double fitVisualLen = (realScale && fittingDepth > 0)
        ? math.max(fittingDepth, minOnScreen)
        : 20.0;
    if (pts3D.length > 1) {
      if (startFit) {
        vmath.Vector3 dir = (pts3D[1] - pts3D[0])..normalize();
        vmath.Vector3 fitEnd =
            pts3D[0] +
            dir * math.min(fitVisualLen, pts3D[0].distanceTo(pts3D[1]));
        vmath.Vector3 projStart = cameraMatrix.transformed3(
          pts3D[0] - center3D,
        );
        vmath.Vector3 projEnd = cameraMatrix.transformed3(fitEnd - center3D);
        renderQueue.add(
          ConduitFittingRenderable(
            to2D(projStart),
            to2D(projEnd),
            ((projStart.z + projEnd.z) / 2) - 0.1,
            isLightMode: isLightMode,
          ),
        );
      }
      if (endFit) {
        int last = pipeEndIndex;
        vmath.Vector3 dir = (pts3D[last - 1] - pts3D[last])..normalize();
        vmath.Vector3 fitEnd =
            pts3D[last] +
            dir *
                math.min(fitVisualLen, pts3D[last].distanceTo(pts3D[last - 1]));
        vmath.Vector3 projStart = cameraMatrix.transformed3(
          pts3D[last] - center3D,
        );
        vmath.Vector3 projEnd = cameraMatrix.transformed3(fitEnd - center3D);
        renderQueue.add(
          ConduitFittingRenderable(
            to2D(projStart),
            to2D(projEnd),
            ((projStart.z + projEnd.z) / 2) - 0.1,
            isLightMode: isLightMode,
          ),
        );
      }
    }

    for (int i = 0; i <= pipeEndIndex; i++) {
      if (i == 0) {
        Offset nodePos = to2D(projectedPts[i]);
        labelQueue.add(
          ConduitLabelRenderable(
            nodePos + Offset(0, -30.0 * sf),
            projectedPts[i].z - 0.1,
            "START",
            isStartLabel: true,
            isLightMode: isLightMode,
          ),
        );
      }
    }

    vmath.Vector3 translatedEnd =
        (pathEndPoint(pts3D) + pathEndDirection(pts3D) * (150.0 / scale)) -
        center3D;
    vmath.Vector3 pEndDir = cameraMatrix.transformed3(translatedEnd);
    Offset pEndDir2D = to2D(pEndDir);
    Offset pCurrentPos2D = to2D(projectedPts.last);
    double zAvgDir = (projectedPts.last.z + pEndDir.z) / 2;

    renderQueue.add(
      ConduitDashedLineRenderable(
        pCurrentPos2D,
        pEndDir2D,
        zAvgDir,
        isLightMode: isLightMode,
      ),
    );

    renderQueue.sort((a, b) => b.z.compareTo(a.z));
    labelQueue.sort((a, b) => b.z.compareTo(a.z));

    final pipePaint = Paint()
      ..color = isLightMode ? const Color(0xFF455A64) : const Color(0xFF607D8B)
      ..strokeWidth = pipeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final highlightPaint = Paint()
      ..color = Colors.orange.shade500
      ..strokeWidth = pipeWidth + 2.0 * sf
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final outlinePaint = Paint()
      ..color = isLightMode ? Colors.black87 : Colors.black45
      ..strokeWidth = pipeWidth + 2.0 * sf
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    _drawAxisGuide(canvas, cameraMatrix, to2D, scale, sf);
    for (var item in renderQueue) {
      item.draw(canvas, pipePaint, highlightPaint, outlinePaint);
    }
    for (var label in labelQueue) {
      label.draw(canvas, pipePaint, highlightPaint, outlinePaint);
    }
  }

  vmath.Vector3 _calculateCenter(List<vmath.Vector3> pts) {
    double minX = double.infinity,
        maxX = -double.infinity,
        minY = double.infinity,
        maxY = -double.infinity,
        minZ = double.infinity,
        maxZ = -double.infinity;
    for (var p in pts) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
      if (p.z < minZ) minZ = p.z;
      if (p.z > maxZ) maxZ = p.z;
    }
    return vmath.Vector3(
      (minX + maxX) / 2,
      (minY + maxY) / 2,
      (minZ + maxZ) / 2,
    );
  }

  double _calculateMaxRadius(List<vmath.Vector3> pts, vmath.Vector3 center) {
    double maxRadius = 10.0;
    for (var p in pts) {
      double dist = p.distanceTo(center);
      if (dist > maxRadius) maxRadius = dist;
    }
    return maxRadius;
  }

  void _drawAxisGuide(
    Canvas canvas,
    vmath.Matrix4 camMatrix,
    Offset Function(vmath.Vector3) to2D,
    double scale,
    double sf,
  ) {
    double axLen = (40.0 / scale) * sf;
    List<vmath.Vector3> axes = [
      vmath.Vector3(axLen, 0, 0),
      vmath.Vector3(0, axLen, 0),
      vmath.Vector3(0, 0, axLen),
    ];
    List<Color> axColors = [
      const Color(0xFF81C784),
      const Color(0xFFE57373),
      const Color(0xFF64B5F6),
    ];
    vmath.Vector3 originCenter = vmath.Vector3(-axLen * 2, -axLen * 2, 0);
    vmath.Vector3 projOrigin = camMatrix.transformed3(originCenter);
    for (int i = 0; i < 3; i++) {
      vmath.Vector3 endDir = camMatrix.transformed3(originCenter + axes[i]);
      canvas.drawLine(
        to2D(projOrigin),
        to2D(endDir),
        Paint()
          ..color = axColors[i].withValues(alpha: 0.8)
          ..strokeWidth = 2.0 * sf,
      );
    }
  }

  // 🚀 [버그 수정] bendList는 in-place로 add/removeAt/원소 교체되는 같은
  // List라서, 참조 비교(!=)로는 벤딩을 추가/삭제/수정해도 "안 바뀜"으로
  // 판정돼 3D 배관 형상이 예전 상태로 멈춰 있었다. 길이 + 각 원소(맵)
  // 참조를 순서대로 비교해 실제 변경만 감지한다.
  bool _bendListChanged(
    List<Map<String, dynamic>> oldList,
    List<Map<String, dynamic>> newList,
  ) {
    if (oldList.length != newList.length) return true;
    for (int i = 0; i < newList.length; i++) {
      if (oldList[i] != newList[i]) return true;
    }
    return false;
  }

  @override
  bool shouldRepaint(covariant ConduitIsoPainter oldDelegate) {
    return oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationY != rotationY ||
        oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.panX != panX ||
        oldDelegate.panY != panY ||
        _bendListChanged(oldDelegate.bendList, bendList) ||
        oldDelegate.isFlippedX != isFlippedX ||
        oldDelegate.isFlippedY != isFlippedY ||
        oldDelegate.startDirection != startDirection ||
        oldDelegate.selectedSegmentIndex != selectedSegmentIndex ||
        oldDelegate.isLightMode != isLightMode ||
        oldDelegate.startFit != startFit ||
        oldDelegate.endFit != endFit ||
        oldDelegate.realScale != realScale ||
        oldDelegate.bendRadius != bendRadius ||
        oldDelegate.outerDiameter != outerDiameter ||
        oldDelegate.fittingDepth != fittingDepth;
  }
}
