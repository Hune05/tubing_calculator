import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math' as math;
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad_glass.dart';

const Color makitaTeal = Color(0xFF007580);
const Color panelBg = Color(0xFF2A2A2A);
const Color pureWhite = Color(0xFFFFFFFF); // 🚀 에러 방지

class SaddleBottomSheet extends StatefulWidget {
  final double currentRotation;
  final Function(double length, double angle, double rotation) onAddBend;

  const SaddleBottomSheet({
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
      builder: (context) => SaddleBottomSheet(
        currentRotation: currentRotation,
        onAddBend: onAddBend,
      ),
    );
  }

  @override
  State<SaddleBottomSheet> createState() => _SaddleBottomSheetState();
}

class _SaddleBottomSheetState extends State<SaddleBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _heightCtrl = TextEditingController(text: "100");
  final TextEditingController _widthCtrl = TextEditingController(text: "200");
  final TextEditingController _angle3PtCtrl = TextEditingController(text: "45");
  final TextEditingController _angle4PtCtrl = TextEditingController(text: "30");

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _heightCtrl.addListener(() => setState(() {}));
    _widthCtrl.addListener(() => setState(() {}));
    _angle3PtCtrl.addListener(() => setState(() {}));
    _angle4PtCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _heightCtrl.dispose();
    _widthCtrl.dispose();
    _angle3PtCtrl.dispose();
    _angle4PtCtrl.dispose();
    super.dispose();
  }

  void _adjustValue(TextEditingController ctrl, double amount) {
    double current = double.tryParse(ctrl.text) ?? 0;
    double next = current + amount;
    if (next < 0) next = 0;
    ctrl.text = next.toStringAsFixed(next % 1 == 0 ? 0 : 1);
  }

  // 🚀 평행 유지를 위한 180도 반전 회전값 계산
  double _getOppositeRotation(double currentRot) {
    if (currentRot == 360.0) return 450.0;
    if (currentRot == 450.0) return 360.0;
    return (currentRot + 180.0) % 360.0;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    // 🚀 화면 잘림 방지 (동적 높이)
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    double h = double.tryParse(_heightCtrl.text) ?? 0;
    double w = double.tryParse(_widthCtrl.text) ?? 0;
    double a3 = double.tryParse(_angle3PtCtrl.text) ?? 0;
    double a4 = double.tryParse(_angle4PtCtrl.text) ?? 0;

    double travel3Pt = (a3 > 0) ? h / math.sin((a3 / 2) * math.pi / 180.0) : 0;
    double travel4Pt = (a4 > 0) ? h / math.sin(a4 * math.pi / 180.0) : 0;

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
        child: Column(
          mainAxisSize: MainAxisSize.min, // 🚀 내용물 크기만큼만 잡히도록
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.rainbow, color: makitaTeal, size: 28),
                    SizedBox(width: 12),
                    Text(
                      "새들(Saddle)",
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
                Tab(text: "3-Point (원형 배관)"),
                Tab(text: "4-Point (사각 빔)"),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // --- 3-Point 탭 ---
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "장애물 높이/깊이 (H)",
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInputRow(_heightCtrl, "높이 mm"),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "센터 각도 (∠)",
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildAngleField(_angle3PtCtrl, "각도 °"),
                            ),
                            const SizedBox(width: 12),
                            ...[22.5, 30.0, 45.0, 60.0].map(
                              (val) => _buildQuickAngleBtn(_angle3PtCtrl, val),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        _buildResultBox(
                          title: "빗변 길이 (Travel)",
                          value: travel3Pt,
                          btnText: "적용",
                          onPressed: () {
                            if (travel3Pt > 0 && a3 > 0) {
                              double roundedTravel = double.parse(
                                travel3Pt.toStringAsFixed(1),
                              );
                              double sideAngle = a3 / 2;
                              // 🚀 기존 진행 방향과 그 반대축 자동 계산
                              double oppRot = _getOppositeRotation(
                                widget.currentRotation,
                              );

                              // 🚀 3포인트 새들 (사이드 -> 센터(180도 뒤집기) -> 사이드)
                              widget.onAddBend(
                                0.0,
                                sideAngle,
                                widget.currentRotation,
                              );
                              widget.onAddBend(roundedTravel, a3, oppRot);
                              widget.onAddBend(
                                roundedTravel,
                                sideAngle,
                                widget.currentRotation,
                              );
                              Navigator.pop(context);
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),

                  // --- 4-Point 탭 ---
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "높이/깊이 (H)",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInputRow(_heightCtrl, "높이 mm"),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "넓이 (W)",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInputRow(_widthCtrl, "넓이 mm"),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "각도 (∠)",
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildAngleField(_angle4PtCtrl, "각도 °"),
                            ),
                            const SizedBox(width: 12),
                            ...[22.5, 30.0, 45.0, 60.0].map(
                              (val) => _buildQuickAngleBtn(_angle4PtCtrl, val),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        _buildResultBox(
                          title: "빗변 길이 (Travel)",
                          value: travel4Pt,
                          btnText: "적용",
                          onPressed: () {
                            if (travel4Pt > 0 && w > 0 && a4 > 0) {
                              double roundedTravel = double.parse(
                                travel4Pt.toStringAsFixed(1),
                              );
                              double roundedW = double.parse(
                                w.toStringAsFixed(1),
                              );
                              // 🚀 기존 진행 방향과 그 반대축 자동 계산
                              double oppRot = _getOppositeRotation(
                                widget.currentRotation,
                              );

                              // 🚀 4포인트 새들 (진입 -> 직진 -> 하강 -> 복귀)
                              widget.onAddBend(0.0, a4, widget.currentRotation);
                              widget.onAddBend(roundedTravel, a4, oppRot);
                              widget.onAddBend(roundedW, a4, oppRot);
                              widget.onAddBend(
                                roundedTravel,
                                a4,
                                widget.currentRotation,
                              );
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

  Widget _buildInputRow(TextEditingController ctrl, String hint) {
    return Row(
      children: [
        Expanded(
          child: TextField(
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
                horizontal: 12,
                vertical: 10,
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
        ),
        const SizedBox(width: 8),
        Column(
          children: [
            InkWell(
              onTap: () => _adjustValue(ctrl, 10),
              child: const Icon(
                Icons.arrow_drop_up,
                color: Colors.white54,
                size: 28,
              ),
            ),
            InkWell(
              onTap: () => _adjustValue(ctrl, -10),
              child: const Icon(
                Icons.arrow_drop_down,
                color: Colors.white54,
                size: 28,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAngleField(TextEditingController ctrl, String hint) {
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
                value > 0 ? "${value.toStringAsFixed(1)} mm" : "입력 대기",
                style: TextStyle(
                  color: value > 0 ? Colors.white : Colors.white54,
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
