import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math' as math;
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad_glass.dart';

const Color makitaTeal = Color(0xFF007580);
const Color panelBg = Color(0xFF2A2A2A);

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

  bool _isInverted = false; // 🚀 방향 반전 스위치

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
      if (h > t)
        inverseError = true;
      else
        calcAngle = math.asin(h / t) * 180.0 / math.pi;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: 530,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: makitaTeal, width: 3)),
        ),
        child: Column(
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "각도 (∠)",
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
                          ...[
                            22.5,
                            30.0,
                            45.0,
                            60.0,
                          ].map((val) => _buildQuickAngleBtn(_angleCtrl, val)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [_buildInvertToggle()],
                      ), // 🚀 반전 토글
                      const SizedBox(height: 8),
                      _buildResultBox(
                        title: "빗변 길이 (Travel)",
                        value: calcTravel,
                        btnText: "추가",
                        isError: false,
                        onPressed: () {
                          if (calcTravel > 0 && a > 0) {
                            double roundedTravel = double.parse(
                              calcTravel.toStringAsFixed(1),
                            );
                            // 🔥 반전 여부에 따라 각도 뒤집기
                            double r1 = _isInverted
                                ? (widget.currentRotation + 180.0) % 360.0
                                : widget.currentRotation;
                            double r2 = _isInverted
                                ? widget.currentRotation
                                : (widget.currentRotation + 180.0) % 360.0;
                            widget.onAddBend(0.0, a, r1);
                            widget.onAddBend(roundedTravel, a, r2);
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "빗변 길이 (Travel)",
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
                            "오류: 빗변은 높이보다 커야함!",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [_buildInvertToggle()],
                      ), // 🚀 반전 토글
                      const SizedBox(height: 8),
                      _buildResultBox(
                        title: "각도 (∠)",
                        value: calcAngle,
                        btnText: "추가",
                        isError: inverseError,
                        isAngle: true,
                        onPressed: () {
                          if (t > 0 && calcAngle > 0 && !inverseError) {
                            double roundedAngle = double.parse(
                              calcAngle.toStringAsFixed(1),
                            );
                            double r1 = _isInverted
                                ? (widget.currentRotation + 180.0) % 360.0
                                : widget.currentRotation;
                            double r2 = _isInverted
                                ? widget.currentRotation
                                : (widget.currentRotation + 180.0) % 360.0;
                            widget.onAddBend(0.0, roundedAngle, r1);
                            widget.onAddBend(t, roundedAngle, r2);
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🚀 반전 토글 UI
  Widget _buildInvertToggle() {
    return InkWell(
      onTap: () => setState(() => _isInverted = !_isInverted),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _isInverted
              ? Colors.redAccent.withOpacity(0.2)
              : Colors.black45,
          border: Border.all(
            color: _isInverted ? Colors.redAccent : Colors.white24,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_vert,
              color: _isInverted ? Colors.redAccent : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _isInverted ? "반전 (아래로 파기)" : "정방향 (위로 넘기)",
              style: TextStyle(
                color: _isInverted ? Colors.white : Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 13,
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
