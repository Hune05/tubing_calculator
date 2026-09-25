import 'package:tubing_calculator/src/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../tube_cutting/cutting_leftovers.dart';
import '../../tube_cutting/cutting_pending_banner.dart';
import '../../tube_cutting/cutting_theme.dart'
    show showCuttingConfirmDialog, showCuttingSnack;
import '../../tube_cutting/widgets/leftover_log_page.dart';
import '../material_catalog.dart';
import 'inventory_item_page.dart';
import 'inventory_owner.dart';
import 'inventory_view_logic.dart';
import 'material_catalog_page.dart';
import 'mobile_inventory_logs_page.dart';

// 🎨 토스 스타일 색상 팔레트
const Color makitaTeal = AppColors.brand;
const Color slate900 = AppColors.text;
const Color slate600 = AppColors.textSub;
const Color slate100 = AppColors.background;
const Color pureWhite = Color(0xFFFFFFFF);
const Color warnColor = AppColors.caution; // 모자란 자재 알림
const Color warnSoft = Color(0xFFFFF3DF);

// 칩에서 잔재를 고르면 재고가 아니라 잔재 목록을 보여 준다.
// (재고와 달리 잔재는 규격과 길이만 있어서 목록 생김새가 다르다.)
const String kLeftoverCategory = 'LEFTOVER';

class MobileInventoryStatusPage extends StatefulWidget {
  final String workerName;

  const MobileInventoryStatusPage({super.key, required this.workerName});

  @override
  State<MobileInventoryStatusPage> createState() =>
      _MobileInventoryStatusPageState();
}

class _MobileInventoryStatusPageState extends State<MobileInventoryStatusPage> {
  String _searchQuery = "";
  String _selectedCategory = "ALL";
  // 켜면 최소 수량 아래로 내려간 자재만 본다.
  bool _shortOnly = false;
  // 전체·내 것·공용. 남의 개인 재고는 어느 쪽에서도 안 보인다.
  StockScope _scope = StockScope.all;
  final String? _uid = currentStockUid();
  // 🚀 [추가] 재고 줄에 그 규격 잔재를 같이 보여 준다. 예전에는 잔재를
  // 따로 골라 봐야 해서, "새로 뺄까 잔재로 될까"를 한눈에 못 봤다.
  Map<String, LeftoverSummary> _leftoverBySpec = const {};

  // 잔재 칸을 보고 있을 때 서버에서 읽어 둔 잔재.
  List<Leftover>? _leftovers;
  bool _leftoversLoading = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 재고 줄에 잔재를 같이 보여 주려고 화면을 열 때 한 번 읽어 둔다.
    _loadLeftoverSummary();
  }

  Future<void> _loadLeftoverSummary() async {
    try {
      final list = await loadLeftovers();
      if (!mounted) return;
      setState(() => _leftoverBySpec = leftoverSummaryBySpec(list));
    } catch (_) {
      // 못 읽어도 재고 보기는 그대로 된다.
    }
  }

  final CollectionReference _inventoryDb = FirebaseFirestore.instance
      .collection('inventory');

  // 칩에 보이는 글은 한글, 자재에 저장된 분류는 영문 아이디다
  // (material_catalog.dart에 둘을 짝지어 뒀다).
  final List<String> _categories = [
    "ALL",
    kLeftoverCategory,
    "CONDUIT",
    "STEEL",
    "FLEX",
    "ACC",
    "TUBE",
    "FITTING",
    "VALVE",
    "FLANGE",
    "기타",
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: pureWhite, // 전체 배경 화이트
        appBar: AppBar(
          backgroundColor: pureWhite,
          scrolledUnderElevation: 0,
          elevation: 0,
          iconTheme: const IconThemeData(color: slate900),
          centerTitle: true,
          title: const Text(
            "자재 현황",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: slate900,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.listPlus, size: 26),
              tooltip: '자재 목록에서 재고에 넣기',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        MaterialCatalogPage(workerName: widget.workerName),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(LucideIcons.clipboardList, size: 26),
              tooltip: '자재 기록 보기',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MobileInventoryLogsPage(),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        // 🚀 [고침] 혼자 쓰는 앱이라 불출·반납은 같은 일을 두 번 하게 만들었다.
        // "내 불출 목록" 칸을 없애고 자재 찾기만 남긴다. 재고 수량은
        // 재고조사에서 맞춘다.
        // 키보드 내리기 적용
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: _buildAllInventoryTab(),
        ),
      ),
    );
  }

  // ==========================================
  // 탭 1: 전체 자재 목록
  // ==========================================
  Widget _buildAllInventoryTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        // 🌟 검색창 (선 없이 배경색으로만)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(
              color: slate900,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            onChanged: (val) =>
                setState(() => _searchQuery = val.toLowerCase()),
            decoration: InputDecoration(
              hintText: "자재명, 규격, 위치 검색",
              hintStyle: TextStyle(color: slate600.withValues(alpha: 0.6)),
              prefixIcon: const Icon(
                LucideIcons.search,
                color: slate600,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.cancel, color: slate600, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                      },
                    )
                  : null,
              filled: true,
              fillColor: slate100,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 내 재고·공용 재고 가르기
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              for (final s in StockScope.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: Key('scope_${s.name}'),
                    label: Text(stockScopeLabel(s)),
                    labelStyle: TextStyle(
                      color: _scope == s ? pureWhite : slate600,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    selected: _scope == s,
                    selectedColor: makitaTeal,
                    backgroundColor: slate100,
                    showCheckmark: false,
                    side: BorderSide.none,
                    onSelected: (_) => setState(() => _scope = s),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 🌟 카테고리 칩 (가로 스크롤, 그림자 제거)
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    cat == "ALL"
                        ? "전체"
                        : (cat == kLeftoverCategory
                              ? "잔재"
                              : materialCategoryLabel(cat)),
                  ),
                  labelStyle: TextStyle(
                    color: isSelected ? pureWhite : slate600,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 14,
                  ),
                  selected: isSelected,
                  selectedColor: slate900, // 선택 시 진한 검정
                  backgroundColor: slate100, // 미선택 시 연한 회색
                  showCheckmark: false,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  onSelected: (selected) {
                    setState(() => _selectedCategory = cat);
                    if (cat == kLeftoverCategory) _loadLeftovers();
                  },
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),
        Divider(height: 1, color: slate100, thickness: 1),

        // 🌟 리스트 뷰
        Expanded(
          child: _selectedCategory == kLeftoverCategory
              ? _buildLeftoverList()
              : StreamBuilder<QuerySnapshot>(
                  stream: _inventoryDb.snapshots(includeMetadataChanges: true),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text("자재 목록을 불러오지 못했습니다. 통신을 확인하십시오."),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: slate300),
                      );
                    }

                    // 남의 개인 재고는 처음부터 뺀다.
                    final visibleDocs = snapshot.data!.docs
                        .where(
                          (d) => canSeeStock(
                            d.data() as Map<String, dynamic>,
                            _uid,
                          ),
                        )
                        .toList();

                    // 아직 서버로 못 올라간 저장이 몇 건인지(통신 없는 곳에서 고친 것).
                    final pending = visibleDocs
                        .where((d) => d.metadata.hasPendingWrites)
                        .length;

                    // 최소 수량 아래로 내려간 자재가 몇 개인지(칸을 가리지 않고 센다).
                    final shortCount = visibleDocs
                        .where(
                          (d) => isShortStock(d.data() as Map<String, dynamic>),
                        )
                        .length;

                    List<DocumentSnapshot> filteredDocs = visibleDocs.where((
                      doc,
                    ) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (!matchesStockScope(data, _uid, _scope)) return false;
                      bool categoryMatch =
                          _selectedCategory == "ALL" ||
                          data['category'] == _selectedCategory;
                      String target =
                          "${data['name']} ${inventorySpecOf(data)} ${data['location']}"
                              .toLowerCase();
                      if (_shortOnly && !isShortStock(data)) return false;
                      return categoryMatch && target.contains(_searchQuery);
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return Column(
                        children: [
                          PendingWritesBanner(count: pending),
                          if (shortCount > 0) _shortBar(shortCount),
                          const Expanded(
                            child: Center(
                              child: Text(
                                "찾는 자재가 없습니다.",
                                style: TextStyle(
                                  color: slate600,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    // 🚀 [고침] 잔재가 있어도 그 규격이 자재로 등록돼 있지
                    // 않으면 아무 데도 안 보였다(형강 잔재가 그렇다).
                    // 재고에 없는 잔재는 목록 끝에 따로 붙여 준다.
                    final leftoverOnly = _leftoverOnlyRows(snapshot.data!.docs);

                    return Column(
                      children: [
                        PendingWritesBanner(count: pending),
                        if (shortCount > 0) _shortBar(shortCount),
                        Expanded(
                          child: _inventoryList(filteredDocs, leftoverOnly),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  // 최소 수량 아래로 내려간 자재가 있으면 알려 주고, 그것만 보게 해 준다.
  Widget _shortBar(int count) {
    return InkWell(
      onTap: () => setState(() => _shortOnly = !_shortOnly),
      child: Container(
        width: double.infinity,
        color: _shortOnly ? warnSoft : pureWhite,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Icon(
              _shortOnly ? LucideIcons.checkSquare : LucideIcons.alertTriangle,
              size: 18,
              color: warnColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _shortOnly ? "부족한 자재만 보고 있습니다" : "자재 부족 $count개",
                style: const TextStyle(
                  color: warnColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              _shortOnly ? "모두 보기" : "이것만 보기",
              style: const TextStyle(
                color: slate600,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 재고에 등록된 자재와 짝이 없는 잔재 규격들.
  /// 검색 중이거나 다른 칸을 보고 있을 때는 보여 주지 않는다.
  List<MapEntry<String, LeftoverSummary>> _leftoverOnlyRows(
    List<DocumentSnapshot> allDocs,
  ) {
    if (_leftoverBySpec.isEmpty) return const [];
    if (_selectedCategory != "ALL" || _searchQuery.isNotEmpty) return const [];
    if (_shortOnly) return const [];

    final matched = <String>{};
    for (final d in allDocs) {
      final data = d.data() as Map<String, dynamic>?;
      final name = (data?['name'] ?? '').toString();
      for (final e in _leftoverBySpec.entries) {
        if (leftoverFor(name, {e.key: e.value}) != null) matched.add(e.key);
      }
    }
    return [
      for (final e in _leftoverBySpec.entries)
        if (!matched.contains(e.key)) e,
    ];
  }

  /// 재고에는 없고 잔재만 있는 규격 한 줄.
  Widget _leftoverOnlyRow(String spec, LeftoverSummary s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec,
                  style: const TextStyle(
                    color: slate900,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: slate100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "자재 목록에 없음",
                        style: TextStyle(
                          color: slate600,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.short,
                        key: const Key('leftover_only_row'),
                        style: const TextStyle(
                          color: makitaTeal,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inventoryList(
    List<DocumentSnapshot> filteredDocs, [
    List<MapEntry<String, LeftoverSummary>> leftoverOnly = const [],
  ]) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: filteredDocs.length + leftoverOnly.length,
      separatorBuilder: (context, index) =>
          Divider(height: 1, color: slate100, indent: 24, endIndent: 24),
      itemBuilder: (context, index) {
        if (index >= filteredDocs.length) {
          final e = leftoverOnly[index - filteredDocs.length];
          return _leftoverOnlyRow(
            e.value.label.isEmpty ? e.key : e.value.label,
            e.value,
          );
        }
        final doc = filteredDocs[index];
        final data = doc.data() as Map<String, dynamic>;

        int qty = data['qty'] ?? 0;
        String itemName = data['name'] ?? "이름 없음";
        String unit = data['unit'] ?? "EA";
        bool canCheckout = qty > 0;

        // 🌟 카드 박스 제거, 여백 위주 디자인
        // 줄을 누르면 그 자재만 보는 한 장 화면으로 간다.
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => InventoryItemPage(
                  docId: doc.id,
                  workerName: widget.workerName,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. 자재 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemName,
                        style: const TextStyle(
                          color: slate900,
                          fontSize: 18,
                          fontWeight: FontWeight.w800, // 타이틀 볼드 강조
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: canCheckout
                                  ? makitaTeal.withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "재고 $qty$unit",
                              style: TextStyle(
                                color: canCheckout
                                    ? makitaTeal
                                    : Colors.red.shade700,
                                // 🚀 [고침] 13px라 햇빛 아래서 재고 수가 잘 안 보였다.
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              inventorySpecAndPlace(data),
                              style: const TextStyle(
                                color: slate600,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (leftoverFor(itemName, _leftoverBySpec) != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          leftoverFor(itemName, _leftoverBySpec)!.short,
                          key: const Key('row_leftover'),
                          style: const TextStyle(
                            color: makitaTeal,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // 잔재 칸 (형강·튜브 컷팅에서 저장한 잔재. 서버에 있다)
  // ==========================================
  Future<void> _loadLeftovers() async {
    if (_leftoversLoading) return;
    setState(() => _leftoversLoading = true);
    try {
      final list = await loadLeftovers();
      list.sort(
        (a, b) => compareLeftoverRow(a.label, a.length, b.label, b.length),
      );
      if (!mounted) return;
      setState(() {
        _leftovers = list;
        _leftoverBySpec = leftoverSummaryBySpec(list);
        _leftoversLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _leftovers = const [];
        _leftoversLoading = false;
      });
      showCuttingSnack(context, "잔재를 불러오지 못했습니다.", isError: true);
    }
  }

  Future<void> _removeLeftover(Leftover l) async {
    final ok = await showCuttingConfirmDialog(
      context,
      title: "이 잔재를 지우겠습니까?",
      message: "${_leftoverTitle(l)}를 잔재 목록에서 지웁니다.",
      confirmLabel: "지우기",
      danger: true,
    );
    if (!ok) return;
    final all = [...(_leftovers ?? const <Leftover>[])];
    final i = l.id.isNotEmpty
        ? all.indexWhere((x) => x.id == l.id)
        : all.indexWhere((x) => x.label == l.label && x.length == l.length);
    if (i < 0) return;
    final gone = all.removeAt(i);
    try {
      // 이 잔재 하나만 뺀다(목록을 통째로 덮으면 다른 폰에서 바꾼 잔재가 사라진다).
      await leftoverStore.change(used: [gone]);
      if (!mounted) return;
      setState(() {
        _leftovers = all;
        // 자재 줄의 "잔재 있음" 표시도 같이 갱신(예전엔 지운 잔재가 계속 보였다).
        _leftoverBySpec = leftoverSummaryBySpec(all);
      });
      showCuttingSnack(context, "지웠습니다.");
    } catch (_) {
      if (!mounted) return;
      showCuttingSnack(context, "지우지 못했습니다.", isError: true);
    }
  }

  String _leftoverTitle(Leftover l) =>
      l.label.trim().isEmpty ? "규격 없음" : l.label;

  Widget _buildLeftoverList() {
    if (_leftovers == null || _leftoversLoading) {
      return const Center(child: CircularProgressIndicator(color: slate300));
    }
    final list = [
      for (final l in _leftovers!)
        if (_searchQuery.isEmpty ||
            "${l.label} ${l.length.toStringAsFixed(0)}".toLowerCase().contains(
              _searchQuery,
            ))
          l,
    ];

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: pureWhite,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  "자르고 남은 잔재입니다. 재단 계획에서 이 잔재부터 씁니다.",
                  style: TextStyle(
                    color: slate600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LeftoverLogPage(),
                  ),
                ),
                child: const Text(
                  "기록",
                  style: TextStyle(
                    color: makitaTeal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: slate100),
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Text(
                    "남은 잔재가 없습니다.",
                    style: TextStyle(
                      color: slate600,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: list.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: slate100,
                    indent: 24,
                    endIndent: 24,
                  ),
                  itemBuilder: (context, i) {
                    final l = list[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _leftoverTitle(l),
                                  style: const TextStyle(
                                    color: slate900,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "${l.length.toStringAsFixed(0)}mm",
                                  style: const TextStyle(
                                    color: makitaTeal,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '잔재 지우기',
                            icon: const Icon(
                              LucideIcons.trash2,
                              size: 20,
                              color: slate600,
                            ),
                            onPressed: () => _removeLeftover(l),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
