import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

// 💡 일관된 라이트/슬레이트 테마 컬러
const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color slate50 = Color(0xFFF8FAFC);
const Color pureWhite = Color(0xFFFFFFFF);

class ProjectManagementPage extends StatefulWidget {
  const ProjectManagementPage({super.key});

  @override
  State<ProjectManagementPage> createState() => _ProjectManagementPageState();
}

class _ProjectManagementPageState extends State<ProjectManagementPage> {
  // 열려있는 프로젝트 카드의 인덱스
  int? _expandedIndex;

  // 💡 테스트용 프로젝트별 소모 자재 데이터
  final List<Map<String, dynamic>> projects = [
    {
      "name": "MAIN LINE #1 Setup",
      "date": "2026-03-01 ~ 진행중",
      "status": "ONGOING",
      "materials": [
        {"name": "1/2\" Seamless Tube", "type": "TUBE", "qty_mm": 44500},
        {"name": "1/2\" Union Elbow", "type": "FITTING", "qty_ea": 14},
        {"name": "1/2\" Male Connector", "type": "FITTING", "qty_ea": 8},
      ],
    },
    {
      "name": "SUB LINE #2 Repair",
      "date": "2026-02-15 ~ 2026-02-20",
      "status": "COMPLETED",
      "materials": [
        {"name": "3/8\" Seamless Tube", "type": "TUBE", "qty_mm": 11800},
        {"name": "3/8\" Union Tee", "type": "FITTING", "qty_ea": 4},
      ],
    },
  ];

  // 💡 프로젝트 생성 팝업 띄우기
  void _showCreateProjectSheet() {
    final TextEditingController nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "신규 프로젝트 생성",
                  style: TextStyle(
                    color: slate900,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "새로운 라인 또는 작업 구간의 이름을 입력하세요.",
                  style: TextStyle(color: slate600, fontSize: 13),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: const TextStyle(
                    color: slate900,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    labelText: "프로젝트 명 (예: UTILITY LINE #3)",
                    filled: true,
                    fillColor: slate50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: makitaTeal, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: makitaTeal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      if (nameController.text.trim().isNotEmpty) {
                        // 오늘 날짜 구하기
                        final today = DateTime.now();
                        final dateString =
                            "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

                        setState(() {
                          // 새 프로젝트를 리스트 맨 위(0번째)에 추가
                          projects.insert(0, {
                            "name": nameController.text.trim(),
                            "date": "$dateString ~ 진행중",
                            "status": "ONGOING",
                            "materials": [], // 초기엔 소모 자재 없음
                          });
                        });
                        Navigator.pop(context); // 팝업 닫기
                      }
                    },
                    child: const Text(
                      "생성하기",
                      style: TextStyle(
                        color: pureWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slate50,
      appBar: AppBar(
        title: const Text(
          'PROJECTS',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 1.5,
          ),
        ),
        backgroundColor: makitaTeal,
        foregroundColor: pureWhite,
        elevation: 0,
      ),
      body: projects.isEmpty
          ? const Center(
              child: Text(
                "등록된 프로젝트가 없습니다.\n우측 하단 버튼을 눌러 생성하세요.",
                textAlign: TextAlign.center,
                style: TextStyle(color: slate600, height: 1.5),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: 80,
              ),
              itemCount: projects.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final project = projects[index];
                final bool isExpanded = _expandedIndex == index;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: pureWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isExpanded ? makitaTeal : Colors.grey.shade300,
                      width: isExpanded ? 2.0 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // 🔹 프로젝트 헤더 (클릭 시 확장)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _expandedIndex = isExpanded ? null : index;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // 아이콘
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isExpanded
                                      ? makitaTeal.withOpacity(0.1)
                                      : slate50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  LucideIcons.folderKanban,
                                  color: isExpanded ? makitaTeal : slate600,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),

                              // 프로젝트 제목 & 날짜
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      project['name'],
                                      style: const TextStyle(
                                        color: slate900,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      project['date'],
                                      style: const TextStyle(
                                        color: slate600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // 상태 배지
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: project['status'] == 'ONGOING'
                                      ? makitaTeal.withOpacity(0.1)
                                      : slate100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  project['status'],
                                  style: TextStyle(
                                    color: project['status'] == 'ONGOING'
                                        ? makitaTeal
                                        : slate600,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: slate600,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 🔹 소모 자재 리스트 (확장 영역)
                      if (isExpanded) ...[
                        const Divider(height: 1),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: slate50,
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(12),
                            ),
                          ),
                          child: project['materials'].isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    "아직 등록된 소모 자재가 없습니다.",
                                    style: TextStyle(
                                      color: slate600,
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "소모 자재 집계 (BOM)",
                                      style: TextStyle(
                                        color: slate900,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ...project['materials'].map<Widget>((mat) {
                                      return _buildMaterialRow(mat);
                                    }).toList(),
                                  ],
                                ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
      // 🔥 생성 기능 연결 완료
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateProjectSheet,
        backgroundColor: makitaTeal,
        icon: const Icon(Icons.add, color: pureWhite),
        label: const Text(
          "프로젝트 생성",
          style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // 💡 자재별 소모량 표시 위젯 (튜브일 경우 '본' 계산 적용)
  Widget _buildMaterialRow(Map<String, dynamic> mat) {
    bool isTube = mat['type'] == 'TUBE';

    // 튜브인 경우 총 길이를 6m(6000mm) 기준으로 나누어 필요 '본' 수를 올림으로 계산합니다.
    int tubeSticks = 0;
    if (isTube) {
      double totalMm = (mat['qty_mm'] as int).toDouble();
      tubeSticks = (totalMm / 6000).ceil();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isTube ? Icons.line_weight : LucideIcons.gitMerge,
            size: 18,
            color: slate600,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mat['name'],
                  style: const TextStyle(
                    color: slate900,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (isTube) ...[
                  const SizedBox(height: 2),
                  Text(
                    "총 컷팅: ${(mat['qty_mm'] / 1000).toStringAsFixed(1)}m",
                    style: const TextStyle(color: slate600, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isTube ? "$tubeSticks 본" : "${mat['qty_ea']} EA",
                style: const TextStyle(
                  color: makitaTeal,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              if (isTube)
                const Text(
                  "(6m 원장 기준)",
                  style: TextStyle(color: slate600, fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
