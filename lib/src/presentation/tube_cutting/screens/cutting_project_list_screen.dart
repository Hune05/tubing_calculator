// lib/src/presentation/tube_cutting/screens/cutting_project_list_screen.dart

import 'package:flutter/material.dart';
import '../../../data/models/cutting_project_model.dart';
import 'cutting_main_screen.dart';

const Color darkBg = Color(0xFF1E2124);
const Color cardBg = Color(0xFF2A2E33);
const Color makitaTeal = Color(0xFF007580);
const Color mutedWhite = Color(0xFFD0D4D9);

class CuttingProjectListScreen extends StatefulWidget {
  const CuttingProjectListScreen({super.key});

  @override
  State<CuttingProjectListScreen> createState() =>
      _CuttingProjectListScreenState();
}

class _CuttingProjectListScreenState extends State<CuttingProjectListScreen> {
  final List<CuttingProject> _projects = [];

  void _createNewProject() {
    TextEditingController nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardBg,
          title: const Text(
            "새 컷팅 작업 생성",
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "작업명 (예: A구역 1층 라인)",
              hintStyle: TextStyle(color: Colors.grey.shade600),
              filled: true,
              fillColor: darkBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: makitaTeal),
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _projects.insert(
                      0,
                      CuttingProject(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameCtrl.text.trim(),
                        createdAt: DateTime.now(),
                      ),
                    );
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text("생성", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _openProject(CuttingProject project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CuttingMainScreen(project: project),
      ),
    ).then((_) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        elevation: 0,
        title: const Text(
          "튜브 컷팅 작업 보관함",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: _projects.isEmpty
          ? Center(
              child: Text(
                "등록된 작업이 없습니다.\n우측 하단의 + 버튼을 눌러 새 작업을 생성하세요.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 18),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1.5,
              ),
              itemCount: _projects.length,
              itemBuilder: (context, index) {
                final project = _projects[index];
                return InkWell(
                  onTap: () => _openProject(project),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.folder,
                              color: makitaTeal,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                project.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "총 절단 횟수: ${project.cutCount} 회",
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "예상 소모량: ${project.estimatedMeters} m",
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
