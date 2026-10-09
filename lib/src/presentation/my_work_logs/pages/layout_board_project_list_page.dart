import 'package:tubing_calculator/src/core/common_widgets/snack_once.dart';
import 'package:tubing_calculator/src/core/utils/quick_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/korean_text.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:tubing_calculator/src/core/common_widgets/swipe_to_delete.dart';
import 'package:tubing_calculator/src/presentation/common/app_icons.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/models/layout_board_owner.dart';
import 'package:tubing_calculator/src/presentation/my_work_logs/pages/layout_board_page.dart';
import 'package:tubing_calculator/src/presentation/trash/trash_kinds.dart';
import 'package:tubing_calculator/src/core/utils/error_text.dart';

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

/// 목록에 보여 줄 배치도만 골라 최근 고친 순으로 늘어놓는다.
/// 만든 사람 칸이 없는 예전 배치도는 그대로 보이고, 칸이 있으면 내 것만 보인다.
List<LayoutListEntry> visibleLayoutEntries(
  List<LayoutListEntry> all,
  LayoutOwner me,
) {
  DateTime sortKey(LayoutListEntry d) {
    final ts =
        (d.data['updatedAt'] as Timestamp?) ??
        (d.data['createdAt'] as Timestamp?);
    return ts?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  final list = all.where((e) => layoutVisibleTo(e.data, me)).toList();
  list.sort((a, b) => sortKey(b).compareTo(sortKey(a)));
  return list;
}

class LayoutBoardProjectListPage extends StatefulWidget {
  // 테스트에서 서버 없이 목록을 그려 보려고 넣는 자리. 앱에서는 비워 두면
  // 서버의 layouts 모음을 그대로 읽는다.
  final Stream<List<LayoutListEntry>>? entries;

  // 테스트에서 "나"를 정해 넣는 자리. 비워 두면 로그인 정보와 프로필 이름을 읽는다.
  final LayoutOwner? owner;

  const LayoutBoardProjectListPage({super.key, this.entries, this.owner});

  @override
  State<LayoutBoardProjectListPage> createState() =>
      _LayoutBoardProjectListPageState();
}

class _LayoutBoardProjectListPageState
    extends State<LayoutBoardProjectListPage> {
  LayoutOwner? _me;
  late final Stream<List<LayoutListEntry>> _stream = _entryStream();

  @override
  void initState() {
    super.initState();
    if (widget.owner != null) {
      _me = widget.owner;
    } else {
      loadLayoutOwner().then((me) {
        if (mounted) setState(() => _me = me);
      });
    }
  }

  Stream<List<LayoutListEntry>> _entryStream() {
    return widget.entries ??
        FirebaseFirestore.instance
            .collection(kLayoutsCollection)
            .snapshots()
            .map(
              (snap) => snap.docs
                  .map((d) => LayoutListEntry(d.id, d.data()))
                  .toList(),
            );
  }

  // 새 배치도: 캐비닛(중판·측판)인지 스키드(위에서 본 평면)인지 고른다.
  Future<void> _openNew() async {
    HapticFeedback.lightImpact();
    final String? kind = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: pureWhite,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              layoutSheetRow(
                icon: Icons.dashboard_outlined,
                label: "캐비닛",
                caption: "중판·좌우 측판에 계기·전기 부품 배치",
                onTap: () => Navigator.pop(ctx, kLayoutKindCabinet),
              ),
              layoutSheetRow(
                icon: Icons.grid_on_rounded,
                label: "스키드",
                caption: "위에서 본 평면에 형강 틀·장비·JB·전선관 배치",
                onTap: () => Navigator.pop(ctx, kLayoutKindSkid),
              ),
            ],
          ),
        ),
      ),
    );
    if (kind == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LayoutBoardPage(initialKind: kind)),
    );
  }

  void _openProject(String docId) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LayoutBoardPage(projectId: docId)),
    );
  }

  // 🚀 [신규] 비슷한 현장을 새로 시작할 때 처음부터 다시 배치하지 않고,
  // 기존에 저장해둔 배치도를 그대로 복제해서 이름만 바꿔 시작할 수 있게.
  // 복제본은 새로 만드는 배치도라서 만든 사람을 "나"로 적는다.
  Future<void> _duplicateProject(String docId) async {
    // 통신이 약하면 끝없이 기다리고, 다시 누르면 사본이 여럿 생겼다(10-08). 읽기는 폰 사본으로 넘어가고
    // 쓰기는 폰에 적힌 뒤 8초까지만 기다린다.
    if (_duplicating) return;
    _duplicating = true;
    HapticFeedback.mediumImpact();
    try {
      final ref = FirebaseFirestore.instance.collection(kLayoutsCollection).doc(docId);
      final snap = await readDocQuick(ref, wait: const Duration(seconds: 5));
      final data = snap.data();
      if (data == null) return;
      final String rawName = (data['projectName'] as String?) ?? "";
      final String baseName = rawName.trim().isNotEmpty ? rawName : "이름 없는 배치도";
      final LayoutOwner me = _me ?? await loadLayoutOwner();
      final newRef = FirebaseFirestore.instance
          .collection(kLayoutsCollection)
          .doc();
      await newRef.set({
        ...(Map<String, dynamic>.from(data)
          ..remove(kLayoutOwnerUidField)
          ..remove(kLayoutOwnerNameField)),
        ...layoutOwnerFields(me),
        'projectId': newRef.id,
        'projectName': "$baseName (복사본)",
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 8), onTimeout: () {});
      if (mounted) {
        showSnackOnce(ScaffoldMessenger.of(context),
          SnackBar(
            content: Text(keepWords("배치도를 복제했습니다.")),
            backgroundColor: tossBlue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showSnackOnce(ScaffoldMessenger.of(context),
          SnackBar(
            content: Text(keepWords(failText("복제하지 못했습니다", e))),
            backgroundColor: warningRed,
          ),
        );
      }
    } finally {
      _duplicating = false;
    }
  }

  bool _duplicating = false;

  void _showItemActions(String docId, String name) {
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
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
              layoutSheetRow(
                icon: Icons.copy_rounded,
                label: "복제하기",
                onTap: () {
                  Navigator.pop(ctx);
                  _duplicateProject(docId);
                },
              ),
              const Divider(height: 1, indent: 20, endIndent: 20),
              layoutSheetRow(
                icon: Icons.delete_outline_rounded,
                label: "삭제하기",
                danger: true,
                onTap: () {
                  Navigator.pop(ctx);
                  _removeProject(docId, name);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // 밀어서 지운 줄은 서버 목록이 따라오기 전에 바로 빠져야 해서 여기 적어 둔다.
  final Set<String> _hiddenIds = {};

  // 배치도를 휴지통으로 옮긴다(30일 보관). 목록에서는 바로 빼고 "되돌리기"를 누르면
  // 휴지통에서 같은 아이디로 되살린다(10-02). 통신이 없어도 폰에 먼저 반영된다.
  void _removeProject(String docId, String name) {
    setState(() => _hiddenIds.add(docId));
    // 서버가 준비 안 됐을 때 나는 오류도 아래 onError로 받는다.
    final done = Future.sync(() => trashFirestoreDoc(
      kind: TrashKind.layout,
      title: name,
      ref: FirebaseFirestore.instance.collection(kLayoutsCollection).doc(docId),
    ));
    onTrashFailed(done, () {
      if (!mounted) return;
      setState(() => _hiddenIds.remove(docId));
      showSnackOnce(ScaffoldMessenger.of(context),
        SnackBar(
          content: Text(keepWords("삭제하지 못했습니다. 통신을 확인하십시오.")),
          backgroundColor: warningRed,
        ),
      );
    });
    showTrashUndo(context, name, done, onRestored: () async {
      if (mounted) setState(() => _hiddenIds.remove(docId));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tossBg,
      appBar: AppBar(
        backgroundColor: tossBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 60,
        title: const Text(
          "작업 배치도",
          style: TextStyle(
            color: tossText,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: tossText, size: 26),
      ),
      body: StreamBuilder<List<LayoutListEntry>>(
        // 🚀 [주의] updatedAt으로 orderBy를 걸면, 이 필드가 아직 없는
        // (이번 기능 이전에 저장된) 문서는 Firestore가 결과에서 통째로
        // 빼버린다. 그래서 정렬 없이 다 가져온 뒤 클라이언트에서
        // updatedAt(없으면 createdAt) 기준으로 정렬한다.
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  keepWords("목록을 불러오지 못했습니다.\n${snapshot.error}"),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: tossSubText, fontSize: 15),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting ||
              _me == null) {
            return const Center(
              child: CircularProgressIndicator(color: tossBlue),
            );
          }

          final docs = visibleLayoutEntries(
            snapshot.data ?? const <LayoutListEntry>[],
            _me!,
          ).where((e) => !_hiddenIds.contains(e.id)).toList();

          return Column(
            children: [
              _buildHeader(docs.length),
              Expanded(
                child: docs.isEmpty
                    ? _buildEmptyState()
                    : LayoutBuilder(
                        // 넓은 화면(태블릿·폴드)에서는 두 줄로 놓아 카드가 옆으로 너무 길어지지 않게.
                        builder: (context, box) => box.maxWidth >= 720
                            // 칸 높이를 글 길이에 맞춘다(이름이 두 줄이 되거나 글씨를 키워도 넘치지 않게).
                            ? ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  110,
                                ),
                                itemCount: (docs.length + 1) ~/ 2,
                                itemBuilder: (context, row) {
                                  final int i = row * 2;
                                  return IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(child: _buildCard(docs[i])),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: i + 1 < docs.length
                                              ? _buildCard(docs[i + 1])
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              )
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  110,
                                ),
                                itemCount: docs.length,
                                itemBuilder: (context, index) =>
                                    _buildCard(docs[index]),
                              ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNew,
        backgroundColor: tossBlue,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded, color: pureWhite, size: 26),
        label: const Text(
          "새 배치도",
          style: TextStyle(
            color: pureWhite,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  // 전선관 계산기 머리말처럼 왼쪽에 설명, 오른쪽에 큰 숫자.
  Widget _buildHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Expanded(
            child: Text(
              "내 배치도",
              style: TextStyle(
                color: tossSubText,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            "$count",
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: tossBlue,
              height: 1.0,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            "개",
            style: TextStyle(
              color: tossSubText,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
          decoration: layoutCardDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: tossBg,
                  shape: BoxShape.circle,
                ),
                child: const AppIcon(
                  AppGlyph.layout,
                  size: 40,
                  color: tossSubText,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "저장된 배치도가 없습니다",
                style: TextStyle(
                  color: tossText,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                keepWords("아래 '새 배치도'를 눌러 시작하십시오."),
                textAlign: TextAlign.center,
                style: const TextStyle(color: tossSubText, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(LayoutListEntry doc) {
    final data = doc.data;
    final String rawName = (data['projectName'] as String?) ?? "";
    final String name = rawName.trim().isNotEmpty ? rawName : "이름 없는 배치도";
    final int itemCount = (data['items'] as List?)?.length ?? 0;
    final double w = (data['panelWidth'] as num?)?.toDouble() ?? 0;
    final double h = (data['panelHeight'] as num?)?.toDouble() ?? 0;
    final DateTime? updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

    // 왼쪽으로 밀어도 지울 수 있다. 휴지통으로 가니 묻지 않고 되돌리기를 띄운다.
    return SwipeToDelete(
      itemKey: ValueKey('layout-${doc.id}'),
      radius: 18,
      bottomMargin: 12,
      onDelete: () => _removeProject(doc.id, name),
      child: _buildCardBody(doc, name, itemCount, w, h, updatedAt),
    );
  }

  Widget _buildCardBody(
    LayoutListEntry doc,
    String name,
    int itemCount,
    double w,
    double h,
    DateTime? updatedAt,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openProject(doc.id),
          onLongPress: () => _showItemActions(doc.id, name),
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: layoutCardDecoration(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tossBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const AppIcon(
                      AppGlyph.layout,
                      size: 30,
                      color: tossBlue,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: tossText,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${w.toInt()}×${h.toInt()}mm · 부품 $itemCount개",
                          style: const TextStyle(
                            color: tossSubText,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (updatedAt != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            keepWords(
                              "마지막 수정 ${updatedAt.month}/${updatedAt.day}",
                            ),
                            style: const TextStyle(
                              color: tossSubText,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 길게 누르지 않아도 복제·삭제를 열 수 있게 늘 보이는 단추.
                  IconButton(
                    tooltip: "복제·삭제",
                    constraints: const BoxConstraints(
                      minWidth: 52,
                      minHeight: 52,
                    ),
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: tossSubText,
                      size: 26,
                    ),
                    onPressed: () => _showItemActions(doc.id, name),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
