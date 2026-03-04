import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math' as math;

// 💡 새롭게 만든 반투명 글래스 패드를 임포트합니다.
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad_glass.dart';

const Color makitaTeal = Color(0xFF007580);
const Color panelBg = Color(0xFF2A2A2A);

class SaddleBottomSheet extends StatefulWidget {
  final Function(double length, double angle, double rotation) onAddBend;

  const SaddleBottomSheet({super.key, required this.onAddBend});

  static void show(
    BuildContext context, {
    required Function(double, double, double) onAddBend,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SaddleBottomSheet(onAddBend: onAddBend),
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

  final double _baseDirection = 0.0;

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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    double h = double.tryParse(_heightCtrl.text) ?? 0;
    double w = double.tryParse(_widthCtrl.text) ?? 0;
    double a3 = double.tryParse(_angle3PtCtrl.text) ?? 0;
    double a4 = double.tryParse(_angle4PtCtrl.text) ?? 0;

    double travel3Pt = 0;
    if (a3 > 0) {
      travel3Pt = h / math.sin((a3 / 2) * math.pi / 180.0);
    }

    double travel4Pt = 0;
    if (a4 > 0) {
      travel4Pt = h / math.sin(a4 * math.pi / 180.0);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: 520,
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
                    Icon(LucideIcons.rainbow, color: makitaTeal, size: 28),
                    SizedBox(width: 12),
                    Text(
                      "새들(Saddle) 계산기",
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
                  // 1번 탭 (3-Point 새들)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "높이 (H)",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildInputRow(_heightCtrl, "높이 입력")),
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
                            child: _buildAngleField(_angle3PtCtrl, "각도 °"),
                          ),
                          const SizedBox(width: 12),
                          ...[22.5, 30.0, 45.0, 60.0].map(
                            (val) => _buildQuickAngleBtn(_angle3PtCtrl, val),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildResultBox(
                        title: "빗변 길이 (Travel)",
                        value: travel3Pt,
                        btnText: "3-Point 추가",
                        onPressed: () {
                          if (travel3Pt > 0 && a3 > 0) {
                            double roundedTravel = double.parse(
                              travel3Pt.toStringAsFixed(1),
                            );
                            double sideAngle = a3 / 2;

                            // 🔥 핵심 수정: 3-Point 벤딩 순서 및 각도 상쇄
                            // 1. 제자리에서 첫 번째 사이드 꺾음 (위로 올라가기 시작)
                            widget.onAddBend(0.0, sideAngle, _baseDirection);

                            // 2. 빗변 전진 후 산꼭대기(센터)에서 반대 방향으로 크게 꺾음 (아래로 내려감)
                            widget.onAddBend(
                              roundedTravel,
                              a3,
                              (_baseDirection + 180.0) % 360.0,
                            );

                            // 3. 빗변 전진 후 원래 방향으로 다시 꺾어 바닥 평행 복귀
                            widget.onAddBend(
                              roundedTravel,
                              sideAngle,
                              _baseDirection,
                            );

                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                  ),

                  // 2번 탭 (4-Point 새들)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "장애물 높이 (H)",
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
                                  "장애물 넓이 (W)",
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
                      const SizedBox(height: 24),
                      _buildResultBox(
                        title: "빗변 길이 (Travel)",
                        value: travel4Pt,
                        btnText: "4-Point 추가",
                        onPressed: () {
                          if (travel4Pt > 0 && w > 0 && a4 > 0) {
                            double roundedTravel = double.parse(
                              travel4Pt.toStringAsFixed(1),
                            );
                            double roundedW = double.parse(
                              w.toStringAsFixed(1),
                            );

                            // 🔥 핵심 수정: 4-Point 벤딩 순서 및 각도 상쇄
                            // 1. 제자리에서 첫 번째 꺾음 (위로 올라가기 시작)
                            widget.onAddBend(0.0, a4, _baseDirection);

                            // 2. 빗변 전진 후 반대 방향으로 꺾어 평행하게 만듦 (장애물 위 올라탐)
                            widget.onAddBend(
                              roundedTravel,
                              a4,
                              (_baseDirection + 180.0) % 360.0,
                            );

                            // 3. 장애물 넓이(W) 전진 후 다시 반대로 꺾음 (아래로 내려가기 시작)
                            widget.onAddBend(
                              roundedW,
                              a4,
                              (_baseDirection + 180.0) % 360.0,
                            );

                            // 4. 빗변 전진 후 원래 방향으로 꺾어 바닥 평행 완전 복귀
                            widget.onAddBend(roundedTravel, a4, _baseDirection);

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

  // 💡 [핵심] 글래스 패드 호출 적용 (+/- 버튼 포함된 필드)
  Widget _buildInputRow(TextEditingController ctrl, String hint) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            readOnly: true, // 시스템 키보드 차단
            onTap: () {
              MakitaNumpadGlass.show(context, controller: ctrl, title: hint);
            },
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

  // 💡 [핵심] 글래스 패드 호출 적용 (각도 입력 필드)
  Widget _buildAngleField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      readOnly: true, // 시스템 키보드 차단
      onTap: () {
        MakitaNumpadGlass.show(context, controller: ctrl, title: hint);
      },
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
