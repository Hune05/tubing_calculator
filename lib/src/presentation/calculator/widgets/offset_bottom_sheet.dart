import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math' as math;
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad_glass.dart';

const Color makitaTeal = Color(0xFF007580);
const Color panelBg = Color(0xFF2A2A2A);
const Color pureWhite = Color(0xFFFFFFFF);

class OffsetBottomSheet extends StatefulWidget {
  final double currentRotation;
  final Function(double length, double angle, double rotation) onAddBend;

  const OffsetBottomSheet({
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
      builder: (context) => OffsetBottomSheet(
        currentRotation: currentRotation,
        onAddBend: onAddBend,
      ),
    );
  }

  @override
  State<OffsetBottomSheet> createState() => _OffsetBottomSheetState();
}

class _OffsetBottomSheetState extends State<OffsetBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _heightCtrl = TextEditingController(text: "100");
  final TextEditingController _angleCtrl = TextEditingController(text: "45");
  final TextEditingController _travelCtrl = TextEditingController(text: "150");

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _heightCtrl.addListener(() => setState(() {}));
    _angleCtrl.addListener(() => setState(() {}));
    _travelCtrl.addListener(() => setState(() {}));
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

  // 평행을 맞추기 위한 180도 반전 회전값 계산
  double _getOppositeRotation(double currentRot) {
    if (currentRot == 360.0) return 450.0;
    if (currentRot == 450.0) return 360.0;
    return (currentRot + 180.0) % 360.0;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

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
                      "오프셋(Offset)",
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
            TabBar(
              controller: _tabController,
              indicatorColor: makitaTeal,
              labelColor: makitaTeal,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(text: "정방향 (H+∠)"),
                Tab(text: "역산 (H+Travel)"),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              "장애물 높이/깊이 (H)",
              style: TextStyle(color: Colors.white70, fontSize: 13),
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
            const SizedBox(height: 20),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // 🚀 탭 1: 정방향 오프셋
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "벤딩 각도 (∠)",
                          style: TextStyle(color: Colors.white70, fontSize: 13),
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
                        _buildResultBox(
                          title: "필요 빗변 길이 (Travel)",
                          value: calcTravel,
                          btnText: "적용",
                          isError: false,
                          onPressed: () {
                            if (calcTravel > 0 && a > 0) {
                              double roundedTravel = double.parse(
                                calcTravel.toStringAsFixed(1),
                              );
                              // 🚀 사용자가 선택하는 대신, 기존 진행 방향을 그대로 활용하여 평행 오프셋 구성
                              double oppRot = _getOppositeRotation(
                                widget.currentRotation,
                              );

                              widget.onAddBend(0.0, a, widget.currentRotation);
                              widget.onAddBend(roundedTravel, a, oppRot);
                              Navigator.pop(context);
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  // 🚀 탭 2: 역산 오프셋
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "현장 빗변 길이 (Travel)",
                          style: TextStyle(color: Colors.white70, fontSize: 13),
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
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text(
                              "오류: 빗변(Travel)은 높이(H)보다 길어야 합니다!",
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        _buildResultBox(
                          title: "필요 각도 (∠)",
                          value: calcAngle,
                          btnText: "적용",
                          isError: inverseError,
                          isAngle: true,
                          onPressed: () {
                            if (t > 0 && calcAngle > 0 && !inverseError) {
                              double roundedAngle = double.parse(
                                calcAngle.toStringAsFixed(1),
                              );
                              // 🚀 탭 2에서도 마찬가지로 기존 진행 방향 활용
                              double oppRot = _getOppositeRotation(
                                widget.currentRotation,
                              );

                              widget.onAddBend(
                                0.0,
                                roundedAngle,
                                widget.currentRotation,
                              );
                              widget.onAddBend(t, roundedAngle, oppRot);
                              Navigator.pop(context);
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
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
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
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
          color: Colors.black45,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAngleBtn(TextEditingController ctrl, double val) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: InkWell(
        onTap: () => ctrl.text = val.toStringAsFixed(val % 1 == 0 ? 0 : 1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultBox({
    required String title,
    required double value,
    required String btnText,
    required VoidCallback onPressed,
    bool isError = false,
    bool isAngle = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: makitaTeal.withAlpha(40),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: makitaTeal),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Text(
                value > 0 && !isError
                    ? "${value.toStringAsFixed(1)} ${isAngle ? "°" : "mm"}"
                    : "입력 대기",
                style: TextStyle(
                  color: value > 0 && !isError
                      ? Colors.white
                      : Colors.redAccent,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: makitaTeal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            onPressed: onPressed,
            child: Text(
              btnText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
