import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math' as math;

import 'package:tubing_calculator/src/core/utils/settings_manager.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
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

  final TextEditingController _heightCtrl = TextEditingController();
  final TextEditingController _widthCtrl = TextEditingController();
  final TextEditingController _angle3PtCtrl = TextEditingController();
  final TextEditingController _angle4PtCtrl = TextEditingController();

  final List<Map<String, dynamic>> _directions = [
    {"label": "UP (위)", "val": 0.0, "icon": Icons.arrow_upward},
    {"label": "FRONT (앞)", "val": 360.0, "icon": Icons.call_made},
    {"label": "LEFT (좌)", "val": 270.0, "icon": Icons.arrow_back},
    {"label": "RIGHT (우)", "val": 90.0, "icon": Icons.arrow_forward},
    {"label": "DOWN (아래)", "val": 180.0, "icon": Icons.arrow_downward},
    {"label": "BACK (뒤)", "val": 450.0, "icon": Icons.call_received},
  ];

  String _formatNum(double val) {
    return val % 1 == 0 ? val.toInt().toString() : val.toString();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final dm = MobileBendDataManager();
    _heightCtrl.text = _formatNum(dm.saddleHeight);
    _widthCtrl.text = _formatNum(dm.saddleWidth);
    _angle3PtCtrl.text = _formatNum(dm.saddleAngle3Pt);
    _angle4PtCtrl.text = _formatNum(dm.saddleAngle4Pt);

    _heightCtrl.addListener(() {
      dm.saddleHeight = double.tryParse(_heightCtrl.text) ?? 0.0;
      setState(() {});
    });
    _widthCtrl.addListener(() {
      dm.saddleWidth = double.tryParse(_widthCtrl.text) ?? 0.0;
      setState(() {});
    });
    _angle3PtCtrl.addListener(() {
      dm.saddleAngle3Pt = double.tryParse(_angle3PtCtrl.text) ?? 0.0;
      setState(() {});
    });
    _angle4PtCtrl.addListener(() {
      dm.saddleAngle4Pt = double.tryParse(_angle4PtCtrl.text) ?? 0.0;
      setState(() {});
    });

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

  void _apply3Point(double travel3Pt, double a3, double shrink) {
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
      double roundedShrink = double.parse(shrink.toStringAsFixed(1));
      double sideAngle = a3 / 2;
      double oppRot = _getOppositeRotation(_selectedRotation!);

      widget.onAddBend(roundedShrink, sideAngle, _selectedRotation!);
      widget.onAddBend(roundedTravel, a3, oppRot);
      widget.onAddBend(roundedTravel, sideAngle, _selectedRotation!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("축소값(+${roundedShrink}mm)이 첫 번째 마킹에 자동 적용되었습니다."),
          backgroundColor: makitaTeal,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _apply4Point(double travel4Pt, double w, double a4, double shrink) {
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
      double roundedShrink = double.parse(shrink.toStringAsFixed(1));
      double oppRot = _getOppositeRotation(_selectedRotation!);

      widget.onAddBend(roundedShrink, a4, _selectedRotation!);
      widget.onAddBend(roundedTravel, a4, oppRot);
      widget.onAddBend(roundedW, a4, oppRot);
      widget.onAddBend(roundedTravel, a4, _selectedRotation!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("축소값(+${roundedShrink}mm)이 첫 번째 마킹에 자동 적용되었습니다."),
          backgroundColor: makitaTeal,
        ),
      );
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

    // --- 3-Point 계산 ---
    double travel3Pt = 0;
    double run3PtTotal = 0;
    double pipeUsed3Pt = 0;
    double shrink3Pt = 0.0;
    double gain3Pt = 0.0;
    String gainDetails3Pt = "";
    double totalConsumed3Pt = 0.0;

    if (a3 > 0 && h > 0) {
      double radSide = (a3 / 2) * math.pi / 180.0;
      travel3Pt = h / math.sin(radSide);
      double run3 = h / math.tan(radSide);

      pipeUsed3Pt = travel3Pt * 2;
      run3PtTotal = run3 * 2;

      shrink3Pt = pipeUsed3Pt - run3PtTotal;
      if (_userOffsetShrink > 0) shrink3Pt += (_userOffsetShrink * 2);

      double gainCenter = 0.0;
      double gainSide = 0.0;

      if (_machineRadius > 0) {
        double centerRad = a3 * math.pi / 180.0;
        gainCenter =
            (2 * _machineRadius * math.tan(centerRad / 2)) -
            (math.pi * _machineRadius * a3 / 180.0);
        gainSide =
            (2 * _machineRadius * math.tan(radSide / 2)) -
            (math.pi * _machineRadius * (a3 / 2) / 180.0);
        gain3Pt = gainCenter + (gainSide * 2);
      } else if (_machineGain > 0) {
        gainCenter = (_machineGain * (a3 / 90.0));
        gainSide = (_machineGain * ((a3 / 2) / 90.0));
        gain3Pt = gainCenter + (gainSide * 2);
      }

      // 🚀 직관적인 연신율 텍스트 적용 (3-Point)
      if (gainCenter > 0 || gainSide > 0) {
        gainDetails3Pt =
            "센터(${a3.toInt()}°): +${gainCenter.toStringAsFixed(1)} mm\n"
            "사이드(${(a3 / 2).toInt()}°): +${gainSide.toStringAsFixed(1)} mm x 2곳\n"
            "▶ 총 연신율(늘어난 길이): +${gain3Pt.toStringAsFixed(1)} mm";
      } else {
        gainDetails3Pt = "설정된 연신율 데이터 없음";
      }

      totalConsumed3Pt = pipeUsed3Pt + gain3Pt;
    }

    // --- 4-Point 계산 ---
    double travel4Pt = 0;
    double run4PtTotal = 0;
    double pipeUsed4Pt = 0;
    double shrink4Pt = 0.0;
    double gain4Pt = 0.0;
    String gainDetails4Pt = "";
    double totalConsumed4Pt = 0.0;

    if (a4 > 0 && h > 0) {
      double rad4 = a4 * math.pi / 180.0;
      travel4Pt = h / math.sin(rad4);
      double run4 = h / math.tan(rad4);

      pipeUsed4Pt = (travel4Pt * 2) + w;
      run4PtTotal = (run4 * 2) + w;

      shrink4Pt = pipeUsed4Pt - run4PtTotal;
      if (_userOffsetShrink > 0) shrink4Pt += (_userOffsetShrink * 2);

      double gainBend = 0.0;

      if (_machineRadius > 0) {
        gainBend =
            (2 * _machineRadius * math.tan(rad4 / 2)) -
            (math.pi * _machineRadius * a4 / 180.0);
        gain4Pt = gainBend * 4;
      } else if (_machineGain > 0) {
        gainBend = (_machineGain * (a4 / 90.0));
        gain4Pt = gainBend * 4;
      }

      // 🚀 직관적인 연신율 텍스트 적용 (4-Point)
      if (gainBend > 0) {
        gainDetails4Pt =
            "1개소당(${a4.toInt()}°): +${gainBend.toStringAsFixed(1)} mm x 4곳\n"
            "▶ 총 연신율(늘어난 길이): +${gain4Pt.toStringAsFixed(1)} mm";
      } else {
        gainDetails4Pt = "설정된 연신율 데이터 없음";
      }

      totalConsumed4Pt = pipeUsed4Pt + gain4Pt;
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
                          shrink3Pt,
                          gainDetails3Pt,
                          totalConsumed3Pt,
                        )
                      : _build4PointTab(
                          h,
                          w,
                          a4,
                          travel4Pt,
                          pipeUsed4Pt,
                          shrink4Pt,
                          gainDetails4Pt,
                          totalConsumed4Pt,
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
    double shrink,
    String gainDetails,
    double totalConsumed,
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
          shrink: shrink,
          gainDetails: gainDetails,
          totalConsumed: totalConsumed,
          onPressed: () => _apply3Point(travel, a3, shrink),
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
    double shrink,
    String gainDetails,
    double totalConsumed,
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
          shrink: shrink,
          gainDetails: gainDetails,
          totalConsumed: totalConsumed,
          onPressed: () => _apply4Point(travel, w, a4, shrink),
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

  // 🚀 완전 무결점 결과 박스 (UI 깨짐 방지 및 직관성 강화 적용 + 바깥선 실측 참고 추가)
  Widget _buildResultBox({
    required double travel,
    required double pipeUsed,
    required double shrink,
    required String gainDetails,
    required double totalConsumed,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "마킹 빗변 (Travel)",
                    style: TextStyle(
                      color: slate600,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    travel > 0 ? "${travel.toStringAsFixed(1)} mm" : "0.0 mm",
                    style: const TextStyle(
                      color: slate900,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Text(
                    "C to C 마킹 치수",
                    style: TextStyle(color: Colors.black54, fontSize: 10),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    "도면상 합계 (이론값)",
                    style: TextStyle(
                      color: slate600,
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
                      color: slate900,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Text(
                    "연신율 적용 전 기본 합계",
                    style: TextStyle(color: Colors.black54, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.black12, height: 1),
          const SizedBox(height: 16),

          // 🚀 발생한 연신율 (상세 내역)
          const Text(
            "📍 연신율 상세 내역 (Gain)",
            style: TextStyle(
              color: makitaTeal,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: makitaTeal.withOpacity(0.3)),
            ),
            child: Text(
              gainDetails,
              style: const TextStyle(
                color: slate900,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 🚀 진짜 총 기장 (이론값 + 연신율)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: makitaTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: makitaTeal, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "실제 커팅 기장 (총 기장)",
                        style: TextStyle(
                          color: makitaTeal,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "도면합계 + 총 연신율 (파이프 소모량)",
                        style: TextStyle(color: slate600, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Text(
                  totalConsumed > 0
                      ? "${totalConsumed.toStringAsFixed(1)} mm"
                      : "0.0 mm",
                  style: const TextStyle(
                    color: makitaTeal,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 🚀 현장 검수용 바깥선 실측 참고 (새로 추가된 핵심 기능)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade400, width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.ruler, size: 20, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "현장 검수용 실측 참고 (바깥선/등 기준)",
                        style: TextStyle(
                          color: slate900,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "줄자 측정값 ≈ 도면상 합계(${pipeUsed > 0 ? pipeUsed.toStringAsFixed(1) : '0'}) + 튜브 반지름",
                        style: const TextStyle(color: slate600, fontSize: 11),
                      ),
                      if (pipeUsed > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "※ 3/8\" 기준 약 ${(pipeUsed + 5.0).toStringAsFixed(1)} ~ ${(pipeUsed + 6.0).toStringAsFixed(1)} mm 예상",
                            style: const TextStyle(
                              color: Colors.deepOrange,
                              fontSize: 12,
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

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "자동 적용 옵션",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "1번 마킹 축소값: +${shrink.toStringAsFixed(1)} mm",
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
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: makitaTeal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    maxLines: 1,
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
