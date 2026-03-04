import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math' as math;

// 💡 새롭게 만든 반투명 글래스 패드를 임포트합니다.
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad_glass.dart';

const Color makitaTeal = Color(0xFF007580);
const Color panelBg = Color(0xFF2A2A2A);

class RollingOffsetBottomSheet extends StatefulWidget {
  final Function(double length, double angle, double rotation) onAddBend;

  const RollingOffsetBottomSheet({super.key, required this.onAddBend});

  static void show(
    BuildContext context, {
    required Function(double, double, double) onAddBend,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RollingOffsetBottomSheet(onAddBend: onAddBend),
    );
  }

  @override
  State<RollingOffsetBottomSheet> createState() =>
      _RollingOffsetBottomSheetState();
}

class _RollingOffsetBottomSheetState extends State<RollingOffsetBottomSheet> {
  final TextEditingController _riseCtrl = TextEditingController(text: "150");
  final TextEditingController _rollCtrl = TextEditingController(text: "200");
  final TextEditingController _angleCtrl = TextEditingController(text: "45");

  @override
  void initState() {
    super.initState();
    _riseCtrl.addListener(() => setState(() {}));
    _rollCtrl.addListener(() => setState(() {}));
    _angleCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _riseCtrl.dispose();
    _rollCtrl.dispose();
    _angleCtrl.dispose();
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

    double rise = double.tryParse(_riseCtrl.text) ?? 0;
    double roll = double.tryParse(_rollCtrl.text) ?? 0;
    double angle = double.tryParse(_angleCtrl.text) ?? 0;

    double trueOffset = math.sqrt(math.pow(rise, 2) + math.pow(roll, 2));

    double travel = 0;
    if (angle > 0) {
      travel = trueOffset / math.sin(angle * math.pi / 180.0);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: 480,
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

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "위로 (Rise) H",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      _buildInputRow(_riseCtrl, "수직 높이"),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "옆으로 (Roll) W",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      _buildInputRow(_rollCtrl, "수평 넓이"),
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
                Expanded(flex: 2, child: _buildAngleField(_angleCtrl, "각도 °")),
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

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "오프셋 거리 (True Offset)",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    "${trueOffset.toStringAsFixed(1)} mm",
                    style: const TextStyle(
                      color: makitaTeal,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Container(
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
                      const Text(
                        "빗변 길이 (Travel)",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Text(
                        travel > 0
                            ? "${travel.toStringAsFixed(1)} mm"
                            : "입력 대기",
                        style: TextStyle(
                          color: travel > 0 ? Colors.white : Colors.white54,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: makitaTeal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    onPressed: () {
                      if (travel > 0 && angle > 0) {
                        double roundedTravel = double.parse(
                          travel.toStringAsFixed(1),
                        );

                        // 🔥 핵심 수정 및 보너스: 롤링 3D 회전 각도 계산 & 연산 순서 교정
                        // Rise(수직)와 Roll(수평)을 이용해 3D 공간에서 비틀어지는 실제 진행 각도를 계산합니다.
                        double rollRotation = 0.0;
                        if (rise > 0 || roll > 0) {
                          // 수직 기준 회전각 (atan2를 이용하여 Y, X 좌표계 기준 회전 변환)
                          rollRotation =
                              math.atan2(roll, rise) * (180.0 / math.pi);
                        }

                        // 1. 제자리에서 계산된 롤링 회전각(rollRotation) 방향으로 즉시 꺾음
                        widget.onAddBend(0.0, angle, rollRotation);

                        // 2. 빗변 이동 후 완전히 반대 방향(+180도)으로 꺾어 기존 직관 평행선에 안착
                        widget.onAddBend(
                          roundedTravel,
                          angle,
                          (rollRotation + 180.0) % 360.0,
                        );

                        Navigator.pop(context);
                      }
                    },
                    child: const Text(
                      "롤링 추가",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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

  // 💡 [핵심] 글래스 패드 호출 적용
  Widget _buildInputRow(TextEditingController ctrl, String hint) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            readOnly: true, // 시스템 키보드 차단
            onTap: () {
              // 💡 MakitaNumpadGlass 호출
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

  // 💡 [핵심] 글래스 패드 호출 적용
  Widget _buildAngleField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      readOnly: true, // 시스템 키보드 차단
      onTap: () {
        // 💡 MakitaNumpadGlass 호출
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
}
