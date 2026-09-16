import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/models/cutting_project_model.dart';
import '../cutting_firestore_helper.dart';
import 'cutting_main_screen.dart';
import 'cutting_history_page.dart';

const Color lightBg = Color(0xFFF0F3F5); // 화이트/그레이 배경
const Color whiteCard = Colors.white;
const Color makitaTeal = Color(0xFF007580);
const Color textPrimary = Color(0xFF1A1A1A);

// 🚀 [1번 강화] 예전엔 이 화면(넓은 화면/태블릿용 '/cutting' 경로)이 메모리
// 리스트(_projects)만 들고 있어서, 화면을 나가거나 앱을 재시작하면 작업
// 목록 자체가 사라졌고, 저장/기록 기능도 전혀 연결돼 있지 않았다. 모바일
// 전용 화면(MobileCuttingProjectListPage)과 같은 Firestore 컬렉션
// (kCuttingProjectsCollection)을 써서, 어느 화면으로 들어와도 같은 작업
// 목록을 보고 이어서 작업할 수 있게 통일했다.
class CuttingProjectListScreen extends StatefulWidget {
  const CuttingProjectListScreen({super.key});

  @override
  State<CuttingProjectListScreen> createState() =>
      _CuttingProjectListScreenState();
}

class _CuttingProjectListScreenState extends State<CuttingProjectListScreen> {
  void _createNewProject() {
    TextEditingController nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: whiteCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "새 컷팅 작업 생성",
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: nameCtrl,
            autofocus: true,
            style: const TextStyle(color: textPrimary),
            decoration: InputDecoration(
              hintText: "작업명 (예: A구역 1층 라인)",
              hintStyle: TextStyle(color: Colors.grey.shade500),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: makitaTeal, width: 2),
              ),
            ),
            onSubmitted: (_) => _submitNewProject(context, nameCtrl.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "취소",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: makitaTeal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _submitNewProject(context, nameCtrl.text),
              child: const Text(
                "생성",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _submitNewProject(BuildContext context, String rawName) {
    final name = rawName.trim();
    if (name.isEmpty) return;
    FirebaseFirestore.instance.collection(kCuttingProjectsCollection).add({
      'name': name,
      'createdAt': DateTime.now().toIso8601String(),
      'totalTubeUsed': 0.0,
      'cutCount': 0,
      'usedFittings': <String, int>{},
    });
    Navigator.pop(context);
  }

  void _openProject(String docId, CuttingProject project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CuttingMainScreen(
          project: project,
          onSaveCallback:
              (
                double totalTubeLength,
                List<Map<String, dynamic>> fittingsList, [
                List<CutRecord> cutRecords = const [],
              ]) {
                saveCuttingSession(
                  projectId: docId,
                  project: project,
                  totalTubeLength: totalTubeLength,
                  fittingsList: fittingsList,
                  cutRecords: cutRecords,
                );
              },
        ),
      ),
    );
  }

  Future<void> _deleteProject(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: whiteCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "작업 삭제",
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
        content: const Text("이 컷팅 작업과 저장된 컷팅 기록을 모두 삭제할까요? 되돌릴 수 없습니다."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "삭제",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await deleteCuttingProjectWithRecords(docId);
    }
  }

  void _showCardMenu(
    BuildContext cardContext,
    String docId,
    CuttingProject project,
  ) {
    showMenu(
      context: cardContext,
      position: RelativeRect.fromLTRB(1, 1, 0, 0),
      color: whiteCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        const PopupMenuItem(
          value: 'history',
          child: Row(
            children: [
              Icon(Icons.history_rounded, color: makitaTeal, size: 20),
              SizedBox(width: 10),
              Text("컷팅 기록 보기"),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'deduct',
          child: Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: makitaTeal, size: 20),
              SizedBox(width: 10),
              Text("재고 차감"),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              SizedBox(width: 10),
              Text("삭제하기", style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (!mounted || value == null) return;
      switch (value) {
        case 'history':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CuttingHistoryPage(project: project),
            ),
          );
          break;
        case 'deduct':
          deductCuttingProjectInventory(
            context: context,
            projectId: docId,
            projectName: project.name,
          );
          break;
        case 'delete':
          _deleteProject(docId);
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        backgroundColor: makitaTeal,
        elevation: 0,
        title: const Text(
          "튜브 컷팅 작업 보관함",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(kCuttingProjectsCollection)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "작업 목록을 불러오지 못했습니다.\n${snapshot.error}",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: makitaTeal),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Text(
                "등록된 작업이 없습니다.\n우측 하단의 + 버튼을 눌러 새 작업을 생성하세요.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 18),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1.5,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final project = CuttingProject.fromMap(doc.id, data);
              final lastCutAt = data['lastCutAt'] is String
                  ? DateTime.tryParse(data['lastCutAt'] as String)
                  : null;

              return Builder(
                builder: (cardContext) => InkWell(
                  onTap: () => _openProject(doc.id, project),
                  onLongPress: () =>
                      _showCardMenu(cardContext, doc.id, project),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: whiteCard,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: makitaTeal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.folder_outlined,
                                color: makitaTeal,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                project.name,
                                style: const TextStyle(
                                  color: textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.more_vert_rounded,
                                color: Colors.grey.shade500,
                              ),
                              onPressed: () =>
                                  _showCardMenu(cardContext, doc.id, project),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "총 절단 횟수: ${project.cutCount} 회",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "예상 소모량: ${project.estimatedMeters} m",
                              style: const TextStyle(
                                color: makitaTeal,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (lastCutAt != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                "마지막 작업 ${lastCutAt.month}/${lastCutAt.day}",
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewProject,
        backgroundColor: makitaTeal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "새 작업 생성",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
