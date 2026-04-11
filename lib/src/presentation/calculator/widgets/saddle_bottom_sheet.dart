// lib/src/presentation/calculator/widgets/saddle_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math' as math;

import 'package:tubing_calculator/src/core/utils/settings_manager.dart';
import 'package:tubing_calculator/src/data/models/mobile_bend_data_manager.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad_glass.dart';

const Color makitaTeal = Color(0xFF007580);
const Color panelBg = Color(0xFF2A2A2A);
const Color pureWhite = Color(0xFFFFFFFF);

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
  double? _selectedRotation;

  // 기계 셋팅값 (모바일 V2 이식)
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

    final dm = MobileBendDataManager();
    // 모바일 V2처럼 DataManager 연동
    _heightCtrl.text = _formatNum(dm.saddleHeight > 0 ? dm.saddleHeight : 100);
    _widthCtrl.text = _formatNum(dm.saddleWidth > 0 ? dm.saddleWidth : 200);
    _angle3PtCtrl.text = _formatNum(
      dm.saddleAngle3Pt > 0 ? dm.saddleAngle3Pt : 45,
    );
    _angle4PtCtrl.text = _formatNum(
      dm.saddleAngle4Pt > 0 ? dm.saddleAngle4Pt : 30,
    );

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

  // 🚀 모바일 V2의 완벽한 3-Point 로직
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

  // 🚀 모바일 V2의 완벽한 4-Point 로직
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    double h = double.tryParse(_heightCtrl.text) ?? 0;
    double w = double.tryParse(_widthCtrl.text) ?? 0;
    double a3 = double.tryParse(_angle3PtCtrl.text) ?? 0;
    double a4 = double.tryParse(_angle4PtCtrl.text) ?? 0;

    // --- 3-Point 계산 (모바일 로직 100% 반영) ---
    double travel3Pt = 0,
        run3PtTotal = 0,
        pipeUsed3Pt = 0,
        shrink3Pt = 0.0,
        gain3Pt = 0.0,
        totalConsumed3Pt = 0.0;
    String gainDetails3Pt = "";

    if (a3 > 0 && h > 0) {
      double radSide = (a3 / 2) * math.pi / 180.0;
      travel3Pt = h / math.sin(radSide);
      double run3 = h / math.tan(radSide);

      pipeUsed3Pt = travel3Pt * 2;
      run3PtTotal = run3 * 2;

      shrink3Pt = pipeUsed3Pt - run3PtTotal;
      if (_userOffsetShrink > 0) shrink3Pt += (_userOffsetShrink * 2);

      double gainCenter = 0.0, gainSide = 0.0;

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

    // --- 4-Point 계산 (모바일 로직 100% 반영) ---
    double travel4Pt = 0,
        run4PtTotal = 0,
        pipeUsed4Pt = 0,
        shrink4Pt = 0.0,
        gain4Pt = 0.0,
        totalConsumed4Pt = 0.0;
    String gainDetails4Pt = "";

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
      // 🚀 핵심 변경: 태블릿의 가로 찢어짐을 방지하는 Align + ConstrainedBox
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 720, // 태블릿 최적화 폭
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: panelBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: makitaTeal, width: 3)),
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
                          Icon(
                            LucideIcons.rainbow,
                            color: makitaTeal,
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Text(
                            "새들(Saddle) 패널",
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
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 20),
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
        ),
      ),
    );
  }

  // 🚀 태블릿 다크 테마용 6축 방향 선택기
  Widget _buildDirectionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "장애물 회피 방향 (6축)",
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
            childAspectRatio: 3.0, // 태블릿 화면에 맞춰 살짝 넓게 조정
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
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Row(children: [Expanded(child: _buildInputRow(_heightCtrl, "높이 mm"))]),
        const SizedBox(height: 20),
        const Text(
          "센터 각도 (∠)",
          style: TextStyle(color: Colors.white70, fontSize: 13),
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
        const SizedBox(height: 24),
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
                    style: TextStyle(color: Colors.white70, fontSize: 13),
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
                    style: TextStyle(color: Colors.white70, fontSize: 13),
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
        const SizedBox(height: 24),
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
                size: 32,
              ),
            ),
            InkWell(
              onTap: () => _adjustValue(ctrl, -10),
              child: const Icon(
                Icons.arrow_drop_down,
                color: Colors.white54,
                size: 32,
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
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
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

  // 🚀 태블릿용 다크 테마 + 완벽 스펙의 결과 박스
  Widget _buildResultBox({
    required double travel,
    required double pipeUsed,
    required double shrink,
    required String gainDetails,
    required double totalConsumed,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black26, // 다크테마 베이스
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
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
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    travel > 0 ? "${travel.toStringAsFixed(1)} mm" : "0.0 mm",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Text(
                    "C to C 마킹 치수",
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    "도면상 합계 (이론값)",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pipeUsed > 0
                        ? "${pipeUsed.toStringAsFixed(1)} mm"
                        : "0.0 mm",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Text(
                    "연신율 적용 전 기본 합계",
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),

          const Text(
            "📍 연신율 상세 내역 (Gain)",
            style: TextStyle(
              color: makitaTeal,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: makitaTeal.withOpacity(0.3)),
            ),
            child: Text(
              gainDetails,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: makitaTeal.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: makitaTeal, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "실제 커팅 기장 (총 기장)",
                      style: TextStyle(
                        color: makitaTeal,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "도면합계 + 총 연신율",
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
                Text(
                  totalConsumed > 0
                      ? "${totalConsumed.toStringAsFixed(1)} mm"
                      : "0.0 mm",
                  style: const TextStyle(
                    color: makitaTeal,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 🚀 바깥선 실측 참고 (다크 테마 앰버 컬러 최적화)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.amber.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.ruler, size: 22, color: Colors.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "현장 검수용 실측 참고 (바깥선/등 기준)",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "줄자 측정값 ≈ 도면상 합계(${pipeUsed > 0 ? pipeUsed.toStringAsFixed(1) : '0'}) + 튜브 반지름",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      if (pipeUsed > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            "※ 3/8\" 기준 약 ${(pipeUsed + 5.0).toStringAsFixed(1)} ~ ${(pipeUsed + 6.0).toStringAsFixed(1)} mm 예상",
                            style: TextStyle(
                              color: Colors.amber.shade400,
                              fontSize: 13,
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

          const SizedBox(height: 24),

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
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "1번 마킹 축소값: +${shrink.toStringAsFixed(1)} mm",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 52,
                width: 140, // 버튼을 시원하게
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
                      fontSize: 16,
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
