import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/database/database_helper.dart';

const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF0F172A);
const Color slate600 = Color(0xFF475569);
const Color slate100 = Color(0xFFF1F5F9);
const Color pureWhite = Color(0xFFFFFFFF);

class SaveJobDialog extends StatefulWidget {
  final Function(String projectName, String fromText, String toText) onSave;

  const SaveJobDialog({super.key, required this.onSave});

  static void show(
    BuildContext context, {
    required Function(String, String, String) onSave,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => SaveJobDialog(onSave: onSave),
    );
  }

  @override
  State<SaveJobDialog> createState() => _SaveJobDialogState();
}

class _SaveJobDialogState extends State<SaveJobDialog> {
  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();

  List<Map<String, dynamic>> _projects = [];
  String? _selectedProject;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  // DB에서 만들어둔 프로젝트 목록 불러오기
  Future<void> _loadProjects() async {
    final projects = await DatabaseHelper.instance.getProjects();
    setState(() {
      _projects = projects;
      if (_projects.isNotEmpty) {
        _selectedProject = _projects.first['name']; // 기본값으로 최신 프로젝트 선택
      }
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: makitaTeal, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "작업 내역 저장",
              style: TextStyle(
                color: slate900,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "어느 프로젝트에 귀속시킬까요?",
              style: TextStyle(color: slate600, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // 1. 프로젝트 선택 드롭다운
            const Text(
              "프로젝트 선택",
              style: TextStyle(
                color: slate900,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: makitaTeal),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: slate100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedProject,
                        isExpanded: true,
                        dropdownColor: pureWhite,
                        hint: const Text("프로젝트를 선택하세요 (또는 새로 생성)"),
                        items: _projects.map((proj) {
                          return DropdownMenuItem<String>(
                            value: proj['name'],
                            child: Text(
                              proj['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: slate900,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedProject = val;
                          });
                        },
                      ),
                    ),
                  ),
            if (_projects.isEmpty && !_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  "※ 등록된 프로젝트가 없습니다. [프로젝트 관리] 메뉴에서 먼저 생성해주세요.",
                  style: TextStyle(color: Colors.redAccent, fontSize: 11),
                ),
              ),

            const SizedBox(height: 20),

            // 2. 구간 정보 (FROM -> TO)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "FROM (시작점)",
                        style: TextStyle(
                          color: slate900,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _fromCtrl,
                        decoration: InputDecoration(
                          hintText: "예: VLV-101",
                          filled: true,
                          fillColor: slate100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "TO (종료점)",
                        style: TextStyle(
                          color: slate900,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _toCtrl,
                        decoration: InputDecoration(
                          hintText: "예: INST-205",
                          filled: true,
                          fillColor: slate100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // 3. 버튼 영역
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "취소",
                      style: TextStyle(
                        color: slate600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: makitaTeal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      if (_selectedProject == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("프로젝트를 선택해주세요!"),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }
                      // 부모 위젯(계산기)으로 데이터 넘겨주기
                      widget.onSave(
                        _selectedProject!,
                        _fromCtrl.text,
                        _toCtrl.text,
                      );
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "저장하기",
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
      ),
    );
  }
}
