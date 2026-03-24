import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math' as math;

import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad_glass.dart';

const Color makitaTeal = Color(0xFF007580);
const Color panelBg = Color(0xFF2A2A2A);
const Color pureWhite = Color(0xFFFFFFFF);

class RollingOffsetBottomSheet extends StatefulWidget {
  final double currentRotation;
  final Function(double length, double angle, double rotation) onAddBend;

  const RollingOffsetBottomSheet({
    super.key,
    required this.currentRotation,
    required this.onAddBend,
  });

  static void show(
    BuildContext context, {
    required double currentRotation,
    required Function(double, double, double) onAddBend,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RollingOffsetBottomSheet(
        currentRotation: currentRotation,
        onAddBend: onAddBend,
      ),
    );
  }

  @override
  State<RollingOffsetBottomSheet> createState() =>
      _RollingOffsetBottomSheetState();
}

class _RollingOffsetBottomSheetState extends State<RollingOffsetBottomSheet> {
  // 기본값을 정산 모드로 시작
  bool _isReverseMode = false;

  final TextEditingController _riseCtrl = TextEditingController(text: "150");
  final TextEditingController _rollCtrl = TextEditingController(text: "200");
  final TextEditingController _travelCtrl = TextEditingController(text: "350");
  final TextEditingController _angleCtrl = TextEditingController(text: "45");
  // 🚀 수평/회전 각도는 Rise와 Roll 거리로 자동 계산되므로 입력 컨트롤러 삭제

  @override
  void initState() {
    super.initState();
    _riseCtrl.addListener(() => setState(() {}));
    _rollCtrl.addListener(() => setState(() {}));
    _travelCtrl.addListener(() => setState(() {}));
    _angleCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _riseCtrl.dispose();
    _rollCtrl.dispose();
    _travelCtrl.dispose();
    _angleCtrl.dispose();
    super.dispose();
  }

  // 🚀 3D 엔진용 180도 반전 함수
  double _getOppositeRotation(double currentRot) {
    if (currentRot == 360.0) return 450.0;
    if (currentRot == 450.0) return 360.0;
    return (currentRot + 180.0) % 360.0;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    // 1. 공통 입력값 파싱 (거리는 수직, 수평으로 고정)
    double rise = double.tryParse(_riseCtrl.text) ?? 0;
    double roll = double.tryParse(_rollCtrl.text) ?? 0;

    // 2. 공통 계산 (True Offset 및 회전 각도는 자동 계산!)
    double trueOffset = math.sqrt(math.pow(rise, 2) + math.pow(roll, 2));
    double rollAngle = 0;
    if (rise > 0 || roll > 0) {
      rollAngle = math.atan2(roll, rise) * (180.0 / math.pi);
      if (rollAngle < 0) rollAngle += 360;
    }

    // 3. 모드에 따른 최종 결과값 도출
    double finalTravel = 0;
    double finalBendAngle = 0;
    double advance = 0; // 🚀 가로 길이(Run/Advance) 변수 추가

    if (_isReverseMode) {
      // 🚀 [역산] 빗변 길이 입력 -> 벤딩 각도 및 가로 길이 도출
      finalTravel = double.tryParse(_travelCtrl.text) ?? 0;
      if (finalTravel > 0 && trueOffset <= finalTravel) {
        // 아크사인(asin)을 이용하여 정확한 벤딩 각도 계산
        finalBendAngle =
            math.asin(trueOffset / finalTravel) * (180.0 / math.pi);
        // 피타고라스 정리로 가로 길이 계산: √(빗변² - 밑변²)
        advance = math.sqrt(math.pow(finalTravel, 2) - math.pow(trueOffset, 2));
      }
    } else {
      // 🚀 [정산] 벤딩 각도 입력 -> 빗변 길이 및 가로 길이 도출
      finalBendAngle = double.tryParse(_angleCtrl.text) ?? 0;
      if (finalBendAngle > 0 && finalBendAngle < 180) {
        double bendRad = finalBendAngle * math.pi / 180.0;
        finalTravel = trueOffset / math.sin(bendRad);
        // 탄젠트를 이용하여 가로 길이 계산 (밑변 / tan(각도))
        // 90도일 경우 가로 길이는 0이 되도록 처리
        advance = finalBendAngle == 90.0 ? 0 : trueOffset / math.tan(bendRad);
      }
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: makitaTeal, width: 3)),
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
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                decoration: BoxDecoration(
                  color: Colors.black45,
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
                              color: !_isReverseMode
                                  ? Colors.white
                                  : Colors.white54,
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
                              color: _isReverseMode
                                  ? Colors.white
                                  : Colors.white54,
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

              // 🚀 공통 입력: 수직, 수평 거리는 무조건 최상단에 고정
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

              // 🚀 모드에 따라 3번째 입력창 토글
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
                        style: TextStyle(color: Colors.white54, fontSize: 12),
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

              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 좌측 보조 결과창 (자동 계산된 값들)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildResultText(
                          "True Offset",
                          "${trueOffset.toStringAsFixed(1)} mm",
                        ),
                        const SizedBox(height: 4),
                        // 🚀 가로 길이 결과 표시 추가
                        _buildResultText(
                          "가로 길이 (Run)",
                          "${advance.toStringAsFixed(1)} mm",
                        ),
                        const SizedBox(height: 4),
                        _buildResultText(
                          "자동 회전각", // 명확하게 자동 계산됨을 알림
                          "${rollAngle.toStringAsFixed(1)}°",
                        ),
                      ],
                    ),
                  ),
                  // 🚀 우측 메인 결과창 (핵심: 역산이면 각도를, 정산이면 빗변을 띄움)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _isReverseMode ? "목표 벤딩 각도 (∠)" : "필요한 빗변 (Travel)",
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _isReverseMode
                            ? (finalBendAngle > 0
                                  ? "${finalBendAngle.toStringAsFixed(1)}°"
                                  : "입력 에러")
                            : (finalTravel > 0
                                  ? "${finalTravel.toStringAsFixed(1)} mm"
                                  : "입력 대기"),
                        style: TextStyle(
                          color:
                              (_isReverseMode
                                  ? finalBendAngle > 0
                                  : finalTravel > 0)
                              ? makitaTeal
                              : Colors.redAccent, // 에러 시 빨간색 강조
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: makitaTeal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          // 값이 모두 정상일 때만 3D 뷰로 넘김
                          if (finalTravel > 0 && finalBendAngle > 0) {
                            double roundedTravel = double.parse(
                              finalTravel.toStringAsFixed(1),
                            );
                            double roundedBendAngle = double.parse(
                              finalBendAngle.toStringAsFixed(1),
                            );

                            double r1 =
                                (widget.currentRotation + rollAngle) % 360.0;
                            double r2 = _getOppositeRotation(r1);

                            widget.onAddBend(0.0, roundedBendAngle, r1);
                            widget.onAddBend(
                              roundedTravel,
                              roundedBendAngle,
                              r2,
                            );

                            Navigator.pop(context);
                          }
                        },
                        child: const Text(
                          "적용",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 85, // 글자가 잘리지 않도록 너비를 살짝 늘렸습니다.
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInputRow(TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hint,
          style: const TextStyle(
            color: Colors.white70,
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
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black45,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
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
            color: Colors.black45,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            val % 1 == 0 ? "${val.toInt()}°" : "$val°",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
