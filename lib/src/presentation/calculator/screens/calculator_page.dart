import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/saddle_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/rolling_offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/pipe_visualizer.dart';
import 'package:lucide_icons/lucide_icons.dart';

// 💡 [테마 컬러 변경] 다른 페이지와 동일한 라이트/슬레이트 테마 적용
const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class CalculatorPage extends StatefulWidget {
  final PageController? pageController;
  final List<Map<String, double>> bendList;
  final Function(double, double, double) onAddBend;
  final Function(int, double, double, double) onUpdateBend;
  final VoidCallback onClear;

  const CalculatorPage({
    super.key,
    this.pageController,
    required this.bendList,
    required this.onAddBend,
    required this.onUpdateBend,
    required this.onClear,
  });

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _tempController = TextEditingController();
  int? _editingIndex;

  // 🔥 기본 각도 0.0(직관)
  double _currentAngle = 0.0;
  double _currentRotation = 0.0;

  String _getDirectionText(double rot) {
    if (rot == 0.0) return "UP";
    if (rot == 90.0) return "RIGHT";
    if (rot == 180.0) return "DOWN";
    if (rot == 270.0) return "LEFT";
    if (rot == 360.0) return "FRONT";
    if (rot == 450.0) return "BACK";
    return "${rot.toInt()}°";
  }

  void _handleApply() {
    final double? val = double.tryParse(_tempController.text);
    if (val != null && val > 0) {
      if (_editingIndex != null) {
        widget.onUpdateBend(
          _editingIndex!,
          val,
          _currentAngle,
          _currentRotation,
        );
        _editingIndex = null;
      } else {
        widget.onAddBend(val, _currentAngle, _currentRotation);
      }
      _tempController.clear();
      setState(() {
        _currentAngle = 0.0;
        _currentRotation = 0.0;
      });
      FocusScope.of(context).unfocus();
    }
  }

  void _startEdit(int index) {
    setState(() {
      _editingIndex = index;
      _tempController.text = widget.bendList[index]['length'].toString();
      _currentAngle = widget.bendList[index]['angle']!;
      _currentRotation = widget.bendList[index]['rotation']!;
    });
  }

  @override
  void dispose() {
    _tempController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: slate100, // 전체 배경 화이트 톤으로 변경
      body: Row(
        children: [
          // 🔹 [왼쪽] 실시간 배관 형상 시각화
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: pureWhite, // 화이트 배경
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 2,
                ), // 밝은 테두리
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05), // 부드러운 그림자
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Opacity(
                    opacity: 0.3,
                    child: Center(
                      child: Icon(
                        Icons.grid_4x4,
                        size: 500,
                        color: slate100,
                      ), // 그리드 아이콘 밝게
                    ),
                  ),
                  PipeVisualizer(bendList: widget.bendList),
                  Positioned(
                    top: 20,
                    left: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "ISO 3D VIEW",
                          style: TextStyle(
                            color: makitaTeal,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          "TOTAL BENDS: ${widget.bendList.length}",
                          style: TextStyle(
                            color: Colors.orange.shade700, // 호박색보다 시인성 좋은 오렌지
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          color: Colors.red.shade600,
                          size: 12,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "START POINT",
                          style: TextStyle(
                            color: slate600, // 라이트 테마에 맞는 슬레이트 컬러
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🔹 [오른쪽] 조작반
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 12, right: 12),
              child: Column(
                children: [
                  // 1. 인풋 리스트 및 특수 공구 버튼 영역
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: pureWhite, // 화이트 패널
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  "INPUT LIST",
                                  style: TextStyle(
                                    color: makitaTeal,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildToolChip("오프셋", null, () {
                                      OffsetBottomSheet.show(
                                        context,
                                        onAddBend: widget.onAddBend,
                                      );
                                    }),
                                    const SizedBox(width: 6),
                                    _buildToolChip("새들", null, () {
                                      SaddleBottomSheet.show(
                                        context,
                                        onAddBend: widget.onAddBend,
                                      );
                                    }),
                                    const SizedBox(width: 6),
                                    _buildToolChip("롤링", LucideIcons.orbit, () {
                                      RollingOffsetBottomSheet.show(
                                        context,
                                        onAddBend: widget.onAddBend,
                                      );
                                    }),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_sweep,
                                        color: slate600, // 라이트 테마 휴지통
                                        size: 24,
                                      ),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      onPressed: () {
                                        setState(() {
                                          _editingIndex = null;
                                          _tempController.clear();
                                        });
                                        widget.onClear();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Divider(color: Colors.grey.shade200, thickness: 1.5),
                          Expanded(
                            child: widget.bendList.isEmpty
                                ? const Center(
                                    child: Text(
                                      "치수와 방향을 셋팅하세요",
                                      style: TextStyle(color: slate600),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: widget.bendList.length,
                                    itemBuilder: (context, index) {
                                      bool isEditing = _editingIndex == index;
                                      final bend = widget.bendList[index];
                                      return GestureDetector(
                                        onTap: () => _startEdit(index),
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isEditing
                                                ? makitaTeal.withOpacity(0.08)
                                                : slate100, // 슬레이트 100 배경
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: isEditing
                                                  ? makitaTeal
                                                  : Colors.transparent,
                                              width: isEditing ? 2 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "#${index + 1}",
                                                style: TextStyle(
                                                  color: isEditing
                                                      ? makitaTeal
                                                      : slate600,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                "L: ${bend['length']} | A: ${bend['angle']}° | DIR: ${_getDirectionText(bend['rotation']!)}",
                                                style: TextStyle(
                                                  color: isEditing
                                                      ? makitaTeal
                                                      : slate900,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
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
                  const SizedBox(height: 12),

                  // 2. 입력 패널
                  Expanded(
                    flex: 6,
                    child: Container(
                      decoration: BoxDecoration(
                        color: pureWhite, // 화이트 패널
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            TabBar(
                              indicatorColor: makitaTeal,
                              labelColor: makitaTeal, // 선택된 탭 텍스트 색상
                              unselectedLabelColor: slate600, // 비선택 탭 텍스트 색상
                              labelStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              tabs: const [
                                Tab(text: "치수 입력 (L)"),
                                Tab(text: "공간 방향 (6축)"),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                physics: const NeverScrollableScrollPhysics(),
                                children: [
                                  Transform.scale(
                                    scale: 0.9,
                                    child: MakitaNumpad(
                                      controller: _tempController,
                                      onApply: _handleApply,
                                      title: _editingIndex != null
                                          ? "#${_editingIndex! + 1} 적용"
                                          : "적용 (L, A, DIR 세트)",
                                    ),
                                  ),
                                  _buildAngleRotationPanel(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 💡 라이트 테마용 툴 칩 빌더
  Widget _buildToolChip(String label, IconData? icon, VoidCallback onPressed) {
    return ActionChip(
      backgroundColor: pureWhite,
      side: BorderSide(color: Colors.grey.shade300, width: 1.5),
      labelStyle: const TextStyle(
        color: slate900,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      avatar: icon != null ? Icon(icon, color: makitaTeal, size: 16) : null,
      label: Text(label),
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }

  Widget _buildAngleRotationPanel() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 🔹 [왼쪽] 각도 패널
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.grey.shade200, width: 1.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "벤딩 각도",
                    style: TextStyle(
                      color: makitaTeal,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              _buildAngleBtn(0.0),
                              const SizedBox(width: 8),
                              _buildAngleBtn(15.0),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Row(
                            children: [
                              _buildAngleBtn(22.5),
                              const SizedBox(width: 8),
                              _buildAngleBtn(30.0),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Row(
                            children: [
                              _buildAngleBtn(45.0),
                              const SizedBox(width: 8),
                              _buildAngleBtn(60.0),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Row(
                            children: [
                              _buildAngleBtn(90.0),
                              const SizedBox(width: 8),
                              _buildAngleBtn(135.0),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Row(
                            children: [
                              _buildAngleBtn(180.0),
                              const SizedBox(width: 8),
                              const Expanded(child: SizedBox()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 🔹 [오른쪽] 6축 방향 패널
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "배관 진행 방향 (아이소 도면 기준)",
                  style: TextStyle(
                    color: slate600,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            _buildDirBtn(
                              LucideIcons.arrowUpRight,
                              "FRONT",
                              360.0,
                            ),
                            const SizedBox(width: 8),
                            _buildDirBtn(LucideIcons.arrowUp, "UP", 0.0),
                            const SizedBox(width: 8),
                            _buildDirBtn(
                              LucideIcons.arrowDownLeft,
                              "BACK",
                              450.0,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Row(
                          children: [
                            _buildDirBtn(LucideIcons.arrowLeft, "LEFT", 270.0),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: slate100, // 중앙 상태 표시창 라이트 테마
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      "현재 방향",
                                      style: TextStyle(
                                        color: slate600,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _getDirectionText(_currentRotation),
                                      style: const TextStyle(
                                        color: makitaTeal,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 26,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildDirBtn(LucideIcons.arrowRight, "RIGHT", 90.0),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Row(
                          children: [
                            _GlowingActionBtn(
                              icon: Icons.close,
                              label: "취소",
                              color: Colors.red.shade500,
                              onTap: () {
                                setState(() {
                                  _editingIndex = null;
                                  _tempController.clear();
                                });
                                FocusScope.of(context).unfocus();
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildDirBtn(LucideIcons.arrowDown, "DOWN", 180.0),
                            const SizedBox(width: 8),
                            _GlowingActionBtn(
                              icon: Icons.check,
                              label: "적용",
                              color: makitaTeal,
                              onTap: _handleApply,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAngleBtn(double value) {
    bool isSelected = value == _currentAngle;
    String buttonText = value == 0.0
        ? "0°(직관)"
        : "${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}°";

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentAngle = value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? makitaTeal : pureWhite,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? makitaTeal : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: makitaTeal.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              buttonText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? pureWhite : slate900,
                fontSize: value == 0.0 ? 14 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDirBtn(IconData icon, String label, double value) {
    bool isSelected = _currentRotation == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentRotation = value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? makitaTeal : pureWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? makitaTeal : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: makitaTeal.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? pureWhite : slate600, size: 26),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? pureWhite : slate600,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 🔥 라이트 테마에 맞춘 쫀득한 버튼 (BoxShadow 네온 효과 최적화)
class _GlowingActionBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _GlowingActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_GlowingActionBtn> createState() => _GlowingActionBtnState();
}

class _GlowingActionBtnState extends State<_GlowingActionBtn> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) setState(() => _isPressed = false);
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          decoration: BoxDecoration(
            color: _isPressed ? widget.color.withOpacity(0.1) : pureWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.color,
              width: _isPressed ? 3.0 : 1.5,
            ),
            boxShadow: _isPressed
                ? [
                    BoxShadow(
                      color: widget.color.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: widget.color, size: 26),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.color,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
