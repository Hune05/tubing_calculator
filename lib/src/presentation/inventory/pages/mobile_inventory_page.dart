import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';
import 'package:tubing_calculator/src/presentation/inventory/pages/usage_since_count.dart';

import '../../tube_cutting/cutting_pending_banner.dart';
import '../../tube_cutting/cutting_theme.dart'
    show showCuttingConfirmDialog, showCuttingSnack;
import '../material_catalog.dart' show materialCategoryLabel;
import 'inventory_model.dart';
import 'inventory_item_card.dart';
import 'material_catalog_page.dart';
import 'mobile_inventory_ocr.dart';

part 'mobile_inventory_dialogs.dart';
part 'mobile_inventory_sync.dart';

// 🎨 미니멀 감성을 위한 색상 정의 (토스 스타일)
const Color makitaTeal = Color(0xFF007580);
const Color slate900 = Color(0xFF191F28); // 부드러운 텍스트 블랙
const Color slate600 = Color(0xFF8B95A1); // 부드러운 텍스트 그레이
const Color slate100 = Color(0xFFF2F4F6); // 은은한 배경 그레이
const Color pureWhite = Color(0xFFFFFFFF);

class MobileInventoryPage extends StatefulWidget {
  final String workerName;

  const MobileInventoryPage({super.key, required this.workerName});

  @override
  State<MobileInventoryPage> createState() => _MobileInventoryPageState();
}

class _MobileInventoryPageState extends State<MobileInventoryPage> {
  // 보고 있는 분류('ALL'이면 모두)와 찾는 글.
  String _filter = 'ALL';
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  final CollectionReference _inventoryDb = FirebaseFirestore.instance
      .collection('inventory');
  final CollectionReference _logsDb = FirebaseFirestore.instance.collection(
    'inventory_logs',
  );

  // 분류. 이름은 material_catalog.dart에 있는 한글 이름을 쓰고, 색은 앱 색
  // 하나로 맞췄다(예전에는 카테고리마다 갈색·자색으로 달랐다).
  final List<Map<String, dynamic>> _categories = const [
    {"id": "CONDUIT", "name": "전선관"},
    {"id": "STEEL", "name": "형강"},
    {"id": "FLEX", "name": "후렉시블"},
    {"id": "ACC", "name": "부속"},
    {"id": "TUBE", "name": "튜브"},
    {"id": "FITTING", "name": "피팅"},
    {"id": "VALVE", "name": "밸브"},
    {"id": "FLANGE", "name": "가스켓·후렌지"},
    {"id": "기타", "name": "기타"},
  ];

  // 다이얼로그·전송 기록이 "지금 보고 있는 분류"를 쓴다. 전체를 보고 있으면
  // 기타로 본다.
  Map<String, dynamic> get _currentCategoryInfo => _categories.firstWhere(
    (c) => c['id'] == _filter,
    orElse: () => _categories.last,
  );

  @override
  void initState() {
    super.initState();
    _loadUsage();
  }

  /// 기록을 읽어 자재별로 지난 재고조사 뒤 드나듦을 센다.
  Future<void> _loadUsage() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('inventory_logs')
          .orderBy('timestamp', descending: true)
          .limit(400)
          .get();
      if (!mounted) return;
      setState(() {
        _usage = usageSinceLastCount([for (final d in snap.docs) d.data()]);
      });
    } catch (_) {
      // 못 읽어도 재고조사는 그대로 된다.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  final Map<String, ItemData> _localEdits = {};

  /// 지난 재고조사 뒤로 자재가 얼마나 드나들었는지(자재 이름별).
  Map<String, UsageSinceCount> _usage = const {};
  final Map<String, Map<String, dynamic>> _newLocalItems = {};
  final List<Map<String, dynamic>> _historyLogs = [];

  ItemData _createItemDataFromDoc(Map<String, dynamic> docData) {
    ItemData item = ItemData();
    // 다른 기기가 소수로 적었어도 죽지 않게.
    item.qty = (docData['qty'] as num?)?.toInt() ?? 0;
    try {
      item.heatNo = docData['heatNo'] ?? '';
      item.maker = docData['maker'] ?? '';
      item.location = docData['location'] ?? '';
      item.material = docData['material'] ?? '';
      item.spec = docData['spec'] ?? docData['size'] ?? '';
      item.projectName = docData['projectName'] ?? '';
      item.department = docData['department'] ?? '';
      item.minQty = docData['minQty'] ?? docData['min_qty'] ?? 0;
    } catch (_) {}
    return item;
  }

  Future<void> recordMobileLog({
    required String itemName,
    required String action,
    required int qty,
  }) async {
    try {
      await _logsDb.add({
        'itemName': itemName,
        'action': action,
        'qty': qty,
        'workerName': widget.workerName,
        'device': 'Mobile',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("로그 저장 실패: $e");
    }
  }

  // 🚀 [정리] 예전에는 카테고리마다 한 장씩(8장) 좌우로 넘기는 구조였고 찾기가
  // 없어서, 자재가 늘어나면 원하는 줄을 찾을 수 없었다. 한 목록으로 합치고
  // 위쪽에 찾기와 분류 칩을 뒀다(자재 현황 화면과 같은 방식). 색도 카테고리마다
  // 다르게 쓰던 것을 앱 색(청록) 하나로 맞췄다.
  @override
  Widget build(BuildContext context) {
    // 센 수량은 올리기 전까지 폰 화면에만 있다. 뒤로 가기로 나가면 다 사라지므로 묻는다.
    return PopScope(
      canPop: _localEdits.isEmpty && _newLocalItems.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: pureWhite,
            title: const Text("아직 올리지 않은 수량이 있습니다"),
            content: const Text("나가면 센 수량이 사라집니다. 그래도 나가겠습니까?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("계속 세기"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("나가기", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.pop(context);
      },
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Scaffold(
      backgroundColor: pureWhite,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(),
              _searchBox(),
              _categoryChips(),
              if (_localEdits.isNotEmpty) _editedBar(),
              Divider(height: 1, color: slate100),
              Expanded(child: _auditList()),
              _sendBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: slate900),
            onPressed: () => Navigator.maybePop(context),
          ),
          const Expanded(
            child: Text(
              "재고조사",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: slate900,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: '자재 목록에서 재고에 넣기',
            icon: const Icon(LucideIcons.listPlus, color: slate900),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MaterialCatalogPage(workerName: widget.workerName),
              ),
            ),
          ),
          IconButton(
            tooltip: '여기 없는 자재 직접 넣기',
            icon: const Icon(Icons.add_circle_outline, color: slate900),
            onPressed: () =>
                _showAddNewItemDialog(_filter == 'ALL' ? '기타' : _filter),
          ),
        ],
      ),
    );
  }

  Widget _searchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(
          color: slate900,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        decoration: InputDecoration(
          hintText: "자재명, 규격, 위치 찾기",
          hintStyle: TextStyle(color: slate600.withValues(alpha: 0.6)),
          prefixIcon: const Icon(LucideIcons.search, color: slate600, size: 20),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.cancel, color: slate600, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = "");
                  },
                ),
          filled: true,
          fillColor: slate100,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _categoryChips() {
    final ids = ['ALL', for (final c in _categories) c['id'] as String];
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: ids.length,
        itemBuilder: (context, i) {
          final id = ids[i];
          final on = _filter == id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(id == 'ALL' ? '전체' : materialCategoryLabel(id)),
              labelStyle: TextStyle(
                color: on ? pureWhite : slate600,
                fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                fontSize: 14,
              ),
              selected: on,
              selectedColor: makitaTeal,
              backgroundColor: slate100,
              showCheckmark: false,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onSelected: (_) => setState(() => _filter = id),
            ),
          );
        },
      ),
    );
  }

  // 아직 서버에 올리지 않은 고친 내용을 몇 건인지 알려 주고, 한 번에 되돌린다.
  Widget _editedBar() {
    return Container(
      width: double.infinity,
      color: makitaTeal.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "고친 것 ${_localEdits.length}건. 아직 서버에 올리지 않았습니다.",
              style: const TextStyle(
                color: makitaTeal,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: _undoEdits,
            child: const Text(
              "되돌리기",
              style: TextStyle(color: slate600, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _undoEdits() async {
    final ok = await showCuttingConfirmDialog(
      context,
      title: "고친 것을 되돌리겠습니까?",
      message: "서버에 올리지 않은 ${_localEdits.length}건을 모두 되돌립니다.",
      confirmLabel: "되돌리기",
      danger: true,
    );
    if (!ok) return;
    setState(() {
      _localEdits.clear();
      _newLocalItems.clear();
    });
  }

  Widget _auditList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _inventoryDb.snapshots(includeMetadataChanges: true),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "자재 목록을 불러오지 못했습니다. 통신을 확인하십시오.",
              style: TextStyle(color: slate600),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: makitaTeal),
          );
        }

        final pending = snapshot.data!.docs
            .where((d) => d.metadata.hasPendingWrites)
            .length;

        // 서버에 있는 자재 + 이 화면에서 새로 적은 자재를 한 목록으로 합친다.
        final dbDocs = snapshot.data!.docs.where(_matchesFilter).toList()
          ..sort((a, b) {
            final ma = a.data() as Map<String, dynamic>;
            final mb = b.data() as Map<String, dynamic>;
            final ca = (ma['category'] ?? '').toString();
            final cb = (mb['category'] ?? '').toString();
            if (ca != cb) return ca.compareTo(cb);
            return (ma['name'] ?? '').toString().compareTo(
              (mb['name'] ?? '').toString(),
            );
          });

        final localNew = _newLocalItems.entries.where((e) {
          final m = Map<String, dynamic>.from(e.value);
          return _matchesMap(m);
        }).toList();

        final total = dbDocs.length + localNew.length;
        if (total == 0) {
          return Column(
            children: [
              PendingWritesBanner(count: pending),
              Expanded(child: _emptyNote()),
            ],
          );
        }

        return Column(
          children: [
            PendingWritesBanner(count: pending),
            Expanded(child: _cards(dbDocs, localNew, total)),
          ],
        );
      },
    );
  }

  Widget _emptyNote() => Center(
    child: Text(
      _searchQuery.isEmpty ? "등록된 자재가 없습니다." : "찾는 자재가 없습니다.",
      style: const TextStyle(
        color: slate600,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _cards(
    List<DocumentSnapshot> dbDocs,
    List<MapEntry<String, Map<String, dynamic>>> localNew,
    int total,
  ) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      itemCount: total,
      itemBuilder: (context, i) {
        final isLocalNew = i >= dbDocs.length;
        final String docId;
        final String itemName;
        final ItemData displayData;

        if (!isLocalNew) {
          final doc = dbDocs[i];
          docId = doc.id;
          final m = doc.data() as Map<String, dynamic>?;
          itemName = (m?['name'] ?? '이름 없음').toString();
          displayData = _localEdits[docId] ?? _createItemDataFromDoc(m ?? {});
        } else {
          final e = localNew[i - dbDocs.length];
          docId = e.key;
          itemName = (e.value['name'] ?? '이름 없음').toString();
          displayData = _localEdits[docId] ?? _createItemDataFromDoc(e.value);
        }

        final card = InventoryItemCard(
          itemName: itemName,
          data: displayData,
          usedNote: _usage[itemName.trim()]?.note ?? '',
          categoryIndex: 0,
          themeColor: makitaTeal,
          onUpdateQuantity: (delta) {
            HapticFeedback.lightImpact();
            setState(() {
              if (!_localEdits.containsKey(docId) && !isLocalNew) {
                // 목록이 바뀌는 순간 누르면 없을 수 있다(예전엔 여기서 죽었다).
                final doc = dbDocs.cast<QueryDocumentSnapshot?>().firstWhere(
                  (d) => d!.id == docId,
                  orElse: () => null,
                );
                _localEdits[docId] = _createItemDataFromDoc(
                  (doc?.data() as Map<String, dynamic>?) ?? {},
                );
              }
              final next = (_localEdits[docId]?.qty ?? 0) + delta;
              if (next >= 0) _localEdits[docId]!.qty = next;
            });
          },
          onQuantityTap: () => _showQuantityInputDialog(
            docId,
            itemName,
            displayData.qty,
            seed: () => isLocalNew
                ? null
                : _createItemDataFromDoc(
                    (dbDocs
                                .cast<QueryDocumentSnapshot?>()
                                .firstWhere(
                                  (d) => d!.id == docId,
                                  orElse: () => null,
                                )
                                ?.data()
                            as Map<String, dynamic>?) ??
                        {},
                  ),
          ),
          onExtraInfoTap: (infoType) =>
              _showExtraInfoDialog(docId, displayData, infoType),
        );

        return GestureDetector(
          onLongPress: () => _askDelete(
            docId: docId,
            itemName: itemName,
            isLocalNew: isLocalNew,
            qty: displayData.qty,
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              decoration: BoxDecoration(
                color: pureWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: slate100, width: 2),
              ),
              child: Theme(
                data: ThemeData.light().copyWith(
                  cardColor: pureWhite,
                  scaffoldBackgroundColor: pureWhite,
                  colorScheme: const ColorScheme.light(surface: pureWhite),
                ),
                child: card,
              ),
            ),
          ),
        );
      },
    );
  }

  bool _matchesFilter(DocumentSnapshot doc) =>
      _matchesMap((doc.data() as Map<String, dynamic>?) ?? {});

  bool _matchesMap(Map<String, dynamic> m) {
    if (_filter != 'ALL' && (m['category'] ?? '') != _filter) return false;
    if (_searchQuery.isEmpty) return true;
    final target =
        "${m['name'] ?? ''} ${m['spec'] ?? m['size'] ?? ''} ${m['location'] ?? ''}"
            .toLowerCase();
    return target.contains(_searchQuery);
  }

  Future<void> _askDelete({
    required String docId,
    required String itemName,
    required bool isLocalNew,
    required int qty,
  }) async {
    HapticFeedback.heavyImpact();
    final ok = await showCuttingConfirmDialog(
      context,
      title: isLocalNew ? "올릴 목록에서 지우겠습니까?" : "자재를 아주 지우겠습니까?",
      message: isLocalNew
          ? "$itemName을 올릴 목록에서 지웁니다."
          : "$itemName을 창고 목록에서 아주 지웁니다. 되돌릴 수 없습니다.",
      confirmLabel: "지우기",
      danger: true,
    );
    if (!ok) return;

    if (isLocalNew) {
      setState(() {
        _newLocalItems.remove(docId);
        _localEdits.remove(docId);
      });
      return;
    }

    try {
      await _inventoryDb.doc(docId).delete();
      if (mounted) setState(() => _localEdits.remove(docId));
      await recordMobileLog(itemName: itemName, action: '완전 삭제', qty: qty);
      if (!mounted) return;
      showCuttingSnack(context, "지웠습니다.");
    } catch (_) {
      if (!mounted) return;
      showCuttingSnack(context, "지우지 못했습니다.", isError: true);
    }
  }

  Widget _sendBar() {
    final n = _localEdits.length;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: const BoxDecoration(
          color: pureWhite,
          border: Border(top: BorderSide(color: slate100, width: 1)),
        ),
        child: SizedBox(
          height: 60,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: n == 0 ? null : _syncToServer,
            style: ElevatedButton.styleFrom(
              backgroundColor: makitaTeal,
              disabledBackgroundColor: slate100,
              disabledForegroundColor: slate600,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              n == 0 ? "고친 것이 없습니다" : "고친 것 $n건 서버에 올리기",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: n == 0 ? slate600 : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
