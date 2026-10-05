import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:tubing_calculator/src/core/common_widgets/swipe_to_delete.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tubing_calculator/src/data/conduit_drawings.dart';
import 'package:tubing_calculator/src/data/models/conduit_data_manager.dart';
import 'conduit_settings_page.dart'
    show globalBenderSettings, saveGlobalBenderSettings;
import 'conduit_settings_diff.dart';
import '../widgets/conduit_drawing_edit_dialog.dart';
import 'package:tubing_calculator/src/core/common_widgets/app_components.dart';
import 'package:tubing_calculator/src/core/common_widgets/save_name_chips.dart';
import 'package:tubing_calculator/src/presentation/calculator/screens/history_card_info.dart';
import 'package:tubing_calculator/src/presentation/calculator/widgets/history_folder_rename_dialog.dart';

/// 보관함에 새로 저장하면 올린다(보관함 탭이 다시 읽는다).
final ValueNotifier<int> conduitDrawingsRevision = ValueNotifier(0);

// 🎨 프리미엄 컬러 팔레트
const Color makitaTeal = AppColors.brand;
const Color slate900 = AppColors.text;
const Color slate800 = Color(0xFF1E293B);
const Color slate600 = AppColors.textSub;
const Color slate400 = Color(0xFF94A3B8); // 폴더 아이콘 색상 추가
const Color slate200 = AppColors.line;
const Color slate100 = AppColors.background;
const Color slate50 = Color(0xFFF8FAFC);
const Color pureWhite = Color(0xFFFFFFFF);
const Color warningRed = AppColors.danger;

class ConduitHistoryTab extends StatefulWidget {
  /// 불러온 뒤(입력 탭으로 옮길 때 쓴다).
  final VoidCallback? onLoaded;

  const ConduitHistoryTab({super.key, this.onLoaded});

  @override
  State<ConduitHistoryTab> createState() => _ConduitHistoryTabState();
}

class _ConduitHistoryTabState extends State<ConduitHistoryTab> {
  // 폰에 저장된 도면(화면이 쓰는 모양으로 바꿔 둔다).
  List<Map<String, dynamic>> _savedDrawings = [];
  Map<String, ConduitDrawing> _byId = {};
  final TextEditingController _search = TextEditingController();
  String _query = '';

  /// 접어 둔 작업(폴더). 검색 중에는 모두 펼친다.
  final Set<String> _collapsed = {};

  @override
  void initState() {
    super.initState();
    _reload();
    conduitDrawingsRevision.addListener(_reload);
  }

  @override
  void dispose() {
    conduitDrawingsRevision.removeListener(_reload);
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final list = await loadConduitDrawings();
    if (!mounted) return;
    setState(() {
      _byId = {for (final d in list) d.id: d};
      _savedDrawings = [
        for (final d in list)
          {
            'id': d.id,
            'folderName': d.folderName,
            'title': d.title,
            'date': d.date,
            'totalCut': d.totalCut.round(),
            'segmentCount': d.segmentCount,
            'shape': bendShapeSummary([
              for (final b in d.bends) (b['angle'] as num?)?.toDouble() ?? 0.0,
            ]),
            'notes': d.notes,
          },
      ];
    });
  }

  /// 작업 이름(폴더)의 이름을 바꾼다. 이미 있는 작업 이름으로 바꾸면 그 작업과 합쳐진다.
  /// 도면마다 저장된 작업 이름을 한 번에 고치고, "되돌리기"로 이전 이름을 되돌린다.
  Future<void> _renameFolder(String folderName, List<Map<String, dynamic>> items) async {
    final existing = {for (final e in _savedDrawings) '${e['folderName'] ?? '미분류 도면'}'};
    final others = recentDistinctNames(existing.where((k) => k != folderName), max: 8);
    final newName = await showFolderRenameDialog(
      context,
      current: folderName == '미분류 도면' ? '' : folderName,
      others: others,
    );
    if (newName == null || !mounted) return;
    final target = newName.trim();
    if (target.isEmpty || target == folderName) return;
    final merged = existing.contains(target);
    final ids = [for (final it in items) '${it['id']}'];
    try {
      await setConduitFolders({for (final id in ids) id: target});
    } catch (e) {
      debugPrint('작업 이름 바꾸기 실패: $e');
      if (mounted) {
        showAppSnack(context, '이름을 바꾸지 못했습니다. 다시 시도하십시오.', kind: AppSnackKind.error);
      }
      return;
    }
    await _reload();
    if (!mounted) return;
    showAppSnack(
      context,
      merged ? '작업을 합쳤습니다: $target (${ids.length}개)' : '작업 이름을 바꿨습니다: $target (${ids.length}개)',
      kind: AppSnackKind.undo,
      onUndo: () async {
        try {
          await setConduitFolders({for (final id in ids) id: folderName});
        } catch (e) {
          debugPrint('작업 이름 되돌리기 실패: $e');
        }
        if (mounted) await _reload();
      },
    );
  }

  /// 지금 장비 설정을 도면을 저장했을 때의 값으로 맞춘다(다른 항목만). "되돌리기"로 이전 값을 되돌린다.
  Future<void> _applySavedSettings(ConduitDrawing drawing) async {
    final now = globalBenderSettings.value;
    final changes = conduitSettingChanges(drawing.settings, now);
    if (changes.isEmpty) return;
    final previous = {for (final k in changes.keys) k: now[k]};
    globalBenderSettings.value = {...now, ...changes};
    try {
      await saveGlobalBenderSettings();
    } catch (e) {
      debugPrint('설정 저장 실패: $e');
    }
    if (!mounted) return;
    showAppSnack(
      context,
      '장비 설정을 저장 때 값으로 맞췄습니다 (${changes.length}개)',
      kind: AppSnackKind.undo,
      onUndo: () async {
        globalBenderSettings.value = {...globalBenderSettings.value, ...previous};
        try {
          await saveGlobalBenderSettings();
        } catch (e) {
          debugPrint('설정 되돌리기 실패: $e');
        }
      },
    );
  }

  /// 도면의 작업 이름·도면 이름·메모를 고친다. "되돌리기"로 이전 값을 되돌린다.
  Future<void> _editDrawing(String id) async {
    final d = _byId[id];
    if (d == null) return;
    // 추천 칩에는 지금 이 도면의 작업 이름을 빼고 다른 작업 이름만 보인다(누르나 마나라서).
    final others = recentDistinctNames(
      {
        for (final e in _savedDrawings)
          if ('${e['folderName'] ?? '미분류 도면'}' != d.folderName)
            '${e['folderName'] ?? '미분류 도면'}',
      },
      max: 8,
    );
    final info = await showConduitDrawingEditDialog(
      context,
      folderName: d.folderName,
      title: d.title,
      notes: d.notes,
      otherFolders: others,
    );
    if (info == null || !mounted) return;
    ConduitDrawing? before;
    try {
      before = await updateConduitDrawingInfo(
        id: id,
        folderName: info.folderName,
        title: info.title,
        notes: info.notes,
      );
    } catch (e) {
      debugPrint('도면 정보 고치기 실패: $e');
      if (mounted) {
        showAppSnack(context, '고치지 못했습니다. 다시 시도하십시오.', kind: AppSnackKind.error);
      }
      return;
    }
    await _reload();
    if (!mounted || before == null) return;
    final prev = before;
    showAppSnack(
      context,
      '도면 정보를 고쳤습니다',
      kind: AppSnackKind.undo,
      onUndo: () async {
        try {
          await replaceConduitDrawing(prev);
        } catch (e) {
          debugPrint('도면 정보 되돌리기 실패: $e');
        }
        if (mounted) await _reload();
      },
    );
  }

  /// 밀어서 지운 도면. 밀린 줄이 화면에 남으면 오류라 목록에서 먼저 빼고 지운다.
  void _deleteHistory(String id) async {
    final removed = _byId[id];
    setState(() => _savedDrawings.removeWhere((e) => e['id'] == id));
    await deleteConduitDrawing(id);
    await _reload();
    if (!mounted || removed == null) return;
    showDeleteUndo(
      context,
      removed.title,
      onUndo: () async {
        await restoreConduitDrawing(removed);
        await _reload();
      },
    );
  }

  // 🚀 index 대신 고유 id를 사용하여 데이터 불러오기
  void _loadHistory(String id) {
    HapticFeedback.heavyImpact();
    final targetItem = _savedDrawings.cast<Map?>().firstWhere(
      (item) => item!['id'] == id,
      orElse: () => null,
    );
    if (targetItem == null) return; // 목록이 새로 읽히는 사이 없어졌다

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pureWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "도면 불러오기",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: slate900,
          ),
        ),
        content: Text(
          "'${targetItem['title']}'을(를) 불러오면 지금 입력 목록이 이 도면으로 바뀝니다.\n(입력 탭의 ↶로 되돌릴 수 있습니다)\n고쳐서 저장할 때 이 도면에 덮어쓸 수도 있습니다.",
          style: const TextStyle(color: slate600, fontSize: 15, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: slate100,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "취소",
                    style: TextStyle(
                      color: slate600,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final drawing = _byId[id];
                    if (drawing == null) return;
                    // 🚀 [고침] 예전에는 알림만 띄우고 목록에 넣지 않았다.
                    ConduitDataManager().replaceAll(drawing.bends);
                    // 고친 뒤 저장할 때 "이 도면에 덮어쓰기"를 고를 수 있게 어느 도면인지 기억한다.
                    ConduitDataManager().setSource(drawing.id);
                    widget.onLoaded?.call();
                    // 저장 때 장비 설정과 지금 설정이 다르면 마킹이 다르게 나온다(알리기만 한다).
                    final diffs = conduitSettingDiffs(
                      drawing.settings,
                      globalBenderSettings.value,
                    );
                    if (diffs.isNotEmpty) {
                      showDialog<void>(
                        context: context,
                        builder: (dctx) => AppConfirmDialog(
                          title: '장비 설정이 다릅니다',
                          icon: const Icon(Icons.tune_rounded),
                          cancelText: '그대로 두기',
                          okText: '저장 때 설정으로',
                          okKey: const Key('conduit_diff_apply'),
                          onOk: () {
                            Navigator.pop(dctx);
                            _applySavedSettings(drawing);
                          },
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final d in diffs)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: AppConfirmDialog.message(d),
                                ),
                              const SizedBox(height: 6),
                              AppConfirmDialog.message(
                                '계산기에서는 지금 설정으로 계산하므로 마킹 자리가 저장 때와 달라집니다.\n"저장 때 설정으로"를 누르면 위 항목이 저장 때 값으로 바뀝니다(되돌릴 수 있습니다). "그대로 두기"는 설정을 바꾸지 않습니다.',
                              ),
                            ],
                          ),
                        ),
                      );
                      return;
                    }
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          "도면을 불러왔습니다. 입력 탭의 ↶로 되돌릴 수 있습니다.",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: pureWhite,
                          ),
                        ),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: makitaTeal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: makitaTeal,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "불러오기",
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
    );
  }

  // 🚀 데이터를 폴더별로 묶어주는 로직 및 Sliver 리스트 생성
  List<Widget> _buildGroupedSlivers() {
    if (_savedDrawings.isEmpty) {
      return [
        SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState()),
      ];
    }

    final q = _query.trim().toLowerCase();
    final searching = q.isNotEmpty;
    bool matches(Map<String, dynamic> e) =>
        '${e['folderName']} ${e['title']} ${e['notes']} ${e['shape']}'
            .toLowerCase()
            .contains(q);

    // 1. 데이터를 폴더별로 그룹화 (Map 형태)
    Map<String, List<Map<String, dynamic>>> groupedData = {};
    for (var item in _savedDrawings) {
      if (searching && !matches(item)) continue;
      String folder = item['folderName'] ?? '미분류 도면';
      if (!groupedData.containsKey(folder)) {
        groupedData[folder] = [];
      }
      groupedData[folder]!.add(item);
    }

    if (groupedData.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              "'${_query.trim()}'에 맞는 도면이 없습니다",
              key: const Key('conduit_search_empty'),
              style: const TextStyle(color: slate600, fontSize: 15),
            ),
          ),
        ),
      ];
    }

    List<Widget> slivers = [];

    // 2. 그룹화된 데이터를 바탕으로 UI 생성
    groupedData.forEach((folderName, items) {
      final open = searching || !_collapsed.contains(folderName);
      // 폴더 타이틀 (섹션 헤더)
      slivers.add(
        SliverToBoxAdapter(
          child: InkWell(
            key: ValueKey('conduit_folder_toggle_$folderName'),
            onTap: searching
                ? null
                : () => setState(() {
                    if (!_collapsed.remove(folderName)) _collapsed.add(folderName);
                  }),
            child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        open ? Icons.folder_open_rounded : Icons.folder_rounded,
                        color: slate400,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          folderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: slate900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: slate200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${items.length}",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: slate600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 작업 이름 바꾸기·합치기
                IconButton(
                  key: ValueKey('conduit_folder_menu_$folderName'),
                  tooltip: '작업 이름 바꾸기',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined, color: slate600, size: 20),
                  onPressed: () => _renameFolder(folderName, items),
                ),
              ],
            ),
          ),
          ),
        ),
      );

      if (!open) return;
      // 해당 폴더 내의 카드 리스트
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildTossStyleCard(items[index]),
              childCount: items.length,
            ),
          ),
        ),
      );
    });

    // 하단 여백 추가
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 120)));

    return slivers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slate100,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          _buildTossStyleHeader(),
          if (_savedDrawings.isNotEmpty) _buildSearchBox(),
          // 🚀 그룹화된 슬리버 리스트를 스프레드 연산자(...)로 펼쳐서 삽입
          ..._buildGroupedSlivers(),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: TextField(
          key: const Key('conduit_search_field'),
          controller: _search,
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: '작업 이름·도면 이름·메모 검색',
            prefixIcon: const Icon(Icons.search_rounded, color: slate400),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    key: const Key('conduit_search_clear'),
                    icon: const Icon(Icons.close_rounded, color: slate400),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
            filled: true,
            fillColor: pureWhite,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTossStyleHeader() {
    return SliverAppBar(
      expandedHeight: 140.0,
      pinned: true,
      backgroundColor: slate100,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        title: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "보관된 도면 ${_savedDrawings.length}개",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: slate900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // 🚀 [10-02] × 단추를 잘못 눌러 바로 지워지던 것을 왼쪽으로 밀어서 지우기로 바꿨다.
  Widget _buildTossStyleCard(Map<String, dynamic> item) {
    return SwipeToDelete(
      itemKey: ValueKey('conduit_history_${item['id']}'),
      radius: 24,
      bottomMargin: 16,
      onDelete: () => _deleteHistory(item['id']),
      child: _buildTossStyleCardBody(item),
    );
  }

  // 🚀 인자로 Map 자체를 받도록 수정 (id 접근 용이)
  Widget _buildTossStyleCardBody(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: pureWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: slate900.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: slate50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.architecture_rounded,
                  color: makitaTeal,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      item['title'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: slate900,
                        height: 1.3,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item['date'],
                      style: const TextStyle(
                        fontSize: 13,
                        color: slate600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['shape'] ?? '',
                      key: const Key('conduit_card_shape'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: slate600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((item['notes'] as String? ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item['notes'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: slate600,
                          fontStyle: FontStyle.italic,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('conduit_edit_${item['id']}'),
                tooltip: '도면 이름·메모 고치기',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, color: slate600, size: 20),
                onPressed: () => _editDrawing(item['id']),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: _buildInfoChip("총 절단 길이", "${item['totalCut']} mm"),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoChip("조립 구간", "${item['segmentCount']} 구간"),
              ),
            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _loadHistory(item['id']), // 🚀 고유 id 전달
              style: ElevatedButton.styleFrom(
                backgroundColor: slate100,
                foregroundColor: slate900,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "계산기로 불러오기",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: slate50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: slate600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: slate900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: pureWhite,
            ),
            child: const Icon(
              Icons.folder_off_rounded,
              size: 48,
              color: slate200,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "보관된 도면이 없습니다",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: slate900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "마킹 탭에서 작업 결과를 저장해 보십시오.",
            style: TextStyle(
              color: slate600,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
