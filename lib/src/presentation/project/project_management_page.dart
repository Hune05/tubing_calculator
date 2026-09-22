import 'dart:io';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_stock_deduct.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';
import 'project_list_item.dart';

import 'package:tubing_calculator/src/core/utils/settings_manager.dart';
import 'package:tubing_calculator/src/data/models/cutting_project_model.dart';
import 'package:tubing_calculator/src/data/repositories/work_project_repository.dart';

// 🚀 [수정 완료] 새로 만든 Workspace를 import 합니다!
import 'package:tubing_calculator/src/presentation/calculator/screens/electric_bending_workspace.dart'
    as electric;
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/cutting_main_screen.dart'
    as manual;

class ProjectManagementPage extends StatefulWidget {
  const ProjectManagementPage({super.key, this.repository});

  // 테스트에서 서버 대신 쓸 저장소. 없으면 실제 저장소를 쓴다.
  final WorkProjectRepository? repository;

  @override
  State<ProjectManagementPage> createState() => _ProjectManagementPageState();
}

class _ProjectManagementPageState extends State<ProjectManagementPage> {
  int? _expandedIndex;
  final ImagePicker _picker = ImagePicker();

  late final WorkProjectRepository _projectRepo =
      widget.repository ?? WorkProjectRepository();
  List<Map<String, dynamic>> projects = [];
  bool _isLoadingProjects = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final loaded = await _projectRepo.fetchAllProjects();
      if (!mounted) return;
      setState(() {
        projects = loaded;
        _isLoadingProjects = false;
      });
    } catch (e) {
      debugPrint("⚠️ 내 프로젝트 불러오기 실패: $e");
      if (!mounted) return;
      setState(() => _isLoadingProjects = false);
    }
  }

  // 바뀐 프로젝트 하나만 저장한다. 예전에는 화면을 열 때 불러온 프로젝트 전부를
  // 다시 써서, 그 사이 다른 폰에서 넣은 일지·일정이 다른 프로젝트에서 지워질 수 있었다.
  void _saveData(int index) {
    if (index < 0 || index >= projects.length) return;
    // 예전엔 저장 실패가 아무 표시 없이 사라졌다(화면은 저장된 것처럼 보였다).
    _projectRepo.upsertProject(projects[index]).catchError((e) {
      debugPrint('프로젝트 저장 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("저장하지 못했습니다. 통신을 확인하고 다시 해 보십시오.")),
        );
      }
    });
  }

  Future<String?> _pickImageSource() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "사진 첨부 방식 선택",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: slate900,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: makitaTeal),
              title: const Text(
                '카메라로 바로 촬영',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: slate600),
              title: const Text(
                '갤러리에서 사진 선택',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source != null) {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      return image?.path;
    }
    return null;
  }

  Future<void> _confirmDeleteProject(int index) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text(
              "프로젝트 삭제",
              style: TextStyle(fontWeight: FontWeight.bold, color: slate900),
            ),
          ],
        ),
        content: const Text(
          "정말로 이 프로젝트를 삭제하시겠습니까?\n삭제된 데이터는 복구할 수 없습니다.",
          style: TextStyle(color: slate600, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              "취소",
              style: TextStyle(color: slate600, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "삭제",
              style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // 삭제한 프로젝트의 문서만 지운다(남은 프로젝트는 다시 쓰지 않는다).
      final deletedId = projects[index]['id']?.toString();
      setState(() {
        projects.removeAt(index);
        if (_expandedIndex == index) {
          _expandedIndex = null;
        } else if (_expandedIndex != null && _expandedIndex! > index) {
          _expandedIndex = _expandedIndex! - 1;
        }
      });
      if (deletedId != null) {
        _projectRepo.deleteProject(deletedId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🗑️ 프로젝트가 삭제되었습니다."),
            backgroundColor: slate600,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showUpdateProgressDialog(int index) {
    final project = projects[index];
    double currentProgress = ((project['progress'] as num?) ?? 0.0).toDouble();
    final TextEditingController percentCtrl = TextEditingController(
      text: (currentProgress * 100).toInt().toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isCompleted = currentProgress >= 1.0;
          return AlertDialog(
            backgroundColor: pureWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text(
              "진행률 업데이트",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "현재 진행률 (%)",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: slate900,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: percentCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: isCompleted
                              ? Colors.green.shade600
                              : makitaTeal,
                          fontSize: 18,
                        ),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                          filled: true,
                          fillColor: slate50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffixText: "%",
                        ),
                        onChanged: (val) {
                          double? parsed = double.tryParse(val);
                          if (parsed != null) {
                            setDialogState(
                              () => currentProgress =
                                  (parsed.clamp(0, 100)) / 100.0,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Slider(
                  value: currentProgress,
                  min: 0.0,
                  max: 1.0,
                  divisions: 100,
                  activeColor: isCompleted ? Colors.green.shade500 : makitaTeal,
                  inactiveColor: slate200,
                  onChanged: (val) {
                    setDialogState(() {
                      currentProgress = val;
                      percentCtrl.text = (val * 100).toInt().toString();
                    });
                  },
                ),
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green.shade50
                          : makitaTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCompleted
                            ? Colors.green.shade300
                            : makitaTeal.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      isCompleted ? "🎉 COMPLETED (완료)" : "🚀 ONGOING (진행중)",
                      style: TextStyle(
                        color: isCompleted ? Colors.green.shade700 : makitaTeal,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "취소",
                  style: TextStyle(
                    color: slate600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCompleted
                      ? Colors.green.shade600
                      : makitaTeal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    projects[index]['progress'] = currentProgress;
                    projects[index]['status'] = currentProgress >= 1.0
                        ? 'COMPLETED'
                        : 'ONGOING';
                    _saveData(index);
                  });
                  Navigator.pop(ctx);
                },
                child: const Text(
                  "저장",
                  style: TextStyle(
                    color: pureWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUpdateRevisionDialog(int projectIndex) {
    final TextEditingController revCtrl = TextEditingController(
      text: projects[projectIndex]['revision'],
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          "기준 도면(리비전) 변경",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: TextField(
          controller: revCtrl,
          autofocus: true, // 🚀 여기! 'autFocus' -> 'autofocus' 로 수정 완료
          style: const TextStyle(fontWeight: FontWeight.bold, color: slate900),
          decoration: InputDecoration(
            hintText: "예: P&ID Rev.3",
            filled: true,
            fillColor: pureWhite,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade500, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: makitaTeal, width: 2.0),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "취소",
              style: TextStyle(color: slate600, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: makitaTeal),
            onPressed: () {
              setState(() {
                projects[projectIndex]['revision'] = revCtrl.text.trim();
                _saveData(projectIndex);
              });
              Navigator.pop(ctx);
            },
            child: const Text(
              "수정",
              style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPunchDialog(int projectIndex) {
    final TextEditingController punchCtrl = TextEditingController();
    List<String> attachedImages = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool hasImage = attachedImages.isNotEmpty;
          return AlertDialog(
            backgroundColor: pureWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text(
              "펀치 리스트 추가",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: slate900,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: punchCtrl,
                    autofocus: true,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: slate900,
                    ),
                    decoration: InputDecoration(
                      labelText: "수정/보완 내용",
                      labelStyle: const TextStyle(
                        color: slate700,
                        fontWeight: FontWeight.bold,
                      ),
                      hintText: "여기에 내용을 입력하십시오",
                      filled: true,
                      fillColor: pureWhite,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.grey.shade500,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: makitaTeal,
                          width: 2.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: attachedImages.length >= 5
                        ? null
                        : () async {
                            final path = await _pickImageSource();
                            if (path != null) {
                              setDialogState(() => attachedImages.add(path));
                            }
                          },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: hasImage
                            ? makitaTeal.withValues(alpha: 0.05)
                            : pureWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: hasImage ? makitaTeal : Colors.grey.shade400,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.add_a_photo,
                            color: attachedImages.length >= 5
                                ? Colors.grey.shade400
                                : makitaTeal,
                            size: 36,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "현장 사진 첨부 (${attachedImages.length}/5)",
                            style: TextStyle(
                              color: attachedImages.length >= 5
                                  ? Colors.grey.shade400
                                  : slate900,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (hasImage) const SizedBox(height: 16),
                          if (hasImage)
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: attachedImages.asMap().entries.map((
                                entry,
                              ) {
                                int idx = entry.key;
                                String path = entry.value;
                                return Stack(
                                  alignment: Alignment.topRight,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(path),
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => setDialogState(
                                        () => attachedImages.removeAt(idx),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "취소",
                  style: TextStyle(
                    color: slate600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade500,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onPressed: () {
                  String textValue = punchCtrl.text.trim();
                  if (textValue.isNotEmpty || attachedImages.isNotEmpty) {
                    setState(() {
                      ((projects[projectIndex]['punch_lists'] ??= <dynamic>[])
                              as List)
                          .insert(0, {
                            "id": DateTime.now().millisecondsSinceEpoch
                                .toString(),
                            "created_at": DateTime.now(),
                            // 🚀 처리 완료 전까지 우선순위별 주기로 알림을
                            // 보내기 위한 발송 시간 기록 (모바일 이슈 등록과 동일)
                            "lastPunchReminderAt": null,
                            "linkedScheduleId": null,
                            "content": textValue.isEmpty
                                ? "내용 없음 (사진 참조)"
                                : textValue,
                            "is_completed": false,
                            "has_image": attachedImages.isNotEmpty,
                            "image_path": attachedImages.isNotEmpty
                                ? attachedImages.first
                                : null,
                            "image_paths": List.from(attachedImages),
                          });
                      _saveData(projectIndex);
                    });
                    Navigator.pop(ctx);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("내용을 입력하거나 사진을 최소 1장 첨부해 주십시오!"),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: const Text(
                  "등록하기",
                  style: TextStyle(
                    color: pureWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDailyReportDialog(int projectIndex, {int? reportIndex}) {
    final bool isEdit = reportIndex != null;
    final targetList =
        (projects[projectIndex]['daily_reports'] ??= <dynamic>[]) as List;
    final existingData = isEdit ? targetList[reportIndex] : null;

    final TextEditingController pointCtrl = TextEditingController(
      text: isEdit ? existingData['points'].toString() : "",
    );
    final TextEditingController noteCtrl = TextEditingController(
      text: isEdit ? existingData['note'] : "",
    );
    final TextEditingController asBuiltCtrl = TextEditingController(
      text: isEdit ? existingData['as_built_reason'] : "",
    );
    bool isAsBuilt = isEdit ? (existingData['is_as_built'] ?? false) : false;

    List<dynamic> existingPaths =
        existingData?['image_paths'] ??
        (existingData?['image_path'] != null
            ? [existingData!['image_path']]
            : []);
    List<String> attachedImages = isEdit
        ? List<String>.from(existingPaths)
        : [];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool hasImage = attachedImages.isNotEmpty;
            return AlertDialog(
              backgroundColor: pureWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                isEdit ? "작업 일지 수정" : "오늘의 작업 일지",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: slate900,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: pointCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: slate900,
                      ),
                      decoration: InputDecoration(
                        labelText: "벤딩 포인트 수",
                        labelStyle: const TextStyle(
                          color: slate700,
                          fontWeight: FontWeight.bold,
                        ),
                        filled: true,
                        fillColor: pureWhite,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.grey.shade500,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: makitaTeal,
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: slate900,
                      ),
                      decoration: InputDecoration(
                        labelText: "특이사항 및 작업 내용",
                        labelStyle: const TextStyle(
                          color: slate700,
                          fontWeight: FontWeight.bold,
                        ),
                        filled: true,
                        fillColor: pureWhite,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.grey.shade500,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: makitaTeal,
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    InkWell(
                      onTap: attachedImages.length >= 5
                          ? null
                          : () async {
                              final path = await _pickImageSource();
                              if (path != null) {
                                setDialogState(() => attachedImages.add(path));
                              }
                            },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: hasImage
                              ? makitaTeal.withValues(alpha: 0.05)
                              : pureWhite,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: hasImage ? makitaTeal : Colors.grey.shade400,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.add_a_photo,
                              color: attachedImages.length >= 5
                                  ? Colors.grey.shade400
                                  : makitaTeal,
                              size: 36,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "현장 사진 첨부 (${attachedImages.length}/5)",
                              style: TextStyle(
                                color: attachedImages.length >= 5
                                    ? Colors.grey.shade400
                                    : slate900,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            if (hasImage) const SizedBox(height: 16),
                            if (hasImage)
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: attachedImages.asMap().entries.map((
                                  entry,
                                ) {
                                  int idx = entry.key;
                                  String path = entry.value;
                                  return Stack(
                                    alignment: Alignment.topRight,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(path),
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => setDialogState(
                                          () => attachedImages.removeAt(idx),
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: isAsBuilt ? Colors.orange.shade50 : pureWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isAsBuilt
                              ? Colors.orange.shade400
                              : Colors.grey.shade400,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          CheckboxListTile(
                            title: Text(
                              "도면과 다름 (도면 수정 필요)",
                              style: TextStyle(
                                color: isAsBuilt
                                    ? Colors.orange.shade800
                                    : slate900,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            value: isAsBuilt,
                            activeColor: Colors.orange.shade700,
                            checkColor: pureWhite,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (val) =>
                                setDialogState(() => isAsBuilt = val ?? false),
                          ),
                          if (isAsBuilt)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                bottom: 16,
                              ),
                              child: TextField(
                                controller: asBuiltCtrl,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: slate900,
                                ),
                                decoration: InputDecoration(
                                  labelText: "변경 사유 및 벤딩값",
                                  filled: true,
                                  fillColor: pureWhite,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade500,
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.orange,
                                      width: 2.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    "취소",
                    style: TextStyle(
                      color: slate600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: makitaTeal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {
                    String ptText = pointCtrl.text.trim();
                    String ntText = noteCtrl.text.trim();

                    if (ptText.isNotEmpty ||
                        ntText.isNotEmpty ||
                        attachedImages.isNotEmpty) {
                      final today = DateTime.now();
                      final dateStr = isEdit
                          ? existingData['date']
                          : "${today.month.toString().padLeft(2, '0')}/${today.day.toString().padLeft(2, '0')}";

                      final newReport = {
                        "date": dateStr,
                        "points": int.tryParse(ptText) ?? 0,
                        "note": ntText.isEmpty ? "특이사항 없음" : ntText,
                        "is_as_built": isAsBuilt,
                        "as_built_reason": isAsBuilt
                            ? asBuiltCtrl.text.trim()
                            : "",
                        "has_image": attachedImages.isNotEmpty,
                        "image_path": attachedImages.isNotEmpty
                            ? attachedImages.first
                            : null,
                        "image_paths": List.from(attachedImages),
                      };

                      setState(() {
                        if (isEdit) {
                          targetList[reportIndex] = newReport;
                        } else {
                          targetList.insert(0, newReport);
                        }
                        _saveData(projectIndex);
                      });
                      Navigator.pop(ctx);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("포인트 수, 작업 내용, 또는 사진 중 하나는 입력해 주십시오!"),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: Text(
                    isEdit ? "수정완료" : "저장하기",
                    style: const TextStyle(
                      color: pureWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteDailyReport(
    int projectIndex,
    int reportIndex,
  ) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          "작업 일지 삭제",
          style: TextStyle(fontWeight: FontWeight.bold, color: slate900),
        ),
        content: const Text(
          "이 작업 일지를 삭제하시겠습니까?",
          style: TextStyle(color: slate600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              "취소",
              style: TextStyle(color: slate600, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "삭제",
              style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        (projects[projectIndex]['daily_reports'] as List?)?.removeAt(
          reportIndex,
        );
        _saveData(projectIndex);
      });
    }
  }

  Future<void> _deductMaterialsFromInventory(int index) async {
    final project = projects[index];
    if (project['isDeducted'] == true) return;

    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          "재고 한꺼번에 차감",
          style: TextStyle(fontWeight: FontWeight.bold, color: slate900),
        ),
        content: const Text("이 프로젝트에 사용된 자재들을 창고 재고에서 차감하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              "취소",
              style: TextStyle(color: slate600, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: makitaTeal),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "차감하기",
              style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    bool progressOpen = false;
    if (mounted) {
      progressOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) =>
            const Center(child: CircularProgressIndicator(color: makitaTeal)),
      );
    }

    try {
      final materials = project['materials'] as List<dynamic>;
      // 🚀 [고침] 차감 셈이 화면마다 따로 한 벌씩 있었다(여기·컷팅 목록·형강).
      // 한 곳만 고치면 나머지가 어긋나므로 공용 함수 하나로 모았다.
      // 재고에 없는 자재를 음수로 새로 만들지 않고, 통신이 안 될 때
      // "재고에 없다"고 잘라 말하지 않는 것도 그 함수에 들어 있다.
      final stock = await loadStockInfo();
      final takes = stockTakesFromMaterials(
        materials,
        barLengthByName: stock.barLengthByName,
        unitByName: stock.unitByName,
      );
      // 기록에 남는 작업 이름은 형강 쪽 모양으로 맞춘다.
      final result = await deductStockTakes(
        takes,
        projectName: '튜브 컷팅 · ${(project['name'] ?? '').toString()}',
        device: 'PC',
      );
      if (mounted) Navigator.pop(context);
      progressOpen = false;

      // 🚀 [고침] 예전에는 못 찾은 자재가 있어도 "완료"라고만 하고 차감함으로
      // 표시해 버려서, 자재를 나중에 넣고 다시 누르면 이미 뺀 것까지 또 빠졌다.
      // 뺀 자재는 목록에서 지우고, 못 찾은 것만 남겨 둔다.
      final leftNames = {for (final m in result.missing) m.name};
      final left = [
        for (final raw in materials)
          if (raw is Map &&
              leftNames.contains(
                (raw['db_name'] ?? raw['name'] ?? '').toString().trim(),
              ))
            raw,
      ];
      setState(() {
        projects[index]['materials'] = left;
        projects[index]['isDeducted'] = left.isEmpty;
        _saveData(index);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.allDone
                ? Colors.green.shade700
                : Colors.orange.shade800,
          ),
        );
      }
    } catch (e) {
      // 진행 창을 이미 닫은 뒤 실패하면 화면까지 닫히던 것.
      if (mounted && progressOpen) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("차감 실패: $e"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _showCreateProjectSheet() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController revController = TextEditingController();

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
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            decoration: const BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: slate200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  "신규 프로젝트 생성",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: slate900,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 32),

                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: const TextStyle(
                    color: slate900,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    labelText: "프로젝트 명",
                    labelStyle: const TextStyle(
                      color: makitaTeal,
                      fontWeight: FontWeight.bold,
                    ),
                    hintText: "새로운 프로젝트 이름을 입력하십시오",
                    hintStyle: const TextStyle(
                      color: slate400,
                      fontWeight: FontWeight.normal,
                    ),
                    filled: true,
                    fillColor: pureWhite,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: makitaTeal,
                        width: 2.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: revController,
                  style: const TextStyle(
                    color: slate900,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    labelText: "기준 도면 / P&ID 리비전",
                    labelStyle: const TextStyle(
                      color: makitaTeal,
                      fontWeight: FontWeight.bold,
                    ),
                    hintText: "예: Rev.0",
                    hintStyle: const TextStyle(
                      color: slate400,
                      fontWeight: FontWeight.normal,
                    ),
                    filled: true,
                    fillColor: pureWhite,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: makitaTeal,
                        width: 2.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: makitaTeal,
                      foregroundColor: pureWhite,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      if (nameController.text.trim().isNotEmpty) {
                        final today = DateTime.now();
                        setState(() {
                          projects.insert(0, {
                            "id": DateTime.now().millisecondsSinceEpoch
                                .toString(),
                            "name": nameController.text.trim(),
                            "date":
                                "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')} ~ 진행중",
                            "revision": revController.text.trim().isEmpty
                                ? "기준 도면 없음"
                                : revController.text.trim(),
                            "status": "ONGOING",
                            "progress": 0.0,
                            "isDeducted": false,
                            "materials": [],
                            "daily_reports": [],
                            "punch_lists": [],
                          });
                          _saveData(0);
                        });
                        Navigator.pop(context);
                      }
                    },
                    child: const Text(
                      "프로젝트 생성하기",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
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

  void _showDetailModal(
    String title,
    String content,
    List<dynamic>? imagePaths, {
    bool isAsBuilt = false,
    String? asBuiltReason,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: slate900,
                ),
              ),
              const Divider(height: 24, thickness: 1, color: slate200),

              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content,
                      style: const TextStyle(
                        fontSize: 16,
                        color: slate900,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isAsBuilt &&
                        asBuiltReason != null &&
                        asBuiltReason.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text(
                          "⚠️ As-Built: $asBuiltReason",
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),

              Expanded(
                child: (imagePaths != null && imagePaths.isNotEmpty)
                    ? Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          PageView.builder(
                            itemCount: imagePaths.length,
                            itemBuilder: (context, index) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: InteractiveViewer(
                                  minScale: 1.0,
                                  maxScale: 5.0,
                                  child: Image.file(
                                    File(imagePaths[index]),
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              );
                            },
                          ),
                          if (imagePaths.length > 1)
                            Container(
                              margin: const EdgeInsets.all(12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "👈 좌우로 스와이프 (${imagePaths.length}장) 👉",
                                style: const TextStyle(
                                  color: pureWhite,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      )
                    : Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: slate50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: slate200),
                        ),
                        child: const Center(
                          child: Text(
                            "📷 첨부된 사진이 없습니다.",
                            style: TextStyle(
                              color: slate600,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: makitaTeal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    "닫기",
                    style: TextStyle(
                      color: pureWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
      body: _isLoadingProjects
          ? const Center(child: CircularProgressIndicator(color: makitaTeal))
          : projects.isEmpty
          ? const Center(
              child: Text(
                "등록된 프로젝트가 없습니다.\n우측 하단 버튼을 눌러 추가하십시오.",
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

                return ProjectListItem(
                  project: project,
                  isExpanded: isExpanded,
                  onToggleExpand: () => setState(
                    () => _expandedIndex = isExpanded ? null : index,
                  ),
                  onUpdateRevision: () => _showUpdateRevisionDialog(index),
                  onDeleteProject: () => _confirmDeleteProject(index),
                  onUpdateProgress: () => _showUpdateProgressDialog(index),
                  onAddDailyReport: () => _showDailyReportDialog(index),
                  onEditDailyReport: (reportIdx) =>
                      _showDailyReportDialog(index, reportIndex: reportIdx),
                  onDeleteDailyReport: (reportIdx) =>
                      _confirmDeleteDailyReport(index, reportIdx),
                  onAddPunch: () => _showAddPunchDialog(index),
                  onDeductInventory: () => _deductMaterialsFromInventory(index),
                  onStateUpdate: () {
                    setState(() {});
                    _saveData(index);
                  },
                  onViewDailyReportDetail: (reportIdx) {
                    final report =
                        (project['daily_reports'] as List? ??
                        const [])[reportIdx];
                    List<dynamic> passImages =
                        report['image_paths'] ??
                        (report['image_path'] != null
                            ? [report['image_path']]
                            : []);
                    _showDetailModal(
                      "${report['date']} 작업 일지",
                      "벤딩 포인트: ${report['points']} pt\n작업 내용: ${report['note']}",
                      passImages,
                      isAsBuilt: report['is_as_built'] ?? false,
                      asBuiltReason: report['as_built_reason'],
                    );
                  },
                  onViewPunchDetail: (punchIdx) {
                    final punch =
                        (project['punch_lists'] as List? ?? const [])[punchIdx];
                    List<dynamic> passImages =
                        punch['image_paths'] ??
                        (punch['image_path'] != null
                            ? [punch['image_path']]
                            : []);
                    _showDetailModal(
                      "펀치 리스트 상세 내용",
                      punch['content'],
                      passImages,
                    );
                  },
                  onOpenCutting: () async {
                    if (project['id'] == null ||
                        project['id'].toString().trim().isEmpty) {
                      project['id'] = DateTime.now().millisecondsSinceEpoch
                          .toString();
                      _saveData(index);
                    }

                    final prefs = await SharedPreferences.getInstance();
                    final String benderType =
                        prefs.getString('benderType') ?? "수동 (Hand)";
                    final settings = await SettingsManager.loadSettings();
                    final double clr = settings['bendRadius'] ?? 0.0;
                    final double minClamp = settings['minStraight'] ?? 0.0;

                    if (!context.mounted) return;

                    if (benderType == "전동 (Electric)") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          // 🚀 전동 워크스페이스 호출
                          builder: (context) => electric.ElectricBendingWorkspace(
                            startDir: 'RIGHT',
                            clr: clr,
                            minClampLength: minClamp,
                            onSaveCallback:
                                (
                                  double tubeLengthMm,
                                  List<Map<String, dynamic>> fittingsList, [
                                  List<CutRecord> cutRecords = const [],
                                ]) {
                                  setState(() {
                                    List<dynamic> currentMaterials =
                                        List<dynamic>.from(
                                          projects[index]['materials'] ?? [],
                                        );

                                    int tubeIdx = currentMaterials.indexWhere(
                                      (m) => m['type'] == 'TUBE',
                                    );
                                    if (tubeIdx >= 0) {
                                      currentMaterials[tubeIdx]['qty_mm'] =
                                          (currentMaterials[tubeIdx]['qty_mm'] ??
                                              0) +
                                          tubeLengthMm;
                                    } else {
                                      currentMaterials.add({
                                        'db_name': 'TUBE 3/8 (기본)',
                                        'type': 'TUBE',
                                        'qty_mm': tubeLengthMm,
                                      });
                                    }

                                    for (var newFit in fittingsList) {
                                      int fitIdx = currentMaterials.indexWhere(
                                        (m) =>
                                            m['db_name'] == newFit['db_name'],
                                      );
                                      if (fitIdx >= 0) {
                                        currentMaterials[fitIdx]['qty_ea'] =
                                            (currentMaterials[fitIdx]['qty_ea'] ??
                                                0) +
                                            newFit['qty'];
                                      } else {
                                        currentMaterials.add({
                                          'db_name': newFit['db_name'],
                                          'maker': newFit['maker'],
                                          'spec': newFit['spec'],
                                          'name': newFit['name'],
                                          'type': 'FITTING',
                                          'qty_ea': newFit['qty'],
                                        });
                                      }
                                    }

                                    projects[index]['materials'] =
                                        currentMaterials;
                                    _saveData(index);
                                  });
                                },
                          ),
                        ),
                      ).then((_) => _loadData());
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => manual.CuttingMainScreen(
                            project: CuttingProject(
                              id: project['id'],
                              name: project['name'] ?? '이름 없음',
                              createdAt: DateTime.now(),
                            ),
                            onSaveCallback:
                                (
                                  double tubeLengthMm,
                                  List<Map<String, dynamic>> fittingsList, [
                                  List<CutRecord> cutRecords = const [],
                                ]) {
                                  setState(() {
                                    List<dynamic> currentMaterials =
                                        List<dynamic>.from(
                                          projects[index]['materials'] ?? [],
                                        );

                                    int tubeIdx = currentMaterials.indexWhere(
                                      (m) => m['type'] == 'TUBE',
                                    );
                                    if (tubeIdx >= 0) {
                                      currentMaterials[tubeIdx]['qty_mm'] =
                                          (currentMaterials[tubeIdx]['qty_mm'] ??
                                              0) +
                                          tubeLengthMm;
                                    } else {
                                      currentMaterials.add({
                                        'db_name': 'TUBE 3/8 (기본)',
                                        'type': 'TUBE',
                                        'qty_mm': tubeLengthMm,
                                      });
                                    }

                                    for (var newFit in fittingsList) {
                                      int fitIdx = currentMaterials.indexWhere(
                                        (m) =>
                                            m['db_name'] == newFit['db_name'],
                                      );
                                      if (fitIdx >= 0) {
                                        currentMaterials[fitIdx]['qty_ea'] =
                                            (currentMaterials[fitIdx]['qty_ea'] ??
                                                0) +
                                            newFit['qty'];
                                      } else {
                                        currentMaterials.add({
                                          'db_name': newFit['db_name'],
                                          'maker': newFit['maker'],
                                          'spec': newFit['spec'],
                                          'name': newFit['name'],
                                          'type': 'FITTING',
                                          'qty_ea': newFit['qty'],
                                        });
                                      }
                                    }

                                    projects[index]['materials'] =
                                        currentMaterials;
                                    _saveData(index);
                                  });
                                },
                          ),
                        ),
                      ).then((_) => _loadData());
                    }
                  },
                );
              },
            ),
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
}
