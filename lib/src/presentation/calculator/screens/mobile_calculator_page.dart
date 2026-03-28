import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// 🚀 결과 화면 및 데이터 관리 임포트
import 'package:tubing_calculator/src/data/bend_data_manager.dart';
import 'package:tubing_calculator/src/core/common_widgets/smart_save_pad.dart';
import 'package:tubing_calculator/src/core/engine/tube_bending_engine.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad.dart';

// 🚀 모바일 전용 3D 뷰어 임포트
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_pipe_visualizer.dart';

// 🚀 설정 화면 임포트
import 'package:tubing_calculator/src/core/utils/settings_manager.dart';
import 'package:tubing_calculator/src/presentation/settings/controllers/settings_controller.dart';
import 'package:tubing_calculator/src/presentation/settings/widgets/settings_widgets.dart';
import 'package:tubing_calculator/src/core/utils/fitting_data.dart';

// 🚀 [핵심 수정] 모바일 전용 특수 계산기 바텀시트 임포트!
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_rolling_offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_saddle_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_parallel_shrink_bottom_sheet.dart';

// 🚀 보관함(History) 구동 및 [모바일 전용 상세 화면] 임포트
import 'package:tubing_calculator/src/core/database/database_helper.dart';
import 'package:tubing_calculator/src/presentation/fabrication/screens/mobile_fabrication_detail_screen.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);
const Color toolGripBlack = Color(0xFF222222);
const Color hardwareButtonTeal = Color(0xFF005C63);

class MobileCalculatorPage extends StatefulWidget {
  const MobileCalculatorPage({super.key});

  @override
  State<MobileCalculatorPage> createState() => _MobileCalculatorPageState();
}

class _MobileCalculatorPageState extends State<MobileCalculatorPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  String _startDir = "RIGHT";

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onTabTapped(int index) {
    HapticFeedback.lightImpact();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slate100,
      appBar: AppBar(
        backgroundColor: makitaTeal,
        title: const Text(
          "모바일 벤딩 계산기",
          style: TextStyle(fontWeight: FontWeight.bold, color: pureWhite),
        ),
        iconTheme: const IconThemeData(color: pureWhite),
        elevation: 0,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(),
        children: [
          const MobileInputTab(),
          MobileResultTab(startDir: _startDir),
          MobileViewerTab(
            startDir: _startDir,
            onStartDirChanged: (val) => setState(() => _startDir = val),
          ),
          const MobileHistoryTab(),
          const MobileSettingsTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          backgroundColor: pureWhite,
          selectedItemColor: makitaTeal,
          unselectedItemColor: slate600,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 10,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.penTool),
              label: "입력",
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.calculator),
              label: "결과",
            ),
            BottomNavigationBarItem(icon: Icon(LucideIcons.box), label: "도면"),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_open),
              label: "보관함",
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.settings),
              label: "설정",
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 🚀 1탭: 모바일 치수 입력 (라인 빌더)
// ==========================================
class MobileInputTab extends StatefulWidget {
  const MobileInputTab({super.key});
  @override
  State<MobileInputTab> createState() => _MobileInputTabState();
}

class _MobileInputTabState extends State<MobileInputTab> {
  final TextEditingController _lengthController = TextEditingController();
  double _selectedAngle = 90.0;

  // 방향값 nullable 처리 (매번 선택 강제)
  double? _selectedRotation;

  final List<Map<String, dynamic>> _directions = [
    {"label": "UP (위)", "val": 0.0, "icon": Icons.arrow_upward},
    {"label": "FRONT (앞)", "val": 360.0, "icon": Icons.call_made},
    {"label": "LEFT (좌)", "val": 270.0, "icon": Icons.arrow_back},
    {"label": "RIGHT (우)", "val": 90.0, "icon": Icons.arrow_forward},
    {"label": "DOWN (아래)", "val": 180.0, "icon": Icons.arrow_downward},
    {"label": "BACK (뒤)", "val": 450.0, "icon": Icons.call_received},
  ];

  @override
  void dispose() {
    _lengthController.dispose();
    super.dispose();
  }

  void _addSegment() {
    double length = double.tryParse(_lengthController.text) ?? 0.0;

    if (length <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("정확한 길이를 입력해주세요."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_selectedAngle > 0 && _selectedRotation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("벤딩 진행 방향(6축)을 먼저 선택해주세요!"),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      BendDataManager().bendList.add({
        'length': length,
        'angle': _selectedAngle,
        'rotation': _selectedAngle == 0.0 ? 0.0 : _selectedRotation!,
      });
      _lengthController.clear();
      _selectedRotation = null; // 입력 후 리셋
    });
  }

  void _removeSegment(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      BendDataManager().bendList.removeAt(index);
    });
  }

  void _clearAll() {
    HapticFeedback.heavyImpact();
    setState(() {
      BendDataManager().bendList.clear();
    });
  }

  void _addMultipleBends(List<Map<String, double>> bends) {
    setState(() {
      BendDataManager().bendList.addAll(bends);
    });
  }

  void _addSingleBend(double length, double angle, double rotation) {
    setState(() {
      BendDataManager().bendList.add({
        'length': length,
        'angle': angle,
        'rotation': rotation,
      });
    });
  }

  void _showSpecialBendingMenu() {
    double currentRot = _selectedRotation ?? 90.0;
    if (BendDataManager().bendList.isNotEmpty) {
      final lastRot = BendDataManager().bendList.last['rotation'];
      currentRot = (lastRot as num?)?.toDouble() ?? (_selectedRotation ?? 90.0);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "특수 벤딩 계산 및 삽입",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: slate900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "현장 치수를 입력하면 벤딩 데이터가 자동으로 조립됩니다.",
                style: TextStyle(fontSize: 13, color: slate600),
              ),
              const SizedBox(height: 24),

              // 🚀 [수정] 모바일 전용 특수 벤딩 화면 호출
              _buildSpecialMenuBtn("일반 오프셋 (Offset)", Icons.timeline, () {
                Navigator.pop(context);
                MobileOffsetBottomSheet.show(
                  context,
                  currentRotation: currentRot,
                  onAddMultipleBends: _addMultipleBends,
                );
              }),
              _buildSpecialMenuBtn("롤링 오프셋 (Rolling Offset)", Icons.sync, () {
                Navigator.pop(context);
                MobileRollingOffsetBottomSheet.show(
                  context,
                  currentRotation: currentRot,
                  onAddBend: _addSingleBend,
                );
              }),
              _buildSpecialMenuBtn("새들 벤딩 (Saddle)", Icons.architecture, () {
                Navigator.pop(context);
                MobileSaddleBottomSheet.show(
                  context,
                  currentRotation: currentRot,
                  onAddBend: _addSingleBend,
                );
              }),
              _buildSpecialMenuBtn(
                "평행 및 축소값 (Parallel & Shrink)",
                Icons.grid_view,
                () {
                  Navigator.pop(context);
                  MobileParallelShrinkBottomSheet.show(
                    context,
                    currentAngle: _selectedAngle,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialMenuBtn(String title, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: makitaTeal.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: makitaTeal, size: 20),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: slate900,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bendList = BendDataManager().bendList;

    return Column(
      children: [
        Expanded(
          flex: 4,
          child: Container(
            color: slate100,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  color: pureWhite,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "배관 라인 리스트",
                        style: TextStyle(
                          color: slate900,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (bendList.isNotEmpty)
                        InkWell(
                          onTap: _clearAll,
                          child: const Text(
                            "전체 삭제",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: bendList.isEmpty
                      ? const Center(
                          child: Text(
                            "아래에서 수치와 방향을 입력해\n배관을 조립해 주세요.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: slate600, height: 1.5),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: bendList.length,
                          itemBuilder: (context, index) {
                            final item = bendList[index];
                            bool isStraight =
                                (item['angle'] as num?)?.toDouble() == 0.0;
                            double rotValue =
                                (item['rotation'] as num?)?.toDouble() ?? 0.0;
                            String dirLabel = _directions.firstWhere(
                              (d) => d['val'] == rotValue,
                              orElse: () => {"label": "N/A"},
                            )['label'];
                            IconData dirIcon = _directions.firstWhere(
                              (d) => d['val'] == rotValue,
                              orElse: () => {"icon": Icons.help},
                            )['icon'];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: pureWhite,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isStraight
                                      ? Colors.grey.shade200
                                      : makitaTeal.withValues(alpha: 0.1),
                                  child: Icon(
                                    isStraight ? Icons.straighten : dirIcon,
                                    color: isStraight ? slate600 : makitaTeal,
                                  ),
                                ),
                                title: Text(
                                  isStraight
                                      ? "직관 (Straight)"
                                      : "${(item['angle'] as num?)?.round()}° 벤딩 ($dirLabel)",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isStraight ? slate600 : slate900,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  "길이: ${item['length']} mm",
                                  style: const TextStyle(
                                    color: makitaTeal,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  onPressed: () => _removeSegment(index),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: pureWhite,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        "배관 형태",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: slate600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SegmentedButton<double>(
                          segments: const [
                            ButtonSegment(
                              value: 90.0,
                              label: Text(
                                "90° 벤딩",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            ButtonSegment(
                              value: 0.0,
                              label: Text(
                                "0° 직관",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          selected: {_selectedAngle},
                          onSelectionChanged: (Set<double> newSelection) {
                            setState(() {
                              _selectedAngle = newSelection.first;
                              if (_selectedAngle == 0.0)
                                _selectedRotation = null;
                            });
                          },
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.resolveWith<Color>((
                                  states,
                                ) {
                                  if (states.contains(WidgetState.selected))
                                    return makitaTeal;
                                  return Colors.grey.shade100;
                                }),
                            foregroundColor:
                                WidgetStateProperty.resolveWith<Color>((
                                  states,
                                ) {
                                  if (states.contains(WidgetState.selected))
                                    return pureWhite;
                                  return slate600;
                                }),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_selectedAngle > 0) ...[
                    Row(
                      children: [
                        Text(
                          "진행 방향 (6축)",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _selectedRotation == null
                                ? Colors.redAccent
                                : slate600,
                            fontSize: 13,
                          ),
                        ),
                        if (_selectedRotation == null)
                          const Text(
                            " *방향을 선택하세요",
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
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
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
                          onTap: () =>
                              setState(() => _selectedRotation = dir['val']),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? makitaTeal.withValues(alpha: 0.1)
                                  : Colors.grey.shade50,
                              border: Border.all(
                                color: isSelected
                                    ? makitaTeal
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  dir['icon'],
                                  size: 16,
                                  color: isSelected ? makitaTeal : slate600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  dir['label'].split(' ')[0],
                                  style: TextStyle(
                                    color: isSelected ? makitaTeal : slate900,
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
                    const SizedBox(height: 16),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "길이 (mm)",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: slate600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                await MakitaNumpad.show(
                                  context,
                                  controller: _lengthController,
                                  title: "배관 길이 (mm)",
                                );
                                setState(() {});
                              },
                              child: AbsorbPointer(
                                child: TextField(
                                  controller: _lengthController,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: makitaTeal,
                                    fontFamily: 'monospace',
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "0",
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    suffixIcon: const Icon(
                                      Icons.edit,
                                      color: slate600,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _addSegment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: makitaTeal,
                            foregroundColor: pureWhite,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          icon: const Icon(Icons.add_circle),
                          label: const Text(
                            "추가",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _showSpecialBendingMenu,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: makitaTeal, width: 1.5),
                        foregroundColor: makitaTeal,
                        backgroundColor: makitaTeal.withValues(alpha: 0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.auto_awesome_mosaic, size: 20),
                      label: const Text(
                        "특수 벤딩 (오프셋 / 새들) 계산기",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 🚀 2탭: 모바일 결과 (Marking) 화면
// ==========================================
class MobileResultTab extends StatefulWidget {
  final String startDir;
  const MobileResultTab({super.key, required this.startDir});
  @override
  State<MobileResultTab> createState() => _MobileResultTabState();
}

class _MobileResultTabState extends State<MobileResultTab> {
  bool _includeStartFitting = false;
  bool _includeEndFitting = false;
  double _tailLength = 0.0;
  final TextEditingController _tailController = TextEditingController(
    text: "0",
  );

  @override
  void initState() {
    super.initState();
    _refreshSettings();
  }

  Future<void> _refreshSettings() async {
    final dataManager = BendDataManager();
    await dataManager.loadSavedSettings();
    if (mounted) {
      setState(() {
        _includeStartFitting = dataManager.startFit;
        _includeEndFitting = dataManager.endFit;
        _tailLength = dataManager.tail;
        _tailController.text = _tailLength > 0
            ? _tailLength.round().toString()
            : "0";
      });
    }
  }

  @override
  void dispose() {
    _tailController.dispose();
    super.dispose();
  }

  String _getDirectionText(double rot) {
    if (rot == 0.0) return "UP";
    if (rot == 90.0) return "RIGHT";
    if (rot == 180.0) return "DOWN";
    if (rot == 270.0) return "LEFT";
    if (rot == 360.0) return "FRONT";
    if (rot == 450.0) return "BACK";
    return "${rot.toInt()}°";
  }

  IconData _getDirectionIcon(double rot) {
    if (rot == 0.0) return Icons.arrow_upward;
    if (rot == 90.0) return Icons.arrow_forward;
    if (rot == 180.0) return Icons.arrow_downward;
    if (rot == 270.0) return Icons.arrow_back;
    if (rot == 360.0) return Icons.call_made;
    if (rot == 450.0) return Icons.call_received;
    return Icons.rotate_right;
  }

  @override
  Widget build(BuildContext context) {
    final dataManager = BendDataManager();
    final bendList = dataManager.bendList;
    final double radius = dataManager.takeUp90;
    final double fittingDepth = dataManager.fittingDepth;
    final engine = TubeBendingEngine(radius: radius);

    List<BendInstruction> instructions = [];
    for (int i = 0; i < bendList.length; i++) {
      double l = (bendList[i]['length'] as num?)?.toDouble() ?? 0.0;
      if (i == 0 && _includeStartFitting) {
        l += fittingDepth;
      }
      if (i == bendList.length - 1 && _includeEndFitting) {
        l += fittingDepth;
      }
      instructions.add(
        BendInstruction(
          length: l,
          angle: (bendList[i]['angle'] as num?)?.toDouble() ?? 0.0,
          rotation: (bendList[i]['rotation'] as num?)?.toDouble() ?? 0.0,
        ),
      );
    }

    final result = engine.calculate(instructions, 0.0);
    final double pureCutLength = result['totalCutLength'];
    final List<StepResult> steps = result['steps'];

    List<Map<String, dynamic>> displayMarks = [];
    int markNumber = 1;
    double lastMarkingPoint = 0.0;
    double accumulatedIncremental = 0.0;

    for (int i = 0; i < bendList.length; i++) {
      double angleValue = (bendList[i]['angle'] as num?)?.toDouble() ?? 0.0;
      bool isStraight = angleValue == 0.0;
      double currentMark = steps[i].markingPoint;
      double currentLength = (bendList[i]['length'] as num?)?.toDouble() ?? 0.0;

      if (currentMark > lastMarkingPoint) {
        lastMarkingPoint = currentMark;
      }

      if (currentLength <= 0.01 && isStraight) {
        accumulatedIncremental += steps[i].incrementalMark;
        displayMarks.add({
          ...bendList[i],
          'is_straight': true,
          'is_hidden': true,
          'mark_num': 0,
          'marking_point': currentMark,
          'incremental_mark': 0.0,
        });
        continue;
      }

      if (isStraight) {
        accumulatedIncremental += steps[i].incrementalMark;
        displayMarks.add({
          ...bendList[i],
          'is_straight': true,
          'is_hidden': false,
          'mark_num': 0,
          'marking_point': currentMark,
          'incremental_mark': 0.0,
        });
      } else {
        displayMarks.add({
          ...bendList[i],
          'is_straight': false,
          'is_hidden': false,
          'mark_num': markNumber,
          'marking_point': currentMark,
          'incremental_mark': steps[i].incrementalMark + accumulatedIncremental,
        });
        markNumber++;
        accumulatedIncremental = 0.0;
      }
    }

    double totalCut = bendList.isEmpty ? 0.0 : pureCutLength + _tailLength;
    double diffAfterLastMark = (totalCut - lastMarkingPoint) - radius;
    if (diffAfterLastMark < 0) {
      diffAfterLastMark = 0;
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: pureWhite,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "TOTAL CUT LENGTH",
                      style: TextStyle(
                        color: slate600,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${totalCut.round()} mm",
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (bendList.isNotEmpty && diffAfterLastMark > 0)
                      Text(
                        "※ 마지막 벤딩 후 잔여: +${diffAfterLastMark.round()}mm",
                        style: TextStyle(
                          color: Colors.red.shade600,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "반경(R): ${radius.round()}mm",
                    style: const TextStyle(
                      color: slate600,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: makitaTeal,
                      foregroundColor: pureWhite,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () => _handleSave(totalCut, displayMarks),
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text(
                      "저장",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          color: pureWhite,
          margin: const EdgeInsets.only(top: 8),
          child: Column(
            children: [
              _buildOptionTile(
                title: "시작 피팅 (+${fittingDepth.round()}mm)",
                value: _includeStartFitting,
                onChanged: (v) => setState(() {
                  _includeStartFitting = v;
                  BendDataManager().startFit = v;
                }),
              ),
              Divider(
                height: 1,
                color: Colors.grey.shade200,
                indent: 20,
                endIndent: 20,
              ),
              _buildOptionTile(
                title: "종료 피팅 (+${fittingDepth.round()}mm)",
                value: _includeEndFitting,
                onChanged: (v) => setState(() {
                  _includeEndFitting = v;
                  BendDataManager().endFit = v;
                }),
              ),
              Divider(
                height: 1,
                color: Colors.grey.shade200,
                indent: 20,
                endIndent: 20,
              ),
              InkWell(
                onTap: _showTailPad,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.straighten, color: slate600, size: 20),
                          SizedBox(width: 12),
                          Text(
                            "절단 여유 기장 (Tail)",
                            style: TextStyle(
                              color: slate900,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "${_tailLength.round()} mm >",
                        style: const TextStyle(
                          color: makitaTeal,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          width: double.infinity,
          color: slate100,
          child: const Text(
            "MARKING POINTS (줄자 0점 고정)",
            style: TextStyle(
              color: slate600,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: displayMarks.isEmpty
              ? const Center(
                  child: Text(
                    "1번 탭에서 치수를 입력해주세요.",
                    style: TextStyle(color: slate600, fontSize: 14),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 40),
                  itemCount: displayMarks.length,
                  itemBuilder: (context, index) {
                    final item = displayMarks[index];

                    if (item['is_hidden'] == true) {
                      return const SizedBox.shrink();
                    }

                    int cumulativeMark =
                        (item['marking_point'] as num?)?.round() ?? 0;
                    int incrementalMark =
                        (item['incremental_mark'] as num?)?.round() ?? 0;
                    int originalLength = (item['length'] as num?)?.round() ?? 0;

                    if (item['is_straight'] == true) {
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.arrow_downward,
                              color: Colors.grey,
                              size: 16,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "직관 연장: +$originalLength mm",
                                style: const TextStyle(
                                  color: slate600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              "마킹: $cumulativeMark",
                              style: const TextStyle(
                                color: makitaTeal,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    double rotationVal =
                        (item['rotation'] as num?)?.toDouble() ?? 0.0;
                    double angleVal =
                        (item['angle'] as num?)?.toDouble() ?? 0.0;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: pureWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: makitaTeal.withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: makitaTeal,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "${item['mark_num']}",
                              style: const TextStyle(
                                color: pureWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "누적 마킹 지점",
                                  style: TextStyle(
                                    color: slate600,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  "$cumulativeMark",
                                  style: const TextStyle(
                                    color: slate900,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                if ((item['mark_num'] as num?) != null &&
                                    (item['mark_num'] as num) > 1)
                                  Text(
                                    "↳ 앞 마킹과의 거리: +$incrementalMark",
                                    style: const TextStyle(
                                      color: makitaTeal,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "길이: $originalLength",
                                style: const TextStyle(
                                  color: slate900,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    _getDirectionIcon(rotationVal),
                                    size: 16,
                                    color: makitaTeal,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${angleVal.round()}° / ${_getDirectionText(rotationVal)}",
                                    style: const TextStyle(
                                      color: makitaTeal,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        child: Row(
          children: [
            Icon(
              value ? Icons.check_circle : Icons.radio_button_unchecked,
              color: value ? makitaTeal : slate600,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: value ? slate900 : slate600,
                fontSize: 15,
                fontWeight: value ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSave(double totalCut, List<Map<String, dynamic>> saveList) {
    final finalSaveData = List<Map<String, dynamic>>.from(
      saveList.map((e) => Map<String, dynamic>.from(e)),
    );
    if (finalSaveData.isNotEmpty) {
      finalSaveData[0]['start_fit_applied'] = _includeStartFitting;
      finalSaveData[finalSaveData.length - 1]['end_fit_applied'] =
          _includeEndFitting;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SmartSavePad(
        totalCut: totalCut,
        bendList: finalSaveData,
        includeStart: _includeStartFitting,
        includeEnd: _includeEndFitting,
        tailLength: _tailLength,
        startDir: widget.startDir,
        onSaveCallback: null,
      ),
    );
  }

  void _showTailPad() async {
    _tailController.text = _tailLength > 0
        ? _tailLength.round().toString()
        : "";
    await MakitaNumpad.show(
      context,
      controller: _tailController,
      title: "절단 여유 기장 (mm)",
    );
    if (!mounted) return;

    double val = double.tryParse(_tailController.text) ?? 0.0;

    setState(() {
      _tailLength = val;
      BendDataManager().tail = _tailLength;
    });
  }
}

// ==========================================
// 🚀 3탭: 모바일 도면 (3D Viewer) 화면
// ==========================================
class MobileViewerTab extends StatelessWidget {
  final String startDir;
  final ValueChanged<String>? onStartDirChanged;

  const MobileViewerTab({
    super.key,
    required this.startDir,
    this.onStartDirChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dataManager = BendDataManager();
    final bendList = dataManager.bendList;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: pureWhite,
          child: const Row(
            children: [
              Icon(Icons.threed_rotation, color: makitaTeal, size: 20),
              SizedBox(width: 10),
              Text(
                "ISO 3D 도면 뷰어 (드래그하여 회전)",
                style: TextStyle(
                  color: slate900,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: bendList.isEmpty
              ? const Center(
                  child: Text(
                    "입력된 치수가 없습니다.",
                    style: TextStyle(color: slate600, fontSize: 14),
                  ),
                )
              : MobilePipeVisualizer(
                  bendList: bendList,
                  tailLength: dataManager.tail,
                  initialStartDir: startDir,
                  onStartDirChanged: onStartDirChanged,
                  startFit: dataManager.startFit,
                  endFit: dataManager.endFit,
                  isLightMode: false, // 🚀 모바일 뷰어 다크모드 적용
                ),
        ),
      ],
    );
  }
}

// ==========================================
// 🚀 4탭: 모바일 보관함 (History) 화면
// ==========================================
class MobileHistoryTab extends StatefulWidget {
  const MobileHistoryTab({super.key});

  @override
  State<MobileHistoryTab> createState() => _MobileHistoryTabState();
}

class _MobileHistoryTabState extends State<MobileHistoryTab> {
  Map<String, List<Map<String, dynamic>>> _groupedHistory = {};
  bool _isLoading = true;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshHistory() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getHistory();
    if (!mounted) return;

    Map<String, List<Map<String, dynamic>>> tempGrouped = {};
    for (var item in data) {
      String rawPtoP = item['p_to_p'] ?? '{}';
      String project = "미지정 프로젝트";
      try {
        var pData = jsonDecode(rawPtoP);
        if (pData['project'] != null &&
            pData['project'].toString().trim().isNotEmpty) {
          project = pData['project'];
        }
      } catch (_) {}

      if (!tempGrouped.containsKey(project)) {
        tempGrouped[project] = [];
      }
      tempGrouped[project]!.add(item);
    }

    tempGrouped.forEach((key, list) {
      list.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
    });

    setState(() {
      _groupedHistory = tempGrouped;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Map<String, List<Map<String, dynamic>>> filteredGroupedHistory = {};

    if (_searchQuery.isEmpty) {
      filteredGroupedHistory = _groupedHistory;
    } else {
      _groupedHistory.forEach((folderName, items) {
        bool folderMatches = folderName.toLowerCase().contains(_searchQuery);
        List<Map<String, dynamic>> matchingItems = items.where((item) {
          String rawPtoP = item['p_to_p'] ?? '{}';
          String fromTo = "";
          try {
            var pData = jsonDecode(rawPtoP);
            fromTo = "${pData['from']} ➔ ${pData['to']}".toLowerCase();
          } catch (_) {}
          return fromTo.contains(_searchQuery);
        }).toList();

        if (folderMatches) {
          filteredGroupedHistory[folderName] = items;
        } else if (matchingItems.isNotEmpty) {
          filteredGroupedHistory[folderName] = matchingItems;
        }
      });
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: pureWhite,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '프로젝트명 또는 경로 검색...',
              hintStyle: const TextStyle(color: slate600),
              prefixIcon: const Icon(Icons.search, color: makitaTeal),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.cancel, color: slate600),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                      },
                    )
                  : null,
              filled: true,
              fillColor: slate100,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) =>
                setState(() => _searchQuery = val.toLowerCase()),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: makitaTeal),
                )
              : filteredGroupedHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_off,
                        size: 80,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? '검색 결과가 없습니다.'
                            : '저장된 도면이 없습니다.',
                        style: const TextStyle(
                          color: slate600,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredGroupedHistory.keys.length,
                  itemBuilder: (context, index) {
                    String folderName = filteredGroupedHistory.keys.elementAt(
                      index,
                    );
                    List<Map<String, dynamic>> folderItems =
                        filteredGroupedHistory[folderName]!;

                    return Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: pureWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ExpansionTile(
                          initiallyExpanded:
                              index == 0 || _searchQuery.isNotEmpty,
                          iconColor: makitaTeal,
                          collapsedIconColor: slate600,
                          leading: const Icon(
                            Icons.folder,
                            color: makitaTeal,
                            size: 28,
                          ),
                          title: Text(
                            "$folderName (${folderItems.length})",
                            style: const TextStyle(
                              color: slate900,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          children: folderItems.map((item) {
                            String rawPtoP = item['p_to_p'] ?? '{}';
                            String fromTo = "경로 미상";
                            try {
                              var pData = jsonDecode(rawPtoP);
                              fromTo = "${pData['from']} ➔ ${pData['to']}";
                            } catch (_) {}

                            double cutRaw =
                                double.tryParse(
                                  item['total_length'].toString(),
                                ) ??
                                0.0;
                            int cutDisplay = cutRaw.round();

                            return Container(
                              margin: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                bottom: 12,
                              ),
                              decoration: BoxDecoration(
                                color: slate100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          MobileFabricationDetailScreen(
                                            itemData: item,
                                          ),
                                    ),
                                  );
                                  if (!context.mounted) return;
                                  _refreshHistory();
                                },
                                title: Text(
                                  fromTo,
                                  style: const TextStyle(
                                    color: makitaTeal,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.straighten,
                                            size: 14,
                                            color: slate600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Total Cut: $cutDisplay mm",
                                            style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            "Size: ${item['pipe_size']}",
                                            style: const TextStyle(
                                              color: slate600,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "날짜: ${item['date']?.toString().substring(0, 10) ?? ''}",
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: Colors.red.shade400,
                                  ),
                                  onPressed: () async {
                                    bool? confirm = await showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: pureWhite,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        title: const Text(
                                          "삭제 확인",
                                          style: TextStyle(
                                            color: slate900,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        content: const Text(
                                          "이 도면을 보관함에서 영구 삭제하시겠습니까?",
                                          style: TextStyle(color: slate600),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text(
                                              "취소",
                                              style: TextStyle(
                                                color: slate600,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: Text(
                                              "삭제",
                                              style: TextStyle(
                                                color: Colors.red.shade600,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await DatabaseHelper.instance
                                          .deleteHistory(item['id']);
                                      if (!context.mounted) return;
                                      _refreshHistory();
                                    }
                                  },
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ==========================================
// 🚀 5탭: 모바일 설정 (Settings) 화면 및 가이드
// ==========================================
class MobileSettingsTab extends StatefulWidget {
  const MobileSettingsTab({super.key});
  @override
  State<MobileSettingsTab> createState() => _MobileSettingsTabState();
}

class _MobileSettingsTabState extends State<MobileSettingsTab> {
  bool _isInch = false;
  bool _useHaptic = true;
  bool _saveHistory = true;

  String _tubeMaterial = "SUS";
  String _benderBrand = "Swagelok";
  String _benderType = "수동 (Hand)";
  String _currentOD = "";

  final String _measurementMode = "C-to-C";
  String _defaultRotation = "CW (시계방향)";
  String _fittingType = "Twin Ferrule";
  String _benderMark = "0 (기본/다양한 각도)";

  final Map<String, bool> _autoStates = {
    'radius': true,
    'takeUp': true,
    'gain': true,
    'minStraight': true,
    'offset': true,
    'fittingDepth': true,
  };

  final _wtController = TextEditingController();
  final _rController = TextEditingController();
  final _takeUpController = TextEditingController();
  final _springbackController = TextEditingController();
  final _gainController = TextEditingController();
  final _minStraightController = TextEditingController();
  final _benderOffsetController = TextEditingController();
  final _fittingDepthController = TextEditingController();
  final _markThicknessController = TextEditingController();
  final _offsetShrinkController = TextEditingController();

  String get _unit => _isInch ? "inch" : "mm";
  List<String> get _odList => SettingsController.getOdList(_isInch);
  bool get _isElectric => _benderType == "전동 (Electric)";

  @override
  void initState() {
    super.initState();
    _currentOD = _odList.contains("12.7") ? "12.7" : _odList.first;
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await SettingsManager.loadSettings();
    final prefs = await SharedPreferences.getInstance();

    if (mounted) {
      setState(() {
        _isInch = data['isInch'] ?? false;
        _useHaptic = data['useHaptic'] ?? true;
        _saveHistory = data['saveHistory'] ?? true;
        _tubeMaterial = data['tubeMaterial'] ?? "SUS";
        _benderBrand = data['benderBrand'] ?? "Swagelok";
        _benderType = prefs.getString('benderType') ?? "수동 (Hand)";
        _defaultRotation = data['defaultRotation'] ?? "CW (시계방향)";
        _fittingType = data['fittingType'] ?? "Twin Ferrule";
        _benderMark = data['benderMark'] ?? "0 (기본/다양한 각도)";

        String loadedOD = (data['tubeOD'] ?? (_isInch ? 0.5 : 12.7)).toString();
        if (!loadedOD.contains('.')) loadedOD += ".0";
        _currentOD = _odList.contains(loadedOD) ? loadedOD : _odList.first;

        _autoStates['radius'] = data['auto_radius'] ?? true;
        _autoStates['takeUp'] = data['auto_takeUp'] ?? true;
        _autoStates['gain'] = data['auto_gain'] ?? true;
        _autoStates['minStraight'] = data['auto_minStraight'] ?? true;
        _autoStates['offset'] = data['auto_offset'] ?? true;
        _autoStates['fittingDepth'] = data['auto_fittingDepth'] ?? true;

        _wtController.text = (data['tubeWT'] ?? 0.0).toString();
        _springbackController.text = (data['springback'] ?? 0.0).toString();
        _markThicknessController.text = (data['markThickness'] ?? 0.0)
            .toString();
        _offsetShrinkController.text = (data['offsetShrink'] ?? 0.0).toString();

        if (_autoStates['radius'] == false) {
          _rController.text = (data['bendRadius'] ?? 0.0).toString();
        }
        if (_autoStates['takeUp'] == false) {
          _takeUpController.text = (data['takeUp'] ?? 0.0).toString();
        }
        if (_autoStates['gain'] == false) {
          _gainController.text = (data['gain'] ?? 0.0).toString();
        }
        if (_autoStates['minStraight'] == false) {
          _minStraightController.text = (data['minStraight'] ?? 0.0).toString();
        }
        if (_autoStates['offset'] == false) {
          _benderOffsetController.text = (data['benderOffset'] ?? 0.0)
              .toString();
        }
        if (_autoStates['fittingDepth'] == false) {
          _fittingDepthController.text = (data['fittingDepth'] ?? 0.0)
              .toString();
        }
      });
      _onSpecsChanged(isInitialLoad: true);
    }
  }

  Future<void> _saveData() async {
    FocusScope.of(context).unfocus();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('benderType', _benderType);

    await SettingsManager.saveSettings(
      isInch: _isInch,
      useHaptic: _useHaptic,
      saveHistory: _saveHistory,
      tubeMaterial: _tubeMaterial,
      benderBrand: _benderBrand,
      measurementMode: _measurementMode,
      defaultRotation: _defaultRotation,
      fittingType: _fittingType,
      benderMark: _benderMark,
      tubeOD: double.tryParse(_currentOD) ?? 0.0,
      tubeWT: double.tryParse(_wtController.text) ?? 0.0,
      bendRadius: double.tryParse(_rController.text) ?? 0.0,
      takeUp: double.tryParse(_takeUpController.text) ?? 0.0,
      springback: double.tryParse(_springbackController.text) ?? 0.0,
      gain: double.tryParse(_gainController.text) ?? 0.0,
      minStraight: double.tryParse(_minStraightController.text) ?? 0.0,
      benderOffset: double.tryParse(_benderOffsetController.text) ?? 0.0,
      fittingDepth: double.tryParse(_fittingDepthController.text) ?? 0.0,
      markThickness: double.tryParse(_markThicknessController.text) ?? 0.0,
      offsetShrink: double.tryParse(_offsetShrinkController.text) ?? 0.0,
      cutMargin: 0.0,
      autoRadius: _autoStates['radius'] ?? true,
      autoTakeUp: _autoStates['takeUp'] ?? true,
      autoGain: _autoStates['gain'] ?? true,
      autoMinStraight: _autoStates['minStraight'] ?? true,
      autoOffset: _autoStates['offset'] ?? true,
      autoFittingDepth: _autoStates['fittingDepth'] ?? true,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isElectric ? "전동 장비 설정이 저장되었습니다." : "수동 장비 설정이 저장되었습니다.",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: makitaTeal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onSpecsChanged({bool isInitialLoad = false}) {
    final specs = SettingsController.getStandardSpecs(_benderBrand, _currentOD);
    setState(() {
      if (specs != null) {
        if (_autoStates['radius'] == true) {
          _rController.text = specs.bendRadius.toString();
        }
        if (_autoStates['takeUp'] == true) {
          _takeUpController.text = specs.takeUp.toString();
        }
        if (_autoStates['gain'] == true) {
          _gainController.text = specs.gain.toString();
        }
        if (_autoStates['minStraight'] == true) {
          _minStraightController.text = specs.minStraight.toString();
        }
        if (_autoStates['offset'] == true) {
          _benderOffsetController.text = specs.benderOffset.toString();
        }
      }
      if (_autoStates['fittingDepth'] == true) {
        if (_fittingType == "Twin Ferrule") {
          double depth = FittingData.getInsertionDepth(
            _benderBrand,
            _currentOD,
          );
          _fittingDepthController.text = depth > 0 ? depth.toString() : "";
        } else {
          _fittingDepthController.text = "";
        }
      }
    });
  }

  @override
  void dispose() {
    _wtController.dispose();
    _rController.dispose();
    _takeUpController.dispose();
    _springbackController.dispose();
    _gainController.dispose();
    _minStraightController.dispose();
    _benderOffsetController.dispose();
    _fittingDepthController.dispose();
    _markThicknessController.dispose();
    _offsetShrinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._buildLeftInputSettingsGroup(),
                  const SizedBox(height: 24),
                  ..._buildRightGuideGroup(),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pureWhite,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _saveData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: makitaTeal,
                    foregroundColor: pureWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.save),
                  label: const Text(
                    "설정 저장 및 적용",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 공통 박스 디자인 헬퍼 ---
  Widget _machineSpecText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _guideText(String title, String desc, {Color color = Colors.black87}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 12, color: color, height: 1.5),
          children: [
            TextSpan(
              text: "$title: ",
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
            TextSpan(text: desc),
          ],
        ),
      ),
    );
  }

  TableRow _buildGuideRow4Col(
    String col1,
    String col2,
    String col3,
    String col4, {
    bool isHighlight = false,
  }) {
    Color bgColor = isHighlight
        ? Colors.orange.withValues(alpha: 0.1)
        : Colors.transparent;
    return TableRow(
      decoration: BoxDecoration(color: bgColor),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            col1,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.black87,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            col2,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.black87,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            col3,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            col4,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.black87,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildGuideRow3Col(
    String col1,
    String col2,
    String col3, [
    Color color3 = Colors.black87,
  ]) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Text(
            col1,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Text(
            col2,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Text(
            col3,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color3,
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildGuideRow2Col(
    String col1,
    String col2, [
    Color color2 = Colors.black87,
  ]) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Text(
            col1,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Text(
            col2,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color2,
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildOffsetRow(
    String angle,
    String mult,
    String shrink,
    Color pointColor,
  ) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Text(
            angle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Text(
            mult,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: pointColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Text(
            shrink,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownWithHelper({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String Function(String)? displayMapper,
    required String helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingDropdownField(
          label: label,
          value: value,
          items: items,
          onChanged: onChanged,
          displayMapper: displayMapper,
        ),
        const SizedBox(height: 6),
        Text(
          helperText,
          style: TextStyle(
            fontSize: 11,
            color: Colors.blueGrey[700],
            fontWeight: FontWeight.w600,
            height: 1.4,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLockedMeasurementMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "측정 기준 (Fixed Mode)",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, size: 16, color: makitaTeal),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "C-to-C 고정",
                      style: TextStyle(
                        color: toolGripBlack,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "가상 센터라인 기준",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blueGrey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNumpadInput(
    String label,
    TextEditingController controller, {
    String? key,
    String? helperText,
  }) {
    return MakitaNumericInput(
      label: label,
      controller: controller,
      helperText: helperText,
      isAutoMode: key != null ? _autoStates[key] : null,
      onModeChanged: key != null
          ? (isAuto) {
              setState(() => _autoStates[key] = isAuto);
              if (isAuto) {
                _onSpecsChanged();
              }
            }
          : null,
      onTap: () {
        if (key == null || _autoStates[key] != true) {
          MakitaNumpad.show(context, controller: controller, title: label);
        }
      },
    );
  }

  Widget _buildSwitchRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SettingLabel(text: label),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: makitaTeal,
          ),
        ],
      ),
    );
  }

  Widget _buildUnitToggle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          const SettingLabel(text: "측정 단위 (Unit)"),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                _buildUnitBtn("mm", !_isInch),
                _buildUnitBtn("inch", _isInch),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitBtn(String text, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _isInch = (text == "inch");
          String targetOD = _isInch ? "0.5" : "12.0";
          _currentOD = _odList.contains(targetOD) ? targetOD : _odList.first;
        });
        _onSpecsChanged();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? makitaTeal : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLeftInputSettingsGroup() {
    return [
      SettingSection(
        title: "1. 튜브 기본 제원",
        icon: Icons.architecture,
        child: Column(
          children: [
            _buildUnitToggle(),
            const SizedBox(height: 8),
            TwoColumnRow(
              left: _buildDropdownWithHelper(
                label: "외경 (OD) [$_unit]",
                value: _currentOD,
                items: _odList,
                onChanged: (val) {
                  setState(() => _currentOD = val!);
                  _onSpecsChanged();
                },
                displayMapper: (item) =>
                    SettingsController.getDisplayOD(item, _isInch),
                helperText: "※ 배관의 바깥쪽 지름",
              ),
              right: _buildNumpadInput(
                "두께 (WT) [mm]",
                _wtController,
                helperText: "※ 배관 벽의 두께",
              ),
            ),
            const SizedBox(height: 12),
            TwoColumnRow(
              left: _buildDropdownWithHelper(
                label: "튜브 재질",
                value: _tubeMaterial,
                items: const ["SUS", "Copper", "Carbon", "Aluminum"],
                onChanged: (val) => setState(() => _tubeMaterial = val!),
                helperText: "※ 재질별 특성",
              ),
              right: _buildDropdownWithHelper(
                label: "피팅 타입",
                value: _fittingType,
                items: const ["Twin Ferrule", "Bite Type", "Flare"],
                onChanged: (val) {
                  setState(() => _fittingType = val!);
                  _onSpecsChanged();
                },
                helperText: "※ 삽입 깊이 기준",
              ),
            ),
          ],
        ),
      ),
      SettingSection(
        title: "2. 배관 조립 및 마킹 기준",
        icon: Icons.straighten,
        child: Column(
          children: [
            TwoColumnRow(
              left: _buildLockedMeasurementMode(),
              right: _buildDropdownWithHelper(
                label: "기본 회전",
                value: _defaultRotation,
                items: const ["CW (시계방향)", "CCW (반시계)"],
                onChanged: (val) => setState(() => _defaultRotation = val!),
                helperText: "※ 도면 기준 방향",
              ),
            ),
            const SizedBox(height: 12),
            TwoColumnRow(
              left: _buildNumpadInput(
                "피팅 삽입 깊이 [mm]",
                _fittingDepthController,
                key: 'fittingDepth',
                helperText: "※ 전체 체결 기준",
              ),
              right: _isElectric
                  ? const SizedBox.shrink()
                  : _buildDropdownWithHelper(
                      label: "마커 정렬",
                      value: _benderMark,
                      items: const [
                        "0 (기본/다양한 각도)",
                        "L (90도 정방향)",
                        "R (90도 역방향)",
                      ],
                      onChanged: (val) => setState(() => _benderMark = val!),
                      helperText: "• 0: 기본\n• L/R: 90도 전용",
                    ),
            ),
          ],
        ),
      ),
      SettingSection(
        title: "3. 벤더 장비 제원",
        icon: Icons.build,
        child: Column(
          children: [
            TwoColumnRow(
              left: _buildDropdownWithHelper(
                label: "벤더 브랜드",
                value: _benderBrand,
                items: const [
                  "Swagelok",
                  "Hy-Lok",
                  "Parker",
                  "Ridgid",
                  "TRACTO-TECHNIK",
                  "Other",
                ],
                onChanged: (val) {
                  setState(() => _benderBrand = val!);
                  _onSpecsChanged();
                },
                helperText: "※ 브랜드별 가이드",
              ),
              right: _buildDropdownWithHelper(
                label: "장비 타입 선택",
                value: _benderType,
                items: const ["수동 (Hand)", "전동 (Electric)"],
                onChanged: (val) {
                  setState(() => _benderType = val!);
                  _onSpecsChanged();
                },
                helperText: "※ 수동/전동 가이드",
              ),
            ),
            const SizedBox(height: 16),
            if (_isElectric) ...[
              TwoColumnRow(
                left: _buildNumpadInput(
                  "금형 반경 (CLR) [mm]",
                  _rController,
                  key: 'radius',
                  helperText: "※ 다이 R값",
                ),
                right: _buildNumpadInput(
                  "클램프 물림 길이 [mm]",
                  _minStraightController,
                  key: 'minStraight',
                  helperText: "※ 최소 구간",
                ),
              ),
              const SizedBox(height: 12),
              TwoColumnRow(
                left: _buildNumpadInput(
                  "연신율 (Gain) [mm]",
                  _gainController,
                  key: 'gain',
                  helperText: "※ 늘어나는 양",
                ),
                right: _buildNumpadInput(
                  "스프링백 보상 [°]",
                  _springbackController,
                  helperText: "※ 보통 1~3° 입력",
                ),
              ),
              const SizedBox(height: 12),
              TwoColumnRow(
                left: _buildNumpadInput(
                  "장비 원점 오프셋 [mm]",
                  _benderOffsetController,
                  key: 'offset',
                  helperText: "※ 클램프 끝 ~ 다이 0점",
                ),
                right: const SizedBox.shrink(),
              ),
            ] else ...[
              TwoColumnRow(
                left: _buildNumpadInput(
                  "벤드 반경 (R) [mm]",
                  _rController,
                  key: 'radius',
                  helperText: "※ 다이 중심 ~ 튜브 중심",
                ),
                right: _buildNumpadInput(
                  "테이크업 [mm]",
                  _takeUpController,
                  key: 'takeUp',
                  helperText: "※ 차감 보정치",
                ),
              ),
              const SizedBox(height: 12),
              TwoColumnRow(
                left: _buildNumpadInput(
                  "연신율 (Gain) [mm]",
                  _gainController,
                  key: 'gain',
                  helperText: "※ 늘어나는 총 길이",
                ),
                right: _buildNumpadInput(
                  "최소 직선 구간 [mm]",
                  _minStraightController,
                  key: 'minStraight',
                  helperText: "※ 벤더 후크 물림 최소장",
                ),
              ),
              const SizedBox(height: 12),
              TwoColumnRow(
                left: _buildNumpadInput(
                  "기준선 오프셋 [mm]",
                  _benderOffsetController,
                  key: 'offset',
                  helperText: "※ 다이 0점과 실제 시작점",
                ),
                right: _buildNumpadInput(
                  "스프링백 [°]",
                  _springbackController,
                  helperText: "※ 탄성 복원 각도 보정치",
                ),
              ),
            ],
          ],
        ),
      ),
      SettingSection(
        title: "4. 오차 보정 및 앱 설정",
        icon: Icons.settings_suggest,
        child: Column(
          children: [
            if (!_isElectric) ...[
              TwoColumnRow(
                left: _buildNumpadInput(
                  "마킹선 두께 [mm]",
                  _markThicknessController,
                  helperText: "※ 마커 펜촉 미세 보정",
                ),
                right: _buildNumpadInput(
                  "오프셋 축소 [mm]",
                  _offsetShrinkController,
                  helperText: "※ 간섭 회피용 여유 축소값",
                ),
              ),
              const Divider(color: Colors.black12, height: 24),
            ],
            _buildSwitchRow(
              "진동 피드백 (Haptic)",
              _useHaptic,
              (val) => setState(() => _useHaptic = val),
            ),
            _buildSwitchRow(
              "기록 자동 저장 (History)",
              _saveHistory,
              (val) => setState(() => _saveHistory = val),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildRightGuideGroup() {
    return [
      if (_isElectric)
        _buildElectricUnifiedGuide()
      else
        _buildManualUnifiedGuide(),
      _buildHoneyJarReferenceCard(),
    ];
  }

  Widget _buildElectricUnifiedGuide() {
    bool isSwagelok = _benderBrand == "Swagelok";
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.precision_manufacturing,
                color: Colors.orange.shade800,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                isSwagelok
                    ? "Swagelok 전동기 가이드 (MS-BTB)"
                    : "TRACTO-TECHNIK 전동기 가이드 (TB20D)",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isSwagelok) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _machineSpecText("모델명 (Type)", "Swagelok MS-BTB Series"),
                  _machineSpecText("적용 규격", "1/2\" ~ 1-1/4\" (주력: 3/4\", 1\")"),
                  _machineSpecText("구동 방식", "전자식 제어 펜던트 & 모터 구동"),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "🔧 제어반(Pendant) 조작 매뉴얼",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            _guideText(
              "1. 툴링 세팅",
              "관경(3/4\" 또는 1\")에 맞는 벤드 슈(Bend Shoe)와 롤러 서포트(Roller Support)를 장착합니다.",
            ),
            _guideText(
              "2. 기기 초기화",
              "전원 스위치를 켜고 펜던트의 [RETURN] 버튼을 눌러 벤드 슈를 0° 원점 위치로 복귀시킵니다.",
            ),
            _guideText(
              "3. 각도/스프링백",
              "펜던트의 [ANGLE] 버튼을 눌러 목표 각도를, [SPRINGBACK] 버튼을 눌러 탄성 보정값(SUS 통상 1.5°~3.0°)을 입력합니다.",
            ),
            _guideText(
              "4. 파이프 고정",
              "파이프를 삽입하고 토글 클램프(Toggle Clamp) 레버를 끝까지 밀어 고정시킵니다.",
            ),
            _guideText(
              "5. 벤딩 실행",
              "펜던트의 [BEND] 버튼을 누르고 있으면 벤딩이 진행됩니다. 벤딩 후 [RETURN]을 눌러 원위치시킵니다.",
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "알루미늄 가이드 롤러에 'Swagelok 전용 윤활유'를 반드시 도포하십시오. 미도포 시 대구경 튜브 찌그러짐(Ovality)이 발생합니다.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "📊 대구경 집중 권장 제원표 (SUS 기준)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(1.2),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1),
                },
                border: TableBorder.symmetric(
                  inside: BorderSide(color: Colors.grey.shade200),
                ),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          "규격 (OD)",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          "표준 R (CLR)",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          "연신율",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          "최소물림",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildGuideRow4Col(
                    "1/2\" (12.7)",
                    "R 38.1 (1.5\")",
                    "약 16.5",
                    "65 mm",
                  ),
                  _buildGuideRow4Col(
                    "3/4\" (19.05)",
                    "R 76.2 (3.0\")",
                    "약 32.5",
                    "85 mm",
                    isHighlight: true,
                  ),
                  _buildGuideRow4Col(
                    "1\" (25.4)",
                    "R 101.6 (4.0\")",
                    "약 43.5",
                    "110 mm",
                    isHighlight: true,
                  ),
                  _buildGuideRow4Col(
                    "1-1/4\" (31.75)",
                    "R 127.0 (5.0\")",
                    "약 55.0",
                    "130 mm",
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _machineSpecText("모델명 (Type)", "TUBOBEND TB20D"),
                  _machineSpecText("일련번호 (Serial)", "286"),
                  _machineSpecText("제작 연도 (Year)", "2020년"),
                  _machineSpecText(
                    "제조사 (Maker)",
                    "TRACTO-TECHNIK GmbH & Co.KG (독일)",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "🔧 제어반(HMI) 조작 매뉴얼",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            _guideText(
              "1. 기기 초기화",
              "전원(Main Switch) 인가 후, 터치패널에서 [HOME] 또는 [RESET] 버튼을 눌러 C축(벤딩 암)을 0° 원점으로 복귀시킵니다.",
            ),
            _guideText(
              "2. 프로그램 입력",
              "화면의 [PROG] 버튼을 눌러 빈 슬롯을 선택합니다.\n• [ANGLE] 칸에 앱에서 계산된 각도를 입력합니다.\n• [SPRINGBACK] 칸에 재질별 탄성 보정값을 입력하고 [ENTER]로 저장합니다.",
            ),
            _guideText(
              "3. 클램핑 조작",
              "다이(Die)에 파이프를 삽입하여 최소 물림 길이 이상 확보한 뒤, 제어반의 [CLAMP] 버튼을 눌러 파이프를 고정합니다.",
            ),
            _guideText(
              "4. 벤딩 실행",
              "[MANUAL] 또는 [AUTO] 모드 선택 후, 풋스위치를 끝까지 밟아 벤딩을 실행합니다. 종료 후 [OPEN]을 눌러 파이프를 분리합니다.",
            ),
            const SizedBox(height: 16),
            const Text(
              "📊 규격별 권장 연신율 표 (SUS 기준)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                },
                border: TableBorder.symmetric(
                  inside: BorderSide(color: Colors.grey.shade200),
                ),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          "규격(OD)",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          "표준 금형(CLR)",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          "권장 연신율",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildGuideRow3Col(
                    "1/4\" (6.35)",
                    "R15.0",
                    "7.0 ~ 8.0",
                    Colors.orange.shade900,
                  ),
                  _buildGuideRow3Col(
                    "3/8\" (9.52)",
                    "R22.5",
                    "11.0 ~ 12.5",
                    Colors.orange.shade900,
                  ),
                  _buildGuideRow3Col(
                    "1/2\" (12.7)",
                    "R35.0",
                    "18.0 ~ 20.0",
                    Colors.orange.shade900,
                  ),
                  _buildGuideRow3Col(
                    "25mm",
                    "R75.0",
                    "38.0 ~ 42.0",
                    Colors.orange.shade900,
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 40, color: Colors.black12, thickness: 1),
          Row(
            children: [
              Icon(Icons.calculate, color: Colors.blueGrey.shade800, size: 20),
              const SizedBox(width: 8),
              Text(
                "📐 연신율(Gain) 산출 공식 및 실무 적용",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Colors.blueGrey.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                const Text(
                  "이론상 90° 연신율 공식 (Centerline 기준)",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Gain = (2 × R) - (1.57 × R) = 0.43 × R",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.blueGrey.shade800,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "⚠️ 위 공식은 '관의 중심선'을 기준으로 한 제조사 이론값입니다. 실제 벤딩 시에는 파이프의 외경(OD)과 두께(WT)에 의해 중립축이 안쪽으로 이동하므로, 파이프가 더 길게 늘어납니다. 반드시 시편을 꺾어 실제 기장을 측정한 뒤 [MAN(수동)] 모드에 실측값을 입력하십시오.",
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Divider(height: 40, color: Colors.black12, thickness: 1),
          Row(
            children: [
              Icon(Icons.call_split, color: Colors.orange.shade800, size: 20),
              const SizedBox(width: 8),
              Text(
                "공통 오프셋 (Offset) 벤딩 배수표",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1.2),
                2: FlexColumnWidth(1.2),
              },
              border: TableBorder.symmetric(
                inside: BorderSide(color: Colors.grey.shade200),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "벤딩 각도",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "마킹 배수 (×)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Color(0xFF007580),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "축소량 (×)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                _buildOffsetRow("15°", "3.86", "0.13", Colors.orange.shade900),
                _buildOffsetRow(
                  "22.5°",
                  "2.61",
                  "0.20",
                  Colors.orange.shade900,
                ),
                _buildOffsetRow("30°", "2.00", "0.27", Colors.orange.shade900),
                _buildOffsetRow("45°", "1.41", "0.41", Colors.orange.shade900),
                _buildOffsetRow("60°", "1.15", "0.58", Colors.orange.shade900),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "※ 마킹 간격(빗변) = 오프셋 높이 × 마킹 배수\n※ 기장 추가분 = 오프셋 높이 × 축소량",
            style: TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualUnifiedGuide() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: makitaTeal.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: makitaTeal.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.construction, color: makitaTeal, size: 28),
              SizedBox(width: 8),
              Text(
                "수동 벤더 실무 조작 가이드",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: makitaTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _guideText("1. 적용 규격", "[Inch] 1/4\" ~ 1\"  /  [mm] 8mm ~ 25mm"),
          _guideText(
            "2. 테이크업 (Take-Up)",
            "가상 센터라인 기준이 아닌, 튜브 두께(WT)를 적용하여 보정해야 정확한 치수가 나옵니다.",
          ),
          _guideText(
            "3. 연신율 (Gain)",
            "90도 벤딩 시 늘어나는 총 길이입니다. 마킹 시 이 값을 고려해야 합니다.",
          ),
          const Divider(height: 32, color: Colors.black12),
          const Text(
            "📊 규격별 권장 연신율 표",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1.2),
              },
              border: TableBorder.symmetric(
                inside: BorderSide(color: Colors.grey.shade200),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "규격 (OD)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "연신율 (Gain)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: makitaTeal,
                        ),
                      ),
                    ),
                  ],
                ),
                _buildGuideRow2Col(
                  "1/4\" (6.35mm)",
                  "approx. 8.5 mm",
                  makitaTeal,
                ),
                _buildGuideRow2Col(
                  "3/8\" (9.52mm)",
                  "approx. 12.5 mm",
                  makitaTeal,
                ),
                _buildGuideRow2Col(
                  "1/2\" (12.7mm)",
                  "approx. 20.0 mm",
                  makitaTeal,
                ),
                _buildGuideRow2Col(
                  "3/4\" (19.05mm)",
                  "approx. 28.5 mm",
                  makitaTeal,
                ),
                _buildGuideRow2Col(
                  "1\" (25.4mm)",
                  "approx. 38.0 mm",
                  makitaTeal,
                ),
              ],
            ),
          ),
          const Divider(height: 32, color: Colors.black12),
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                "측정 기준 안내 및 보정표",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "본 계산기는 C-to-C(가상 센터라인) 전용입니다.\n도면이 끝단(Face) 또는 바깥쪽(Back) 기준이라면, 아래의 보정 참조표(OD/2)를 보고 치수를 직접 가감하여 입력하십시오.",
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1.2),
              },
              border: TableBorder.symmetric(
                inside: BorderSide(color: Colors.grey.shade200),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "규격 (OD)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "측정 보정값 (OD/2)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                _buildGuideRow2Col(
                  "1/4\" (6.35mm)",
                  "3.17 mm",
                  Colors.redAccent,
                ),
                _buildGuideRow2Col(
                  "3/8\" (9.52mm)",
                  "4.76 mm",
                  Colors.redAccent,
                ),
                _buildGuideRow2Col(
                  "1/2\" (12.7mm)",
                  "6.35 mm",
                  Colors.redAccent,
                ),
                _buildGuideRow2Col(
                  "3/4\" (19.05mm)",
                  "9.52 mm",
                  Colors.redAccent,
                ),
                _buildGuideRow2Col("1\" (25.4mm)", "12.7 mm", Colors.redAccent),
              ],
            ),
          ),
          const Divider(height: 32, color: Colors.black12),
          const Row(
            children: [
              Icon(Icons.call_split, color: makitaTeal, size: 20),
              SizedBox(width: 8),
              Text(
                "오프셋 (Offset) 벤딩 계산표",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: makitaTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "장애물 회피 벤딩 시, 두 번째 마킹 위치(빗변)와 총 기장 축소량을 계산하기 위한 곱셈 배수입니다.",
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1.2),
                2: FlexColumnWidth(1.2),
              },
              border: TableBorder.symmetric(
                inside: BorderSide(color: Colors.grey.shade200),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "벤딩 각도",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "마킹 배수 (×)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: makitaTeal,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "축소량 (×)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                _buildOffsetRow("15°", "3.86", "0.13", makitaTeal),
                _buildOffsetRow("22.5°", "2.61", "0.20", makitaTeal),
                _buildOffsetRow("30°", "2.00", "0.27", makitaTeal),
                _buildOffsetRow("45°", "1.41", "0.41", makitaTeal),
                _buildOffsetRow("60°", "1.15", "0.58", makitaTeal),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "※ 마킹 간격(빗변) = 오프셋 높이 × 마킹 배수\n※ 기장 추가분 = 오프셋 높이 × 축소량",
            style: TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoneyJarReferenceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book_rounded,
                color: Colors.blueGrey.shade800,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                "공통 실무 꿀단지 참고표",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Colors.blueGrey.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "🍯 1. 180° U-벤딩 최소 간격 (Return Bend)",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "배관이 180도로 완전히 돌아나올 때 파이프끼리 닿지 않는 최소 C-to-C 간격입니다. (표준 벤더 기준)",
            style: TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1.2),
              },
              border: TableBorder.symmetric(
                inside: BorderSide(color: Colors.grey.shade200),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "규격 (OD)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "표준 금형(R)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "최소 간격(C-to-C)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Color(0xFF37474F),
                        ),
                      ),
                    ),
                  ],
                ),
                _buildGuideRow3Col(
                  "1/4\" (6.35)",
                  "R 14.2",
                  "28.4 mm",
                  Colors.blueGrey.shade800,
                ),
                _buildGuideRow3Col(
                  "3/8\" (9.52)",
                  "R 23.8",
                  "47.6 mm",
                  Colors.blueGrey.shade800,
                ),
                _buildGuideRow3Col(
                  "1/2\" (12.7)",
                  "R 38.1",
                  "76.2 mm",
                  Colors.blueGrey.shade800,
                ),
                _buildGuideRow3Col(
                  "3/4\" (19.05)",
                  "R 76.2",
                  "152.4 mm",
                  Colors.blueGrey.shade800,
                ),
                _buildGuideRow3Col(
                  "1\" (25.4)",
                  "R 101.6",
                  "203.2 mm",
                  Colors.blueGrey.shade800,
                ),
              ],
            ),
          ),
          const Divider(height: 32, color: Colors.black12),
          const Text(
            "🍯 2. NPT / PT 나사산 체결 깊이 (Engagement)",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "나사 조립 시 피팅이 포트 안으로 먹어 들어가는 길이입니다. 총 기장 산출 시 이 값을 빼주어야 정확합니다.",
            style: TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1.2),
              },
              border: TableBorder.symmetric(
                inside: BorderSide(color: Colors.grey.shade200),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "나사 규격",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "체결 깊이 (근사치)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Color(0xFF37474F),
                        ),
                      ),
                    ),
                  ],
                ),
                _buildGuideRow2Col(
                  "1/4\" NPT",
                  "약 10.0 mm",
                  Colors.blueGrey.shade800,
                ),
                _buildGuideRow2Col(
                  "3/8\" NPT",
                  "약 10.5 mm",
                  Colors.blueGrey.shade800,
                ),
                _buildGuideRow2Col(
                  "1/2\" NPT",
                  "약 13.5 mm",
                  Colors.blueGrey.shade800,
                ),
                _buildGuideRow2Col(
                  "3/4\" NPT",
                  "약 14.0 mm",
                  Colors.blueGrey.shade800,
                ),
                _buildGuideRow2Col(
                  "1\" NPT",
                  "약 17.5 mm",
                  Colors.blueGrey.shade800,
                ),
              ],
            ),
          ),
          const Divider(height: 32, color: Colors.black12),
          const Text(
            "🍯 3. 인치 분수 ↔ mm 환산표",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1.2),
              },
              border: TableBorder.symmetric(
                inside: BorderSide(color: Colors.grey.shade200),
              ),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "분수 (Inch)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "소수점 (Inch)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        "mm 환산",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Color(0xFF37474F),
                        ),
                      ),
                    ),
                  ],
                ),
                _buildGuideRow3Col(
                  "1/8\"",
                  "0.125",
                  "3.17 mm",
                  Colors.blueGrey.shade800,
                ),
                _buildGuideRow3Col(
                  "1/4\"",
                  "0.250",
                  "6.35 mm",
                  Colors.blueGrey.shade800,
                ),
                _buildGuideRow3Col(
                  "3/8\"",
                  "0.375",
                  "9.52 mm",
                  Colors.blueGrey.shade800,
                ),
                _buildGuideRow3Col(
                  "1/2\"",
                  "0.500",
                  "12.70 mm",
                  Colors.blueGrey.shade800,
                ),
                _buildGuideRow3Col(
                  "5/8\"",
                  "0.625",
                  "15.87 mm",
                  Colors.blueGrey.shade800,
                ),
                _buildGuideRow3Col(
                  "3/4\"",
                  "0.750",
                  "19.05 mm",
                  Colors.blueGrey.shade800,
                ),
                _buildGuideRow3Col(
                  "7/8\"",
                  "0.875",
                  "22.22 mm",
                  Colors.blueGrey.shade800,
                ),
                _buildGuideRow3Col(
                  "1\"",
                  "1.000",
                  "25.40 mm",
                  Colors.blueGrey.shade800,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MakitaNumericInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? helperText;
  final bool? isAutoMode;
  final ValueChanged<bool>? onModeChanged;
  final VoidCallback onTap;
  const MakitaNumericInput({
    super.key,
    required this.label,
    required this.controller,
    this.helperText,
    this.isAutoMode,
    this.onModeChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool readOnly = isAutoMode == true;
    Color getBgColor() {
      if (readOnly) {
        return Colors.grey.shade200;
      }
      if (isAutoMode != null && !isAutoMode!) {
        return Colors.orange.shade50;
      }
      return Colors.white;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: readOnly ? null : onTap,
                  child: AbsorbPointer(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: (isAutoMode != null && !isAutoMode!)
                                ? Colors.orange.shade300
                                : Colors.grey.shade400,
                          ),
                        ),
                        filled: true,
                        fillColor: getBgColor(),
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: readOnly ? Colors.black54 : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
              if (isAutoMode != null && onModeChanged != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => onModeChanged!(!isAutoMode!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isAutoMode! ? makitaTeal : Colors.deepOrange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isAutoMode! ? "AUTO" : "MAN",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (helperText != null) ...[
            const SizedBox(height: 6),
            Text(
              helperText!,
              style: TextStyle(
                fontSize: 11,
                color: Colors.blueGrey[700],
                fontWeight: FontWeight.w600,
                height: 1.4,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
