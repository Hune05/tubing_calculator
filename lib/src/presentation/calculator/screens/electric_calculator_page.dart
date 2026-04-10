// lib/src/presentation/calculator/screens/electric_calculator_page.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:lucide_icons/lucide_icons.dart';

import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad.dart';
// 🚀 [수정] Mobile 접두사가 붙은 최신 파일 경로로 수정
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_saddle_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_rolling_offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_pipe_visualizer.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class ElectricCalculatorPage extends StatefulWidget {
  final String startDir;
  final double clr;
  final double minClampLength;
  final List<Map<String, double>> bendList;
  final ValueChanged<List<Map<String, double>>> onListChanged;

  const ElectricCalculatorPage({
    super.key,
    required this.startDir,
    required this.clr,
    required this.minClampLength,
    required this.bendList,
    required this.onListChanged,
  });

  @override
  State<ElectricCalculatorPage> createState() => _ElectricCalculatorPageState();
}

class _ElectricCalculatorPageState extends State<ElectricCalculatorPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _tempController = TextEditingController();

  int? _editingIndex;
  double? _currentAngle;
  double? _currentRotation;
  late String _localStartDir;

  double _safeMargin = 100.0;

  double get _rawLengthSum {
    if (widget.bendList.isEmpty) return 0.0;
    return widget.bendList.fold(
      0.0,
      (sum, bend) => sum + (bend['length'] ?? 0.0),
    );
  }

  double get _estimatedTotalLength {
    if (widget.bendList.isEmpty) return 0.0;
    double totalCut = 0.0;
    double prevSetback = 0.0;

    for (var b in widget.bendList) {
      double l = b['length']!.toDouble();
      double a = b['angle']!.toDouble();

      if (a == 0) {
        totalCut += (l - prevSetback);
        prevSetback = 0.0;
      } else {
        double setback = widget.clr * math.tan((a / 2) * (math.pi / 180));
        double arcLength = 2 * math.pi * widget.clr * (a / 360);
        double straightLength = l - prevSetback - setback;
        totalCut += straightLength + arcLength;
        prevSetback = setback;
      }
    }
    return totalCut + widget.minClampLength + _safeMargin;
  }

  @override
  void initState() {
    super.initState();
    _localStartDir = widget.startDir;
  }

  @override
  void dispose() {
    _tempController.dispose();
    super.dispose();
  }

  void _showMarginNumpad() {
    String tempValue = _safeMargin > 0 ? _safeMargin.toStringAsFixed(0) : "";
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void pressKey(String key) {
              setModalState(() {
                if (key == 'C') {
                  tempValue = "";
                } else if (key == '⌫') {
                  if (tempValue.isNotEmpty) {
                    tempValue = tempValue.substring(0, tempValue.length - 1);
                  }
                } else {
                  tempValue = tempValue == "0" ? key : tempValue + key;
                }
              });
            }

            void applyMargin() {
              double? val = double.tryParse(tempValue);
              setState(() => _safeMargin = val ?? 0.0);
              Navigator.pop(context);
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.55,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: pureWhite,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "여유 마진 입력",
                            style: TextStyle(
                              color: slate900,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            "마진이 필요없다면 0을 입력하세요",
                            style: TextStyle(color: slate600, fontSize: 12),
                          ),
                        ],
                      ),
                      Text(
                        tempValue.isEmpty ? "0 mm" : "$tempValue mm",
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              _numKey('7', pressKey),
                              _numKey('8', pressKey),
                              _numKey('9', pressKey),
                              _numKey(
                                'C',
                                pressKey,
                                color: Colors.red.shade400,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              _numKey('4', pressKey),
                              _numKey('5', pressKey),
                              _numKey('6', pressKey),
                              _numKey(
                                '⌫',
                                pressKey,
                                color: Colors.orange.shade400,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              _numKey('1', pressKey),
                              _numKey('2', pressKey),
                              _numKey('3', pressKey),
                              _numKey('.', pressKey),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              _numKey('0', pressKey),
                              _numKey('00', pressKey),
                              Expanded(
                                flex: 2,
                                child: InkWell(
                                  onTap: applyMargin,
                                  child: Container(
                                    margin: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade800,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      "마진 적용",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
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
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _numKey(String text, Function(String) onTap, {Color? color}) {
    return Expanded(
      child: InkWell(
        onTap: () => onTap(text),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: slate100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: color ?? slate900,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _showCustomAnglePad() {
    String tempValue = (_currentAngle ?? 0) > 0
        ? _currentAngle!.toStringAsFixed(_currentAngle! % 1 == 0 ? 0 : 1)
        : "";
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void pressKey(String key) {
              setModalState(() {
                if (key == 'C') {
                  tempValue = "";
                } else if (key == '⌫') {
                  if (tempValue.isNotEmpty) {
                    tempValue = tempValue.substring(0, tempValue.length - 1);
                  }
                } else {
                  tempValue = tempValue == "0" ? key : tempValue + key;
                }
                double? val = double.tryParse(tempValue);
                if (val != null && val > 360) tempValue = "360";
              });
            }

            void applyAngle() {
              double? val = double.tryParse(tempValue);
              if (val != null) setState(() => _currentAngle = val);
              Navigator.pop(context);
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.55,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: pureWhite,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "자유 각도 입력 (0~360°)",
                        style: TextStyle(
                          color: slate600,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        tempValue.isEmpty ? "0°" : "$tempValue°",
                        style: const TextStyle(
                          color: slate900,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              _numKey('7', pressKey),
                              _numKey('8', pressKey),
                              _numKey('9', pressKey),
                              _numKey(
                                'C',
                                pressKey,
                                color: Colors.red.shade400,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              _numKey('4', pressKey),
                              _numKey('5', pressKey),
                              _numKey('6', pressKey),
                              _numKey(
                                '⌫',
                                pressKey,
                                color: Colors.orange.shade400,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              _numKey('1', pressKey),
                              _numKey('2', pressKey),
                              _numKey('3', pressKey),
                              _numKey('.', pressKey),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              _numKey('0', pressKey),
                              _numKey('00', pressKey),
                              Expanded(
                                flex: 2,
                                child: InkWell(
                                  onTap: applyAngle,
                                  child: Container(
                                    margin: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade800,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      "적용",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
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
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleApply() {
    final double? val = double.tryParse(_tempController.text);
    if (val != null && val > 0) {
      if (_currentAngle == null) {
        _showError("⚠️ 벤딩 각도를 먼저 선택해주세요.");
        return;
      }
      if (_currentRotation == null) {
        _showError("⚠️ 배관 진행 방향(6축)을 먼저 선택해주세요.");
        return;
      }

      List<Map<String, double>> newList = List.from(widget.bendList);

      setState(() {
        if (_editingIndex != null) {
          newList[_editingIndex!] = {
            'length': val,
            'angle': _currentAngle!,
            'rotation': _currentRotation!,
          };
          _editingIndex = null;
        } else {
          newList.add({
            'length': val,
            'angle': _currentAngle!,
            'rotation': _currentRotation!,
          });
        }
        widget.onListChanged(newList);
        _tempController.clear();
        _currentAngle = null;
        _currentRotation = null;
      });
      FocusScope.of(context).unfocus();
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: slate600,
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  void _startEdit(int index) {
    setState(() {
      _editingIndex = index;
      _tempController.text = widget.bendList[index]['length'].toString();
      _currentAngle = widget.bendList[index]['angle']!.toDouble();
      _currentRotation = widget.bendList[index]['rotation']!.toDouble();
    });
  }

  String _getDirectionText(double? rot) {
    if (rot == null) return "--";
    if (rot == 0.0) return "UP";
    if (rot == 90.0) return "RIGHT";
    if (rot == 180.0) return "DOWN";
    if (rot == 270.0) return "LEFT";
    if (rot == 360.0) return "FRONT";
    if (rot == 450.0) return "BACK";
    return "${rot.toInt()}°";
  }

  void _executeMacro(double val, double angle, double rot) {
    List<Map<String, double>> newList = List.from(widget.bendList);
    setState(() {
      if (_editingIndex != null) {
        newList[_editingIndex!] = {
          'length': val,
          'angle': angle,
          'rotation': rot,
        };
        _editingIndex = null;
      } else {
        newList.add({'length': val, 'angle': angle, 'rotation': rot});
      }
      widget.onListChanged(newList);
      _tempController.clear();
    });
  }

  // 🚀 화면이 튀지 않도록 오프셋 등 여러 개의 벤딩을 한 번에 삽입하는 함수
  void _executeMultipleMacros(List<Map<String, double>> bends) {
    List<Map<String, double>> newList = List.from(widget.bendList);
    setState(() {
      if (_editingIndex != null) {
        newList.removeAt(_editingIndex!); // 기존 데이터 지우고
        newList.insertAll(_editingIndex!, bends); // 그 자리에 묶음으로 추가
        _editingIndex = null;
      } else {
        newList.addAll(bends); // 끝에 묶음으로 추가
      }
      widget.onListChanged(newList); // 한 번만 상태 갱신 발송!
      _tempController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: slate100,
      appBar: AppBar(
        title: const Text(
          "ELECTRIC BENDING CALCULATOR",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1.0,
          ),
        ),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Row(
        children: [
          // 🔹 [왼쪽] 3D 뷰어
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: pureWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
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
                      child: Icon(Icons.grid_4x4, size: 500, color: slate100),
                    ),
                  ),
                  // 🚀 [수정] MobilePipeVisualizer로 이름 교체됨
                  MobilePipeVisualizer(
                    bendList: widget.bendList,
                    initialStartDir: _localStartDir,
                    onStartDirChanged: (newDir) =>
                        setState(() => _localStartDir = newDir),
                  ),
                  Positioned(
                    top: 20,
                    left: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ISO 3D VIEW",
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          "TOTAL BENDS: ${widget.bendList.where((b) => b['angle']! > 0).length}",
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 12,
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

          // 🔹 [오른쪽] 조작반 패널
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 12, right: 12),
              child: Column(
                children: [
                  // 예상 튜브 길이 표시 패널
                  GestureDetector(
                    onTap: _showMarginNumpad,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: _estimatedTotalLength == 0
                            ? slate900
                            : Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _estimatedTotalLength == 0
                              ? slate900
                              : Colors.orange.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "예상 튜브 길이",
                                style: TextStyle(
                                  color: _estimatedTotalLength == 0
                                      ? pureWhite
                                      : slate900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (_estimatedTotalLength > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    "순수합: ${_rawLengthSum.toStringAsFixed(1)} + 마진: ${_safeMargin.toStringAsFixed(0)}",
                                    style: TextStyle(
                                      color: slate600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            _estimatedTotalLength == 0
                                ? "계산 대기중..."
                                : "${_estimatedTotalLength.toStringAsFixed(1)} mm",
                            style: TextStyle(
                              color: _estimatedTotalLength == 0
                                  ? Colors.white54
                                  : Colors.orange.shade800,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // INPUT LIST 및 매크로
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: pureWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
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
                              Text(
                                "INPUT LIST",
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildToolChip("오프셋", null, () {
                                      // 🚀 [수정] Mobile 접두사 클래스명 적용
                                      MobileOffsetBottomSheet.show(
                                        context,
                                        currentRotation:
                                            _currentRotation ?? 0.0,
                                        onAddMultipleBends: (bends) =>
                                            _executeMultipleMacros(bends),
                                      );
                                    }),
                                    const SizedBox(width: 6),
                                    _buildToolChip("새들", null, () {
                                      // 🚀 [수정] Mobile 접두사 클래스명 적용
                                      MobileSaddleBottomSheet.show(
                                        context,
                                        currentRotation:
                                            _currentRotation ?? 0.0,
                                        onAddBend: (val, angle, rot) =>
                                            _executeMacro(val, angle, rot),
                                      );
                                    }),
                                    const SizedBox(width: 6),
                                    _buildToolChip("롤링", LucideIcons.orbit, () {
                                      // 🚀 [수정] Mobile 접두사 클래스명 적용
                                      MobileRollingOffsetBottomSheet.show(
                                        context,
                                        currentRotation:
                                            _currentRotation ?? 0.0,
                                        onAddBend: (val, angle, rot) =>
                                            _executeMacro(val, angle, rot),
                                      );
                                    }),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_sweep,
                                        color: Colors.grey,
                                        size: 24,
                                      ),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      onPressed: () {
                                        setState(() {
                                          _editingIndex = null;
                                          _tempController.clear();
                                          _currentRotation = null;
                                          _currentAngle = null;
                                          widget.onListChanged([]);
                                        });
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
                                      "치수와 방향을 셋팅하세요\n입력 후 스와이프하여 마킹 확인",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: slate600,
                                        height: 1.5,
                                      ),
                                    ),
                                  )
                                : ReorderableListView.builder(
                                    itemCount: widget.bendList.length,
                                    onReorder: (oldIndex, newIndex) {
                                      setState(() {
                                        if (oldIndex < newIndex) newIndex -= 1;
                                        List<Map<String, double>> newList =
                                            List.from(widget.bendList);
                                        final item = newList.removeAt(oldIndex);
                                        newList.insert(newIndex, item);
                                        _editingIndex = null;
                                        _tempController.clear();
                                        widget.onListChanged(newList);
                                      });
                                    },
                                    itemBuilder: (context, index) {
                                      bool isEditing = _editingIndex == index;
                                      final bend = widget.bendList[index];
                                      return GestureDetector(
                                        key: ValueKey(
                                          'bend_${index}_${bend.hashCode}',
                                        ),
                                        onTap: () => _startEdit(index),
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isEditing
                                                ? Colors.orange.withValues(
                                                    alpha: 0.08,
                                                  )
                                                : slate100,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: isEditing
                                                  ? Colors.orange.shade800
                                                  : Colors.transparent,
                                              width: isEditing ? 2 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.drag_indicator,
                                                    color: Colors.grey,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    "#${index + 1}",
                                                    style: TextStyle(
                                                      color: isEditing
                                                          ? Colors
                                                                .orange
                                                                .shade800
                                                          : slate600,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                "L: ${bend['length']} | A: ${bend['angle']}° | DIR: ${_getDirectionText(bend['rotation'])}",
                                                style: TextStyle(
                                                  color: isEditing
                                                      ? Colors.orange.shade800
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

                  // 탭 컨트롤러
                  Expanded(
                    flex: 6,
                    child: Container(
                      decoration: BoxDecoration(
                        color: pureWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            TabBar(
                              indicatorColor: Colors.orange.shade800,
                              labelColor: Colors.orange.shade800,
                              unselectedLabelColor: slate600,
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

  Widget _buildToolChip(String label, IconData? icon, VoidCallback onPressed) {
    return ActionChip(
      backgroundColor: pureWhite,
      side: BorderSide(color: Colors.grey.shade300, width: 1.5),
      labelStyle: const TextStyle(
        color: slate900,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      avatar: icon != null
          ? Icon(icon, color: Colors.orange.shade800, size: 16)
          : null,
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
                  Text(
                    "벤딩 각도",
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Row(
                      children: [
                        _AnglePushBtn(
                          label: "0°(직관)",
                          onTap: () => setState(() => _currentAngle = 0.0),
                        ),
                        const SizedBox(width: 8),
                        _AnglePushBtn(
                          label: "15°",
                          onTap: () => setState(() => _currentAngle = 15.0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Row(
                      children: [
                        _AnglePushBtn(
                          label: "22.5°",
                          onTap: () => setState(() => _currentAngle = 22.5),
                        ),
                        const SizedBox(width: 8),
                        _AnglePushBtn(
                          label: "30°",
                          onTap: () => setState(() => _currentAngle = 30.0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Row(
                      children: [
                        _AnglePushBtn(
                          label: "45°",
                          onTap: () => setState(() => _currentAngle = 45.0),
                        ),
                        const SizedBox(width: 8),
                        _AnglePushBtn(
                          label: "60°",
                          onTap: () => setState(() => _currentAngle = 60.0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Row(
                      children: [
                        _AnglePushBtn(
                          label: "90°",
                          onTap: () => setState(() => _currentAngle = 90.0),
                        ),
                        const SizedBox(width: 8),
                        _AnglePushBtn(
                          label: "180°",
                          onTap: () => setState(() => _currentAngle = 180.0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: slate100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        "현재 각도",
                                        style: TextStyle(
                                          color: slate600,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _currentAngle == null
                                            ? "--"
                                            : "${_currentAngle!.toStringAsFixed(_currentAngle! % 1 == 0 ? 0 : 1)}°",
                                        style: TextStyle(
                                          color: _currentAngle == null
                                              ? slate600
                                              : Colors.orange.shade800,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 24,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _AnglePushBtn(
                          label: "직접 입력",
                          icon: Icons.edit,
                          onTap: _showCustomAnglePad,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
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
                  child: Row(
                    children: [
                      _DirectionPushBtn(
                        icon: LucideIcons.arrowUpRight,
                        label: "FRONT",
                        onTap: () => setState(() => _currentRotation = 360.0),
                      ),
                      const SizedBox(width: 8),
                      _DirectionPushBtn(
                        icon: LucideIcons.arrowUp,
                        label: "UP",
                        onTap: () => setState(() => _currentRotation = 0.0),
                      ),
                      const SizedBox(width: 8),
                      _DirectionPushBtn(
                        icon: LucideIcons.arrowDownLeft,
                        label: "BACK",
                        onTap: () => setState(() => _currentRotation = 450.0),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    children: [
                      _DirectionPushBtn(
                        icon: LucideIcons.arrowLeft,
                        label: "LEFT",
                        onTap: () => setState(() => _currentRotation = 270.0),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: slate100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
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
                                      style: TextStyle(
                                        color: _currentRotation == null
                                            ? slate600
                                            : Colors.orange.shade800,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 26,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _DirectionPushBtn(
                        icon: LucideIcons.arrowRight,
                        label: "RIGHT",
                        onTap: () => setState(() => _currentRotation = 90.0),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    children: [
                      _GlowingActionBtn(
                        icon: Icons.delete_outline,
                        label: "라인 삭제",
                        color: Colors.red.shade600,
                        onTap: () {
                          if (_editingIndex != null) {
                            setState(() {
                              List<Map<String, double>> newList = List.from(
                                widget.bendList,
                              );
                              newList.removeAt(_editingIndex!);
                              _editingIndex = null;
                              _tempController.clear();
                              widget.onListChanged(newList);
                            });
                          } else {
                            _showError("삭제할 라인을 위 리스트에서 먼저 선택해주세요.");
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _DirectionPushBtn(
                        icon: LucideIcons.arrowDown,
                        label: "DOWN",
                        onTap: () => setState(() => _currentRotation = 180.0),
                      ),
                      const SizedBox(width: 8),
                      _GlowingActionBtn(
                        icon: Icons.check,
                        label: "적용",
                        color: Colors.orange.shade800,
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
    );
  }
}

class _AnglePushBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  const _AnglePushBtn({required this.label, required this.onTap, this.icon});
  @override
  State<_AnglePushBtn> createState() => _AnglePushBtnState();
}

class _AnglePushBtnState extends State<_AnglePushBtn> {
  bool _isPressed = false;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          decoration: BoxDecoration(
            color: _isPressed ? Colors.orange.shade800 : pureWhite,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isPressed ? Colors.orange.shade800 : Colors.grey.shade300,
              width: _isPressed ? 2 : 1,
            ),
            boxShadow: _isPressed
                ? [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: 14,
                    color: _isPressed ? pureWhite : slate600,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isPressed ? pureWhite : slate900,
                    fontSize: widget.label == "0°(직관)" || widget.icon != null
                        ? 13
                        : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectionPushBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DirectionPushBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  State<_DirectionPushBtn> createState() => _DirectionPushBtnState();
}

class _DirectionPushBtnState extends State<_DirectionPushBtn> {
  bool _isPressed = false;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          decoration: BoxDecoration(
            color: _isPressed ? Colors.orange.shade800 : pureWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isPressed ? Colors.orange.shade800 : Colors.grey.shade300,
              width: _isPressed ? 2 : 1,
            ),
            boxShadow: _isPressed
                ? [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4.0,
                  vertical: 2.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.icon,
                      color: _isPressed ? pureWhite : slate600,
                      size: 26,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: _isPressed ? pureWhite : slate600,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          decoration: BoxDecoration(
            color: _isPressed ? widget.color.withValues(alpha: 0.1) : pureWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.color,
              width: _isPressed ? 3.0 : 1.5,
            ),
            boxShadow: _isPressed
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4.0,
                  vertical: 2.0,
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
          ),
        ),
      ),
    );
  }
}
