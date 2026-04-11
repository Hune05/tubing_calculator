// lib/src/presentation/calculator/widgets/rolling_offset_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math' as math;
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad_glass.dart';
import 'package:tubing_calculator/src/core/utils/settings_manager.dart';

const Color makitaTeal = Color(0xFF007580);
const Color panelBg = Color(0xFF2A2A2A); // 태블릿 전용 다크 배경
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
  bool _isReverseMode = false;
  double? _selectedRotation;
  double _bendRadius = 0.0; // 벤더 R값

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
    _loadSettings();
    _riseCtrl.addListener(() => setState(() {}));
    _rollCtrl.addListener(() => setState(() {}));
    _travelCtrl.addListener(() => setState(() {}));
    _angleCtrl.addListener(() => setState(() {}));
  }

  Future<void> _loadSettings() async {
    try {
      final data = await SettingsManager.loadSettings();
      if (mounted) {
        setState(() {
          _bendRadius = data['bendRadius'] ?? 0.0;
        });
      }
    } catch (e) {
      debugPrint("설정 로드 실패: $e");
    }
  }

  @override
  void dispose() {
    _riseCtrl.dispose();
    _rollCtrl.dispose();
    _travelCtrl.dispose();
    _angleCtrl.dispose();
    super.dispose();
  }

  double _getOppositeRotation(double currentRot) {
    if (currentRot == 360.0) return 450.0;
    if (currentRot == 450.0) return 360.0;
    return (currentRot + 180.0) % 360.0;
  }

  void _applyRolling(
    double finalTravel,
    double finalBendAngle,
    double rollAngle,
  ) {
    if (_selectedRotation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("진행할 기준면 축을 먼저 선택해주세요!"),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }
    if (finalTravel > 0 && finalBendAngle > 0) {
      double r1 = (_selectedRotation! + rollAngle) % 360.0;
      double r2 = _getOppositeRotation(r1);
      widget.onAddBend(
        0.0,
        double.parse(finalBendAngle.toStringAsFixed(1)),
        r1,
      );
      widget.onAddBend(
        double.parse(finalTravel.toStringAsFixed(1)),
        double.parse(finalBendAngle.toStringAsFixed(1)),
        r2,
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    double rise = double.tryParse(_riseCtrl.text) ?? 0;
    double roll = double.tryParse(_rollCtrl.text) ?? 0;
    double trueOffset = math.sqrt(math.pow(rise, 2) + math.pow(roll, 2));
    double rollAngle = (rise > 0 || roll > 0)
        ? (math.atan2(roll, rise) * (180.0 / math.pi))
        : 0;
    if (rollAngle < 0) rollAngle += 360;

    double finalTravel = 0, finalBendAngle = 0, advance = 0;

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

    // 테이크오프 및 현장 마킹 거리 계산
    double takeOff = 0, markingDistance = 0;
    if (_bendRadius > 0 && finalBendAngle > 0) {
      takeOff =
          _bendRadius * math.tan((finalBendAngle / 2.0) * (math.pi / 180.0));
      if (finalTravel > 0) markingDistance = finalTravel - takeOff;
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
                  _buildModeSwitcher(),
                  const SizedBox(height: 24),
                  _buildInputs(),
                  const SizedBox(height: 24),
                  _buildDirectionSelector(),
                  const SizedBox(height: 24),
                  _buildResultPanel(
                    trueOffset,
                    advance,
                    rollAngle,
                    finalTravel,
                    finalBendAngle,
                    takeOff,
                    markingDistance,
                  ),
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
            Icon(LucideIcons.orbit, color: makitaTeal, size: 28),
            SizedBox(width: 12),
            Text(
              "롤링 오프셋 패널 (V2)",
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

  Widget _buildModeSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildModeBtn(
            "정산 (각도 입력)",
            !_isReverseMode,
            () => setState(() => _isReverseMode = false),
          ),
          _buildModeBtn(
            "역산 (빗변 입력)",
            _isReverseMode,
            () => setState(() => _isReverseMode = true),
          ),
        ],
      ),
    );
  }

  Widget _buildModeBtn(String label, bool isActive, VoidCallback onTap) {
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputs() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildCompactInputRow(_riseCtrl, "수직 거리 (Rise)")),
            const SizedBox(width: 16),
            Expanded(child: _buildCompactInputRow(_rollCtrl, "수평 거리 (Roll)")),
          ],
        ),
        const SizedBox(height: 16),
        if (_isReverseMode)
          _buildCompactInputRow(_travelCtrl, "가진 파이프 빗변 (Travel)")
        else ...[
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
                    children: [22.5, 30.0, 45.0, 60.0, 90.0]
                        .map((val) => _buildQuickAngleBtn(_angleCtrl, val))
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDirectionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "진행할 기준면 축 지정 (6축)",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 3.5,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _directions.length,
          itemBuilder: (context, index) {
            final dir = _directions[index];
            bool isSelected = _selectedRotation == dir['val'];
            return InkWell(
              onTap: () => setState(() => _selectedRotation = dir['val']),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? makitaTeal : Colors.black45,
                  border: Border.all(
                    color: isSelected ? makitaTeal : Colors.white12,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      dir['icon'],
                      size: 18,
                      color: isSelected ? Colors.white : Colors.white54,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dir['label'].split(' ')[0],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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

  Widget _buildResultPanel(
    double trueOffset,
    double run,
    double rollAngle,
    double travel,
    double angle,
    double takeOff,
    double marking,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          // 1. 계산 지표 (태블릿 가로 배열)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetric(
                "True Offset",
                "${trueOffset.toStringAsFixed(1)} mm",
              ),
              _buildMetric("진행 거리(Run)", "${run.toStringAsFixed(1)} mm"),
              _buildMetric("회전각(Roll ∠)", "${rollAngle.toStringAsFixed(1)}°"),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 20),

          // 2. 실무 마킹 데이터 (오렌지 강조)
          if (_bendRadius > 0 && travel > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.construction,
                    color: Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetric(
                      "공제량(Take-off)",
                      "- ${takeOff.toStringAsFixed(1)} mm",
                      color: Colors.orange.shade300,
                    ),
                  ),
                  Expanded(
                    child: _buildMetric(
                      "실제 마킹 간격",
                      "${marking.toStringAsFixed(1)} mm",
                      color: Colors.orange,
                      isBold: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 3. 메인 타겟 및 적용 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isReverseMode ? "목표 벤딩 각도 (∠)" : "필요한 빗변 (Travel)",
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  Text(
                    _isReverseMode
                        ? "${angle.toStringAsFixed(1)}°"
                        : "${travel.toStringAsFixed(1)} mm",
                    style: const TextStyle(
                      color: makitaTeal,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 54,
                width: 160,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: makitaTeal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _applyRolling(travel, angle, rollAngle),
                  child: const Text(
                    "도면 적용",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(
    String label,
    String value, {
    Color? color,
    bool isBold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 16,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
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
}
