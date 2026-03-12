import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/saddle_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/rolling_offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/pipe_visualizer.dart';
import 'package:lucide_icons/lucide_icons.dart';

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
  final Function(int index) onDeleteBend; // 🚀 삭제 콜백 추가
  final Function(int oldIndex, int newIndex) onReorderBend;
  final VoidCallback onClear;

  const CalculatorPage({
    super.key,
    this.pageController,
    required this.bendList,
    required this.onAddBend,
    required this.onUpdateBend,
    required this.onDeleteBend, // 🚀
    required this.onReorderBend,
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

  double _currentAngle = 0.0;
  double _currentRotation = 0.0;

  bool _isAutoProcessing = false;

  StreamSubscription<QuerySnapshot>? _remoteSubscription;
  late int _listenerStartTime;

  @override
  void initState() {
    super.initState();
    _listenerStartTime = DateTime.now().millisecondsSinceEpoch;
    _startRemoteListener();
    WakelockPlus.enable();
  }

  void _startRemoteListener() {
    _remoteSubscription = FirebaseFirestore.instance
        .collection('remote_commands')
        .where('timestamp', isGreaterThan: _listenerStartTime)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data != null) {
                receiveRemoteData(data);
              }
            }
          }
        });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _remoteSubscription?.cancel();
    _tempController.dispose();
    super.dispose();
  }

  void receiveRemoteData(Map<String, dynamic> data) async {
    if (!mounted || _isAutoProcessing) return;

    setState(() => _isAutoProcessing = true);

    String mode = data['mode'] ?? "";
    double val1 = double.tryParse(data['val1'].toString()) ?? 0;
    double val2 = double.tryParse(data['val2'].toString()) ?? 0;
    double angle = double.tryParse(data['angle'].toString()) ?? 0;
    String dirStr = data['dir'] ?? "UP";

    double targetRot = _parseDirectionToRotation(dirStr);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("📲 리모컨 수신: [$mode] 연산 및 자동 입력 중..."),
        backgroundColor: makitaTeal,
        duration: const Duration(milliseconds: 1500),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 400));

    if (mode == "직관 (Straight)") {
      _executeMacro(val1, 0.0, targetRot);
    } else if (mode == "90° 벤딩") {
      _executeMacro(val1, 90.0, targetRot);
    } else if (mode == "오프셋") {
      double d = 0;
      double finalAngle = angle;
      if (angle > 0) {
        d = val1 / math.sin(angle * (math.pi / 180));
      } else if (val2 > 0) {
        d = val2;
        finalAngle = math.asin(val1 / val2) * (180 / math.pi);
      }
      _executeMacro(d, finalAngle, targetRot);
    } else if (mode == "새들") {
      double d = (angle > 0)
          ? (val1 / math.sin(angle * (math.pi / 180)))
          : val1;
      _executeMacro(d, angle, targetRot);
    } else if (mode == "롤링 오프셋") {
      double trueH = math.sqrt((val1 * val1) + (val2 * val2));
      double d = (angle > 0)
          ? (trueH / math.sin(angle * (math.pi / 180)))
          : trueH;
      _executeMacro(d, angle, targetRot);
    } else {
      setState(() => _isAutoProcessing = false);
    }
  }

  double _parseDirectionToRotation(String dir) {
    switch (dir) {
      case "UP":
        return 0.0;
      case "RIGHT":
        return 90.0;
      case "DOWN":
        return 180.0;
      case "LEFT":
        return 270.0;
      case "FRONT":
        return 360.0;
      case "BACK":
        return 450.0;
      default:
        return 0.0;
    }
  }

  void _executeMacro(double length, double angle, double rot) async {
    setState(() {
      _tempController.text = length.toStringAsFixed(1);
      _currentAngle = angle;
      _currentRotation = rot;
    });

    await Future.delayed(const Duration(milliseconds: 600));
    _handleApply();

    setState(() => _isAutoProcessing = false);
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
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: slate100,
      body: AbsorbPointer(
        absorbing: _isAutoProcessing,
        child: Row(
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

            // 🔹 [오른쪽] 조작반
            Expanded(
              flex: 5,
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 12, right: 12),
                child: Column(
                  children: [
                    Expanded(
                      flex: 4,
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
                                          currentRotation: _currentRotation,
                                          onAddBend: (val, angle, rot) {
                                            if (_editingIndex != null) {
                                              widget.onUpdateBend(
                                                _editingIndex!,
                                                val,
                                                angle,
                                                rot,
                                              );
                                              setState(() {
                                                _editingIndex = null;
                                                _tempController.clear();
                                              });
                                            } else {
                                              widget.onAddBend(val, angle, rot);
                                            }
                                          },
                                        );
                                      }),
                                      const SizedBox(width: 6),
                                      _buildToolChip("새들", null, () {
                                        SaddleBottomSheet.show(
                                          context,
                                          currentRotation: _currentRotation,
                                          onAddBend: (val, angle, rot) {
                                            if (_editingIndex != null) {
                                              widget.onUpdateBend(
                                                _editingIndex!,
                                                val,
                                                angle,
                                                rot,
                                              );
                                              setState(() {
                                                _editingIndex = null;
                                                _tempController.clear();
                                              });
                                            } else {
                                              widget.onAddBend(val, angle, rot);
                                            }
                                          },
                                        );
                                      }),
                                      const SizedBox(width: 6),
                                      _buildToolChip(
                                        "롤링",
                                        LucideIcons.orbit,
                                        () {
                                          RollingOffsetBottomSheet.show(
                                            context,
                                            currentRotation: _currentRotation,
                                            onAddBend: (val, angle, rot) {
                                              if (_editingIndex != null) {
                                                widget.onUpdateBend(
                                                  _editingIndex!,
                                                  val,
                                                  angle,
                                                  rot,
                                                );
                                                setState(() {
                                                  _editingIndex = null;
                                                  _tempController.clear();
                                                });
                                              } else {
                                                widget.onAddBend(
                                                  val,
                                                  angle,
                                                  rot,
                                                );
                                              }
                                            },
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_sweep,
                                          color: slate600,
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
                            Divider(
                              color: Colors.grey.shade200,
                              thickness: 1.5,
                            ),
                            Expanded(
                              child: widget.bendList.isEmpty
                                  ? const Center(
                                      child: Text(
                                        "치수와 방향을 셋팅하세요\n또는 리모컨으로 데이터를 전송하세요",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: slate600),
                                      ),
                                    )
                                  : ReorderableListView.builder(
                                      itemCount: widget.bendList.length,
                                      onReorder: (int oldIndex, int newIndex) {
                                        setState(() {
                                          if (oldIndex < newIndex)
                                            newIndex -= 1;
                                          _editingIndex = null;
                                          _tempController.clear();
                                        });
                                        widget.onReorderBend(
                                          oldIndex,
                                          newIndex,
                                        );
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
                                                  ? makitaTeal.withValues(
                                                      alpha: 0.08,
                                                    )
                                                  : slate100,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isEditing
                                                    ? makitaTeal
                                                    : Colors.transparent,
                                                width: isEditing ? 2 : 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
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
                                                            ? makitaTeal
                                                            : slate600,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
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
                              const TabBar(
                                indicatorColor: makitaTeal,
                                labelColor: makitaTeal,
                                unselectedLabelColor: slate600,
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                tabs: [
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
                                  color: slate100,
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
                            // 🚀 [핵심] "취소" 버튼을 "라인 삭제" 버튼으로 완벽하게 교체!
                            _GlowingActionBtn(
                              icon: Icons.delete_outline,
                              label: "라인 삭제",
                              color: Colors.red.shade600,
                              onTap: () {
                                if (_editingIndex == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "삭제할 라인을 위 리스트에서 먼저 선택해주세요.",
                                      ),
                                      backgroundColor: slate600,
                                      duration: Duration(milliseconds: 1500),
                                    ),
                                  );
                                  return;
                                }

                                // 🚀 삭제 전 경고 팝업 띄우기
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    title: Row(
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.red.shade600,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          "라인 삭제",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    content: Text(
                                      "선택하신 #${_editingIndex! + 1} 구간을 목록에서 완전히 삭제하시겠습니까?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text(
                                          "취소",
                                          style: TextStyle(
                                            color: slate600,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red.shade600,
                                        ),
                                        onPressed: () {
                                          widget.onDeleteBend(
                                            _editingIndex!,
                                          ); // 부모에게 삭제 요청!
                                          setState(() {
                                            _editingIndex = null;
                                            _tempController.clear();
                                          });
                                          Navigator.pop(ctx);
                                        },
                                        child: const Text(
                                          "삭제",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
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
                      color: makitaTeal.withValues(alpha: 0.3),
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
                      color: makitaTeal.withValues(alpha: 0.3),
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

  void _handleTapDown(TapDownDetails details) =>
      setState(() => _isPressed = true);
  void _handleTapUp(TapUpDetails details) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) setState(() => _isPressed = false);
    widget.onTap();
  }

  void _handleTapCancel() => setState(() => _isPressed = false);

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
