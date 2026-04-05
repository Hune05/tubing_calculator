import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math' as math;

// 🚀 SettingsManager import (경로는 프로젝트에 맞게 수정하세요)
import 'package:tubing_calculator/src/core/utils/settings_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad_glass.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class MobileOffsetBottomSheet extends StatefulWidget {
  final double currentRotation;
  final Function(List<Map<String, double>> bends) onAddMultipleBends;

  const MobileOffsetBottomSheet({
    super.key,
    required this.currentRotation,
    required this.onAddMultipleBends,
  });

  static void show(
    BuildContext context, {
    required double currentRotation,
    required Function(List<Map<String, double>>) onAddMultipleBends,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MobileOffsetBottomSheet(
        currentRotation: currentRotation,
        onAddMultipleBends: onAddMultipleBends,
      ),
    );
  }

  @override
  State<MobileOffsetBottomSheet> createState() =>
      _MobileOffsetBottomSheetState();
}

class _MobileOffsetBottomSheetState extends State<MobileOffsetBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isInverted = false;
  double? _selectedRotation;

  // 🚀 장비 제원 데이터 변수
  double _machineRadius = 0.0;
  double _machineGain = 0.0;
  double _userOffsetShrink = 0.0;

  final TextEditingController _heightCtrl = TextEditingController(text: "100");
  final TextEditingController _angleCtrl = TextEditingController(text: "45");
  final TextEditingController _travelCtrl = TextEditingController(text: "150");

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
    _tabController = TabController(length: 2, vsync: this);
    _heightCtrl.addListener(() => setState(() {}));
    _angleCtrl.addListener(() => setState(() {}));
    _travelCtrl.addListener(() => setState(() {}));

    _loadMachineSettings();
  }

  Future<void> _loadMachineSettings() async {
    final data = await SettingsManager.loadSettings();
    if (mounted) {
      setState(() {
        _machineRadius = data['bendRadius'] ?? 0.0;
        _machineGain = data['gain'] ?? 0.0;
        _userOffsetShrink = data['offsetShrink'] ?? 0.0;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _heightCtrl.dispose();
    _angleCtrl.dispose();
    _travelCtrl.dispose();
    super.dispose();
  }

  void _adjustValue(TextEditingController ctrl, double amount) {
    double current = double.tryParse(ctrl.text) ?? 0;
    double next = current + amount;
    if (next < 0) next = 0;
    ctrl.text = next.toStringAsFixed(next % 1 == 0 ? 0 : 1);
  }

  void _applyBending(double angle, double travel) {
    if (_selectedRotation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("돌출 방향(Direction)을 먼저 선택해주세요!"),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }
    if (angle <= 0 || travel <= 0) return;

    double roundedAngle = double.parse(angle.toStringAsFixed(1));
    double roundedTravel = double.parse(travel.toStringAsFixed(1));

    double r1 = _isInverted
        ? (_selectedRotation! + 180.0) % 360.0
        : _selectedRotation!;
    double r2 = _isInverted
        ? _selectedRotation!
        : (_selectedRotation! + 180.0) % 360.0;

    widget.onAddMultipleBends([
      {'length': 0.0, 'angle': roundedAngle, 'rotation': r1},
      {'length': roundedTravel, 'angle': roundedAngle, 'rotation': r2},
    ]);
    Navigator.pop(context);
  }

  Widget _buildDirectionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "돌출 방향 지정 (6축)",
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
    double h = double.tryParse(_heightCtrl.text) ?? 0;
    double a = double.tryParse(_angleCtrl.text) ?? 0;
    double t = double.tryParse(_travelCtrl.text) ?? 0;

    double calcTravel = (a > 0 && a < 90)
        ? h / math.sin(a * math.pi / 180.0)
        : 0;
    double calcAngle = 0;
    bool inverseError = false;

    if (t > 0 && h > 0) {
      if (h > t) {
        inverseError = true;
      } else {
        calcAngle = math.asin(h / t) * 180.0 / math.pi;
      }
    }

    double targetAngle = _tabController.index == 0 ? a : calcAngle;
    double targetTravel = _tabController.index == 0 ? calcTravel : t;

    // 🚀 [추가] 직선 진행 거리(Run) 변수
    double calcRun = 0.0;
    double geometricShrink = 0.0;
    double totalGain = 0.0;

    if (targetAngle > 0 && targetAngle < 90 && h > 0 && targetTravel > 0) {
      double rad = targetAngle * math.pi / 180.0;

      // 1. 직선 진행 거리(Run) 계산!
      calcRun = h / math.tan(rad);

      // 2. 오프셋 축소량(Shrink) = 빗변(Travel) - 바닥변(Run)
      geometricShrink = targetTravel - calcRun;

      if (_userOffsetShrink > 0) {
        geometricShrink += _userOffsetShrink;
      }

      // 3. 연신율(Gain) = (2 * Setback) - ArcLength
      double gainPerBend = 0.0;
      if (_machineRadius > 0) {
        double setback = _machineRadius * math.tan(rad / 2);
        double arcLength = math.pi * _machineRadius * targetAngle / 180.0;
        gainPerBend = (2 * setback) - arcLength;
      } else if (_machineGain > 0) {
        gainPerBend = _machineGain * (targetAngle / 90.0);
      }
      totalGain = gainPerBend * 2;
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
                      Icon(LucideIcons.calculator, color: makitaTeal, size: 28),
                      SizedBox(width: 12),
                      Text(
                        "오프셋 계산기",
                        style: TextStyle(
                          color: slate900,
                          fontSize: 18,
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
              const SizedBox(height: 12),
              TabBar(
                controller: _tabController,
                indicatorColor: makitaTeal,
                labelColor: makitaTeal,
                unselectedLabelColor: slate600,
                tabs: const [
                  Tab(text: "정방향 (H+∠)"),
                  Tab(text: "역산 (H+Travel)"),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                "장애물 높이/깊이 (H)",
                style: TextStyle(
                  color: slate600,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildTextField(_heightCtrl, "높이 mm")),
                  const SizedBox(width: 12),
                  _buildQuickBtn(_heightCtrl, -5.0, "-5"),
                  const SizedBox(width: 4),
                  _buildQuickBtn(_heightCtrl, 5.0, "+5"),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  return _tabController.index == 0
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "각도 (∠)",
                              style: TextStyle(
                                color: slate600,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildTextField(_angleCtrl, "각도 °"),
                                ),
                                const SizedBox(width: 12),
                                ...[22.5, 30.0, 45.0, 60.0].map(
                                  (val) => _buildQuickAngleBtn(_angleCtrl, val),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _buildDirectionSelector(),
                            const SizedBox(height: 12),
                            _buildInvertToggle(),
                            const SizedBox(height: 16),
                            _buildResultBox(
                              title: "계산된 빗변 (Travel)",
                              value: calcTravel,
                              runDistance: calcRun, // 🚀 Run 추가
                              shrink: geometricShrink,
                              gain: totalGain,
                              btnText: "적용",
                              onPressed: () => _applyBending(a, calcTravel),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "현장 빗변 (Travel)",
                              style: TextStyle(
                                color: slate600,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(_travelCtrl, "거리 mm"),
                                ),
                                const SizedBox(width: 12),
                                _buildQuickBtn(_travelCtrl, -10.0, "-10"),
                                const SizedBox(width: 4),
                                _buildQuickBtn(_travelCtrl, 10.0, "+10"),
                              ],
                            ),
                            if (inverseError)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  "오류: 빗변은 높이보다 커야함!",
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
                            _buildDirectionSelector(),
                            const SizedBox(height: 12),
                            _buildInvertToggle(),
                            const SizedBox(height: 16),
                            _buildResultBox(
                              title: "계산된 각도 (∠)",
                              value: calcAngle,
                              runDistance: calcRun, // 🚀 Run 추가
                              shrink: geometricShrink,
                              gain: totalGain,
                              btnText: "적용",
                              isError: inverseError,
                              isAngle: true,
                              onPressed: () => _applyBending(calcAngle, t),
                            ),
                          ],
                        );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvertToggle() {
    return Align(
      alignment: Alignment.centerRight,
      child: InkWell(
        onTap: () => setState(() => _isInverted = !_isInverted),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isInverted ? Colors.red.shade50 : slate100,
            border: Border.all(
              color: _isInverted ? Colors.red.shade300 : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.swap_vert,
                color: _isInverted ? Colors.red.shade700 : slate600,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                _isInverted ? "아래로 파기(Invert)" : "위로 넘기(Normal)",
                style: TextStyle(
                  color: _isInverted ? Colors.red.shade700 : slate600,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint) {
    return TextField(
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
    );
  }

  Widget _buildQuickBtn(
    TextEditingController ctrl,
    double amount,
    String label,
  ) {
    return InkWell(
      onTap: () => _adjustValue(ctrl, amount),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: const TextStyle(color: slate900, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildQuickAngleBtn(TextEditingController ctrl, double val) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        onTap: () => ctrl.text = val.toStringAsFixed(val % 1 == 0 ? 0 : 1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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

  // 🚀 결과창 업데이트 (Run 영역 추가)
  Widget _buildResultBox({
    required String title,
    required double value,
    required double runDistance, // 🚀 새로 추가된 파라미터
    required double shrink,
    required double gain,
    required String btnText,
    required VoidCallback onPressed,
    bool isError = false,
    bool isAngle = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: makitaTeal.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: makitaTeal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 기존 메인 결과 (Travel 또는 Angle) & 적용 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: slate600,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value > 0 && !isError
                            ? "${value.toStringAsFixed(1)} ${isAngle ? "°" : "mm"}"
                            : "입력 대기",
                        style: TextStyle(
                          color: value > 0 && !isError
                              ? makitaTeal
                              : Colors.redAccent,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: makitaTeal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
                onPressed: onPressed,
                child: Text(
                  btnText,
                  style: const TextStyle(
                    color: pureWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // 2. 🚀 [추가됨] 직선 진행 거리(Run)와 추가 연신율/축소량 정보 패널
          if (value > 0 && !isError) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.black12, height: 1),
            const SizedBox(height: 12),

            // 👉 Run 표시 영역
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "직선 진행 거리 (Run)",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: slate600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${runDistance.toStringAsFixed(1)} mm",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: slate900,
                    fontFamily: 'monospace',
                  ),
                ),
                const Text(
                  "(바닥을 타고 앞으로 나아간 실제 직선 거리)",
                  style: TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(color: Colors.black12, height: 1),
            const SizedBox(height: 12),

            // 👉 기존 Shrink & Gain 표시 영역
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "오프셋 축소량",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "+${shrink.toStringAsFixed(1)} mm",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Text(
                        "(총 기장에 더함)",
                        style: TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.black12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "2포인트 연신율 (Gain)",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "-${gain.toStringAsFixed(1)} mm",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Text(
                        "(절단 기장에서 뺌)",
                        style: TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
