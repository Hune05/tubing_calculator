// lib/src/presentation/calculator/widgets/offset_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math' as math;

import 'package:tubing_calculator/src/core/utils/settings_manager.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad_glass.dart';

const Color makitaTeal = Color(0xFF007580);
const Color panelBg = Color(0xFF2A2A2A); // 태블릿 전용 다크 배경
const Color pureWhite = Color(0xFFFFFFFF);

class OffsetBottomSheet extends StatefulWidget {
  final double currentRotation;
  final Function(List<Map<String, double>> bends) onAddMultipleBends;

  const OffsetBottomSheet({
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
      builder: (context) => OffsetBottomSheet(
        currentRotation: currentRotation,
        onAddMultipleBends: onAddMultipleBends,
      ),
    );
  }

  @override
  State<OffsetBottomSheet> createState() => _OffsetBottomSheetState();
}

class _OffsetBottomSheetState extends State<OffsetBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isInverted = false;
  double? _selectedRotation;

  // 기계 셋팅값 (모바일 V2 이식)
  double _machineRadius = 0.0;
  double _machineGain = 0.0;
  double _userOffsetShrink = 0.0;

  final TextEditingController _heightCtrl = TextEditingController(text: "100");
  final TextEditingController _angleCtrl = TextEditingController(text: "45");
  final TextEditingController _travelCtrl = TextEditingController(text: "150");

  // 🚀 장애물까지의 시작 거리를 입력받는 컨트롤러
  final TextEditingController _startDistanceCtrl = TextEditingController(
    text: "0",
  );

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

    final dm = MobileBendDataManager();
    _heightCtrl.text = _formatNum(dm.offsetHeight > 0 ? dm.offsetHeight : 100);
    _angleCtrl.text = _formatNum(dm.offsetAngle > 0 ? dm.offsetAngle : 45);
    _travelCtrl.text = _formatNum(dm.offsetTravel > 0 ? dm.offsetTravel : 150);

    _heightCtrl.addListener(() {
      dm.offsetHeight = double.tryParse(_heightCtrl.text) ?? 0.0;
      setState(() {});
    });
    _angleCtrl.addListener(() {
      dm.offsetAngle = double.tryParse(_angleCtrl.text) ?? 0.0;
      setState(() {});
    });
    _travelCtrl.addListener(() {
      dm.offsetTravel = double.tryParse(_travelCtrl.text) ?? 0.0;
      setState(() {});
    });
    _startDistanceCtrl.addListener(() => setState(() {}));

    _loadMachineSettings();
  }

  String _formatNum(double val) {
    return val % 1 == 0 ? val.toInt().toString() : val.toString();
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
    _startDistanceCtrl.dispose();
    super.dispose();
  }

  void _adjustValue(TextEditingController ctrl, double amount) {
    double current = double.tryParse(ctrl.text) ?? 0;
    double next = current + amount;
    if (next < 0) next = 0;
    ctrl.text = next.toStringAsFixed(next % 1 == 0 ? 0 : 1);
  }

  // 🚀 핵심 로직: 1번 마킹(거리+축소값)과 2번 마킹(빗변) 적용
  void _applyBending(double angle, double travel, double shrink) {
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
    double roundedShrink = double.parse(shrink.toStringAsFixed(1));

    double startDistance = double.tryParse(_startDistanceCtrl.text) ?? 0.0;

    // 💡 1번 구간 = (장애물 거리) + (오프셋 축소값 보상)
    double firstSegmentLength = startDistance + roundedShrink;
    // 💡 2번 구간 = 빗변(Travel) 거리
    double secondSegmentLength = roundedTravel;

    double r1 = _isInverted
        ? (_selectedRotation! + 180.0) % 360.0
        : _selectedRotation!;
    double r2 = _isInverted
        ? _selectedRotation!
        : (_selectedRotation! + 180.0) % 360.0;

    widget.onAddMultipleBends([
      {'length': firstSegmentLength, 'angle': roundedAngle, 'rotation': r1},
      {'length': secondSegmentLength, 'angle': roundedAngle, 'rotation': r2},
    ]);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          startDistance > 0
              ? "1번 마킹에 거리(${startDistance}mm) + 축소값(${roundedShrink}mm)이 적용되었습니다."
              : "축소값(${roundedShrink}mm)과 빗변(${roundedTravel}mm)이 리스트에 추가되었습니다.",
        ),
        backgroundColor: makitaTeal,
      ),
    );

    Navigator.pop(context);
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

    double calcRun = 0.0;
    double geometricShrink = 0.0;
    double totalGain = 0.0;

    if (targetAngle > 0 && targetAngle < 90 && h > 0 && targetTravel > 0) {
      double rad = targetAngle * math.pi / 180.0;
      calcRun = h / math.tan(rad);
      geometricShrink = targetTravel - calcRun;

      if (_userOffsetShrink > 0) {
        geometricShrink += _userOffsetShrink;
      }

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
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 720, // 🚀 태블릿 폭 제한
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: panelBg, // 🚀 다크 테마
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: makitaTeal, width: 3)),
            ),
            // 🚀 높이 고정 오류 제거 (SingleChildScrollView 사용)
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
                          Icon(
                            LucideIcons.calculator,
                            color: makitaTeal,
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Text(
                            "오프셋 계산기 패널",
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

                  // 🚀 장애물 앞 거리 입력 박스 (다크 테마)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "장애물 앞 시작 거리 (옵션)",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "입력 시 1번 마킹에 축소값이 자동 합산됩니다.",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 140,
                          child: _buildTextField(_startDistanceCtrl, "거리 mm"),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

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
                  const SizedBox(height: 24),

                  const Text(
                    "장애물 높이/깊이 (H)",
                    style: TextStyle(
                      color: Colors.white70,
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
                      const SizedBox(width: 6),
                      _buildQuickBtn(_heightCtrl, 5.0, "+5"),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 🚀 탭 뷰를 AnimatedBuilder로 교체하여 높이 유동성 확보
                  AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, _) {
                      return _tabController.index == 0
                          ? _buildForwardTab(
                              a,
                              calcTravel,
                              calcRun,
                              geometricShrink,
                              totalGain,
                            )
                          : _buildInverseTab(
                              t,
                              calcAngle,
                              calcRun,
                              geometricShrink,
                              totalGain,
                              inverseError,
                            );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🚀 1. 정방향 탭 내용
  Widget _buildForwardTab(
    double angle,
    double travel,
    double run,
    double shrink,
    double gain,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "각도 (∠)",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(flex: 2, child: _buildTextField(_angleCtrl, "각도 °")),
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
        _buildDirectionSelector(),
        const SizedBox(height: 16),
        _buildInvertToggle(),
        const SizedBox(height: 20),
        _buildResultBox(
          title: "계산된 빗변 (Travel)",
          value: travel,
          runDistance: run,
          shrink: shrink,
          gain: gain,
          btnText: "적용",
          onPressed: () => _applyBending(angle, travel, shrink),
        ),
      ],
    );
  }

  // 🚀 2. 역산 탭 내용
  Widget _buildInverseTab(
    double travel,
    double angle,
    double run,
    double shrink,
    double gain,
    bool isError,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "현장 빗변 (Travel)",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildTextField(_travelCtrl, "거리 mm")),
            const SizedBox(width: 12),
            _buildQuickBtn(_travelCtrl, -10.0, "-10"),
            const SizedBox(width: 6),
            _buildQuickBtn(_travelCtrl, 10.0, "+10"),
          ],
        ),
        if (isError)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              "오류: 빗변은 높이보다 커야 합니다!",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        const SizedBox(height: 24),
        _buildDirectionSelector(),
        const SizedBox(height: 16),
        _buildInvertToggle(),
        const SizedBox(height: 20),
        _buildResultBox(
          title: "계산된 각도 (∠)",
          value: angle,
          runDistance: run,
          shrink: shrink,
          gain: gain,
          btnText: "적용",
          isError: isError,
          isAngle: true,
          onPressed: () => _applyBending(angle, travel, shrink),
        ),
      ],
    );
  }

  // 🚀 6축 방향 지정기 (다크 테마)
  Widget _buildDirectionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "돌출 방향 지정 (6축)",
              style: TextStyle(
                color: _selectedRotation == null
                    ? Colors.redAccent
                    : Colors.white70,
                fontSize: 13,
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
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 3.0, // 태블릿 폭에 맞게 넓게
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
                      color: isSelected ? pureWhite : Colors.white54,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dir['label'].split(' ')[0],
                      style: TextStyle(
                        color: isSelected ? pureWhite : Colors.white70,
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

  // 🚀 Invert 토글 (다크 테마)
  Widget _buildInvertToggle() {
    return Align(
      alignment: Alignment.centerRight,
      child: InkWell(
        onTap: () => setState(() => _isInverted = !_isInverted),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _isInverted ? Colors.red.withOpacity(0.15) : Colors.black45,
            border: Border.all(
              color: _isInverted ? Colors.redAccent : Colors.white12,
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
                _isInverted ? "아래로 파기 (Invert)" : "위로 넘기 (Normal)",
                style: TextStyle(
                  color: _isInverted ? Colors.redAccent : Colors.white70,
                  fontSize: 13,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            val % 1 == 0 ? "${val.toInt()}°" : "$val°",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  // 🚀 최종 결과창 (다크 테마 + 상세 스펙)
  Widget _buildResultBox({
    required String title,
    required double value,
    required double runDistance,
    required double shrink,
    required double gain,
    required String btnText,
    required VoidCallback onPressed,
    bool isError = false,
    bool isAngle = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value > 0 && !isError
                          ? "${value.toStringAsFixed(1)} ${isAngle ? "°" : "mm"}"
                          : "입력 대기",
                      style: TextStyle(
                        color: value > 0 && !isError
                            ? makitaTeal
                            : Colors.redAccent,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 52,
                width: 120,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: makitaTeal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: onPressed,
                  child: Text(
                    btnText,
                    style: const TextStyle(
                      color: pureWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (value > 0 && !isError) ...[
            const SizedBox(height: 20),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 16),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "직선 진행 거리 (Run)",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${runDistance.toStringAsFixed(1)} mm",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'monospace',
                  ),
                ),
                const Text(
                  "(바닥을 타고 앞으로 나아간 실제 직선 거리)",
                  style: TextStyle(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "오프셋 축소량",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "+${shrink.toStringAsFixed(1)} mm",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Text(
                        "(1번 마킹에 더함)",
                        style: TextStyle(fontSize: 11, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white12),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "2포인트 연신율 (Gain)",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "-${gain.toStringAsFixed(1)} mm",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade400,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Text(
                        "(절단 기장에서 뺌)",
                        style: TextStyle(fontSize: 11, color: Colors.white38),
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
