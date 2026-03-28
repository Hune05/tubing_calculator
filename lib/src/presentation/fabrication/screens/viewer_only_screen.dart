import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/pipe_visualizer.dart';

class ViewerOnlyScreen extends StatefulWidget {
  final String project;
  final String pipeSize;
  final List<Map<String, dynamic>> bendList;

  final bool startFit;
  final bool endFit;
  final double tailLength;
  final String startDir;

  const ViewerOnlyScreen({
    super.key,
    required this.project,
    required this.pipeSize,
    required this.bendList,
    this.startFit = false,
    this.endFit = false,
    this.tailLength = 0.0,
    this.startDir = 'RIGHT',
  });

  @override
  State<ViewerOnlyScreen> createState() => _ViewerOnlyScreenState();
}

class _ViewerOnlyScreenState extends State<ViewerOnlyScreen> {
  int? _selectedSegmentIndex;
  late List<bool> _completedSteps;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _completedSteps = List<bool>.filled(widget.bendList.length, false);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151B22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF007580),
        foregroundColor: Colors.white,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "QR VIEWER: ${widget.project}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              "SPEC: ${widget.pipeSize} | Read-Only",
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                "${_completedSteps.where((e) => e).length} / ${_completedSteps.length} 완료",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orangeAccent,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  PipeVisualizer(
                    bendList: widget.bendList,
                    selectedSegmentIndex: _selectedSegmentIndex,
                    isLightMode: false,
                    startFit: widget.startFit,
                    endFit: widget.endFit,
                    tailLength: widget.tailLength,
                    initialStartDir: widget.startDir,
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          // 🚀 플러터 최신 문법 반영
                          color: Colors.redAccent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            color: Colors.redAccent,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            "참조 전용 (저장 불가)",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 160, // 🚀 오버플로우 방지 높이 160으로 확장 적용
              decoration: BoxDecoration(
                color: const Color(0xFF1E2630),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade800, width: 2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 12, bottom: 4),
                    child: Text(
                      "작업 진행 체크리스트 (터치하여 완료)",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: widget.bendList.length,
                      itemBuilder: (context, index) {
                        bool isCompleted = _completedSteps[index];
                        bool isSelected = _selectedSegmentIndex == index;
                        var bend = widget.bendList[index];
                        bool isStraight = bend['is_straight'] ?? false;

                        String label = isStraight
                            ? "직관 연장"
                            : "벤딩 ${bend['angle']}°";

                        double lengthVal = (bend['length'] ?? 0).toDouble();
                        String lengthInfo = "L: ${lengthVal.round()}";

                        if (!isStraight &&
                            bend['mark'] != null &&
                            bend['mark'] > 0) {
                          lengthInfo += "\nMark: ${bend['mark']}";
                        }

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedSegmentIndex = index;
                            });
                          },
                          onDoubleTap: () {
                            setState(() {
                              _completedSteps[index] = !_completedSteps[index];
                            });
                          },
                          child: Container(
                            width: 140,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  // 🚀 플러터 최신 문법 반영
                                  ? Colors.green.shade800.withValues(alpha: 0.4)
                                  : (isSelected
                                        ? Colors.orange.withValues(alpha: 0.2)
                                        : const Color(0xFF2B3643)),
                              border: Border.all(
                                color: isCompleted
                                    ? Colors.green
                                    : (isSelected
                                          ? Colors.orange
                                          : Colors.transparent),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "${index + 1}. $label",
                                        style: TextStyle(
                                          color: isCompleted
                                              ? Colors.greenAccent
                                              : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          decoration: isCompleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        lengthInfo,
                                        style: TextStyle(
                                          color: isCompleted
                                              ? Colors.green.shade200
                                              : Colors.white70,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (isCompleted)
                                  const Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Icon(
                                      Icons.check_circle,
                                      color: Colors.greenAccent,
                                      size: 24,
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
          ],
        ),
      ),
    );
  }
}
