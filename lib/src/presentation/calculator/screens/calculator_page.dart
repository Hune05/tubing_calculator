// lib/src/presentation/calculator/screens/calculator_page.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubing_calculator/src/data/bend_data_manager.dart';

import 'package:tubing_calculator/src/core/utils/app_settings_controller.dart';

// 🚀 [수정] Mobile 접두사가 붙은 최신 파일 경로 및 클래스명으로 모두 교체
import 'package:tubing_calculator/src/presentation/calculator/widgets/makita_numpad.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_saddle_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_rolling_offset_bottom_sheet.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_pipe_visualizer.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_parallel_shrink_bottom_sheet.dart';
import 'package:lucide_icons/lucide_icons.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class CalculatorPage extends StatefulWidget {
  final PageController? pageController;
  final List<Map<String, double>> bendList;

  final String startDir;
  final ValueChanged<String> onStartDirChanged;

  final Function(double, double, double) onAddBend;
  // 🚀 [추가됨] 화면 튀는 걸 막기 위한 다중 삽입 콜백
  final Function(List<Map<String, double>>) onAddMultipleBends;

  final Function(int, double, double, double) onUpdateBend;
  final Function(int index) onDeleteBend;
  final Function(int oldIndex, int newIndex) onReorderBend;
  final VoidCallback onClear;

  const CalculatorPage({
    super.key,
    this.pageController,
    required this.bendList,
    required this.startDir,
    required this.onStartDirChanged,
    required this.onAddBend,
    required this.onAddMultipleBends, // 🚀 연결
    required this.onUpdateBend,
    required this.onDeleteBend,
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

  double? _currentAngle;
  double? _currentRotation;

  bool _isAutoProcessing = false;

  StreamSubscription<QuerySnapshot>? _remoteSubscription;
  late int _listenerStartTime;

  // 🚀 [수정] 같은 스냅샷에 여러 명령이 한꺼번에 들어와도 유실되지 않도록 큐로 처리
  final List<Map<String, dynamic>> _remoteQueue = [];

  String _localStartDir = 'RIGHT';

  double _safeMargin = 100.0;

  // 🚀 [수정] 최소 직선 구간은 더 이상 이 화면이 직접 SettingsManager를 불러서
  // 캐시하지 않는다 - AppSettingsController().minStraight를 그때그때 읽는다.
  double get _minStraightFromSettings => AppSettingsController().minStraight;

  double get _rawLengthSum {
    if (widget.bendList.isEmpty) return 0.0;
    return widget.bendList.fold(
      0.0,
      (acc, bend) => acc + (bend['length'] ?? 0.0),
    );
  }

  double get _estimatedTotalLength {
    if (_rawLengthSum == 0) return 0.0;
    return _rawLengthSum + _safeMargin;
  }

  @override
  void initState() {
    super.initState();
    _localStartDir = widget.startDir;
    _loadSavedStartDir();

    // 🚀 [수정] 이 화면은 더 이상 wakelock을 직접 켜지 않는다.
    // "화면 꺼짐 방지"는 사용자의 영속 설정(AppSettingsController.keepScreenOn)에
    // 따라서만 켜지고 꺼진다 - 이전에는 이 화면에 들어오기만 하면 설정과
    // 무관하게 무조건 켜져서, 설정에서 꺼도 계산기 화면에서는 계속 켜져
    // 있는 불일치가 있었다. AppSettingsController가 아직 로드 전이면
    // 로드가 끝나는 시점에 알아서 wakelock을 적용해준다.
    AppSettingsController().ensureLoaded();
    AppSettingsController().addListener(_onSettingsChanged);

    _listenerStartTime = DateTime.now().millisecondsSinceEpoch;
    _startRemoteListener();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(CalculatorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDir != widget.startDir) {
      setState(() {
        _localStartDir = widget.startDir;
      });
    }
  }

  Future<void> _loadSavedStartDir() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDir = prefs.getString('saved_calc_start_dir');
      if (savedDir != null && savedDir.isNotEmpty) {
        setState(() {
          _localStartDir = savedDir;
        });
        widget.onStartDirChanged(savedDir);
      }
    } catch (e) {
      debugPrint("방향 불러오기 실패: $e");
    }
  }

  void _startRemoteListener() {
    _remoteSubscription = FirebaseFirestore.instance
        .collection('remote_commands')
        .where('timestamp', isGreaterThan: _listenerStartTime)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen(
          (snapshot) {
            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final data = change.doc.data();
                if (data != null) {
                  // 🚀 [수정] 즉시 처리하지 않고 큐에 쌓은 뒤 순차 처리 -> 동시 도착 시 유실 방지
                  _remoteQueue.add(data);
                }
              }
            }
            _processRemoteQueue();
          },
          // 🚀 [수정] 스트림 에러 발생 시 조용히 죽지 않도록 로그를 남김
          onError: (error, stackTrace) {
            debugPrint("원격 명령 리스너 오류: $error");
          },
        );
  }

  // 🚀 [추가] 원격 명령 큐를 하나씩 순차적으로 처리
  Future<void> _processRemoteQueue() async {
    if (_isAutoProcessing || _remoteQueue.isEmpty || !mounted) return;
    final data = _remoteQueue.removeAt(0);
    await receiveRemoteData(data);
    if (mounted && _remoteQueue.isNotEmpty) {
      // ignore: unawaited_futures
      _processRemoteQueue();
    }
  }

  @override
  void dispose() {
    // 🚀 [수정] 이 화면이 wakelock을 켰던 게 아니므로, 나갈 때도 강제로
    // disable() 하지 않는다 (그러면 설정에서 켜둔 wakelock을 이 화면을
    // 나가는 순간 꺼버리는 반대 방향의 버그가 생긴다).
    AppSettingsController().removeListener(_onSettingsChanged);
    _remoteSubscription?.cancel();
    _tempController.dispose();
    super.dispose();
  }

  void _showMarginNumpad() async {
    final controller = TextEditingController(
      text: _safeMargin > 0 ? _safeMargin.toStringAsFixed(0) : "",
    );

    await MakitaNumpad.show(
      context,
      controller: controller,
      title: "여유 마진 입력 (mm)",
    );

    if (!mounted) return;
    double? val = double.tryParse(controller.text);
    setState(() {
      _safeMargin = val ?? 0.0;
    });
  }

  void _showCustomAnglePad() async {
    final controller = TextEditingController(
      text: (_currentAngle ?? 0) > 0
          ? _currentAngle!.toStringAsFixed(_currentAngle! % 1 == 0 ? 0 : 1)
          : "",
    );

    await MakitaNumpad.show(
      context,
      controller: controller,
      // 🚀 [수정] 실제 물리적으로 유효한 범위(0~180°)로 안내 문구 정정
      title: "자유 각도 입력 (0~180°)",
    );

    if (!mounted) return;
    double? val = double.tryParse(controller.text);
    if (val != null) {
      setState(() {
        // 🚀 [수정] 음수 입력을 막고, 180°를 넘는 값도 클램프
        // (180°에 근접한 값은 엔진에서 별도로 에러 처리됨 - U-Bend 전용 계산기 사용 권장)
        _currentAngle = val.clamp(0.0, 180.0);
      });
    }
  }

  Future<void> receiveRemoteData(Map<String, dynamic> data) async {
    if (!mounted || _isAutoProcessing) return;

    setState(() => _isAutoProcessing = true);

    String docId = data['id']?.toString() ?? "";
    String mode = data['mode'] ?? "";
    double val1 = double.tryParse(data['val1'].toString()) ?? 0;
    double val2 = double.tryParse(data['val2'].toString()) ?? 0;
    double angle = double.tryParse(data['angle'].toString()) ?? 0;
    String dirStr = data['dir'] ?? "UP";

    double targetRot = _parseDirectionToRotation(dirStr);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("📲 리모컨 수신: [${data['modeName'] ?? mode}] 처리 중..."),
        backgroundColor: makitaTeal,
        duration: const Duration(milliseconds: 1500),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 400));

    if (mode == "STRAIGHT" || mode == "직관 (Straight)") {
      await _executeMacro(val1, 0.0, targetRot, docId);
    } else if (mode == "BEND_90" || mode == "90° 벤딩") {
      await _executeMacro(val1, 90.0, targetRot, docId);
    } else if (mode == "OFFSET" || mode == "오프셋") {
      double d = 0;
      double finalAngle = angle;
      if (angle > 0) {
        double sinVal = math.sin(angle * (math.pi / 180));
        d = sinVal == 0 ? val1 : val1 / sinVal;
      } else if (val2 > 0) {
        d = val2;
        finalAngle =
            math.asin((val1 / val2).clamp(-1.0, 1.0)) * (180 / math.pi);
      }
      await _executeMacro(d, finalAngle, targetRot, docId);
    } else if (mode == "SADDLE" || mode == "새들") {
      double d = val1;
      if (angle > 0) {
        double sinVal = math.sin(angle * (math.pi / 180));
        d = sinVal == 0 ? val1 : val1 / sinVal;
      }
      await _executeMacro(d, angle, targetRot, docId);
    } else if (mode == "ROLLING" || mode == "롤링 오프셋") {
      double trueH = math.sqrt((val1 * val1) + (val2 * val2));
      double d = trueH;
      if (angle > 0) {
        double sinVal = math.sin(angle * (math.pi / 180));
        d = sinVal == 0 ? trueH : trueH / sinVal;
      }
      await _executeMacro(d, angle, targetRot, docId);
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

  Future<void> _executeMacro(
    double length,
    double angle,
    double rot,
    String docId,
  ) async {
    setState(() {
      _tempController.text = length.toStringAsFixed(1);
      _currentAngle = angle;
      _currentRotation = rot;
    });

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    // 🚀 [수정] 실제 적용 성공 여부를 받아서 원격 쪽에 정확한 상태를 전달
    final bool success = _handleApply();

    if (docId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('remote_commands')
            .doc(docId)
            .update({'status': success ? 'completed' : 'failed'});
      } catch (e) {
        debugPrint("상태 업데이트 실패: $e");
      }
    }

    setState(() => _isAutoProcessing = false);
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

  // 🚀 [수정] 성공 여부를 bool로 반환하도록 변경 (원격 명령 완료 처리에 사용)
  bool _handleApply() {
    final double? val = double.tryParse(_tempController.text);
    if (val != null && val > 0) {
      if (_currentAngle == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ 벤딩 각도를 먼저 선택해 주십시오."),
            backgroundColor: slate600,
            duration: Duration(milliseconds: 1500),
          ),
        );
        return false;
      }

      if (_currentRotation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ 배관 진행 방향(6축)을 먼저 선택해 주십시오."),
            backgroundColor: slate600,
            duration: Duration(milliseconds: 1500),
          ),
        );
        return false;
      }

      if (_editingIndex != null) {
        widget.onUpdateBend(
          _editingIndex!,
          val,
          _currentAngle!,
          _currentRotation!,
        );
        _editingIndex = null;
      } else {
        widget.onAddBend(val, _currentAngle!, _currentRotation!);
      }
      _tempController.clear();

      setState(() {
        _currentAngle = null;
        _currentRotation = null;
      });
      FocusScope.of(context).unfocus();
      return true;
    }

    // 🚀 [수정] 길이가 비어있거나 0 이하일 때도 다른 검증들과 일관되게 안내
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("⚠️ 올바른 길이를 입력해 주십시오."),
        backgroundColor: slate600,
        duration: Duration(milliseconds: 1500),
      ),
    );
    return false;
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
                    // 🚀 [수정] MobilePipeVisualizer로 변경
                    MobilePipeVisualizer(
                      bendList: widget.bendList,
                      bendRadius: BendDataManager().radius,
                      outerDiameter: AppSettingsController().isInch
                          ? AppSettingsController().tubeOD * 25.4
                          : AppSettingsController().tubeOD,
                      initialStartDir: _localStartDir,
                      onStartDirChanged: (newDir) async {
                        setState(() {
                          _localStartDir = newDir;
                        });
                        widget.onStartDirChanged(newDir);
                        try {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('saved_calc_start_dir', newDir);
                        } catch (e) {
                          debugPrint("방향 저장 실패: $e");
                        }
                      },
                    ),
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

            Expanded(
              flex: 5,
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 12, right: 12),
                child: Column(
                  children: [
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
                              : makitaTeal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _estimatedTotalLength == 0
                                ? slate900
                                : makitaTeal.withValues(alpha: 0.5),
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
                                    : makitaTeal,
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
                                      // 🚀 [수정] MobileOffsetBottomSheet 로 교체
                                      _buildToolChip("오프셋", null, () {
                                        MobileOffsetBottomSheet.show(
                                          context,
                                          currentRotation:
                                              _currentRotation ?? 0.0,
                                          onAddMultipleBends: (bends) {
                                            if (_editingIndex != null) {
                                              widget.onDeleteBend(
                                                _editingIndex!,
                                              );
                                              widget.onAddMultipleBends(bends);
                                              setState(() {
                                                _editingIndex = null;
                                                _tempController.clear();
                                              });
                                            } else {
                                              widget.onAddMultipleBends(bends);
                                            }
                                          },
                                        );
                                      }),
                                      const SizedBox(width: 6),
                                      // 🚀 [수정] MobileSaddleBottomSheet 로 교체
                                      _buildToolChip("새들", null, () {
                                        MobileSaddleBottomSheet.show(
                                          context,
                                          currentRotation:
                                              _currentRotation ?? 0.0,
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
                                      // 🚀 [수정] MobileRollingOffsetBottomSheet 로 교체
                                      _buildToolChip(
                                        "롤링",
                                        LucideIcons.orbit,
                                        () {
                                          MobileRollingOffsetBottomSheet.show(
                                            context,
                                            currentRotation:
                                                _currentRotation ?? 0.0,
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
                                      const SizedBox(width: 6),
                                      // 🚀 [수정] MobileParallelShrinkBottomSheet 로 교체
                                      _buildToolChip(
                                        "평행/축소",
                                        LucideIcons.layoutGrid,
                                        () {
                                          MobileParallelShrinkBottomSheet.show(
                                            context,
                                            currentAngle: _currentAngle,
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
                                            _currentRotation = null;
                                            _currentAngle = null;
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
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.playlist_add_rounded,
                                            size: 48,
                                            color: Colors.grey.shade300,
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            "치수와 방향을 셋팅하십시오\n또는 리모컨으로 데이터를 전송하십시오",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: slate600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ReorderableListView.builder(
                                      itemCount: widget.bendList.length,
                                      onReorder: (int oldIndex, int newIndex) {
                                        setState(() {
                                          if (oldIndex < newIndex) {
                                            newIndex -= 1;
                                          }
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

                                        bool isWarning =
                                            bend['length']! > 0.01 &&
                                            bend['length']! <
                                                _minStraightFromSettings;

                                        return GestureDetector(
                                          key: ValueKey(bend.hashCode),
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
                                                  : (isWarning
                                                        ? Colors.red.shade50
                                                        : slate100),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isEditing
                                                    ? makitaTeal
                                                    : (isWarning
                                                          ? Colors.red.shade300
                                                          : Colors.transparent),
                                                width: isEditing || isWarning
                                                    ? 2
                                                    : 1,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
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
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
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
                                                      "L: ${bend['length']} | A: ${bend['angle']}° | DIR: ${_getDirectionText(bend['rotation'])}",
                                                      style: TextStyle(
                                                        color: isEditing
                                                            ? makitaTeal
                                                            : (isWarning
                                                                  ? Colors
                                                                        .red
                                                                        .shade900
                                                                  : slate900),
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (isWarning)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 6,
                                                        ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.end,
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .warning_amber_rounded,
                                                          color: Colors
                                                              .red
                                                              .shade600,
                                                          size: 14,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          "기계 간섭 주의 (최소 직관 ${_minStraightFromSettings.round()}mm 권장)",
                                                          style: TextStyle(
                                                            color: Colors
                                                                .red
                                                                .shade600,
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
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
                                        key: ValueKey(
                                          _editingIndex ?? 'new_input',
                                        ),
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
                              _MakitaBtn(
                                label: "0°(직관)",
                                fontSize: 13,
                                onTap: () =>
                                    setState(() => _currentAngle = 0.0),
                              ),
                              const SizedBox(width: 8),
                              _MakitaBtn(
                                label: "15°",
                                fontSize: 18,
                                onTap: () =>
                                    setState(() => _currentAngle = 15.0),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Row(
                            children: [
                              _MakitaBtn(
                                label: "22.5°",
                                fontSize: 18,
                                onTap: () =>
                                    setState(() => _currentAngle = 22.5),
                              ),
                              const SizedBox(width: 8),
                              _MakitaBtn(
                                label: "30°",
                                fontSize: 18,
                                onTap: () =>
                                    setState(() => _currentAngle = 30.0),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Row(
                            children: [
                              _MakitaBtn(
                                label: "45°",
                                fontSize: 18,
                                onTap: () =>
                                    setState(() => _currentAngle = 45.0),
                              ),
                              const SizedBox(width: 8),
                              _MakitaBtn(
                                label: "60°",
                                fontSize: 18,
                                onTap: () =>
                                    setState(() => _currentAngle = 60.0),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Row(
                            children: [
                              _MakitaBtn(
                                label: "90°",
                                fontSize: 18,
                                onTap: () =>
                                    setState(() => _currentAngle = 90.0),
                              ),
                              const SizedBox(width: 8),
                              _MakitaBtn(
                                label: "180°",
                                fontSize: 18,
                                onTap: () =>
                                    setState(() => _currentAngle = 180.0),
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
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
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
                                                    : makitaTeal,
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
                              _MakitaBtn(
                                label: "직접 입력",
                                icon: Icons.edit,
                                fontSize: 13,
                                onTap: _showCustomAnglePad,
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
                            _MakitaBtn(
                              icon: LucideIcons.arrowUpRight,
                              label: "FRONT",
                              isVertical: true,
                              borderRadius: 10,
                              defaultTextColor: slate600,
                              defaultIconColor: slate600,
                              fontSize: 12,
                              onTap: () =>
                                  setState(() => _currentRotation = 360.0),
                            ),
                            const SizedBox(width: 8),
                            _MakitaBtn(
                              icon: LucideIcons.arrowUp,
                              label: "UP",
                              isVertical: true,
                              borderRadius: 10,
                              defaultTextColor: slate600,
                              defaultIconColor: slate600,
                              fontSize: 12,
                              onTap: () =>
                                  setState(() => _currentRotation = 0.0),
                            ),
                            const SizedBox(width: 8),
                            _MakitaBtn(
                              icon: LucideIcons.arrowDownLeft,
                              label: "BACK",
                              isVertical: true,
                              borderRadius: 10,
                              defaultTextColor: slate600,
                              defaultIconColor: slate600,
                              fontSize: 12,
                              onTap: () =>
                                  setState(() => _currentRotation = 450.0),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Row(
                          children: [
                            _MakitaBtn(
                              icon: LucideIcons.arrowLeft,
                              label: "LEFT",
                              isVertical: true,
                              borderRadius: 10,
                              defaultTextColor: slate600,
                              defaultIconColor: slate600,
                              fontSize: 12,
                              onTap: () =>
                                  setState(() => _currentRotation = 270.0),
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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
                                                  : makitaTeal,
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
                            _MakitaBtn(
                              icon: LucideIcons.arrowRight,
                              label: "RIGHT",
                              isVertical: true,
                              borderRadius: 10,
                              defaultTextColor: slate600,
                              defaultIconColor: slate600,
                              fontSize: 12,
                              onTap: () =>
                                  setState(() => _currentRotation = 90.0),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Row(
                          children: [
                            _MakitaBtn(
                              icon: Icons.delete_outline,
                              label: "라인 삭제",
                              primaryColor: Colors.red.shade600,
                              isVertical: true,
                              solidFill: false,
                              borderRadius: 10,
                              fontSize: 13,
                              onTap: () {
                                if (_editingIndex == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "삭제할 라인을 위 리스트에서 먼저 선택해 주십시오.",
                                      ),
                                      backgroundColor: slate600,
                                      duration: Duration(milliseconds: 1500),
                                    ),
                                  );
                                  return;
                                }
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
                                          widget.onDeleteBend(_editingIndex!);
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
                            _MakitaBtn(
                              icon: LucideIcons.arrowDown,
                              label: "DOWN",
                              isVertical: true,
                              borderRadius: 10,
                              defaultTextColor: slate600,
                              defaultIconColor: slate600,
                              fontSize: 12,
                              onTap: () =>
                                  setState(() => _currentRotation = 180.0),
                            ),
                            const SizedBox(width: 8),
                            _MakitaBtn(
                              icon: Icons.check,
                              label: "적용",
                              primaryColor: makitaTeal,
                              isVertical: true,
                              solidFill: false,
                              borderRadius: 10,
                              fontSize: 13,
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
}

class _MakitaBtn extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final Color primaryColor;
  final Color? defaultTextColor;
  final Color? defaultIconColor;
  final bool isVertical;
  final bool solidFill;
  final double fontSize;
  final double borderRadius;

  const _MakitaBtn({
    required this.label,
    required this.onTap,
    this.icon,
    this.primaryColor = makitaTeal,
    this.defaultTextColor,
    this.defaultIconColor,
    this.isVertical = false,
    this.solidFill = true,
    this.fontSize = 14,
    this.borderRadius = 8,
  });

  @override
  State<_MakitaBtn> createState() => _MakitaBtnState();
}

class _MakitaBtnState extends State<_MakitaBtn> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    Color bgColor = pureWhite;
    Color borderColor = Colors.grey.shade300;
    Color txtColor = widget.defaultTextColor ?? slate900;
    Color icnColor = widget.defaultIconColor ?? slate600;
    double borderWidth = 1.0;
    List<BoxShadow> shadows = [];

    if (widget.solidFill) {
      if (_isPressed) {
        bgColor = widget.primaryColor;
        borderColor = widget.primaryColor;
        borderWidth = 2.0;
        txtColor = pureWhite;
        icnColor = pureWhite;
        shadows = [
          BoxShadow(
            color: widget.primaryColor.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ];
      }
    } else {
      borderColor = widget.primaryColor;
      borderWidth = _isPressed ? 3.0 : 1.5;
      txtColor = widget.primaryColor;
      icnColor = widget.primaryColor;
      if (_isPressed) {
        bgColor = widget.primaryColor.withValues(alpha: 0.1);
        shadows = [
          BoxShadow(
            color: widget.primaryColor.withValues(alpha: 0.3),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ];
      }
    }

    final content = widget.isVertical
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null)
                Icon(widget.icon, color: icnColor, size: 26),
              if (widget.icon != null) const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  color: txtColor,
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null)
                Icon(widget.icon, size: 14, color: icnColor),
              if (widget.icon != null) const SizedBox(width: 4),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: txtColor,
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );

    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          // 🚀 [수정] 지연 중 위젯이 사라졌으면 onTap을 호출하지 않음
          if (!mounted) return;
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: shadows,
          ),
          child: Center(
            child: widget.isVertical
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4.0,
                        vertical: 2.0,
                      ),
                      child: content,
                    ),
                  )
                : content,
          ),
        ),
      ),
    );
  }
}
