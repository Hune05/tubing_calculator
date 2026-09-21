import 'package:flutter/material.dart';
import '../widgets/korean_text.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';

const String kLayoutsCollection = 'layouts';

// 🚀 [신규] 예전엔 "작업 배치도" 메뉴를 누르면 무조건 빈 도면이 새로
// 열려서, 저장한 도면을 다시 불러볼 방법이 앱 안에 없었다(저장은 되는데
// 그 저장된 목록을 볼 화면 자체가 없었음). 이 화면이 그 목록/불러오기
// 역할을 한다.
/// 목록 한 줄에 쓰는 저장된 배치도 한 건(문서 ID + 저장된 칸 그대로).
class LayoutListEntry {
  final String id;
  final Map<String, dynamic> data;
  const LayoutListEntry(this.id, this.data);
}

class LayoutBoardProjectListPage extends StatelessWidget {
  // 테스트에서 서버 없이 목록을 그려 보려고 넣는 자리. 앱에서는 비워 두면
  // 서버의 layouts 모음을 그대로 읽는다.
  final Stream<List<LayoutListEntry>>? entries;

  const LayoutBoardProjectListPage({super.key, this.entries});

  Stream<List<LayoutListEntry>> _entryStream() {
    return entries ??
        FirebaseFirestore.instance
            .collection(kLayoutsCollection)
            .snapshots()
            .map(
              (snap) => snap.docs
                  .map((d) => LayoutListEntry(d.id, d.data()))
                  .toList(),
            );
  }

  void _openNew(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LayoutBoardPage()),
    );
  }

  void _openProject(BuildContext context, String docId) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LayoutBoardPage(projectId: docId)),
    );
  }

  // 🚀 [신규] 비슷한 현장을 새로 시작할 때 처음부터 다시 배치하지 않고,
  // 기존에 저장해둔 배치도를 그대로 복제해서 이름만 바꿔 시작할 수 있게.
  Future<void> _duplicateProject(BuildContext context, String docId) async {
    HapticFeedback.mediumImpact();
    try {
      final snap = await FirebaseFirestore.instance
          .collection(kLayoutsCollection)
          .doc(docId)
          .get();
      final data = snap.data();
      if (data == null) return;
      final String rawName = (data['projectName'] as String?) ?? "";
      final String baseName = rawName.trim().isNotEmpty ? rawName : "이름 없는 배치도";
      final newRef = FirebaseFirestore.instance
          .collection(kLayoutsCollection)
          .doc();
      await newRef.set({
        ...data,
        'projectId': newRef.id,
        'projectName': "$baseName (복사본)",
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(keepWords("배치도를 복제했습니다.")),
            backgroundColor: tossBlue,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(keepWords("복제 실패: $e")),
            backgroundColor: warningRed,
          ),
        );
      }
    }
  }

  void _showItemActions(BuildContext context, String docId, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: pureWhite,
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
                    color: tossText,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: tossBlue),
                title: const Text(
                  "복제하기",
                  style: TextStyle(
                    color: tossText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _duplicateProject(context, docId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: warningRed),
                title: const Text(
                  "삭제하기",
                  style: TextStyle(
                    color: warningRed,
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

  Future<void> _deleteProject(BuildContext context, String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "도면 삭제",
          style: TextStyle(color: tossText, fontWeight: FontWeight.bold),
        ),
        content: Text(
          keepWords("저장된 도면을 삭제하시겠습니까? 되돌릴 수 없습니다."),
          style: TextStyle(color: tossSubText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "삭제",
              style: TextStyle(color: warningRed, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection(kLayoutsCollection)
          .doc(docId)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pureWhite,
      appBar: AppBar(
        backgroundColor: pureWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text(
          "작업 배치도",
          style: TextStyle(
            color: tossText,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: tossText),
      ),
      body: StreamBuilder<List<LayoutListEntry>>(
        // 🚀 [주의] updatedAt으로 orderBy를 걸면, 이 필드가 아직 없는
        // (이번 기능 이전에 저장된) 문서는 Firestore가 결과에서 통째로
        // 빼버린다. 그래서 정렬 없이 다 가져온 뒤 클라이언트에서
        // updatedAt(없으면 createdAt) 기준으로 정렬한다.
        stream: _entryStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  keepWords("목록을 불러오지 못했습니다.\n${snapshot.error}"),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: tossSubText),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: tossBlue),
            );
          }

          final docs = [...(snapshot.data ?? <LayoutListEntry>[])];
          DateTime sortKey(LayoutListEntry d) {
            final data = d.data;
            final ts =
                (data['updatedAt'] as Timestamp?) ??
                (data['createdAt'] as Timestamp?);
            return ts?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          }

          docs.sort((a, b) => sortKey(b).compareTo(sortKey(a)));

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.dashboard_customize_outlined,
                      size: 48,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "저장된 배치도가 없습니다.",
                      style: TextStyle(color: tossSubText, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      keepWords("아래 + 버튼으로 새 배치도를 시작해 보십시오."),
                      style: TextStyle(color: tossSubText, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data;
              final String rawName = (data['projectName'] as String?) ?? "";
              final String name = rawName.trim().isNotEmpty
                  ? rawName
                  : "이름 없는 배치도";
              final int itemCount = (data['items'] as List?)?.length ?? 0;
              final double w = (data['panelWidth'] as num?)?.toDouble() ?? 0;
              final double h = (data['panelHeight'] as num?)?.toDouble() ?? 0;
              final DateTime? updatedAt = (data['updatedAt'] as Timestamp?)
                  ?.toDate();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _openProject(context, doc.id),
                  onLongPress: () => _showItemActions(context, doc.id, name),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: tossBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: tossBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.dashboard_customize_rounded,
                            color: tossBlue,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: tossText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${w.toInt()}×${h.toInt()}mm · 모듈 $itemCount개",
                                style: const TextStyle(
                                  color: tossSubText,
                                  fontSize: 13,
                                ),
                              ),
                              if (updatedAt != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  keepWords(
                                    "마지막 수정 ${updatedAt.month}/${updatedAt.day}",
                                  ),
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: tossSubText,
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
        onPressed: () => _openNew(context),
        backgroundColor: tossBlue,
        icon: const Icon(Icons.add, color: pureWhite),
        label: const Text(
          "새 배치도",
          style: TextStyle(color: pureWhite, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
