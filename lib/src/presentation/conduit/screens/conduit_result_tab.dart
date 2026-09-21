import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/bend_warning_banner.dart';

// 🚀 매니저 임포트: 전선관 전용 매니저
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_field_data.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking_screen.dart';
import 'package:tubing_calculator/src/presentation/field/marking_sheet_pdf.dart';
import 'package:tubing_calculator/src/presentation/conduit/conduit_marking_logic.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_settings_page.dart';

final ValueNotifier<Map<String, dynamic>> globalMarkingState = ValueNotifier({
  'totalCutLength': 0.0,
  'markings': <Map<String, dynamic>>[],
});

// 🎨 색상 테마 정의
const Color makitaTeal = Color(0xFF007580); // 수동
const Color ramBlue = Colors.blueAccent; // 유압식
const Color chicagoPurple = Colors.deepPurple; // 시카고식

const Color slate900 = Color(0xFF0F172A);
const Color slate800 = Color(0xFF1E293B);
const Color slate600 = Color(0xFF475569);
const Color slate400 = Color(0xFF94A3B8);
const Color slate200 = Color(0xFFE2E8F0);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class ConduitResultTab extends StatefulWidget {
  const ConduitResultTab({super.key});

  @override
  State<ConduitResultTab> createState() => _ConduitResultTabState();
}

class _ConduitResultTabState extends State<ConduitResultTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // 커플링 체결 여부와 시작 방향은 현장 탭과 같이 쓴다(conduit_field_data.dart).
  bool get _useCoupling => conduitUseCoupling.value;
  set _useCoupling(bool v) => conduitUseCoupling.value = v;

  @override
  void initState() {
    super.initState();
    loadConduitStartDir();
  }

  final List<Map<String, dynamic>> _directions = [
    {"label": "UP (위)", "val": 0.0, "icon": Icons.arrow_upward},
    {"label": "RIGHT (우)", "val": 90.0, "icon": Icons.arrow_forward},
    {"label": "DOWN (아래)", "val": 180.0, "icon": Icons.arrow_downward},
    {"label": "LEFT (좌)", "val": 270.0, "icon": Icons.arrow_back},
    {"label": "FRONT (앞)", "val": 360.0, "icon": Icons.call_made},
    {"label": "BACK (뒤)", "val": 450.0, "icon": Icons.call_received},
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

  // ==========================================
  // 📐 [수학 알고리즘 보정] 임의 각도 게인(Gain) 연산
  // ==========================================
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return AnimatedBuilder(
      animation: Listenable.merge([
        ConduitDataManager(),
        globalBenderSettings,
        conduitUseCoupling,
        conduitStartDir,
      ]),
      builder: (context, child) {
        final manager = ConduitDataManager();
        final bendList = manager.bendList;
        final currentSettings = globalBenderSettings.value;

        final String benderType = currentSettings['benderType'] ?? 'hand';

        final markings = calculateConduitMarkings(
          bendList,
          currentSettings,
          useCoupling: _useCoupling,
        );
        // 🚀 [추가] 튜브 마킹 화면처럼 만들 수 없는 형상이면 값 위에 띠를 띄운다.
        final check = conduitBendCheck(
          bendList,
          currentSettings,
          startDir: conduitStartDir.value,
        );

        // 총 절단 길이 = 구간 길이 합 − 각도별 게인 합 + 톱날 두께(현장 탭과 같은 셈).
        final double totalCut = conduitTotalCut(bendList, currentSettings);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          globalMarkingState.value = {
            'totalCutLength': totalCut,
            'markings': markings,
          };
        });

        // 🚀 [수정] 폴더블 대응으로 넓은 화면에서 입력 탭과 나란히 붙여
        // 보여줄 수 있도록, 자체 Scaffold 대신 배경색만 칠하는 ColoredBox로
        // 바꿨다. SliverAppBar는 Scaffold 없이 CustomScrollView 안에서도
        // 그대로 동작한다.
        return ColoredBox(
          color: slate100,
          child: SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: slate100,
                  elevation: 0,
                  systemOverlayStyle: SystemUiOverlayStyle.dark,
                  title: const Text(
                    "마킹 가이드",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: slate900,
                    ),
                  ),
                  centerTitle: false,
                  actions: [
                    if (markings.isNotEmpty)
                      IconButton(
                        key: const Key('conduit_marking_sheet'),
                        icon: const Icon(
                          Icons.picture_as_pdf_outlined,
                          color: slate900,
                        ),
                        tooltip: "마킹지(PDF)",
                        onPressed: () => openMarkingSheet(
                          context,
                          title: "전선관 벤딩 마킹지",
                          fileBase: "전선관_마킹지",
                          data: computeConduitFieldData(),
                          specs: conduitMarkingSheetSpecs(currentSettings),
                          inputs: bendList,
                        ),
                      ),
                    if (markings.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: IconButton(
                          icon: const Icon(
                            Icons.screen_rotation_rounded,
                            color: slate900,
                          ),
                          tooltip: "가로 도면 보기",
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FieldMarkingScreen(
                                  listenable: conduitFieldListenable(),
                                  compute: computeConduitFieldData,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: BendWarningBanner(warnings: check.warnings),
                ),
                SliverToBoxAdapter(
                  child: markings.isEmpty
                      ? const SizedBox.shrink()
                      : (benderType == 'ram'
                            ? _buildRamDashboard(totalCut, currentSettings)
                            : benderType == 'chicago'
                            ? _buildChicagoDashboard(totalCut, currentSettings)
                            : _buildHandDashboard(totalCut, currentSettings)),
                ),
                markings.isEmpty
                    ? SliverFillRemaining(child: _buildEmptyState())
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            var item = markings[index];
                            if (item['benderType'] == 'ram') {
                              return _buildRamMarkingCard(index, item);
                            } else if (item['benderType'] == 'chicago') {
                              return _buildChicagoMarkingCard(index, item);
                            } else {
                              return _buildHandMarkingCard(index, item);
                            }
                          }, childCount: markings.length),
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // 🎨 1. 수동 벤더(Hand) UI 위젯
  // ==========================================
  Widget _buildHandDashboard(double totalCut, Map<String, dynamic> settings) {
    return _buildBaseDashboard(
      totalCut: totalCut,
      title: "총 절단 길이 (수동 벤더)",
      icon: Icons.content_cut_rounded,
      themeColor: makitaTeal,
      deductionLabel: "설정된 테이크업",
      deductionValue: settings['takeUp'] ?? 0.0,
      couplingDepth: settings['couplingDepth'] ?? 20.0,
    );
  }

  Widget _buildHandMarkingCard(int index, Map<String, dynamic> item) {
    return _buildBaseMarkingCard(
      index: index,
      item: item,
      themeColor: makitaTeal,
    );
  }

  // ==========================================
  // 🎨 2. 유압식(Ram) UI 위젯
  // ==========================================
  Widget _buildRamDashboard(double totalCut, Map<String, dynamic> settings) {
    return _buildBaseDashboard(
      totalCut: totalCut,
      title: "총 절단 길이 (유압식)",
      icon: Icons.vertical_align_top_rounded,
      themeColor: ramBlue,
      deductionLabel: "설정된 셋백(Setback)",
      deductionValue: settings['setback'] ?? 0.0,
      couplingDepth: settings['couplingDepth'] ?? 20.0,
    );
  }

  Widget _buildRamMarkingCard(int index, Map<String, dynamic> item) {
    double ramTravel = (item['ramTravel'] as num?)?.toDouble() ?? 0.0;
    bool isStraight = (item['angle'] as num).toDouble() == 0.0;

    return _buildBaseMarkingCard(
      index: index,
      item: item,
      themeColor: ramBlue,
      extraWidget: (!isStraight)
          ? _buildExtraInfoBox(
              icon: Icons.vertical_align_top_rounded,
              // 🚀 [고침] 유압 램은 관 굵기·받침 간격에 따라 실제로 밀어야 하는
              // 양이 달라진다. 이 값은 sin(각/2) 비율로 잡은 어림값이므로,
              // 값 옆에 어림값이라고 적어 한 번 재 보고 쓰게 한다.
              label: "실린더 푸시량(어림):",
              valueText: ramTravel > 0
                  ? "${ramTravel.toStringAsFixed(1)} mm · 첫 개는 재 보십시오"
                  : "설정 입력 필요",
              themeColor: ramBlue,
            )
          : null,
    );
  }

  // ==========================================
  // 🎨 3. 시카고식(Chicago) UI 위젯
  // ==========================================
  Widget _buildChicagoDashboard(
    double totalCut,
    Map<String, dynamic> settings,
  ) {
    return _buildBaseDashboard(
      totalCut: totalCut,
      title: "총 절단 길이 (시카고식)",
      icon: Icons.settings_backup_restore_rounded,
      themeColor: chicagoPurple,
      deductionLabel: "설정된 테이크업",
      deductionValue: settings['takeUp'] ?? 0.0,
      couplingDepth: settings['couplingDepth'] ?? 20.0,
    );
  }

  Widget _buildChicagoMarkingCard(int index, Map<String, dynamic> item) {
    int notches = item['notches'] ?? 0;
    bool isStraight = (item['angle'] as num).toDouble() == 0.0;

    return _buildBaseMarkingCard(
      index: index,
      item: item,
      themeColor: chicagoPurple,
      extraWidget: (!isStraight)
          ? _buildExtraInfoBox(
              icon: Icons.grid_goldenratio_rounded,
              label: "기어/노치 진행:",
              valueText: notches > 0 ? "$notches 칸 이동" : "설정 입력 필요",
              themeColor: chicagoPurple,
            )
          : null,
    );
  }

  // ==========================================
  // 🧱 공통 UI 빌더
  // ==========================================
  Widget _buildBaseDashboard({
    required double totalCut,
    required String title,
    required IconData icon,
    required Color themeColor,
    required String deductionLabel,
    required double deductionValue,
    required double couplingDepth,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: slate900.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: themeColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: pureWhite, size: 12),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: themeColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                "${totalCut.round()}",
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: slate900,
                  letterSpacing: -1,
                  height: 1.0,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                "mm",
                style: TextStyle(
                  fontSize: 14,
                  color: slate600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: slate200),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deductionLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: slate600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${deductionValue.round()} mm",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: slate900,
                    ),
                  ),
                ],
              ),
              Container(width: 1, height: 24, color: slate200),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "커플링 (깊이 ${couplingDepth.round()}mm)",
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: slate600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildToggleBtn(
                        title: "미체결",
                        isSelected: !_useCoupling,
                        themeColor: themeColor,
                        onTap: () => setState(() => _useCoupling = false),
                      ),
                      const SizedBox(width: 4),
                      _buildToggleBtn(
                        title: "체결",
                        isSelected: _useCoupling,
                        themeColor: themeColor,
                        onTap: () => setState(() => _useCoupling = true),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBaseMarkingCard({
    required int index,
    required Map<String, dynamic> item,
    required Color themeColor,
    Widget? extraWidget,
  }) {
    double angle = (item['angle'] as num).toDouble();
    double targetAngle = (item['targetAngle'] as num?)?.toDouble() ?? angle;
    double rotation = (item['rotation'] as num).toDouble();
    double mark = (item['mark'] as num).toDouble();
    String note = item['note']?.toString() ?? '';
    bool isStraight = angle == 0.0;
    // 앞 마킹보다 뒤로 간 벤드. 그 사이 곧은 부분이 벤더에 물릴 만큼 없다.
    final bool isShort = item['short'] == true;
    final Color noteColor = isShort
        ? const Color(0xFFC77700)
        : (isStraight ? slate600 : themeColor);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isStraight ? slate200 : themeColor.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: slate900.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 60,
              decoration: BoxDecoration(
                color: isStraight ? slate200 : themeColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(15),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "STEP",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isStraight
                          ? slate400
                          : pureWhite.withValues(alpha: 0.7),
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    "${index + 1}",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: isStraight ? slate600 : pureWhite,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isStraight
                              ? "직관 연장 마킹"
                              : "${angle.toInt()}° 벤딩 (실제 ${targetAngle.toStringAsFixed(1)}°)",
                          style: const TextStyle(
                            color: slate600,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!isStraight)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: themeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: themeColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.turn_right_rounded,
                                  color: themeColor,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _getDirectionText(rotation),
                                  style: TextStyle(
                                    color: themeColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: slate100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            "${mark.round()}",
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: slate900,
                              fontFamily: 'monospace',
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            "mm",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: slate600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            isShort
                                ? Icons.warning_amber_rounded
                                : Icons.info_outline_rounded,
                            size: 14,
                            color: noteColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              note,
                              style: TextStyle(
                                color: noteColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    ?extraWidget,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtraInfoBox({
    required IconData icon,
    required String label,
    required String valueText,
    required Color themeColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: themeColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: themeColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              valueText,
              style: TextStyle(
                color: themeColor,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn({
    required String title,
    required bool isSelected,
    required Color themeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? themeColor : slate100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? themeColor : slate200),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? pureWhite : slate600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          decoration: BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: slate200, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: slate900.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: slate100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.straighten_rounded,
                  size: 40,
                  color: slate600.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "마킹 데이터가 없습니다",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: slate900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "입력 탭에서 배관 형태와 길이를 추가하면\n자동으로 장비에 맞는 마킹 가이드가 생성됩니다.",
                textAlign: TextAlign.center,
                style: TextStyle(color: slate600, height: 1.5, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
