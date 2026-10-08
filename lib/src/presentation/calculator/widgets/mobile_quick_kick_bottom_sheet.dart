import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tubing_calculator/src/core/utils/settings_manager.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad_glass.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/quick_kick_guide.dart';

const Color makitaTeal = AppColors.brand;
const Color slate900 = AppColors.text;
const Color slate600 = AppColors.textSub;
const Color slate100 = AppColors.background;
const Color pureWhite = Color(0xFFFFFFFF);

class MobileQuickKickBottomSheet extends StatefulWidget {
  const MobileQuickKickBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const MobileQuickKickBottomSheet(),
    );
  }

  @override
  State<MobileQuickKickBottomSheet> createState() =>
      _MobileQuickKickBottomSheetState();
}

class _MobileQuickKickBottomSheetState
    extends State<MobileQuickKickBottomSheet> {
  // 장비 간섭 경고용 (비동기 로드)
  double _minStraight = 0.0;
  bool _warnShoeInterference = true;

  final TextEditingController _heightCtrl = TextEditingController();
  final TextEditingController _angleCtrl = TextEditingController(text: "45");

  @override
  void initState() {
    super.initState();
    _loadAsyncSettings();
    _heightCtrl.addListener(() => setState(() {}));
    _angleCtrl.addListener(() => setState(() {}));
  }

  Future<void> _loadAsyncSettings() async {
    final data = await SettingsManager.loadSettings();
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _minStraight = data['minStraight'] ?? 0.0;
        _warnShoeInterference = prefs.getBool('warnShoeInterference') ?? true;
      });
    }
  }

  @override
  void dispose() {
    _heightCtrl.dispose();
    _angleCtrl.dispose();
    super.dispose();
  }

  Widget _buildQuickAngleBtn(TextEditingController ctrl, double val) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // 🚀 DataManager에서 메모리에 떠있는 R값을 바로 가져옵니다.
    final double bendRadius = MobileBendDataManager().radius;

    double h = double.tryParse(_heightCtrl.text) ?? 0;
    double a = double.tryParse(_angleCtrl.text) ?? 0;

    double travel = 0;
    double run = 0;
    double takeOff = 0;
    double markingDistance = 0;

    // 삼각함수 연산 및 공제량(Take-off) 연산
    if (h > 0 && a > 0 && a < 90) {
      double rad = a * math.pi / 180.0;
      travel = h / math.sin(rad);
      run = h / math.tan(rad);

      // 킥은 한 번만 꺾으므로 "마킹 간격"이 아니라 벤드 뒤 곧은 부분(빗변 − 셋백)이다
      // (10-09: 예전에는 "실제 마킹 간격"이라 적혀 두 마킹 사이로 오해할 수 있었다).
      if (bendRadius > 0) {
        takeOff = bendRadius * math.tan((a / 2.0) * (math.pi / 180.0));
        markingDistance = travel - takeOff;
      }
    }

    // 벤드 뒤 곧은 부분(빗변 − 셋백)으로 본다(10-09: 예전에는 빗변 그대로 비교).
    final double kickStraight = bendRadius > 0 ? markingDistance : travel;
    bool isTooShort =
        _warnShoeInterference &&
        _minStraight > 0 &&
        travel > 0 &&
        kickStraight < _minStraight;

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
              // 헤더 영역
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(LucideIcons.zap, color: makitaTeal, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "퀵 킥",
                      style: TextStyle(
                        color: slate900,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: slate600),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "장애물을 넘거나 목표 포트에 닿기 위한 빗변 길이를 계산해 봅니다. (도면 목록에는 넣지 않습니다)",
                style: TextStyle(color: slate600, fontSize: 12),
              ),
              const SizedBox(height: 16),
              QuickKickGuide(
                heightMm: h,
                runMm: run,
                travelMm: travel,
                angleDeg: a,
              ),
              const SizedBox(height: 16),

              // 입력부 (높이, 각도)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "단차 높이 (Rise)",
                          style: TextStyle(
                            color: slate600,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _heightCtrl,
                          readOnly: true,
                          onTap: () => MakitaNumpadGlass.show(
                            context,
                            controller: _heightCtrl,
                            title: "높이 (mm)",
                          ),
                          style: const TextStyle(
                            color: makitaTeal,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                          ),
                          decoration: InputDecoration(
                            hintText: "0",
                            filled: true,
                            fillColor: slate100,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Text(
                "벤딩 각도 (∠)",
                style: TextStyle(
                  color: slate600,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // 좁은 폭에서는 빠른 각도 단추가 다음 줄로 내려간다.
              Wrap(
                spacing: 0,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _angleCtrl,
                      readOnly: true,
                      onTap: () => MakitaNumpadGlass.show(
                        context,
                        controller: _angleCtrl,
                        title: "벤딩 각도 °",
                      ),
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
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ...[
                    15.0,
                    22.5,
                    30.0,
                    45.0,
                    60.0,
                  ].map((val) => _buildQuickAngleBtn(_angleCtrl, val)),
                ],
              ),
              const SizedBox(height: 24),

              // 🚀 현장 실측 마킹 정보 (R값이 설정되어 있을 때만 노출)
              if (bendRadius > 0 && travel > 0) ...[
                const Row(
                  children: [
                    Icon(
                      Icons.construction,
                      color: Colors.deepOrange,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      "설정 R값으로 본 길이",
                      style: TextStyle(
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.deepOrange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "셋백 (R·tan(θ/2))",
                            style: TextStyle(
                              color: Colors.deepOrange.shade800,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "- ${takeOff.toStringAsFixed(1)} mm",
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "벤드 뒤 곧은 부분",
                            style: TextStyle(
                              color: Colors.deepOrange.shade800,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${markingDistance.toStringAsFixed(1)} mm",
                            style: const TextStyle(
                              color: Colors.deepOrange,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 🚀 기계 간섭 경고 메시지 (조건 충족 시에만 노출)
              if (isTooShort) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "벤드 뒤 곧은 부분(${kickStraight.toStringAsFixed(1)}mm)이 최소 물림 길이($_minStraight mm)보다 짧아 벤더기에 안 물릴 수 있습니다.",
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 메인 결과 출력부
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: makitaTeal.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: makitaTeal.withValues(alpha: 0.3)),
                ),
                // 결과 아래에 닫기 단추를 둔다(좁은 폭에서 옆에 두면 넘쳤다).
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "도달 빗변 (C-C Travel)",
                          style: TextStyle(
                            color: slate600,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          travel > 0
                              ? "${travel.toStringAsFixed(1)} mm"
                              : "0.0 mm",
                          style: const TextStyle(
                            color: makitaTeal,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "※ 수평 거리 (Run): ${run > 0 ? run.toStringAsFixed(1) : '0.0'} mm",
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 닫기 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: makitaTeal, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "확인 (닫기)",
                          style: TextStyle(
                            color: makitaTeal,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
}
