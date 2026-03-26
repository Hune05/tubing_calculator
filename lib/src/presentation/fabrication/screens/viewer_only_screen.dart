import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
// 💡 아래 임포트 경로는 유저님의 실제 폴더 구조에 맞게 유지해주세요!
import 'package:tubing_calculator/src/presentation/calculator/widgets/pipe_visualizer.dart';

class ViewerOnlyScreen extends StatefulWidget {
  final String project;
  final String pipeSize;
  final List<Map<String, dynamic>> bendList;

  const ViewerOnlyScreen({
    super.key,
    required this.project,
    required this.pipeSize,
    required this.bendList,
  });

  @override
  State<ViewerOnlyScreen> createState() => _ViewerOnlyScreenState();
}

class _ViewerOnlyScreenState extends State<ViewerOnlyScreen> {
  int? _selectedSegmentIndex;

  // 🚀 진행도 저장을 위한 리스트 (해당 세션에서만 유지되는 휘발성 데이터)
  late List<bool> _completedSteps;

  @override
  void initState() {
    super.initState();
    // 🚀 현장 편의성: 뷰어 화면에 진입하면 절대 화면이 꺼지지 않음
    WakelockPlus.enable();

    // 초기화: 벤딩 리스트 길이만큼 체크 상태 생성 (false)
    _completedSteps = List<bool>.filled(widget.bendList.length, false);
  }

  @override
  void dispose() {
    // 🚀 화면을 나갈 때 화면 꺼짐 방지 해제 (배터리 보호)
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151B22), // 다크 테마 고정
      appBar: AppBar(
        backgroundColor: const Color(0xFF007580),
        foregroundColor: Colors.white,
        title: Column(
          mainAxisSize: MainAxisSize.min, // 🚀 상단 오버플로우 방지
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
          // 현재 작업 진행률 표시
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
            // 🚀 상단: 3D 파이프 뷰어 영역 (남는 공간을 모두 차지함)
            Expanded(
              child: Stack(
                children: [
                  PipeVisualizer(
                    bendList: widget.bendList,
                    selectedSegmentIndex: _selectedSegmentIndex,
                    isLightMode: false, // 항상 다크 모드
                  ),
                  // 수정 불가 경고 라벨
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
                          color: Colors.redAccent.withOpacity(0.5),
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

            // 🚀 하단: 장갑 친화적 작업 체크리스트 (가로 스크롤)
            Container(
              height: 145, // 🚀 5픽셀 오버플로우 해결을 위해 높이를 넉넉하게 145px로 확장!
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
                    padding: EdgeInsets.only(
                      left: 16,
                      top: 12,
                      bottom: 4,
                    ), // 🚀 패딩 최적화
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
                        String lengthInfo = "L: ${bend['length']?.round()}";

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              // 터치 시 해당 구간을 3D 뷰어에서 하이라이트
                              _selectedSegmentIndex = index;
                            });
                          },
                          onDoubleTap: () {
                            setState(() {
                              // 🚀 두 번 터치(또는 길게 누르기) 시 완료 처리 토글
                              _completedSteps[index] = !_completedSteps[index];
                            });
                          },
                          child: Container(
                            width: 140, // 🚀 버튼 너비도 살짝 키워서 터치하기 쉽게!
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? Colors.green.shade800.withOpacity(0.4)
                                  : (isSelected
                                        ? Colors.orange.withOpacity(0.2)
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
                              alignment: Alignment.centerLeft, // 🚀 내부 정렬을 명확하게
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize
                                        .min, // 🚀 하단부 오버플로우 방지 핵심 속성!
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
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                        ),
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
