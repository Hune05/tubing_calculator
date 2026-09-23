import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../tube_cutting/cutting_theme.dart';
import '../material_catalog.dart';
import 'material_catalog_store.dart';

/// 자재 목록(카탈로그) 화면. 여기서 자재를 골라 창고 재고에 넣는다.
/// 이름·규격이 현장에서 부르는 말과 다르면 길게 눌러 고칠 수 있다.
/// 밝은 테마(CuttingTheme)를 화면 위에 씌운다. 이렇게 해 두면 이 안에서 띄우는
/// 창·시트·메뉴가 모두 밝은 테마를 따라간다(앱 기본값은 어두운 테마라서,
/// 화면 안쪽에서 테마를 씌우면 창만 검게 뜬다).
class MaterialCatalogPage extends StatelessWidget {
  // 누가 넣었는지 자재 기록에 남기기 위해 이름을 받는다.
  final String workerName;
  const MaterialCatalogPage({super.key, this.workerName = ''});

  @override
  Widget build(BuildContext context) =>
      CuttingTheme(child: _CatalogBody(workerName: workerName));
}

class _CatalogBody extends StatefulWidget {
  final String workerName;
  const _CatalogBody({required this.workerName});

  @override
  State<_CatalogBody> createState() => _CatalogBodyState();
}

class _CatalogBodyState extends State<_CatalogBody> {
  final TextEditingController _search = TextEditingController();
  List<CatalogItem> _all = const [];
  final Set<String> _picked = {};
  String _category = 'ALL';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load(seedIfEmpty: true);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool seedIfEmpty = false}) async {
    setState(() => _loading = true);
    try {
      var list = await loadMaterialCatalog();
      if (list.isEmpty && seedIfEmpty) {
        final n = await seedMissingCatalog();
        list = await loadMaterialCatalog();
        if (mounted && n > 0) {
          showCuttingSnack(context, "기본 자재 목록 $n개를 채웠습니다.");
        }
      }
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showCuttingSnack(context, "자재 목록을 불러오지 못했습니다.", isError: true);
    }
  }

  List<String> get _categories {
    final ids = <String>{for (final i in _all) i.category};
    final order = kMaterialCategoryLabels.keys.toList();
    final list = ids.toList()
      ..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
    return ['ALL', ...list];
  }

  List<CatalogItem> get _shown {
    final q = _search.text.trim().toLowerCase();
    return [
      for (final i in _all)
        if (_category == 'ALL' || i.category == _category)
          if (q.isEmpty || i.searchText.contains(q)) i,
    ];
  }

  Future<void> _fillFromApp() async {
    try {
      final n = await seedMissingCatalog();
      if (!mounted) return;
      showCuttingSnack(
        context,
        n == 0 ? "더 채울 자재가 없습니다." : "자재 $n개를 목록에 채웠습니다.",
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      showCuttingSnack(context, "목록을 채우지 못했습니다.", isError: true);
    }
  }

  Future<void> _putIntoInventory() async {
    final items = [
      for (final i in _all)
        if (_picked.contains(i.id)) i,
    ];
    if (items.isEmpty) return;

    final makers = await loadMakers();
    if (!mounted) return;
    final answer = await _askMakerAndPlace(items.length, makers);
    if (answer == null) return;

    try {
      final added = await addCatalogItemsToInventory(
        items,
        maker: answer.maker,
        location: answer.place,
        worker: widget.workerName,
        shared: answer.shared,
      );
      await rememberMaker(answer.maker);
      if (!mounted) return;
      setState(() => _picked.clear());
      final skipped = items.length - added;
      showCuttingSnack(
        context,
        skipped == 0
            ? "자재 $added개를 재고에 넣었습니다."
            : "자재 $added개를 넣었습니다. $skipped개는 이미 있습니다.",
      );
    } catch (_) {
      if (!mounted) return;
      showCuttingSnack(context, "재고에 넣지 못했습니다.", isError: true);
    }
  }

  Future<_MakerPlace?> _askMakerAndPlace(int count, List<String> makers) async {
    var maker = '';
    var shared = false;
    final place = TextEditingController();
    final typed = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Builder(
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setInner) => AlertDialog(
            title: Text("자재 $count개를 재고에 넣습니다"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "제조사 (안 정했으면 비워 둡니다)",
                    style: TextStyle(
                      color: CuttingColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in makers)
                        ChoiceChip(
                          label: Text(m),
                          labelStyle: TextStyle(
                            color: maker == m
                                ? Colors.white
                                : CuttingColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          selected: maker == m,
                          selectedColor: CuttingColors.primary,
                          backgroundColor: CuttingColors.background,
                          showCheckmark: false,
                          side: BorderSide.none,
                          onSelected: (v) => setInner(() {
                            maker = v ? m : '';
                            if (v) typed.clear();
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: typed,
                    decoration: const InputDecoration(
                      labelText: "목록에 없는 제조사",
                      isDense: true,
                    ),
                    onChanged: (v) => setInner(() {
                      if (v.trim().isNotEmpty) maker = v.trim();
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: place,
                    decoration: const InputDecoration(
                      labelText: "보관 위치 (예: H-2 자재렉)",
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 끄면 내 개인 재고, 켜면 같이 쓰는 공용 재고.
                  SwitchListTile(
                    key: const Key('catalog_shared'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text("공용 재고로 넣기"),
                    subtitle: Text(
                      shared ? "같이 쓰는 사람 모두 봅니다." : "내 개인 재고로 넣습니다.",
                    ),
                    value: shared,
                    onChanged: (v) => setInner(() => shared = v),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "수량은 0으로 넣습니다. 재고조사나 반납으로 채웁니다.",
                    style: TextStyle(
                      color: CuttingColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("취소"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: CuttingColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("넣기"),
              ),
            ],
          ),
        ),
      ),
    );

    if (ok != true) return null;
    return _MakerPlace(maker, place.text, shared: shared);
  }

  Future<void> _editItem(CatalogItem item) async {
    final name = TextEditingController(text: item.name);
    final spec = TextEditingController(text: item.spec);
    final unit = TextEditingController(text: item.unit);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("자재 고치기"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: "이름", isDense: true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: spec,
              decoration: const InputDecoration(labelText: "규격", isDense: true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: unit,
              decoration: const InputDecoration(
                labelText: "단위 (본 / m / EA)",
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CuttingColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("고치기"),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (name.text.trim().isEmpty) return;

    try {
      await saveCatalogItem(
        CatalogItem(
          id: item.id,
          name: name.text.trim(),
          category: item.category,
          spec: spec.text.trim(),
          kind: item.kind,
          unit: unit.text.trim().isEmpty ? item.unit : unit.text.trim(),
          order: item.order,
          source: item.source,
        ),
      );
      if (!mounted) return;
      showCuttingSnack(context, "고쳤습니다.");
      await _load();
    } catch (_) {
      if (!mounted) return;
      showCuttingSnack(context, "고치지 못했습니다.", isError: true);
    }
  }

  Future<void> _deleteItem(CatalogItem item) async {
    final ok = await showCuttingConfirmDialog(
      context,
      title: "목록에서 지우겠습니까?",
      message: "${item.name}을 자재 목록에서 지웁니다. 창고 재고는 그대로 둡니다.",
      confirmLabel: "지우기",
      danger: true,
    );
    if (!ok) return;
    try {
      await deleteCatalogItem(item.id);
      if (!mounted) return;
      showCuttingSnack(context, "지웠습니다.");
      await _load();
    } catch (_) {
      if (!mounted) return;
      showCuttingSnack(context, "지우지 못했습니다.", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return Scaffold(
      backgroundColor: CuttingColors.surface,
      appBar: AppBar(
        backgroundColor: CuttingColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "자재 목록",
          style: TextStyle(
            color: CuttingColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: CuttingColors.textPrimary),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'fill') _fillFromApp();
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'fill', child: Text("기본 목록 채우기")),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: CuttingColors.primary),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: CuttingColors.background,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      hintText: "자재 이름·규격 찾기",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final c in _categories)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(
                              c == 'ALL' ? '전체' : materialCategoryLabel(c),
                            ),
                            labelStyle: TextStyle(
                              color: _category == c
                                  ? Colors.white
                                  : CuttingColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                            selected: _category == c,
                            selectedColor: CuttingColors.primary,
                            backgroundColor: CuttingColors.background,
                            showCheckmark: false,
                            side: BorderSide.none,
                            onSelected: (_) => setState(() => _category = c),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: CuttingColors.border),
                Expanded(
                  child: shown.isEmpty
                      ? const Center(
                          child: Text(
                            "찾는 자재가 없습니다.",
                            style: TextStyle(
                              color: CuttingColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: shown.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            color: CuttingColors.border,
                            indent: 16,
                            endIndent: 16,
                          ),
                          itemBuilder: (context, i) {
                            final item = shown[i];
                            final on = _picked.contains(item.id);
                            return ListTile(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  if (on) {
                                    _picked.remove(item.id);
                                  } else {
                                    _picked.add(item.id);
                                  }
                                });
                              },
                              onLongPress: () => _showRowMenu(item),
                              leading: Icon(
                                on ? Icons.check_circle : Icons.circle_outlined,
                                color: on
                                    ? CuttingColors.primary
                                    : CuttingColors.border,
                              ),
                              title: Text(
                                item.name,
                                style: const TextStyle(
                                  color: CuttingColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  if (item.kind.isNotEmpty)
                                    item.kind
                                  else
                                    materialCategoryLabel(item.category),
                                  "단위 ${item.unit}",
                                  if (item.source.isNotEmpty) item.source,
                                ].join(' · '),
                                style: const TextStyle(
                                  color: CuttingColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: _picked.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CuttingColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _putIntoInventory,
                  child: Text(
                    "${_picked.length}개 재고에 넣기",
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  void _showRowMenu(CatalogItem item) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text("이름·규격 고치기"),
              onTap: () {
                Navigator.pop(ctx);
                _editItem(item);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: CuttingColors.danger,
              ),
              title: const Text("목록에서 지우기"),
              onTap: () {
                Navigator.pop(ctx);
                _deleteItem(item);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MakerPlace {
  final String maker;
  final String place;
  final bool shared;
  const _MakerPlace(this.maker, this.place, {this.shared = false});
}
