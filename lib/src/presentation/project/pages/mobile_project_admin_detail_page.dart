import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🔥 파이어베이스 연동

const Color tossBlue = Color(0xFF3182F6);
const Color tossGrey = Color(0xFFF2F4F6);
const Color slate900 = Color(0xFF191F28);
const Color slate600 = Color(0xFF8B95A1);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = Color(0xFFF04438);

class MobileProjectAdminDetailPage extends StatefulWidget {
  final Map<String, dynamic> project;

  const MobileProjectAdminDetailPage({super.key, required this.project});

  @override
  State<MobileProjectAdminDetailPage> createState() =>
      _MobileProjectAdminDetailPageState();
}

class _MobileProjectAdminDetailPageState
    extends State<MobileProjectAdminDetailPage> {
  // 공정 단계 입력을 위한 컨트롤러
  late TextEditingController _stageCtrl;

  @override
  void initState() {
    super.initState();
    // 초기 공정 단계 값을 입력창에 세팅
    _stageCtrl = TextEditingController(text: widget.project['stage'] ?? '대기');
  }

  @override
  void dispose() {
    _stageCtrl.dispose();
    super.dispose();
  }

  // 🔥 파이어베이스의 프로젝트 상태를 업데이트하는 공통 함수
  Future<void> _updateProjectStage(String newStage) async {
    final projectId = widget.project['id'];
    if (projectId != null) {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .update({'stage': newStage});
      setState(() {
        widget.project['stage'] = newStage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tossGrey,
      appBar: AppBar(
        backgroundColor: pureWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slate900),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "상세 일정 및 관리",
              style: TextStyle(
                color: slate900,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              widget.project['name'] ?? '이름 없음',
              style: const TextStyle(
                color: tossBlue,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 공정 단계 관리 (직접 입력 + 드롭다운 혼합)
            _buildSectionTitle("현재 공정 단계 지정"),
            _buildStageSelector(),
            const SizedBox(height: 32),

            // 2. 사급 및 대형 자재 관리 (Firebase 연동)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle("사급 및 주요 자재 일정"),
                IconButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _showAddDialog("자재", (name, date) async {
                      // 🔥 새 자재 데이터를 Firestore에 추가
                      await FirebaseFirestore.instance
                          .collection('project_materials')
                          .add({
                            'projectName':
                                widget.project['name'], // 어떤 프로젝트 소속인지 표시
                            'name': name,
                            'date': date,
                            'status': "대기 중",
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                    });
                  },
                  icon: const Icon(Icons.add_circle, color: tossBlue, size: 28),
                ),
              ],
            ),
            // 🔥 자재 리스트 StreamBuilder
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('project_materials')
                  .where('projectName', isEqualTo: widget.project['name'])
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text(
                    "등록된 자재 일정이 없습니다.",
                    style: TextStyle(color: slate600),
                  );
                }
                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final m = doc.data() as Map<String, dynamic>;
                    m['id'] = doc.id; // 문서 ID 챙기기

                    return _buildManageCard(
                      title: m['name'] ?? '-',
                      subtitle: "입고 예정: ${m['date'] ?? '-'}",
                      badge: m['status'] ?? '대기 중',
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _showEditMaterialBottomSheet(m); // 🔥 맵 전체를 넘김
                      },
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 32),

            // 3. 검사 일정 관리 (Firebase 연동)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle("검사 일정 현황"),
                IconButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _showAddDialog("검사", (name, date) async {
                      // 🔥 새 검사 데이터를 Firestore에 추가
                      await FirebaseFirestore.instance
                          .collection('project_inspections')
                          .add({
                            'projectName': widget.project['name'],
                            'name': name,
                            'date': date,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                    });
                  },
                  icon: const Icon(Icons.add_circle, color: tossBlue, size: 28),
                ),
              ],
            ),
            // 🔥 검사 리스트 StreamBuilder
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('project_inspections')
                  .where('projectName', isEqualTo: widget.project['name'])
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text(
                    "등록된 검사 일정이 없습니다.",
                    style: TextStyle(color: slate600),
                  );
                }
                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final i = doc.data() as Map<String, dynamic>;
                    i['id'] = doc.id;

                    return _buildManageCard(
                      title: i['name'] ?? '-',
                      subtitle: "검사 예정일: ${i['date'] ?? '-'}",
                      icon: LucideIcons.clipboardCheck,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _showEditInspectionBottomSheet(i); // 🔥 맵 전체를 넘김
                      },
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: slate900,
        ),
      ),
    );
  }

  // 공정 단계 셀렉터
  Widget _buildStageSelector() {
    final List<String> presetStages = [
      "자재 발주",
      "자재 검사",
      "작업 진행",
      "검사 및 펀치",
      "수정 작업 중",
      "완료",
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _stageCtrl,
              style: const TextStyle(
                color: slate900,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                hintText: "공정 단계를 직접 입력하세요",
                hintStyle: TextStyle(
                  color: Colors.black26,
                  fontWeight: FontWeight.normal,
                ),
                border: InputBorder.none,
              ),
              onSubmitted: (value) {
                // 키보드 엔터를 쳤을 때 파이어베이스 업데이트
                _updateProjectStage(value.trim());
              },
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: slate600,
            ),
            color: pureWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (String value) {
              HapticFeedback.mediumImpact();
              _stageCtrl.text = value;
              _updateProjectStage(value); // 🔥 선택 즉시 파이어베이스 업데이트
            },
            itemBuilder: (BuildContext context) {
              return presetStages.map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(
                    choice,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: slate900,
                    ),
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
    );
  }

  // 관리용 카드 UI
  Widget _buildManageCard({
    required String title,
    required String subtitle,
    String? badge,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    bool isWarning = badge == "입고 지연";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWarning
              ? warningRed.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Icon(
          icon ?? LucideIcons.packageCheck,
          color: isWarning ? warningRed : slate600,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: slate900,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: isWarning ? warningRed : slate600,
            fontWeight: isWarning ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: badge != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isWarning
                      ? warningRed.withValues(alpha: 0.1)
                      : tossGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isWarning ? warningRed : slate900,
                  ),
                ),
              )
            : const Icon(Icons.chevron_right_rounded, color: slate600),
      ),
    );
  }

  // 항목 추가 다이얼로그 (신규 등록)
  void _showAddDialog(String type, Function(String name, String date) onAdd) {
    final nameCtrl = TextEditingController();
    final dateCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "신규 $type 일정 등록",
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                hintText: "$type 명칭 (예: 메인 엔진)",
                filled: true,
                fillColor: tossGrey,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dateCtrl,
              decoration: InputDecoration(
                hintText: "날짜 (예: 2026-05-10)",
                filled: true,
                fillColor: tossGrey,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소", style: TextStyle(color: slate600)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && dateCtrl.text.isNotEmpty) {
                onAdd(nameCtrl.text, dateCtrl.text);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: tossBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "등록",
              style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // 자재 수정/삭제 바텀시트
  void _showEditMaterialBottomSheet(Map<String, dynamic> material) {
    final nameCtrl = TextEditingController(text: material['name']);
    final dateCtrl = TextEditingController(text: material['date']);
    String currentStatus = material['status'] ?? "대기 중";
    String docId = material['id']; // Firestore 문서 ID

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 32,
            ),
            decoration: const BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "자재 일정 수정",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: slate900,
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  "자재명",
                  style: TextStyle(
                    color: slate600,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: tossGrey,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  "입고 예정일",
                  style: TextStyle(
                    color: slate600,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: dateCtrl,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: tossGrey,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  "현재 상태",
                  style: TextStyle(
                    color: slate600,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tossGrey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: currentStatus,
                      isExpanded: true,
                      items: ["대기 중", "제작 중", "입고 지연", "입고 완료"].map((
                        String value,
                      ) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setSheetState(() => currentStatus = newValue!);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: () async {
                          HapticFeedback.heavyImpact();
                          await FirebaseFirestore.instance
                              .collection('project_materials')
                              .doc(docId)
                              .delete(); // 🔥 Firestore에서 삭제
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("삭제되었습니다.")),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: warningRed,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: warningRed),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "삭제",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          await FirebaseFirestore.instance
                              .collection('project_materials')
                              .doc(docId)
                              .update({
                                'name': nameCtrl.text.trim(),
                                'date': dateCtrl.text.trim(),
                                'status': currentStatus,
                              }); // 🔥 Firestore에 수정 사항 저장
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("수정 내용이 저장되었습니다.")),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tossBlue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "저장하기",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: pureWhite,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 검사 수정/삭제 바텀시트
  void _showEditInspectionBottomSheet(Map<String, dynamic> inspection) {
    final nameCtrl = TextEditingController(text: inspection['name']);
    final dateCtrl = TextEditingController(text: inspection['date']);
    String docId = inspection['id']; // Firestore 문서 ID

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        decoration: const BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "검사 일정 수정",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: slate900,
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              "검사명",
              style: TextStyle(
                color: slate600,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                filled: true,
                fillColor: tossGrey,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              "검사 예정일",
              style: TextStyle(
                color: slate600,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: dateCtrl,
              decoration: InputDecoration(
                filled: true,
                fillColor: tossGrey,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: () async {
                      HapticFeedback.heavyImpact();
                      await FirebaseFirestore.instance
                          .collection('project_inspections')
                          .doc(docId)
                          .delete(); // 🔥 Firestore에서 삭제
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("삭제되었습니다.")),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: warningRed,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: warningRed),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "삭제",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      await FirebaseFirestore.instance
                          .collection('project_inspections')
                          .doc(docId)
                          .update({
                            'name': nameCtrl.text.trim(),
                            'date': dateCtrl.text.trim(),
                          }); // 🔥 Firestore에 수정 사항 저장
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("수정 내용이 저장되었습니다.")),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tossBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "저장하기",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: pureWhite,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
