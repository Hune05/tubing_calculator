import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math' as math;

import 'package:tubing_calculator/src/core/utils/settings_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad_glass.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class MobileSaddleBottomSheet extends StatefulWidget {
  final double currentRotation;
  final Function(double length, double angle, double rotation) onAddBend;

  const MobileSaddleBottomSheet({
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
      builder: (context) => MobileSaddleBottomSheet(
        currentRotation: currentRotation,
        onAddBend: onAddBend,
      ),
    );
  }

  @override
  State<MobileSaddleBottomSheet> createState() =>
      _MobileSaddleBottomSheetState();
}

class _MobileSaddleBottomSheetState extends State<MobileSaddleBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double? _selectedRotation;

  double _machineRadius = 0.0;
  double _machineGain = 0.0;
  double _userOffsetShrink = 0.0;

  final TextEditingController _heightCtrl = TextEditingController(text: "100");
  final TextEditingController _widthCtrl = TextEditingController(text: "200");
  final TextEditingController _angle3PtCtrl = TextEditingController(text: "45");
  final TextEditingController _angle4PtCtrl = TextEditingController(text: "30");

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
    _widthCtrl.addListener(() => setState(() {}));
    _angle3PtCtrl.addListener(() => setState(() {}));
    _angle4PtCtrl.addListener(() => setState(() {}));
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

  double _getOppositeRotation(double currentRot) {
    if (currentRot == 360.0) return 450.0;
    if (currentRot == 450.0) return 360.0;
    return (currentRot + 180.0) % 360.0;
  }

  void _apply3Point(double travel3Pt, double a3) {
    if (_selectedRotation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("장애물 회피 방향을 선택해주세요!"),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }
    if (travel3Pt > 0 && a3 > 0) {
      double roundedTravel = double.parse(travel3Pt.toStringAsFixed(1));
      double sideAngle = a3 / 2;
      double oppRot = _getOppositeRotation(_selectedRotation!);
      widget.onAddBend(0.0, sideAngle, _selectedRotation!);
      widget.onAddBend(roundedTravel, a3, oppRot);
      widget.onAddBend(roundedTravel, sideAngle, _selectedRotation!);
      Navigator.pop(context);
    }
  }

  void _apply4Point(double travel4Pt, double w, double a4) {
    if (_selectedRotation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("장애물 회피 방향을 선택해주세요!"),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }
    if (travel4Pt > 0 && w > 0 && a4 > 0) {
      double roundedTravel = double.parse(travel4Pt.toStringAsFixed(1));
      double roundedW = double.parse(w.toStringAsFixed(1));
      double oppRot = _getOppositeRotation(_selectedRotation!);
      widget.onAddBend(0.0, a4, _selectedRotation!);
      widget.onAddBend(roundedTravel, a4, oppRot);
      widget.onAddBend(roundedW, a4, oppRot);
      widget.onAddBend(roundedTravel, a4, _selectedRotation!);
      Navigator.pop(context);
    }
  }

  Widget _buildDirectionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "장애물 회피 방향 (6축)",
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
    double w = double.tryParse(_widthCtrl.text) ?? 0;
    double a3 = double.tryParse(_angle3PtCtrl.text) ?? 0;
    double a4 = double.tryParse(_angle4PtCtrl.text) ?? 0;

    // 🚀 3-Point 계산
    double travel3Pt = 0;
    double run3PtTotal = 0;
    double pipeUsed3Pt = 0;
    double shrink3Pt = 0.0;
    double gain3Pt = 0.0;

    if (a3 > 0 && h > 0) {
      double radSide = (a3 / 2) * math.pi / 180.0;
      travel3Pt = h / math.sin(radSide);
      double run3 = h / math.tan(radSide); // 한 쪽 빗변의 바닥 직선거리

      pipeUsed3Pt = travel3Pt * 2; // 실제 굽혀진 전체 파이프 길이
      run3PtTotal = run3 * 2; // 앞으로 나아간 총 직선거리

      shrink3Pt = pipeUsed3Pt - run3PtTotal;
      if (_userOffsetShrink > 0) shrink3Pt += (_userOffsetShrink * 2);

      if (_machineRadius > 0) {
        double centerRad = a3 * math.pi / 180.0;
        double gainCenter =
            (2 * _machineRadius * math.tan(centerRad / 2)) -
            (math.pi * _machineRadius * a3 / 180.0);
        double gainSide =
            (2 * _machineRadius * math.tan(radSide / 2)) -
            (math.pi * _machineRadius * (a3 / 2) / 180.0);
        gain3Pt = gainCenter + (gainSide * 2);
      } else if (_machineGain > 0) {
        gain3Pt =
            (_machineGain * (a3 / 90.0)) +
            2 * (_machineGain * ((a3 / 2) / 90.0));
      }
    }

    // 🚀 4-Point 계산
    double travel4Pt = 0;
    double run4PtTotal = 0;
    double pipeUsed4Pt = 0;
    double shrink4Pt = 0.0;
    double gain4Pt = 0.0;

    if (a4 > 0 && h > 0) {
      double rad4 = a4 * math.pi / 180.0;
      travel4Pt = h / math.sin(rad4);
      double run4 = h / math.tan(rad4); // 한 쪽 빗변의 바닥 직선거리

      pipeUsed4Pt = (travel4Pt * 2) + w; // (빗변*2) + 중앙 넓이
      run4PtTotal = (run4 * 2) + w; // 앞으로 나아간 총 직선거리

      shrink4Pt = pipeUsed4Pt - run4PtTotal;
      if (_userOffsetShrink > 0) shrink4Pt += (_userOffsetShrink * 2);

      if (_machineRadius > 0) {
        double gainBend =
            (2 * _machineRadius * math.tan(rad4 / 2)) -
            (math.pi * _machineRadius * a4 / 180.0);
        gain4Pt = gainBend * 4;
      } else if (_machineGain > 0) {
        gain4Pt = 4 * (_machineGain * (a4 / 90.0));
      }
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
                      Icon(LucideIcons.rainbow, color: makitaTeal, size: 28),
                      SizedBox(width: 12),
                      Text(
                        "새들 (Saddle)",
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
                  Tab(text: "3-Point (원형)"),
                  Tab(text: "4-Point (사각)"),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  return _tabController.index == 0
                      ? _build3PointTab(
                          h,
                          a3,
                          travel3Pt,
                          pipeUsed3Pt,
                          run3PtTotal,
                          shrink3Pt,
                          gain3Pt,
                        )
                      : _build4PointTab(
                          h,
                          w,
                          a4,
                          travel4Pt,
                          pipeUsed4Pt,
                          run4PtTotal,
                          shrink4Pt,
                          gain4Pt,
                        );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _build3PointTab(
    double h,
    double a3,
    double travel,
    double pipeUsed,
    double runTotal,
    double shrink,
    double gain,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "장애물 높이/깊이 (H)",
          style: TextStyle(
            color: slate600,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [Expanded(child: _buildInputRow(_heightCtrl, "높이 mm"))]),
        const SizedBox(height: 20),
        const Text(
          "센터 각도 (∠)",
          style: TextStyle(
            color: slate600,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(flex: 2, child: _buildAngleField(_angle3PtCtrl, "각도 °")),
            const SizedBox(width: 12),
            ...[
              22.5,
              30.0,
              45.0,
              60.0,
            ].map((val) => _buildQuickAngleBtn(_angle3PtCtrl, val)),
          ],
        ),
        const SizedBox(height: 24),
        _buildDirectionSelector(),
        const SizedBox(height: 16),
        _buildResultBox(
          travel: travel,
          pipeUsed: pipeUsed,
          runTotal: runTotal,
          shrink: shrink,
          gain: gain,
          points: 3,
          onPressed: () => _apply3Point(travel, a3),
        ),
      ],
    );
  }

  Widget _build4PointTab(
    double h,
    double w,
    double a4,
    double travel,
    double pipeUsed,
    double runTotal,
    double shrink,
    double gain,
  ) {
    return Column(
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
                      color: slate600,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
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
                      color: slate600,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
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
          style: TextStyle(
            color: slate600,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(flex: 2, child: _buildAngleField(_angle4PtCtrl, "각도 °")),
            const SizedBox(width: 12),
            ...[
              22.5,
              30.0,
              45.0,
              60.0,
            ].map((val) => _buildQuickAngleBtn(_angle4PtCtrl, val)),
          ],
        ),
        const SizedBox(height: 24),
        _buildDirectionSelector(),
        const SizedBox(height: 16),
        _buildResultBox(
          travel: travel,
          pipeUsed: pipeUsed,
          runTotal: runTotal,
          shrink: shrink,
          gain: gain,
          points: 4,
          onPressed: () => _apply4Point(travel, w, a4),
        ),
      ],
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
              color: makitaTeal,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: slate100,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
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
          ),
        ),
        const SizedBox(width: 8),
        Column(
          children: [
            InkWell(
              onTap: () => _adjustValue(ctrl, 10),
              child: const Icon(Icons.arrow_drop_up, color: slate600, size: 28),
            ),
            InkWell(
              onTap: () => _adjustValue(ctrl, -10),
              child: const Icon(
                Icons.arrow_drop_down,
                color: slate600,
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
        color: makitaTeal,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        fontFamily: 'monospace',
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
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

  // 🚀 새들 전용 명확한 결과 패널
  Widget _buildResultBox({
    required double travel,
    required double pipeUsed,
    required double runTotal,
    required double shrink,
    required double gain,
    required int points,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 핵심: 구간의 실제 파이프 소비량 vs 전진 거리
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "직선 진행 거리 (Run)",
                    style: TextStyle(
                      color: slate600,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    runTotal > 0
                        ? "${runTotal.toStringAsFixed(1)} mm"
                        : "0.0 mm",
                    style: const TextStyle(
                      color: slate900,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Text(
                    "전체 라인 길이에서 차감할 값",
                    style: TextStyle(color: Colors.black54, fontSize: 10),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    "파이프 소요량 (Travel Total)",
                    style: TextStyle(
                      color: makitaTeal,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pipeUsed > 0
                        ? "${pipeUsed.toStringAsFixed(1)} mm"
                        : "0.0 mm",
                    style: const TextStyle(
                      color: makitaTeal,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Text(
                    "구간을 만드는 데 들어가는 파이프 양",
                    style: TextStyle(color: Colors.black54, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.black12, height: 1),
          const SizedBox(height: 16),
          // 보상값 및 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "기장 보상값 (Shrink / Gain)",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "추가 파이프: +${shrink.toStringAsFixed(1)} mm\n연신율 차감: -${gain.toStringAsFixed(1)} mm",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 100,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: makitaTeal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: onPressed,
                  child: const Text(
                    "도면 적용",
                    style: TextStyle(
                      color: pureWhite,
                      fontSize: 15,
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
}
