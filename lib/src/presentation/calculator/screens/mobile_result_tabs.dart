import 'dart:convert';
import 'package:tubing_calculator/src/presentation/calculator/widgets/calc_tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/core/common_widgets/smart_save_pad.dart';
import 'package:tubing_calculator/src/core/engine/tube_bending_engine.dart';
import 'package:tubing_calculator/src/core/utils/app_settings_controller.dart';
import 'package:tubing_calculator/src/presentation/calculator/bend_check.dart';
import 'package:tubing_calculator/src/presentation/field/field_marking.dart';
import 'package:tubing_calculator/src/presentation/field/marking_sheet_pdf.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/bend_warning_banner.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/app_dialog.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/step_mark_card.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_pipe_visualizer.dart';
import 'package:tubing_calculator/src/core/database/database_helper.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/mobile_fabrication_detail_screen.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color slate50 = Color(0xFFF8FAFC);
const Color slate200 = Color(0xFFE2E8F0);
const Color _slate400 = Color(0xFF94A3B8);
const Color pureWhite = Color(0xFFFFFFFF);

/// 관 바깥지름을 mm로. 설정이 인치면 바꿔 준다.
double _odMm() {
  final s = AppSettingsController();
  return s.isInch ? s.tubeOD * 25.4 : s.tubeOD;
}

/// 마킹지(PDF)에 적을 튜브 장비 제원.
List<(String, String)> tubeMarkingSheetSpecs() {
  final s = AppSettingsController();
  final m = MobileBendDataManager();
  String n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  final size = s.isInch ? '${n(s.tubeOD)}"' : '${n(s.tubeOD)}mm';
  return [
    ("벤더", "${s.benderBrand} ${s.benderType}"),
    ("규격", size),
    ("반경 R", "${n(m.radius)} mm"),
    ("게인(90°)", "${n(m.gain90)} mm"),
    ("스프링백", "${n(m.springback)}°"),
    (
      "피팅 깊이",
      m.startFit || m.endFit
          ? "${n(m.fittingDepth)} mm (${[if (m.startFit) "시작", if (m.endFit) "끝"].join("·")})"
          : "넣지 않음",
    ),
    if (m.tail > 0) ("꼬리", "${n(m.tail)} mm"),
    if (m.benderOffset != 0) ("벤더 원점", "${n(m.benderOffset)} mm"),
    if (m.cutMargin > 0) ("톱날 손실", "${n(m.cutMargin)} mm"),
  ];
}

/// 현장 탭(가로 줄자 화면)에 넘길 마킹 자료.
/// 현장 탭이 자기 build() 안에서 직접 부른다(다른 탭의 빌드 시점에 기대면
/// 한 프레임 늦게 빈 값을 보여 주던 일이 있었다).
/// 마킹 탭과 같은 엔진·같은 점검(짧은 구간·관끼리 닿음·굴림 각도)을 쓴다.
FieldMarkingData computeTubeFieldData({String startDir = "RIGHT"}) {
  final dataManager = MobileBendDataManager();
  final bendList = dataManager.bendList;
  if (bendList.isEmpty) return FieldMarkingData.empty;

  final engine = TubeBendingEngine(
    radius: dataManager.radius,
    userGain90: dataManager.gain90,
    springbackDeg: dataManager.springback,
  );

  final List<BendInstruction> instructions = [];
  for (int i = 0; i < bendList.length; i++) {
    double l = (bendList[i]['length'] as num?)?.toDouble() ?? 0.0;
    if (i == 0 && dataManager.startFit) l += dataManager.fittingDepth;
    if (i == bendList.length - 1 && dataManager.endFit) {
      l += dataManager.fittingDepth;
    }
    instructions.add(
      BendInstruction(
        length: l,
        angle: (bendList[i]['angle'] as num?)?.toDouble() ?? 0.0,
        rotation: (bendList[i]['rotation'] as num?)?.toDouble() ?? 0.0,
      ),
    );
  }

  Map<String, dynamic> result;
  try {
    result = engine.calculate(
      instructions,
      dataManager.benderOffset,
      tail: dataManager.tail,
    );
  } catch (e) {
    return FieldMarkingData(
      totalCut: 0,
      marks: const [],
      error: e.toString().replaceFirst('Invalid argument(s): ', ''),
    );
  }

  final List<StepResult> steps = result['steps'];
  final check = checkBends(
    bendList,
    radius: dataManager.radius,
    startDir: startDir,
    tail: dataManager.tail,
    outerDiameter: _odMm(),
    engineWarnings: (result['warnings'] as List?)?.cast<String>() ?? const [],
  );

  final marks = <FieldMark>[];
  int number = 0;
  double prevBend = 0.0;
  for (int i = 0; i < bendList.length; i++) {
    final double len = (bendList[i]['length'] as num?)?.toDouble() ?? 0.0;
    final double angle = (bendList[i]['angle'] as num?)?.toDouble() ?? 0.0;
    if (angle == 0.0 && len <= 0.01) continue; // 길이 0짜리 더미 구간
    final pos = steps[i].markingPoint;
    if (angle > 0) {
      number++;
      marks.add(
        FieldMark(
          number: number,
          position: pos,
          angle: angle,
          targetAngle: steps[i].targetAngle,
          rotation: (bendList[i]['rotation'] as num?)?.toDouble() ?? 0.0,
          gap: pos - prevBend,
          roll: check.rollByIndex[i],
        ),
      );
      prevBend = pos;
    } else {
      marks.add(FieldMark(number: 0, position: pos, angle: 0, rotation: 0));
    }
  }

  // 꼬리는 엔진이 마지막 셋백을 빼고 더해 준다. 여기서는 톱날 손실만 더한다.
  final double totalCut =
      (result['totalCutLength'] as double) + dataManager.cutMargin;
  return FieldMarkingData(
    totalCut: totalCut,
    marks: marks,
    warnings: check.warnings,
  );
}

// ==========================================
// 🚀 2탭: 모바일 결과 (Result) 화면
// ==========================================
class MobileResultTab extends StatefulWidget {
  final String startDir;
  const MobileResultTab({super.key, required this.startDir});
  @override
  State<MobileResultTab> createState() => _MobileResultTabState();
}

class _MobileResultTabState extends State<MobileResultTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _includeStartFitting = false;
  bool _includeEndFitting = false;
  double _tailLength = 0.0;
  final TextEditingController _tailController = TextEditingController(
    text: "0",
  );

  @override
  void initState() {
    super.initState();
    _refreshSettings();
  }

  Future<void> _refreshSettings() async {
    final dataManager = MobileBendDataManager();
    if (mounted) {
      setState(() {
        _includeStartFitting = dataManager.startFit;
        _includeEndFitting = dataManager.endFit;
        _tailLength = dataManager.tail;
        _tailController.text = _tailLength > 0
            ? _tailLength.round().toString()
            : "0";
      });
    }
  }

  @override
  void dispose() {
    _tailController.dispose();
    super.dispose();
  }

  String _getDirectionText(double rot) {
    if (rot == 0.0) return "UP";
    if (rot == 90.0) return "RIGHT";
    if (rot == 180.0) return "DOWN";
    if (rot == 270.0) return "LEFT";
    if (rot == 360.0) return "FRONT";
    if (rot == 450.0) return "BACK";
    return "${rot.toInt()}°";
  }

  IconData _getDirectionIcon(double rot) {
    if (rot == 0.0) return Icons.arrow_upward;
    if (rot == 90.0) return Icons.arrow_forward;
    if (rot == 180.0) return Icons.arrow_downward;
    if (rot == 270.0) return Icons.arrow_back;
    if (rot == 360.0) return Icons.call_made;
    if (rot == 450.0) return Icons.call_received;
    return Icons.rotate_right;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ListenableBuilder(
      listenable: MobileBendDataManager(),
      builder: (context, child) {
        final dataManager = MobileBendDataManager();
        final bendList = dataManager.bendList;

        // 🚀 [수정] dataManager가 다른 화면(예: 저장된 도면 불러오기)에서 바뀌어도
        // 이 탭이 예전 캐시값으로 계산하지 않도록, 재빌드될 때마다 항상 최신값으로 동기화한다.
        // (Switch/입력 자체는 여전히 아래 로컬 필드를 그대로 사용하므로 동작은 동일함)
        _includeStartFitting = dataManager.startFit;
        _includeEndFitting = dataManager.endFit;
        _tailLength = dataManager.tail;

        // 🚀 버그 픽스 완료: radius 값을 온전히 가져옵니다!
        final double radius = dataManager.radius;
        final double fittingDepth = dataManager.fittingDepth;
        // 🚀 [버그 수정] springback(스프링백 보상)이 설정 화면에 저장만 되고
        // 실제 연산에는 전달되지 않던 문제를 고쳐서 엔진에 넘긴다.
        final engine = TubeBendingEngine(
          radius: radius,
          userGain90: dataManager.gain90, // 🚀 실측 연신율 엔진으로 전달!
          springbackDeg: dataManager.springback,
        );

        List<BendInstruction> instructions = [];
        for (int i = 0; i < bendList.length; i++) {
          double l = (bendList[i]['length'] as num?)?.toDouble() ?? 0.0;
          if (i == 0 && _includeStartFitting) {
            l += fittingDepth;
          }
          if (i == bendList.length - 1 && _includeEndFitting) {
            l += fittingDepth;
          }
          instructions.add(
            BendInstruction(
              length: l,
              angle: (bendList[i]['angle'] as num?)?.toDouble() ?? 0.0,
              rotation: (bendList[i]['rotation'] as num?)?.toDouble() ?? 0.0,
            ),
          );
        }

        // 🚀 [수정] 180°에 가까운 벤딩 등 엔진이 계산할 수 없는 입력이 있으면
        // 전체 탭이 빨간 에러 화면으로 크래시하는 대신, 안내 카드로 대체한다.
        Map<String, dynamic>? result;
        String? calcError;
        try {
          // 🚀 [버그 수정] "장비 원점 오프셋"도 설정에 저장만 되고 실제
          // 마킹 계산의 기준점에는 전혀 반영되지 않고 있었다.
          result = engine.calculate(
            instructions,
            dataManager.benderOffset,
            tail: _tailLength,
          );
        } catch (e) {
          calcError = e.toString();
        }

        if (calcError != null || result == null) {
          return Container(
            color: pureWhite,
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red.shade400,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "이 도면은 계산할 수 없습니다.",
                    style: TextStyle(
                      color: slate900,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    calcError ?? "알 수 없는 오류",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: slate600, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        final double pureCutLength = result['totalCutLength'];
        final List<StepResult> steps = result['steps'];

        // 관이 저희끼리 닿는지, 얼마나 굴려 물려야 하는지 같이 본다.
        final settings = AppSettingsController();
        final check = checkBends(
          bendList,
          radius: radius,
          startDir: widget.startDir,
          tail: _tailLength,
          outerDiameter: settings.isInch
              ? settings.tubeOD * 25.4
              : settings.tubeOD,
          engineWarnings:
              (result['warnings'] as List?)?.cast<String>() ?? const [],
        );
        final rolls = check.rollByIndex;

        List<Map<String, dynamic>> displayMarks = [];
        int markNumber = 1;
        double lastMarkingPoint = 0.0;
        double accumulatedIncremental = 0.0;

        for (int i = 0; i < bendList.length; i++) {
          double angleValue = (bendList[i]['angle'] as num?)?.toDouble() ?? 0.0;
          bool isStraight = angleValue == 0.0;
          double currentMark = steps[i].markingPoint;
          double currentLength =
              (bendList[i]['length'] as num?)?.toDouble() ?? 0.0;

          double appliedFit = 0.0;
          if (i == 0 && _includeStartFitting) appliedFit += fittingDepth;
          if (i == bendList.length - 1 && _includeEndFitting) {
            appliedFit += fittingDepth;
          }

          if (currentMark > lastMarkingPoint) {
            lastMarkingPoint = currentMark;
          }

          if (currentLength <= 0.01 && isStraight) {
            accumulatedIncremental += steps[i].incrementalMark;
            displayMarks.add({
              ...bendList[i],
              'is_straight': true,
              'is_hidden': true,
              'mark_num': 0,
              'marking_point': currentMark,
              'incremental_mark': 0.0,
              'applied_fit': appliedFit,
            });
            continue;
          }

          if (isStraight) {
            accumulatedIncremental += steps[i].incrementalMark;
            displayMarks.add({
              ...bendList[i],
              'is_straight': true,
              'is_hidden': false,
              'mark_num': 0,
              'marking_point': currentMark,
              'incremental_mark': 0.0,
              'applied_fit': appliedFit,
            });
          } else {
            displayMarks.add({
              ...bendList[i],
              'is_straight': false,
              'is_hidden': false,
              'mark_num': markNumber,
              'marking_point': currentMark,
              'incremental_mark':
                  steps[i].incrementalMark + accumulatedIncremental,
              'applied_fit': appliedFit,
              'target_angle': steps[i].targetAngle,
              'roll_deg': rolls[i] ?? 0.0,
            });
            markNumber++;
            accumulatedIncremental = 0.0;
          }
        }

        // 🚀 [설정값 추가] 톱날 손실(커프) 보정 - 전선관 계산기의 bladeKerf와
        // 동일하게, 원자재 절단 시 톱날 두께만큼 없어지는 길이를 더해준다.
        double totalCut = bendList.isEmpty
            ? 0.0
            : pureCutLength + dataManager.cutMargin;
        double diffAfterLastMark = (totalCut - lastMarkingPoint) - radius;

        if (diffAfterLastMark < 0) {
          diffAfterLastMark = 0;
        }

        // 🚀 [추가] 만들 수 없는 형상(앞뒤 셋백보다 짧은 구간)이면 값 대신
        // 먼저 알려 준다. 예전에는 조용히 이상한 마킹이 나왔다.
        final List<String> warnings = check.warnings;

        // 🚀 전선관 마킹 탭과 같은 짜임: 머리(고정) → 총 절단 길이 카드 →
        // STEP 카드 목록. 모양만 맞추고, 튜브에만 있는 피팅·꼬리 길이·
        // 스프링백·굴림은 그대로 보여 준다.
        return ColoredBox(
          color: slate100,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: slate100,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                systemOverlayStyle: SystemUiOverlayStyle.dark,
                title: const TitleWithTag(
                  kind: CalcKind.tube,
                  title: Text(
                    "마킹 가이드",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: slate900,
                    ),
                  ),
                ),
                centerTitle: false,
                actions: [
                  if (bendList.isNotEmpty)
                    IconButton(
                      key: const Key('tube_save_drawing'),
                      icon: const Icon(Icons.save_alt_rounded, color: slate900),
                      tooltip: "보관함에 저장",
                      onPressed: () => _handleSave(totalCut, bendList),
                    ),
                  if (bendList.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        key: const Key('tube_marking_sheet'),
                        icon: const Icon(
                          Icons.picture_as_pdf_outlined,
                          color: slate900,
                        ),
                        tooltip: "마킹지(PDF)",
                        onPressed: () => openMarkingSheet(
                          context,
                          title: "튜브 벤딩 마킹지",
                          fileBase: "튜브_마킹지",
                          data: computeTubeFieldData(startDir: widget.startDir),
                          specs: tubeMarkingSheetSpecs(),
                          inputs: bendList,
                        ),
                      ),
                    ),
                ],
              ),
              SliverToBoxAdapter(child: BendWarningBanner(warnings: warnings)),
              SliverToBoxAdapter(
                child: _buildDashboard(
                  totalCut: totalCut,
                  radius: radius,
                  fittingDepth: fittingDepth,
                  leftover: bendList.isNotEmpty ? diffAfterLastMark : 0,
                ),
              ),
              if (displayMarks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      "입력 탭에서 치수를 넣어 주십시오.",
                      style: TextStyle(
                        color: slate600.withValues(alpha: 0.8),
                        fontSize: 15,
                      ),
                    ),
                  ),
                )
              else ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Text(
                      "마킹 위치 (줄자 0점 기준)",
                      style: TextStyle(
                        color: slate600,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = displayMarks[index];
                      if (item['is_hidden'] == true) {
                        return const SizedBox.shrink();
                      }
                      return _buildMarkingCard(item);
                    }, childCount: displayMarks.length),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 총 절단 길이 카드(전선관 카드와 같은 모양).
  /// 아래 칸: 반경 | 피팅(시작·종료), 그 밑에 꼬리 길이.
  Widget _buildDashboard({
    required double totalCut,
    required double radius,
    required double fittingDepth,
    required double leftover,
  }) {
    return CutLengthCard(
      totalCut: totalCut,
      under: leftover > 0
          ? Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                "마지막 벤딩 후 잔여 +${leftover.round()}mm",
                style: const TextStyle(
                  color: slate600,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      bottom: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CardLabelValue("반경(R)", "${radius.round()} mm"),
            Container(width: 1, height: 24, color: slate200),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "피팅 (깊이 ${fittingDepth.round()}mm)",
                  style: cardLabelStyle,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildToggleBtn(
                      key: const Key('tube_start_fit'),
                      title: "시작",
                      isSelected: _includeStartFitting,
                      onTap: () => setState(() {
                        _includeStartFitting = !_includeStartFitting;
                        MobileBendDataManager().startFit = _includeStartFitting;
                      }),
                    ),
                    const SizedBox(width: 4),
                    _buildToggleBtn(
                      key: const Key('tube_end_fit'),
                      title: "종료",
                      isSelected: _includeEndFitting,
                      onTap: () => setState(() {
                        _includeEndFitting = !_includeEndFitting;
                        MobileBendDataManager().endFit = _includeEndFitting;
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        InkWell(
          key: const Key('tube_tail'),
          onTap: _showTailPad,
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              const Expanded(child: Text("꼬리 길이", style: cardLabelStyle)),
              Text("${_tailLength.round()} mm", style: cardValueStyle),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: slate600,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// STEP 카드. 번호는 벤딩에만 붙인다(현장 탭·마킹지의 "N번 마킹"과
  /// 같은 번호). 직관은 회색 띠.
  Widget _buildMarkingCard(Map<String, dynamic> item) {
    final bool isStraight = item['is_straight'] == true;
    final int incremental = (item['incremental_mark'] as num?)?.round() ?? 0;
    final int length = (item['length'] as num?)?.round() ?? 0;
    final double appliedFit = (item['applied_fit'] as num?)?.toDouble() ?? 0.0;
    final String fitText = appliedFit > 0 ? " (+피팅 ${appliedFit.round()})" : "";
    final double rotation = (item['rotation'] as num?)?.toDouble() ?? 0.0;
    final double angle = (item['angle'] as num?)?.toDouble() ?? 0.0;
    final double target = (item['target_angle'] as num?)?.toDouble() ?? angle;
    final bool hasSpringback = (target - angle).abs() > 0.05;
    // 앞 벤드와 다른 평면으로 꺾을 때 관을 굴릴 각도.
    final double rollDeg = (item['roll_deg'] as num?)?.toDouble() ?? 0.0;
    final int markNum = (item['mark_num'] as num?)?.toInt() ?? 0;

    return StepMarkCard(
      isStraight: isStraight,
      markNum: markNum,
      mark: (item['marking_point'] as num?)?.round() ?? 0,
      title: isStraight
          ? "직관 연장 마킹"
          : hasSpringback
          ? "${angle.round()}° 벤딩 (실제 ${target.toStringAsFixed(1)}°)"
          : "${angle.round()}° 벤딩",
      dirIcon: _getDirectionIcon(rotation),
      dirText: _getDirectionText(rotation),
      notes: [
        if (isStraight)
          (Icons.info_outline_rounded, "직관 +$length$fitText mm", stepNoteGrey)
        else ...[
          if (markNum > 1)
            (
              Icons.info_outline_rounded,
              "앞 마킹과의 거리 +$incremental mm",
              stepNoteTeal,
            ),
          (Icons.info_outline_rounded, "배관 $length$fitText mm", stepNoteGrey),
          if (rollDeg > 0.5)
            (
              Icons.warning_amber_rounded,
              "앞 벤드에서 ${rollDeg.round()}° 굴려 물리십시오",
              stepNoteAmber,
            ),
        ],
      ],
    );
  }

  Widget _buildToggleBtn({
    Key? key,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? makitaTeal : slate100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? makitaTeal : slate200),
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

  void _handleSave(double totalCut, List<Map<String, dynamic>> saveList) {
    HapticFeedback.mediumImpact();
    final finalSaveData = List<Map<String, dynamic>>.from(
      saveList.map((e) => Map<String, dynamic>.from(e)),
    );
    if (finalSaveData.isNotEmpty) {
      finalSaveData[0]['start_fit_applied'] = _includeStartFitting;
      finalSaveData[finalSaveData.length - 1]['end_fit_applied'] =
          _includeEndFitting;

      // 🚀 아이소 진행 방향 저장 기능 추가 적용 완료
      finalSaveData[0]['start_dir'] = widget.startDir;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SmartSavePad(
        totalCut: totalCut,
        bendList: finalSaveData,
        includeStart: _includeStartFitting,
        includeEnd: _includeEndFitting,
        tailLength: _tailLength,
        startDir: widget.startDir,
        onSaveCallback: null,
      ),
    );
  }

  void _showTailPad() async {
    _tailController.text = _tailLength > 0
        ? _tailLength.round().toString()
        : "";
    await MakitaNumpad.show(
      context,
      controller: _tailController,
      title: "절단 여유 기장 (mm)",
    );
    if (!mounted) {
      return;
    }
    double val = double.tryParse(_tailController.text) ?? 0.0;
    setState(() {
      _tailLength = val;
      MobileBendDataManager().tail = _tailLength;
    });
  }
}

// ==========================================
// 🚀 3탭: 모바일 도면 (3D Viewer) 화면
// ==========================================
class MobileViewerTab extends StatefulWidget {
  final String startDir;
  final ValueChanged<String>? onStartDirChanged;

  const MobileViewerTab({
    super.key,
    required this.startDir,
    this.onStartDirChanged,
  });

  @override
  State<MobileViewerTab> createState() => _MobileViewerTabState();
}

class _MobileViewerTabState extends State<MobileViewerTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ListenableBuilder(
      listenable: MobileBendDataManager(),
      builder: (context, child) {
        final dataManager = MobileBendDataManager();
        final bendList = dataManager.bendList;

        return Container(
          color: pureWhite,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                color: pureWhite,
                child: const Row(
                  children: [
                    Icon(Icons.threed_rotation, color: makitaTeal, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "ISO 3D 도면 뷰어 (드래그하여 회전)",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: slate900,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    CalcTag.tube(),
                  ],
                ),
              ),
              Expanded(
                child: bendList.isEmpty
                    ? const Center(
                        child: Text(
                          "입력된 치수가 없습니다.",
                          style: TextStyle(color: slate600, fontSize: 14),
                        ),
                      )
                    : MobilePipeVisualizer(
                        bendList: bendList,
                        tailLength: dataManager.tail,
                        initialStartDir: widget.startDir,
                        onStartDirChanged: widget.onStartDirChanged,
                        startFit: dataManager.startFit,
                        endFit: dataManager.endFit,
                        isLightMode: false,
                        // 실제 비율로 그릴 때 쓸 제원.
                        bendRadius: dataManager.radius,
                        outerDiameter: _odMm(),
                        fittingDepth: dataManager.fittingDepth,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// 🚀 4탭: 모바일 보관함 (History) 화면
// ==========================================
class MobileHistoryTab extends StatefulWidget {
  /// 도면을 계산기로 불러온 뒤(시작 방향을 넘긴다). 입력 탭으로 옮길 때 쓴다.
  final ValueChanged<String>? onLoaded;

  const MobileHistoryTab({super.key, this.onLoaded});
  @override
  State<MobileHistoryTab> createState() => _MobileHistoryTabState();
}

class _MobileHistoryTabState extends State<MobileHistoryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, List<Map<String, dynamic>>> _groupedHistory = {};
  bool _isLoading = true;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 🚀 [수정] 날짜 문자열이 10자 미만이어도(빈 문자열 등) 크래시 나지 않도록 안전하게 자름
  String _safeDatePrefix(dynamic date) {
    final raw = date?.toString() ?? '';
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  // 🚀 [수정] showFullLoader=false로 호출하면 이미 떠 있는 목록을 유지한 채 조용히 갱신한다.
  // (당겨서 새로고침 시 목록 전체가 스피너로 바뀌었다 사라지는 깜빡임 방지)
  Future<void> _refreshHistory({bool showFullLoader = true}) async {
    if (showFullLoader) {
      setState(() => _isLoading = true);
    }
    final data = await DatabaseHelper.instance.getHistory();
    if (!mounted) {
      return;
    }

    Map<String, List<Map<String, dynamic>>> tempGrouped = {};
    for (var item in data) {
      String rawPtoP = item['p_to_p'] ?? '{}';
      String project = "미지정 프로젝트";
      try {
        var pData = jsonDecode(rawPtoP);
        if (pData['project'] != null &&
            pData['project'].toString().trim().isNotEmpty) {
          project = pData['project'];
        }
      } catch (_) {}

      if (!tempGrouped.containsKey(project)) {
        tempGrouped[project] = [];
      }
      tempGrouped[project]!.add(item);
    }

    tempGrouped.forEach((key, list) {
      list.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
    });

    setState(() {
      _groupedHistory = tempGrouped;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    Map<String, List<Map<String, dynamic>>> filteredGroupedHistory = {};
    if (_searchQuery.isEmpty) {
      filteredGroupedHistory = _groupedHistory;
    } else {
      _groupedHistory.forEach((folderName, items) {
        bool folderMatches = folderName.toLowerCase().contains(_searchQuery);
        List<Map<String, dynamic>> matchingItems = items.where((item) {
          String rawPtoP = item['p_to_p'] ?? '{}';
          String fromTo = "";
          try {
            var pData = jsonDecode(rawPtoP);
            fromTo = "${pData['from']} ➔ ${pData['to']}".toLowerCase();
          } catch (_) {}
          return fromTo.contains(_searchQuery);
        }).toList();
        if (folderMatches) {
          filteredGroupedHistory[folderName] = items;
        } else if (matchingItems.isNotEmpty) {
          filteredGroupedHistory[folderName] = matchingItems;
        }
      });
    }

    final int total = _groupedHistory.values.fold(0, (n, l) => n + l.length);

    // 🚀 전선관 보관함과 같은 모양: 큰 제목 "보관된 도면 N개", 폴더 제목 줄,
    // 흰 카드(도면 이름·날짜·×, 총 재단 길이·규격, 단추). 검색과 폴더
    // 접기·펴기, 누르면 도면 보기는 그대로 둔다.
    return ColoredBox(
      color: slate100,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TitleWithTag(
                kind: CalcKind.tube,
                title: Text(
                  "보관된 도면 $total개",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: slate900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '프로젝트명 또는 경로 검색...',
                hintStyle: TextStyle(color: slate600.withValues(alpha: 0.6)),
                prefixIcon: const Icon(Icons.search, color: slate600),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.cancel, color: slate600),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = "");
                        },
                      )
                    : null,
                filled: true,
                fillColor: pureWhite,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: makitaTeal),
                  )
                : filteredGroupedHistory.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    // 🚀 [수정] 당겨서 새로고침할 땐 전체 스피너로 바꾸지 않고 조용히 갱신
                    onRefresh: () => _refreshHistory(showFullLoader: false),
                    color: makitaTeal,
                    backgroundColor: pureWhite,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                      itemCount: filteredGroupedHistory.keys.length,
                      itemBuilder: (context, index) {
                        final String folderName = filteredGroupedHistory.keys
                            .elementAt(index);
                        final folderItems = filteredGroupedHistory[folderName]!;
                        return Theme(
                          // 🚀 [수정] 폴더 이름 기준 key를 줘서, 검색으로 목록 순서/개수가
                          // 바뀌어도 ExpansionTile의 펼침 상태가 엉뚱한 폴더에 붙지 않게 함
                          key: ValueKey(folderName),
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            initiallyExpanded:
                                index == 0 || _searchQuery.isNotEmpty,
                            iconColor: slate600,
                            collapsedIconColor: slate600,
                            shape: const Border(),
                            collapsedShape: const Border(),
                            tilePadding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                            childrenPadding: EdgeInsets.zero,
                            title: _buildFolderTitle(
                              folderName,
                              folderItems.length,
                            ),
                            children: [
                              for (final item in folderItems)
                                _buildDrawingCard(item),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 폴더 제목 줄(전선관 보관함과 같은 모양).
  Widget _buildFolderTitle(String name, int count) {
    return Row(
      children: [
        const Icon(Icons.folder_rounded, color: _slate400, size: 22),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: slate900,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: slate200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            "$count",
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: slate600,
            ),
          ),
        ),
      ],
    );
  }

  /// 도면 카드(전선관 보관함 카드와 같은 모양).
  Widget _buildDrawingCard(Map<String, dynamic> item) {
    String fromTo = "경로 미상";
    try {
      final pData = jsonDecode(item['p_to_p'] ?? '{}');
      fromTo = "${pData['from']} ➔ ${pData['to']}";
    } catch (_) {}
    final int cut = (double.tryParse(item['total_length'].toString()) ?? 0.0)
        .round();

    return GestureDetector(
      onTap: () => _openDetail(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: slate900.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: slate50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.architecture_rounded,
                    color: makitaTeal,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        fromTo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: slate900,
                          height: 1.3,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        // 🚀 [수정] substring(0,10) 크래시 방지
                        _safeDatePrefix(item['date']),
                        style: const TextStyle(
                          fontSize: 13,
                          color: slate600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: ValueKey('tube_history_delete_${item['id']}'),
                    borderRadius: BorderRadius.circular(50),
                    onTap: () => _confirmDelete(item),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.close_rounded,
                        color: _slate400,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildInfoChip("총 재단 길이", "$cut mm")),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoChip("규격", "${item['pipe_size'] ?? '-'}"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _openDetail(item),
                style: ElevatedButton.styleFrom(
                  backgroundColor: slate100,
                  foregroundColor: slate900,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "도면 보기",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: slate50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: slate600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: slate900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: pureWhite,
            ),
            child: const Icon(
              Icons.folder_off_rounded,
              size: 48,
              color: slate200,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty ? "검색 결과가 없습니다" : "보관된 도면이 없습니다",
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: slate900,
              letterSpacing: -0.5,
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              "마킹 탭에서 작업 결과를 저장해 보십시오.",
              style: TextStyle(
                color: slate600,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 도면 보기 화면을 연다. 거기서 "계산기로 불러오기"를 했으면 입력 탭으로.
  Future<void> _openDetail(Map<String, dynamic> item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MobileFabricationDetailScreen(itemData: item),
      ),
    );
    if (!mounted) return;
    if (result is Map && result['loaded'] == true) {
      widget.onLoaded?.call(result['startDir']?.toString() ?? 'RIGHT');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: makitaTeal,
          behavior: SnackBarBehavior.floating,
          content: Text(
            "도면을 불러왔습니다. 입력 탭의 ↶로 되돌릴 수 있습니다.",
            style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
    // 🚀 [수정] 상세화면에서 돌아올 때는 조용히 갱신
    _refreshHistory(showFullLoader: false);
  }

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: "삭제 확인",
        okText: "삭제",
        onCancel: () => Navigator.pop(ctx, false),
        onOk: () => Navigator.pop(ctx, true),
        content: AppDialog.message("이 도면을 보관함에서 영구 삭제하시겠습니까?"),
      ),
    );
    if (confirm != true) return;
    await DatabaseHelper.instance.deleteHistory(item['id']);
    if (!mounted) return;
    // 🚀 [수정] 삭제 후에도 조용히 갱신
    _refreshHistory(showFullLoader: false);
  }
}
