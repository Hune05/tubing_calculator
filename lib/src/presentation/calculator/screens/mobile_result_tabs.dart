import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/core/common_widgets/smart_save_pad.dart';
import 'package:tubing_calculator/src/core/engine/tube_bending_engine.dart';
import 'package:tubing_calculator/src/core/utils/app_settings_controller.dart';
import 'package:tubing_calculator/src/presentation/calculator/bend_check.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/bend_warning_banner.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_pipe_visualizer.dart';
import 'package:tubing_calculator/src/core/database/database_helper.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/mobile_fabrication_detail_screen.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color slate100 = Color(0xFFF2F4F6);
const Color slate50 = Color(0xFFF8FAFC);
const Color pureWhite = Color(0xFFFFFFFF);

// 🚀 [추가] "현장" 탭(가로 모드 줄자 화면)이 필요한 최소 데이터(총 길이 +
// 마킹 지점 목록)만 MobileBendDataManager에서 직접 다시 계산해주는 함수.
// 🚀 [버그 수정] 처음엔 MobileResultTab의 build() 안에서 계산한 값을
// postFrameCallback으로 전역 ValueNotifier에 밀어넣고 "현장" 탭이 그걸
// 구독하는 방식이었는데, IndexedStack 안에서 두 위젯의 빌드 타이밍이
// 어긋나면 "현장" 탭이 한 프레임 늦게 텅 빈 초기값을 보여주는 문제가
// 있었다(사용자가 "결과 값을 안 가져오는 것 같다"고 확인). 다른 위젯의
// 빌드 시점에 기대지 않도록, "현장" 탭이 자기 build() 안에서 이 함수를
// 직접 호출해서 그 자리에서 항상 최신값을 스스로 계산하게 바꿨다.
/// 관 바깥지름을 mm로. 설정이 인치면 바꿔 준다.
double _odMm() {
  final s = AppSettingsController();
  return s.isInch ? s.tubeOD * 25.4 : s.tubeOD;
}

({double totalCutLength, List<Map<String, dynamic>> markings, String? error})
computeLandscapeMarkingData() {
  final dataManager = MobileBendDataManager();
  final bendList = dataManager.bendList;

  if (bendList.isEmpty) {
    return (totalCutLength: 0.0, markings: const [], error: null);
  }

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
    return (totalCutLength: 0.0, markings: const [], error: e.toString());
  }

  final double pureCutLength = result['totalCutLength'];
  final List<StepResult> steps = result['steps'];

  final List<Map<String, dynamic>> markings = [];
  for (int i = 0; i < bendList.length; i++) {
    final double currentLength =
        (bendList[i]['length'] as num?)?.toDouble() ?? 0.0;
    final double angleValue = (bendList[i]['angle'] as num?)?.toDouble() ?? 0.0;
    final bool isStraight = angleValue == 0.0;
    if (currentLength <= 0.01 && isStraight) continue; // 길이 0짜리 더미 구간 제외

    markings.add({
      'mark': steps[i].markingPoint,
      'angle': angleValue,
      'rotation': (bendList[i]['rotation'] as num?)?.toDouble() ?? 0.0,
    });
  }

  // 꼬리는 엔진이 마지막 셋백을 빼고 더해 준다(예전에는 여기서 그대로 더해
  // 마지막 셋백만큼 길게 잘렸다). 여기서는 톱날 손실만 더한다.
  final double totalCut = pureCutLength + dataManager.cutMargin;

  return (totalCutLength: totalCut, markings: markings, error: null);
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

        return Container(
          color: pureWhite,
          child: Column(
            children: [
              BendWarningBanner(warnings: warnings),
              // 1. 상단 토탈 컷 카드
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "TOTAL CUT LENGTH",
                            style: TextStyle(
                              color: slate600,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${totalCut.round()} mm",
                            style: const TextStyle(
                              color: makitaTeal,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                          if (bendList.isNotEmpty && diffAfterLastMark > 0)
                            Text(
                              "※ 마지막 벤딩 후 잔여: +${diffAfterLastMark.round()}mm",
                              style: TextStyle(
                                color: Colors.red.shade400,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "반경(R): ${radius.round()}mm",
                          style: const TextStyle(
                            color: slate600,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: slate900,
                            foregroundColor: pureWhite,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          // ✅ 수정 완료: UI 전용 데이터(displayMarks) 대신 순수 데이터(bendList) 저장
                          onPressed: bendList.isEmpty
                              ? null
                              : () => _handleSave(totalCut, bendList),
                          icon: const Icon(Icons.save_alt_rounded, size: 18),
                          label: const Text(
                            "도면 저장",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. 피팅 & 여유 기장 옵션 박스
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: slate50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildOptionTile(
                      title: "시작 피팅 (+${fittingDepth.round()}mm)",
                      value: _includeStartFitting,
                      onChanged: (v) => setState(() {
                        _includeStartFitting = v;
                        MobileBendDataManager().startFit = v;
                      }),
                    ),
                    _buildOptionTile(
                      title: "종료 피팅 (+${fittingDepth.round()}mm)",
                      value: _includeEndFitting,
                      onChanged: (v) => setState(() {
                        _includeEndFitting = v;
                        MobileBendDataManager().endFit = v;
                      }),
                    ),
                    InkWell(
                      onTap: _showTailPad,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 20,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.straighten,
                                  color: slate600,
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  "절단 여유 기장 (Tail)",
                                  style: TextStyle(
                                    color: slate900,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              "${_tailLength.round()} mm >",
                              style: const TextStyle(
                                color: makitaTeal,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. 마킹 포인트 헤더
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 32, 24, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "MARKING POINTS (줄자 0점 고정)",
                    style: TextStyle(
                      color: slate600,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

              // 4. 마킹 포인트 리스트
              Expanded(
                child: displayMarks.isEmpty
                    ? Center(
                        child: Text(
                          "1번 탭에서 치수를 입력해 주십시오.",
                          style: TextStyle(
                            color: slate600.withValues(alpha: 0.6),
                            fontSize: 15,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        itemCount: displayMarks.length,
                        itemBuilder: (context, index) {
                          final item = displayMarks[index];
                          if (item['is_hidden'] == true) {
                            return const SizedBox.shrink();
                          }

                          int cumulativeMark =
                              (item['marking_point'] as num?)?.round() ?? 0;
                          int incrementalMark =
                              (item['incremental_mark'] as num?)?.round() ?? 0;
                          int originalLength =
                              (item['length'] as num?)?.round() ?? 0;

                          double appliedFit =
                              (item['applied_fit'] as num?)?.toDouble() ?? 0.0;
                          String fitText = appliedFit > 0
                              ? " (+피팅 ${appliedFit.round()})"
                              : "";

                          if (item['is_straight'] == true) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: slate50,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.arrow_downward,
                                    color: slate600,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "직관 연장: +$originalLength$fitText mm",
                                      style: const TextStyle(
                                        color: slate600,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "마킹: $cumulativeMark",
                                    style: const TextStyle(
                                      color: makitaTeal,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'monospace',
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          double rotationVal =
                              (item['rotation'] as num?)?.toDouble() ?? 0.0;
                          double angleVal =
                              (item['angle'] as num?)?.toDouble() ?? 0.0;
                          double targetAngleVal =
                              (item['target_angle'] as num?)?.toDouble() ??
                              angleVal;
                          bool hasSpringback =
                              (targetAngleVal - angleVal).abs() > 0.05;
                          // 앞 벤드와 다른 평면으로 꺾을 때 관을 굴릴 각도.
                          // 예전에는 화면에 나오지 않아, 관을 얼마나 돌려
                          // 물려야 하는지 눈대중으로 맞췄다.
                          final double rollDeg =
                              (item['roll_deg'] as num?)?.toDouble() ?? 0.0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: slate50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: makitaTeal.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    "${item['mark_num']}",
                                    style: const TextStyle(
                                      color: makitaTeal,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "누적 마킹 지점",
                                        style: TextStyle(
                                          color: slate600,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        "$cumulativeMark mm",
                                        style: const TextStyle(
                                          color: slate900,
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      if ((item['mark_num'] as num?) != null &&
                                          (item['mark_num'] as num) > 1)
                                        Text(
                                          "↳ 앞 마킹과의 거리: +$incrementalMark",
                                          style: const TextStyle(
                                            color: makitaTeal,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "배관: $originalLength$fitText",
                                      style: const TextStyle(
                                        color: slate600,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: pureWhite,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _getDirectionIcon(rotationVal),
                                            size: 16,
                                            color: slate900,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${angleVal.round()}° / ${_getDirectionText(rotationVal)}",
                                            style: const TextStyle(
                                              color: slate900,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (hasSpringback) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        "스프링백 보정 → ${targetAngleVal.toStringAsFixed(1)}°",
                                        style: const TextStyle(
                                          color: makitaTeal,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                    if (rollDeg > 0.5) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        "앞 벤드에서 ${rollDeg.round()}° 굴려 물리십시오",
                                        style: const TextStyle(
                                          color: Color(0xFFC77700),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          children: [
            Icon(
              value ? Icons.check_circle : Icons.radio_button_unchecked,
              color: value ? makitaTeal : slate600.withValues(alpha: 0.5),
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: value ? slate900 : slate600,
                fontSize: 15,
                fontWeight: value ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ],
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
                    Text(
                      "ISO 3D 도면 뷰어 (드래그하여 회전)",
                      style: TextStyle(
                        color: slate900,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
  const MobileHistoryTab({super.key});
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

    return Container(
      color: pureWhite,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '프로젝트명 또는 경로 검색...',
                hintStyle: TextStyle(color: slate600.withValues(alpha: 0.5)),
                prefixIcon: const Icon(Icons.search, color: slate900),
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
                fillColor: slate50,
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
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          size: 64,
                          color: slate600.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? '검색 결과가 없습니다.'
                              : '저장된 도면이 없습니다.',
                          style: TextStyle(
                            color: slate600.withValues(alpha: 0.6),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    // 🚀 [수정] 당겨서 새로고침할 땐 전체 스피너로 바꾸지 않고 조용히 갱신
                    onRefresh: () => _refreshHistory(showFullLoader: false),
                    color: makitaTeal,
                    backgroundColor: pureWhite,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: filteredGroupedHistory.keys.length,
                      itemBuilder: (context, index) {
                        String folderName = filteredGroupedHistory.keys
                            .elementAt(index);
                        List<Map<String, dynamic>> folderItems =
                            filteredGroupedHistory[folderName]!;

                        return Theme(
                          // 🚀 [수정] 폴더 이름 기준 key를 줘서, 검색으로 목록 순서/개수가
                          // 바뀌어도 ExpansionTile의 펼침 상태가 엉뚱한 폴더에 붙지 않게 함
                          key: ValueKey(folderName),
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: slate50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ExpansionTile(
                              initiallyExpanded:
                                  index == 0 || _searchQuery.isNotEmpty,
                              iconColor: slate900,
                              collapsedIconColor: slate600,
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 4,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: pureWhite,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.folder_rounded,
                                  color: makitaTeal,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                "$folderName (${folderItems.length})",
                                style: const TextStyle(
                                  color: slate900,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              children: folderItems.map((item) {
                                String rawPtoP = item['p_to_p'] ?? '{}';
                                String fromTo = "경로 미상";
                                try {
                                  var pData = jsonDecode(rawPtoP);
                                  fromTo = "${pData['from']} ➔ ${pData['to']}";
                                } catch (_) {}
                                double cutRaw =
                                    double.tryParse(
                                      item['total_length'].toString(),
                                    ) ??
                                    0.0;
                                int cutDisplay = cutRaw.round();

                                return Container(
                                  margin: const EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    bottom: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: pureWhite,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              MobileFabricationDetailScreen(
                                                itemData: item,
                                              ),
                                        ),
                                      );
                                      if (!context.mounted) {
                                        return;
                                      }
                                      // 🚀 [수정] 상세화면에서 돌아올 때는 조용히 갱신
                                      _refreshHistory(showFullLoader: false);
                                    },
                                    title: Text(
                                      fromTo,
                                      style: const TextStyle(
                                        color: slate900,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.straighten,
                                                size: 14,
                                                color: slate600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                "Cut: $cutDisplay mm",
                                                style: const TextStyle(
                                                  color: makitaTeal,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                "Size: ${item['pipe_size']}",
                                                style: const TextStyle(
                                                  color: slate600,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            // 🚀 [수정] substring(0,10) 크래시 방지
                                            "날짜: ${_safeDatePrefix(item['date'])}",
                                            style: TextStyle(
                                              color: slate600.withValues(
                                                alpha: 0.5,
                                              ),
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.red.shade300,
                                      ),
                                      onPressed: () async {
                                        bool? confirm = await showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor: pureWhite,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            title: const Text(
                                              "삭제 확인",
                                              style: TextStyle(
                                                color: slate900,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            content: const Text(
                                              "이 도면을 보관함에서 영구 삭제하시겠습니까?",
                                              style: TextStyle(color: slate600),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: const Text(
                                                  "취소",
                                                  style: TextStyle(
                                                    color: slate600,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: Text(
                                                  "삭제",
                                                  style: TextStyle(
                                                    color: Colors.red.shade600,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await DatabaseHelper.instance
                                              .deleteHistory(item['id']);
                                          if (!context.mounted) {
                                            return;
                                          }
                                          // 🚀 [수정] 삭제 후에도 조용히 갱신
                                          _refreshHistory(
                                            showFullLoader: false,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
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
}
