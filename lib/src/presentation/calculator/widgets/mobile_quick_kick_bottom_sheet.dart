import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tubing_calculator/src/core/utils/settings_manager.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad_glass.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
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

      // R값이 존재하면 실제 마킹 위치(공제량)를 계산합니다.
      if (bendRadius > 0) {
        takeOff = bendRadius * math.tan((a / 2.0) * (math.pi / 180.0));
        markingDistance = travel - takeOff;
      }
    }

    bool isTooShort =
        _warnShoeInterference && travel > 0 && travel < _minStraight;

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
                  const Row(
                    children: [
                      Icon(LucideIcons.zap, color: makitaTeal, size: 28),
                      SizedBox(width: 12),
                      Text(
                        "퀵 킥 (단일 단차) 계산기",
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
              const SizedBox(height: 8),
              const Text(
                "장애물을 피하거나 목표 포트에 도달하기 위한 꺾임(빗변) 거리를 즉시 확인합니다. (도면에 저장되지 않습니다)",
                style: TextStyle(color: slate600, fontSize: 12),
              ),
              const SizedBox(height: 24),

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
              Row(
                children: [
                  Expanded(
                    flex: 2,
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
                      "현장 마킹 제원 (설정 R값 적용)",
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
                    color: Colors.deepOrange.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.deepOrange.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "공제량 (Take-off)",
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
                            "실제 펜 마킹 거리",
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
                          "계산된 빗변(${travel.toStringAsFixed(1)}mm)이 최소 물림 기장($_minStraight mm)보다 짧아 벤더기에 안 물릴 수 있습니다.",
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
                  color: makitaTeal.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: makitaTeal.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          "※ 수평 진행 거리(Run): ${run > 0 ? run.toStringAsFixed(1) : '0.0'} mm",
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    // 닫기 버튼
                    SizedBox(
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
