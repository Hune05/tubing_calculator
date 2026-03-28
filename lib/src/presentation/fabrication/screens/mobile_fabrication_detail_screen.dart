import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

// ✅ 모바일 전용 뷰어 임포트 추가 (경로 확인 필수!)
import 'package:tubing_calculator/src/presentation/calculator/widgets/mobile_pipe_visualizer.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class MobileFabricationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> itemData;

  const MobileFabricationDetailScreen({super.key, required this.itemData});

  @override
  State<MobileFabricationDetailScreen> createState() =>
      _MobileFabricationDetailScreenState();
}

class _MobileFabricationDetailScreenState
    extends State<MobileFabricationDetailScreen> {
  Map<String, dynamic> _pToP = {};
  List<Map<String, dynamic>> _bendList = [];
  double _totalLength = 0.0;
  String _pipeSize = "";
  String _projectName = "";
  String _fromTo = "";
  double _tailLength = 0.0;
  String _startDir = "RIGHT";

  // 🚀 [추가] 리스트에서 선택한 세그먼트를 3D 도면에서 빨갛게 표시하기 위한 상태
  int? _selectedSegmentIndex;

  @override
  void initState() {
    super.initState();
    _parseData();
  }

  void _parseData() {
    try {
      _pToP = jsonDecode(widget.itemData['p_to_p'] ?? '{}');
      List<dynamic> rawBends = jsonDecode(widget.itemData['bend_data'] ?? '[]');

      _bendList = List<Map<String, dynamic>>.from(rawBends);
      _totalLength =
          (widget.itemData['total_length'] as num?)?.toDouble() ?? 0.0;
      _pipeSize = widget.itemData['pipe_size'] ?? 'Unknown';
      _projectName = _pToP['project'] ?? '미지정 프로젝트';
      _fromTo = "${_pToP['from'] ?? '미상'} ➔ ${_pToP['to'] ?? '미상'}";
      _tailLength = (_pToP['tail'] as num?)?.toDouble() ?? 0.0;
      _startDir = _pToP['start_dir'] ?? 'RIGHT';
    } catch (e) {
      debugPrint("데이터 파싱 에러: $e");
    }
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
    // 깡통(더미) 직관 숨기기 처리
    List<Map<String, dynamic>> displayMarks = _bendList
        .where((b) => b['is_hidden'] != true)
        .toList();

    return Scaffold(
      backgroundColor: slate100,
      appBar: AppBar(
        backgroundColor: makitaTeal,
        foregroundColor: pureWhite,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _projectName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              _fromTo,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // 🌟 1. 상단 3D 뷰어 영역 (고정 높이)
          Container(
            height:
                MediaQuery.of(context).size.height *
                0.40, // 🚀 3D 도면 보기가 편하도록 높이를 살짝 키웠습니다 (35% -> 40%)
            width: double.infinity,
            color: slate900, // 🚀 3D 컨트롤러 버튼들이 잘 보이도록 배경을 다크 모드로 변경!
            child: Stack(
              children: [
                // 🚀 모든 기능을 그대로 살린 PipeVisualizer 호출
                MobilePipeVisualizer(
                  bendList: _bendList,
                  tailLength: _tailLength,
                  initialStartDir: _startDir,
                  startFit: _pToP['start_fit'] == true,
                  endFit: _pToP['end_fit'] == true,
                  isLightMode:
                      false, // 🚀 모바일에서도 어두운 테마를 써야 흰색 컨트롤 버튼들이 잘 보입니다!
                  selectedSegmentIndex:
                      _selectedSegmentIndex, // 🚀 리스트 클릭 시 하이라이트 연동!
                  onStartDirChanged: (newDir) {
                    setState(() {
                      _startDir = newDir;
                    });
                  },
                ),
                // 💡 상단 좌측 배관 규격 라벨
                Positioned(
                  top: 12,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: pureWhite.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: pureWhite.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      "규격: $_pipeSize",
                      style: const TextStyle(
                        color: pureWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 🌟 2. 컷팅 기장 요약 정보
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: pureWhite,
              border: Border.symmetric(
                horizontal: BorderSide(color: Colors.grey.shade300),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "총 컷팅 기장 (Total Cut)",
                      style: TextStyle(
                        color: slate600,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${_totalLength.round()} mm",
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                if (_tailLength > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: makitaTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "여유: +${_tailLength.round()}mm",
                      style: const TextStyle(
                        color: makitaTeal,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 🌟 3. 하단 마킹 리스트 (스크롤)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16).copyWith(bottom: 40),
              itemCount: displayMarks.length,
              itemBuilder: (context, index) {
                final item = displayMarks[index];

                int cumulativeMark =
                    (item['marking_point'] as num?)?.round() ?? 0;
                int incrementalMark =
                    (item['incremental_mark'] as num?)?.round() ?? 0;
                int originalLength = (item['length'] as num?)?.round() ?? 0;

                // 🚀 이 아이템이 bendList 원본에서 몇 번째 인덱스인지 찾습니다. (하이라이트를 위해)
                int realIndex = _bendList.indexOf(item);
                bool isSelected = _selectedSegmentIndex == realIndex;

                // 직관 연장 블록
                if (item['is_straight'] == true) {
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedSegmentIndex = isSelected ? null : realIndex;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.orange.shade50
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(
                                color: Colors.orange.shade400,
                                width: 2,
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.arrow_downward,
                            color: isSelected
                                ? Colors.orange.shade700
                                : Colors.grey,
                            size: 16,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "직관 연장: +$originalLength mm",
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.orange.shade900
                                    : slate600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            "마킹: $cumulativeMark",
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.orange.shade900
                                  : makitaTeal,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // 벤딩 블록
                double rotationVal =
                    (item['rotation'] as num?)?.toDouble() ?? 0.0;
                double angleVal = (item['angle'] as num?)?.toDouble() ?? 0.0;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedSegmentIndex = isSelected ? null : realIndex;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.orange.shade50 : pureWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.orange.shade400
                            : makitaTeal.withValues(alpha: 0.3),
                        width: isSelected ? 2 : 1,
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
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.orange.shade500
                                : makitaTeal,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "${item['mark_num'] ?? '-'}",
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
                              Text(
                                "누적 마킹 지점",
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.orange.shade800
                                      : slate600,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                "$cumulativeMark",
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.orange.shade900
                                      : slate900,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              if ((item['mark_num'] as num?) != null &&
                                  (item['mark_num'] as num) > 1)
                                Text(
                                  "↳ 앞 마킹과의 거리: +$incrementalMark",
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.orange.shade600
                                        : makitaTeal,
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
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.orange.shade900
                                    : slate900,
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
                                  color: isSelected
                                      ? Colors.orange.shade700
                                      : makitaTeal,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "${angleVal.round()}° / ${_getDirectionText(rotationVal)}",
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.orange.shade700
                                        : makitaTeal,
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
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
