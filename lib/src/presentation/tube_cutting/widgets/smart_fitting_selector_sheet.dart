import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/fitting_item.dart';
import '../cutting_theme.dart';
import '../cutting_fitting_favorites.dart';

const Color pureWhite = CuttingColors.surface;
const Color makitaTeal = CuttingColors.primary;
const Color textDark = CuttingColors.textPrimary;

// 🚀 [전면 재구성] 예전엔 "대분류 선택 → 상세종류 선택 → 목록"의 3단계를
// 거쳐야 겨우 부속을 찾을 수 있었고, 이름이 아니라 분류 체계를 먼저
// 알아야 했다(예: "니들밸브"가 "볼/니들"에 속하는지 미리 알아야 함).
// 검색창 하나로 이름/분류를 바로 찾고, 분류는 평평한 칩 한 줄로 눌러서
// 바로 필터링되게 단순화했다. 검색어가 있으면 칩 필터는 무시하고
// 이름/분류 전체에서 찾는다.
// 🚀 [입력 고도화 3번] 매번 규격/분류를 다시 뒤지지 않도록 "즐겨찾기"와
// "최근 사용"을 기기에 저장해두고 목록 맨 위에서 바로 고를 수 있게 했다.
class SmartFittingSelectorSheet extends StatefulWidget {
  final String maker;

  const SmartFittingSelectorSheet({super.key, required this.maker});

  static Future<FittingItem?> show(BuildContext context, String maker) {
    return showModalBottomSheet<FittingItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SmartFittingSelectorSheet(maker: maker),
    );
  }

  @override
  State<SmartFittingSelectorSheet> createState() =>
      _SmartFittingSelectorSheetState();
}

class _SmartFittingSelectorSheetState extends State<SmartFittingSelectorSheet> {
  String selectedSize = "1/2";
  String selectedCategory = "전체";
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  static const String _kRecentsKey = 'cutting_recent_fittings_v1';
  static const int _kMaxRecents = 8;
  List<FittingItem> _favorites = [];
  List<FittingItem> _recents = [];

  final List<String> allSizes = [
    "1/4",
    "3/8",
    "1/2",
    "3/4",
    "1",
    "8mm",
    "10mm",
    "12mm",
    "20mm",
    "25mm",
  ];

  // 🚀 평평한 분류 칩 - 값이 null이면 "전체"(필터 없음), 아니면 해당
  // category 코드 목록과 매칭한다.
  final Map<String, List<String>?> categoryFilters = {
    '전체': null,
    '유니온류': [
      'UNI',
      'BLK_UNI',
      'EL90',
      'EL45',
      'TEE',
      'CRS',
      'RED',
      'PORT_CONN',
      'ADAPTER',
    ],
    '커넥터류': [
      'M_CONN',
      'F_CONN',
      'M_EL90',
      'F_EL90',
      'M_RUN_TEE',
      'F_RUN_TEE',
      'M_BRN_TEE',
      'F_BRN_TEE',
    ],
    '어저스트류': ['ADJ_EL90', 'ADJ_RUN_TEE', 'ADJ_BRN_TEE'],
    '마감류': ['CAP', 'PLUG'],
    '볼/니들': ['V_BALL', 'V_NEEDLE', 'V_MANI', 'V_BLEED'],
    '체크/릴리프': ['V_CHECK', 'V_RELIEF'],
    '플랜지': ['FL_150', 'FL_300', 'FL_600'],
    '특수부속': ['ORI', 'FIL_IN', 'FIL_TEE', 'QC'],
  };

  @override
  void initState() {
    super.initState();
    _loadExtras();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _fittingKey(FittingItem item) =>
      "${item.maker}|${item.tubeOD}|${item.category}|${item.name}";

  Future<void> _loadExtras() async {
    final prefs = await SharedPreferences.getInstance();
    final favStr = prefs.getString(kFavoriteFittingsPrefsKey);
    final recStr = prefs.getString(_kRecentsKey);
    if (!mounted) return;
    setState(() {
      if (favStr != null) {
        _favorites = (jsonDecode(favStr) as List)
            .map((e) => fittingItemFromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (recStr != null) {
        _recents = (jsonDecode(recStr) as List)
            .map((e) => fittingItemFromJson(e as Map<String, dynamic>))
            .toList();
      }
    });
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kFavoriteFittingsPrefsKey,
      jsonEncode(_favorites.map(fittingItemToJson).toList()),
    );
  }

  Future<void> _saveRecents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kRecentsKey,
      jsonEncode(_recents.map(fittingItemToJson).toList()),
    );
  }

  bool _isFavorite(FittingItem item) =>
      _favorites.any((f) => _fittingKey(f) == _fittingKey(item));

  void _toggleFavorite(FittingItem item) {
    setState(() {
      if (_isFavorite(item)) {
        _favorites.removeWhere((f) => _fittingKey(f) == _fittingKey(item));
      } else {
        _favorites.insert(0, item);
      }
    });
    _saveFavorites();
  }

  void _recordRecentAndPop(FittingItem item) {
    _recents.removeWhere((f) => _fittingKey(f) == _fittingKey(item));
    _recents.insert(0, item);
    if (_recents.length > _kMaxRecents) {
      _recents = _recents.sublist(0, _kMaxRecents);
    }
    _saveRecents();
    Navigator.of(context).pop(item);
  }

  // 🚀 [부속 검색 팝업 고도화] 예전엔 DB에 없는 부속을 쓰려면 일단 아무
  // 기성 부속이나 골라 화면을 닫은 뒤, 연필 아이콘으로 다시 바꿔야만
  // 커스텀 입력이 가능했다. 팝업 안에서 바로 "커스텀으로 입력"을 고를
  // 수 있게, 호출한 화면이 알아볼 수 있는 신호값을 돌려준다.
  void _requestCustomFitting() {
    Navigator.of(context).pop(
      FittingItem(
        id: kCustomFittingRequestId,
        maker: widget.maker,
        tubeOD: '',
        category: 'CUSTOM',
        name: '커스텀 부속',
        deduction: 0.0,
        icon: Icons.extension,
      ),
    );
  }

  Widget _buildCustomEntryRow() {
    return InkWell(
      onTap: _requestCustomFitting,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        color: CuttingColors.background,
        child: const Row(
          children: [
            Icon(Icons.edit_note_rounded, size: 16, color: makitaTeal),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                "찾는 부속이 없나요? 커스텀으로 직접 입력",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: makitaTeal,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 16, color: makitaTeal),
          ],
        ),
      ),
    );
  }

  // 🚀 검색어와 일치하는 부분을 굵게/색으로 강조해서, 왜 이 항목이
  // 검색 결과에 걸렸는지 눈으로 바로 확인할 수 있게 한다.
  Widget _highlightedTitle(String text, TextStyle style) {
    if (_searchQuery.isEmpty) {
      return Text(text, overflow: TextOverflow.ellipsis, style: style);
    }
    final lowerText = text.toLowerCase();
    final lowerQuery = _searchQuery.toLowerCase();
    final idx = lowerText.indexOf(lowerQuery);
    if (idx < 0) {
      return Text(text, overflow: TextOverflow.ellipsis, style: style);
    }
    return RichText(
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + _searchQuery.length),
            style: const TextStyle(
              color: makitaTeal,
              backgroundColor: CuttingColors.warningSoft,
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(text: text.substring(idx + _searchQuery.length)),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: makitaTeal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: makitaTeal.withValues(alpha: 0.5)),
      ),
      child: Text(
        category.replaceAll('_', '\n'),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: category.length > 4 ? 9 : 12,
          fontWeight: FontWeight.w900,
          color: makitaTeal,
          height: 1.1,
        ),
      ),
    );
  }

  // 🚀 [팝업 UI 고도화] GestureDetector는 눌러도 물결(ripple) 반응이
  // 없어서 다른 화면의 버튼들과 손맛이 달랐다. Material+InkWell로 바꿔
  // 눌렀을 때 자연스러운 리플이 뜨게 하고, 선택 색 전환도
  // AnimatedContainer로 부드럽게 했다.
  Widget _buildSizeButton(String size) {
    bool isSelected = selectedSize == size;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => selectedSize = size),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? makitaTeal : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? makitaTeal : Colors.transparent,
              ),
            ),
            child: Text(
              size,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSelected ? pureWhite : textDark,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label) {
    bool isSelected = selectedCategory == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => selectedCategory = label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? makitaTeal : pureWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? makitaTeal : Colors.grey.shade300,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? pureWhite : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🚀 즐겨찾기/최근 사용 칩 - 목록을 훑을 필요 없이 눌러서 바로 확정한다.
  Widget _buildQuickPickChip(FittingItem item, {required bool isFavorite}) {
    final Color accent = isFavorite ? CuttingColors.warning : makitaTeal;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _recordRecentAndPop(item),
        child: Container(
          width: 128,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "${item.tubeOD} · -${item.deduction}mm",
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickPickSection() {
    final favs = _favorites.where((f) => f.maker == widget.maker).toList();
    final recents = _recents.where((f) => f.maker == widget.maker).toList();
    if (_searchQuery.isNotEmpty || (favs.isEmpty && recents.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (favs.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: CuttingColors.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  "즐겨찾기",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: favs
                  .map((f) => _buildQuickPickChip(f, isFavorite: true))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (recents.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  "최근 사용",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: recents
                  .map((f) => _buildQuickPickChip(f, isFavorite: false))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  // 🚀 [팝업 통일감] 재단 최적화 시트와 같은 흰 배경 + 원형 아이콘 헤더 +
  // 닫기 버튼 형식으로 바꿨다. 예전엔 이 팝업만 진한 틸 색 헤더 블록을
  // 따로 써서, 같은 앱 안에서도 팝업마다 인상이 달랐다. DraggableScroll
  // -ableSheet로도 바꿔서 다른 시트들처럼 화면 크기에 맞게 늘어난다.
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: pureWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: [
                      cuttingDialogIcon(Icons.search_rounded),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          "${widget.maker} 부속 검색",
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textDark,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.grey,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  // 🚀 [추가] 검색창 - 분류 체계를 몰라도 이름으로 바로 찾는다.
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim()),
                    style: const TextStyle(color: textDark, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: "부속 이름으로 검색 (예: 볼밸브, 유니온)",
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      prefixIcon: const Icon(Icons.search, color: makitaTeal),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = "");
                              },
                            ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                _buildQuickPickSection(),

                Padding(
                  padding: const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    bottom: 8,
                  ),
                  child: Text(
                    "규격",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: allSizes.map((s) => _buildSizeButton(s)).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // 🚀 검색 중일 땐 분류 칩이 의미가 없으므로(검색이 우선) 숨긴다.
                if (_searchQuery.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: 8,
                    ),
                    child: Text(
                      "분류",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: categoryFilters.keys
                          .map((label) => _buildCategoryChip(label))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                const Divider(
                  height: 1,
                  thickness: 2,
                  color: Color(0xFFEEEEEE),
                ),
                _buildCustomEntryRow(),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    // 🚀 group/category는 더 이상 서버 쿼리로 나누지 않고
                    // maker+tubeOD만 가져온 뒤 검색어/분류칩은 클라이언트에서
                    // 필터링한다 (한 규격당 데이터 양이 적어 충분히 가볍다).
                    stream: FirebaseFirestore.instance
                        .collection('fittings')
                        .where('maker', isEqualTo: widget.maker)
                        .where('tubeOD', isEqualTo: selectedSize)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: makitaTeal),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 40,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "이 규격에 등록된 부속 데이터가 없습니다.",
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: _requestCustomFitting,
                                  icon: const Icon(
                                    Icons.edit_note_rounded,
                                    color: makitaTeal,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    "커스텀으로 직접 입력",
                                    style: TextStyle(color: makitaTeal),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: makitaTeal),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      var allDocs = snapshot.data!.docs;
                      var filteredDocs = allDocs.where((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        String cat = (data['category'] ?? '').toString();
                        String name =
                            (data['displayName'] ?? data['name'] ?? '')
                                .toString();

                        if (_searchQuery.isNotEmpty) {
                          final q = _searchQuery.toLowerCase();
                          return name.toLowerCase().contains(q) ||
                              cat.toLowerCase().contains(q);
                        }

                        final codes = categoryFilters[selectedCategory];
                        if (codes == null) return true; // '전체'
                        return codes.contains(cat);
                      }).toList();

                      if (filteredDocs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 40,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? "'$_searchQuery' 검색 결과가 없습니다."
                                      : "선택한 분류에 해당하는 부속이 없습니다.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: _requestCustomFitting,
                                  icon: const Icon(
                                    Icons.edit_note_rounded,
                                    color: makitaTeal,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    "커스텀으로 직접 입력",
                                    style: TextStyle(color: makitaTeal),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: makitaTeal),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // 🚀 몇 개가 걸렸는지 목록을 스크롤하지 않고도 바로 알
                      // 수 있게, 결과 개수를 목록 위에 작게 표시한다.
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "${filteredDocs.length}개 결과",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: filteredDocs.length,
                              itemBuilder: (context, index) {
                                final doc = filteredDocs[index];
                                var data = doc.data() as Map<String, dynamic>;
                                final rawId = data['id'] as String?;

                                FittingItem item = FittingItem(
                                  id: (rawId != null && rawId.isNotEmpty)
                                      ? rawId
                                      : doc.id,
                                  tubeOD: data['tubeOD'] ?? '',
                                  category: data['category'] ?? '',
                                  name:
                                      data['displayName'] ?? data['name'] ?? '',
                                  maker: data['maker'] ?? '',
                                  deduction:
                                      (data['deduction'] as num?)?.toDouble() ??
                                      0.0,
                                  icon: Icons.settings,
                                );
                                final bool fav = _isFavorite(item);

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: pureWhite,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.only(
                                      left: 16,
                                      right: 8,
                                      top: 4,
                                      bottom: 4,
                                    ),
                                    leading: _buildCategoryBadge(item.category),
                                    title: _highlightedTitle(
                                      item.name,
                                      const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: textDark,
                                      ),
                                    ),
                                    subtitle: Text(
                                      "${item.maker} | ${item.tubeOD}  ·  -${item.deduction}mm",
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(
                                        fav
                                            ? Icons.star_rounded
                                            : Icons.star_border_rounded,
                                        color: fav
                                            ? CuttingColors.warning
                                            : Colors.grey.shade400,
                                      ),
                                      onPressed: () => _toggleFavorite(item),
                                    ),
                                    onTap: () => _recordRecentAndPop(item),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
