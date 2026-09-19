import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 🎨 프리미엄 컬러 팔레트
const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate800 = Color(0xFF1E293B);
const Color slate600 = Color(0xFF475569);
const Color slate400 = Color(0xFF94A3B8); // 폴더 아이콘 색상 추가
const Color slate200 = Color(0xFFE2E8F0);
const Color slate100 = Color(0xFFF1F5F9);
const Color slate50 = Color(0xFFF8FAFC);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);

class ConduitHistoryTab extends StatefulWidget {
  const ConduitHistoryTab({super.key});

  @override
  State<ConduitHistoryTab> createState() => _ConduitHistoryTabState();
}

class _ConduitHistoryTabState extends State<ConduitHistoryTab> {
  // 🚀 폴더명(folderName) 데이터 추가
  final List<Map<String, dynamic>> _savedDrawings = [
    {
      "id": "1",
      "folderName": "A구역 메인라인", // 📁 그룹화 기준
      "title": "A구역 메인 트레이 배관 (오프셋)",
      "date": "2024-05-24 14:30",
      "totalCut": 1850,
      "segmentCount": 3,
    },
    {
      "id": "2",
      "folderName": "EPS실 내부",
      "title": "EPS실 벽체 통과 (3점 새들)",
      "date": "2024-05-23 09:15",
      "totalCut": 2100,
      "segmentCount": 5,
    },
    {
      "id": "3",
      "folderName": "A구역 메인라인",
      "title": "서브 트레이 연결부 (90도 벤딩)",
      "date": "2024-05-25 10:00",
      "totalCut": 1200,
      "segmentCount": 2,
    },
  ];

  // 🚀 index 대신 고유 id를 사용하여 삭제 (그룹화 상태에서 안전함)
  void _deleteHistory(String id) {
    HapticFeedback.mediumImpact();
    setState(() {
      _savedDrawings.removeWhere((item) => item['id'] == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          "도면이 삭제되었습니다.",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // 🚀 index 대신 고유 id를 사용하여 데이터 불러오기
  void _loadHistory(String id) {
    HapticFeedback.heavyImpact();
    final targetItem = _savedDrawings.firstWhere((item) => item['id'] == id);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "도면 불러오기",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: slate900,
          ),
        ),
        content: Text(
          "'${targetItem['title']}'\n데이터를 현재 작업창으로 불러오시겠습니까?",
          style: const TextStyle(color: slate600, fontSize: 15, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: slate100,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "취소",
                    style: TextStyle(
                      color: slate600,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          "도면을 성공적으로 불러왔습니다.",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: makitaTeal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: makitaTeal,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "불러오기",
                    style: TextStyle(
                      color: pureWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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

  // 🚀 데이터를 폴더별로 묶어주는 로직 및 Sliver 리스트 생성
  List<Widget> _buildGroupedSlivers() {
    if (_savedDrawings.isEmpty) {
      return [
        SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState()),
      ];
    }

    // 1. 데이터를 폴더별로 그룹화 (Map 형태)
    Map<String, List<Map<String, dynamic>>> groupedData = {};
    for (var item in _savedDrawings) {
      String folder = item['folderName'] ?? '미분류 도면';
      if (!groupedData.containsKey(folder)) {
        groupedData[folder] = [];
      }
      groupedData[folder]!.add(item);
    }

    List<Widget> slivers = [];

    // 2. 그룹화된 데이터를 바탕으로 UI 생성
    groupedData.forEach((folderName, items) {
      // 폴더 타이틀 (섹션 헤더)
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
            child: Row(
              children: [
                const Icon(Icons.folder_rounded, color: slate400, size: 22),
                const SizedBox(width: 8),
                Text(
                  folderName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: slate900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: slate200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${items.length}",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: slate600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // 해당 폴더 내의 카드 리스트
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildTossStyleCard(items[index]),
              childCount: items.length,
            ),
          ),
        ),
      );
    });

    // 하단 여백 추가
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 120)));

    return slivers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slate100,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          _buildTossStyleHeader(),
          // 🚀 그룹화된 슬리버 리스트를 스프레드 연산자(...)로 펼쳐서 삽입
          ..._buildGroupedSlivers(),
        ],
      ),
    );
  }

  Widget _buildTossStyleHeader() {
    return SliverAppBar(
      expandedHeight: 140.0,
      pinned: true,
      backgroundColor: slate100,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        title: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "보관된 도면 ${_savedDrawings.length}개",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: slate900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // 🚀 인자로 Map 자체를 받도록 수정 (id 접근 용이)
  Widget _buildTossStyleCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: slate900.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: slate50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.architecture_rounded,
                  color: makitaTeal,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      item['title'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: slate900,
                        height: 1.3,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item['date'],
                      style: const TextStyle(
                        fontSize: 13,
                        color: slate600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(50),
                  onTap: () => _deleteHistory(item['id']), // 🚀 고유 id 전달
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.close_rounded, color: slate200, size: 20),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: _buildInfoChip("총 재단 길이", "${item['totalCut']} mm"),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoChip("조립 구간", "${item['segmentCount']} 구간"),
              ),
            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _loadHistory(item['id']), // 🚀 고유 id 전달
              style: ElevatedButton.styleFrom(
                backgroundColor: slate100,
                foregroundColor: slate900,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "작업창으로 불러오기",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: slate50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: slate600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: slate900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: pureWhite,
            ),
            child: const Icon(
              Icons.folder_off_rounded,
              size: 48,
              color: slate200,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "보관된 도면이 없습니다",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: slate900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "마킹 탭에서 작업 결과를 저장해 보십시오.",
            style: TextStyle(
              color: slate600,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
