import 'package:tubing_calculator/src/data/ownership.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tubing_calculator/src/presentation/common/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/steel_cutting_project_model.dart';
import '../../tube_cutting/cutting_pending_banner.dart';
import '../../tube_cutting/cutting_theme.dart';
import '../steel_weight.dart';
import 'steel_cutting_detail_screen.dart';

// 🚀 [형강 컷팅 신규] 튜브 컷팅 작업 목록(mobile_cutting_project_list_page.dart)과
// 같은 형식으로 만든 형강(찬넬/앵글) 컷팅 프로젝트 목록. 재고 연동과
// 컷팅 기록(이력) 화면은 이번 범위에서 빠졌다 - 형강 재고 카테고리 자체가
// 아직 없어서, 나중에 필요해지면 튜브 쪽 cutting_firestore_helper.dart
// 패턴을 그대로 가져와 붙이면 된다.
class MobileSteelProjectListPage extends StatelessWidget {
  const MobileSteelProjectListPage({super.key});

  Future<void> _createProject(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            decoration: const BoxDecoration(
              color: CuttingColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: CuttingColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const AppIcon(
                    AppGlyph.stChannel,
                    color: CuttingColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "새 형강 컷팅 작업",
                  style: TextStyle(
                    color: CuttingColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "작업 위치나 라인 이름으로 구분해두면 나중에 찾기 편합니다",
                  style: TextStyle(
                    color: CuttingColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: const TextStyle(
                    color: CuttingColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) Navigator.pop(ctx, val.trim());
                  },
                  decoration: InputDecoration(
                    hintText: "예: A구역 프레임 제작",
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: CuttingColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: CuttingColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CuttingColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (nameCtrl.text.trim().isNotEmpty) {
                        Navigator.pop(ctx, nameCtrl.text.trim());
                      }
                    },
                    child: const Text(
                      "만들기",
                      style: TextStyle(
                        color: CuttingColors.surface,
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

    if (name == null) return;

    await FirebaseFirestore.instance
        .collection(kSteelCuttingProjectsCollection)
        .add({
          'name': name,
          ...ownerFieldsFor(shared: false, uid: currentUid()),
          'createdAt': DateTime.now().toIso8601String(),
          'stockLength': 6000.0,
          'items': <Map<String, dynamic>>[],
        });
  }

  Future<void> _renameProject(
    BuildContext context,
    String docId,
    String currentName,
  ) async {
    final ctrl = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CuttingColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            cuttingDialogIcon(Icons.edit_outlined),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                "이름 바꾸기",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: CuttingColors.textPrimary,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CuttingColors.primary,
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text(
              "저장",
              style: TextStyle(color: CuttingColors.surface),
            ),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == currentName) return;
    await FirebaseFirestore.instance
        .collection(kSteelCuttingProjectsCollection)
        .doc(docId)
        .update({'name': name});
  }

  Future<void> _deleteProject(BuildContext context, String docId) async {
    final confirmed = await showCuttingConfirmDialog(
      context,
      title: "작업 삭제",
      message: "이 형강 컷팅 작업을 삭제하시겠습니까? 되돌릴 수 없습니다.",
      confirmLabel: "삭제",
      danger: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed) {
      // 변경 이력(하위 모음)도 같이 지운다(튜브 쪽 deleteCuttingProjectWithRecords와 같게).
      final docRef = FirebaseFirestore.instance
          .collection(kSteelCuttingProjectsCollection)
          .doc(docId);
      // 🚀 [고침] 통신이 없으면 이력 읽기가 8초 뒤 오류로 끝나 작업이 안 지워졌다.
      // 폰 캐시에 있는 이력으로 지우고, 그것도 없으면 작업 문서만 지운다.
      List<QueryDocumentSnapshot<Map<String, dynamic>>> logs = const [];
      try {
        logs =
            (await docRef
                    .collection(kSteelChangeLogSubcollection)
                    .get()
                    .timeout(const Duration(seconds: 8)))
                .docs;
      } catch (_) {
        try {
          logs =
              (await docRef
                      .collection(kSteelChangeLogSubcollection)
                      .get(const GetOptions(source: Source.cache)))
                  .docs;
        } catch (_) {}
      }
      final batch = FirebaseFirestore.instance.batch();
      for (final d in logs) {
        batch.delete(d.reference);
      }
      batch.delete(docRef);
      await batch.commit().timeout(
        const Duration(seconds: 8),
        onTimeout: () {},
      );
      if (context.mounted) showCuttingSnack(context, "작업을 삭제했습니다.");
    }
  }

  void _showItemActions(BuildContext context, String docId, String name) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CuttingColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: CuttingColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.edit_outlined,
                  color: CuttingColors.primary,
                ),
                title: const Text(
                  "이름 바꾸기",
                  style: TextStyle(
                    color: CuttingColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _renameProject(context, docId, name);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  "삭제하기",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteProject(context, docId);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _openProject(BuildContext context, SteelCuttingProject project) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SteelCuttingDetailScreen(project: project),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CuttingTheme(
      child: Scaffold(
        backgroundColor: CuttingColors.surface,
        appBar: AppBar(
          backgroundColor: CuttingColors.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          title: const Text(
            "형강 컷팅 (찬넬/앵글)",
            style: TextStyle(
              color: CuttingColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: -0.5,
            ),
          ),
          iconTheme: const IconThemeData(color: CuttingColors.textPrimary),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(kSteelCuttingProjectsCollection)
              .orderBy('createdAt', descending: true)
              // 서버로 아직 못 올라간 저장이 있는지 알려면 메타데이터 변화도 받아야 한다.
              .snapshots(includeMetadataChanges: true),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    "작업 목록을 불러오지 못했습니다.\n${snapshot.error}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: CuttingColors.textSecondary),
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: CuttingColors.primary),
              );
            }

            final uid = currentUid();
            final docs = (snapshot.data?.docs ?? [])
                .where((d) => canSeeDoc(d.data() as Map, uid))
                .toList();

            if (docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(
                        AppGlyph.stChannel,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "등록된 형강 컷팅 작업이 없습니다.",
                        style: TextStyle(
                          color: CuttingColors.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "우측 하단 + 버튼으로 새 작업을 만들어 보십시오.",
                        style: TextStyle(
                          color: CuttingColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final int pending = docs
                .where((d) => d.metadata.hasPendingWrites)
                .length;

            return ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
              itemCount: docs.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return PendingWritesBanner(count: pending);
                final index = i - 1;
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final project = SteelCuttingProject.fromMap(doc.id, data);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _openProject(context, project),
                    onLongPress: () =>
                        _showItemActions(context, doc.id, project.name),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: CuttingColors.background,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: CuttingColors.primary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const AppIcon(
                              AppGlyph.stChannel,
                              color: CuttingColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  project.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: CuttingColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "항목 ${project.items.length}건 · 총 길이 "
                                  "${(project.totalLength / 1000).toStringAsFixed(1)}m",
                                  style: const TextStyle(
                                    color: CuttingColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                if (steelProjectWeightText(project).isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      steelProjectWeightText(project),
                                      key: Key(
                                        'steel_project_weight_${project.id}',
                                      ),
                                      style: const TextStyle(
                                        color: CuttingColors.primaryDark,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // 🚀 [고침] 기록·재고·삭제 메뉴가 길게 누르기로만 열려 있는 줄 몰랐다.
                          IconButton(
                            key: const Key('steel_project_more'),
                            tooltip: "메뉴",
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: CuttingColors.textSecondary,
                            ),
                            onPressed: () =>
                                _showItemActions(context, doc.id, project.name),
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
          onPressed: () => _createProject(context),
          backgroundColor: CuttingColors.primary,
          icon: const Icon(Icons.add, color: CuttingColors.surface),
          label: const Text(
            "새 작업 생성",
            style: TextStyle(
              color: CuttingColors.surface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
