import 'package:tubing_calculator/src/data/ownership.dart';
import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/presentation/common/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:tubing_calculator/src/data/models/cutting_project_model.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/cutting_main_screen.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/screens/cutting_history_page.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_firestore_helper.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_pending_banner.dart';
import 'package:tubing_calculator/src/presentation/tube_cutting/cutting_theme.dart';
import 'package:tubing_calculator/src/core/utils/db_seeder.dart';

// 🚀 [신규] 컷팅 계산기용 프로젝트 목록 - 모바일 전용, Firestore 기반.
// 예전엔 (1) 데스크톱 ProjectManagementPage 안에서만 열 수 있었고 데이터도
// 폰 로컬(Hive)에만 저장돼서 폰을 바꾸면 사라졌고, (2) main.dart에 등록된
// '/cutting' 경로는 아예 메모리에만 저장해서 화면 나가면 작업 목록 자체가
// 사라지는 상태였다. 이 화면은 그 두 문제를 없애고 Firestore 컬렉션
// 'cutting_projects'에 저장해서 기기가 바뀌어도 데이터가 유지되게 한다.
class MobileCuttingProjectListPage extends StatelessWidget {
  const MobileCuttingProjectListPage({super.key});

  // 🚀 [재구성] 가운데 뜨는 AlertDialog 대신, 엄지로 바로 닿는 하단
  // 시트로 바꾸고 아이콘/여백/둥근 모서리를 요즘 모바일 앱 트렌드에
  // 맞게 다듬었다.
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
                    AppGlyph.tubeCut,
                    color: CuttingColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "새 컷팅 작업",
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
                    hintText: "예: A구역 1층 라인",
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
                // 🚀 [고침] 이름이 비었을 때 눌러도 반응이 없어 고장처럼 보였다.
                // 이름을 넣기 전에는 단추를 흐리게 하고 이유를 적는다.
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: nameCtrl,
                  builder: (context, v, _) {
                    final empty = v.text.trim().isEmpty;
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        key: const Key('new_cut_project_ok'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CuttingColors.primary,
                          disabledBackgroundColor: Colors.grey.shade300,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: empty
                            ? null
                            : () => Navigator.pop(ctx, nameCtrl.text.trim()),
                        child: Text(
                          empty ? "이름을 넣으면 만들 수 있습니다" : "만들기",
                          style: TextStyle(
                            color: empty
                                ? CuttingColors.textSecondary
                                : CuttingColors.surface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (name == null) return;

    await FirebaseFirestore.instance.collection(kCuttingProjectsCollection).add(
      {
        'name': name,
        // 새 작업은 내 것(점검 26번). 예전 작업은 주인이 없어 공용으로 보인다.
        ...ownerFieldsFor(shared: false, uid: currentUid()),
        'createdAt': DateTime.now().toIso8601String(),
        'totalTubeUsed': 0.0,
        'cutCount': 0,
        'usedFittings': <String, int>{},
      },
    );
  }

  Future<void> _deleteProject(BuildContext context, String docId) async {
    final confirmed = await showCuttingConfirmDialog(
      context,
      title: "작업 삭제",
      message: "이 컷팅 작업과 저장된 컷팅 기록을 모두 삭제하시겠습니까? 되돌릴 수 없습니다.",
      confirmLabel: "삭제",
      danger: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed) {
      await deleteCuttingProjectWithRecords(docId);
      if (context.mounted) {
        showCuttingSnack(context, "작업을 삭제했습니다.");
      }
    }
  }

  // 🚀 [신규] 롱프레스로 바로 삭제 확인창이 뜨던 걸 하단 액션 시트로 바꿔서,
  // 삭제 말고도 "컷팅 기록 보기"와 "재고 차감"(2번 강화 항목)까지 한 곳에서
  // 고를 수 있게 했다.
  void _showItemActions(
    BuildContext context,
    String docId,
    CuttingProject project,
    Map<String, dynamic> data,
  ) {
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
                  project.name,
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
                  Icons.history_rounded,
                  color: CuttingColors.primary,
                ),
                title: const Text(
                  "컷팅 기록 보기",
                  style: TextStyle(
                    color: CuttingColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CuttingHistoryPage(project: project),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const AppIcon(
                  AppGlyph.stockOut,
                  color: CuttingColors.primary,
                ),
                title: const Text(
                  "재고에서 빼기",
                  style: TextStyle(
                    color: CuttingColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  deductCuttingProjectInventory(
                    context: context,
                    projectId: docId,
                    projectName: project.name,
                  );
                },
              ),
              if (currentUid() != null)
                ListTile(
                  leading: Icon(
                    isSharedDoc(data)
                        ? Icons.person_outline_rounded
                        : Icons.groups_outlined,
                    color: CuttingColors.primary,
                  ),
                  title: Text(
                    isSharedDoc(data) ? "내 것으로 가져오기" : "공용으로 돌리기",
                    style: const TextStyle(
                      color: CuttingColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    isSharedDoc(data) ? "나만 보고 고칩니다" : "이 앱을 쓰는 모두가 보고 고칩니다",
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      final shared = await toggleSharedDoc(
                        FirebaseFirestore.instance
                            .collection(kCuttingProjectsCollection)
                            .doc(docId),
                        data,
                      );
                      if (context.mounted) {
                        showCuttingSnack(
                          context,
                          shared ? "공용으로 돌렸습니다." : "내 것으로 가져왔습니다.",
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        showCuttingSnack(context, "바꾸지 못했습니다.", isError: true);
                      }
                    }
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

  void _openProject(
    BuildContext context,
    String docId,
    CuttingProject project,
  ) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CuttingMainScreen(
          project: project,
          // 🚀 CuttingMainScreen이 '완료' 시점에 project 객체(totalTubeUsed/
          // cutCount/usedFittings)를 메모리상에서 먼저 갱신해두므로, 여기서는
          // 그 최신 상태를 그대로 Firestore 문서에 덮어쓰기만 하면 된다.
          // 🚀 [추가] cutRecords는 이번 "완료" 한 번에 실제로 잘린 구간들 -
          // 서브컬렉션에 하나씩 남겨서 "컷팅 기록" 화면에서 날짜별로
          // 되짚어볼 수 있게 한다.
          askTubeStockOnSave: true,
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
                ).catchError((e) {
                  if (context.mounted) {
                    showCuttingSnack(
                      context,
                      "저장하지 못했습니다. 통신을 확인하십시오.",
                      isError: true,
                    );
                  }
                });
              },
          // 저장 직후 "실행 취소": 저장한 사용량·기록을 되돌린다(화면이 메모리 값은 이미 뺐다).
          onUndoCallback:
              (
                double totalTubeLength,
                List<Map<String, dynamic>> fittingsList,
                List<CutRecord> cutRecords,
              ) {
                undoCuttingSession(
                  projectId: docId,
                  project: project,
                  totalTubeLength: totalTubeLength,
                  fittingsList: fittingsList,
                  cutRecords: cutRecords,
                ).catchError((e) {
                  if (context.mounted) {
                    showCuttingSnack(
                      context,
                      "되돌리지 못했습니다. 통신을 확인하십시오.",
                      isError: true,
                    );
                  }
                });
              },
        ),
      ),
    );
  }

  // 🚀 [피팅 고도화] 데스크톱 스플래시 화면에만 있던 "DB 초기화" 개발자용
  // 버튼이 폰(모바일 로딩 화면 - 자동 로그인 후 바로 통과)에서는 아예
  // 뜨지 않아서, 새 부속 카탈로그(DK-Lok/나사산/규격쌍 리듀서)를 서버에
  // 반영할 방법이 없었다. 컷팅 계산기 목록 화면 AppBar에 눈에 띄지 않는
  // 아이콘으로 같은 기능을 추가해서, 항상 손닿는 곳에서 실행할 수 있게
  // 했다.
  Future<void> _reseedFittingCatalog(BuildContext context) async {
    final confirmed = await showCuttingConfirmDialog(
      context,
      title: "부속 DB 새로고침",
      message:
          "부속 카탈로그를 최신 버전(DK-Lok 브랜드, 나사산 구분, 규격쌍 리듀서 포함)으로 다시 만듭니다. "
          "기존 부속 데이터는 전부 지워지고 새로 올라갑니다(현장에서 직접 입력한 커스텀 부속은 영향 없음). 계속하시겠습니까?",
      confirmLabel: "새로고침",
      icon: Icons.cloud_sync_outlined,
    );
    if (!confirmed) return;

    // 통신부터 확인한다. 없으면 지우기·올리기가 서버 답을 기다리느라 스피너가 안 닫혔다.
    try {
      await FirebaseFirestore.instance
          .collection('fittings')
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      if (context.mounted) {
        showCuttingSnack(
          context,
          "통신이 없어 새로고침하지 않았습니다. 통신되는 곳에서 다시 하십시오.",
          isError: true,
        );
      }
      return;
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: CuttingColors.primary),
      ),
    );

    try {
      await SmartFittingDBSeeder.uploadInitialData();
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        showCuttingSnack(context, "부속 DB를 최신 카탈로그로 새로고침했습니다.");
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        showCuttingSnack(context, "새로고침 실패: $e", isError: true);
      }
    }
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
            "튜브 컷팅 계산기",
            style: TextStyle(
              color: CuttingColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: -0.5,
            ),
          ),
          iconTheme: const IconThemeData(color: CuttingColors.textPrimary),
          actions: [
            IconButton(
              tooltip: "부속 DB 새로고침 (개발자용)",
              icon: Icon(
                Icons.cloud_sync_outlined,
                color: CuttingColors.textSecondary,
              ),
              onPressed: () => _reseedFittingCatalog(context),
            ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(kCuttingProjectsCollection)
              .orderBy('createdAt', descending: true)
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

            // 공용과 내 것만(남의 작업은 안 보인다).
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
                        AppGlyph.tubeCut,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "등록된 컷팅 작업이 없습니다.",
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

            // 통신 없는 곳에서 만든 작업이 아직 서버로 못 올라갔으면 알려 준다.
            final pending = docs
                .where((d) => d.metadata.hasPendingWrites)
                .length;

            return ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              itemCount: docs.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return PendingWritesBanner(count: pending);
                final index = i - 1;
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final project = CuttingProject.fromMap(doc.id, data);
                final lastCutAt = data['lastCutAt'] is String
                    ? DateTime.tryParse(data['lastCutAt'] as String)
                    : null;
                final pendingMaterials =
                    (data['materials'] as List?)?.length ?? 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _openProject(context, doc.id, project),
                    onLongPress: () =>
                        _showItemActions(context, doc.id, project, data),
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
                              AppGlyph.tubeCut,
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
                                  "총 절단 ${project.cutCount < 0 ? 0 : project.cutCount}회 · 소모량 ${project.estimatedMeters}m",
                                  style: const TextStyle(
                                    color: CuttingColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                if (lastCutAt != null ||
                                    pendingMaterials > 0) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      if (lastCutAt != null)
                                        Text(
                                          "마지막 작업 ${lastCutAt.month}/${lastCutAt.day}",
                                          // 🚀 [고침] 옅은 회색 11px라 안 보였다.
                                          style: const TextStyle(
                                            color: CuttingColors.textSecondary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      PendingDeductionBadge(
                                        materialCount: pendingMaterials,
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // 🚀 [고침] 기록·재고·삭제 메뉴가 길게 누르기로만 열려 있는 줄 몰랐다.
                          IconButton(
                            key: const Key('cut_project_more'),
                            tooltip: "메뉴",
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: CuttingColors.textSecondary,
                            ),
                            onPressed: () => _showItemActions(
                              context,
                              doc.id,
                              project,
                              data,
                            ),
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
