// lib/src/presentation/calculator/widgets/parallel_shrink_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad_glass.dart';

const Color makitaTeal = Color(0xFF007580);
const Color panelBg = Color(0xFF2A2A2A); // 태블릿 전용 다크 배경
const Color pureWhite = Color(0xFFFFFFFF);

class ParallelShrinkBottomSheet extends StatefulWidget {
  final double? initialAngle;
  const ParallelShrinkBottomSheet({super.key, this.initialAngle});

  static void show(BuildContext context, {double? currentAngle}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          ParallelShrinkBottomSheet(initialAngle: currentAngle),
    );
  }

  @override
  State<ParallelShrinkBottomSheet> createState() =>
      _ParallelShrinkBottomSheetState();
}

class _ParallelShrinkBottomSheetState extends State<ParallelShrinkBottomSheet> {
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
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 720,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Container(
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
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildModeToggles(),
                  const SizedBox(height: 24),
                  _buildInputs(),
                  const SizedBox(height: 24),
                  if (_isParallelMode) _buildPipeSelector(),
                  const SizedBox(height: 32),
                  _buildResultPanel(trueRise, finalResult),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Row(
          children: [
            Icon(LucideIcons.layoutGrid, color: makitaTeal, size: 28),
            SizedBox(width: 12),
            Text(
              "평행 & 축소 계산기 (V2)",
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
    );
  }

  Widget _buildModeToggles() {
    return Column(
      children: [
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
      ],
    );
  }

  Widget _buildInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isParallelMode)
          _buildCompactInputRow(_spacingCtrl, "배관 간격 (Spacing)")
        else
          _is3DMode
              ? Row(
                  children: [
                    Expanded(
                      child: _buildCompactInputRow(_riseCtrl, "수직 높이 (Rise)"),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildCompactInputRow(_rollCtrl, "수평 이동 (Roll)"),
                    ),
                  ],
                )
              : _buildCompactInputRow(_riseCtrl, "목표 높이 (Rise)"),

        if (_isParallelMode && _is3DMode) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCompactInputRow(_riseCtrl, "장애물 수직 높이 (Rise)"),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCompactInputRow(_rollCtrl, "장애물 수평 이동 (Roll)"),
              ),
            ],
          ),
        ],

        const SizedBox(height: 16),
        _buildCompactInputRow(_angleCtrl, "벤딩 각도 (∠)"),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text(
              "빠른 각도:",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    22.5,
                    30.0,
                    45.0,
                    60.0,
                    90.0,
                  ].map((val) => _buildQuickAngleBtn(_angleCtrl, val)).toList(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPipeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "옆 가닥 번호",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
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
    );
  }

  Widget _buildResultPanel(double trueRise, double finalResult) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: makitaTeal, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "마킹 가이드",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isParallelMode
                          ? "배관 간격 유지를 위해 기존 마킹점에서 진입 시(+), 탈출 시(-) 연산하여 마킹합니다."
                          : "간섭 회피를 위해 첫 번째 벤딩 마킹점을 기존 길이에서 아래 수치만큼 뒤로 미룹니다.",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (_is3DMode)
                _buildMetric(
                  "True Offset",
                  "${trueRise.toStringAsFixed(1)} mm",
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isParallelMode
                    ? "$_pipeIndex번 보정치 (Stagger)"
                    : "첫 벤딩 미루기 (Shrink)",
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                finalResult > 0
                    ? "+${finalResult.toStringAsFixed(1)} mm"
                    : "계산 대기중",
                style: TextStyle(
                  color: finalResult > 0 ? makitaTeal : Colors.redAccent,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildToggleBtn(leftLabel, isLeftActive, onLeft),
          _buildToggleBtn(rightLabel, !isLeftActive, onRight),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String label, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? makitaTeal : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white54,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: makitaTeal,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildCompactInputRow(TextEditingController ctrl, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          readOnly: true,
          onTap: () =>
              MakitaNumpadGlass.show(context, controller: ctrl, title: label),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
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
      padding: const EdgeInsets.only(right: 8.0),
      child: InkWell(
        onTap: () => ctrl.text = val.toStringAsFixed(val % 1 == 0 ? 0 : 1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Text(
            "${val % 1 == 0 ? val.toInt() : val}°",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPipeIndexBtn(int idx) {
    bool isActive = _pipeIndex == idx;
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: GestureDetector(
        onTap: () => setState(() => _pipeIndex = idx),
        child: Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? makitaTeal : Colors.black45,
            border: Border.all(
              color: isActive ? makitaTeal : Colors.white12,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            "$idx",
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
