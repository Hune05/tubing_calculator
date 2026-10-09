import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/common_widgets/app_components.dart' show showSheetSnack;
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math' as math;
import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad_glass.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/bend_sheet_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/sheet_direction_gate.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/opposite_rotation.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/rolling_offset_guide.dart';

/// 굴림 오프셋이 목록에 넣을 두 구간(길이, 각도, 방향).
///
/// 🚀 [고침] 예전에는 첫 구간을 축소값(빗변 − 전진)으로만 넣어서, 마킹 화면이
/// 셋백을 빼고 나면 R150·높이 100·45°에서 1번 마킹이 −20.7mm가 되었다(반경과
/// 높이가 우연히 같을 때만 맞았다). 오프셋·새들처럼 "시작 거리 + 셋백"을
/// 첫 구간으로 넣어 1번 마킹이 시작 거리 자리에 오게 한다.
List<(double, double, double)> rollingOffsetBends({
  required BendSheetSpecs specs,
  required double startDistance,
  required double travel,
  required double angle,
  required double advance,
  required double rotation,
}) {
  double r1(double v) => double.parse(v.toStringAsFixed(1));
  final double a = r1(angle);
  final double shrink = (travel - advance).clamp(0.0, travel);
  return [
    (r1(specs.firstLength(startDistance, a, shrink)), a, rotation),
    (r1(travel), a, oppositeRotation(rotation)),
  ];
}

/// 10-09: 롤링 시트에 넣었던 값을 앱이 켜져 있는 동안 기억한다(오프셋·새들처럼 — 예전에는 열 때마다 150/200/45로).
final Map<String, String> _rollingRemembered = {};

/// 시험에서 기억을 비운다.
@visibleForTesting
void resetRollingSheetMemory() => _rollingRemembered.clear();

const Color makitaTeal = AppColors.brand;
const Color slate900 = AppColors.text;
const Color slate600 = AppColors.textSub;
const Color slate100 = AppColors.background;
const Color pureWhite = Color(0xFFFFFFFF);

class MobileRollingOffsetBottomSheet extends StatefulWidget {
  final double currentRotation;
  final Function(double length, double angle, double rotation) onAddBend;

  /// 줄 여러 개를 한 번에 넣는 곳(있으면 이것을 쓴다). 🚀 [고침] 예전엔 줄마다 따로
  /// 넣어 되돌리기(↶)를 여러 번 눌러야 했다(새들과 같은 방식).
  final void Function(List<Map<String, double>> bends)? onAddBends;

  /// 어느 계산기에서 열었는지에 따른 장비 값. 없으면 튜브 제원을 읽는다.
  final BendSheetSpecs? specs;

  /// 지금 진행 방향에서 그 방향으로 꺾을 수 있는지(입력 탭이 넘긴다). 없으면 모두 고를 수 있다.
  final BendRule? canBendTo;

  const MobileRollingOffsetBottomSheet({
    super.key,
    required this.currentRotation,
    required this.onAddBend,
    this.onAddBends,
    this.specs,
    this.canBendTo,
  });

  static void show(
    BuildContext context, {
    required double currentRotation,
    required Function(double, double, double) onAddBend,
    void Function(List<Map<String, double>> bends)? onAddBends,
    BendSheetSpecs? specs,
    BendRule? canBendTo,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MobileRollingOffsetBottomSheet(
        currentRotation: currentRotation,
        onAddBend: onAddBend,
        onAddBends: onAddBends,
        specs: specs,
        canBendTo: canBendTo,
      ),
    );
  }

  @override
  State<MobileRollingOffsetBottomSheet> createState() =>
      _MobileRollingOffsetBottomSheetState();
}

class _MobileRollingOffsetBottomSheetState
    extends State<MobileRollingOffsetBottomSheet> {
  bool _isReverseMode = false;
  RollingFocus? _focus; // 마지막으로 누른 입력 칸(그림에서 그 값을 강조)
  double? _selectedRotation;
  double _bendRadius = 0.0; // 🚀 설정화면에서 불러올 R값 저장 변수
  BendSheetSpecs? _specs;

  // 1번 마킹을 찍을 자리(관 끝이나 앞 마킹에서).
  final TextEditingController _startCtrl = TextEditingController(text: "0");

  final TextEditingController _riseCtrl = TextEditingController(text: "150");
  final TextEditingController _rollCtrl = TextEditingController(text: "200");
  final TextEditingController _travelCtrl = TextEditingController(text: "350");
  final TextEditingController _angleCtrl = TextEditingController(text: "45");

  final List<Map<String, dynamic>> _directions = [
    {"label": "UP (위)", "val": 0.0, "icon": Icons.arrow_upward},
    {"label": "FRONT (앞)", "val": 360.0, "icon": Icons.call_made},
    {"label": "LEFT (좌)", "val": 270.0, "icon": AppIcons.back},
    {"label": "RIGHT (우)", "val": 90.0, "icon": Icons.arrow_forward},
    {"label": "DOWN (아래)", "val": 180.0, "icon": Icons.arrow_downward},
    {"label": "BACK (뒤)", "val": 450.0, "icon": Icons.call_received},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings(); // 🚀 초기화 시 설정값 불러오기
    for (final (k, c) in [
      ('rise', _riseCtrl),
      ('roll', _rollCtrl),
      ('travel', _travelCtrl),
      ('angle', _angleCtrl),
      ('start', _startCtrl),
    ]) {
      final v = _rollingRemembered[k];
      if (v != null) c.text = v;
      c.addListener(() {
        _rollingRemembered[k] = c.text;
        setState(() {});
      });
    }
  }

  // 🚀 설정 파일에서 벤더 R값 끌어오는 함수
  Future<void> _loadSettings() async {
    try {
      // 🚀 [고침] 전선관에서 열어도 튜브 반경을 읽고 있었다.
      final specs = widget.specs ?? await BendSheetSpecs.tube();
      if (mounted) {
        setState(() {
          _specs = specs;
          _bendRadius = specs.radius;
        });
      }
    } catch (e) {
      debugPrint("설정값 로드 실패: $e");
    }
  }

  @override
  void dispose() {
    _riseCtrl.dispose();
    _rollCtrl.dispose();
    _travelCtrl.dispose();
    _angleCtrl.dispose();
    _startCtrl.dispose();
    super.dispose();
  }

  void _applyRolling(
    double finalTravel,
    double finalBendAngle,
    double rollAngle,
    double advance,
  ) {
    // 오프셋 창처럼 90° 미만만 받는다(10-08: 120°·175°도 목록에 들어가 절단 길이가 이상하게 나왔다).
    if (finalBendAngle >= 90) {
      // 시트 안에서 보이게(10-09: 시트 밑 화면에 떠 가려졌다).
      showSheetSnack(context, "넣을 수 없습니다. 각도는 90°보다 작아야 합니다.");
      return;
    }
    if (_selectedRotation == null) {
      showSheetSnack(context, "꺾는 방향(6축)을 먼저 고르십시오.");
      return;
    }
    if (finalTravel > 0 && finalBendAngle > 0) {
      // 🚀 [고침] 예전에는 방향값에 굴림 각도를 더해서(예: 0 + 30 = 30) 표에
      // 없는 값이 되었고, 그런 값은 모두 '우'로 떨어져 형상이 엉켰다. 방향은
      // 고른 기준면 그대로 쓰고, 굴림 각도는 작업 지시로 따로 알려 준다.
      final specs =
          _specs ??
          BendSheetSpecs(
            radius: _bendRadius,
            gain90: 0.0,
            markOffset: (a) => bendSetback(_bendRadius, a),
          );
      final bends = rollingOffsetBends(
        specs: specs,
        startDistance: double.tryParse(_startCtrl.text) ?? 0.0,
        travel: finalTravel,
        angle: finalBendAngle,
        advance: advance,
        rotation: _selectedRotation!,
      );
      // 넣은 뒤 1번 마킹 자리를 알린다(축소값이 더해지면 그 값까지).
      final double start = double.tryParse(_startCtrl.text) ?? 0.0;
      final double addShrink = specs.shrinkToAdd(finalTravel - advance);
      final String firstMarkNote = start > 0
          ? "넣었습니다. 1번 마킹이 ${(start + addShrink).toStringAsFixed(0)}mm 자리에 찍힙니다"
                "${addShrink > 0 ? "(시작 ${start.toStringAsFixed(0)} + 축소값 ${addShrink.toStringAsFixed(1)})" : ""}. "
          : "넣었습니다. ";
      final many = widget.onAddBends;
      if (many != null) {
        // 10-09: 굴림 각도를 첫 줄에 남긴다(예전에는 넣은 직후 4초 알림에만 나와 마킹 카드·현장 탭·
        // 마킹지 어디에도 없었다 — 두 벤드가 한 평면이라 형상 점검으로는 굴림이 안 잡힌다).
        many([
          for (final (i, (length, angle, rotation)) in bends.indexed)
            {
              'length': length,
              'angle': angle,
              'rotation': rotation,
              if (i == 0 && rollAngle > 0.5) 'rollHint': rollAngle,
            },
        ]);
      } else {
        for (final (length, angle, rotation) in bends) {
          widget.onAddBend(length, angle, rotation);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "$firstMarkNote${rollAngle > 0.5 ? "꺾기 전에 관을 ${rollAngle.toStringAsFixed(0)}° 굴려서 잡으십시오." : ""}",
          ),
          backgroundColor: makitaTeal,
        ),
      );
      Navigator.pop(context);
    } else {
      // 🚀 [고침] 값이 모자라면 말없이 아무 일도 안 했다.
      showSheetSnack(
        context,
        _isReverseMode
            ? "넣을 수 없습니다. 빗변을 True Offset보다 길게 넣으십시오."
            : "넣을 수 없습니다. Rise·Roll 값과 벤딩 각도를 넣으십시오.",
        key: const Key('rolling_missing'),
      );
    }
  }

  Widget _buildDirectionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "꺾는 방향 (6축)",
              style: TextStyle(
                color: _selectedRotation == null ? Colors.redAccent : slate600,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_selectedRotation == null)
              const Text(
                " *필수",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _directions.length,
          itemBuilder: (context, index) {
            final dir = _directions[index];
            bool isSelected = _selectedRotation == dir['val'];
            return gateSheetDirection(
              context: context,
              rule: widget.canBendTo,
              rot: dir['val'] as double,
              label: dir['label'].split(' ')[0],
              onPick: () => setState(() => _selectedRotation = dir['val']),
              chip: (onTap) => InkWell(
                onTap: onTap,
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? makitaTeal : slate100,
                    border: Border.all(
                      color: isSelected ? makitaTeal : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        dir['icon'],
                        size: 16,
                        color: isSelected ? pureWhite : slate600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dir['label'].split(' ')[0],
                        style: TextStyle(
                          color: isSelected ? pureWhite : slate900,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    double rise = double.tryParse(_riseCtrl.text) ?? 0;
    double roll = double.tryParse(_rollCtrl.text) ?? 0;
    double trueOffset = math.sqrt(math.pow(rise, 2) + math.pow(roll, 2));
    double rollAngle = 0;

    if (rise > 0 || roll > 0) {
      rollAngle = math.atan2(roll, rise) * (180.0 / math.pi);
      if (rollAngle < 0) rollAngle += 360;
    }

    double finalTravel = 0;
    double finalBendAngle = 0;
    double advance = 0;

    if (_isReverseMode) {
      finalTravel = double.tryParse(_travelCtrl.text) ?? 0;
      if (finalTravel > 0 && trueOffset <= finalTravel) {
        finalBendAngle =
            math.asin(trueOffset / finalTravel) * (180.0 / math.pi);
        advance = math.sqrt(math.pow(finalTravel, 2) - math.pow(trueOffset, 2));
      }
    } else {
      finalBendAngle = double.tryParse(_angleCtrl.text) ?? 0;
      if (finalBendAngle > 0 && finalBendAngle < 180) {
        double bendRad = finalBendAngle * math.pi / 180.0;
        finalTravel = trueOffset / math.sin(bendRad);
        advance = finalBendAngle == 90.0 ? 0 : trueOffset / math.tan(bendRad);
      }
    }

    // 1번 → 2번 마킹 간격은 마킹 탭과 같은 셈(빗변 − 앞 벤드 게인)으로 보인다.
    // 🚀 [고침 10-09] 예전에는 "빗변 − R·tan(θ/2)"를 "실제 마킹 간격"으로 보여 마킹 탭과
    // 달랐다(R38.1, 진짜 오프셋 100, 45°: 125.6 / 마킹 탭 139.8). 목록에 넣는 값은 원래 맞았다.
    final sheetSpecs = _specs;
    double gapGain = 0;
    double markingDistance = 0;
    final bool showGap = sheetSpecs != null &&
        finalTravel > 0 &&
        finalBendAngle > 0 &&
        finalBendAngle < 90;
    if (showGap) {
      gapGain = sheetSpecs.gainAt(finalBendAngle);
      markingDistance = sheetSpecs.markGap(finalTravel, finalBendAngle);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(LucideIcons.orbit, color: makitaTeal, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "롤링 오프셋",
                      style: TextStyle(
                        color: slate900,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: slate600),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              RollingOffsetGuide(
                rise: rise,
                roll: roll,
                trueOffset: trueOffset,
                rollAngle: rollAngle,
                bendAngle: finalBendAngle,
                focus: _focus,
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: slate100,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isReverseMode = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isReverseMode
                                ? makitaTeal
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "정방향 (각도 입력)",
                            style: TextStyle(
                              color: !_isReverseMode ? pureWhite : slate600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isReverseMode = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isReverseMode
                                ? makitaTeal
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "역산 (빗변 입력)",
                            style: TextStyle(
                              color: _isReverseMode ? pureWhite : slate600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildCompactInputRow(
                      _riseCtrl,
                      "수직 거리 (Rise)",
                      RollingFocus.rise,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCompactInputRow(
                      _rollCtrl,
                      "롤링 (Roll)",
                      RollingFocus.roll,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildCompactInputRow(
                _startCtrl,
                // 10-09: 전선관에서 "1번 마킹에 축소값 더하기"가 켜져 있으면 1번 마킹은 이 값 + 축소값이다
                // (예전 이름은 늘 "1번 마킹 자리"라 시작 300에 마킹이 403.6에 찍혀도 알 수 없었다).
                (_specs?.addGeometricShrink ?? false)
                    ? "시작 거리 (mm) · 1번 마킹 = 이 값 + 축소값"
                    : "시작 거리 (1번 마킹 자리, mm)",
                RollingFocus.start,
              ),
              const SizedBox(height: 12),
              if (_isReverseMode) ...[
                _buildCompactInputRow(
                  _travelCtrl,
                  "현장 빗변 (Travel)",
                  RollingFocus.travel,
                ),
              ] else ...[
                _buildCompactInputRow(
                  _angleCtrl,
                  "벤딩 각도 (∠)",
                  RollingFocus.bend,
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text(
                        "빠른 각도:",
                        style: TextStyle(
                          color: slate600,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...[
                        22.5,
                        30.0,
                        45.0,
                        60.0,
                        // 10-09: 90°는 롤링 오프셋에 못 넣어(90° 미만만) 늘 거절됐다 → 뺐다.
                      ].map((val) => _buildQuickAngleBtn(_angleCtrl, val)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _buildDirectionSelector(),
              const SizedBox(height: 16),

              // 🚀 [UI 핵심 수정] 계산 결과 및 실무용 마킹 데이터 영역
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: makitaTeal.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: makitaTeal.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. 보조 지표 영역 (위쪽)
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: makitaTeal, size: 16),
                        SizedBox(width: 6),
                        Text(
                          "계산 결과",
                          style: TextStyle(
                            color: makitaTeal,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: pureWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _buildMiniResult(
                            "True Offset",
                            "${trueOffset.toStringAsFixed(1)} mm",
                          ),
                          _buildMiniResult(
                            "수평 거리 (Run)",
                            "${advance.toStringAsFixed(1)} mm",
                          ),
                          _buildMiniResult(
                            "회전각",
                            "${rollAngle.toStringAsFixed(1)}°",
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 🚀 2. [신규] 현장 실무용 오차 보정 마킹 데이터 영역
                    if (showGap) ...[
                      const Row(
                        children: [
                          Icon(
                            Icons.construction,
                            color: Colors.deepOrange,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              "현장 마킹 (마킹 탭과 같은 셈)",
                              style: TextStyle(
                                color: Colors.deepOrange,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.deepOrange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "앞 벤드 게인",
                                  style: TextStyle(
                                    color: Colors.deepOrange.shade800,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "- ${gapGain.toStringAsFixed(1)} mm",
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "1번 → 2번 마킹 간격",
                                  style: TextStyle(
                                    color: Colors.deepOrange.shade800,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "${markingDistance.toStringAsFixed(1)} mm",
                                  style: const TextStyle(
                                    color: Colors.deepOrange,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 3. 메인 결과 및 적용 버튼 영역 (아래쪽)
                    // 결과 아래에 적용 단추를 둔다(좁은 폭에서 옆에 두면 넘쳤다).
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isReverseMode
                                  ? "목표 벤딩 각도 (∠)"
                                  : "이론 빗변 (Travel)",
                              style: const TextStyle(
                                color: slate600,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isReverseMode
                                  ? (finalBendAngle > 0
                                        ? "${finalBendAngle.toStringAsFixed(1)}°"
                                        : "계산 불가")
                                  : (finalTravel > 0
                                        ? "${finalTravel.toStringAsFixed(1)} mm"
                                        : "입력 필요"),
                              style: TextStyle(
                                color:
                                    (_isReverseMode
                                        ? finalBendAngle > 0
                                        : finalTravel > 0)
                                    ? makitaTeal
                                    : Colors.redAccent,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: makitaTeal,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _applyRolling(
                              finalTravel,
                              finalBendAngle,
                              rollAngle,
                              advance,
                            ),
                            child: const Text(
                              "목록에 넣기",
                              style: TextStyle(
                                color: pureWhite,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🚀 미니 결과값 위젯
  Widget _buildMiniResult(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: slate600,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: slate900,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildCompactInputRow(
    TextEditingController ctrl,
    String hint,
    RollingFocus focus,
  ) {
    final active = _focus == focus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hint,
          style: const TextStyle(
            color: slate600,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          readOnly: true,
          onTap: () {
            setState(() => _focus = focus);
            MakitaNumpadGlass.show(context, controller: ctrl, title: hint);
          },
          style: const TextStyle(
            color: makitaTeal,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: slate100,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: active
                  ? const BorderSide(color: makitaTeal, width: 2)
                  : BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: makitaTeal, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAngleBtn(TextEditingController ctrl, double val) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: InkWell(
        onTap: () {
          setState(() => _focus = RollingFocus.bend);
          ctrl.text = val.toStringAsFixed(val % 1 == 0 ? 0 : 1);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            val % 1 == 0 ? "${val.toInt()}°" : "$val°",
            style: const TextStyle(
              color: slate900,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
