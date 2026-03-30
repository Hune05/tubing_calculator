import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

// ✅ 모바일 전용 뷰어 임포트
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

  // 🚀 리스트에서 선택한 세그먼트를 3D 도면에서 빨갛게 표시하기 위한 상태
  int? _selectedSegmentIndex;

  @override
  void initState() {
    super.initState();
    _parseData();
  }

  void _parseData() {
    try {
      _pToP = jsonDecode(widget.itemData['p_to_p']?.toString() ?? '{}');
      List<dynamic> rawBends = jsonDecode(
        widget.itemData['bend_data']?.toString() ?? '[]',
      );

      _bendList = List<Map<String, dynamic>>.from(rawBends);

      // 🚀 [해결 포인트] DB에서 String으로 넘어오든 int/double로 넘어오든
      // toString() 후 tryParse를 사용해 타입 캐스팅 에러(0으로 뜨는 현상) 원천 차단!
      double dbTotal =
          double.tryParse(widget.itemData['total_length']?.toString() ?? '0') ??
          0.0;

      double pToPTotal =
          double.tryParse(
            _pToP['total_length']?.toString() ??
                _pToP['total_cut']?.toString() ??
                '0',
          ) ??
          0.0;

      double bendListTotal = 0.0;
      if (_bendList.isNotEmpty) {
        bendListTotal =
            double.tryParse(_bendList[0]['total_length']?.toString() ?? '0') ??
            0.0;
      }

      // 셋 중 하나라도 0보다 큰 진짜 값이 있으면 그걸 _totalLength로 확정
      double maxTotal = dbTotal;
      if (pToPTotal > maxTotal) maxTotal = pToPTotal;
      if (bendListTotal > maxTotal) maxTotal = bendListTotal;
      _totalLength = maxTotal;

      _pipeSize = widget.itemData['pipe_size']?.toString() ?? 'Unknown';
      _projectName = _pToP['project']?.toString() ?? '미지정 프로젝트';
      _fromTo = "${_pToP['from'] ?? '미상'} ➔ ${_pToP['to'] ?? '미상'}";
      _tailLength = double.tryParse(_pToP['tail']?.toString() ?? '0') ?? 0.0;
      _startDir = _pToP['start_dir']?.toString() ?? 'RIGHT';
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

    // 🚀 모바일 전용 탭 구조 적용
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
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
            // 🌟 1. 공통 요약 정보 (항상 상단 노출)
            _buildSummaryPanel(),

            // 🌟 2. 탭 바 메뉴
            Container(
              color: pureWhite,
              child: const TabBar(
                labelColor: makitaTeal,
                unselectedLabelColor: slate600,
                indicatorColor: makitaTeal,
                indicatorWeight: 3,
                tabs: [
                  Tab(text: "ISO DWG (3D)"),
                  Tab(text: "마킹 가이드"),
                ],
              ),
            ),

            // 🌟 3. 탭 화면 (1페이지 / 2페이지)
            Expanded(
              child: TabBarView(
                // 🚀 3D 뷰어 화면에서 터치 회전 시 탭이 넘어가버리는 현상 방지
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildIsoPage(), // 1페이지 (3D 도면)
                  _buildMarkingPage(displayMarks), // 2페이지 (마킹 리스트)
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 🚀 [컴포넌트] 상단 요약 정보 (총 컷팅 기장)
  // ==========================================
  Widget _buildSummaryPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: pureWhite,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    );
  }

  // ==========================================
  // 🚀 [페이지 1] ISO DWG (3D 뷰어)
  // ==========================================
  Widget _buildIsoPage() {
    return Container(
      width: double.infinity,
      color: slate900, // 다크 모드 배경
      child: MobilePipeVisualizer(
        bendList: _bendList,
        tailLength: _tailLength,
        initialStartDir: _startDir,
        startFit: _pToP['start_fit'] == true,
        endFit: _pToP['end_fit'] == true,
        isLightMode: false,
        selectedSegmentIndex: _selectedSegmentIndex,
        onStartDirChanged: (newDir) {
          setState(() {
            _startDir = newDir;
          });
        },
        // 🚀 3D 뷰어의 우측 뱃지에도 값을 전달합니다!
        totalCutLength: _totalLength,
      ),
    );
  }

  // ==========================================
  // 🚀 [페이지 2] 마킹 리스트
  // ==========================================
  Widget _buildMarkingPage(List<Map<String, dynamic>> displayMarks) {
    if (displayMarks.isEmpty) {
      return const Center(
        child: Text("표시할 마킹 데이터가 없습니다.", style: TextStyle(color: slate600)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16).copyWith(bottom: 40),
      itemCount: displayMarks.length,
      itemBuilder: (context, index) {
        final item = displayMarks[index];

        int cumulativeMark = (item['marking_point'] as num?)?.round() ?? 0;
        int incrementalMark = (item['incremental_mark'] as num?)?.round() ?? 0;
        int originalLength = (item['length'] as num?)?.round() ?? 0;

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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.orange.shade50
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: Colors.orange.shade400, width: 2)
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_downward,
                    color: isSelected ? Colors.orange.shade700 : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "직관 연장: +$originalLength mm",
                      style: TextStyle(
                        color: isSelected ? Colors.orange.shade900 : slate600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    "마킹: $cumulativeMark",
                    style: TextStyle(
                      color: isSelected ? Colors.orange.shade900 : makitaTeal,
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
        double rotationVal = (item['rotation'] as num?)?.toDouble() ?? 0.0;
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
                    color: isSelected ? Colors.orange.shade500 : makitaTeal,
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
                          color: isSelected ? Colors.orange.shade800 : slate600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        "$cumulativeMark",
                        style: TextStyle(
                          color: isSelected ? Colors.orange.shade900 : slate900,
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
                        color: isSelected ? Colors.orange.shade900 : slate900,
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
    );
  }
}
