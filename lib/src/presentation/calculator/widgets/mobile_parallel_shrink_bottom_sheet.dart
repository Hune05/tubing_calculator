import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad_glass.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class MobileParallelShrinkBottomSheet extends StatefulWidget {
  final double? initialAngle;
  const MobileParallelShrinkBottomSheet({super.key, this.initialAngle});

  static void show(BuildContext context, {double? currentAngle}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          MobileParallelShrinkBottomSheet(initialAngle: currentAngle),
    );
  }

  @override
  State<MobileParallelShrinkBottomSheet> createState() =>
      _MobileParallelShrinkBottomSheetState();
}

class _MobileParallelShrinkBottomSheetState
    extends State<MobileParallelShrinkBottomSheet> {
  bool _isParallelMode = true;
  bool _is3DMode = false;

  final TextEditingController _spacingCtrl = TextEditingController(text: "50");
  final TextEditingController _riseCtrl = TextEditingController(text: "150");
  final TextEditingController _rollCtrl = TextEditingController(text: "200");
  late TextEditingController _angleCtrl;

  int _pipeIndex = 1;

  @override
  void initState() {
    super.initState();
    double initAng =
        (widget.initialAngle != null &&
            widget.initialAngle! > 0 &&
            widget.initialAngle! <= 90)
        ? widget.initialAngle!
        : 45.0;
    _angleCtrl = TextEditingController(
      text: initAng.toStringAsFixed(initAng % 1 == 0 ? 0 : 1),
    );
    _spacingCtrl.addListener(() => setState(() {}));
    _riseCtrl.addListener(() => setState(() {}));
    _rollCtrl.addListener(() => setState(() {}));
    _angleCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _spacingCtrl.dispose();
    _riseCtrl.dispose();
    _rollCtrl.dispose();
    _angleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    double angle = double.tryParse(_angleCtrl.text) ?? 0.0;
    double spacing = double.tryParse(_spacingCtrl.text) ?? 0.0;
    double trueRise = 0;
    double finalResult = 0;

    if (_is3DMode) {
      double r = double.tryParse(_riseCtrl.text) ?? 0;
      double rl = double.tryParse(_rollCtrl.text) ?? 0;
      trueRise = math.sqrt((r * r) + (rl * rl));
    } else {
      trueRise = double.tryParse(_riseCtrl.text) ?? 0;
    }

    if (_isParallelMode) {
      if (angle > 0 && spacing > 0) {
        if (angle == 90.0)
          finalResult = spacing * _pipeIndex * 1.5708;
        else
          finalResult =
              spacing * _pipeIndex * math.tan((angle / 2) * (math.pi / 180));
      }
    } else {
      if (angle > 0 && angle < 90.0 && trueRise > 0) {
        double rad = angle * (math.pi / 180);
        finalResult = trueRise * ((1 / math.sin(rad)) - (1 / math.tan(rad)));
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
            mainAxisSize: MainAxisSize.min, // 여백 제거
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.layoutGrid, color: makitaTeal, size: 28),
                      SizedBox(width: 12),
                      Text(
                        "평행 & 축소 계산기",
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
              _buildToggleBox(
                "평행 계산기",
                "축소값 계산기",
                _isParallelMode,
                () => setState(() => _isParallelMode = true),
                () => setState(() => _isParallelMode = false),
              ),
              const SizedBox(height: 12),
              _buildToggleBox(
                "2D 평면 (일반)",
                "3D 입체 (롤링)",
                !_is3DMode,
                () => setState(() => _is3DMode = false),
                () => setState(() => _is3DMode = true),
              ),
              const SizedBox(height: 24),
              if (_isParallelMode) ...[
                _buildCompactInputRow(_spacingCtrl, "배관 간격 (Spacing)"),
                if (_is3DMode) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactInputRow(
                          _riseCtrl,
                          "장애물 수직 높이 (Rise)",
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCompactInputRow(
                          _rollCtrl,
                          "장애물 수평 이동 (Roll)",
                        ),
                      ),
                    ],
                  ),
                ],
              ] else ...[
                if (!_is3DMode)
                  _buildCompactInputRow(_riseCtrl, "목표 높이 (Rise)")
                else
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactInputRow(_riseCtrl, "수직 높이 (Rise)"),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCompactInputRow(_rollCtrl, "수평 이동 (Roll)"),
                      ),
                    ],
                  ),
              ],
              const SizedBox(height: 12),
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
              const SizedBox(height: 16),
              if (_isParallelMode) ...[
                const Text(
                  "옆 가닥 번호",
                  style: TextStyle(
                    color: slate600,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    1,
                    2,
                    3,
                    4,
                    5,
                  ].map((idx) => _buildPipeIndexBtn(idx)).toList(),
                ),
              ],
              const SizedBox(height: 32),

              // 🚀 [핵심 수정] 가이드와 결과값을 위아래로 분리하여 시인성 확보
              Container(
                width: double.infinity, // 전체 너비 사용
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: makitaTeal.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: makitaTeal.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. 가이드 영역 (위쪽)
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: makitaTeal,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "마킹 가이드",
                          style: TextStyle(
                            color: makitaTeal,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (_is3DMode) ...[
                          const Spacer(),
                          Text(
                            "True Offset: ${trueRise.toStringAsFixed(1)} mm",
                            style: const TextStyle(
                              color: slate600,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: pureWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        _isParallelMode
                            ? "배관 간격 유지를 위해 기존 마킹점에서\n진입 시(+), 탈출 시(-) 연산하여 마킹합니다."
                            : "간섭 회피를 위해 첫 번째 벤딩 마킹점을\n기존 길이에서 아래 수치만큼 뒤로 미룹니다.",
                        style: const TextStyle(
                          color: slate900,
                          fontSize: 12,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. 메인 결과 영역 (아래쪽)
                    Text(
                      _isParallelMode
                          ? "$_pipeIndex번 보정치 (Stagger)"
                          : "첫 벤딩 미루기 (Shrink)",
                      style: const TextStyle(
                        color: slate600,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      finalResult > 0
                          ? "+${finalResult.toStringAsFixed(1)} mm"
                          : "계산 대기중",
                      style: TextStyle(
                        color: finalResult > 0 ? makitaTeal : Colors.redAccent,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
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

  Widget _buildToggleBox(
    String leftLabel,
    String rightLabel,
    bool isLeftActive,
    VoidCallback onLeft,
    VoidCallback onRight,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: slate100,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: isLeftActive ? makitaTeal : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    leftLabel,
                    style: TextStyle(
                      color: isLeftActive ? pureWhite : slate600,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: !isLeftActive ? makitaTeal : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    rightLabel,
                    style: TextStyle(
                      color: !isLeftActive ? pureWhite : slate600,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
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

  Widget _buildPipeIndexBtn(int idx) {
    bool isActive = _pipeIndex == idx;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: () => setState(() => _pipeIndex = idx),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? makitaTeal : pureWhite,
            border: Border.all(
              color: isActive ? makitaTeal : Colors.grey.shade300,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            "$idx",
            style: TextStyle(
              color: isActive ? pureWhite : slate900,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
