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
  bool _isReverseMode = true;

  final TextEditingController _riseCtrl = TextEditingController(text: "150");
  final TextEditingController _rollCtrl = TextEditingController(text: "200");
  final TextEditingController _travelCtrl = TextEditingController(text: "350");
  final TextEditingController _rollAngleCtrl = TextEditingController(
    text: "30",
  );
  final TextEditingController _angleCtrl = TextEditingController(text: "45");

  @override
  void initState() {
    super.initState();
    _riseCtrl.addListener(() => setState(() {}));
    _rollCtrl.addListener(() => setState(() {}));
    _travelCtrl.addListener(() => setState(() {}));
    _rollAngleCtrl.addListener(() => setState(() {}));
    _angleCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _riseCtrl.dispose();
    _rollCtrl.dispose();
    _travelCtrl.dispose();
    _rollAngleCtrl.dispose();
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

    double bendAngle = double.tryParse(_angleCtrl.text) ?? 0;
    double bendRad = bendAngle * math.pi / 180.0;

    double rise = 0;
    double roll = 0;
    double travel = 0;
    double rollAngle = 0;
    double trueOffset = 0;

    if (_isReverseMode) {
      travel = double.tryParse(_travelCtrl.text) ?? 0;
      rollAngle = double.tryParse(_rollAngleCtrl.text) ?? 0;
      double rollRad = rollAngle * math.pi / 180.0;

      if (bendAngle > 0) {
        trueOffset = travel * math.sin(bendRad);
        rise = trueOffset * math.cos(rollRad);
        roll = trueOffset * math.sin(rollRad);
      }
    } else {
      rise = double.tryParse(_riseCtrl.text) ?? 0;
      roll = double.tryParse(_rollCtrl.text) ?? 0;

      trueOffset = math.sqrt(math.pow(rise, 2) + math.pow(roll, 2));

      if (rise > 0 || roll > 0) {
        rollAngle = math.atan2(roll, rise) * (180.0 / math.pi);
        if (rollAngle < 0) rollAngle += 360;
      }

      if (bendAngle > 0) {
        travel = trueOffset / math.sin(bendRad);
      }
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight), // 🚀 유동 높이 적용
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: makitaTeal, width: 3)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min, // 🚀 내용물 크기만큼만 잡히도록
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
                            "역산 (길이·각도)",
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
                            "정산 (수직·수평)",
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
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (_isReverseMode) ...[
                _buildCompactInputRow(_travelCtrl, "빗변 길이 (Travel)"),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactInputRow(_angleCtrl, "벤딩 각도 (∠)"),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCompactInputRow(
                        _rollAngleCtrl,
                        "회전 각도 (Roll ∠)",
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactInputRow(_riseCtrl, "수직 (Rise)"),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCompactInputRow(_rollCtrl, "수평 (Roll)"),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildCompactInputRow(_angleCtrl, "벤딩 각도 (∠)"),
              ],

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

              const SizedBox(height: 32), // 🚀 6축이 빠진 자리에 여백 확보

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildResultText(
                          "True Offset",
                          "${trueOffset.toStringAsFixed(1)} mm",
                        ),
                        const SizedBox(height: 4),
                        if (_isReverseMode) ...[
                          _buildResultText(
                            "수직(Rise)",
                            "${rise.toStringAsFixed(1)} mm",
                          ),
                          _buildResultText(
                            "수평(Roll)",
                            "${roll.toStringAsFixed(1)} mm",
                          ),
                        ] else ...[
                          _buildResultText(
                            "회전 각도",
                            "${rollAngle.toStringAsFixed(1)}°",
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        "빗변 (Travel)",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      Text(
                        travel > 0
                            ? "${travel.toStringAsFixed(1)} mm"
                            : "입력 대기",
                        style: TextStyle(
                          color: travel > 0 ? makitaTeal : Colors.white54,
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
                          if (travel > 0 && bendAngle > 0) {
                            double roundedTravel = double.parse(
                              travel.toStringAsFixed(1),
                            );

                            // 🚀 6축 방향이 빠진 핵심 로직 (자동 계산)
                            // 1. 현재 파이프가 뻗어 나가는 방향(currentRotation)에
                            //    계산된 롤 각도(rollAngle)를 더해서 대각선으로 꺾어 올릴 타겟 방향(r1) 산출
                            double r1 =
                                (widget.currentRotation + rollAngle) % 360.0;

                            // 2. 평행을 맞추기 위해 그 타겟 방향에서 정확히 180도 뒤집은 방향(r2) 산출
                            double r2 = _getOppositeRotation(r1);

                            widget.onAddBend(0.0, bendAngle, r1);
                            widget.onAddBend(roundedTravel, bendAngle, r2);

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
            width: 80,
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
