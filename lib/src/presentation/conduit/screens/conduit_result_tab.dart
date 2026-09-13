import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 🚀 매니저 임포트: 전선관 전용 매니저
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'package:tubing_calculator/src/presentation/conduit/screens/conduit_viewer_tab.dart';
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

  bool _useCoupling = false;

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
  double _calculateGainForAngle(double angle, double gain90) {
    if (angle <= 0 || gain90 <= 0) return 0.0;
    // 부동소수점 오차 방지: 90도 근처면 정확히 90도 게인 반환
    if ((angle - 90.0).abs() < 0.1) return gain90;

    // 기하학적 배관 절약분 이론 공식에 따른 각도별 비례 연산
    // Gain(θ) / Gain(90) = [2 * tan(θ/2) - (π * θ / 180)] / [2 - π/2]
    double radHalf = (angle / 2.0) * (math.pi / 180.0);
    double radFull = angle * (math.pi / 180.0);
    double numerator = 2.0 * math.tan(radHalf) - radFull;
    double denominator = 2.0 - (math.pi / 2.0); // 약 0.42920367

    if (denominator == 0) return 0.0;
    return gain90 * (numerator / denominator);
  }

  // ==========================================
  // 🚀 [라우터] 설정값에 따라 계산기 분리
  // ==========================================
  List<Map<String, dynamic>> _calculateMarkings(
    List<Map<String, dynamic>> bendList,
    Map<String, dynamic> settings,
  ) {
    String benderType = settings['benderType'] ?? 'hand';

    if (benderType == 'ram') {
      return _calculateRamMarkings(bendList, settings);
    } else if (benderType == 'chicago') {
      return _calculateChicagoMarkings(bendList, settings);
    } else {
      return _calculateHandMarkings(bendList, settings);
    }
  }

  // ------------------------------------------
  // 🧮 1. 수동 벤더(Hand) - TakeUp & Gain 보정
  // ------------------------------------------
  List<Map<String, dynamic>> _calculateHandMarkings(
    List<Map<String, dynamic>> bendList,
    Map<String, dynamic> settings,
  ) {
    List<Map<String, dynamic>> markings = [];
    double currentTapeMark = 0.0;

    double takeUp = settings['takeUp'] ?? 152.0;
    double couplingDepth = settings['couplingDepth'] ?? 20.0;
    bool applySpringback = settings['applySpringback'] ?? true;
    double springbackVal = settings['springback'] ?? 3.0;

    for (int i = 0; i < bendList.length; i++) {
      var bend = bendList[i];
      double len = (bend['length'] as num).toDouble();
      double angle = (bend['angle'] as num).toDouble();

      // 스프링백 보정
      double targetAngle = angle;
      if (applySpringback && angle > 0) {
        targetAngle += springbackVal;
      }

      bool isFirst = (i == 0);
      String note = '';
      double offset = len;

      // 줄자 마킹 위치 계산 (총 자재 길이와 무관한 화살표 마킹 전용)
      if (isFirst) {
        if (angle > 0) {
          offset -= takeUp;
          note += '테이크업(-${takeUp.round()}mm) ';
        }
        if (_useCoupling) {
          offset -= couplingDepth;
          note += '커플링(-${couplingDepth.round()}mm) ';
        }
        if (note.isEmpty) {
          note = angle == 0.0 ? '직관 시작' : '첫 벤딩점';
        }
        currentTapeMark = offset;
      } else {
        double gap = len;
        currentTapeMark += gap;
        offset = gap;
        note = angle == 0.0 ? '직관 연장' : '간격 누적 (+${gap.round()}mm)';
      }

      markings.add({
        ...bend,
        'mark': currentTapeMark,
        'gap': offset,
        'note': note.trim(),
        'benderType': 'hand',
        'targetAngle': targetAngle,
      });
    }
    return markings;
  }

  // ------------------------------------------
  // 🧮 2. 유압식(Ram) - 3점 벤딩 비선형 공식 적용
  // ------------------------------------------
  List<Map<String, dynamic>> _calculateRamMarkings(
    List<Map<String, dynamic>> bendList,
    Map<String, dynamic> settings,
  ) {
    List<Map<String, dynamic>> markings = [];
    double currentTapeMark = 0.0;

    double setback = settings['setback'] ?? 0.0;
    double baseRamTravel = settings['ramTravel'] ?? 0.0;
    double couplingDepth = settings['couplingDepth'] ?? 20.0;
    bool applySpringback = settings['applySpringback'] ?? true;
    double springbackVal = settings['springback'] ?? 3.0;

    for (int i = 0; i < bendList.length; i++) {
      var bend = bendList[i];
      double len = (bend['length'] as num).toDouble();
      double angle = (bend['angle'] as num).toDouble();

      double targetAngle = angle;
      if (applySpringback && angle > 0) {
        targetAngle += springbackVal;
      }

      bool isFirst = (i == 0);
      String note = '';
      double offset = len;

      // 🚀 [보정] 유압 실린더 비선형 삼각함수 이동 거리 연산: Stroke ∝ sin(θ / 2)
      double ramTravelForBend = 0.0;
      if (angle > 0 && baseRamTravel > 0) {
        double radTargetHalf = (targetAngle / 2.0) * (math.pi / 180.0);
        double rad45 = 45.0 * (math.pi / 180.0);
        ramTravelForBend =
            baseRamTravel * (math.sin(radTargetHalf) / math.sin(rad45));
      }

      if (isFirst) {
        if (angle > 0) {
          offset -= setback;
          note += '셋백(-${setback.round()}mm) ';
        }
        if (_useCoupling) {
          offset -= couplingDepth;
          note += '커플링(-${couplingDepth.round()}mm) ';
        }
        if (note.isEmpty) {
          note = angle == 0.0 ? '직관 시작' : '첫 벤딩점';
        }
        currentTapeMark = offset;
      } else {
        double gap = len;
        currentTapeMark += gap;
        offset = gap;
        note = angle == 0.0 ? '직관 연장' : '간격 누적 (+${gap.round()}mm)';
      }

      markings.add({
        ...bend,
        'mark': currentTapeMark,
        'gap': offset,
        'note': note.trim(),
        'benderType': 'ram',
        'ramTravel': ramTravelForBend,
        'targetAngle': targetAngle,
      });
    }
    return markings;
  }

  // ------------------------------------------
  // 🧮 3. 시카고식(Chicago) - 반올림 보정
  // ------------------------------------------
  List<Map<String, dynamic>> _calculateChicagoMarkings(
    List<Map<String, dynamic>> bendList,
    Map<String, dynamic> settings,
  ) {
    List<Map<String, dynamic>> markings = [];
    double currentTapeMark = 0.0;

    double couplingDepth = settings['couplingDepth'] ?? 20.0;
    double degPerNotch = settings['degPerNotch'] ?? 2.5;
    double takeUp = settings['takeUp'] ?? 0.0;
    bool applySpringback = settings['applySpringback'] ?? true;
    double springbackVal = settings['springback'] ?? 3.0;

    for (int i = 0; i < bendList.length; i++) {
      var bend = bendList[i];
      double len = (bend['length'] as num).toDouble();
      double angle = (bend['angle'] as num).toDouble();

      double targetAngle = angle;
      if (applySpringback && angle > 0) {
        targetAngle += springbackVal;
      }

      bool isFirst = (i == 0);
      String note = '';
      double offset = len;

      // 🚀 [보정] 과도한 꺾임(Over-bending) 방지를 위해 ceil 대신 round 적용
      int notches = angle > 0 ? (targetAngle / degPerNotch).round() : 0;

      if (isFirst) {
        // 🚀 [버그 수정] 시카고식도 슈에 감아 구부리는 구조라 수동 벤더의
        // 테이크업과 동일한 여유 길이 차감이 필요함 (이전엔 누락되어 있었음).
        if (angle > 0) {
          offset -= takeUp;
          note += '테이크업(-${takeUp.round()}mm) ';
        }
        if (_useCoupling) {
          offset -= couplingDepth;
          note += '커플링(-${couplingDepth.round()}mm) ';
        }
        if (note.isEmpty) {
          note = angle == 0.0 ? '직관 시작' : '첫 벤딩점';
        }
        currentTapeMark = offset;
      } else {
        double gap = len;
        currentTapeMark += gap;
        offset = gap;
        note = angle == 0.0 ? '직관 연장' : '간격 누적 (+${gap.round()}mm)';
      }

      markings.add({
        ...bend,
        'mark': currentTapeMark,
        'gap': offset,
        'note': note.trim(),
        'benderType': 'chicago',
        'notches': notches,
        'targetAngle': targetAngle,
      });
    }
    return markings;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return AnimatedBuilder(
      animation: Listenable.merge([ConduitDataManager(), globalBenderSettings]),
      builder: (context, child) {
        final manager = ConduitDataManager();
        final bendList = manager.bendList;
        final currentSettings = globalBenderSettings.value;

        final double bladeKerf = currentSettings['bladeKerf'] ?? 0.0;
        final String benderType = currentSettings['benderType'] ?? 'hand';
        final double gain90 = currentSettings['gain'] ?? 0.0;

        final markings = _calculateMarkings(bendList, currentSettings);

        // 🚀 [핵심 보정] 총 절단 길이 독립 연산 (테이크업 이중 차감 원천 차단)
        double totalLengthSum = 0.0;
        double totalGainDeduction = 0.0;
        for (var bend in bendList) {
          double len = (bend['length'] as num).toDouble();
          double angle = (bend['angle'] as num).toDouble();
          totalLengthSum += len;
          if (angle > 0) {
            totalGainDeduction += _calculateGainForAngle(angle, gain90);
          }
        }

        double kerfAdjustment = bendList.isEmpty ? 0.0 : bladeKerf;

        // 총 원자재 절단 길이 = (모든 구간 설계 길이 합) - (각도별 총 게인 합) + (톱날 손실)
        double totalCut = bendList.isEmpty
            ? 0.0
            : (totalLengthSum - totalGainDeduction + kerfAdjustment);

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
                                builder: (_) => const LandscapeMarkingScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
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
              label: "실린더 푸시량:",
              valueText: ramTravel > 0
                  ? "${ramTravel.toStringAsFixed(1)} mm"
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
                            Icons.info_outline_rounded,
                            size: 14,
                            color: isStraight ? slate600 : themeColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              note,
                              style: TextStyle(
                                color: isStraight ? slate600 : themeColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (extraWidget != null) extraWidget,
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
