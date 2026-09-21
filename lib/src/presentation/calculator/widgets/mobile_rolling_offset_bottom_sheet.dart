import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math' as math;
import 'package:tubing_calculator/src/core/engine/bend_geometry.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad_glass.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/bend_sheet_specs.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/opposite_rotation.dart';

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

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class MobileRollingOffsetBottomSheet extends StatefulWidget {
  final double currentRotation;
  final Function(double length, double angle, double rotation) onAddBend;

  /// 어느 계산기에서 열었는지에 따른 장비 값. 없으면 튜브 제원을 읽는다.
  final BendSheetSpecs? specs;

  const MobileRollingOffsetBottomSheet({
    super.key,
    required this.currentRotation,
    required this.onAddBend,
    this.specs,
  });

  static void show(
    BuildContext context, {
    required double currentRotation,
    required Function(double, double, double) onAddBend,
    BendSheetSpecs? specs,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MobileRollingOffsetBottomSheet(
        currentRotation: currentRotation,
        onAddBend: onAddBend,
        specs: specs,
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
    {"label": "LEFT (좌)", "val": 270.0, "icon": Icons.arrow_back},
    {"label": "RIGHT (우)", "val": 90.0, "icon": Icons.arrow_forward},
    {"label": "DOWN (아래)", "val": 180.0, "icon": Icons.arrow_downward},
    {"label": "BACK (뒤)", "val": 450.0, "icon": Icons.call_received},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings(); // 🚀 초기화 시 설정값 불러오기
    _riseCtrl.addListener(() => setState(() {}));
    _rollCtrl.addListener(() => setState(() {}));
    _travelCtrl.addListener(() => setState(() {}));
    _angleCtrl.addListener(() => setState(() {}));
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
    if (_selectedRotation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("진행할 기준면 축을 먼저 선택해 주십시오!"),
          backgroundColor: Colors.deepOrange,
        ),
      );
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
      for (final (length, angle, rotation) in bends) {
        widget.onAddBend(length, angle, rotation);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            rollAngle > 0.5
                ? "넣었습니다. 꺾기 전에 관을 ${rollAngle.toStringAsFixed(0)}° 굴려서 잡으십시오."
                : "넣었습니다.",
          ),
          backgroundColor: makitaTeal,
        ),
      );
      Navigator.pop(context);
    }
  }

  Widget _buildDirectionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "진행할 기준면 축 지정 (6축)",
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
            return InkWell(
              onTap: () => setState(() => _selectedRotation = dir['val']),
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

    // 🚀 [추가] 테이크오프(Take-off) 및 최종 마킹 거리 계산 로직
    double takeOff = 0;
    double markingDistance = 0;

    if (_bendRadius > 0 && finalBendAngle > 0) {
      // 공식: R * tan(각도/2)
      takeOff =
          _bendRadius * math.tan((finalBendAngle / 2.0) * (math.pi / 180.0));
      if (finalTravel > 0) {
        // 실제 마킹 거리 = 도면상 빗변 - 공제량
        markingDistance = finalTravel - takeOff;
      }
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
                  const Row(
                    children: [
                      Icon(LucideIcons.orbit, color: makitaTeal, size: 28),
                      SizedBox(width: 12),
                      Text(
                        "롤링 오프셋 계산기",
                        style: TextStyle(
                          color: slate900,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: slate600),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
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
                            "정산 (각도 입력)",
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
                    child: _buildCompactInputRow(_riseCtrl, "수직 거리 (Rise)"),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCompactInputRow(_rollCtrl, "수평 거리 (Roll)"),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildCompactInputRow(_startCtrl, "시작 거리 (1번 마킹 자리, mm)"),
              const SizedBox(height: 12),
              if (_isReverseMode) ...[
                _buildCompactInputRow(_travelCtrl, "가진 파이프 빗변 (Travel)"),
              ] else ...[
                _buildCompactInputRow(_angleCtrl, "벤딩 각도 (∠)"),
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
                        90.0,
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
                          "기하학적 계산 지표",
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniResult(
                            "True Offset",
                            "${trueOffset.toStringAsFixed(1)} mm",
                          ),
                          _buildMiniResult(
                            "가로(Run)",
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
                    if (_bendRadius > 0 && finalTravel > 0) ...[
                      const Row(
                        children: [
                          Icon(
                            Icons.construction,
                            color: Colors.deepOrange,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            "현장 마킹 제원 (설정 R값 적용)",
                            style: TextStyle(
                              color: Colors.deepOrange,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "공제량 (Take-off)",
                                  style: TextStyle(
                                    color: Colors.deepOrange.shade800,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "- ${takeOff.toStringAsFixed(1)} mm",
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
                                  "실제 마킹 간격",
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
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
                                        : "에러")
                                  : (finalTravel > 0
                                        ? "${finalTravel.toStringAsFixed(1)} mm"
                                        : "대기"),
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
                        SizedBox(
                          width: 100, // 버튼 너비 고정
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
                              "도면 적용",
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

  Widget _buildCompactInputRow(TextEditingController ctrl, String hint) {
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
          onTap: () =>
              MakitaNumpadGlass.show(context, controller: ctrl, title: hint),
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
              borderSide: BorderSide(color: Colors.grey.shade300),
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
        onTap: () => ctrl.text = val.toStringAsFixed(val % 1 == 0 ? 0 : 1),
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
